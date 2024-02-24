local BackgroundGradientPane = require "debug.inspectors.panes.backgroundgradient"
local DebugNodes = require "dbui.debug_nodes"
local GroundTiles = require "defs.groundtiles"
local MapShadowPane = require "debug.inspectors.panes.mapshadow"
local PrefabEditorBase = require "debug.inspectors.prefabeditorbase"
local RoomLoader = require "roomloader"
local WorldPhysicsPane = require "debug.inspectors.panes.worldphysics"
local bossdef = require "defs.monsters.bossdata"
local filepath = require "util.filepath"
local lume = require "util.lume"
local mapgen = require "defs.mapgen"
local prefabutil = require "prefabs.prefabutil"
require "debug.inspectors.lighting"
require "debug.inspectors.shadows"
require "debug.inspectors.sky"
require "debug.inspectors.water"
require "prefabs.world_autogen" --Make sure our util functions are loaded


local _static = PrefabEditorBase.MakeStaticData("world_autogen_data")

local ALL_ROOMTYPES = "All"

local popup_id = "Cannot load level"

local WorldEditor = Class(PrefabEditorBase, function(self)
	PrefabEditorBase._ctor(self, _static)

	self.name = "World Editor"
	self.prefab_label = "World"
	self.test_label = "Load World"

	self.dungeon_progress = 0

	self.curve_key = PROGRESS_ENDPOINTS[1]

	self.roomtypes = mapgen.roomtypes.RoomType:Ordered()
	table.sort(self.roomtypes)
	table.insert(self.roomtypes, 1, ALL_ROOMTYPES)

	if TheWorld ~= nil then
		self.prefabname = TheWorld.prefab

		local params = _static.data[self.prefabname]
		if params ~= nil and params.group ~= nil then
			self.groupfilter = params.group
		end
	end

	self.physicsEditorPane = self.physicsEditorPane or WorldPhysicsPane("##Locked", WorldPhysicsPane.Constraint.s.ByBlockers)
	self.unlockedPhysicsEditorPane = self.unlockedPhysicsEditorPane or WorldPhysicsPane("##Unlocked", WorldPhysicsPane.Constraint.s.Unconstrained)
	self.mapshadowEditorPane = self.mapshadowEditorPane or MapShadowPane()
	self.backgroundgradientEditorPane = self.backgroundgradientEditorPane or BackgroundGradientPane()

end)

WorldEditor.PANEL_WIDTH = 600
WorldEditor.PANEL_HEIGHT = 600

-- Called from debug_panel when the window is closed
function WorldEditor:OnDeactivate()
	self.physicsEditorPane:StopEditing()
	self.unlockedPhysicsEditorPane:StopEditing()
end

function WorldEditor:Revert()
	WorldEditor._base.Revert(self)

	if TheWorld ~= nil then
		local params = _static.data[TheWorld.prefab]
		if params ~= nil then
			self.physicsEditorPane:StopEditing()
			self.unlockedPhysicsEditorPane:StopEditing()
			local loopdata = params.worldCollision ~= nil and params.worldCollision.loop or nil
			if loopdata ~= nil then
				TheWorld.Map:SetCollisionEdges(loopdata, true)
			else
				GenerateCollisionEdge(TheWorld)
			end

			self:Refresh(TheWorld.prefab, params)
		end
	end
end

function WorldEditor:Test(prefab, params)
	if self:IsDirty() then
		self.popup = popup_id
	else
		self:ReopenNodeAfterReset()
		RoomLoader.DevLoadLevel(prefab)
	end
end

function WorldEditor:OnLayoutChanged(prefab, params)
	if PrefabExists(prefab) then
		local assets, deps = {}, {}
		CollectDepsForLayout(assets, deps, params.layout)
		for i = 1, #assets do
			self:AppendPrefabAsset(prefab, assets[i])
		end
		for i = 1, #deps do
			self:AppendPrefabDep(prefab, deps[i])
		end
	end
end

function WorldEditor:OnColorCubeChanged(prefab, params)
	if PrefabExists(prefab) then
		local assets = {}
		CollectAssetsForColorCube(assets, params.colorcube.entrance)
		CollectAssetsForColorCube(assets, params.colorcube.boss)
		for i = 1, #assets do
			self:AppendPrefabAsset(prefab, assets[i])
		end
	end
end

function WorldEditor:OnRampTextureChanged(prefab, params)
	if PrefabExists(prefab) then
		local assets = {}
		CollectAssetsForCliffRamp(assets, params.clifframp)
		for i = 1, #assets do
			self:AppendPrefabAsset(prefab, assets[i])
		end
	end
end

function WorldEditor:OnWaterRampTextureChanged(prefab, params)
	if PrefabExists(prefab) then
		local assets = {}
		CollectAssetsForWaterRamp(assets, params.water_settings and params.water_settings.ramp)
		for i = 1, #assets do
			self:AppendPrefabAsset(prefab, assets[i])
		end
	end
end

function WorldEditor:OnSkirtTextureChanged(prefab, params)
	if PrefabExists(prefab) then
		local assets = {}
		CollectAssetsForCliffSkirt(assets, params.cliffskirt)
		for i = 1, #assets do
			self:AppendPrefabAsset(prefab, assets[i])
		end
	end
end

function WorldEditor:OnShadowTilesChanged(prefab, params)
	if PrefabExists(prefab) then
		local assets = {}
		GroundTiles.CollectAssetsForTileGroup(assets, params.shadow_tilegroup or "forest_shadow")
		for i = 1, #assets do
			self:AppendPrefabAsset(prefab, assets[i])
		end
	end
end

function WorldEditor:RefreshWater(_prefab_name, water)
	if not TheWorld then
		return
	end
	if TheWorld.prefab ~= self.prefabname then
		return
	end
	water = water or (TheSceneGen and TheSceneGen.components.scenegen.water)
	if water then
		ApplyWater(water, self.dungeon_progress)
	end
end

function WorldEditor:RefreshLighting(lighting)
	if not TheWorld then
		return
	end
	if TheWorld.prefab ~= self.prefabname then
		return
	end
	lighting = lighting or (TheSceneGen and TheSceneGen.components.scenegen.lighting)
	if lighting then
		ApplyLighting(lighting, self.dungeon_progress)
	end
end

function WorldEditor:RefreshSky(sky)
	if not TheWorld then
		return
	end
	if TheWorld.prefab ~= self.prefabname then
		return
	end
	sky = sky or (TheSceneGen and TheSceneGen.components.scenegen.sky)
	if sky then
		ApplySky(sky, self.dungeon_progress)
	end
end

function WorldEditor:Refresh(prefab, params)
	if not TheWorld then
		return
	end
	if TheWorld.prefab ~= prefab then
		return
	end

	if TheWorld.shadow_layers then
		-- release existing renderlayers
		TheWorld:Debug_RemoveShadowLayer()
	end

	local lighting = params.scene_gen_overrides
		and params.scene_gen_overrides.lighting
		or (TheSceneGen and TheSceneGen.lighting)
	self:RefreshLighting(lighting)

	local sky = params.scene_gen_overrides
		and params.scene_gen_overrides.sky
		or (TheSceneGen and TheSceneGen.sky)
	self:RefreshSky(sky)

	ApplyShadows(params)

	local cameralimits = TheWorld.components.cameralimits
	if cameralimits then
		if params.cameralimits ~= nil then
			cameralimits:SetXRange(params.cameralimits.xmin, params.cameralimits.xmax, params.cameralimits.xpadding)
			cameralimits:SetZRange(params.cameralimits.zmin, params.cameralimits.zmax, params.cameralimits.zpadding)
		else
			cameralimits:SetToDefaultLimits()
		end
	end
	TheWorld.Map:Rebuild()

	local water = params.scene_gen_overrides
		and params.scene_gen_overrides.water
		or (TheSceneGen and TheSceneGen.water)
	self:RefreshWater(water)
end

function WorldEditor:GetLayoutList()
	local files = { "" }
	filepath.list_files("scripts/map/layouts/", "*.lua", true, files)
	for i = 2, #files do
		files[i] = string.match(files[i], "^scripts/map/layouts/(.+)[.]lua$")
	end
	return files
end

function WorldEditor:GatherErrors()
	local bad_items = {}
	for name,params in pairs(self.static.data) do
		if name:find("_arena_") then
			if not params.worldCollision then
				bad_items[name] = ("Missing Locked world physics."):format(name)
			end
			if not params.worldCollisionUnlocked then
				bad_items[name] = ("Missing Unlocked world physics."):format(name)
			end
		end
	end
	return bad_items
end

function WorldEditor:SceneGenOverrideUi(ui, params, override, OverrideUi, RecoverOverrides, Refresh)
	local previous_override = deepcopy(params.scene_gen_overrides[override])
	local override_enabled = params.scene_gen_overrides[override] ~= nil
	local changed
	changed, override_enabled = ui:Checkbox("##"..override, override_enabled)
	ui:SetTooltipIfHovered("Override SceneGen "..override)
	if not override_enabled then
		params.scene_gen_overrides[override] = nil
		ui:PushDisabledStyle()
	elseif not params.scene_gen_overrides[override] then
		params.scene_gen_overrides[override] = {}
		RecoverOverrides(params, params.scene_gen_overrides[override])
	end
	if changed then
		Refresh(params.scene_gen_overrides[override])
	end
	ui:SameLineWithSpace()
	OverrideUi(self, ui, params.scene_gen_overrides[override], override_enabled)
	if not override_enabled then
		ui:PopDisabledStyle()
	end
	if not deepcompare(previous_override, params.scene_gen_overrides[override]) then
		self:SetDirty()
	end
end

function WorldEditor:AddEditableOptions(ui, params)
	if self.popup then
		ui:OpenPopup(self.popup)
		self.popup = nil
	end

	self:PushRedWindowColor(ui)
	if ui:BeginPopupModal(popup_id, false, ui.WindowFlags.AlwaysAutoResize) then
		ui:Text("Save or discard changes before testing!")
		ui:Spacing()
		ui:Dummy(65, 0) ui:SameLine()
		self:PushRedButtonColor(ui)
		if ui:Button("        Cancel        ") then
			ui:CloseCurrentPopup()
		end
		self:PopButtonColor(ui)
		ui:EndPopup()
	end
	self:PopWindowColor(ui)

	if self.prefabname
		and self.prefabname:endswith("_nesw")
		and ui:Button("Copy nesw to other directions")
	then
		local other_dirs = {
			"_esw",
			"_ew",
			"_new",
			"_nsw",
			"_nw",
			"_sw",
		}
		for _,dir in ipairs(other_dirs) do
			local new_world = deepcopy(params)
			local new_name = self.prefabname:gsub("_nesw$", dir)
			if not self.static.data[new_name] then
				new_world.layout = new_world.layout:gsub("_nesw$", dir)
				for _,scene in ipairs(new_world.scenes or {}) do
					scene.name = scene.name:gsub("_nesw$", dir)
				end
				self.static.data[new_name] = new_world
			end
		end
		self:SetDirty()
	end
	ui:SetTooltipIfHovered({
		"Clone this world for all directions and adjust 'nesw' to the new direction in scenes and layouts.",
		"You should have already created and exported tile layouts for the new directions.",
		"Will not clobber existing worlds. Delete them if you want them replaced.",
	})

	local roomtypelist =
	{
		"Dungeon",
		"Town",
		"Debug",
	}
	local roomtypeidx = params.town and 2 or params.is_debug and 3 or 1
	local newroomtypeidx = ui:_Combo("##roomtype", roomtypeidx, roomtypelist)
	if newroomtypeidx ~= roomtypeidx then
		local newtown = newroomtypeidx == 2 or nil
		if params.town ~= newtown then
			params.town = newtown
			self:SetDirty()
		end
		local newdebug = newroomtypeidx == 3 or nil
		if params.is_debug ~= newdebug then
			params.is_debug = newdebug
			self:SetDirty()
		end
	end

	if not params.town then
		local changed , v = ui:SliderFloat("Dungeon Progress", self.dungeon_progress, 0, 1)
		if changed then
			self.dungeon_progress = v
			self:Refresh(self.prefabname, params)
		end
	end

	self:AddSectionEnder(ui)

	if ui:CollapsingHeader("Scenes", ui.TreeNodeFlags.DefaultOpen) then
		self:AddSectionStarter(ui)

		params.scenes = params.scenes or { {
				name = self.prefabname,
		} }
		local function draw_fn(ui_, i, id, scene)
			if i == 1 then
				ui:PushDisabledStyle()
				scene = deepcopy(scene) -- ignore changes
			end

			local force_rename = false

			local dirty = false
			ui:SetNextColumnItemToFillWidth()
			local changed, newscene = ui:InputText(id .."scene", scene.name, ui.InputTextFlags.CharsNoBlank)
			if changed then
				scene.name = newscene
				dirty = true
			end
			ui:NextColumn()

			ui:SetNextColumnItemToFillWidth()
			local newval
			changed, newval = ui:ComboAsString(id .."progress", scene.progress, prefabutil.ProgressSegments:Ordered(), true)
			if changed then
				scene.progress = newval
				force_rename = true
				dirty = true
			end
			ui:NextColumn()

			ui:SetNextColumnItemToFillWidth()
			local bosses = lume.keys(bossdef.boss)
			table.sort(bosses)
			table.insert(bosses, 1, "Any")
			changed, newval = ui:ComboAsString(id .."required_boss", scene.required_boss, bosses, true)
			if changed then
				scene.required_boss = newval
				force_rename = true
				dirty = true
			end
			ui:NextColumn()

			ui:SetNextColumnItemToFillWidth()
			changed, newval = ui:ComboAsString(id .."roomtype", scene.roomtype, self.roomtypes, true)
			if changed then
				assert(newval ~= ALL_ROOMTYPES, "Should have converted to nil.")
				scene.roomtype = newval
				force_rename = true
				dirty = true
			end

			if force_rename
				or (scene.name and scene.name:len() == 0)
			then
				-- startingforest_hype_nearboss_treek_ew
				local prefix = self.prefabname:gsub("_.*$", "")
				local exits = self.prefabname:gsub(".*_", "")

				scene.name = prefix
				if scene.roomtype then
					scene.name = scene.name .."_".. scene.roomtype
				end
				if scene.progress then
					scene.name = scene.name .."_".. scene.progress
				end
				if scene.required_boss then
					scene.name = scene.name .."_".. scene.required_boss
				end
				scene.name = scene.name .."_".. exits
			end

			if i == 1 then
				ui:PopDisabledStyle()
				return false
			end
			return dirty, scene
		end
		local function create_fn()
			return {
				name = "",
			}
		end
		local columns = {
			{
				name = "Scene",
				width_pct = 0.49,
			},
			{
				name = "Progress",
				width_pct = 0.16,
			},
			{
				name = "Boss",
				width_pct = 0.15,
			},
			{
				name = "RoomType",
				width_pct = 0.20,
			},
		}
		local result = ui:MultiColumnList("##scene", params.scenes, columns, draw_fn, create_fn)
		if result ~= ui.MultiColumnListResult.id.None then
			self:SetDirty()
		end

		-- Don't need to track the one named after the world.
		if #params.scenes <= 1 then
			params.scenes = nil
		end

		self:AddSectionEnder(ui)
	end

	if ui:CollapsingHeader("Ground", ui.TreeNodeFlags.DefaultOpen) then
		self:AddSectionStarter(ui)

		if ui:TreeNode("Layout", ui.TreeNodeFlags.DefaultOpen) then
			--Layout File
			local layoutlist = self:GetLayoutList()
			local layoutidx = nil
			for i = 1, #layoutlist do
				if params.layout == layoutlist[i] then
					layoutidx = i
					break
				end
			end
			local missing = layoutidx == nil and params.layout ~= nil
			if missing then
				layoutidx = 1
				layoutlist[1] = params.layout.." (missing)"
				self:PushRedButtonColor(ui)
				self:PushRedFrameColor(ui)
			end
			local newlayoutidx = ui:_Combo("##layout", layoutidx or 1, layoutlist)
			if newlayoutidx ~= layoutidx then
				local newlayout = layoutlist[newlayoutidx]
				if string.len(newlayout) == 0 then
					newlayout = nil
				end
				if params.layout ~= newlayout then
					params.layout = newlayout
					self:SetDirty()
					self:OnLayoutChanged(self.prefabname, params)
				end
			end
			if missing then
				self:PopFrameColor(ui)
				self:PopButtonColor(ui)
			end

			self:AddTreeNodeEnder(ui)
		end

		self:AddSectionEnder(ui)
	end

	params.scene_gen_overrides = params.scene_gen_overrides or {}
	self:SceneGenOverrideUi(
		ui,
		params,
		"lighting",
		LightingUi,
		function(from, to)
			CopyLightingProperties(from, to)
			LoadLightingAssets(self, to)
		end,
		function(lighting) self:RefreshLighting(lighting) end
	)
	self:SceneGenOverrideUi(
		ui,
		params,
		"sky",
		SkyUi,
		function(from, to)
			CopySkyProperties(from, to)
			LoadSkyAssets(self, to)
		end,
		function(sky) self:RefreshSky(sky) end
	)
	ShadowsUi(self, ui, params, true)

	if ui:CollapsingHeader("Camera") then
		self:AddSectionStarter(ui)

		if ui:TreeNode("Limits", ui.TreeNodeFlags.DefaultOpen) then
			local _, newauto = ui:Checkbox("Auto##CameraLimits", params.cameralimits == nil)
			if newauto ~= (params.cameralimits == nil) then
				if newauto then
					params.cameralimits = nil
				else
					params.cameralimits = {}
				end
				self:SetDirty()
				self:Refresh(self.prefabname, params)
			end

			if params.cameralimits ~= nil then
				ui:Spacing()

				local xmin = params.cameralimits.xmin
				local xmax = params.cameralimits.xmax
				local zmin = params.cameralimits.zmin
				local zmax = params.cameralimits.zmax
				local xpadding = params.cameralimits.xpadding
				local zpadding = params.cameralimits.zpadding

				local w = ui:GetColumnWidth()
				local w2 = math.min(120, w * .3)
				ui:Columns(5, nil, false)
				ui:SetColumnOffset(1, 20)
				ui:SetColumnOffset(2, 20 + w2)
				ui:SetColumnOffset(3, 20 + w2 * 2)
				ui:SetColumnOffset(4, 20 + w2 * 3)

				ui:NextColumn()
				ui:NextColumn()
				ui:PushItemWidth(60)
				local _, newzmax = ui:InputText("+Z", tostring(zmax or ""), imgui.InputTextFlags.CharsDecimal)
				if newzmax ~= nil then
					newzmax = tonumber(newzmax)
					if zmax ~= newzmax then
						if params.cameralimits == nil then
							params.cameralimits = { zmax = newzmax }
						else
							params.cameralimits.zmax = newzmax
						end
						self:SetDirty()
						self:Refresh(self.prefabname, params)
					end
				end
				ui:PopItemWidth()
				ui:NextColumn()
				ui:NextColumn()
				ui:NextColumn()

				ui:NextColumn()
				ui:PushItemWidth(60)
				local _, newxmin = ui:InputText("-X", tostring(xmin or ""), imgui.InputTextFlags.CharsDecimal)
				if newxmin ~= nil then
					newxmin = tonumber(newxmin)
					if xmin ~= newxmin then
						if params.cameralimits == nil then
							params.cameralimits = { xmin = newxmin }
						else
							params.cameralimits.xmin = newxmin
						end
						self:SetDirty()
						self:Refresh(self.prefabname, params)
					end
				end
				ui:PopItemWidth()
				ui:NextColumn()
				ui:NextColumn()
				ui:PushItemWidth(60)
				local _, newxmax = ui:InputText("+X", tostring(xmax or ""), imgui.InputTextFlags.CharsDecimal)
				if newxmax ~= nil then
					newxmax = tonumber(newxmax)
					if xmax ~= newxmax then
						if params.cameralimits == nil then
							params.cameralimits = { xmax = newxmax }
						else
							params.cameralimits.xmax = newxmax
						end
						self:SetDirty()
						self:Refresh(self.prefabname, params)
					end
				end
				ui:PopItemWidth()
				ui:NextColumn()
				ui:NextColumn()

				ui:NextColumn()
				ui:NextColumn()
				ui:PushItemWidth(60)
				local _, newzmin = ui:InputText("-Z", tostring(zmin or ""), imgui.InputTextFlags.CharsDecimal)
				if newzmin ~= nil then
					newzmin = tonumber(newzmin)
					if zmin ~= newzmin then
						if params.cameralimits == nil then
							params.cameralimits = { zmin = newzmin }
						else
							params.cameralimits.zmin = newzmin
						end
						self:SetDirty()
						self:Refresh(self.prefabname, params)
					end
				end
				ui:PopItemWidth()

				ui:Columns()
				ui:Spacing()
				ui:Spacing()

				ui:PushItemWidth(60)
				local _, newxpadding = ui:InputText("X Padding", tostring(xpadding or ""), imgui.InputTextFlags.CharsDecimal)
				if newxpadding ~= nil then
					newxpadding = tonumber(newxpadding)
					if xpadding ~= newxpadding then
						if params.cameralimits == nil then
							params.cameralimits = { xpadding = newxpadding }
						else
							params.cameralimits.xpadding = newxpadding
						end
						self:SetDirty()
						self:Refresh(self.prefabname, params)
					end
				end
				ui:PopItemWidth()

				ui:PushItemWidth(60)
				local _, newzpadding = ui:InputText("Z Padding", tostring(zpadding or ""), imgui.InputTextFlags.CharsDecimal)
				if newzpadding ~= nil then
					newzpadding = tonumber(newzpadding)
					if zpadding ~= newzpadding then
						if params.cameralimits == nil then
							params.cameralimits = { zpadding = newzpadding }
						else
							params.cameralimits.zpadding = newzpadding
						end
						self:SetDirty()
						self:Refresh(self.prefabname, params)
					end
				end
				ui:PopItemWidth()
			end

			self:AddTreeNodeEnder(ui)
		end
	end

	if ui:CollapsingHeader("Physics") then
		self:AddSectionStarter(ui)

		local function WorldPhysicsUI(world_collision, editor)
			local pointdata = world_collision ~= nil and world_collision.points or nil
			local newpointdata = editor:OnRender(self.prefabname, pointdata)

			if pointdata == newpointdata then
				return world_collision
			end
			if not (pointdata == nil or newpointdata == nil or not deepcompare(pointdata, newpointdata)) then
				return world_collision
			end

			if newpointdata == nil then
				world_collision.points = nil
				if next(world_collision) == nil then
					world_collision = nil
				end
			elseif world_collision == nil then
				world_collision = { points = deepcopy(newpointdata) }
			else
				world_collision.points = deepcopy(newpointdata)
			end
			self:SetDirty()

			return world_collision
		end

		if ui:TreeNode("World Physics (Locked)", ui.TreeNodeFlags.DefaultOpen) then
			params.worldCollision = WorldPhysicsUI(params.worldCollision, self.physicsEditorPane)
			if params.worldCollisionUnlocked and ui:Button("Initialize from Unlocked") then
				params.worldCollision = deepcopy(params.worldCollisionUnlocked)
			end
			self:AddTreeNodeEnder(ui)
		end

		if ui:TreeNode("World Physics (Unlocked)", ui.TreeNodeFlags.DefaultOpen) then
			params.worldCollisionUnlocked = WorldPhysicsUI(params.worldCollisionUnlocked, self.unlockedPhysicsEditorPane)
			if params.worldCollision and ui:Button("Initialize from Locked") then
				params.worldCollisionUnlocked = deepcopy(params.worldCollision)
			end
			self:AddTreeNodeEnder(ui)
		end

		self:AddSectionEnder(ui)
	end

	self:SceneGenOverrideUi(
		ui,
		params,
		"water",
		WaterUi,
		function(from, to)
			CopyWaterProperties(from, to)
			LoadWaterAssets(self, to)
		end,
		function(water) self:RefreshWater(water) end
	)
end

function WorldEditor:CanEditSkyGradient(ui)
	if not TheWorld or TheWorld.prefab ~= self.prefabname then
		ui:Text("** Sky Gradient can only be edited when inside the level being edited **")
		return false
	end
	return true
end


-- Don't submit this code uncommented. Don't want the button unless a coder is
-- using it.
--~ function WorldEditor:BatchModify(prefabs)
--~ 	local small_6x5 = {
--~ 		startingforest_small_esw = true,
--~ 		startingforest_small_new = true,
--~ 		startingforest_small_nsw = true,
--~ 	}
--~ 	local small_8x4 = {
--~ 		startingforest_small_nesw = true,
--~ 		startingforest_small_ew = true,
--~ 		startingforest_small_nw = true,
--~ 		startingforest_small_sw = true,
--~ 	}
--~ 	local filtered_keys = lume.filter(lume.keys(self.static.data), function(v)
--~ 		--~ return v:find('startingforest_mat', nil, true) == 1
--~ 		return small_8x4[v] or small_6x5[v]
--~ 	end)
--~ 	--~ self:CopyParamsToPrefabs('startingforest_small_esw', filtered_keys, {'rimlightcolor', 'backgroundGradientCurve', 'colorcube', })


--~ 	local boss = prefabs.startingforest_boss_w.colorcube
--~ 	for key,world in pairs(prefabs) do
--~ 		if world.colorcube then
--~ 			world.colorcube = {
--~ 				entrance = world.colorcube,
--~ 				boss = deepcopy(boss),
--~ 			}
--~ 			if world.town then
--~ 				world.colorcube.boss = nil
--~ 			end
--~ 		end
--~ 	end

--~ 	--~ for key,world in pairs(prefabs) do
--~ 	--~ 	if key:find("_small_")
--~ 	--~ 		and not kstring.endswith(key, "_esw")
--~ 	--~ 		and not kstring.endswith(key, "_ew")
--~ 	--~ 	then
--~ 	--~ 		world.worldCollision = nil
--~ 	--~ 		print(key)
--~ 	--~ 	end
--~ 	--~ end

--~ 	self:SetDirty()
--~ end


DebugNodes.WorldEditor = WorldEditor

return WorldEditor
