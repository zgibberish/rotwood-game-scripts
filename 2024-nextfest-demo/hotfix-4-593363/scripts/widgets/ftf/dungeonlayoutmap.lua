local Bound2 = require "math.modules.bound2"
local Button = require "widgets.button"
local DungeonHistoryMap = require "widgets.ftf.dungeonhistorymap"
local Image = require "widgets.image"
local MapRoom = require "widgets.ftf.maproom"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local kassert = require "util.kassert"
local lume = require "util.lume"
local templates = require "widgets.ftf.templates"
require "class"
require "vector2"


-- This map shows the layout of the dungeon with all the choices we presented
-- to you.

local function noop() end
local nodeSizeMin = 100

-- set to true to allow some debug buttons to work on clients
local EnableDebugButtonsOnClients = false
------------------------------------------------------------------------------------------
--- Map of the dungeon.
----
local DungeonLayoutMap = Class(Widget, function(self, nav)
	Widget._ctor(self, "DungeonLayoutMap")
	kassert.typeof("table", nav)

	self.nav = nav
	self.onMapChangedFn = noop

	self.buttons = self:AddChild(Widget())
		:LayoutBounds("after", "top", self)
		:Offset(200, -220)

	self.debug_btn = self.buttons:AddChild(templates.Button("Dump World Info"))
		:SetDebug()
		:SetOnClick(function()
			d_dumpworldgen()
			self.roomid_btn.onclick()
			TheSim:OpenGameLogFolder()
		end)

	self.roomid_btn = self.buttons:AddChild(templates.Button("Show Room IDs"))
		:SetDebug()
		:SetOnClick(function()
			for rid, node in pairs(self.map_nodes) do
				if node.debug_label then
					node.debug_label:Show()
					if node.is_potential_path then
						node.debug_label:SetGlyphColor(WEBCOLORS.LIGHTBLUE)
					end
				end
				if self.nav.data.gen_state.dbg_tracker then
					node:SetToolTip(table.inspect(self.nav.data.gen_state.dbg_tracker[rid]))
					--~ node:SetToolTip(table.inspect(node.room))
				end
			end
			-- Move up enough to see full tooltip.
			local x = self:GetPosition()
			self:SetPosition(x, 0)
		end)

	self.scout = self.buttons:AddChild(templates.Button(""))
		:SetDebug()
	self.scout
		:SetOnClick(function()
			local scout = TheSaveSystem.friends:GetValue("scout") or 1
			scout = circular_index_number(4, scout + 1)
			TheSaveSystem.friends:SetValue("scout", scout)
			self.scout:RefreshScoutLabel()
		end)
	self.scout.RefreshScoutLabel = function(_)
		local scout = TheSaveSystem.friends:GetValue("scout") or 1
		self.scout:SetText("Scout Level ".. scout)
	end
	self.scout:RefreshScoutLabel()

	self.regen_btn = self.buttons:AddChild(templates.Button("Regen Map"))
		:SetDebug()
		:SetEnabled(TheNet:IsGameTypeLocal())
		:SetToolTip(not TheNet:IsGameTypeLocal() and "Only available in local games")
		:SetOnClick(function()
			local worldmap = TheDungeon:GetDungeonMap()
			self.seed = (self.seed or 0) + 1
			local biome_location = worldmap:GetBiomeLocation()
			worldmap:GenerateDungeonMap(biome_location, self.seed, nil, worldmap:BuildQuestParams(biome_location.id))
			self.nav = worldmap.nav
			print(self.seed, worldmap:GetDebugString(true))
			self:_RebuildMapNodes()

			-- Save so if we c_reset, there's still a valid map.
			TheSaveSystem.dungeon:SetValue("worldmap", worldmap:GetMapData())
			TheSaveSystem.dungeon:Save()

			self.onMapChangedFn()
		end)

	self.step_top = self.buttons:AddChild(templates.Button("Full Path - Top"))
		:SetDebug()
		:SetEnabled(TheNet:IsHost() or EnableDebugButtonsOnClients)
		:SetToolTip(not (TheNet:IsHost() or EnableDebugButtonsOnClients) and "Only available for hosts or set EnableDebugButtonsOnClients")
		:SetOnClick(function()
			local worldmap = TheDungeon:GetDungeonMap()
			local traveled = worldmap:Debug_StepDungeon(nil, false)
			self._debug_travel_used = self._debug_travel_used or traveled
			self:_RebuildMapNodes()
			self.onMapChangedFn()
		end)

	self.step_all = self.buttons:AddChild(templates.Button("Full Path - Random"))
		:SetDebug()
		:SetEnabled(TheNet:IsGameTypeLocal())
		:SetToolTip(not TheNet:IsGameTypeLocal() and "Only available in local games")
		:SetOnClick(function()
			local worldmap = TheDungeon:GetDungeonMap()
			local traveled = worldmap:Debug_StepDungeon(nil, true)
			self._debug_travel_used = self._debug_travel_used or traveled
			self:_RebuildMapNodes()
			self.onMapChangedFn()
		end)

	self.reveal_step = self.buttons:AddChild(templates.Button("Next Room"))
		:SetDebug()
		:SetEnabled(TheNet:IsHost() or EnableDebugButtonsOnClients)
		:SetToolTip(not (TheNet:IsHost() or EnableDebugButtonsOnClients) and "Only available for hosts or set EnableDebugButtonsOnClients")
		:SetOnClick(function()
			local worldmap = TheDungeon:GetDungeonMap()
			local traveled = worldmap:Debug_StepDungeon(1, false)
			self._debug_travel_used = self._debug_travel_used or traveled
			self:_RebuildMapNodes()
			self.onMapChangedFn()
		end)

	self.reveal_all = self.buttons:AddChild(templates.Button("Reveal All"))
		:SetDebug()
		:SetEnabled(TheNet:IsHost() or EnableDebugButtonsOnClients)
		:SetToolTip(not (TheNet:IsHost() or EnableDebugButtonsOnClients) and "Only available for hosts or set EnableDebugButtonsOnClients")
		:SetOnClick(function()
			local worldmap = TheDungeon:GetDungeonMap()
			worldmap:RevealAll()
			self:_RebuildMapNodes()

			self.onMapChangedFn()
		end)

	self.regen_reveal = self.buttons:AddChild(templates.Button("Regen and Full Path"))
		:SetDebug()
		:SetEnabled(TheNet:IsHost())
		:SetToolTip(not TheNet:IsHost() and "Only available for hosts")
		:SetOnClick(function()
			self.regen_btn:onclick()
			self.step_top:onclick()
		end)

	self.buttons:LayoutChildrenInGrid(1, 10)

	if TheWorld:HasTag("town") then
		-- Buttons don't work in town since it doesn't have a mapgen biome.
		self.buttons:Hide()
	end

	--~ self.inst:StartWallUpdatingComponent(self)
end)

function DungeonLayoutMap:Debug_SetupEditor(parent)
	assert(not self.mapgen_label, "Already setup debug editor.")

	local mapgen_name = self.nav.data.gen_state.alternate_mapgen_name or self.nav:GetBiomeLocation().id
	-- Don't use self as parent so it doesn't affect how may is laid out.
	self.mapgen_label = parent:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.BUTTON, ""))
		:SetText("mapgen: ".. mapgen_name)
		:LayoutBounds("center", "top", parent)
		:Offset(0, -50)

	-- TODO: Maybe only init these debug buttons here?
	self.buttons:Reparent(parent)
		:SetScale(0.6, 0.6)
		:LayoutBounds("right", "top", parent)
		:Offset(-30, -30)
	return self
end

function DungeonLayoutMap:DrawFullMap()
	self.preview_roomid = nil
	self.preview_cardinal_data = nil
	self:_RebuildMapNodes()
	return self
end

function DungeonLayoutMap:DrawMapAfterRoomId(room_id, cardinal_data)
	self.preview_roomid = room_id
	self.preview_cardinal_data = cardinal_data
	-- Remove buttons so they don't mess with layout.
	self.buttons:Remove()
	self.buttons = nil
	self:_RebuildMapNodes()
	return self
end

function DungeonLayoutMap:Debug_MakeNodesClickable()
	for rid, node in pairs(self.map_nodes) do
		if node.is_potential_path then
			node.go_btn = node:AddChild(Button())
				:SetText(tostring(rid), true)
				:SetTextColour(WEBCOLORS.WHITE)
				:SetTextFocusColour(WEBCOLORS.YELLOW)
				:SetTextSize(80)
				:IgnoreParentMultColor()
				:Offset(0, -20)
				:SetOnClick(function()
					local dest_room = self.nav.data.rooms[rid]
					if not dest_room.roomtype then
						-- No roomtype means no generation has occurred so we'd
						-- crash on loading. Can't just reveal to current room
						-- without implementing pathfinding. Don't want to try
						-- to run dungeon gen out of order since it risks
						-- producing more bugs.
						print("Room is unrevealed. We'll reveal a bunch of rooms and hopefully the one you want will be available.")
						local worldmap = TheDungeon:GetDungeonMap()
						local current = worldmap:Debug_GetCurrentRoom()
						local depth = dest_room.depth - current.depth - worldmap:_GetScoutLevel()
						local traveled = worldmap:Debug_StepDungeon(depth, false)
						self._debug_travel_used = self._debug_travel_used or traveled
						self:_RebuildMapNodes()
						self.onMapChangedFn()
						self:Debug_MakeNodesClickable()
						return
					end
					local prev_rid = self.nav:get_first_backtrack_roomid(dest_room)
					if not prev_rid then
						TheLog.ch.WorldMap:printf("Failed to find previous room for roomid %i", rid)
						return
					end
					local prev_room = self.nav.data.rooms[prev_rid]
					local cardinal = lume.find(prev_room.connect, rid)
					self.nav.data.current = prev_rid
					TheDungeon:GetDungeonMap():TravelCardinalDirection(cardinal)
					local screen = TheFrontEnd:GetActiveScreen()
					if screen.Unpause then
						-- Need sim to tick for travel to work.
						screen:Unpause()
					end
				end)
		end
	end
end

local MapConnector = Class(Widget, function(self, line_id)
	Widget._ctor(self, "MapConnector")
	self:SetName(tostring(line_id))
	self.line = self:AddChild(Image("images/ui_dungeonmap/in_world_map_arrows.tex"))
		:SetMultColor(MapRoom.GetColor_FutureConnector())
	self.label = self.line:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.BUTTON, self._widgetname))
		:Hide() -- only show for debug
	self:SetIsNextConnector(false)
end)

function MapConnector:SetIsNextConnector(is_next)
	if is_next then
		self.line:SetMultColor(MapRoom.GetColor_NextConnector())
	else
		self.line:SetMultColor(MapRoom.GetColor_FutureConnector())
	end
	return self
end

function MapConnector:SetRelevant(is_relevant)
	local alpha = is_relevant and 1 or 0.25
	self.line:SetMultColorAlpha(alpha)
	return self
end

function MapConnector:SetLength(length)
	-- tex can no longer be stretched, so can't change length.
	--~ length = math.max(length, 30)
	--~ self.line:SetSize(length, 30)
	return self
end

function MapConnector:SetVisited()
	return self
end

local cardinal_offsets = {
	north = Vector2(0, 25),
	south = Vector2(0, -25),
	east  = Vector2(0, 0),
	west  = Vector2(0, 0),
}

local function _position_connector(node_connection, start_node, end_node)
	if start_node.room.depth > end_node.room.depth then
		start_node, end_node = end_node, start_node
	end
	if start_node.room.has_visited
		and end_node.room.has_visited
	then
		node_connection:SetVisited()
	else
		local is_relevant = ((start_node.is_potential_path or start_node.room.has_visited)
			and end_node.is_potential_path)
		node_connection:SetRelevant(is_relevant)
		start_node:SetRelevant(is_relevant or start_node.room.has_visited)
		end_node:SetRelevant(is_relevant or end_node.room.has_visited)
	end

	node_connection.start_node = start_node
	node_connection.end_node = end_node

	local offset = Vector2.zero
	local one_entrance_one_exit = 2
	if lume.count(start_node.room.connect) > one_entrance_one_exit then
		local cardinal = lume.find(start_node.room.connect, end_node.room.index)
		offset = cardinal_offsets[cardinal]
		assert(offset, cardinal) -- failed to find it?
	end

	--~ assert(start_node.use_simple_endpoint, node_connection.label.text)
	local start_pos = start_node:GetPositionAsVec2() + offset
	local end_pos = end_node:GetConnectionEndpoint(start_pos)

	local midpoint = (start_pos + end_pos) / 2
	local node_distance = end_pos:Dist(start_pos)
	local delta = start_pos - end_pos
	local angle = delta:AngleTo_Degrees(Vector2.unit_x)

	node_connection:SetPosition(midpoint.x, midpoint.y)
		:SetLength(node_distance - 200) -- leave gap between room and connector
		:SetRotation(angle + 180)
		:SendToBack()

	-- Draw unrevealed nodes above the connectors, since the texture doesn't "connect"
	if not start_node:IsRevealed() then
		start_node:SendToFront()
	end
	if not end_node:IsRevealed() then
		end_node:SendToFront()
	end

	node_connection:SendToBack()

	return node_connection
end

function DungeonLayoutMap:SetOnMapChangedFn(fn)
	self.onMapChangedFn = fn
	return self
end

function DungeonLayoutMap:_ShouldShowRoom(room)
	if not self.nav:is_room_reachable(room) then
		return false
	end
	return (not self.preview_roomid
		or self.preview_roomid == room.index
		or (room.backlinks[self.preview_roomid]
			-- Don't show hype/boss in preview because it should feel unique.
			and room.index ~= self.nav:get_hype_room_id()))
end

function DungeonLayoutMap:_RebuildMapNodes()
	if self.node_root then
		self.node_root:Remove()
	end
	self.node_root = self:AddChild(Widget())
	self.map_nodes = {}
	self.connectors = {} -- The lines connecting the rooms

	local current_rid = self.nav.data.current
	local final = self.nav:get_final_room()
	if final and final.index == current_rid then
		-- Don't show the boss room as a separate room from the hype room.
		current_rid = self.nav:get_hype_room_id()
	end

	local biome_location = self.nav:GetBiomeLocation()

	-- Create rooms
	for room_id,room in ipairs(self.nav.data.rooms) do
		if self:_ShouldShowRoom(room) then
			-- Create room and set it up
			local node = self.node_root:AddChild(MapRoom(room))
			node:SetLocatorColor(WEBCOLORS.WHITE)
			node:ConfigureRoom(self.nav, biome_location, room, current_rid)
			node:SetTheme_SignpostFuture()
			self.map_nodes[room_id] = node
			if self.preview_cardinal_data then
				node:SetRotation(-self.preview_cardinal_data.map_rot)
				if room_id == self.preview_roomid then
					node:SetTheme_SignpostNext()
					if room.roomtype == "hype" then
						-- Boss rooms are too big.
						node:SetScale(0.8)
					end
				end
			end
		end
	end

	-- Tag all nodes forward from the current room.
	local waiting = { current_rid }
	while next(waiting) do
		local room_id = table.remove(waiting, 1)
		local room = self.nav.data.rooms[room_id]
		for cardinal, dest_rid in pairs(room.connect) do
			local dest_node = self.map_nodes[dest_rid]
			if dest_node
				and not self.nav:is_backtracking(room_id, dest_rid)
			then
				dest_node.is_potential_path = true
				table.insert(waiting, dest_rid)
			end
		end
	end

	-- Hide all rooms
	for rid, node in pairs(self.map_nodes) do
		node:Hide()
	end

	-- Show the current and revealed rooms
	for room_id, node in pairs(self.map_nodes) do
		local room = self.nav.data.rooms[room_id]
		if room.is_revealed then
			node:Show()
		end
	end

	self:_PositionNodes()


	if self.preview_roomid then
		-- Move nodes so the previewed room is at origin.
		local current = self.map_nodes[self.preview_roomid]
		local offset = Vector2.zero - current:GetPositionAsVec2()
		self.node_root:SetPosition(offset)
	else
		-- Non preview mode is now only for debug.
		self:Debug_MakeNodesClickable()
	end
end

function DungeonLayoutMap:_PositionNodes()
	-- Go through the map grid and get its rooms
	local worldmap = TheDungeon:GetDungeonMap()
	local columns, rows = worldmap:GetBounds():Get()

	-- Store a grid dictionary with all the rooms
	local connected_rooms_by_column = {}

	-- Go through the grid and save the grid positions to the rooms

	local first_col = 1

	for col = 1, columns do
		for row = 1, rows do
			connected_rooms_by_column[col] = connected_rooms_by_column[col] or {}
			local room_id = self.nav:get_room_id_safe(col, row)
			local room = self.nav.data.rooms[room_id]
			if room
				-- Restricting buckets to revealed rooms vertically centres all
				-- columns, but causes some odd angles when you take a
				-- top/bottom path.
				and room.is_revealed
				and self:_ShouldShowRoom(room)
			then
				table.insert(connected_rooms_by_column[col], room)
				if room_id == self.preview_roomid then
					first_col = col
				end
			end
		end
	end
	local max_count = math.max(table.unpack(lume.map(connected_rooms_by_column, function(bucket)
		return #bucket
	end)))

	if self.preview_roomid then
		max_count = math.max(max_count, 2)
	end


	local start = Vector2(0, 0)
	local pos = start:Clone()
	local node_spacing = Vector2(240, 340)
	local max_node_spacing_x = 350
	local min_separation = Vector2(35, 5)
	local max_offset = (node_spacing / 2) - min_separation
	local max_height = max_count * node_spacing.y

	local random_offsets = self.nav.data.layout.random_points
	if self.preview_roomid then
		-- We display so little, that randomness doesn't look better.
		random_offsets = { Vector2.zero }
	end

	local bounds = Bound2()

	for col = first_col, columns do
		local bucket = connected_rooms_by_column[col]
		local bucket_count = #bucket
		local dy = 0
		if bucket_count > 0 then
			dy = max_height / bucket_count
			pos.y = start.y + max_height - dy * 0.5
			-- otherwise we'll skip this loop anyway
		end
		local column_width = Remap(bucket_count, 1, 8, node_spacing.x, max_node_spacing_x)
		max_offset.x = (column_width / 2) - min_separation.x
		for i,room in ipairs(bucket) do
			local rnd_point = circular_index(random_offsets, room.index)
			local node = self.map_nodes[room.index]
			if node then
				local delta = max_offset:MultiplyComponents(rnd_point)
				local v = pos + delta
				node:SetPosition(v.x, v.y)
				--~ node.debug_label:SetText(serpent.line(node:GetPositionAsVec2()))
				--~ node.debug_label:SetText(col)
				if not room.is_terminal then
					bounds = bounds:extend(v)
				end
			end
			pos.y = pos.y - dy
		end
		pos.x = pos.x + column_width
	end

	-- Now that we have sizes, we can populate and set sizes.
	local pad = 10 -- ensure bounds don't overlap with node positions or we'll get nan.
	local container_data = {
		min_y = bounds.min.y - pad,
		max_y = bounds.max.y + pad,
		height = bounds:size().y,
	}
	for room_id,room in ipairs(self.nav.data.rooms) do
		local node = self.map_nodes[room.index]
		if node then
			node.container_data = container_data
		end
	end

	local final_room = self.nav:get_final_room()
	if final_room then
		-- Hide the boss room to visually join it with the hype room.
		local final_node = self.map_nodes[final_room.index]
		if final_node then
			final_node:Hide()
		end
	else
		TheLog.ch.FrontEnd:print("WARNING: Failed to find final_room. Boss room might display incorrectly.")
	end


	-- Create connections between rooms
	for src_rid,src_room in ipairs(self.nav.data.rooms) do
		local src_node = self.map_nodes[src_rid]
		if src_node then
			if src_node:IsVisible()
			then
				for cardinal, dest_rid in pairs(src_room.connect) do
					local dest_node = self.map_nodes[dest_rid]
					if dest_node
						and not self.nav:is_backtracking(src_rid, dest_rid)
						and dest_node:IsVisible()
						-- Instead of restricting to the most relevant path, we
						-- SetRelevant to dim ignorable parts of the map.
					then
						self:_ConnectRoomIds(src_rid, dest_rid)
					end
				end
			end
		end
	end

	if self.preview_roomid then
		local preview = self.map_nodes[self.preview_roomid]
		preview.connection = self.node_root:AddChild(MapConnector("entrance"))
			:SetRelevant(true)
			:SetIsNextConnector(true)
			:SetVisited()
			:SetPosition(preview:GetPosition())
			:Offset(-150, 0)
			:SendToBack()
	end
end

function DungeonLayoutMap:ScaleMap(max_x, max_y, scale_to_fit)
	-- Scale nodes to fit on screen.
	self.node_root:SetScale(1,1)
	local w, h = self.node_root:GetSize()
	local scale = 1
	if w > max_x or h > max_y then
		local x_scale = max_x / w
		local y_scale = max_y / h
		scale = math.min(x_scale, y_scale)
	end
	if not scale_to_fit then
		-- Don't let it get too tiny unless forced.
		scale = math.max(0.70, scale)
	end
	self.node_root:SetScale(scale, scale)
	return self
end

function DungeonLayoutMap:LayoutMap(relative_to, max_x, max_y, scale_to_fit)
	assert(self.node_root, "Call DrawFullMap or DrawMapAfterRoomId before LayoutMap.")
	self:ScaleMap(max_x, max_y, scale_to_fit)
	local w,h = self:GetSize()
	if w < max_x * 0.7 then
		self:LayoutBounds("center", "center", relative_to)
	else
		-- Map is too big to display, show the right size and let the left side
		-- fall offscreen since it's not important.
		self:LayoutBounds("right", "center", relative_to)
			:Offset(-200, 0)
	end
	return self
end

function DungeonLayoutMap:_ConnectRoomIds(src_rid, dest_rid)
	local src_node = self.map_nodes[src_rid]
	local dest_node = self.map_nodes[dest_rid]
	-- Position a connector.
	local line_id = DungeonHistoryMap.BuildConnectionId(src_rid, dest_rid)
	--~ print("creating connection", src_rid, dest_rid)
	local line = self.connectors[line_id] or self.node_root:AddChild(MapConnector(line_id))
	self.connectors[line_id] = line
	return _position_connector(line, src_node, dest_node)
end

function DungeonLayoutMap:CreateTravelUpdater(cardinal, duration)
	local src = self.map_nodes[self.nav.data.current]
	assert(src)
	local start_pos = src:GetPositionAsVec2()

	local room = TheDungeon:GetDungeonMap():GetDestinationForCardinalDirection(cardinal)
	assert(room)
	local dest = self.map_nodes[room.index]
	assert(dest)
	local end_pos = dest:GetConnectionEndpoint(start_pos)

	self.pointer = self.node_root:AddChild(Widget("pointer"))
		:SetPosition(start_pos:Get())
	self.pointer.img = self.pointer:AddChild(Image("images/ui_ftf_pausescreen/ic_party.tex"))
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetMultColorAlpha(0)
		:SetSize(nodeSizeMin, nodeSizeMin)
		:Offset(0, nodeSizeMin * 0.5)

	-- Make destination more visible with bg and filling in its path.
	local s = 1.3
	dest.highlight_bg = dest:AddChild(Image("images/ui_ftf/gradient_circle.tex"))
		:SendToBack()
	local connector = self:_ConnectRoomIds(src.room.index, dest.room.index)
	connector:SetVisited()
	connector:SetScale(s, s)

	self.pointer:SendToFront()

	return Updater.Series({
			Updater.Ease(function(v) self.pointer.img:SetMultColorAlpha(v) end, 0, 1, 0.7, easing.outQuad),
			Updater.Ease(function(v)
				local pos = lume.lerp(start_pos, end_pos, v)
				self.pointer:SetPosition(pos:Get())
			end, 0, 1, duration, easing.inOutQuad),
	})
end

function DungeonLayoutMap:CreateTravelUpdater_Reverse(duration)
	assert(self.pointer, "Haven't called CreateTravelUpdater yet.")
	local src = self.map_nodes[self.nav.data.current]
	assert(src)
	local start_pos = self.pointer:GetPositionAsVec2()
	local end_pos = src:GetConnectionEndpoint(start_pos)

	return Updater.Series({
			Updater.Ease(function(v)
				local pos = lume.lerp(start_pos, end_pos, v)
				self.pointer:SetPosition(pos:Get())
			end, 0, 1, duration, easing.inOutQuad),
	})
end

function DungeonLayoutMap:HideYouAreHere()
	for key,node in pairs(self.map_nodes) do
		node:SetCurrentLocation(false)
	end
end

function DungeonLayoutMap:Debug_TravelUsed()
	return self._debug_travel_used
end

function DungeonLayoutMap:DebugDraw_AddSection(ui, panel)
	DungeonLayoutMap._base.DebugDraw_AddSection(self, ui, panel)

	if not self.connectors then
		return
	end

	ui:Spacing()
	ui:Text("DungeonLayoutMap")

	ui:Indent() do
		if ui:CollapsingHeader("_PositionNodes") then
			self.dbg_filter = ui:_InputText("Line ID Filter", self.dbg_filter or "")
			for line_id, node_connection in pairs(self.connectors) do
				if self.dbg_filter:len() == 0 or node_connection._widgetname:find(self.dbg_filter) then
					local start_node = node_connection.start_node
					local end_node = node_connection.end_node
					local start_pos = start_node:GetPositionAsVec2()
					local end_pos = end_node:GetPositionAsVec2()
					local angle = end_pos:AngleTo_Degrees(start_pos)
					ui:Text(node_connection._widgetname)
					ui:DragVec2f(start_node._widgetname, start_pos)
					ui:DragVec2f(end_node._widgetname, end_pos)
					ui:Value("AngleTo_Degrees ".. node_connection._widgetname, angle)
					ui:Value("AngleBetween_Degrees ".. node_connection._widgetname, end_pos:AngleBetween_Degrees(start_pos))
					ui:Spacing(20)
					_position_connector(node_connection, start_node, end_node)
				end
			end
		end
	end
	ui:Unindent()
end

return DungeonLayoutMap
