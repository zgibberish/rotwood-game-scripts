local ArenaLoader = require "debug.inspectors.arenaloader"
local DataDumper = require "util.datadumper"
local DebugNodes = require "dbui.debug_nodes"
local DebugSettings = require "debug.inspectors.debugsettings"
local EditorBase = require "debug.inspectors.editorbase"
local Hsb = "util.hsb"
local PropAutogenData = require "prefabs.prop_autogen_data"
local PropEditor = require "debug.inspectors.propeditor"
local RoomLoader = require "roomloader"
local WorldEditor = require "debug.inspectors.worldeditor"
local iterator = require "util.iterator"
local lume = require "util.lume"
local scenegenutil = require "prefabs.scenegenutil"
require "consolecommands"


local _world_static = WorldEditor.MakeStaticData("world_autogen_data")
local _prop_static = PropEditor.MakeStaticData("prop_autogen_data")

-- Convenience class to filter the prefab list with a certain name substring
-- It can be made fancier with a selection predicate
local NonPropPrefabSelector = Class(function(self, friendlyName, prefabPrefix)
	self.name = friendlyName
	self.prefabPrefix = prefabPrefix
	self.selectedPrefab = nil
	self:CreateCache()
end)

-- requires global Prefabs
function NonPropPrefabSelector:CreateCache()
	self.prefabList = {}
	table.insert(self.prefabList, "")

	for k, v in iterator.sorted_pairs(Prefabs) do
		if k:find(self.prefabPrefix) then
			table.insert(self.prefabList, k)
		end
	end
	table.sort(self.prefabList)
end

function NonPropPrefabSelector:RenderPrefabSelection(ui)
	local prefabIdx = table.arrayfind(self.prefabList, self.selectedPrefab) or 1
	local newPrefabIdx = ui:_Combo(self.name .. "##NonPropPrefabSelector", prefabIdx, self.prefabList)
	if newPrefabIdx ~= prefabIdx then
		self.selectedPrefab = self.prefabList[newPrefabIdx]
	end
end

function NonPropPrefabSelector:_RenderAndReturnSelection(ui)
	self:RenderPrefabSelection(ui)
	return self.selectedPrefab
end

function NonPropPrefabSelector:ClearSelection()
	self.selectedPrefab = nil
end

local ParticleSystemSelector = Class(function(self, friendlyName, prefabPrefix)
	self.name = friendlyName
	self.prefabPrefix = prefabPrefix
	self.selectedPrefab = nil
end)

function ParticleSystemSelector:GetGroupList()
	local groupmap = { [""] = true }
	local ParticlesAutogenData = require "prefabs.particles_autogen_data"
	for _, params in pairs(ParticlesAutogenData) do
		if not params.mode_2d then
			if params.group ~= nil then
				groupmap[params.group] = true
			end
		end
	end
	local grouplist = {}
	for groupname in pairs(groupmap) do
		grouplist[#grouplist + 1] = groupname
	end
	table.sort(grouplist)
	groupmap[""] = nil
	return grouplist, groupmap
end

function ParticleSystemSelector:GetParticlesList(groupfilter)
	local param_list = { "" }
	local ParticlesAutogenData = require "prefabs.particles_autogen_data"
	for name, params in pairs(ParticlesAutogenData) do
		if not params.mode_2d then
			if string.len(groupfilter) == 0 or params.group == groupfilter then
				param_list[#param_list + 1] = name
			end
		end
	end
	table.sort(param_list)
	return param_list
end

function ParticleSystemSelector:RenderPrefabSelection(ui)
	--Group filter selection
	local grouplist, groupmap = self:GetGroupList()
	local groupidx = table.arrayfind(grouplist, self.groupfilter)
	local newgroupidx = ui:_Combo("Group Filter", groupidx or 1, grouplist)
	if newgroupidx ~= groupidx then
		self.groupfilter = grouplist[newgroupidx] or ""
	end


	-- particle system selection
	local param_list = self:GetParticlesList(self.groupfilter)
	local idx = table.arrayfind(param_list, self.selectedPrefab)

	local new_idx = ui:_Combo("Particle System", idx or 1, param_list)
	if new_idx ~= idx then
		local new_param_id = param_list[new_idx]
		if new_param_id ~= self.selectedPrefab then
			self.selectedPrefab = new_param_id
		end
	end
end

function ParticleSystemSelector:_RenderAndReturnSelection(ui)
	self:RenderPrefabSelection(ui)
	return self.selectedPrefab
end

function ParticleSystemSelector:ClearSelection()
	self.selectedPrefab = nil
end



local function SceneToSaveFile(scene_name)
	return scene_name.."_propdata"
end

local function SceneToModulePath(scene_name)
	-- Use / because we'll also use as a file path.
	return "map/propdata/".. SceneToSaveFile(scene_name)
end

local function WriteSceneToDisk(scene_name, data)
	local require_path = SceneToModulePath(scene_name)
	local file_path = "scripts/"..require_path..".lua"
	TheSim:DevSaveDataFile(file_path, DataDumper(data, nil, false))
end





--EditableEditor doesn't need it's own static data (uses propmanager instead).
local _static = {}

local EditableEditor = Class(EditorBase, function(self)
	EditorBase._ctor(self, _static)

	self.name = "Level Layout Editor"

	if not TheWorld.components.propmanager then
		TheWorld:AddComponent("propmanager")
	end

	local levelname = TheWorld.prefab
	self.levelparams = _world_static.data[levelname]
	self.levelgroupfilter = self.levelparams ~= nil and self.levelparams.group or ""
	self.scenename = TheWorld.scenelist[1]

	self.edit_options = DebugSettings("editableeditor.edit_options")
		:Option("layer", 1)
		:Option("previews", false)
		:Option("clone_inst_params", false)
		:Option("draw_grid", false)
	self.layer_to_fn = {
		All = self.EnableLayer_All,
		Decor = self.EnableLayer_Decor,
		Lighting = self.EnableLayer_Lighting,
		Grid = self.EnableLayer_Grid,
		Particles = self.EnableLayer_Particles,
	}
	self.layer_list = {
		"All",
		"Decor",
		"Lighting",
		"Grid",
		"Particles",
	}

	self.arena_loader = ArenaLoader("editableeditor.test_options.")

	-- Stomp the persistent levelname.
	self.arena_loader.levelname = levelname

	self.entrances = TheDungeon:GetDungeonMap():GetCurrentWorldEntrances()

	self.showEditableEditorOnDirty = Profile:GetValue("showEditableEditorOnDirty")

	-- For selection of prop prefabs UI
	-- self.propEditor.groupfilter, self.propEditor.prefabname are assigned to via
	-- PrefabEditorBase:RenderGroupSelection() and PrefabEditorBase:RenderPrefabSelection()
	self.propEditor = PropEditor(_prop_static)
	self.propEditor._RenderAndReturnSelection = function(_, ui)
		self.propEditor:RenderGroupSelection(ui)
		self.propEditor:RenderPrefabSelection(ui)
		return self.propEditor.prefabname
	end
	self.propEditor.ClearSelection = function(_)
		self.propEditor.prefabname = nil
		self.propEditor:PrefabDropdownChanged(nil)
	end

	self.
	prefabModeList = {"Prop", "Lightspot", "Particle System"}
	self.lightspotSelector = NonPropPrefabSelector("Light Cookies", "lightspot_")
	self.particleSystemSelector = ParticleSystemSelector("Particle Systems")
	self.decorAssemblySelector = NonPropPrefabSelector("Decor Assemblies", "decorassembly_")

	self.renderPrefabSelector = {
		Prop = self.propEditor,
		Lightspot = self.lightspotSelector,
		["Particle System"] = self.particleSystemSelector
	}

	self.prefabMode = self.prefabModeList[1]
end)

function EditableEditor.CanBeOpened()
	return (TheWorld ~= nil
		and TheDungeon:GetDungeonMap())
end

function EditableEditor.GetCurrentSaveFile()
	local scene_name = TheWorld.scenelist[1]
	local panel = TheFrontEnd:FindOpenDebugPanel(EditableEditor)
	if panel then
		local editor = panel:GetNode()
		scene_name = editor.scenename
	end
	return SceneToSaveFile(scene_name)
end

function EditableEditor:PostFindOrCreateEditor(prefab_to_select)
	if not prefab_to_select then
		return
	end
	self.propEditor.prefabname = prefab_to_select
	self.propEditor:PrefabDropdownChanged(prefab_to_select)
end


function EditableEditor:OnDebugResetGame()
	InstanceParams.dbg = InstanceParams.dbg or {}
	InstanceParams.dbg.target_scene = TheWorld.scenelist[1]
	InstanceParams.dbg.want_single_scene = #TheWorld.scenelist == 1
end


function EditableEditor:IsEditMode()
	return TheWorld ~= nil and TheDungeon:GetDungeonMap():IsDebugMap()
end

function EditableEditor.HasUnsavedChanges()
	return (TheWorld
		and TheDungeon:GetDungeonMap():IsDebugMap()
		and TheWorld.components.propmanager
		and TheWorld.components.propmanager:IsDirty())
end

function EditableEditor.IsLevelPristine()
	return not EditableEditor.HasUnsavedChanges()
end

EditableEditor.PANEL_WIDTH = 650
EditableEditor.PANEL_HEIGHT = 600

function EditableEditor:OnEntityChanged(oldent, newent)
	-- Listen for the 'propchanged' event in prop.lua in order to set the dirty flag for this editor
	if oldent then
		-- TODO(dbriscoe): How does this work? Don't we need to save a handle to the function?
		oldent:RemoveEventCallback("propchanged", function() self:SetDirty() end)
	end

	if newent then
		newent:ListenForEvent("propchanged", function() self:SetDirty() end)
	end
end

function EditableEditor:OnActivate()
	self:ApplySelectionLayer(self.edit_options.layer)
	self:ApplyPreviews(self.edit_options.previews)
end

function EditableEditor:OnDeactivate()
	-- Only change selection layer when the editor is open to avoid "why can't
	-- I select" confusion.
	self:ApplySelectionLayer(1) -- all
	self:ApplyPreviews(false)
end

function EditableEditor:SetDirty()
	--overridden, using propmanager so don't do anything here
end

function EditableEditor:IsDirty()
	return (self:IsEditMode()
		and TheWorld.components.propmanager
		and TheWorld.components.propmanager:IsDirty())
end

function EditableEditor:Save()
	TheWorld.components.propmanager:SaveAllProps()
end

function EditableEditor:LoadRoom(room)
	-- Use the SceneGen specified by the ArenaLoader. This sets the tile group, among other things.
	local scene_gen = scenegenutil.FindSceneGenForLocation(self.arena_loader.location)
	d_loadroom(room, nil, scene_gen)
end

function EditableEditor:Revert()
	self:ReopenNodeAfterReset()
	self:LoadRoom(TheWorld.prefab)
end

function EditableEditor:PlacePrefab(prefab, ref_ent, dest_pos)
	-- Prefab might not be in static data if it's a code prefab.
	local params = self.propEditor.static.data[prefab] or {}
	return self:PlaceWithParams(prefab, params, ref_ent, dest_pos)
end

-- Check if spawnable and print if not.
function EditableEditor.QuerySpawnable(prefab)
	local is_world = _world_static.data[prefab] ~= nil
	if is_world then
		TheLog.ch.Editor:printf("Ignoring request to spawn a world (%s). It would crash the game.", prefab)
	end
	return not is_world
end

function EditableEditor:PlaceWithParams(prefab, params, ref_ent, dest_pos)
	if not EditableEditor.QuerySpawnable(prefab) then
		return
	end

	dest_pos = dest_pos or GetDebugPlayer():GetPosition()

	local ent
	if self.prefabMode == "Particle System" then
		ent = self.propEditor:SpawnParticles(prefab, params, dest_pos)
	else
		ent = self.propEditor:SpawnProp(prefab, params, dest_pos)
		if ent
			and self.edit_options.clone_inst_params
			and ref_ent
		then
			self.propEditor:CopyPropData(ref_ent, ent)
		end
	end
	self:SetDirty()
	return ent
end

function EditableEditor:GetLevelGroupList()
	local groupmap = { [""] = true }
	for _, params in pairs(_world_static.data) do
		if params.group ~= nil then
			groupmap[params.group] = true
		end
	end
	local grouplist = {}
	for groupname in pairs(groupmap) do
		grouplist[#grouplist + 1] = groupname
	end
	table.sort(grouplist)
	groupmap[""] = nil
	return grouplist, groupmap
end

function EditableEditor:GetLevelPrefabList(groupfilter)
	local prefablist = { "" }
	for name, params in pairs(_world_static.data) do
		if string.len(groupfilter) == 0 or params.group == groupfilter then
			prefablist[#prefablist + 1] = name
		end
	end
	table.sort(prefablist)
	return prefablist
end

function EditableEditor:RenderLevelGroupSelection(ui)
	--Group filter selection
	local grouplist, groupmap = self:GetLevelGroupList()
	local groupidx = table.arrayfind(grouplist, self.levelgroupfilter)
	local newgroupidx = ui:_Combo("Level Group Filter", groupidx or 1, grouplist)
	if newgroupidx ~= groupidx then
		self.levelgroupfilter = grouplist[newgroupidx] or ""
	end
end

function EditableEditor:RenderLevelPrefabSelection(ui)
	--Prefab selection
	local prefablist = self:GetLevelPrefabList(self.levelgroupfilter)
	local prefabidx = table.arrayfind(prefablist, self.arena_loader.levelname)
	local newprefabidx = ui:_Combo("##Level Select", prefabidx or 1, prefablist)
	if newprefabidx ~= prefabidx then
		self.arena_loader.levelname = prefablist[newprefabidx]
		self.levelparams = _world_static.data[self.arena_loader.levelname]
	end

	ui:SameLineWithSpace()

	if ui:Button("Load Level", nil, nil, self.levelparams == nil or self:IsDirty()) then
		self:ReopenNodeAfterReset()
		self:LoadRoom(self.arena_loader.levelname)
	end

	ui:SameLineWithSpace()

	local nextlevel = self.arena_loader.levelname
	if #prefablist > 2 then
		local nextidx = newprefabidx + 1
		if nextidx > #prefablist then
			nextidx = 2
		end
		nextlevel = prefablist[nextidx]
	end

	if ui:Button("Next Level   ".. ui.icon.playback_step_fwd, nil, nil, nextlevel == self.arena_loader.levelname or self:IsDirty()) then
		self:ReopenNodeAfterReset()
		self:LoadRoom(nextlevel)
	end
end

local function BuildWorldSceneList(world_prefab)
	local world = _world_static.data[world_prefab]
	if not world or not world.scenes then
		return { world_prefab }
	end
	return lume.map(world.scenes, function(scene)
		return scene.name
	end)
end

local function BuildCurrentSceneList()
	return BuildWorldSceneList(TheWorld.prefab)
end

local function GetAllScenes(groupfilter)
	local scenelist = { "" }
	for name, params in pairs(_world_static.data) do
		if groupfilter:len() == 0 or params.group == groupfilter then
			table.appendarrays(scenelist, BuildWorldSceneList(name))
		end
	end
	table.sort(scenelist)
	return scenelist
end

function EditableEditor:RenderLevelSceneSelection(ui)
	local scenelist = BuildCurrentSceneList()
	local prefabidx = table.arrayfind(scenelist, self.scenename) or 1
	local inspecting_other_level = self.arena_loader.levelname ~= TheWorld.prefab
	local to_pop = 0
	if inspecting_other_level then
		to_pop = ui:PushDisabledStyle()
	end
	local newprefabidx = ui:_Combo("##Scene Select", prefabidx, scenelist)
	ui:PopStyleColor(to_pop)
	if newprefabidx ~= prefabidx then
		self.scenename = scenelist[newprefabidx]
	end

	local is_dirty = self:IsDirty() or inspecting_other_level
	ui:SameLineWithSpace()
	local want_single = ui:Button("Load", nil, nil, is_dirty)
	ui:SetTooltipIfHovered("Load world with only this scene active.")
	ui:SameLineWithSpace()

	local nextscene = scenelist[prefabidx + 1]
	if ui:Button(ui.icon.playback_step_fwd, ui.icon.width, nil,
			not nextscene or nextscene == self.scenename or self:IsDirty())
	then
		self.scenename = nextscene
		want_single = true
	end
	if ui:IsItemHovered() then
		ui:SetTooltip("Load next scene in the list.")
	end
	ui:SameLineWithSpace()

	local want_context = ui:Button("In Context", nil, nil, is_dirty or #scenelist == 1)
	if ui:IsItemHovered() then
		ui:SetTooltipMultiline({
				"Load world with this scene and scenes marked 'All'.",
				"Matches how scene will appear in game.",
			})
	end
	if want_single or want_context then
		self:ReopenNodeAfterReset()
		InstanceParams.dbg.target_scene = self.scenename
		InstanceParams.dbg.want_single_scene = want_single
		self:LoadRoom(self.arena_loader.levelname)
	end

	ui:SameLineWithSpace()
	if ui:Button(ui.icon.list, ui.icon.width) then
		DebugNodes.WorldEditor:FindOrCreateEditor(self.arena_loader.levelname)
	end
	if ui:IsItemHovered() then
		ui:SetTooltip("Edit the list of scenes in WorldEditor.")
	end
end

local function GetAllPropEntities()
	return lume(Ents)
		:values() -- handle gaps
		:filter(function(ent)
			return ent.components.prop
		end)
		:result()
end

local function MatchesPrefabPattern(ent, pattern, invert_pattern)
	if not pattern then
		return true
	end
	local has_match = not not ent.prefab:find(pattern)
	local want_match = not invert_pattern
	return has_match == want_match
end

function EditableEditor:ShowLayer(prop_type, visible, prefab_pattern, invert_pattern)
	visible = not not visible
	for k,ent in pairs(GetAllPropEntities()) do
		local prop = ent.components.prop
		if prop:GetPropType() == prop_type then
			if visible
				and MatchesPrefabPattern(ent, prefab_pattern, invert_pattern)
			then
				ent:Show()
			else
				ent:Hide()
			end
			if prop_type == PropType.Lighting then
				ent.Light:Enable(visible)
			end
		end
	end
end

function EditableEditor:ShowExclusive(name, flag)
	if flag then
		for i,v in pairs(Ents) do
			if v.components.prop then
				if v.prefab ~= name then
					v:Hide()
				else
					v:Show()
				end
			end
		end
	else
		self.showDecor = self.showDecor == nil or self.showDecor
		self.showLighting = self.showLighting == nil or self.showLighting
		self.showGrid = self.showGrid == nil or self.showGrid
		self.showParticles = self.showParticles == nil or self.showParticles

		self:ShowLayer(PropType.Decor, self.showDecor, self.decorLayerPrefabFilter)
		self:ShowLayer(PropType.Decor, self.showDecor, self.decorLayerPrefabFilter)
		self:ShowLayer(PropType.Lighting, self.showLighting)
		self:ShowLayer(PropType.Grid, self.showGrid)
		self:ShowLayer(PropType.Particles, self.showParticles)
	end
end

local function run_script_fn(script, params, fn)
	if script then
		local require_succeeded, script = pcall(function()
			return require("prefabs.customscript.".. script)
		end)
		if not require_succeeded then
			TheLog.ch.Prop:print(script)
			return false
		end
		return fn(script, params)
	end
end


function EditableEditor:RenderPanel( ui, panel )
	assert(self.prefabname == nil, "To inject a default prefab, set EditableEditor.propEditor.prefabname")

	-- Check to see if the dirty state was changed
	-- (SetDirty actually updates checks and updates the dirty flag)
	self:SetDirty()

	if self:IsEditMode() then
		-- Option to have this panel pop up when the level is dirty
		local checkedChanged, showOnDirty = ui:Checkbox("Show Panel on Edit", self.showEditableEditorOnDirty)
		if checkedChanged then
			self.showEditableEditorOnDirty = showOnDirty
			Profile:SetValue("showEditableEditorOnDirty", self.showEditableEditorOnDirty)
			Profile:Save()
		end

		TheDebugSettings.showActiveAABB = ui:_Checkbox("Draw selection box (CTRL + B)", TheDebugSettings.showActiveAABB)

		self:AddSectionEnder(ui)
	end

	self:RenderLevelGroupSelection(ui)
	self:RenderLevelPrefabSelection(ui)
	self:RenderLevelSceneSelection(ui)

	ui:Spacing()

	if not self:IsEditMode() then
		ui:Text("Level is open for gameplay. To edit, click 'Load Level'")
		ui:Separator()
		ui:Spacing()
		if self.levelparams then
			self:DrawTestSection(ui, panel)
		end
		return
	end

	assert(TheWorld.components.propmanager, "Shouldn't be able to open EditableEditor unless IsEditMode or have a PropManager.")

	self:PushRedButtonColor(ui)

	if ui:Button("Save", nil, nil, not self:IsDirty()) then
		self:Save()
	end

	ui:SameLineWithSpace()

	if ui:Button("Revert", nil, nil, not self:IsDirty()) then
		self:Revert()
	end

	self:PopButtonColor(ui)

	ui:SameLineWithSpace()
	self:_DrawCopyPropPopup(ui, panel)
	ui:SameLineWithSpace()
	self:_DrawDeletePropPopup(ui, panel)

	if self.BatchModify then
		ui:SameLineWithSpace()
		if ui:Button("Batch Modify") then
			EditableEditor.RunOnAllPropData(self, self.BatchModify)
		end
	end

	if self.levelparams then
		self:DrawTestSection(ui, panel)
	end


	local prefabModeListIdx = table.arrayfind(self.prefabModeList, self.prefabMode) or 1
	local newPrefabModeListIdx = ui:_Combo("Prefab Type", prefabModeListIdx, self.prefabModeList)
	if newPrefabModeListIdx ~= prefabModeListIdx then
		self.prefabMode = self.prefabModeList[newPrefabModeListIdx]
	end

	local prefabName = self.renderPrefabSelector[self.prefabMode]:_RenderAndReturnSelection(ui)
	local is_valid = prefabName and prefabName ~= ''
	self:PushGreenButtonColor(ui)
	if ui:Button("Spawn Prefab", nil, nil, not is_valid) then
		self:PlacePrefab(prefabName)
		self:SetDirty()
	end
	self:PopButtonColor(ui)

	self:AddSectionEnder(ui)

	if ui:CollapsingHeader("Spawn from props in world") then
		local prefabs = {}
		for savefile, filedata in pairs(TheWorld.components.propmanager.data) do
			for prefab,t in pairs(filedata) do
				prefabs[prefab] = true
			end
		end
		prefabs = lume.keys(prefabs)
		table.sort(prefabs)
		for _,prefab in ipairs(prefabs) do
			if ui:Button(prefab) then
				self:PlacePrefab(prefab)
			end
		end
	end

	self:AddSectionEnder(ui)

	local changed, newlayer = ui:Combo("Selection Layer", self.edit_options.layer, self.layer_list)
	if changed then
		self.edit_options:Set("layer", newlayer)
		self.edit_options:Save()
		self:ApplySelectionLayer(self.edit_options.layer)
	end

	if ui:Button("Snap Layer To Grid") then
		self:SnapAllToGrid()
	end

	if ui:TreeNode("Show/Hide Layers") then
		self.showDecor = self.showDecor == nil or self.showDecor
		if ui:Checkbox("Decor##layervis", self.showDecor) then
			self.showDecor = not self.showDecor
			self:ShowLayer(PropType.Decor, self.showDecor, self.decorLayerPrefabFilter)
		end
		ui:SameLineWithSpace(30)
		ui:SetNextItemWidth(120)
		local decor_layers = { "All", "_bg_", "_fg_", }
		local idx = lume.find(decor_layers, self.decorLayerPrefabFilter) or 1
		changed, idx = ui:Combo("##decor-layer", idx, decor_layers)
		if ui:IsItemHovered() then
			ui:SetTooltip("Only include decor prefabs with this in their name.")
		end
		if changed then
			self.decorLayerPrefabFilter = decor_layers[idx]
			if self.decorLayerPrefabFilter == decor_layers[1] then
				self.decorLayerPrefabFilter = nil
			end
			self:ShowLayer(PropType.Decor, self.showDecor, self.decorLayerPrefabFilter)
		end

		self.showLighting = self.showLighting == nil or self.showLighting
		if ui:Checkbox("Lighting##layervis", self.showLighting) then
			self.showLighting = not self.showLighting
			self:ShowLayer(PropType.Lighting, self.showLighting)
		end
		self.showGrid = self.showGrid == nil or self.showGrid
		changed, self.showGrid = ui:Checkbox("Grid##layervis", self.showGrid)
		ui:SameLineWithSpace(30)
		ui:SetNextItemWidth(120)
		-- Add more Hides to this list to match that string.
		local grid_layers = { "All", "Hide spawner", "Hide gate", }
		local changed2
		changed2, self.grid_layer_filter = ui:ComboAsString("##grid-layer", self.grid_layer_filter, grid_layers)
		if ui:IsItemHovered() then
			ui:SetTooltip("Only include decor prefabs with this in their name.")
		end
		if changed or changed2 then
			local filter = self.grid_layer_filter and self.grid_layer_filter:match("Hide (.*)")
			print(PropType.Grid, self.showGrid, filter, filter)
			self:ShowLayer(PropType.Grid, self.showGrid, filter, filter)
		end
		self.showParticles = self.showParticles == nil or self.showParticles
		if ui:Checkbox("Particles##layervis", self.showParticles) then
			self.showParticles = not self.showParticles
			self:ShowLayer(PropType.Particles, self.showParticles)
		end
		if ui:Checkbox("Ground", TheWorld:IsGroundVisible()) then
			TheWorld:ToggleGroundVisibility()
		end

		self:AddTreeNodeEnder(ui)
	end

	if self.edit_options:Toggle(ui, "Show Previews", "previews") then
		self:ApplyPreviews(self.edit_options.previews)
	end

	local ent = GetDebugEntity()

	ui:SameLineWithSpace()
	self.edit_options:Toggle(ui, "Draw Grid", "draw_grid")
	if ui:IsItemHovered() then
		ui:SetTooltip("Grid is only drawn when selecting a prop snapped to the grid.")
	end
	if TheWorld.components.snapgrid.debugdraw ~= self.edit_options.draw_grid then
		TheWorld.components.snapgrid:SetDebugDrawEnabled(self.edit_options.draw_grid)
	end

	if prefabName and prefabName ~= "" then
		ui:SameLineWithSpace()
		if self.edit_options:Toggle(ui, "Show only props of type '"..prefabName.."'##show_exclusive_editprefab", "show_exclusive_editprefab") then
			if self.edit_options.show_exclusive_editprefab then
				self.edit_options.show_exclusive_selectedprefab = false
			end
			self:ShowExclusive(prefabName, self.edit_options.show_exclusive_editprefab)
		end
	end

	self:ValueColored(ui, "Selection (F1 or ALT + Left Mouse)", WEBCOLORS.GOLD, tostring(ent or "None selected"))
	if ent and ent.components.prop then
		ui:SameLineWithSpace()
		if self.edit_options:Toggle(ui, "Show only props of type '"..ent.prefab.."'##show_exclusive_selectedprefab", "show_exclusive_selectedprefab") then
			if self.edit_options.show_exclusive_selectedprefab then
				self.edit_options.show_exclusive_editprefab = false
			end
			self:ShowExclusive(ent.prefab, self.edit_options.show_exclusive_selectedprefab)
		end
		if prefabName and prefabName ~= "" then
			self:PushGreenButtonColor(ui)
			if ui:Button("Replace selection with "..prefabName) then
				local pos = ent:GetPosition()
				local hsb
				if ent.components.prop then
					hsb = ent.components.prop.data.hsb
				end
				ent:Remove()
				local ent = self:PlacePrefab(prefabName)
				ent.Transform:SetPosition(pos.x, pos.y, pos.z)
				if ent.components.prop and hsb then
					ent.components.prop:SetHsb(Hsb.FromRawTable(hsb))
					ent.components.prop.data.hsb = hsb
				end
				self:SetDirty()
			end
			self:PopButtonColor(ui)
		end
	end

	ui:Value("Teleport Prop", "ALT + t")

	-- KAJ: Should we call a function on the editables if the entity changes?
	if ent ~= self.ent then
		self:OnEntityChanged(self.ent, ent)
	end
	self.ent = ent

	if not ent then
		return
	end

	if ent.components.prop then
		-- savefile is missing until a frame after creation
		self:ValueColored(ui, "Scene", WEBCOLORS.GOLD, ent.components.prop.savefile or "<invalid>")
	end

	if not ent:HasTag("editable") then
		ui:Text("Selection is not editable")
		return
	end

	-- Clone selected prefab
	self:PushGreenButtonColor(ui)
	if ui:Button("Clone") then
		self:PlacePrefab(ent.prefab, ent)
	end
	self:PopButtonColor(ui)

	ui:SameLineWithSpace()
	ui:Text("(CTRL + SHIFT + Right Mouse)")

	ui:SameLineWithSpace()
	self.edit_options:Toggle(ui, "Clone Prop Settings", "clone_inst_params")

	self:AddSectionEnder(ui)

	if ent.EditEditable then
		if ui:CollapsingHeader("Entity") then
			ui:Indent()
			if ent:EditEditable(ui) then
				self:SetDirty()
			end
			ui:Unindent()
			self:AddSectionEnder(ui)
		end
	end

	local prop_settings = _prop_static.data[ent.prefab]
	local script = prop_settings and prop_settings.script
	if script then
		local prop = ent.components.prop
		local params = {script_args = prop.script_args or {}}

		run_script_fn(script, {}, function(scriptclass, _)
			-- make our prop params (defaults + prop def overrides)
			local prop_params = {script_args = deepcopy(scriptclass.Defaults) or {}}
			for i,v in pairs(prop_settings.script_args or {}) do
				prop_params.script_args[i] = v
			end
			-- make our merged params
			local workparams = deepcopy(prop_params)
			for i,v in pairs(params.script_args or {}) do
				workparams.script_args[i] = v
			end
			if scriptclass.LivePropEdit then
				local typename = scriptclass.GetTypeName and scriptclass.GetTypeName() or script
				if ui:CollapsingHeader(typename, ui.TreeNodeFlags.DefaultOpen) then
					local inparams = deepcopy(workparams)
					ui:PushID("script.LivePropEdit")
					scriptclass.LivePropEdit(self,ui,workparams,prop_params.script_args or {})
					ui:PopID()
					if not deepcompare(workparams, inparams) then
						-- Create new prop params, edit may have nilled out the
						-- script args but we need to apply original settings.
						local applyparams = deepcopy(prop_params)
						for i,v in pairs(workparams.script_args or {}) do
							applyparams.script_args[i] = v
						end
						if scriptclass.Apply then
							scriptclass.Apply(ent, applyparams.script_args)
						end
						prop.script_args = deepcopy(workparams.script_args)
						if not next(prop.script_args) then
							prop.script_args = nil
						end
						prop:OnPropChanged()
					end
				end
			end
		end)
	end
	for i,v in pairs(ent.components) do
		if v.EditEditable then
			if ui:CollapsingHeader(v.EditableName or i) then
				v:EditEditable(ui)
				self:AddSectionEnder(ui)
			end
		end
	end
end

local function PropTypePicker(ui, prop_type)
	local proptypes = lume.keys(PropType)
	table.sort(proptypes)
	table.insert(proptypes, 1, "Any")
	return ui:_ComboAsString("Prop Type", prop_type, proptypes, true)
end

local function BuildPropQueryParams(data)
	local prop_query = data.prefab_name
	if data.exact_match then
		prop_query = ('^%s$'):format(prop_query)
	end
	local params = {
		ignore_name   = data.prefab_name:len() == 0,
		prop_query = prop_query,
		typecheck  = nil,
	}
	if data.prop_type then
		local proptype_id = PropType[data.prop_type]
		params.typecheck = lume.filter(PropAutogenData,
			function(v)
				return (v.proptype or PropType.Grid) == proptype_id
			end,
			true)
	end
	return params
end

local function MatchesPropQuery(query_param, prefab)
	return (query_param.ignore_name or prefab:find(query_param.prop_query))
		and (not query_param.typecheck or query_param.typecheck[prefab])
end

function EditableEditor:_DrawCopyPropPopup(ui, panel)
	local copy_props_popup = "Copy Props from..."
	if ui:Button(copy_props_popup) then
		ui:OpenPopup(copy_props_popup)
		self.scene_copier = {
			prefab_name = "",
			src_scene = TheWorld.prefab, -- assume the default one
			dest_scenes = {},
		}
		self.renderPrefabSelector.Prop:ClearSelection()
	end
	if ui:BeginPopupModal(copy_props_popup, true, ui.WindowFlags.AlwaysAutoResize) then
		local current_scene = TheWorld.scenelist[1]
		local ignore_name = self.scene_copier.prefab_name:len() == 0
		if self.scene_copier.copied_props then
			ui:TextWrapped(self.scene_copier.msg)
			if ui:CollapsingHeader("Prop Counts", ui.TreeNodeFlags.DefaultOpen) then
				for prefab,placements in iterator.sorted_pairs(self.scene_copier.copied_props) do
					ui:Value(prefab, #placements)
				end
			end

			if ui:Button("Save and Reset") then
				ui:CloseCurrentPopup()
				-- Load assets since the game thinks we already loaded
				-- dependencies for current level.
				TheSim:LoadPrefabs(lume.keys(self.scene_copier.copied_props))
				self:ReopenNodeAfterReset()
				c_reset() -- so changes are visible
			end
		else
			ui:Value("Group Filter", self.levelgroupfilter)

			local scenes = GetAllScenes(self.levelgroupfilter)
			local idx = lume.find(scenes, self.scene_copier.src_scene) or 1
			idx = ui:_Combo("From Scene", idx, scenes)
			self.scene_copier.src_scene = scenes[idx]

			self.scene_copier.prop_type = PropTypePicker(ui, self.scene_copier.prop_type)

			local changed, text = ui:InputText("Prop Name Pattern", self.scene_copier.prefab_name or "")
			if changed then
				self.renderPrefabSelector.Prop:ClearSelection()
				self.scene_copier.prefab_name = text
				self.scene_copier.exact_match = nil
			end

			ui:Indent() do
				if ui:CollapsingHeader("Prefab Name Picker", ui.TreeNodeFlags.DefaultOpen) then
					local prefab_name = self.renderPrefabSelector.Prop:_RenderAndReturnSelection(ui)
					if prefab_name then
						self.scene_copier.prefab_name = prefab_name
						self.scene_copier.exact_match = true
					end
				end
			end ui:Unindent()

			ui:Spacing()

			local btn_w = 400

			local kind = self.scene_copier.prop_type or ""
			local pat
			if ignore_name then
				pat = ("all %s props"):format(kind)
			else
				local matchtype = self.scene_copier.exact_match and "named" or "matching"
				pat = ("%s props %s '%s'"):format(kind, matchtype, self.scene_copier.prefab_name)
			end
			local msg = string.format("Copying %s from scene '%s'.", pat, self.scene_copier.src_scene)
			ui:TextWrapped(msg)
			ui:Spacing()

			local has_src = self.scene_copier.src_scene:len() > 0
			local is_valid = has_src and self.scene_copier.src_scene ~= current_scene
			local target_scenes
			local label_fmt = "Copy to current scene: %s"
			if ui:Button(label_fmt:format(current_scene), btn_w, nil, not is_valid) then
				target_scenes = {
					[current_scene] = true,
				}
			end
			ui:Spacing()

			is_valid = has_src and next(self.scene_copier.dest_scenes)
			label_fmt = "Copy to %d checked scenes###copy_checked"
			local checked_count = lume.count(self.scene_copier.dest_scenes)
			if ui:Button(label_fmt:format(checked_count), btn_w, nil, not is_valid) then
				target_scenes = self.scene_copier.dest_scenes
			end

			-- After the buttons so button is more visible.
			ui:Indent() do
				if ui:CollapsingHeader("Scene Picker Checkboxes") then
					self.scene_copier.scene_filter = ui:_InputText("Scene Filter", self.scene_copier.scene_filter or "")
					for _,scene in ipairs(scenes) do
						if scene:len() > 0
							and scene ~= current_scene
							and scene:find(self.scene_copier.scene_filter)
						then
							self.scene_copier.dest_scenes[scene] = ui:_Checkbox(scene, self.scene_copier.dest_scenes[scene]) or nil
						end
					end
				end
			end ui:Unindent()

			if target_scenes then
				self.scene_copier.msg = string.format("Copied %s from scene '%s' to '%s'.", pat, self.scene_copier.src_scene, table.inspect(lume.keys(target_scenes)))
				print(self.scene_copier.msg) -- want action to show up in logs.
				local props = {}
				local query_param = BuildPropQueryParams(self.scene_copier)
				EditableEditor.RunOnAllPropData(self, function(editor, data, scene_name)
					if scene_name ~= self.scene_copier.src_scene then
						return
					end
					for prefab,placements in pairs(data) do
						if MatchesPropQuery(query_param, prefab)
						then
							props[prefab] = deepcopy(placements)
						end
					end
				end)
				EditableEditor.RunOnAllPropData(self, function(editor, data, scene_name)
					if not target_scenes[scene_name] then
						return
					end
					for prefab,placements in pairs(props) do
						data[prefab] = props[prefab]
					end
					return true
				end)
				self.scene_copier.copied_props = props
			end
		end
		ui:EndPopup()
	end
end

function EditableEditor:_DrawDeletePropPopup(ui, panel)
	local delete_props_popup = "Delete Props..."
	local is_multiscene = #TheWorld.scenelist > 1
	if ui:Button(delete_props_popup, nil, nil, is_multiscene) then
		ui:OpenPopup(delete_props_popup)
		local props = {}
		for index, entity in pairs(Ents) do
			if entity and entity.components.prop then
				table.insert(props, entity)
			end
		end
		self.scene_deleter = {
			prefab_name = "",
			props = props,
		}
		self.renderPrefabSelector.Prop:ClearSelection()
	end
	if is_multiscene and ui:IsItemHovered() then
		ui:SetTooltip("Can only batch delete props when viewing a single scene.")
	end
	if ui:BeginPopupModal(delete_props_popup, true, ui.WindowFlags.AlwaysAutoResize) then
		local ignore_name = self.scene_deleter.prefab_name:len() == 0

		self.scene_deleter.prop_type = PropTypePicker(ui, self.scene_deleter.prop_type)

		local changed, text = ui:InputText("Prop Name Pattern", self.scene_deleter.prefab_name or "")
		if changed then
			self.renderPrefabSelector.Prop:ClearSelection()
			self.scene_deleter.prefab_name = text
			self.scene_deleter.exact_match = nil
		end

		ui:Indent() do
			if ui:CollapsingHeader("Prefab Name Picker", ui.TreeNodeFlags.DefaultOpen) then
				local prefab_name = self.renderPrefabSelector.Prop:_RenderAndReturnSelection(ui)
				if prefab_name then
					self.scene_deleter.prefab_name = prefab_name
					self.scene_deleter.exact_match = true
				end
			end
		end ui:Unindent()

		ui:Spacing()

		local query_param = BuildPropQueryParams(self.scene_deleter)
		local to_delete = lume.filter(self.scene_deleter.props, function(ent)
			local prefab = ent.prefab
			return MatchesPropQuery(query_param, prefab)
		end)

		local kind = self.scene_deleter.prop_type or ""
		local pat
		if ignore_name then
			pat = ("all %s props"):format(kind)
		else
			local matchtype = self.scene_deleter.exact_match and "named" or "matching"
			pat = ("%s props %s '%s'"):format(kind, matchtype, self.scene_deleter.prefab_name)
		end
		local msg = string.format("Deleting %s (%d) from current scene.", pat, #to_delete)
		ui:TextWrapped(msg)
		ui:Spacing()

		ui:Indent() do
			if ui:CollapsingHeader("Prop Counts", ui.TreeNodeFlags.DefaultOpen) then
				local counts = lume.frequency(lume.map(to_delete, "prefab"))
				for prefab,count in iterator.sorted_pairs(counts) do
					ui:Value(prefab,count)
				end
			end
		end ui:Unindent()

		local label_fmt = "Delete %d Props###delete"
		if ui:Button(label_fmt:format(#to_delete), ui:GetContentRegionAvail(), 0) then
			for _,ent in ipairs(to_delete) do
				ent:Remove()
			end
			ui:CloseCurrentPopup()
		end
		ui:EndPopup()
	end
end

function EditableEditor:DrawTestSection(ui, panel)
	ui:Spacing()

	self:PushGreenButtonColor(ui) do
		if self.levelparams.town then
			local disabled = self:IsDirty()
			if ui:Button("Test Town", nil, nil, disabled) then
				self:_TestTown()
			end
		else
			local can_start, reason = self.arena_loader:CanStartArena()
			local disabled = self:IsDirty() or not can_start
			local test_level = ui:Button("Test Level", nil, nil, disabled)
			if disabled then
				if self:IsDirty() then
					ui:SetTooltipIfHovered("Save or Reset and then you can Test Level")
				end
				if not can_start then
					ui:SetTooltipIfHovered("Can't Test Level because: "..reason)
				end
			end
			if test_level then
				self:_TestLevel()
			end

			ui:SameLine_RightAligned(105)
			TheSaveSystem.cheats:SetValue("eliminate_all_exits", ui:_Checkbox("Remove Exits", TheSaveSystem.cheats:GetValue("eliminate_all_exits")))
			ui:SetTooltipIfHovered("Treat all exits as invalid for EliminateInvalidExits to preview how exits look when they get removed at load time.")
		end
		self:PopButtonColor(ui)
	end

	if self.levelparams.town then
		ui:TextColored(WEBCOLORS.ORANGE, "Testing town will ERASE your gameplay town save.")
		ui:TextColored(WEBCOLORS.ORANGE, "You MUST erase save data to play the game again.")

	else
		--~ ui:SameLineWithSpace()
		--~ self.test_options.entrance = ui:_Combo("##entrance", self.test_options.entrance, self.entrances)
		self.arena_loader:Ui(ui, "##ArenaLoader")
	end

	self:AddSectionEnder(ui)
end

function EditableEditor.RunOnAllPropData(editor, fn)
	local count = 0
	for levelname,world in pairs(_world_static.data) do
		local scenelist = world.scenes or { {
				name = levelname,
				roomtype = "all",
		} }
		for _,scene in ipairs(scenelist) do
			local require_path = SceneToModulePath(scene.name)
			local data = {}
			if kleimoduleexists(require_path) then
				data = require(require_path)
			end
			if fn(editor, data, scene.name) then
				WriteSceneToDisk(scene.name, data)
				count = count + 1
			end
		end
	end
	print(("[Inspector] Batch modified %d files."):format(count))
end

function EditableEditor:_TestTown()
	self:ReopenNodeAfterReset()
	TheLog.ch.Editor:print("LoadTownLevel from EditableEditor. Invalidating save.")

	TheSaveSystem.town:ClearAllRooms(function(success)
		RoomLoader.LoadTownLevel(self.arena_loader.levelname)
	end)
end

function EditableEditor:_TestLevel()
	self:ReopenNodeAfterReset()
	self.arena_loader:StartArena(true)
end


local function is_ambiance_prop(prefab)
	return (prefab:find('_fg_')
		or prefab:find('_bg_')
		or prefab:find('_up_'))
end
local function is_lighting_prop(prefab)
	return prefab:find('lightspot_')
end
local function is_particles_prop(prefab)
	return prefab:find('particlesystem')
end
local function copy_ambiance_props(propdata, levelname)
	local k = levelname:gsub("_mat", "_arena")
	local src_file = require(string.format('map/propdata/%s_propdata', k))
	if src_file then
		for prefab,placements in pairs(propdata) do
			if is_ambiance_prop(prefab) then
				propdata[prefab] = nil
			end
		end

		for prefab,placements in pairs(src_file) do
			if is_ambiance_prop(prefab) then
				propdata[prefab] = deepcopy(placements)
			end
		end
	end
end

-- Don't submit this code uncommented. Don't want the button unless a coder is
-- using it.
--~ function EditableEditor:BatchModify(propdata, levelname)
--~ 	-- Modify level's propdata here. Will run for all existing propdata. You
--~ 	-- can F6 to apply your changes (or Ctrl-R).
--~ 	for prefab,placements in pairs(propdata) do
--~ 		local newname = prefab:gsub("FORGE", "forge")
--~ 		if newname ~= prefab then
--~ 			propdata[newname] = propdata[prefab]
--~ 			propdata[prefab] = nil
--~ 		end
--~ 		if false and prefab:find("lightspot_") then
--~ 			local name,d = prefab:match("(lightspot_%w+)(%d)")
--~ 			if name then
--~ 				propdata[name] = propdata[name] or {}
--~ 				for i,val in ipairs(placements) do
--~ 					val.variation = tonumber(d)
--~ 					table.insert(propdata[name], val)
--~ 				end
--~ 				propdata[prefab] = nil
--~ 			end
--~ 		end
--~ 	end
--~ 	return true
--~ end


function EditableEditor:SnapAllToGrid()
	for k,ent in pairs(GetAllPropEntities()) do
		local prop = ent.components.prop
		if prop.edit_listeners
			and ent.components.snaptogrid
		then
			ent.components.snaptogrid:SetNearestGridPos(ent:GetPosition():Get())
			prop:OnPropChanged()
		end
	end
	self:SetDirty()
end


function EditableEditor:ApplyPreviews(show_previews)
	if show_previews then
		local temp_loading = TheWorld.components.propmanager.temploading
		TheWorld.components.propmanager.temploading = true
		TheWorld:PushEvent("editableeditor.togglepreviews", true)
		TheWorld.components.propmanager.temploading = temp_loading
	else
		TheWorld:PushEvent("editableeditor.togglepreviews", false)
	end
end

function EditableEditor:ApplySelectionLayer(layer_index)
	local layer = self.layer_list[layer_index]
	self.layer_to_fn[layer](self)
end

local function _EnableLayer(should_enable_fn)
	for k,ent in pairs(GetAllPropEntities()) do
		local prop = ent.components.prop
		-- Always ignore to avoid double listening.
		prop:IgnoreEdits()
		if should_enable_fn(prop) then
			prop:ListenForEdits()
		end
	end
end

function EditableEditor:EnableLayer_All()
	_EnableLayer(function(prop)
		return true
	end)
end

local function is_decor_layer(prop)
	return prop:GetPropType() == PropType.Decor
end

local function is_lighting_layer(prop)
	return prop:GetPropType() == PropType.Lighting
end

local function is_particles_layer(prop)
	return prop:GetPropType() == PropType.Particles
end

-- Other editors can use these.
function EditableEditor.EnableLayer_Decor()
	_EnableLayer(is_decor_layer)
end

function EditableEditor:EnableLayer_Lighting()
	_EnableLayer(is_lighting_layer)
end

function EditableEditor.EnableLayer_Particles()
	_EnableLayer(is_particles_layer)
end

function EditableEditor.EnableLayer_Grid()
	_EnableLayer(function(prop)
		return not is_lighting_layer(prop)
			and not is_decor_layer(prop)
			and not is_particles_layer(prop)
	end)
end

function EditableEditor.EnableLayer_PrefabName(target_prefabname)
	_EnableLayer(function(prop)
		return prop.inst.prefab == target_prefabname
	end)
end

DebugNodes.EditableEditor = EditableEditor

return EditableEditor
