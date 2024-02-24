local DebugNodes = require "dbui.debug_nodes"
local DebugSettings = require "debug.inspectors.debugsettings"
local DungeonHistoryMap = require "widgets.ftf.dungeonhistorymap"
local PrefabEditorBase = require "debug.inspectors.prefabeditorbase"
local biomes = require "defs.biomes"
local krandom = require "util.krandom"
local lume = require "util.lume"
local mapgen = require "defs.mapgen"
require "consolecommands"
require "debugcommands"


local _static = PrefabEditorBase.MakeStaticData("mappath_autogen_data")

local MapPathEditor = Class(PrefabEditorBase, function(self)
	PrefabEditorBase._ctor(self, _static)

	self.name = "Map Path Editor"
	self.prefab_label = "Path"
	-- TODO(dbriscoe): What should test do? Should this be an EditorBase instead?
	self.test_label = "Begin Editing"

	self.edit_options = DebugSettings("mappatheditor.edit_options")
		:Option("ignore_boss_position", false)
		:Option("show_path_bounds", false)
end)

MapPathEditor.PANEL_WIDTH = 650
MapPathEditor.PANEL_HEIGHT = 1000

function MapPathEditor:GetLoaderComment()
	return "loaded by DungeonHistoryMap"
end

local function IsInDungeon()
	return not TheWorld:HasTag("town")
end

local function IsValidPathData(path_data)
	return path_data.path
end

local function GetDungeonHistoryMapWidget()
	local pause_module = "screens.redux.pausescreen"
	local PauseScreen = require(pause_module)
	local screen = TheFrontEnd:FindScreen(PauseScreen)
	if not screen then
		screen = d_open_screen(pause_module)
	end
	return screen.map
end

function MapPathEditor:_MaximizeView()
	local editor, panel = MapPathEditor:FindOrCreateEditor()
	panel.did_maximize = not panel.is_maximized -- toggle to maximized
	panel.layout_options:Set("current_maximize", panel.maximize.modes.right)
	local map = GetDungeonHistoryMapWidget()
	map:SetScale(0.375)
	map:LayoutBounds("left", "center", map.parent)
end

function MapPathEditor:OnActivate()
	-- Force pause to open and display map.
	GetDungeonHistoryMapWidget()
end

function MapPathEditor:OnDeactivate()
end


function MapPathEditor:OnPrefabDropdownChanged(new_path_name)
	MapPathEditor._base.OnPrefabDropdownChanged(self, new_path_name)
	local path_data = self.static.data[new_path_name]
	if IsInDungeon() and IsValidPathData(path_data) then
		local map = GetDungeonHistoryMapWidget()
		map:EditDungeonPath(path_data)
	end
end

function MapPathEditor:Test(prefab, params, count)
	self:_MaximizeView()
end

local function CreatePath(anim, sign, is_turn)
	if sign > 0 then
		sign = nil
	end
	return {
		anim = anim,
		sign = sign,
		is_turn = is_turn or nil,
	}
end

function MapPathEditor:PushStyleIfCurrent(ui, current_step, new_step)
	if deepcompare(current_step, new_step) then
		ui:PushStyleColor(ui.Col.Button, WEBCOLORS.GREEN)
		return 1
	end
	return 0
end

function MapPathEditor:AddEditableOptions(ui, params)
	local should_randomize = not params.path
	params.path = params.path or {}

	local locations = lume(mapgen.biomes)
		:enumerate(function(k, v)
			if v.dimensions.long == params.length then
				return k
			end
		end)
		:keys()
		:result()

	params.length = ui:_SliderInt("Path Length", params.length or 17, 5, 25)
	while params.length > #params.path do
		local first_anim = next(DungeonHistoryMap.assets.travel_offsets)
		table.insert(params.path, CreatePath(first_anim, 1))
	end
	if params.length < #params.path then
		params.path = lume.first(params.path, params.length)
	end

	ui:Text(("Path candidate in %i biome location mapgen."):format(#locations))
	ui:SetTooltipIfHovered(table.concat(locations, "\n"))

	if not IsInDungeon() then
		ui:Text("Must be in a dungeon to edit the map layout.")
		local dest = lume.match(locations, function(x)
			return biomes.locations[x]
		end)
		if ui:Button("Start Run: ".. (dest or "<default>")) then
			self:ReopenNodeAfterReset()
			d_startrun(dest)
		end
		-- Don't allow further editing!!!!!!!!!!!!!!!!!!!!!!!!
		return
	end


	if self.edit_options:Toggle(ui, "Preview with fixed start position", "ignore_boss_position") then
		self:ForceMapRebuild()
	end

	if self.edit_options:Toggle(ui, "Show path bounding boxes", "show_path_bounds") then
		self:ForceMapRebuild()
		if self.edit_options.show_path_bounds then
			DebugNodes.DebugWidget:FindOrCreateEditor()
		end
	end

	if self.edit_options:Toggle(ui, "Edit from Boss to Entrance", "edit_back_to_front") then
		if self.edit_options.edit_back_to_front then
			self.current_path_idx = params.length
		else
			self.current_path_idx = 1
		end
	end
	local advance_delta = 1
	if self.edit_options.edit_back_to_front then
		advance_delta = -1
	end


	params.boss_position = ui:_ComboAsString("Boss Position", params.boss_position, DungeonHistoryMap.BossPosition:Ordered(), true)

	ui:Spacing()
	self.current_path_idx = ui:_SliderInt("Current Step", self.current_path_idx or 1, 1, params.length)

	ui:SameLineWithSpace()
	if ui:Button(ui.icon.playback_step_back, ui.icon.width, nil, self.current_path_idx <= 1) then
		self.current_path_idx = self.current_path_idx - 1
	end
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.playback_step_fwd, ui.icon.width, nil, self.current_path_idx >= params.length) then
		self.current_path_idx = self.current_path_idx + 1
	end

	local current_step = params.path[self.current_path_idx] or {}
	local max = Vector2(
		lume(DungeonHistoryMap.assets.travel_offsets)
			:map("x")
			:map(math.abs)
			:reduce(math.max)
			:result(),
		lume(DungeonHistoryMap.assets.travel_offsets)
			:map("y")
			:map(math.abs)
			:reduce(math.max)
			:result())

	if ui:Button("Randomize Path") or should_randomize then
		for _,step in ipairs(params.path) do
			step.anim = krandom.PickKeyValue(DungeonHistoryMap.assets.travel_offsets)
			step.sign = krandom.Boolean() and -1 or nil
			step.is_turn = nil
		end
		for _,i in ipairs({ 7, 9, }) do
			local step = params.path[i]
			step.is_turn = true
			step.anim = krandom.PickKeyValue(DungeonHistoryMap.assets.turn_offsets)
		end
		self:ForceMapRebuild()
	end

	local flags = (0
		| ui.TableFlags.SizingFixedSame
		| ui.TableFlags.BordersH
		| ui.TableFlags.BordersV)
	local btn_size = Vector2(50)
	local table_draw_size = (max + Vector2(2, max.y)):mul(btn_size) + Vector2(5, 0)
	if ui:BeginTable("forward", max.x + 1, flags, table_draw_size:unpack()) then
		for y=-max.y,max.y do
			ui:TableNextRow()
			for x=0,max.x do
				ui:TableNextColumn()
				local abs_y = math.abs(y)
				local anim = DungeonHistoryMap.OffsetToAnimName(Vector2(x,abs_y))
				local offset = DungeonHistoryMap.assets.travel_offsets[anim]
				if offset then
					local newstep = CreatePath(anim, lume.sign(-y))
					local style_count = self:PushStyleIfCurrent(ui, current_step, newstep)
					if ui:Button(anim .."##travel"..y, btn_size:unpack()) then
						params.path[self.current_path_idx] = newstep
						self.current_path_idx = self.current_path_idx + advance_delta
					end
					ui:PopStyleColor(style_count)
				elseif x == 0 and y == 0 then
					ui:Dummy(0, btn_size.y - ui:GetFontSize() * 2.5)
					local dir = DungeonHistoryMap.GetHorizontalDirection(params, self.current_path_idx)
					local cardinal = dir > 0 and "East" or "West"
					ui:Text(cardinal .."\n".. ui.icon.arrow_right)
				else
					ui:Dummy(btn_size:unpack())
				end
			end
		end
		ui:EndTable()
	end
	ui:SameLine()
	ui:Dummy(10,0)

	-- Force a big gap between tables.
	ui:Dummy(0,20)

	max = Vector2(
		lume(DungeonHistoryMap.assets.turn_offsets)
			:map("x")
			:map(math.abs)
			:reduce(math.max)
			:result(),
		lume(DungeonHistoryMap.assets.turn_offsets)
			:map("y")
			:map(math.abs)
			:reduce(math.max)
			:result())
	if ui:BeginTable("uturn", max.x + 1, flags, table_draw_size:unpack()) then
		for y=-max.y,max.y do
			ui:TableNextRow()
			for x=0,max.x do
				ui:TableNextColumn()
				local abs_y = math.abs(y)
				local anim = DungeonHistoryMap.OffsetToAnimName(Vector2(x,abs_y))
				local offset = DungeonHistoryMap.assets.turn_offsets[anim]
				if offset then
					local newstep = CreatePath(anim, lume.sign(-y), true)
					local style_count = self:PushStyleIfCurrent(ui, current_step, newstep)
					if ui:Button(anim .."##turn"..y, btn_size:unpack()) then
						params.path[self.current_path_idx] = newstep
						self.current_path_idx = self.current_path_idx + advance_delta
					end
					ui:PopStyleColor(style_count)
				elseif x == 0 and y == 0 then
					ui:Dummy(0, btn_size.y - ui:GetFontSize() * 2)
					ui:Text("U-Turn\n".. ui.icon.undo)
				else
					ui:Dummy(btn_size:unpack())
				end
			end
		end
		ui:EndTable()
	end

	self.current_path_idx = lume.clamp(self.current_path_idx, 1, params.length)


	if self.last_applied_idx ~= self.current_path_idx
		or not deepcompare(self.last_applied_params, params)
	then
		self.last_applied_idx = self.current_path_idx
		self.last_applied_params = deepcopy(params)
		local map = GetDungeonHistoryMapWidget()
		local editor_params = {
			ignore_boss_position = self.edit_options.ignore_boss_position,
			show_path_bounds = self.edit_options.show_path_bounds,
		}
		map:EditDungeonPath(params, self.current_path_idx, editor_params)
		self:SetDirty()
	end
end

function MapPathEditor:ForceMapRebuild()
	self.last_applied_params = nil
end



DebugNodes.MapPathEditor = MapPathEditor

return MapPathEditor
