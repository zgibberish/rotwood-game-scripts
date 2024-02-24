local DebugDraw = require "util.debugdraw"
local DebugNodes = require "dbui.debug_nodes"
local MapLayout = require "util.maplayout"
local PropProcGen = require "proc_gen.prop_proc_gen"
local Vec2 = require "math.modules.vec2"
local ZoneGenBuilder = require "proc_gen.zone_gen_builder"
local ZoneGrid = require "map.zone_grid"
local iterator = require "util.iterator"
local lume = require "util.lume"
local spawnutil = require "util.spawnutil"

-- Visit each child and add any propagated meta-property they have into the 'propagated' table
-- in our meta-table.
local function ResolvePropagatedMetaProperties(t)
	if not t then
		return
	end
	local new_meta = {propagated = {}}
	for key, value in pairs(t) do
		-- First resolve meta-property propagation for the child.
		local propagate = true
		if type(value) == "table" then
			ResolvePropagatedMetaProperties(value)

			-- Do not propagate properties of empty tables.
			if not next(value) then
				propagate = false
			end
		end

		if propagate then
			-- Then allow the child properties to propagate to us.
			local child_meta = getmetatable(value)
			if child_meta and child_meta.propagate then
				for propagated_field, priority in pairs(child_meta.propagate) do
					local current = new_meta.propagated[propagated_field]
					local candidate = child_meta[propagated_field] and { value = child_meta[propagated_field], priority = priority }
						or child_meta.propagated[propagated_field]

					-- Higher priorities win.
					if not current or current.priority < candidate.priority then
						new_meta.propagated[propagated_field] = candidate
					end
				end

				-- Add the child's propagators as our own, and pass them to our parent.
				new_meta.propagate = new_meta.propagate and lume(new_meta.propagate):merge(child_meta.propagate):result() or child_meta.propagate
			end
		end
	end
	if next(new_meta.propagated) then
		local meta = getmetatable(t)
		if meta then
			-- If we have a metatable already, be careful to only merge in the propagation data.
			if not meta.propagated then
				meta.propagated = new_meta.propagated
			else
				-- When merging the propagated fields, remember to consider, compare, and propagate the priority.
				for field, candidate in pairs(new_meta.propagated) do
					local current = meta.propagated[field]
					if not current or current.priority < candidate.priority then
						meta.propagated[field] = candidate
					end					
				end
			end
			meta.propagate = meta.propagate and lume(meta.propagate):merge(new_meta.propagate):result() or new_meta.propagate
		else
			setmetatable(t,new_meta)
		end
	end
end

local DebugProcGen = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Proc Gen")
	self.draw_zone = false
	self.draw_featured_locations = false
	self.draw_tile_info = false
	self.draw_decor_physics = false
	self.tile_labels = {}
	self.tasks = {}
	self.execution_report = scene_gen_execution_report
	ResolvePropagatedMetaProperties(self.execution_report)

	self._on_world_remove = function() self:_ClearState() end
end)

DebugProcGen.PANEL_WIDTH = 600
DebugProcGen.PANEL_HEIGHT = 800

function DebugProcGen:OnActivate()
	self:DoDrawDecorPhysics()
	-- DebugProcGen is coupled to current world, so use it as listener (but
	-- we'll detach when inactive).
	TheWorld:ListenForEvent("onremove", self._on_world_remove)
end

function DebugProcGen:_CancelDraw()
	if self.tasks.zones then
		self.tasks.zones:Cancel()
		self.tasks.zones = nil
	end
	self:_RetireTileInfos()
end

function DebugProcGen:_CancelDrawFeaturedLocations()
	if self.tasks.featured_locations then
		self.tasks.featured_locations:Cancel()
		self.tasks.featured_locations = nil
	end
end

function DebugProcGen:_CancelDrawDecorPhysics()
	if self.tasks.decor_physics then
		self.tasks.decor_physics:Cancel()
		self.tasks.decor_physics = nil
	end
end

function DebugProcGen:OnDeactivate()
	self:_ClearState()
	TheWorld:RemoveEventCallback("onremove", self._on_world_remove)
end

function DebugProcGen:_ClearState()
	self:_CancelDraw()
	self:_CancelDrawFeaturedLocations()
	self:_CancelDrawDecorPhysics()
	assert(next(self.tasks) == nil, "Forgot to cleanup a task.")

	self.zone = nil
	self.zone_grid = nil
end

local function AddTreeNodeEnder(ui)
	ui:Dummy(0, 5)
	ui:TreePop()
end

function DebugProcGen:RenderPanel( ui, panel )
	self:ZoneUi(ui, panel)
	self:SceneGenUi(ui, panel)
	self:FeaturedLocationsUi(ui, panel)
end

function DebugProcGen:_FilterZoneCell(x, z)
	if self.zone == #PropProcGen.Zone:Ordered() + 1 then
		return not lume(self.zone_grid.position_filters):any(function(filter) return filter(x, z) end):result()
	else
		return self.zone_grid.position_filters[PropProcGen.Zone:Ordered()[self.zone]](x, z)
	end
end

function DebugProcGen:_SpawnTileInfos()
	self.zone_grid:ForEachCell(function(cell, x, z)
		if cell ~= nil and self:_FilterZoneCell(x, z) then
			local cell_info = ZoneGrid.CellInfo(cell)
			local world_point = self.zone_grid:GridToWorld({ x = x, z = z })
			local position = Vector3(world_point.x, world_point.y or 0, world_point.z)

			local tile_info = spawnutil.SpawnWorldLabel(cell_info, position)
			tile_info.Transform:SetScale(0.5, 0.5, 0.5)
			table.insert(self.tile_labels, tile_info)

			-- TODO @chrisp #proc_gen - Would be nicer to use WorldText as it renders on top of the game world, but
			-- alas it does not render in the correct position.
			-- local world_text =  DebugDraw.WorldText
			-- 	( cell_info
			-- 	, position
			-- 	, 10
			-- 	, WEBCOLORS.YELLOW
			-- )
			-- table.insert(self.tile_labels, world_text)
		end
	end)
end

function DebugProcGen:_RetireTileInfos()
	for _, label in ipairs(self.tile_labels) do
		spawnutil.FlagForRemoval(label)
		if label.components.worldtext then 
			label.components.worldtext.inst.followtext:Remove()
		end
	end
	self.tile_labels = {}
end

function DebugProcGen:ZoneUi(ui, panel)
	if not ui:TreeNode("Zones", ui.TreeNodeFlags.DefaultClosed) then
		return
	end

	local id = "##ZoneUi"

	local new_draw_zone
	new_draw_zone, self.draw_zone = ui:Checkbox("Draw Enabled"..id, self.draw_zone)

	local STAGE_BOUNDS_COLOR = WEBCOLORS.CORAL
	local OFFSTAGE_BOUNDS_COLOR = WEBCOLORS.DEEPPINK
	local TILE_COLOR = WEBCOLORS.BLUE

	if self.draw_zone then
		ui:PushStyleColor(ui.Col.Text, STAGE_BOUNDS_COLOR)
		ui:Text("Stage Bounds")
		ui:PushStyleColor(ui.Col.Text, OFFSTAGE_BOUNDS_COLOR)
		ui:SameLineWithSpace()
		ui:Text("Offstage Bounds")
		ui:PushStyleColor(ui.Col.Text, TILE_COLOR)
		ui:SameLineWithSpace()
		ui:Text("TilEd Tile")
		ui:PopStyleColor(3)
	end

	local new_draw_tile_info
	new_draw_tile_info, self.draw_tile_info = ui:Checkbox("Tile Info Enabled"..id, self.draw_tile_info)
	if new_draw_tile_info then
		if self.draw_tile_info then
			self:_SpawnTileInfos()
		else
			self:_RetireTileInfos()
		end
	end

	local zones = deepcopy(PropProcGen.Zone:Ordered())
	table.insert(zones, "NO ZONE!")
	local zone = ui:_Combo( "Zone"..id, self.zone or 1, zones )
	if zone == self.zone then
		AddTreeNodeEnder(ui)
		return
	end

	self:_CancelDraw()

	self.zone = zone

	self.zone_grid = self.zone_grid or ZoneGrid(MapLayout(TheWorld.layout))
	local seconds = 0.5
	local thick = 2

	self.tasks.zones = TheWorld:DoPeriodicTask(seconds, function(_)
		if not self.draw_zone then return end
		self.zone_grid:ForEachCell(function(cell, x, z)
			if cell ~= nil and self:_FilterZoneCell(x, z) then
				local offstage_bounds = self.zone_grid:GetOffstageBounds(x, z)
				if offstage_bounds then
					offstage_bounds = offstage_bounds:with_size(offstage_bounds:size() * 0.92)
					DebugDraw.GroundRect
						( offstage_bounds.min.x
						, offstage_bounds.min.y
						, offstage_bounds.max.x
						, offstage_bounds.max.y
						, OFFSTAGE_BOUNDS_COLOR
						, thick
						, seconds
					)
				end
				local stage_bounds = self.zone_grid:GetStageBounds(x, z)
				if stage_bounds then
					stage_bounds = stage_bounds:with_size(stage_bounds:size() * 0.94)
					DebugDraw.GroundRect
						( stage_bounds.min.x
						, stage_bounds.min.y
						, stage_bounds.max.x
						, stage_bounds.max.y
						, STAGE_BOUNDS_COLOR
						, thick
						, seconds
					)
				end
				local world_point = self.zone_grid:GridToWorld({ x = x, z = z })
				DebugDraw.GroundSquare
					( world_point.x
					, world_point.z
					, ZoneGrid.WORLD_TILE_SIZE * 0.96
					, TILE_COLOR
					, thick
					, seconds
				)
			end
		end)
	end)
	
	if self.draw_tile_info then
		self:_SpawnTileInfos()
	end

	AddTreeNodeEnder(ui)
end

-- Display a table via imgui. Tables are tree nodes and key-value pairs are rendered as strings.
local function ShowTable(ui, t, id)
	for key, value in iterator.sorted_pairs(t) do
		if type(value) == "table" then
			local meta = getmetatable(value)
			local color = meta and meta.color
			if color then
				ui:PushStyleColor(ui.Col.Text, color)
			end

			local hide_if_empty = meta and meta.hide_if_empty ~= nil and meta.hide_if_empty
			local empty = next(value) == nil
			if empty and not hide_if_empty then
				ui:Text(key.." (EMPTY)")
			elseif not (empty and hide_if_empty) then
				local nested_color = meta and meta.propagated and meta.propagated.color and meta.propagated.color.value
				if nested_color then
					ui:PushStyleColor(ui.Col.Text, nested_color)
				end
				if ui:TreeNode(key..id, ui.TreeNodeFlags.DefaultClosed) then
					if nested_color then
						ui:PopStyleColor()
					end
					ShowTable(ui, value, id..key)
					AddTreeNodeEnder(ui)
				else
					if nested_color then
						ui:PopStyleColor()
					end
				end
			end

			if color then
				ui:PopStyleColor()
			end
		elseif type(value) == "number" and math.type(value) == "float" then
			ui:Value(key, value, "%0.3f")
	 	else			
			ui:Value(key, value)
		end
	end
end

function DebugProcGen:SceneGenUi(ui, panel)
	if not self.execution_report.name then
		return
	end
	local id = "##SceneGenUi"
	if not ui:TreeNode("Scene Gen Report: "..self.execution_report.name, ui.TreeNodeFlags.DefaultClosed) then
		return
	end
	ui:Text("Dungeon Progress: "..self.execution_report.dungeon_progress)
	if self.execution_report.zone_gens then
		for i, zone_gen in ipairs(self.execution_report.zone_gens) do
			self:ZoneGenUi(ui, i, zone_gen)
		end
	end
	AddTreeNodeEnder(ui)
end

function DebugProcGen:ZoneGenUi(ui, zone_gen_index, zone_gen)
	zone_gen.draw_decor_physics = ui:_Checkbox("##draw_decor_physics"..zone_gen_index, zone_gen.draw_decor_physics)	
	ui:SetTooltipIfHovered("Draw Physics")
	ui:SameLineWithSpace()
	local has_messages = next(zone_gen.log)
	if has_messages then
		ui:PushStyleColor(ui.Col.Text, WEBCOLORS.YELLOW)
	end
	local changed, selected = ui:Selectable(
		zone_gen.name,
		self.selected_zone_gen == zone_gen_index
	)
	if has_messages then
		ui:PopStyleColor()
	end
	if changed then
		self.selected_zone_gen = selected and zone_gen_index or nil
	end
	if self.selected_zone_gen == zone_gen_index then
		ui:Indent()
		ui:Text("Spawn Health: "..zone_gen.spawn_health)
		if has_messages and ui:CollapsingHeader("Log##"..zone_gen_index) then
			ui:Indent()
			for _, warning in ipairs(zone_gen.log) do
				ui:Text(warning)
			end
			ui:Unindent()
		end
		ui:Unindent()
	end
end

function DebugProcGen:DoDrawDecorPhysics()
	local COLOR = WEBCOLORS.RED

	self:_CancelDrawDecorPhysics()

	local seconds = 0.5
	local thick = 2

	self.tasks.decor_physics = TheWorld:DoPeriodicTask(seconds, function(_)
		if not self.execution_report.zone_gens then
			return
		end
		for _, zone_gen in pairs(self.execution_report.zone_gens) do
			if zone_gen.draw_decor_physics then
				for _, circle in ipairs(zone_gen.circles) do
					if circle.type == DecorType.s.Prop then
						DebugDraw.GroundCircle
							( circle.position.x
							, circle.position.y
							, circle.radius
							, COLOR
							, thick
							, seconds
							)
					end
				end
			end
		end
	end)
end

function DebugProcGen:FeaturedLocationsUi(ui, panel)
	local new_draw_featured_locations
	new_draw_featured_locations, self.draw_featured_locations = ui:Checkbox("Draw Featured Locations", self.draw_featured_locations)

	if not new_draw_featured_locations then
		return
	end

	local COLOR = WEBCOLORS.YELLOW

	if self.draw_featured_locations then
		-- ui:PushStyleColor(ui.Col.Text, COLOR)
		-- ui:Text("Stage Bounds")
		-- ui:PopStyleColor(1)
	end

	self:_CancelDrawFeaturedLocations()

	local seconds = 0.5
	local thick = 2

	local function DrawSemiCircle(x, z)
		DebugDraw.GroundProjectedSemiCircle
			( x
			, z
			, -math.pi / 2
			, ZoneGenBuilder.FEATURE_RADIUS
			, COLOR
			, thick
			, seconds
			)	
	end

	local function DrawBounds(bounds)
		DebugDraw.GroundRect(
			bounds.min.x,
			bounds.min.y,
			bounds.max.x,
			bounds.max.y
			, COLOR
			, thick
			, seconds
		)
	end

	local function DrawClosedPolygon(polygon)
		for i = 1, #polygon do
			local next_i
			if i == #polygon then
				next_i = 1
			else
				next_i = i + 1
			end
			local a = polygon[i]
			local b = polygon[next_i]
			DebugDraw.GroundLine(a.x, a.y, b.x, b.y, COLOR, thick, seconds)
		end
	end

	self.zone_grid = self.zone_grid or ZoneGrid(MapLayout(TheWorld.layout))

	self.tasks.featured_locations = TheWorld:DoPeriodicTask(seconds, function(_)
		if not self.draw_featured_locations
			or not self.execution_report.featured_locations
		then 
			return 
		end
		for _, featured_location in ipairs(self.execution_report.featured_locations) do
			-- If the featured location is structured as a point
			if featured_location.x or featured_location.z then
				local bounds = ZoneGenBuilder.MakeFeaturedLocationRect(
					Vec2(featured_location.x, featured_location.z),
					ZoneGenBuilder.FEATURE_HEIGHT
				)
				DrawBounds(bounds)
			-- If the featured location is structured as a set of line segments.
			elseif featured_location.player and featured_location.exits then
				for _, exit in ipairs(featured_location.exits) do
					local convex_polygon = ZoneGenBuilder.MakeFeaturedLocationRectSweep(
						Vec2(featured_location.player.x, featured_location.player.z), 
						Vec2(exit.x, exit.z),
						ZoneGenBuilder.FEATURE_HEIGHT
					)
					DrawClosedPolygon(convex_polygon)
				end
			end
		end
	end)
end

DebugNodes.DebugProcGen = DebugProcGen

return DebugProcGen
