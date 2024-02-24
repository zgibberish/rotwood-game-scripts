local iterator = require "util.iterator"
local kassert = require "util.kassert"
local lume = require "util.lume"
local mapgen = require "defs.mapgen"
local monstertiers = require "defs.monstertiers"
require "class"


local Wave = Class(function(self, dist)
	kassert.typeof("table", dist)
	self.dist = dist
end)

function Wave:SetBiomeLocation(biome_location)
	self.biome_location = biome_location
end

function Wave:NoRandom()
	self.no_random = true
	return self
end

function Wave:SetProgressRange(min, max)
	self.min_progress = min or 0
	self.max_progress = max or 1
	return self
end

local function ComputeSpawnCount(multiplier, original_count, enemy, rng)
	local count = original_count
	local newcount = count * multiplier

	-- in case of a 0.5 result, should we round it up or down? randomize it for variance
	newcount = rng:Boolean() and math.floor(newcount + 0.5) or math.ceil(newcount - 0.5)

	-- TheLog.ch.Tuning:printf("ComputeSpawnCount [%1s] : Original: %3.0f x %3.0f --> New %4.0f (+%5.0f)", enemy, count, multiplier, newcount, newcount - count)

	return newcount
end

-- spawn_count_multiplier_id is an EnemyModifiers.s variant used as a key to access a multiplier that will be applied
-- against the base spawn count. Variants intended for use are { SpawnCountMult, StationarySpawnCountMult, and MinibossSpawnCountMult }
function Wave:BuildSpawnList(rng, spawn_count_multiplier_id)
	local dist = deepcopy(self.dist)
	local freq = self:_ConvertRolesToPrefabs(rng, dist)

	if spawn_count_multiplier_id then
		dbassert(
			spawn_count_multiplier_id == EnemyModifierNames.s.SpawnCountMult
			or spawn_count_multiplier_id == EnemyModifierNames.s.StationarySpawnCountMult
			or spawn_count_multiplier_id == EnemyModifierNames.s.MinibossSpawnCountMult
		)

		-- Passing a spawn count modifier fn implies we should scale spawn counts.
		local enemy_names = lume.sort(lume.keys(freq))
		for _i, enemy in ipairs(enemy_names) do
			local modifiers = TUNING:GetEnemyModifiers(enemy)
			local spawn_count_multiplier = modifiers[spawn_count_multiplier_id]
			local newcount = ComputeSpawnCount(spawn_count_multiplier, freq[enemy], enemy, rng)

			-- TheLog.ch.Tuning:printf("	Total spawn mod [%1s]: %2.0f --> %3.0f (+%4.0f)", enemy, freq[enemy], newcount, newcount - freq[enemy])

			freq[enemy] = newcount
		end
		-- else: Don't apply multipliers (common for things that can't leave their spawn position).
	end

	-- freq is a mapping of prefab to count.
	-- Return a list of prefabs we should spawn (each enemy repeated for multiple spawns).
	return lume.repeatkeys(freq)
end

function Wave:_ConvertRolesToPrefabs(rng, freq)
	if self.is_biome_specific then
		return freq
	end
	assert(self.biome_location, "Forgot to call EnsureWave.")
	local dist = {}
	for rolepack,count in iterator.sorted_pairs(freq) do
		if count > 0 then
			local role, tier = rolepack:match("(%a+)(%d)")
			local prefab
			local trap_role = role:match("(%a+)trap");
			if trap_role then
				prefab, count = self.biome_location:ChooseTrap(trap_role, tonumber(tier), count)
			else
				prefab, count = monstertiers.ConvertRoleToMonster(self.biome_location, role, tier, count, rng)
			end
			if prefab ~= nil then
				dist[prefab] = count
			end
		end
	end
	return dist
end

-----

local waves = {}

-- Raw waves should only be used in adaptive waves and biome-specific
-- encounters or else they'll spawn enemies from the wrong biome.
function waves.Raw(dist)
	local wave = Wave(dist)
	wave.is_biome_specific = true
	return wave
end

-- Not sure this should be exposed.
function waves._MergeWaves(wave_list)
	local dist = lume.sum(table.unpack(lume.map(wave_list, "dist")))
	return Wave(dist)
end

function waves.EnsureWave(wave_input)
	local biome_location = TheDungeon:GetDungeonMap().nav:GetBiomeLocation()
	local wave
	if wave_input[1] then
		wave = waves._MergeWaves(wave_input)
	elseif not wave_input.dist then
		wave = Wave(wave_input)
	else
		wave = wave_input
	end
	wave:SetBiomeLocation(biome_location)
	return wave
end

-- adaptive_counts does not necessarily map to difficulty. Any group size can be used by any encounter -- for example, an Easy encounter could use a Large group, if we wanted.
-- This table just defines what is considered, e.g., a "small" group of enemies at different parts of the dungeon.
waves.adaptive_counts = {
	easy = {
		{
			progress = 0.15,
			count = 4,
		},
		{
			progress = 0.5,
			count = 4,
		},
		{
			progress = 0.75,
			count = 5,
		},
		{
			progress = 1,
			count = 5,
		},
	},
	medium = {
		{
			progress = 0.25,
			count = 4,
		},
		{
			progress = 0.5,
			count = 5,
		},
		-- Jump in difficulty towards the end
		{
			progress = 0.75,
			count = 6,
		},
		{
			progress = 1,
			count = 6,
		},
	},
	hard = {
		{
			progress = 0.25,
			count = 5,
		},
		{
			progress = 0.5,
			count = 6,
		},
		{
			progress = 0.75,
			count = 6,
		},
		{
			progress = 1,
			count = 7,
		},
	},
}

-- elite_counts DO map to difficulty levels of the encounter, in contrast to adaptive_counts.
-- When spawning elites in an ascension, this determines the maximum amount of elites that can spawn within that encounter.
waves.elite_counts = {
	easy = {
		{
			progress = 0.25,
			count = 1,
		},
		{
			progress = 0.5,
			count = 1,
		},
		{
			progress = 0.75,
			count = 2,
		},
		{
			progress = 1,
			count = 2,
		},
		{
			progress = 1.5, --BOSS ROOM
			count = 3,
		},
	},
	medium = {
		{
			progress = 0.25,
			count = 1,
		},
		{
			progress = 0.5,
			count = 2,
		},
		{
			progress = 0.75,
			count = 3,
		},
		{
			progress = 1,
			count = 3,
		},
		{
			progress = 1.5, --BOSS ROOM
			count = 3,
		},
	},
	hard = {
		{
			progress = 0.25,
			count = 2,
		},
		{
			progress = 0.5,
			count = 2,
		},
		{
			progress = 0.75,
			count = 3,
		},
		{
			progress = 1,
			count = 3,
		},
		{
			progress = 1.5, --BOSS ROOM
			count = 3,
		},
	},
}

mapgen.validate.all_keys_are_difficulty(waves.adaptive_counts)
mapgen.validate.has_all_difficulty_keys(waves.adaptive_counts)
local function test_adaptive_counts_has_increasing_progress()
	for diff,tuning in pairs(waves.adaptive_counts) do
		local last_progress = -1
		for _,tier in ipairs(tuning) do
			kassert.greater(tier.progress, last_progress, diff)
			last_progress = tier.progress
		end
	end
end

waves.adaptive = {
	biome = {},
}
waves.adaptive.slot_count_override = {
	-- waves.adaptive_counts is number of units to spawn. Each creature defaults
	-- to 1 unit but specify them here to increase the amount of spawn slots
	-- an enemy takes up.
	cabbagerolls = 2, -- actually 3 mobs, but trying this out since dealing with a 2tower and 3tower aren't that different
	cabbagerolls2 = 2,
	yammo = 2,
	groak = 2,
}
waves.adaptive.biome.treemon_forest = {
	distribution = {
		blarmadillo = 1,
		beets = 2,
		cabbageroll = 3,
		cabbagerolls2 = 2, -- Doesn't actually show up til later -- but have high chance to appear
		yammo = 1,
	},
	min_progress = {
		blarmadillo = 0,
		beets = 0,
		cabbageroll = 0,
		cabbagerolls2 = 0.51,
		yammo = 0.63, -- Two rooms after miniboss
	},
}

waves.adaptive.biome.owlitzer_forest = {
	distribution = {
		gnarlic = 3,
		battoad = 1,
		gourdo = 1,
		-- zucco's spawn via the trickster waves
		cabbagerolls = 2,
		cabbagerolls2 = 2,
	},
	min_progress = {
		battoad = 0.1,
		gnarlic = 0,
		cabbagerolls = 0,
		cabbagerolls2 = 0.33,
		gourdo = 0.51,
	},
}

waves.adaptive.biome.kanft_swamp = {
	distribution = {
		mothball = 3,
		mossquito = 3,
		-- teen moths spawn via the trickster waves
		-- groaks spawn via traps in encounters
		eyev = 1,
	},

	min_progress = {
		mothball = 0,
		mossquito = 0,
		eyev = 0.25,
	},
}

-- TODO @design #thatcher_swamp - proxy data just to make thatcher_swamp playable
waves.adaptive.biome.thatcher_swamp = {
	distribution = {
		mothball = 3,
		swarmy = 3,
		totolili = 1,
		woworm = 1
	},

	min_progress = {
		mothball = 0,
		swarmy = 0,
		totolili = 0.6,
		woworm = 0.3,
	},
}

-- TODO @design #sedament_tundra - adaptive waves
waves.adaptive.biome.sedament_tundra = {
	distribution = {
		blarmadillo = 1,
		gnarlic = 3,
		battoad = 1,
		cabbagerolls = 3,
		cabbagerolls2 = 2,
	},
	min_progress = {
		blarmadillo = 0,
		gnarlic = 0,
		cabbagerolls = 0,
		cabbagerolls2 = 0.33,
		battoad = 0.25,
	},
}
local function test_AdaptiveBiomeCoverage()
	local biomes = require "defs.biomes"
	for id,biome_location in pairs(biomes.locations) do
		if biome_location.type == biomes.location_type.DUNGEON then
			kassert.assert_fmt(waves.adaptive.biome[id], "Missing adaptive wave for biome '%s'.", id)
		end
	end
end

-- Stationary enemy waves
waves.stationary = {
	easy = Wave{
		turret1 = 1,
	},
	medium = Wave{
		turret1 = 2,
	},
	hard = Wave{
		turret1 = 3,
	},
}

-- Traps are biome specific
waves.trapwaves = {
	biome = {},
}
-- Treemon Forest focuses on bombs, with a bit of spike traps
waves.trapwaves.biome.treemon_forest = {
	--bombs
	one_bomb = Wave{
		bombtrap1 = 1,
	},
	two_bombs = Wave{
		bombtrap1 = 2,
	},
	three_bombs = Wave{
		bombtrap1 = 3,
	},

	--blends
	one_bomb_one_spike = Wave{
		bombtrap1 = 1,
		spiketrap1 = 1,
	},
	two_bombs_one_spike = Wave{
		bombtrap1 = 2,
		spiketrap1 = 1,
	},
	three_bombs_one_spike = Wave{
		bombtrap1 = 3,
		spiketrap1 = 1,
	},
}

-- Owlitzer forest focuses on spikes/thorns & wind traps.
waves.trapwaves.biome.owlitzer_forest = {
	--spikes/thorns
	spikes_more = Wave{
		spiketrap1 = 2,
		thorntrap1 = 4
	}:SetProgressRange(0, 0.65),
	spikes_evenmore = Wave{
		spiketrap1 = 2,
		thorntrap1 = 5
	}:SetProgressRange(0, 0.65),
	spikes_n_thorns = Wave{
		spiketrap1 = 3,
		thorntrap1 = 3
	}:SetProgressRange(0, 0.65),

	--blends
	spikes_wind = Wave{
		thorntrap1 = 6,
		spiketrap1 = 1,
		windtrap1 = 1
	}:SetProgressRange(0.5, 0.75),
	thorns_wind_more = Wave{
		thorntrap1 = 8,
		windtrap1 = 1
	}:SetProgressRange(0.6, 1),
	spikes_wind_evenmore = Wave{
		thorntrap1 = 7,
		windtrap1 = 1
	}:SetProgressRange(0.6, 1),
}

waves.trapwaves.biome.kanft_swamp = {
	-- spores -- What if we want multiple spore types in one room?
	spores = Wave{
		sporetrap1 = 4,
	}:SetProgressRange(0, 0.7),
	spores_more = Wave{
		sporetrap1 = 4,
	}:SetProgressRange(0, 0.7),
	spores_evenmore = Wave{
		sporetrap1 = 4,
	}:SetProgressRange(0, 0.7),

	-- stalactites
	stalactite_spores = Wave{
		stalactitetrap1 = 1,
		sporetrap1 = 3,
	}:SetProgressRange(0.65, 1),
	stalacitite_two_spore = Wave{
		stalactitetrap1 = 2,
		sporetrap1 = 2,
	}:SetProgressRange(0.65, 1),
	stalacitite_one_spore = Wave{
		stalactitetrap1 = 3,
		sporetrap1 = 1,
	}:SetProgressRange(0.65, 1),
}

-- TODO @design #thatcher_swamp - proxy data just to make thatcher_swamp playable
waves.trapwaves.biome.thatcher_swamp = {
	-- acid
	acid = Wave{
		acidtrap1 = 1,
	},
	two_acid = Wave{
		acidtrap1 = 2,
	},
}

-- TODO @design #sedament_tundra - trap waves
waves.trapwaves.biome.sedament_tundra = {
	--spikes
	one_spike = Wave {
		spiketrap1 = 1,
	},
	two_spikes = Wave {
		spiketrap1 = 2,
	},
	three_spikes = Wave {
		spiketrap1 = 3,
	},

	--blends
	one_bomb_one_spike = Wave {
		bombtrap1 = 1,
		spiketrap1 = 1,
	},
	one_bomb_two_spikes = Wave {
		bombtrap1 = 1,
		spiketrap1 = 2,
	},
	one_bomb_three_spikes = Wave {
		bombtrap1 = 1,
		spiketrap1 = 3,
	},
}
-----

waves.single_shooty = Wave{
	ranged1 = 1,
}
waves.shooty_easy = Wave{
	melee1 = 1,
	ranged1 = 2,
}
waves.single_melee = Wave{
	melee1 = 1,
}
waves.melee_easy = Wave{
	melee1 = 3,
}
waves.mixed_easy = Wave{
	melee1 = 2,
	ranged1 = 1,
}

-----

waves.shooty_medium = Wave{
	melee1 = 1,
	ranged1 = 3,
}
waves.melee_medium = Wave{
	melee1 = 5,
}
waves.mixed_medium = Wave{
	melee2 = 1,
	melee1 = 1,
	ranged1 = 2,
}

-----

waves.shooty_hard = Wave{
	melee4 = 1,
	ranged1 = 4,
}

waves.melee_hard = Wave{
	melee2 = 2,
}
waves.mixed_hard = Wave{
	melee2 = 1,
	melee4 = 1,
	ranged1 = 2,
}

waves.cabbage_towers = Wave{
	melee3 = 2,
	melee2 = 1,
	melee1 = 1,
}

-----

waves.trickster = Wave{
	trickster2 = 1,
}

waves.single_heavy = Wave{
	melee5 = 1,
}

waves.tricky_heavy = Wave{
	melee5 = 1,
	trickster2 = 1,
}

waves.support_group = Wave{
	support3 = 1,
	melee1 = 3,
}
waves.support_heavy = Wave{
	support3 = 1,
	melee5 = 1,
}

waves.cabbage_swarm = Wave{
	melee1 = 8,
}

waves.cabbage_tower = Wave{
	melee3 = 1,
}

waves.biome = {}
-- BIOME-SPECIFIC WAVES
waves.biome.kanft_swamp = {

}

return waves
