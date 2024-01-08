local kassert = require "util.kassert"
local mapgen = require "defs.mapgen"
local waves = require "encounter.waves"
local lume = require "util.lume"


local Difficulty = mapgen.Difficulty -- for brevity

-- Encounters are coroutines that accept SpawnCoordinator as an argument. You
-- can call functions on spawner to delay or wait for conditions. See
-- "Encounter API" in SpawnCoordinator.


local function FilterTrapwaves(trapwaves, spawner)
	if not trapwaves then
		return
	end
	local eligible_trapwaves = {}
	local sorted_keys_trapwaves = lume.keys(trapwaves)
	table.sort(sorted_keys_trapwaves)
	local progress = spawner:GetProgressThroughDungeon()

	for _i,key in ipairs(sorted_keys_trapwaves) do
		local trapwave = trapwaves[key]

		local progress_min = trapwave.min_progress or 0
		local progress_max = trapwave.max_progress or 1
		local progress_ok = progress >= progress_min and progress <= progress_max

		if not trapwave.no_random and progress_ok then
			table.insert(eligible_trapwaves, trapwave)
		end
	end
	return eligible_trapwaves
end

-- Here are some functions that build basic encounters around wave lists.
local function SpawnInitialScenario(spawner, opts)
	local rng = spawner:GetRNG()
	if opts.traps then
		-- Pick a random wave of traps. JAMBELLTRAP todo: allow design for these in difficulties
		local worldmap = TheDungeon:GetDungeonMap()
		local biome_location = worldmap.nav:GetBiomeLocation()
		local wave_candidates = FilterTrapwaves(waves.trapwaves.biome[biome_location.id], spawner)
		assert(wave_candidates, biome_location.id)
		local trapwave = rng:PickValue(wave_candidates)

		spawner:SpawnTraps(trapwave)
	end

	if opts.stationary then
		spawner:SpawnStationaryEnemies(opts.stationary, { battlefield = true })
	end

	spawner:SpawnPropDestructibles(4)
end

local function CreateBasicWaveEncounter(wave_list, opts)

	-- Create a wave mainly using roles.
	-- These are a bit more focused/designed than the raw AdaptiveWaves, because they're more likely to pair interesting mechanics together explicitly.

	opts = opts or {}
	return function(spawner)
		SpawnInitialScenario(spawner, opts)
		for wave_idx,wave in ipairs(wave_list) do
			if wave_idx > 1 then
				-- Delay between subsequent spawns
				spawner:WaitForRoomClear()
				spawner:WaitForSeconds(1)
			end
			spawner:SpawnWave(wave)
		end
	end
end

local function CreateAdaptiveWaveEncounter(difficulty, wave_count, opts)

	-- A general, grab-bag encounter: grab a random assortment of ANY available enemy and put them together.
	-- These tend to be a little blurry, unfocused encounters. Great for "bread and butter" encounters, that create a solid baseline for the dungeon.
	-- Not many spikey, noteworthy encounters in here.

	opts = opts or {}
	local difficultytable = false
	if type(difficulty) == "table" then
		assert(#difficulty == wave_count, "[CreateAdaptiveWaveEncounter] A table of difficulties was given, but the difficulty count does not match wave_count.")
		difficultytable = true
	end
	return function(spawner)
		SpawnInitialScenario(spawner, opts)
		for wave_idx=1,wave_count do
			if wave_idx > 1 then
				-- Delay between subsequent spawns
				spawner:WaitForRoomClear()
				spawner:WaitForSeconds(1)
			end
			spawner:SpawnAdaptiveWave(difficultytable and difficulty[wave_idx] or difficulty)
		end
	end
end

local function CreateNonstopWaveEncounter(wave_list, opts)
	opts = opts or {}
	return function(spawner)
		SpawnInitialScenario(spawner, opts)
		for wave_idx,wave in ipairs(wave_list) do
			spawner:WaitForEnemyCount(2)
			spawner:SpawnWave(wave)
		end
	end
end

local function CreateEmptyEncounterSet()
	local enc = {
		monster = {},
		miniboss = {},
	}
	for roomtype,data in pairs(enc) do
		for _, difficulty in ipairs(Difficulty:Ordered()) do
			enc[roomtype][difficulty] = {}
		end
	end
	return enc
end

-- Using numbered names to show up better in encounter editor. Names could be anything.
local encounters = {
	_default = CreateEmptyEncounterSet(),
	_biome = {
		treemon_forest = CreateEmptyEncounterSet(),
		owlitzer_forest = CreateEmptyEncounterSet(),
		kanft_swamp = CreateEmptyEncounterSet(),
		thatcher_swamp = CreateEmptyEncounterSet(),
	},
}
-- Add a biome to this list if you want it to include default and biome specific encounters
local include_default_encounters =
{
	"treemon_forest"
}

--
-- SPECIFIC WAVE FUNCTIONS:

local function GetViableMobs(spawner)
	error("Beware: We've never used this function yet. It may not work.")
	local progress = spawner:GetProgressThroughDungeon()
	local biome_location = TheDungeon:GetDungeonMap().nav:GetBiomeLocation()
	local adaptive_wave = waves.adaptive.biome[biome_location.id]

	local viable_mobs = {}
	for mob,_ in pairs(possible_mobs.distribution) do
		print(mob,_)
	end

	return viable_mobs
end

local function AdaptiveMonoWave(spawner, difficulty)
	error("Beware: We've never used this function yet. It may not work.")

	 -- Create a Wave of one specific mob.
	 -- Find a mob which is available for this biome, and create an adaptive wave of just that mob.

	local rng = spawner:GetRNG()
	local viable_mobs = GetViableMobs(spawner)


	dumptable(viable_mobs)
	-- opts = opts or {}
	-- local difficultytable = false
	-- if type(difficulty) == "table" then
	-- 	assert(#difficulty == wave_count, "[CreateAdaptiveWaveEncounter] A table of difficulties was given, but the difficulty count does not match wave_count.")
	-- 	difficultytable = true
	-- end
	-- return function(spawner)
	-- 	SpawnInitialScenario(spawner, opts)
	-- 	for wave_idx=1,wave_count do
	-- 		if wave_idx > 1 then
	-- 			-- Delay between subsequent spawns
	-- 			spawner:WaitForRoomClear()
	-- 			spawner:WaitForSeconds(1)
	-- 		end
	-- 		spawner:SpawnAdaptiveWave(difficultytable and difficulty[wave_idx] or difficulty)
	-- 	end
	-- end
end

--
local function SpawnRandomTraps(spawner)
	-- Grab a random trapwave and spawn it.
	local worldmap = TheDungeon:GetDungeonMap()
	local rng = spawner:GetRNG()

	local biome_location = worldmap.nav:GetBiomeLocation()
	local possible_trapwaves = FilterTrapwaves(waves.trapwaves.biome[biome_location.id], spawner)
	local trapwave = rng:PickValue(possible_trapwaves)

	spawner:SpawnTraps(trapwave)
end

-----------------------------------------------------------

-- Encounter helper functions, to make the encounter list a bit more readable when doing common math checks or progress checks.
-- Spawn count helpers
local function AdaptiveWaveCount(difficulty, spawner)
	-- Get a wave directly
	-- Distributes difficulty evenly across dungeonprogress
	return spawner:GetCurrentAdaptiveWaveSize(difficulty)
end

local function HalfAdaptiveWaveCount(difficulty, spawner)
	-- Get a wave, cut it in half and ceil() it.
	-- Difficulty of this wave is easy earlier in dungeon.
	return math.ceil(spawner:GetCurrentAdaptiveWaveSize(difficulty)/2)
end

local function HalfAdaptiveWaveCountEasy(difficulty, spawner)
	-- Get a wave, cut it in half and floor() it.
	-- Distributes difficulty such that the early stages of the dungeon are easier.
	return math.ceil(spawner:GetCurrentAdaptiveWaveSize(difficulty)/2)
end

local function SpawnAfterMiniboss(count, spawner)
	return spawner:GetProgressThroughDungeon() > 0.5 and count or 0
end

local function SpawnSometimes(count, spawner)
	-- Spawn 50% of the time.
	return spawner.rng:Boolean() and count or 0
end

local function SpawnTrapWave(spawner, trapwave)
	-- Spawn a specific trapwave
	assert(trapwave)
	spawner:SpawnTraps(trapwave)
end

-- Dungeon state helpers
local function IsAfterMiniboss(spawner)
	-- Returns true/false: are we past the miniboss or not.
	return spawner:GetProgressThroughDungeon() > 0.5
end

local function Progress(spawner)
	return spawner:GetProgressThroughDungeon()
end

--[[
	Encounter Table structure:

	category = {bespoke, _default, _biome}
	location = biome location (see biomes.lua)
	room_type = {monster, miniboss}
	difficulty = {easy, medium, hard}

	encounters.<category>.<location>.<room_type>.<difficulty>.<name> = {
		constraint_fn , -- Constraint is checked when the encounter is drawn. On failure, the encounter is shuffled back in.
		factor, -- Given an initial deck of size N (which includes this encounter), replace the encounter with factor * N copies of itself.
		exec_fn, -- Run as a coroutine to spawn waves of enemies.
	}
]]

encounters.bespoke = {
	-- Learn how to fight
	tutorial1 = {
		exec_fn = function(spawner)
			spawner:SpawnPropDestructibles(4)
			spawner:SpawnWave(waves.Raw{ cabbageroll = 1 }) -- Learn how to fight an enemy on its own
			spawner:WaitForDefeatedPercentage(1)
			spawner:WaitForSeconds(0.75)
			spawner:SpawnWave(waves.Raw{ cabbageroll = 2 }) -- Learn how to fight an enemy while another is approaching
			spawner:WaitForDefeatedPercentage(1)
			spawner:WaitForSeconds(0.75)
			spawner:SpawnWave(waves.Raw{ cabbageroll = 3 }) -- Experience another type of enemy
		end,
	},

	-- Meet Blarmadillo, then fight it with the Cabbageroll you already know.
	tutorial2 = {
		exec_fn = function(spawner)
			spawner:SpawnPropDestructibles(4)
			spawner:SpawnWave(waves.Raw{ cabbageroll = 2, blarmadillo = 1 }) -- Now that you know how to deal with cabbagerolls, fight some while seeing what a blarmadillo does
			spawner:WaitForDefeatedPercentage(0.66) 						 -- Learn that sometimes more mobs spawn in the middle of an encounter!
			spawner:SpawnWave(waves.Raw{ cabbageroll = 1, blarmadillo = 1 }) -- Keep dealing with that problem
		end,
	},

	-- Introduce traps!
	tutorial3 = {
		exec_fn = function(spawner)
			spawner:SpawnPropDestructibles(4)
			SpawnTrapWave(spawner, waves.trapwaves.biome.treemon_forest.three_bombs)
			spawner:SpawnWave(waves.Raw{ cabbageroll = 5 }) -- A lot of mobs -- either they will hit the bomb or you will. Learn to use traps to kill!
			spawner:WaitForDefeatedPercentage(.8)
			spawner:WaitForSeconds(0.75)
			spawner:SpawnWave(waves.Raw{ cabbageroll = 3, blarmadillo = 1 })
			spawner:WaitForDefeatedPercentage(.75)
			spawner:SpawnWave(waves.Raw{ cabbageroll = 2, blarmadillo = 1 })
		end,
	},

	-- Meet Beets!
	tutorial4 = {
		exec_fn = function(spawner)
			spawner:SpawnPropDestructibles(4)
			spawner:SpawnWave(waves.Raw{ beets = 1 }) -- Meet Beets, who has a different attack style than Cabbageroll (short startup, long recovery instead of inverse)
			spawner:WaitForDefeatedPercentage(1)
			spawner:WaitForSeconds(0.75)
			spawner:SpawnWave(waves.Raw{ beets = 1 }) -- Learn how to fight a few of them
			spawner:WaitForSeconds(2)
			spawner:SpawnWave(waves.Raw{ beets = 2 })
			spawner:WaitForDefeatedPercentage(0.75)
			spawner:WaitForSeconds(0.75)
			spawner:SpawnWave(waves.Raw{ beets = 2, cabbageroll = 2 }) -- Fight a group!
		end,
	},

	-- Now that you know Beets, include Treemon
	tutorial5 = {
		exec_fn = function(spawner)
			spawner:SpawnPropDestructibles(5)
			spawner:SpawnStationaryEnemies(waves.stationary.medium)
			spawner:SpawnWave(waves.Raw{ beets = 2 }) -- Learn how to fight a few of them
			spawner:WaitForDefeatedPercentage(.5)
			spawner:WaitForSeconds(0.75)
			spawner:SpawnWave(waves.Raw{ beets = 2, blarmadillo = 1 })
			spawner:WaitForDefeatedPercentage(0.75)
			spawner:WaitForSeconds(0.75)
			spawner:SpawnWave(waves.Raw{ beets = 2, cabbageroll = 1 })
		end,
	},

	tutorial6 = {
		exec_fn = function(spawner)
			spawner:SpawnPropDestructibles(3)
			SpawnTrapWave(spawner, waves.trapwaves.biome.treemon_forest.one_bomb_one_spike)
			spawner:SpawnStationaryEnemies(waves.stationary.easy)
			spawner:SpawnWave(waves.Raw{ cabbageroll = 2 })
			spawner:WaitForDefeatedPercentage(1)
			spawner:WaitForSeconds(0.75)
			spawner:SpawnWave(waves.Raw{ cabbageroll = 2, blarmadillo = 1 })
			spawner:WaitForDefeatedPercentage(0.66)
			spawner:WaitForSeconds(0.75)
			spawner:SpawnWave(waves.Raw{ beets = 2, cabbageroll = 1 })
		end,
	},
}

encounters._default.monster = {
	easy = {
		e01 = {
			factor = 0.3,
			exec_fn = CreateAdaptiveWaveEncounter(Difficulty.id.easy, 2),
		},
		e02 = {
			factor = 0.3,
			exec_fn = CreateAdaptiveWaveEncounter(Difficulty.id.easy, 2, { traps = true, }),
		},
	},

	medium = {
		m01 = {
			factor = 0.3,
			exec_fn = CreateAdaptiveWaveEncounter(Difficulty.id.medium, 2),
		},
		m02 = {
			factor = 0.3,
			exec_fn = CreateAdaptiveWaveEncounter(Difficulty.id.medium, 2, { traps = true, }),
		},
		m03 = {
			factor = 0.3,
			exec_fn = CreateAdaptiveWaveEncounter({ Difficulty.id.medium, Difficulty.id.easy } , 2, { stationary = waves.stationary.easy, }),
		},
		m04 = {
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.medium)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
				spawner:WaitForEnemyCount(1)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
		m06 = {
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.medium)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
				spawner:WaitForDefeatedPercentage(.66)
				spawner:WaitForSeconds(0.75)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
			end,
		},
		m07 = {
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnWave({waves.trickster, waves.mixed_easy})
				spawner:WaitForDefeatedPercentage(.5)
				spawner:WaitForSeconds(0.75)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
			end,
		},
	},

	hard = {
		h01 = {
			exec_fn = CreateBasicWaveEncounter({
					waves.melee_easy,
					waves.cabbage_swarm,
					{ waves.single_heavy, waves.trickster, waves.single_melee, },
				},
				{
					traps = true,
					stationary = waves.stationary.medium,
				}),
			},
		h02 = {
			exec_fn = CreateBasicWaveEncounter({
					waves.mixed_hard,
					waves.shooty_medium,
					{ waves.melee_hard, waves.single_heavy },
				},
				{
					traps = true,
					stationary = waves.stationary.medium,
				}),
			},
		h03 = {
			exec_fn = CreateBasicWaveEncounter({
					waves.melee_hard,
					waves.shooty_hard,
					{ waves.melee_easy, waves.single_heavy },
				},
				{
					traps = true,
					stationary = waves.stationary.medium,
				}),
			},
		h04 = {
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(5)
				spawner:SpawnWave(waves.shooty_hard)
				spawner:WaitForRoomClear()
				spawner:WaitForSeconds(0.75)
				spawner:SpawnWave({waves.single_heavy, waves.shooty_easy})
				spawner:WaitForEnemyCount(2)
				spawner:WaitForSeconds(1)
				spawner:SpawnWave(waves.mixed_hard)
			end,
		},
		h05 = {
			exec_fn = CreateBasicWaveEncounter({
					waves.melee_easy,
					{ waves.mixed_medium, waves.mixed_hard },
					{ waves.single_heavy, waves.trickster },
				},
				{
					traps = true,
				}),
			},
		h06 = {
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(5)
				spawner:SpawnStationaryEnemies(waves.stationary.easy, { perimeter = true })
				spawner:SpawnWave({waves.tricky_heavy, waves.support_group})
				spawner:WaitForDefeatedPercentage(0.5)
				spawner:SpawnWave(waves.mixed_easy)
			end,
		},
		h07 = {
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.hard, { perimeter = true })
				spawner:SpawnWave(waves.melee_easy)
				spawner:WaitForDefeatedPercentage(0.33)
				spawner:WaitForSeconds(0.5)
				spawner:SpawnWave({waves.trickster, waves.melee_easy})
			end,
		},
		h08 = {
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(6)
				spawner:SpawnWave(waves.shooty_medium)
				spawner:WaitForEnemyCount(1)
				spawner:WaitForSeconds(0.25)
				spawner:SpawnWave({waves.trickster, waves.shooty_easy})
				spawner:WaitForDefeatedPercentage(0.5)
				spawner:WaitForSeconds(0.5)
				spawner:SpawnWave(waves.single_heavy)
			end,
		},
		h09 = {
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(3)
				spawner:SpawnWave(waves.melee_medium, 0, 0)
				spawner:WaitForDefeatedPercentage(0.6)
				spawner:SpawnWave({waves.support_heavy, waves.melee_hard, waves.single_shooty,}, 0, 0)
			end,
		},
		h10 = {
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(6)
				spawner:SpawnStationaryEnemies(waves.stationary.hard, { perimeter = true })
				spawner:SpawnWave(waves.shooty_hard)
				spawner:WaitForDefeatedPercentage(0.7)
				spawner:WaitForSeconds(0.5)
				spawner:SpawnWave(waves.tricky_heavy)
			end,
		},
		h11 = {
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(5)
				spawner:SpawnWave({ waves.melee_easy, waves.cabbage_tower})
				spawner:WaitForDefeatedPercentage(0.5)
				spawner:SpawnWave(waves.cabbage_swarm)
				spawner:WaitForDefeatedPercentage(0.25)
				spawner:SpawnWave(waves.support_heavy)
			end,
		},
		h12 = {
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(5)
				spawner:SpawnWave({ waves.melee_easy, waves.cabbage_tower})
				spawner:WaitForDefeatedPercentage(0.3)
				spawner:SpawnWave(waves.support_heavy)
			end,
		},
	},
}

encounters._biome.treemon_forest.monster =
{
	easy =
	{
		e01 = { -- Stationary and adaptive wave
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.easy)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
				spawner:WaitForDefeatedPercentage(0.66)
				spawner:WaitForSeconds(1)
				spawner:SpawnWave({ melee1 = HalfAdaptiveWaveCount(Difficulty.id.easy, spawner) })
				if Progress(spawner) > 0.25 then
					spawner:SpawnWave({ melee1 = SpawnSometimes(HalfAdaptiveWaveCount(Difficulty.id.easy, spawner), spawner) })
				end
			end,
		},
		e02 = { -- One melee, then an ambush!
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnWave({ melee1 = 1 })
				spawner:WaitForDefeatedPercentage(.66)
				spawner:WaitForSeconds(0.75)
				spawner:SpawnWave({ ranged1 = HalfAdaptiveWaveCountEasy(Difficulty.id.easy, spawner) })
				spawner:SpawnWave({ ranged1 = HalfAdaptiveWaveCountEasy(Difficulty.id.easy, spawner) })
				if IsAfterMiniboss(spawner) then
					-- If we're past miniboss, add some extra ambushers
					spawner:SpawnWave({ melee1 = HalfAdaptiveWaveCountEasy(Difficulty.id.easy, spawner) })
					spawner:WaitForDefeatedPercentage(0.33)
					spawner:WaitForSeconds(0.75)
					spawner:SpawnWave({ melee2 = SpawnSometimes(1, spawner) })
				end
			end,
		},
		e03 = { -- Just melees, an onslought!
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(4)
				SpawnRandomTraps(spawner) -- Spawn some traps to make it fun to kill these groups of cabbages
				spawner:SpawnWave({ melee1 = 2 })
				spawner:WaitForDefeatedPercentage(0.5)
				spawner:WaitForSeconds(0.75)
				spawner:SpawnWave({ melee1 = 2 })
				spawner:WaitForDefeatedPercentage(0.5)
				spawner:WaitForSeconds(0.75)
				spawner:SpawnWave({ melee1 = HalfAdaptiveWaveCount(Difficulty.id.easy, spawner) })
				spawner:SpawnWave({ support1 = SpawnAfterMiniboss(1, spawner)})
				spawner:WaitForSeconds(0.75)
				spawner:SpawnWave({ melee1 = HalfAdaptiveWaveCountEasy(Difficulty.id.easy, spawner) })
			end,
		},
	},
	medium =
	{
		m01 = {
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.easy)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
				spawner:WaitForDefeatedPercentage(0.66)
				spawner:WaitForSeconds(0.3)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
			end,
		},
		m02 = { -- A lot of treemons + a few other enemies
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.hard)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
				spawner:WaitForDefeatedPercentage(0.66)
				spawner:WaitForSeconds(1)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
			end,
		},
		m03 = { -- A few stationaries + a weak wave, then a trickster and a medium wave come out
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.medium, { perimeter = true })
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
				spawner:WaitForDefeatedPercentage(0.7)
				spawner:WaitForSeconds(0.3)
				spawner:SpawnWave(waves.trickster)
				spawner:WaitForSeconds(0.75)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
			end,
		},
	},
	hard =
	{
		h01 = {
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(3)
				spawner:SpawnStationaryEnemies(waves.stationary.hard)
				spawner:SpawnAdaptiveWave(Difficulty.id.hard)
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
		h02 = { -- Many zucco ambush
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(5)
				spawner:SpawnWave(waves.Raw{ zucco = 5 })
			end,
		},
	},
}

encounters._biome.owlitzer_forest.monster =
{
	easy = {
		e01 = {
			factor = 5,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.medium)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
		e02 = {
			factor = 5,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.easy)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
		e03 = { --Many gnarlics and windmon
			factor = 1,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(2)
				spawner:SpawnStationaryEnemies(waves.stationary.medium)
				spawner:SpawnWave(waves.Raw{ gnarlic = 4 })
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnWave(waves.Raw{ gnarlic = 3 })
			end,
		},
	},
	medium = {
		m01 = {
			factor = 5,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.medium)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
		m02 = {
			factor = 4,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.easy)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
			end,
		},
		m03 = { --Enemies then Trickster as reinforcement
			factor = 2,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(2)
				spawner:SpawnStationaryEnemies(waves.stationary.easy)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnWave(waves.trickster)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
		m04 = { --Trickster first then reinforcements
			factor = 2,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.easy)
				spawner:SpawnWave(waves.trickster)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
				spawner:WaitForDefeatedPercentage(1)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
			end,
		},
		m05 = { --Group of battoads
			factor = 1,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnStationaryEnemies(waves.stationary.medium)
				spawner:SpawnPropDestructibles(3)
				spawner:SpawnWave(waves.Raw{ battoad = 3 })
			end,
		},
		m06 = { -- Windmons and bonions
			factor = 1,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnStationaryEnemies(waves.stationary.hard)
				spawner:SpawnPropDestructibles(3)
				spawner:SpawnWave(waves.Raw{ cabbagerolls = 2 })
				spawner:WaitForDefeatedPercentage(0.75)
				spawner:SpawnWave(waves.Raw{ cabbagerolls = 2 })
			end,
		},
	},
	hard = {
		h01 = {
			factor = 4,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.easy)
				spawner:SpawnAdaptiveWave(Difficulty.id.hard)
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
		h02 = {
			factor = 2,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.easy)
				spawner:SpawnAdaptiveWave(Difficulty.id.hard)
				spawner:WaitForDefeatedPercentage(1)
				spawner:SpawnWave(waves.trickster)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
		h03 = {
			factor = 3,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnAdaptiveWave(Difficulty.id.hard)
				spawner:WaitForDefeatedPercentage(1)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
				spawner:WaitForDefeatedPercentage(0.9)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
	}
}

encounters._biome.kanft_swamp.monster =
{
	easy =
	{
		e01 = {
			factor = 5,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(5)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
		e02 = {
			factor = 4,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(3)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
				spawner:WaitForRoomClear()
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
		e03 = { -- Constant stream of mothballs, teen at later progress
			factor = 1,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(5)
				spawner:SpawnStationaryEnemies(waves.Raw{ mothball_spawner = SpawnAfterMiniboss(1, spawner) })
				spawner:SpawnWave(waves.Raw{ mothball = HalfAdaptiveWaveCount(Difficulty.id.easy, spawner) })
				spawner:SpawnWave(waves.Raw{ mothball = AdaptiveWaveCount(Difficulty.id.easy, spawner) })
				if Progress(spawner) >= 0.25 then
					spawner:SpawnWave(waves.Raw{ mothball_teen = 1 })
				end
				spawner:WaitForSeconds(1)
				spawner:SpawnWave(waves.Raw{ mothball = AdaptiveWaveCount(Difficulty.id.easy, spawner) })
				spawner:SpawnWave(waves.Raw{ mothball = AdaptiveWaveCount(Difficulty.id.easy, spawner) })
				spawner:WaitForDefeatedPercentage(0.5)
				spawner:SpawnWave(waves.Raw{ mothball = HalfAdaptiveWaveCount(Difficulty.id.easy, spawner) })
				spawner:SpawnWave(waves.Raw{ mothball = AdaptiveWaveCount(Difficulty.id.easy, spawner) })
			end,
		},
	},
	medium =
	{
		m01 = {
			factor = 7,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.easy)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
				spawner:WaitForDefeatedPercentage(0.9)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
		m02 = {
			factor = 7,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.medium)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
			end,
		},
		m03 = { -- Mothball family encounter
			factor = 2,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(5)
				spawner:SpawnStationaryEnemies(waves.Raw{ mothball_spawner = 2 })
				spawner:SpawnWave(waves.Raw{ mothball_teen = 1, mothball = AdaptiveWaveCount(Difficulty.id.easy, spawner) })
				spawner:WaitForDefeatedPercentage(0.33)
				if IsAfterMiniboss(spawner) then
					spawner:SpawnWave(waves.Raw{ mothball_teen = 1, mothball = AdaptiveWaveCount(Difficulty.id.medium, spawner) })
				end
			end,
		},
		m04 = { -- A bulbug applying shield to a bunch of mothballs, only appearing a bit later in the dungeon.
			factor = 2,
			constraint_fn = function(spawner)
				return Progress(spawner) > 0.33
			end,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(5)
				spawner:SpawnStationaryEnemies(waves.Raw{ mothball_spawner = 2 }, { perimeter = true })
				spawner:SpawnWave(waves.Raw{ bulbug = 1 })
				spawner:SpawnWave(waves.Raw{ mothball = AdaptiveWaveCount(Difficulty.id.medium, spawner) })
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnWave(waves.Raw{ mothball = AdaptiveWaveCount(Difficulty.id.medium, spawner) })
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnWave(waves.Raw{ mothball = AdaptiveWaveCount(Difficulty.id.easy, spawner) })
			end,
		},
		m05 = { --Surprise groak!
			factor = 2,
			constraint_fn = function(spawner)
				return Progress(spawner) > 0.51
			end,
			exec_fn = function(spawner)
				spawner:SpawnTraps(waves.Raw{ trap_spores_groak = 1, trap_spores_damage = 3 })
				spawner:SpawnWave(waves.Raw{ mossquito = 1,  mothball = 3 })
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnWave(waves.Raw{ mothball = 4 })
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnWave(waves.Raw{ mossquito = 1, mothball = 3 })
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnWave(waves.Raw{ mothball = 4 })
			end,
		},
		m06 = { --Teen Duo with groak surprise
			factor = 1,
			constraint_fn = function(spawner)
				return Progress(spawner) > 0.51
			end,
			exec_fn = function(spawner)
				spawner:SpawnTraps(waves.Raw{ trap_spores_groak = 1, trap_spores_damage = 3 })
				spawner:SpawnWave(waves.Raw{ mothball_teen = 2 })
				spawner:WaitForDefeatedCount(1)
				spawner:SpawnWave(waves.Raw{ mossquito = 1, mothball = 3 })
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnWave(waves.Raw{ mothball = 5 })
				spawner:WaitForDefeatedPercentage(0.8)
				spawner:SpawnWave(waves.Raw{ mossquito = 2, mothball = 4 })
			end,
		}
	},
	hard =
	{
		h01 = {
			factor = 3,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(2)
				spawner:SpawnStationaryEnemies(waves.stationary.medium)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
				spawner:WaitForDefeatedPercentage(0.9)
				spawner:SpawnAdaptiveWave(Difficulty.id.hard)
				spawner:WaitForDefeatedPercentage(0.9)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
		h02 = {
			factor = 3,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.hard)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
				spawner:WaitForDefeatedPercentage(0.9)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
			end,
		},
		h03 = { -- More common trap groak in hard
			factor = 4,
			constraint_fn = function(spawner)
				return Progress(spawner) > 0.51
			end,
			exec_fn = function(spawner)
				spawner:SpawnTraps(waves.Raw{ trap_spores_groak = 1, trap_spores_damage = 3 })
				spawner:SpawnPropDestructibles(3)
				spawner:SpawnStationaryEnemies(waves.stationary.medium)
				spawner:SpawnAdaptiveWave(Difficulty.id.hard)
				spawner:WaitForDefeatedPercentage(0.9)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
			end,
		},
		h04 = { -- Shielded eyev's
			factor = 1,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(5)
				spawner:SpawnWave(waves.Raw{ bulbug = 1 })
				if Progress(spawner) > 0.66 then
					spawner:SpawnWave(waves.Raw{ bulbug = 1 })
				end
				spawner:SpawnWave(waves.Raw{ eyev = HalfAdaptiveWaveCount(Difficulty.id.medium, spawner) })
				if Progress(spawner) > 0.66 then
					spawner:WaitForDefeatedPercentage(0.6)
					spawner:SpawnWave(waves.Raw{ eyev = HalfAdaptiveWaveCount(Difficulty.id.easy, spawner) })
				end
			end,
		},
		h05 = { -- Trickster at start with hard reinforcement
			factor = 2,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(3)
				spawner:SpawnStationaryEnemies(waves.stationary.easy)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
				spawner:SpawnWave(waves.trickster)
				spawner:WaitForDefeatedPercentage(1)
				spawner:SpawnAdaptiveWave(Difficulty.id.hard)
			end,
		},
		h06 = { -- wave with trickster reinforcement
			factor = 2,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(3)
				spawner:SpawnStationaryEnemies(waves.stationary.medium)
				spawner:SpawnAdaptiveWave(Difficulty.id.hard)
				spawner:WaitForDefeatedPercentage(0.9)
				spawner:SpawnWave(waves.trickster)
			end,
	},
	},
}

encounters._biome.thatcher_swamp.monster =
{
	easy =
	{
		e01 = {
			factor = 15,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.medium)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy)
			end,
		},
	},
	medium =
	{
		e01 = {
			factor = 15,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.medium)
				spawner:SpawnAdaptiveWave(Difficulty.id.medium)
			end,
		},
	},
	hard =
	{
		e01 = {
			factor = 15,
			exec_fn = function(spawner)
				SpawnRandomTraps(spawner)
				spawner:SpawnPropDestructibles(4)
				spawner:SpawnStationaryEnemies(waves.stationary.hard)
				spawner:SpawnAdaptiveWave(Difficulty.id.hard)
			end,
		},
	}
}

-- Biome-specific encounters can use Raw waves to specify specific enemies instead of roles.
--
-- miniboss fights are all biome-specific.
encounters._biome.treemon_forest.miniboss = {
	easy = {
		e01 = {
			exec_fn = function(spawner)
				spawner:SpawnPropDestructibles(5)
				spawner:SpawnMiniboss(waves.Raw{ yammo_elite = 1 })
				spawner:WaitForSeconds(4.9)
				spawner:SpawnWave(waves.Raw{ beets = 3 }, 0, 0, nil, true)
				spawner:WaitForMinibossHealthPercent(0.75)
				spawner:WaitForMinibossHealthPercentWithReinforcement(0, waves.Raw{ beets = 4 }, 2.2)
				TheWorld.components.roomclear:CleanUpRemainingEnemies()
			end,
		},
	},
}
encounters._biome.treemon_forest.miniboss.medium = encounters._biome.treemon_forest.miniboss.easy
encounters._biome.treemon_forest.miniboss.hard = encounters._biome.treemon_forest.miniboss.easy

encounters._biome.owlitzer_forest.miniboss = {
	easy = {
		e01 = {
			exec_fn = function(spawner)
				SpawnTrapWave(spawner, waves.Raw{ trap_weed_spikes = 3 })
				spawner:SpawnPropDestructibles(5)
				spawner:SpawnMiniboss(waves.Raw{ gourdo_elite = 2 })
				spawner:WaitForMinibossHealthPercent(0.6)
				if (TheNet:GetNrPlayersOnRoomChange() > 2) then
					spawner:SpawnWave(waves.Raw{ battoad = 1 }, 0, 0, nil, true)
				end
				spawner:WaitForMinibossHealthPercent(0)
				TheWorld.components.roomclear:CleanUpRemainingEnemies()
			end,
		},
	},
}
encounters._biome.owlitzer_forest.miniboss.medium = encounters._biome.owlitzer_forest.miniboss.easy
encounters._biome.owlitzer_forest.miniboss.hard = encounters._biome.owlitzer_forest.miniboss.easy

encounters._biome.kanft_swamp.miniboss = {
	easy = {
		e01 = {
			exec_fn = function(spawner)
				--SpawnTrapWave(spawner, waves.Raw{ trap_spores_heal = 3 })
				spawner:SpawnPropDestructibles(3)
				spawner:SpawnStationaryEnemies(waves.Raw{ mothball_spawner = 2 })
				spawner:SpawnMiniboss(waves.Raw{ groak_elite = 1 })
				spawner:WaitForMinibossHealthPercent(0.5)
				spawner:WaitForMinibossHealthPercentWithReinforcement(0, waves.Raw{ mothball = 4 }, 2.2)
				TheWorld.components.roomclear:CleanUpRemainingEnemies()
			end,
		},
	},
}
encounters._biome.kanft_swamp.miniboss.medium = encounters._biome.kanft_swamp.miniboss.easy
encounters._biome.kanft_swamp.miniboss.hard = encounters._biome.kanft_swamp.miniboss.easy

encounters._biome.thatcher_swamp.miniboss = {
	easy = {
		e01 = {
			exec_fn = function(spawner)
				--SpawnTrapWave(spawner, waves.Raw{ trap_spores_heal = 3 })
				spawner:SpawnPropDestructibles(5)
				spawner:SpawnMiniboss(waves.Raw{ floracrane_elite = 1 })
				spawner:WaitForSeconds(5)
				spawner:WaitForMinibossHealthPercent(0.75)
				spawner:SpawnWave(waves.Raw{ bulbug = 1 })
				spawner:WaitForMinibossHealthPercent(0.6)
				spawner:SpawnWave(waves.Raw{ mothball = HalfAdaptiveWaveCountEasy(Difficulty.id.easy, spawner) })
				spawner:WaitForMinibossHealthPercent(0.5)
				spawner:SpawnAdaptiveWave(Difficulty.id.easy, 0.33, 1, true)
				TheWorld.components.roomclear:CleanUpRemainingEnemies()
			end,
		},
	},
}
encounters._biome.thatcher_swamp.miniboss.medium = encounters._biome.thatcher_swamp.miniboss.easy
encounters._biome.thatcher_swamp.miniboss.hard = encounters._biome.thatcher_swamp.miniboss.easy

for roomtype,room_enc in pairs(encounters._default) do
	mapgen.validate.all_keys_are_difficulty(room_enc)
end
for biome,enc in pairs(encounters._biome) do
	for roomtype,room_enc in pairs(enc) do
		mapgen.validate.all_keys_are_difficulty(room_enc)
	end
	for difficulty,encounter_list in pairs(enc.miniboss) do
		-- If this fires when you're setting up a new location, temporarily
		-- copypaste another biome's miniboss above. Be sure to remove
		-- incorrect mobs to prevent a crash.
		kassert.assert_fmt(next(encounter_list), "Missing %s miniboss encounter in location %s.", difficulty, biome)
	end
end

-- Debug encounters: everything is a single wave for fast d_clearroom.

--[[encounters._default.monster.easy = {
	e01 = {
		exec_fn = CreateBasicWaveEncounter({
				waves.mixed_easy,
			},
			{
				traps = true,
			}),
		},
	e02 = {
		exec_fn = CreateBasicWaveEncounter{
			waves.mixed_easy,
		},
	},
	e03 = {
		exec_fn = function(spawner)
			local rng = spawner:GetRNG()
			local trapwave = rng:PickValue(waves.trapwaves)
			-- Traps don't count towards room clear.
			spawner:SpawnTraps(trapwave)
			spawner:SpawnStationaryEnemies(waves.stationary.easy, { battlefield = false, perimeter = true, })
			spawner:SpawnPropDestructibles(3)
			spawner:SpawnWave(waves.melee_easy, nil, nil, { center = true, })
			spawner:WaitForSeconds(0.5)
			spawner:SpawnWave(waves.melee_easy, nil, nil, { center = true, })
		end,
	},
}
encounters._default.monster.medium = encounters._default.monster.easy
encounters._default.monster.hard = encounters._default.monster.easy
encounters._default.monster.miniboss = encounters._default.monster.easy
--]]

-- Cache biomes so we can lazily create them but callers don't need to worry
-- about cost of rebuilding.
-- Table of encounter tables, indexed by location.
local location_encounters = {}

-- Return table of encounter tables, indexed by room_type.
function encounters.GetRoomTypeEncounters(location_id)
	kassert.typeof("string", location_id, "Pass the location_id, not the biome_location table.")

	-- If we have built and cached room_type_encounters for this location already, return it.
	local room_type_encounters = location_encounters[location_id]
	if room_type_encounters then
		return room_type_encounters
	end

	-- If this location does not have any custom encounters, just return the defaults.
	if not encounters._biome[location_id] then
		return encounters._default
	end

	-- Build a new room_type_encounters table to cache.
	if (lume.find(include_default_encounters, location_id)) then
		room_type_encounters = deepcopy(encounters._default)
	else
		room_type_encounters = CreateEmptyEncounterSet()
	end

	-- Then add the location-specific encounters.
	for room_type, difficulty_encounters in pairs(encounters._biome[location_id]) do
		for difficulty, encounter_set in pairs(difficulty_encounters) do
			for name, fn in pairs(encounter_set) do
				name = name .."_".. location_id
				kassert.assert_fmt(room_type_encounters[name] == nil, "Why does this default encounter contain a biome name? %s", name)
				room_type_encounters[room_type][difficulty][name] = fn
			end
		end
	end

	-- Cache it.
	location_encounters[location_id] = room_type_encounters

	return room_type_encounters
end

-- Table of encounter tables, indexed by arbitrary key.
return encounters
