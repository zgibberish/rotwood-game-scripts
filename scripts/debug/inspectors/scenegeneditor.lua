-- Editor for SceneGen prefabs.

local ArenaLoader = require "debug.inspectors.arenaloader"
local BackgroundGradientPane = require "debug.inspectors.panes.backgroundgradient"
local Biomes = require "defs.biomes"
local DebugDraw = require "util.debugdraw"
local DebugNodes = require "dbui.debug_nodes"
local DungeonProgress = require "proc_gen.dungeon_progress"
local Encounters = require "encounter.encounters"
local GroundTiles = require "defs.groundtiles"
local Hsb = require "util.hsb"
local KRandom = require "util.krandom"
local Lume = require "util.lume"
local MapGen = require "defs.mapgen"
local MapLayout = require "util.maplayout"
local ParticleSystem = require "components.particlesystem"
local PrefabBrowser = require "proc_gen.prefab_browser"
local PrefabEditorBase = require "debug.inspectors.prefabeditorbase"
local PropAutogenData = require "prefabs.prop_autogen_data"
local PropProcGen = require "proc_gen.prop_proc_gen"
local PropRefsWindow = require "proc_gen.prop_refs_window"
local SceneGen = require "components.scenegen"
local SceneParticleSystem = require "proc_gen.scene_particle_system"
local SceneProp = require "proc_gen.scene_prop"
local UnderlayPropGen = require "proc_gen.underlay_prop_gen"
local Waves = require "encounter.waves"
local ZoneGen = require "proc_gen.zone_gen"
local ZoneGrid = require "map.zone_grid"
require "debug.inspectors.lighting"
require "debug.inspectors.sky"
require "debug.inspectors.water"
require "proc_gen.scene_ui"

local static = PrefabEditorBase.MakeStaticData("scenegen_autogen_data")

local ZONE_GEN_CLIPBOARD_CONTEXT = "++ZONE_GEN_CLIPBOARD_CONTEXT"
local UNDERLAY_CLIPBOARD_CONTEXT = "++UNDERLAY_CLIPBOARD_CONTEXT"
local PARTICLE_SYSTEM_CLIPBOARD_CONTEXT = "++PARTICLE_SYSTEM_CLIPBOARD_CONTEXT"

local function InjectClasses(data)
	for _, scene_gen in pairs(data) do
		SceneGen.InjectClasses(scene_gen)
	end
end

local function StripMetaTables(data)
	if type(data) == "table" then
		setmetatable(data, nil)
		Lume(data):each(StripMetaTables)
	end
end

local SceneGenEditor = Class(PrefabEditorBase, function(self)
	PrefabEditorBase._ctor(self, static)

	InjectClasses(static.data)

	self.name = "SceneGen Editor"
	self.prefab_label = "SceneGen"
	self.testprefab = nil
	self.browser = PrefabBrowser(function(ui, id, browser_element)
		return self:BrowserElementUi(ui, id, browser_element)
	end)
	self.prop_refs = PropRefsWindow()
	self.arena_loader = ArenaLoader("scenegeneditor.arenaloader")
	if TheWorld and TheWorld.prefab then
		self.arena_loader:Set("levelname", TheWorld.prefab)
	end
	self.load_queue = {}
	self.dirty_stuff = {}
	self.curve_key = PROGRESS_ENDPOINTS[1]
	self.backgroundgradientEditorPane = self.backgroundgradientEditorPane or BackgroundGradientPane()

	if TheSceneGen then
		self:SelectPrefab(TheSceneGen.prefab)
		self.active_scene_gen = TheSceneGen.prefab
	else
		self:LoadLastSelectedPrefab(self.name)
	end

	self.test_label = "Rebuild Scene"
	self.test_enabled = TheWorld
		and TheDungeon:GetDungeonMap()
		and self.active_scene_gen == self.prefabname

	local scene_gen = self:GetSceneGen()
	if scene_gen then
		Lume(scene_gen.zone_gens):each(function(zone_gen)
			self:HideZoneGen(zone_gen, not zone_gen.enabled)
		end)
	end

	self:RefreshRoomsErrors()
end)

function SceneGenEditor:CanVisualizePlacements()
	return GetDebugPlayer() ~= nil
end

function SceneGenEditor:VisualizePlacements(visualize_placements)
	if not self:CanVisualizePlacements() then
		return
	end

	local debug_draw_manifested = self.visualize_placements ~= nil
	self.visualize_placements = visualize_placements

	if debug_draw_manifested then
		return
	end

	local COLORS = {
		Prop = WEBCOLORS.RED,
		Spacer = WEBCOLORS.PURPLE,
		Buffer = WEBCOLORS.BLUE,
		ParticleSystem = WEBCOLORS.WHITE
	}
	local seconds = 0.5
	local thick = 2
	DEBUG_CACHE.tasks.scenegeneditor = TheWorld:DoPeriodicTask(seconds, function(_)
		if not self.visualize_placements then
			return
		end
		for _, zone_gen in pairs(scene_gen_execution_report.zone_gens) do
			for _, circle in ipairs(zone_gen.circles) do
				DebugDraw.GroundCircle
					( circle.position.x
					, circle.position.y
					, circle.radius
					, COLORS[circle.type]
					, thick
					, seconds
					)
			end
			for _, circle in ipairs(zone_gen.placement_circles) do
				DebugDraw.GroundCircle
					( circle.center.x
					, circle.center.y
					, circle.radius
					, COLORS.Buffer
					, thick
					, seconds
					)
			end
		end
	end)
end

function SceneGenEditor:OnDeactivate()
	if self.visualize_placements ~= nil then
		DEBUG_CACHE.tasks.scenegeneditor:Cancel()
		self.visualize_placements = nil
	end
	self._base.OnDeactivate(self)
end

function SceneGenEditor:OnPropRenamed(from, to)
	for _, scene_gen in pairs(self.static.data) do
		for _, destructible in ipairs(scene_gen.destructibles) do
			if destructible.prop == from then
				destructible.prop = to
				self.static.dirty = true
			end
		end
		if scene_gen.underlay_props then
			for _, underlay_prop in ipairs(scene_gen.underlay_props) do
				if underlay_prop.prop == from then
					underlay_prop.prop = to
					self.static.dirty = true
				end
			end
		end
		for _, zone_gen in ipairs(scene_gen.zone_gens) do
			for _, scene_prop in ipairs(zone_gen.scene_props) do
				if scene_prop.prop == from then
					scene_prop.prop = to
					self.static.dirty = true
				end
			end
		end
		if scene_gen.creature_spawners then
			for _, creature_spawner in ipairs(scene_gen.creature_spawners) do
				if creature_spawner.prop == from then
					creature_spawner.prop = to
					self.static.dirty = true
				end
			end
		end
	end
end

function SceneGenEditor:OnPropDeleted(prop)
	local function MatchProp(decor_element)
		local match = decor_element.prop == prop
		if match then
			self.static.dirty = true
		end
		return match
	end
	for _, scene_gen in pairs(self.static.data) do
		if scene_gen.destructibles then
			Lume(scene_gen.destructibles):removeall(MatchProp)
		end
		if scene_gen.underlay_props then
			Lume(scene_gen.underlay_props):removeall(MatchProp)
		end
		for _, zone_gen in ipairs(scene_gen.zone_gens) do
			Lume(zone_gen.scene_props):removeall(MatchProp)
		end
		if scene_gen.creature_spawners then
			Lume(scene_gen.creature_spawners):removeall(MatchProp)
		end
	end
end

function SceneGenEditor:PreSave(data)
	StripMetaTables(data)
end

function SceneGenEditor:PostSave(data)
	InjectClasses(data)
	self.dirty_stuff = {}
end

function SceneGenEditor:OnRevert(data)
	SceneGen.InjectClasses(data)
	local live_edit = self.active_scene_gen == self.prefabname
	if live_edit then
		self.dirty_stuff[self:GetSceneGen()] = true
		self:RefreshScene()
	else
		self.dirty_stuff = {}
	end
	self:RefreshRoomsErrors()
end

function SceneGenEditor:OnPrefabDropdownChanged(new_prefab_name)
	SceneGenEditor._base.OnPrefabDropdownChanged(self, new_prefab_name)
	self:RefreshRoomsErrors()
	self.test_enabled = TheWorld
		and TheDungeon:GetDungeonMap()
		and self.active_scene_gen == new_prefab_name
end

function SceneGenEditor:GetZoneGrid()
	if not self.cached_zone_grid then
		self.cached_zone_grid = TheWorld and ZoneGrid(MapLayout(TheWorld.layout))
	end
	return self.cached_zone_grid
end

SceneGenEditor.PANEL_WIDTH = 600
SceneGenEditor.PANEL_HEIGHT = 800

function SceneGenEditor:GetSceneGen()
	return self.prefabname
		and 0 < string.len(self.prefabname)
		and self.static.data[self.prefabname]
		or nil
end

function SceneGenEditor:GetZoneGen()
	return self.selected_zone_gen
		and self:GetSceneGen().zone_gens[self.selected_zone_gen]
		or nil
end

function SceneGenEditor:GetSceneProp()
	local zone_gen = self:GetZoneGen()
	return (zone_gen and self.selected_scene_prop)
		and zone_gen.scene_props[self.selected_scene_prop]
		or nil
end

function SceneGenEditor:GetUnderlayProp()
	local zone_gen = self:GetZoneGen()
	return (zone_gen and self.selected_underlay_prop)
		and zone_gen.scene_props[self.selected_underlay_prop]
		or nil
end

function SceneGenEditor:GetParticleSystem()
	local zone_gen = self:GetZoneGen()
	return (zone_gen and self.selected_particle_system)
		and zone_gen.particle_systems[self.selected_particle_system]
		or nil
end

function SceneGenEditor:GetRoomParticleSystem()
	local zone_gen = self:GetZoneGen()
	return (zone_gen and self.selected_room_particle_system)
		and zone_gen.particle_systems[self.selected_room_particle_system]
		or nil
end

-- Edit the aspect of the contex via the ui_fn. If it changes, mark it true in self.dirty_stuff.
function SceneGenEditor:DetectChanges(aspect, context, ui_fn)
	context[aspect] = context[aspect] or {}
	local current_aspect = deepcopy(context[aspect])
	ui_fn()
	if not deepcompare(current_aspect, context[aspect]) then
		self.dirty_stuff[context[aspect]] = true
	end
end

function SceneGenEditor:AddEditableOptions(ui, params)
	TheSim:ProfilerPush("SceneGenEditor")

	local was_dirty = next(self.dirty_stuff)
	local live_edit = self.active_scene_gen == self.prefabname

	local id = "##SceneGenEditor"

	self:PushGreenButtonColor(ui)
	if ui:Button(ui.icon.image..id, nil, nil, not (live_edit and was_dirty)) then
		self:RefreshScene()
	end
	ui:SetTooltipIfHovered("Refresh Scene")
	self:PopButtonColor(ui)

	ui:SameLineWithSpace()
	if live_edit then
		ui:TextColored(RGB(0, 255, 0), "Live-edit is enabled")
		ui:SameLine()
		ui:Text(" because "..self.active_scene_gen.." is ")
		ui:SameLine()
		ui:TextColored(BGCOLORS.CYAN, "loaded")
		ui:SameLine()
		ui:Text(" and ")
		ui:SameLine()
		ui:TextColored(BGCOLORS.PURPLE, "active.")
	else
		ui:TextColored(BGCOLORS.RED, "Live-edit is disabled")
		ui:SameLine()
		ui:Text(" because ")
		ui:SameLine()
		ui:TextColored(BGCOLORS.CYAN, self.prefabname)
		ui:SameLine()
		ui:Text(" is ")
		ui:SameLine()
		ui:TextColored(BGCOLORS.CYAN, "loaded")
		ui:SameLine()
		ui:Text(" but ")
		ui:SameLine()
		ui:TextColored(BGCOLORS.PURPLE, self.active_scene_gen or "nil")
		ui:SameLine()
		ui:Text(" is ")
		ui:SameLine()
		ui:TextColored(BGCOLORS.PURPLE, "active.")
		ui:Text("Reload Arena in Preview Parameters to enable live-edit for ")
		ui:SameLine()
		ui:TextColored(BGCOLORS.CYAN, self.prefabname)
		ui:SameLine()
		ui:Text(".")
		ui:Text("Load ")
		ui:SameLine()
		ui:TextColored(BGCOLORS.PURPLE, self.active_scene_gen or "nil")
		ui:SameLine()
		ui:Text(" into SceneGenEditor to live-edit it.")
	end

	if self:CanVisualizePlacements() then
		TheSim:ProfilerPush("VisualizePlacements")
		local changed, visualize_placements = ui:Checkbox("Visualize Placements"..id, self.visualize_placements)
		if changed then
			self:VisualizePlacements(visualize_placements)
		end
		ui:SetTooltipIfHovered("Visualize Placements")
		TheSim:ProfilerPop()
	end

	TheSim:ProfilerPush("Preview")
	self:PreviewUi(ui, id.."Preview")
	TheSim:ProfilerPop()

	local changed

	local biomes = Lume(Biomes.regions):keys():result()
	if not params.biome then
		params.biome = biomes[1]
		self.dirty_stuff.biomes = true
	end
	local new_biome
	changed, new_biome = ui:ComboAsString("Biome"..id, params.biome, biomes)
	if changed then
		params.biome = new_biome
		self.dirty_stuff.biomes = true
	end

	local dungeons = Lume(Biomes.regions[params.biome].locations):keys():result()
	if not params.dungeon then
		params.dungeon = dungeons[1]
		self.dirty_stuff.dungeon = true
	end
	local new_dungeon
	changed, new_dungeon = ui:ComboAsString("Dungeon"..id, params.dungeon, dungeons)
	if changed then
		params.dungeon = new_dungeon
		self.dirty_stuff.dungeon = true
	end

	local new_tier
	changed, new_tier = ui:SliderInt("Tier", params.tier or 1, 1, SceneGen.TIER_COUNT)
	if changed then
		params.tier = new_tier
		self.dirty_stuff.tier = true
	end

	self.arena_loader.location = params.dungeon

	local tile_groups = Lume(GroundTiles.TileGroups):keys():result()
	if not params.tile_group then
		params.tile_group = tile_groups[1]
		self.dirty_stuff.tile_group = true
	end
	local new_tile_group
	changed, new_tile_group = ui:ComboAsString("Tile Group"..id, params.tile_group, tile_groups)
	if changed then
		params.tile_group = new_tile_group
		self.dirty_stuff.tile_group = true
	end

	local solo_zone_gen = self.solo_zone_gen

	TheSim:ProfilerPush("ZoneGens")
	self:DetectChanges("zone_gens", params, function()
		ListUi(self, params, ui, id, {
			title = "Zone Gens",
			name = "zone_gens",
			clipboard_context = ZONE_GEN_CLIPBOARD_CONTEXT,
			InlineUi = function(ui, id, zone_gen, zone_gen_index)
				local solo = self.solo_zone_gen == zone_gen_index
				local solo_button = solo
					and ui.icon.star_filled
					or ui.icon.star_empty
				if ui:Button(solo_button..id) then
					if solo then
						self.solo_zone_gen = nil
					else
						self.solo_zone_gen =  zone_gen_index
					end
				end
				ui:SetTooltipIfHovered("Solo")

				-- Refresh/rebuild is enabled if we are not explicitly disabled AND solo is inactive, or this ZoneGen is being
				-- soloed.
				local enabled = zone_gen.enabled
					and (not self.solo_zone_gen or self.solo_zone_gen == zone_gen_index)

				ui:SameLineWithSpace()
				PushButtonColor(ui, WEBCOLORS.GREENYELLOW)
				-- if ui:Button(ui.icon.redo..id.."Refresh", nil, nil, not (enabled and self.dirty_stuff[zone_gen])) then
				if ui:Button(ui.icon.redo..id.."Refresh", nil, nil, not (live_edit and enabled and self.dirty_stuff[zone_gen])) then
					self:BuildZoneGen(zone_gen)
				end
				PopButtonColor(ui)
				ui:SetTooltipIfHovered("Refresh ZoneGen")

				ui:SameLineWithSpace()
				if ui:Button(ui.icon.edit..id.."Rebuild", nil, nil, not (live_edit and enabled)) then
					self:BuildZoneGen(zone_gen)
				end
				ui:SetTooltipIfHovered("Rebuild ZoneGen")

				ui:SameLineWithSpace()
				if ui:Button(ui.icon.remove..id.."Clear", nil, nil, not (live_edit and enabled)) then
					self:ClearZoneGen(zone_gen)
				end
				ui:SetTooltipIfHovered("Clear ZoneGen")

				return true -- We put something on the line.
			end,
			ElementUi = function(ui, id, zone_gen)
				local check_dirty = not self.dirty_stuff[zone_gen]
				local previous_zone_gen = check_dirty and deepcopy(zone_gen)
				zone_gen:Ui(self, ui, id)
				if check_dirty and not deepcompare(previous_zone_gen, zone_gen) then
					self.dirty_stuff[zone_gen] = true
				end
			end,
			ElementLabel = function(zone_gen) return zone_gen:GetLabel() end,
			EnableElement = function(zone_gen, i, enable)
				-- Only modify visibility if the 'solo' feature is inactive.
				if not self.solo_zone_gen or self.solo_zone_gen == i then
					self:HideZoneGen(zone_gen, not enable)
				end
			end,
			Construct = ZoneGen,
			Clone = ZoneGen.FromRawTable,
			features = UI_FEATURE_ENABLE | UI_FEATURE_ORDERED
		})
	end)
	TheSim:ProfilerPop()

	-- Update visibility of all zone_gens when the solo_zone_gen is touched.
	if solo_zone_gen ~= self.solo_zone_gen then
		if self.solo_zone_gen then
			for zone_gen_index, zone_gen in ipairs(params.zone_gens) do
				if zone_gen_index ~= self.solo_zone_gen then
					self:HideZoneGen(zone_gen, true)
				end
			end
			self:HideZoneGen(params.zone_gens[self.solo_zone_gen], false)
		else
			for _, zone_gen in ipairs(params.zone_gens) do
				self:HideZoneGen(zone_gen, not zone_gen.enabled)
			end
		end
	end

	TheSim:ProfilerPush("Rooms")
	self:DetectChanges("rooms", params, function()
		local rooms = params.rooms or {}
		params.rooms = rooms
		self:RoomsUi(ui, id, rooms)
	end)
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("CreatureSpawners")
	self:DetectChanges("creature_spawners", params, function()
		ListUi(self, params, ui, id, {
			title = "Creature Spawners",
			name = "creature_spawners",
			element_editor = "PropEditor",
			browser_context = PrefabBrowserContext.id.CreatureSpawner,
			ElementUi = function(ui, id, creature_spawner)
				local sole_occupant = creature_spawner.sole_occupant_radius or false
				local sole_occupant_radius = creature_spawner.sole_occupant_radius or 1
				sole_occupant = ui:_Checkbox("Sole Occupant"..id, sole_occupant)
				if sole_occupant then
					ui:SameLineWithSpace()
					ui:SetNextItemWidth(200)
					creature_spawner.sole_occupant_radius = ui:_DragFloat("Radius"..id, sole_occupant_radius, 0.01, 0.1, 5)
				else
					creature_spawner.sole_occupant_radius = nil
				end

				if not creature_spawner.color then
					creature_spawner.color = Hsb()
				end
				local new_color = creature_spawner.color:Ui(ui, id)
				if new_color then
					creature_spawner.color = new_color
				end
			end,
			ElementLabel = function(creature_spawner) return creature_spawner.prop end,
			features = UI_FEATURE_INLINE_MANIPULATORS | UI_FEATURE_NESTED,
		})
	end)
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("Destructibles")
	self:DetectChanges("destructibles", params, function()
		ListUi(self, params, ui, id, {
			title = "Destructibles",
			name = "destructibles",
			element_editor = "PropEditor",
			browser_context = PrefabBrowserContext.id.Destructible,
			ElementUi = function(ui, id, destructible)
				DungeonProgress.Ui(ui,id.."DungeonProgressConstraintsUi", destructible)
			end,
			ElementLabel = function(destructible) return destructible.prop end,
			features = UI_FEATURE_INLINE_MANIPULATORS
		})
	end)
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("ParticleSystems")
	self:DetectChanges("particle_systems", params, function()
		ListUi(self, params, ui, id, {
			title = "Particle Systems",
			name = "particle_systems",
			element_editor = "ParticleEditor",
			browser_context = PrefabBrowserContext.id.RoomParticleSystem,
			clipboard_context = PARTICLE_SYSTEM_CLIPBOARD_CONTEXT,
			ElementUi = function(ui, id, particle_system)
				ui:Text("Particle System: "..particle_system.particle_system)
				ui:SameLineWithSpace()
				if ui:Button(ui.icon.search..id) then
					self.browser:Open(ui, PrefabBrowserContext.id.RoomParticleSystem)
				end
				ui:SetTooltipIfHovered("Choose different particle system")
				DungeonProgress.Ui(ui, id.."DungeonProgressConstraintsUi", particle_system)
				ParticleSystem.LayerOverrideUi(ui, id .. "LayerOverride", particle_system)
			end,
			ElementLabel = function(element) return element.particle_system end,
			Construct = function() return { enabled = true } end,
			Clone = SceneParticleSystem.FromRawTable,
			features = UI_FEATURE_ENABLE | UI_FEATURE_ORDERED
		})
	end)
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("UnderlayProps")
	self:DetectChanges("underlay_props", params, function()
		ListUi(self, params, ui, id, {
			title = "Underlay",
			name = "underlay_props",
			element_editor = "PropEditor",
			browser_context = PrefabBrowserContext.id.UnderlayProp,
			clipboard_context = UNDERLAY_CLIPBOARD_CONTEXT,
			ElementUi = function(ui, id, prop)
				self.selected_underlay_color_variant = prop:Ui(ui, id, self.browser, self.selected_underlay_color_variant)
			end,
			ElementLabel = function(element) return element.prop end,
			Construct = UnderlayPropGen,
			Clone = UnderlayPropGen.FromRawTable,
			features = UI_FEATURE_ENABLE | UI_FEATURE_ORDERED
		})
	end)
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("Environments")
	local ENVIRONMENTS_CLIPBOARD_CONTEXT = "++ENVIRONMENTS_CLIPBOARD_CONTEXT"

	local function NewEnvironment(from)
		return {
			label = from and from.label or "<NewEnvironment>",
			sky = from and from.sky or {},
			lighting = from and from.lighting or {},
			water = from and from.water or {},
			room_types =  from and from.room_types or deepcopy(PropProcGen.RoomType:Ordered())
		}
	end

	-- Move old data into new environments table.
	if not params.environments then
		local default_environment = NewEnvironment(params)
		default_environment.label = "Default"
		params.environments = {
			default_environment
		}
		self:SetDirty()
	end

	self:DetectChanges("environments", params, function()
		ListUi(self, params, ui, id, {
			title = "Environments",
			name = "environments",
			clipboard_context = ENVIRONMENTS_CLIPBOARD_CONTEXT,
			ElementUi = function(ui, id, environment)
				local changed, label = ui:InputText("Label"..id, environment.label)
				if changed then
					environment.label = label
					self:SetDirty()
				end

				if ui:FlagRadioButtons("Room Types"..id, PropProcGen.RoomType:Ordered(), environment.room_types) then
					self:SetDirty()
				end

				TheSim:ProfilerPush("Sky")
				self:DetectChanges("sky", environment, function()
					SkyUi(self, ui, environment.sky, true)
				end)
				TheSim:ProfilerPop()

				TheSim:ProfilerPush("Lighting")
				self:DetectChanges("lighting", environment, function()
					LightingUi(self, ui, environment.lighting, true)
				end)
				TheSim:ProfilerPop()

				TheSim:ProfilerPush("Water")
				self:DetectChanges("water", environment, function()
					WaterUi(self, ui, environment.water, true)
				end)
				TheSim:ProfilerPop()
			end,
			ElementLabel = function(environment) return environment.label.."###"..id end,
			Construct = NewEnvironment,
			Clone = NewEnvironment,
			features = UI_FEATURE_ORDERED
		})
	end)
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("AllProps")
	PushHeaderColor(ui, WEBCOLORS.PURPLE)
	if ui:CollapsingHeader("All Props (Read Only)") then
		ui:Indent()
		local props = {}
		local scene_gen = self:GetSceneGen()
		for _, zone_gen in ipairs(scene_gen.zone_gens) do
			for _, prop in ipairs(zone_gen.scene_props) do
				props[prop:GetLabel()] = true
			end
		end
		Lume(props):keys():sort():each(function(prop) ui:Text(prop) end)
		ui:Unindent()
	end
	PopHeaderColor(ui)
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("DesignData")
	PushHeaderColor(ui, WEBCOLORS.PURPLE)
	if ui:CollapsingHeader("Design Data (Read Only)") then
		ui:Indent()
		local location = Biomes.locations[params.dungeon]
		if ui:CollapsingHeader("Biome Location (biomes.lua)") then
			ui:Indent()
			ShowTable(ui, location, "##BiomeLocation")
			ui:Unindent()
		end
		local map_gen = MapGen.biomes[params.dungeon]
		if ui:CollapsingHeader("Map Gen (mapgen.lua)") then
			ui:Indent()
			ShowTable(ui, map_gen, "##MapGen")
			ui:Unindent()
		end
		local encounters = Encounters._biome[params.dungeon]
		if ui:CollapsingHeader("Encounters (encounters.lua)") then
			ui:Indent()
			ShowTable(ui, encounters, "##Encounters")
			ui:Unindent()
		end
		if ui:CollapsingHeader("Encounter Waves (encounter.waves.lua)") then
			ui:Indent()
			local adaptive_waves = Waves.adaptive.biome[params.dungeon]
			if adaptive_waves and ui:CollapsingHeader("Adaptive") then
				ui:Indent()
				ShowTable(ui, adaptive_waves, "##AdaptiveWaves")
				ui:Unindent()
			end
			local trap_waves = Waves.trapwaves.biome[params.dungeon]
			if trap_waves and ui:CollapsingHeader("Trap") then
				ui:Indent()
				ShowTable(ui, trap_waves, "##TrapWaves")
				ui:Unindent()
			end
			ui:Unindent()
		end
		ui:Unindent()
	end
	PopHeaderColor(ui)
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("Error")
	ui:ErrorModal()
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("Browser")
	self.browser:ModalUi(ui, id)
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("PropRefs")
	self.prop_refs:ModalUi(ui, id)
	TheSim:ProfilerPop()

	-- It is bad form to just run this regardless of whether or not we've changed anything. It costs a lot of cpu.
	local is_dirty = next(self.dirty_stuff)
	if is_dirty and not was_dirty then
		TheSim:ProfilerPush("SetDirty")
		self:SetDirty()
		TheSim:ProfilerPop()
	end

	TheSim:ProfilerPop()
end

-- Implementing Background interface:
function SceneGenEditor:CanEditSkyGradient(_ui)
	return true
end

-- Implementing Background interface:
function SceneGenEditor:RefreshLighting( _lighting)
end

-- Implementing Background interface:
function SceneGenEditor:RefreshSky(_sky)
end

-- Implementing LightingUi interface:
function SceneGenEditor:OnColorCubeChanged(scene_gen_name, lighting)
	local assets = {}
	CollectAssetsForColorCube(assets, lighting.colorcube.entrance)
	CollectAssetsForColorCube(assets, lighting.colorcube.boss)
	for i = 1, #assets do
		self:AppendPrefabAsset(scene_gen_name, assets[i])
	end
end

-- Implementing LightingUi interface:
function SceneGenEditor:OnRampTextureChanged(scene_gen_name, lighting)
	local assets = {}
	CollectAssetsForCliffRamp(assets, lighting.clifframp)
	for i = 1, #assets do
		self:AppendPrefabAsset(scene_gen_name, assets[i])
	end
end

-- Implementing LightingUi interface:
function SceneGenEditor:OnSkirtTextureChanged(scene_gen_name, lighting)
	local assets = {}
	CollectAssetsForCliffSkirt(assets, lighting.cliffskirt)
	for i = 1, #assets do
		self:AppendPrefabAsset(scene_gen_name, assets[i])
	end
end

-- Implementing Water interface:
function SceneGenEditor:RefreshWater(scene_gen_name, _water)
end

-- Implementing Water interface:
function SceneGenEditor:OnWaterRampTextureChanged(scene_gen_name, water)
	local assets = {}
	CollectAssetsForWaterRamp(assets, water.water_settings and water.water_settings.ramp)
	for i = 1, #assets do
		self:AppendPrefabAsset(scene_gen_name, assets[i])
	end
end

function SceneGenEditor:ReloadArena()
	-- TODO @chrisp #scenegen - arena_loader.desired_progress will not be applied, but we would like it to
	if not self.arena_loader:StartArena(true) then
		return
	end
	self:ReopenNodeAfterReset()
	self.load_queue = {}
	self.dirty_stuff = {}
end

-- Ui to control preview parameters.
function SceneGenEditor:PreviewUi(ui, id)
	PushHeaderColor(ui,  WEBCOLORS.LIGHTSEAGREEN)
	local preview = ui:CollapsingHeader("Preview Parameters"..id)
	PopHeaderColor(ui)
	if not preview then
		return
	end

	ui:Indent()
	self:PushGreenButtonColor(ui)
	local can_start, reason = self.arena_loader:CanStartArena()
	local disabled = not can_start or self:IsDirty()
	local reload_arena = ui:Button("Reload Arena"..id, nil, nil, disabled)
	if disabled then
		if self:IsDirty() then
			ui:SetTooltipIfHovered("Save or Reset and then you can Reload Arena")
		end
		if not can_start then
			ui:SetTooltipIfHovered("Can't Reload Arena because: "..reason)
		end
	end
	self:PopButtonColor(ui)
	if disabled then
		ui:SetTooltipIfHovered("Save or Revert to enable")
	else
		ui:SetTooltipIfHovered("Reload arena level and encounter")
	end
	if reload_arena and can_start then
		self:ReloadArena()
		return
	end
	local scene_gen = self:GetSceneGen()
	local previous_dungeon_progress = self.arena_loader.desired_progress
	self.arena_loader.levelname = ui:_ComboAsString("Level", self.arena_loader.levelname, scene_gen.rooms or {})
	self.arena_loader:Ui(ui, id, true)
	if previous_dungeon_progress ~= self.arena_loader.desired_progress then
		self.dirty_stuff[scene_gen] = true
	end
	ui:Unindent()
end

function SceneGenEditor:RoomsUi(ui, id, rooms)
	local have_errors = next(self.rooms_errors) ~= nil
	if have_errors then
		PushHeaderColor(ui, WEBCOLORS.RED)
	end

	if not ui:CollapsingHeader("Rooms"..id) then
		if have_errors then
			PopHeaderColor(ui)
		end
		return
	end

	id = id.."Rooms"

	ui:Indent()

	if have_errors then
		if ui:CollapsingHeader("Errors"..id) then
			ui:Indent()
			for _, error in ipairs(self.rooms_errors) do
				ui:Text(error)
			end
			ui:Unindent()
		end
		PopHeaderColor(ui)
	end

	local function RoomUi(i, room)
		local id = id..room..i

		if ui:Button(imgui.icon.remove..id) then
			local index = Lume(rooms):find(room):result()
			table.remove(rooms, index)
			self:RefreshRoomsErrors()
		end
		ui:SetTooltipIfHovered("Remove "..room)

		ui:SameLineWithSpace()
		if ui:Button(ui.icon.folder .. id) then
			DebugNodes.WorldEditor:FindOrCreateEditor(room)
		end
		ui:SetTooltipIfHovered("Open "..room.." in WorldEditor")

		ui:SameLineWithSpace()
		ui:Text(room)
	end

	if ui:CollapsingHeader("By Exits"..id) then
		ui:Indent()
		local id = id.."ByExits"

		local rooms_by_exits = {}
		for _, room in ipairs(rooms) do
			local _, exits = room:match("([%a_]+)_(%a+)")
			if exits then
				local category = rooms_by_exits[exits] or {}
				table.insert(category, room)
				rooms_by_exits[exits] = category
			end
		end

		Lume(rooms_by_exits):keys():sort():each(function(exits)
			local id = id..exits
			if ui:CollapsingHeader(exits..id) then
				ui:Indent()
				ui:AutoTable(nil, rooms_by_exits[exits], RoomUi, nil, 2)
				if ui:Button(ui.icon.add .. id) then
					local MatchExits = function(browser_element)
						local _, candidate_exits = browser_element.__displayName:match("([%a_]+)_(%a+)")
						return candidate_exits == exits
					end
					self.browser:Open(ui, PrefabBrowserContext.id.Room, MatchExits)
				end
				ui:SetTooltipIfHovered("Add '"..exits.."' Room")
				ui:Unindent()
			end
		end)

		ui:Unindent()
	end

	if ui:CollapsingHeader("By Room Category"..id) then
		ui:SetTooltipIfHovered({
				"These are guessed room categories based on names. These are not WorldMap roomtypes.",
				"They're naming suffixes for different kinds of rooms."
			})
		ui:Indent()
		local id = id.."ByRoomCategory"

		local rooms_by_type = {}
		for _, room in ipairs(rooms) do
			local _, room_type, _ = room:match("([%a_]+)_(%a+)_(%a+)")
			if room_type then
				local category = rooms_by_type[room_type] or {}
				table.insert(category, room)
				rooms_by_type[room_type] = category
			end
		end

		Lume(rooms_by_type):keys():sort():each(function(room_type)
			local id = id..room_type
			if ui:CollapsingHeader(room_type..id) then
				ui:Indent()
				ui:AutoTable(nil, rooms_by_type[room_type], RoomUi, nil, 2)
				if ui:Button(ui.icon.add .. id) then
					local MatchRoomCategory = function(browser_element)
						local _, candidate_room_type, _ = browser_element.__displayName:match("([%a_]+)_(%a+)_(%a+)")
						return candidate_room_type == room_type
					end
					self.browser:Open(ui, PrefabBrowserContext.id.Room, MatchRoomCategory)
				end
				ui:SetTooltipIfHovered("Add '"..room_type.."' Room")
				ui:Unindent()
			end
		end)

		ui:Unindent()
	end

	ui:AutoTable("All"..id, rooms, RoomUi, 2);

	if ui:Button(ui.icon.add .. id) then
		self.browser:Open(ui, PrefabBrowserContext.id.Room)
	end
	ui:SetTooltipIfHovered("Add Room")

	ui:Unindent()
end

function SceneGenEditor:GatherRoomsErrors(rooms)
	-- Require a room with each exits scheme for each room type.
	local map_gen_room_types = {"arena", "small"}
	local exit_schemas = {"nw", "new", "nsw", "nesw", "ew", "esw", "sw"}
	local map_gen_errors = {}
	for _, room_type in ipairs(map_gen_room_types) do
		for _, exits in ipairs(exit_schemas) do
			local found = false
			for _, room in ipairs(rooms) do
				local _, candidate_room_type, candidate_exits = room:match("([%a_]+)_(%a+)_(%a+)")
				if candidate_room_type == room_type and candidate_exits == exits then
					found = true
					break
				end
			end
			if not found then
				table.insert(map_gen_errors, "Missing room of type '"..room_type.."' with exits '"..exits.."'.")
			end
		end
	end

	-- Need at least one each of start, hype, and boss rooms.
	local special_room_types = {"start", "hype", "boss"}
	local special_errors = {}
	for _, room_type in ipairs(special_room_types) do
		local found = false
		for _, room in ipairs(rooms) do
			local _, candidate_room_type, _ = room:match("([%a_]+)_(%a+)_(%a+)")
			if candidate_room_type == room_type then
				found = true
				break
			end
		end
		if not found then
			table.insert(map_gen_errors, "Missing room of type '"..room_type.."'.")
		end
	end

	return table.appendarrays(map_gen_errors, special_errors)
end

function SceneGenEditor:RefreshRoomsErrors()
	local scene_gen = self:GetSceneGen()
	self.rooms_errors = (scene_gen and scene_gen.rooms)
		and self:GatherRoomsErrors(scene_gen.rooms)
		or {}
end

-- Ui for element presented via the PrefabBrowser.
function SceneGenEditor:BrowserElementUi(ui, id, browser_element)
	local scene_gen = self:GetSceneGen()
	if self.browser.context == PrefabBrowserContext.id.Prop then
		local zone_gen = self:GetZoneGen()
		if zone_gen then
			if ui:Button(ui.icon.add..id) then
				local scene_props = zone_gen.scene_props
				if not scene_props then
					scene_props = {}
					zone_gen.scene_props = scene_props
				end
				table.insert(scene_props, SceneProp(browser_element, self:GetZoneGen()))
				table.insert(self.load_queue, browser_element)
				self.dirty_stuff[zone_gen] = true
			end
			ui:SetTooltipIfHovered("Add prop to ZoneGen")

			local scene_prop = self:GetSceneProp()
			if scene_prop and scene_prop.prop ~= browser_element then
				ui:SameLineWithSpace()
				if ui:Button(ui.icon.undo..id) then
					scene_prop.prop = browser_element
					self.dirty_stuff[zone_gen] = true
				end
				ui:SetTooltipIfHovered("Replace prop with this one")
			end

			return true -- Yes, we put a button on the line.
		end
	elseif self.browser.context == PrefabBrowserContext.id.UnderlayProp then
		if ui:Button(ui.icon.add..id) then
			table.insert(scene_gen.underlay_props, UnderlayPropGen(browser_element))
			table.insert(self.load_queue, browser_element)
			self.dirty_stuff.underlay_props = true
		end
		ui:SetTooltipIfHovered("Add underlay prop")

		local underlay_prop = self:GetUnderlayProp()
		if underlay_prop and underlay_prop.prop ~= browser_element then
			ui:SameLineWithSpace()
			if ui:Button(ui.icon.undo..id) then
				underlay_prop.prop = browser_element
				self.dirty_stuff.underlay_props = true
			end
			ui:SetTooltipIfHovered("Replace underlay prop with this one")
		end

		return true -- Yes, we put a button on the line.
	elseif self.browser.context == PrefabBrowserContext.id.Destructible then
		local destructibles = scene_gen.destructibles or {}
		local found = Lume(destructibles)
			:any(function(destructible) return destructible.prop == browser_element end)
			:result()
		local add = ui:Button(ui.icon.add..id, nil, nil, found)
		if found then
			ui:SetTooltipIfHovered("Destructible already added")
		else
			ui:SetTooltipIfHovered("Add destructible to SceneGen")
		end
		if not found and add then
			local prop_prefab = PropAutogenData[browser_element]
			local destructible = {
				prop = browser_element,
				dungeon_progress_constraints = (prop_prefab.proc_gen and prop_prefab.proc_gen.dungeon_progress_constraints)
					and deepcopy(prop_prefab.proc_gen.dungeon_progress_constraints)
					or DungeonProgress.DefaultConstraints()
			}
			table.insert(destructibles, destructible)
			scene_gen.destructibles = destructibles
			table.insert(self.load_queue, browser_element)
			self.dirty_stuff.destructibles = true
		end
		return true -- Yes, we put a button on the line.
	elseif self.browser.context == PrefabBrowserContext.id.ParticleSystem
		or self.browser.context == PrefabBrowserContext.id.RoomParticleSystem
	then
		-- Resolve the context in which we are considering particle systems.
		local particle_systems
		local add_tooltip
		local context
		if self.browser.context == PrefabBrowserContext.id.ParticleSystem then
			local zone_gen = self:GetZoneGen()
			if not zone_gen then
				return false
			end
			particle_systems = zone_gen.particle_systems
			context = zone_gen
			add_tooltip = "Add particle system to ZoneGen"
		else
			particle_systems = scene_gen.particle_systems
			context = scene_gen
			add_tooltip = "Add particle system to SceneGen"
		end

		if ui:Button(ui.icon.add .. id) then
			if not particle_systems then
				particle_systems = {}
				context.particle_systems = particle_systems
			end
			local added
			if self.browser.context == PrefabBrowserContext.id.ParticleSystem then
				added = SceneParticleSystem(browser_element, self:GetParticleSystem())
			else
				added = { particle_system = browser_element, enabled = true }
			end
			table.insert(particle_systems, added)
			table.insert(self.load_queue, browser_element)
			self.dirty_stuff.particle_systems = true
		end
		ui:SetTooltipIfHovered(add_tooltip)

		local particle_system
		if self.browser.context == PrefabBrowserContext.id.ParticleSystem then
			particle_system = self:GetParticleSystem()
		else
			particle_system = scene_gen.particle_systems[self.selected_particle_system]
		end
		if particle_system and particle_system.particle_system ~= browser_element then
			ui:SameLineWithSpace()
			if ui:Button(ui.icon.undo .. id) then
				particle_system.particle_system = browser_element
				self.dirty_stuff.particle_systems = true
			end
			ui:SetTooltipIfHovered("Replace particle system with this one")
		end

		return true -- Yes, we put a button on the line.
	elseif self.browser.context == PrefabBrowserContext.id.CreatureSpawner then
		local role = PropAutogenData[browser_element].script_args.spawner_type:match("spawner_(%a+)")
		local creature_spawners = scene_gen.creature_spawners[role] or {}
		local found = Lume(creature_spawners)
			:any(function(creature_spawner) return creature_spawner.prop == browser_element end)
			:result()
		local add = ui:Button(ui.icon.add..id, nil, nil, found)
		if found then
			ui:SetTooltipIfHovered("Creature spawner already added")
		else
			ui:SetTooltipIfHovered("Add creature spawner to SceneGen")
		end
		if not found and add then
			table.insert(creature_spawners, {
				prop = browser_element,
				color = Hsb()
			})
			scene_gen.creature_spawners[role] = Lume(creature_spawners)
				:sort(function(a, b) return a.prop < b.prop end)
				:result()
			table.insert(self.load_queue, browser_element)
			self.dirty_stuff.creature_spawners = true
		end
		return true -- Yes, we put a button on the line.
	elseif self.browser.context == PrefabBrowserContext.id.Room then
		local rooms = scene_gen.rooms or {}
		local found = Lume(rooms)
			:any(function(room) return room == browser_element end)
			:result()
		local add = ui:Button(ui.icon.add..id, nil, nil, found)
		if found then
			ui:SetTooltipIfHovered("Room already added")
		else
			ui:SetTooltipIfHovered("Add room to SceneGen")
		end
		if not found and add then
			table.insert(rooms, browser_element)
			scene_gen.rooms = rooms
			self.dirty_stuff.rooms = true
			self:RefreshRoomsErrors()
		end
		return true -- Yes, we put a button on the line.
	else
		assert(false, "Unhandled browser context: "..self.browser.context);
	end
	return false -- Nope. We didn't draw any ui.
end

-- Return a list of entities that lie within the specified zones.
function SceneGenEditor:CollectZoneDecor(zone_gen)
	local zone_grid = self:GetZoneGrid()
	if not zone_grid then
		return {}
	end
	local zones = zone_gen.zones
	-- local decor_layer = zone_gen.decor_layer or DecorLayer.s.Ground
	local decor_tag = zone_gen.tag
	-- local decor_tag = DecorTags[DecorLayer.id[decor_layer]]
	local decor = {}
	for _, entity in pairs(Ents) do
		if entity
			and entity:HasTag(decor_tag)
			and entity.Transform
		then
			local x, y, z = entity.Transform:GetWorldPosition()
			local grid_position = zone_grid:WorldToGrid({ x = x, y = y, z = z })
			if grid_position
				and Lume(zones)
					:any(function(zone)
						return zone_grid.position_filters[zone](grid_position.x, grid_position.z)
					end)
					:result()
			then
				table.insert(decor, entity)
			end
		end
	end
	return decor
end

function SceneGenEditor:HideZoneGen(zone_gen, hide)
	local decor = self:CollectZoneDecor(zone_gen)
	if hide then
		Lume(decor):each(function(decor_entity) decor_entity:Hide() end)
	else
		Lume(decor):each(function(decor_entity) decor_entity:Show() end)
	end
end

-- Invoked via PrefabEditorBase base class.
function SceneGenEditor:Test(name, scene_gen, count)
	self.dirty_stuff[scene_gen] = true
	self.solo_zone_gen = nil
	self:RefreshScene()
end

-- Collect and return all seed dependencies, including the original zone_gens, recursively determined.
function SceneGenEditor:CollectZoneDependencies(zone_gens)
	local zones = {}
	for _, decor_layer in ipairs(DecorLayer:Ordered()) do
		zones[decor_layer] = {}
	end
	for _, zone_gen in ipairs(zone_gens) do
		zones[zone_gen.decor_layer or DecorLayer.s.Ground] = table.appendarrays(zones, zone_gen.zones)
	end
	local enabled_zone_gens = Lume(self:GetSceneGen().zone_gens)
		:filter(function(zone_gen) return zone_gen.enabled end)
		:result()

	-- Build an ordered list of zone gens. Order is important for seeding to occur correctly.
	local dependencies = {}
	for _, zone_gen in ipairs(enabled_zone_gens) do
		if Lume(zone_gen.zones)
			:any(function(zone)
				return Lume(zones[zone_gen.decor_layer or DecorLayer.s.Ground])
					:values()
					:any(function(dirty_zone) return dirty_zone == zone end)
					:result()
			end)
			:result()
		then
			table.insert(dependencies, zone_gen)
		end
	end
	return dependencies
end

function SceneGenEditor:BuildZoneGen(zone_gen)
	self:BuildScene({zone_gen})
end

function SceneGenEditor:ClearZoneGen(zone_gen)
	for _, entity in pairs(self:CollectZoneDecor(zone_gen)) do
		if not entity:HasTag(SceneGen.ROOM_PARTICLE_SYSTEM_TAG) then
			entity:Remove()
		end
	end
end

-- Clear out the zones, then plan and build them. If underlay and room particle systems are
-- dirty, they will get rebuilt too.
function SceneGenEditor:BuildScene(
	zone_gens,
	suppress_dependencies,
	suppress_clean_up,
	underlay,
	room_particle_systems
)
	if not suppress_dependencies then
		zone_gens = self:CollectZoneDependencies(zone_gens)
	end

	-- Remove all decor in the dirty zone gens.
	for _, zone_gen in ipairs(zone_gens) do
		for _, entity in pairs(self:CollectZoneDecor(zone_gen)) do
			if not entity:HasTag(SceneGen.ROOM_PARTICLE_SYSTEM_TAG) then
				entity:Remove()
			end
		end
	end

	if underlay then
		-- Remove underlay props explicitly.
		local proxy_zone_gen = {
			zones = {PropProcGen.Zone.s.underlay},
			decor_layer = DecorLayer.s.Ground,
			tag = DecorTags[DecorLayer.id.Ground]
		}
		for _, entity in pairs(self:CollectZoneDecor(proxy_zone_gen)) do
			entity:Remove()
		end
	end

	if room_particle_systems then
		for _, entity in pairs(Ents) do
			if entity:HasTag(SceneGen.ROOM_PARTICLE_SYSTEM_TAG) then
				entity:Remove()
			end
		end
	end

	-- If we have added any props, load them.
	if next(self.load_queue) then
		TheSim:LoadPrefabs(self.load_queue)
		self.load_queue = {}
	end

	local scene_gen = self:GetSceneGen()
	SceneGen.StaticBuildScene(
		scene_gen,
		TheWorld,
		self.arena_loader.desired_progress,
		{},
		KRandom.CreateGenerator(), -- @chrisp #proc_rng
		self:GetZoneGrid(),
		self.arena_loader:GetRoomType(),
		zone_gens,
		underlay,
		room_particle_systems
	)

	-- Clean up.
	if not suppress_clean_up then
		for _, zone_gen in ipairs(zone_gens) do
			self.dirty_stuff[zone_gen] = nil
		end
	end
	if underlay then
		self.dirty_stuff[scene_gen.underlay_props] = nil
	end
	if room_particle_systems then
		self.dirty_stuff[scene_gen.particle_systems] = nil
	end
end

-- Rebuild only the parts of the scene controlled by dirty aspects of the SceneGen.
function SceneGenEditor:RefreshScene()
	local scene_gen = self:GetSceneGen()
	local all_dirty = self.dirty_stuff[scene_gen]
	if all_dirty then
		self:BuildScene(
			scene_gen.zone_gens,
			true,
			true,
			true,
			true
		)
	else
		local dirty_zone_gens = Lume(scene_gen.zone_gens)
			:filter(function(zone_gen) return zone_gen.enabled and self.dirty_stuff[zone_gen] end)
			:result()
		self:BuildScene(
			dirty_zone_gens,
			false,
			true,
			self.dirty_stuff[scene_gen.underlay_props],
			self.dirty_stuff[scene_gen.particle_systems]
		)
	end
	self.dirty_stuff = {}
end

DebugNodes.SceneGenEditor = SceneGenEditor

return SceneGenEditor
