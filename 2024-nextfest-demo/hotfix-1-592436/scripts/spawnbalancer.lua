local Enum = require "util.enum"
local SpawnCoordinator = require "components.spawncoordinator"
local kassert = require "util.kassert"
local krandom = require "util.krandom"
local kstring = require "util.kstring"
local lume = require "util.lume"
local waves = require "encounter.waves"
require "class"


-- Helper for DebugEncounter.
--
-- Try to keep functions in the same order as SpawnCoordinator to make it
-- easier to port them over here.
local SpawnBalancer = Class(function(self)
	self.total_encounter_health = 0
	self.total_encounter_enemies = 0
	self.num_enemy_waves = 0
	self.enemy_counts = {}
	self.enemy_health_totals = {}
	self.wave_info = {}
	self.dungeon_progress = TheWorld 
		and TheDungeon:GetDungeonMap().nav:GetProgressThroughDungeon()
		or 0.0
	self.rng = krandom.CreateGenerator()
	assert(self.rng)
end)

local Scenario = Enum{ "InitialSetup", "Combat" }

function SpawnBalancer:EvaluateEncounter(idx, encounter, target_health_amount)
	self.total_encounter_health = 0
	self.total_encounter_enemies = 0
	self.num_enemy_waves = 0
	self.num_encounter_steps = 0
	self.enemy_counts = {}
	self.enemy_health_totals = {}
	self.wave_info = {}

	-- Unfortunately, it's too complex to effectively reuse the state between
	-- SpawnBalancer and SpawnCoordinator. SpawnCoordinator calls random for
	-- many actual spawn decisions that aren't tracked in SpawnBalancer so
	-- spawn results are completely different.
	--~ local rng_state = self.rng:GetState()

	self.initial_scenario_errors = {}
	self.is_initial_scenario = true
	encounter.exec_fn(self)

	local acceptable_variance = 0.20
	local min_health = 1 - acceptable_variance
	local max_health = 1 + acceptable_variance
	local health_ratio = self.total_encounter_health/target_health_amount

	-- printf("Data For Wave %s (%d%% of health target)", idx, math.floor(health_ratio * 100) )
	-- -- dumptable(self.enemy_counts)

	-- if health_ratio < min_health or health_ratio > max_health then
	-- 	printf("Encounter [%s] total health was %d%% of expected amount (%s -> %s)", idx, math.floor(health_ratio * 100), target_health_amount, self.total_encounter_health)
	-- 	printf(" -- [%s] has %s enemies over %s waves", idx, self.total_encounter_enemies, self.num_enemy_waves)
	-- 	-- printf("[%s] Total Encounter Health: %s", idx, self.total_encounter_health)
	-- 	-- printf("[%s] Total Enemy Waves: %s", idx, self.num_enemy_waves)
	-- end


	local encounter_debug =
	{
		total_health = self.total_encounter_health,
		enemy_count = self.total_encounter_enemies,
		enemy_counts = shallowcopy(self.enemy_counts),
		enemy_health_totals = shallowcopy(self.enemy_health_totals),
		wave_count = self.num_enemy_waves,
		health_ratio = health_ratio,
		wave_info = deepcopy(self.wave_info),
		initial_scenario_errors = shallowcopy(self.initial_scenario_errors),
		--~ rng_state = rng_state,
	}

	return encounter_debug
end

function SpawnBalancer:GetRNG()
	return self.rng
end

--
-- Encounter API
--

function SpawnBalancer:GetProgressThroughDungeon()
	return self.dungeon_progress
end

function SpawnBalancer:StartSpawningFromHidingPlaces()
end

function SpawnBalancer:SpawnStationaryEnemies(wave, data)
	self:_RequireFirstWave("Stationary")
	self:_TrackWave("Stationary", wave, Scenario.id.InitialSetup)
end

function SpawnBalancer:SpawnMiniboss(wave, delay_between_spawns)
	self:_TrackWave("Miniboss", wave, Scenario.id.InitialSetup)
end

function SpawnBalancer:SpawnTraps(wave)
	self:_RequireFirstWave("Traps")
	self:_TrackWave("Traps", wave, Scenario.id.InitialSetup)
end

function SpawnBalancer:SpawnPropDestructibles(max_amount)
	self:_RequireFirstWave("PropDestructibles")
	self.num_encounter_steps = self.num_encounter_steps + 1
	local wave_info = {
		wave_title = string.format("[%s] Destructibles: %s", self.num_encounter_steps, max_amount)
	}
	self.wave_info[self.num_encounter_steps] = wave_info
	-- print("SpawnBalancer:SpawnPropDestructibles")
end

function SpawnBalancer:SpawnWave(wave, delay_between_spawns, delay_between_reuse)
	self:_TrackWave("Wave", wave, Scenario.id.Combat)
end

function SpawnBalancer:_RequireFirstWave(label)
	if not self.is_initial_scenario then
		table.insert(self.initial_scenario_errors, label)
	end
end

function SpawnBalancer:_TrackWave(label, wave, scenario)
	wave = waves.EnsureWave(wave)
	self.num_encounter_steps = self.num_encounter_steps + 1

	local wave_health, wave_enemies, wave_enemy_counts, wave_enemy_health_totals = self:GetWaveStats(wave)
	for prefab, count in pairs(wave_enemy_counts) do
		self.enemy_counts[prefab] = (self.enemy_counts[prefab] or 0) + count
	end

	for prefab, health in pairs(wave_enemy_health_totals) do
		self.enemy_health_totals[prefab] = (self.enemy_health_totals[prefab] or 0) + health
	end

	-- print("SpawnBalancer:SpawnWave:", wave_health)
	self.num_enemy_waves = self.num_enemy_waves + 1
	self.total_encounter_health = self.total_encounter_health + wave_health
	self.total_encounter_enemies = self.total_encounter_enemies + wave_enemies

	local wave_info =
	{
		wave_title = string.format("[%s] %s #%s (%s Health, %s Enemies)", self.num_encounter_steps, label, self.num_enemy_waves, wave_health, wave_enemies),
		wave_health = wave_health,
		wave_enemies = wave_enemies,
		wave_enemy_counts = wave_enemy_counts,
		wave_enemy_health_totals = wave_enemy_health_totals,
	}

	self.wave_info[self.num_encounter_steps] = wave_info
	self.is_initial_scenario = self.is_initial_scenario and scenario == Scenario.id.InitialSetup
end

SpawnBalancer.ApplySpawnMultiplierToListOfMobs = SpawnCoordinator.ApplySpawnMultiplierToListOfMobs
SpawnBalancer.FilterAdaptiveWaveByProgress = SpawnCoordinator.FilterAdaptiveWaveByProgress
SpawnBalancer.PopulateAndApplySpawnCountOverrides = SpawnCoordinator.PopulateAndApplySpawnCountOverrides
SpawnBalancer.GetCountForAdaptiveWave = SpawnCoordinator.GetCountForAdaptiveWave


function SpawnBalancer:GetCurrentAdaptiveWaveSize(difficulty)
	return self:GetCountForAdaptiveWave(difficulty, self.dungeon_progress)
end

function SpawnBalancer:SpawnAdaptiveWave(difficulty, delay_between_spawns, delay_between_reuse)
	local adaptive_wave = SpawnCoordinator._GetAdaptiveWaveForBiome(self, self.biome_location)
	local wave = SpawnCoordinator._AdaptWaveToProgress(self, difficulty, adaptive_wave, self.dungeon_progress)
	return self:_TrackWave("Adaptive Wave", wave, Scenario.id.Combat)
end

function SpawnBalancer:WaitForSeconds(duration)
	self.num_encounter_steps = self.num_encounter_steps + 1
	local wave_info = {
		wave_title = string.format("[%s] WAIT: Seconds: %s", self.num_encounter_steps, duration)
	}
	self.wave_info[self.num_encounter_steps] = wave_info
	-- print("SpawnBalancer:WaitForSeconds", duration)
end

function SpawnBalancer:WaitForEnemyCount(count)
	self.num_encounter_steps = self.num_encounter_steps + 1
	local wave_info = {
		wave_title = string.format("[%s] WAIT: Enemy Count: %s", self.num_encounter_steps, count)
	}
	self.wave_info[self.num_encounter_steps] = wave_info
	-- print("SpawnBalancer:WaitForEnemyCount", count)
end

-- Wait for this many to be defeated (not total enemies defeated).
function SpawnBalancer:WaitForDefeatedCount(count)
	self.num_encounter_steps = self.num_encounter_steps + 1
	local wave_info = {
		wave_title = string.format("[%s] WAIT: Defeated Count: %s", self.num_encounter_steps, count)
	}
	self.wave_info[self.num_encounter_steps] = wave_info
	-- print("SpawnBalancer:WaitForDefeatedCount", count)
end

function SpawnBalancer:WaitForDefeatedPercentage(percentage)
	self.num_encounter_steps = self.num_encounter_steps + 1
	local wave_info = {
		wave_title = string.format("[%s] WAIT: For Defeated Percentage: %s", self.num_encounter_steps, percentage)
	}
	self.wave_info[self.num_encounter_steps] = wave_info
	-- print("SpawnBalancer:WaitForDefeatedCount", count)
end

function SpawnBalancer:WaitForMinibossHealthPercent(percentage)
	self.num_encounter_steps = self.num_encounter_steps + 1
	local wave_info = {
		wave_title = string.format("[%s] WAIT: For miniboss health Percentage: %s", self.num_encounter_steps, percentage)
	}
	self.wave_info[self.num_encounter_steps] = wave_info
	-- print("SpawnBalancer:WaitForDefeatedCount", count)
end

function SpawnBalancer:WaitForMinibossHealthPercentWithReinforcement(percentage)
	self.num_encounter_steps = self.num_encounter_steps + 1
	local wave_info = {
		wave_title = string.format("[%s] WAIT: For miniboss health Percentage with reinforcement: %s", self.num_encounter_steps, percentage)
	}
	self.wave_info[self.num_encounter_steps] = wave_info
	-- print("SpawnBalancer:WaitForDefeatedCount", count)
end

function SpawnBalancer:WaitForRoomClear()
	self.num_encounter_steps = self.num_encounter_steps + 1
	local wave_info = {
		wave_title = string.format("[%s] WAIT: Room Clear", self.num_encounter_steps)
	}
	self.wave_info[self.num_encounter_steps] = wave_info
	-- print("SpawnBalancer:WaitForRoomClear")
end

function SpawnBalancer:GetWaveStats(wave)
	local total_health = 0
	local total_enemies = 0
	local wave_enemy_counts = {}
	local wave_enemy_health_totals = {}

	wave:SetBiomeLocation(self.biome_location)
	local dist = wave:BuildSpawnList(self.rng)
	dist = lume.frequency(dist)

	for prefab_name, count in pairs(dist) do

		local health_for_prefab = 0
		if TUNING[prefab_name] then
			health_for_prefab = TUNING[prefab_name].health * count
			total_health = total_health + health_for_prefab
			wave_enemy_health_totals[prefab_name] = health_for_prefab
		end

		total_enemies = total_enemies + count

		wave_enemy_counts[prefab_name] = (wave_enemy_counts[prefab_name] or 0) + count
	end

	return total_health, total_enemies, wave_enemy_counts, wave_enemy_health_totals
end


local function IsIgnoredFnName(fn_name)
	local ignored_prefixes = {
		"Add",
		"Debug",
		"Get",
		"On",
		"Set",
		"Start",
	}
	for _,prefix in ipairs(ignored_prefixes) do
		if kstring.startswith(fn_name, prefix) then
			return true
		end
	end
end
for key,fn in pairs(SpawnCoordinator) do
	kassert.assert_fmt(SpawnBalancer[key]
		or not kstring.is_capitalized(key)
		or IsIgnoredFnName(key)
		, "SpawnBalancer is missing function %s. If %s is internal/private, prefix it with _", key, key)
end

return SpawnBalancer
