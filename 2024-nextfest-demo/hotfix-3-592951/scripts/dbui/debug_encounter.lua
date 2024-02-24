local DebugNodes = require "dbui.debug_nodes"
local DebugSettings = require "debug.inspectors.debugsettings"
local SpawnBalancer = require("spawnbalancer")
local biomes = require "defs.biomes"
local encounters = require "encounter.encounters"
local iterator = require "util.iterator"
local kassert = require "util.kassert"
local lume = require"util.lume"
local mapgen = require "defs.mapgen"
local scenegenutil = require "prefabs.scenegenutil"
require "consolecommands"
require "constants"


local _static = DebugNodes.DebugNode.MakeStaticDebugData("debug_encounter_data")

local DebugEncounter = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Encounter")
	self:SetStaticData(_static)
	self.sb = SpawnBalancer()
	self.test_options = DebugSettings("debug_encounter.test_options.")
		:Option("selected_difficulty_index", 1)
		:Option("selected_roomtype", "monster")
	self.encounter_cache = {}

	self.biome_name = "treemon_forest"
	if TheDungeon and TheDungeon:GetDungeonMap() then
		self.biome_name = TheDungeon:GetDungeonMap():GetBiomeLocation().id
	end
	self.sb.biome_location = biomes.locations[self.biome_name]
end)

DebugEncounter.PANEL_WIDTH = 600
DebugEncounter.PANEL_HEIGHT = 800

function DebugEncounter:OnChangedEncounterSet(new_difficulty_index, new_roomtype)
	if new_difficulty_index or new_roomtype then
		assert(new_difficulty_index and new_roomtype)
		self.test_options:Set("selected_difficulty_index", new_difficulty_index)
		self.test_options:Set("selected_roomtype", new_roomtype)
		self.test_options:Save()
	end
	self.view_encounter = nil
end

function DebugEncounter:OnIdealHealthChanged(value)
	self.static.data.ideal_health_values[self.test_options.selected_difficulty_index] = math.floor(value)
	self.static.dirty = true
end

function DebugEncounter:OnHealthGrowthChanged(value)
	self.static.data.growth_values[self.test_options.selected_difficulty_index] = value
	self.static.dirty = true
end

function DebugEncounter:RenderPanel( ui, panel )
	if not TheWorld or not TheWorld.components.spawncoordinator then
		ui:Text("Need a World with a SpawnCoordinator.")
		return
	end

	local biome_names = lume(biomes.locations)
		:filter(function(location)
			return location.has_combat
		end, true)
		:keys()
		:sort()
		:result()
	self.biome_name = ui:_ComboAsString("Biome", self.biome_name, biome_names)
	if self.sb.biome_location.id ~= self.biome_name then
		self.encounter_cache = {}
		self.sb.biome_location = biomes.locations[self.biome_name]

		-- Load the room we just selected
		local scenegen = self.sb.biome_location:GetSceneGen()
		local layouts = scenegenutil.FindLayoutsForRoomSuffix(scenegen, "_arena_nesw")
		local prefab = layouts and layouts[1]
		kassert.assert_fmt(prefab, "Failed to find destination room in scenegen[%s]. Is SceneGen configured for '%s'?", scenegen, self.biome_name)
		self:ReopenNodeAfterReset()
		d_loadroom(prefab, "empty", scenegen)
		return
	end
	self.biome_encounters = encounters.GetRoomTypeEncounters(self.sb.biome_location.id)

	if not self.sb.biome_location.has_combat then
		return
	end

	local worldmap = TheDungeon:GetDungeonMap()
	local in_biome_for_encounter = self.biome_name == worldmap:GetBiomeLocation().id

	local difficulties = self:GetSortedEncounterDifficulties()

	if TheWorld.components.spawncoordinator and TheWorld.components.spawncoordinator.encounter_idx then
		local room_difficulty = worldmap:GetDifficultyForCurrentRoom()
		local roomtype = worldmap.nav:get_roomtype(worldmap:Debug_GetCurrentRoom())
		ui:Text(string.format("Current Room Encounter: %s %s encounter %s", difficulties[room_difficulty], roomtype, TheWorld.components.spawncoordinator.encounter_idx))
		if ui:Button("View Encounter") then
			self:OnChangedEncounterSet(room_difficulty, roomtype)
			self.view_encounter = TheWorld.components.spawncoordinator.encounter_idx
		end
		ui:Separator()
	end

	if self.test_options:Enum(ui, "Roomtype", "selected_roomtype", lume.keys(self.biome_encounters)) then
		self:OnChangedEncounterSet()
	end

	local new_difficulty_index = ui:_Combo("Encounter Difficulty", self.test_options.selected_difficulty_index, difficulties)
	ui:SameLineWithSpace()
	if ui:Button(ui.icon.playback_step_fwd .."##difficulty", ui.icon.width) then
		new_difficulty_index = circular_index_number(#difficulties, self.test_options.selected_difficulty_index + 1)
	end
	if new_difficulty_index ~= self.test_options.selected_difficulty_index then
		self:OnChangedEncounterSet(new_difficulty_index, self.test_options.selected_roomtype)
	end

	if ui:CollapsingHeader("Tuning Values") then
		-- local changed, new_value = ui:InputText("Ideal Health Value", self.static.data.ideal_health_values[self.test_options.selected_difficulty_index], imgui.InputTextFlags.CharsNoBlank)
		local changed, new_value = ui:SliderInt("Ideal Health Value (Start)", self.static.data.ideal_health_values[self.test_options.selected_difficulty_index] or 0, 1000, 10000)
		if changed then
			local new_val = tonumber(new_value)
			if new_val then
				self:OnIdealHealthChanged(new_val)
			end
		end
		-- How much % more should total health be in last room compared to start room?
		local changed, v = ui:SliderFloat("Health Growth By Last Room (Multiplier)", self.static.data.growth_values[self.test_options.selected_difficulty_index] or 1, 1, 5)
		if changed then
			local new_val = tonumber(v)
			if new_val then
				self:OnHealthGrowthChanged(new_val)
			end
		end

		-- How much variance is acceptable outside of Ideal Health Value, given our DungeonProgress?
		changed, v = ui:SliderInt("Acceptable Health Variance (%)", self.static.data.acceptable_variance, 0, 50)
		if changed then
			self.static.data.acceptable_variance = v
			self.static.dirty = true
		end
		if ui:Button("Save Debug Data", nil, nil, not self.static.dirty) then
			self:SaveDebugData()
		end
	end
	ui:Separator()
	local changed, v = ui:SliderFloat("Dungeon Progress", self.sb.dungeon_progress, 0, 1)
	if changed then
		self.sb.dungeon_progress = v
		lume.clear(self.encounter_cache)
	end
	ui:Text("Ideal Health Values:")--string.format("[%s%%] %s encounter %s", lume.round(amount_out_of_range * 100), difficulty_name, i))
	ui:Indent()
	for id,_ in pairs(difficulties) do
		local prog_mod = self.sb.dungeon_progress * (self.static.data.growth_values[id] - 1)
		local health = self.static.data.ideal_health_values[id]
		ui:Text(string.format("%s: %s", _, lume.round(health + (health * prog_mod))))
	end
	ui:Unindent()
	-- ui:SameLineWithSpace()
	if ui:Button("Stop Encounter") then
		d_clearroom()
	end
	ui:SameLineWithSpace()
	if ui:Button("Load Empty Room") then
		self:ReopenNodeAfterReset()
		local prefab = nil
		if TheDungeon:GetDungeonMap():IsCurrentRoomDungeonEntrance() then
			-- No spawners in entrance, pick a valid room.
			if self.biome_name == "kanft_swamp" then
				prefab = "swamp_arena_nesw"
			else
				prefab = "startingforest_arena_ew"
			end
		end
		d_loadempty(prefab)
	end
	if ui:IsItemHovered() then
		ui:SetTooltipMultiline{
			"Empty rooms are good for encounter testing",
			"because they won't spawn konjur or powers on clear.",
			"Will load the same room if it's valid for combat.",
		}
	end
	ui:SameLineWithSpace()
	if ui:Button("Reevaluate All") then
		lume.clear(self.encounter_cache)
	end

	ui:Separator()

	local selected_encounters = self:GetEncountersForDifficulty(self.test_options.selected_difficulty_index)

	if not selected_encounters then
		ui:Value("Difficulty has no encounters", difficulties[self.test_options.selected_difficulty_index])
		return
	end

	local acceptable_variance = self.static.data.acceptable_variance * 0.01

	local difficulty_name = difficulties[self.test_options.selected_difficulty_index]
	local ideal_health = self.static.data.ideal_health_values[self.test_options.selected_difficulty_index]

	-- Ideal Health changes over the course of a dungeon. The given Ideal Health Value is for the start  of the dungeon.
	-- See how far we are in the dungeon, and then apply how much % growth we should see
	local progress_modifier = self.sb.dungeon_progress * (self.static.data.growth_values[self.test_options.selected_difficulty_index] - 1)
	ideal_health = lume.round(ideal_health + (ideal_health * progress_modifier))

	local enemy_counts = {}
	local enemy_health_totals = {}
	local total_factor = 0

	for i, encounter in iterator.sorted_pairs(selected_encounters) do
		if encounter then
			local this_factor = encounter.factor and encounter.factor or 1
			total_factor = total_factor + this_factor
		end
	end

	for i, encounter in iterator.sorted_pairs(selected_encounters) do
		ui:PushID(i)
		if encounter then

			local encounter_debug = self.encounter_cache[encounter]
			if not encounter_debug then
				-- We cache encounters because some are randomly assembled and
				-- will flicker if we evaluate them every frame.
				encounter_debug = self.sb:EvaluateEncounter(i, encounter, ideal_health)
				self.encounter_cache[encounter] = encounter_debug
			end

			for prefab,count in pairs(encounter_debug.enemy_counts) do
				enemy_counts[prefab] = (enemy_counts[prefab] or 0) + count
			end
			for prefab,health in pairs(encounter_debug.enemy_health_totals) do
				enemy_health_totals[prefab] = (enemy_health_totals[prefab] or 0) + health
			end
			local out_of_range = encounter_debug.health_ratio > (1 + acceptable_variance) or encounter_debug.health_ratio < (1 - acceptable_variance)
			local amount_out_of_range = encounter_debug.health_ratio - 1
			local pop_colors = 0
			if next(encounter_debug.initial_scenario_errors) then
			    pop_colors = 4
				ui:PushStyleColor(ui.Col.Header, { 0.6, 0, 0, 1 })
				ui:PushStyleColor(ui.Col.HeaderHovered, { 0.6, .05, .05, 1 })
				ui:PushStyleColor(ui.Col.HeaderActive, { 0.6, 0, 0, 1 })
				ui:PushStyleColor(ui.Col.Text, WEBCOLORS.YELLOW)

			elseif out_of_range then
			    pop_colors = 3

			    if amount_out_of_range > 0 then
					local t = Remap(amount_out_of_range, 0, acceptable_variance * 3, 0, 1)
					ui:PushStyleColor(ui.Col.Header, { lume.lerp(0.3, 0.5, t), 0, 0, 1 })
					ui:PushStyleColor(ui.Col.HeaderHovered, { lume.lerp(.4, .6, t), .05, .05, 1 })
					ui:PushStyleColor(ui.Col.HeaderActive, { lume.lerp(0.5, .7, t), 0, 0, 1 })
			    else
					local t = Remap(amount_out_of_range, -(acceptable_variance * 3), 0, 1, 0)
					ui:PushStyleColor(ui.Col.Header, { 0, lume.lerp(0.3, 0.5, t), 0, 1 })
					ui:PushStyleColor(ui.Col.HeaderHovered, { .05, lume.lerp(.4, .6, t), .05, 1 })
					ui:PushStyleColor(ui.Col.HeaderActive, { 0, lume.lerp(0.5, .7, t), 0, 1 })
			    end
			end

			local this_factor = encounter.factor and encounter.factor or 1
			if ui:CollapsingHeader(string.format("[%s%%] %s encounter %s (chance %s%%)", lume.round(amount_out_of_range * 100), difficulty_name, i, lume.round((this_factor / total_factor) * 100)), i == self.view_encounter and ui.TreeNodeFlags.DefaultOpen or nil) then
				for _,label in ipairs(encounter_debug.initial_scenario_errors) do
					ui:Value("Initial scenario wave occurring after first wave", label)
				end

				ui:PopStyleColor(pop_colors)
				pop_colors = 0


				local is_valid_room = TheWorld.components.spawncoordinator and #TheWorld.components.spawncoordinator.spawners > 0 and not TheDungeon:GetDungeonMap():IsDebugMap() and not TheWorld:HasTag("town")
				local can_test_encounter = is_valid_room and in_biome_for_encounter

				if ui:Button("Reevaluate") then
					self.encounter_cache[encounter] = nil
				end

				ui:SameLineWithSpace()
				if ui:Button("Test Encounter", nil, nil, not can_test_encounter) then
					TheLog.ch.WorldMap:print("DebugEncounter: Overriding GetProgressThroughDungeon to force SpawnBalancer value.")
					TheDungeon:GetDungeonMap().nav.GetProgressThroughDungeon = function(_self)
						return self.sb.dungeon_progress
					end
					local spawncoordinator = TheWorld.components.spawncoordinator
					spawncoordinator:SetEncounterCleared(true, function()
						-- spawncoordinator.rng = krandom.LoadGenerator(encounter_debug.rng_state)
						spawncoordinator:StartCustomEncounter(encounter.exec_fn)
					end)
				end
				if not in_biome_for_encounter and ui:IsItemHovered() then
					ui:SetTooltip("Cannot test encounters outside your current biome since we wouldn't spawn the right creatures.")
				end
				if not is_valid_room then
					ui:SameLineWithSpace(10)
					ui:Text("You must be in a valid room to test encounters!")
				end

				ui:Text(string.format("Encounter %s Overview: (%s/%s) [%d%%]", i, encounter_debug.total_health, ideal_health, math.floor(encounter_debug.health_ratio * 100)))
				-- ui:Text(string.format("Total Enemy Health: %s/%s"))
				ui:Separator()
				ui:Text(string.format("Total Wave Count: %s", encounter_debug.wave_count))
				if ui:TreeNode(string.format("Wave Breakdown:")) then

					local wave_health_values = {}

					for wave_num, wave_data in ipairs(encounter_debug.wave_info) do
						ui:Text(string.format("%s", wave_data.wave_title))
						if wave_data.wave_health then
							table.insert(wave_health_values, wave_data.wave_health)
							for prefab, count in pairs(wave_data.wave_enemy_counts) do
								local health = wave_data.wave_enemy_health_totals[prefab]
								if health ~= nil then
									ui:Text(string.format("\t - %s : %s (%s Health)", prefab, count, health))
								else
									ui:Text(string.format("\t - %s : %s", prefab, count))
								end
							end
						end
						ui:Dummy(0, 2)
						ui:Separator()
						ui:Dummy(0, 2)
					end

					ui:PlotLines("Health Values", "", wave_health_values, 0, 0, 5000, 100, 50)

					ui:TreePop()
				end
				ui:Separator()
				ui:Text(string.format("Total Enemy Count: %s", encounter_debug.enemy_count))
				if ui:TreeNode(string.format("[Encounter %s] Enemy Breakdown:", i)) then
					for prefab, count in pairs(encounter_debug.enemy_counts) do
						ui:Text(string.format("\t - %s : %s", prefab, count))
					end
					ui:TreePop()
				end


			end
			ui:PopStyleColor(pop_colors)

		end

		ui:PopID()
	end

	ui:Spacing()
	if ui:CollapsingHeader("Possible Enemies in Difficulty ".. difficulty_name .."###enemy_counts") then
		ui:Indent()
		for prefab,count in iterator.sorted_pairs(enemy_counts) do
			ui:Text(prefab)
		end
		ui:Unindent()
	end
end

function DebugEncounter:GetSortedEncounterDifficulties()
	return mapgen.Difficulty:Ordered()
end

function DebugEncounter:GetEncountersForDifficulty(idx)
	local difficulties = self:GetSortedEncounterDifficulties()
	return self.biome_encounters[self.test_options.selected_roomtype][difficulties[idx]]
end

DebugNodes.DebugEncounter = DebugEncounter

return DebugEncounter
