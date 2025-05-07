local kassert = require "util.kassert"
local lume = require "util.lume"

-- We spawn creatures by role and tier. If there isn't a match, then we find
-- the same role at a lower tier and spawn more of that monster.
--
-- Each creature has a tier number (the level they're intended to spawn) and a
-- additional_spawns_per_tier_delta number (how many extra to spawn for each level below the desired
-- tier).

-- monsters can also define a spawn_multiplier as an absolute modifier to how many will spawn.
-- IE: If you ask to spawn 3 of a creature with a spawn_multiplier of 0.5, you will spawn 1.5 (rounded down to 1) of them.
-- If you ask to spawn 3 of a creature with a spawn_multiplier of 2, you will spawn 6 of them.

local monstertiers = {

	roles = {
		ranged = {
			blarmadillo = {
				tier = 1,
				additional_spawns_per_tier_delta = 1,
			},
			mossquito = {
				tier = 1,
				additional_spawns_per_tier_delta = 0.5,
			},
			slowpoke = {
				tier = 1,
				additional_spawns_per_tier_delta = 0.5,
			},
		},
		melee = {
			-- starting forest
			cabbageroll = {
				tier = 1,
				additional_spawns_per_tier_delta = 1,
			},
			cabbagerolls2 = {
				tier = 2,
			},
			cabbagerolls = {
				tier = 3,
				additional_spawns_per_tier_delta = 0.5,
			},
			gnarlic = {
				tier = 1,
				additional_spawns_per_tier_delta = 1,
			},
			beets = {
				tier = 1,
				additional_spawns_per_tier_delta = 1,
			},
			eyev = {
				tier = 5,
				additional_spawns_per_tier_delta = 0.1,
			},
			yammo = {
				tier = 5,
				additional_spawns_per_tier_delta = 0.1,
			},
			battoad = {
				tier = 1,
				additional_spawns_per_tier_delta = 0.1,
			},
			groak = {
				tier = 5,
				additional_spawns_per_tier_delta = 0.1,
			},

			-- swamp
			mothball = {
				tier = 1,
				additional_spawns_per_tier_delta = 2,
				spawn_multiplier = 2,
			},
			floracrane = {
				tier = 5,
				additional_spawns_per_tier_delta = 0.1,
			},
			swarmy = {
				tier = 1,
				additional_spawns_per_tier_delta = 1,
			},
			woworm = {
				tier = 3,
				additional_spawns_per_tier_delta = 0.25,
			},

			-- volcano
			warmy = {
				tier = 3,
				additional_spawns_per_tier_delta = 1,
			},
		},
		support = {
			gourdo = {
				tier = 1,
				additional_spawns_per_tier_delta = 0,
			},
			bulbug = {
				tier = 1,
				additional_spawns_per_tier_delta = 0,
			},
		},
		trickster = {
			zucco = {
				tier = 2,
				additional_spawns_per_tier_delta = 0.25,
			},
			mothball_teen = {
				tier = 2,
				additional_spawns_per_tier_delta = 0.5,
			},
			totolili = {
				tier = 2,
				additional_spawns_per_tier_delta = 0.25,
			},
		},
		turret = {
			treemon = {
				tier = 1,
				additional_spawns_per_tier_delta = 0.2,
			},
			sporemon = {
				tier = 1,
				additional_spawns_per_tier_delta = 0.2,
			},
			windmon = {
				tier = 1,
				additional_spawns_per_tier_delta = 0.2,
			},
			--mothball_spawner = { -- This is spawned directly in custom encounters
			--	tier = 2,
			--	additional_spawns_per_tier_delta = 0.5,
			--	spawn_multiplier = 0.5,
			--},
		},
	},
	tierlist = {}, -- descending order of tier
}

-- TODO(dbriscoe): Define roles with AddMonster instead.
function monstertiers.AddMonster(prefab, role, tier_data)
	monstertiers.roles[role][prefab] = tier_data
	monstertiers.is_dirty = true
end

function monstertiers.FinalizeTiers()
	monstertiers.is_dirty = false
	for role, horde in pairs(monstertiers.roles) do
		local tierlist = {}
		for prefab, monster in pairs(horde) do
			monster.additional_spawns_per_tier_delta = monster.additional_spawns_per_tier_delta or 1
			monster.prefab = prefab
			table.insert(tierlist, monster)
		end
		table.sort(tierlist, function(a, b)
			if a.tier == b.tier then
				-- If their tiers are the same, sort by name instead?
				return a.prefab > b.prefab
			end
			return a.tier > b.tier
		end)
		monstertiers.tierlist[role] = tierlist
	end
	assert(
		monstertiers.tierlist.melee[1].tier >= monstertiers.tierlist.melee[#monstertiers.tierlist.melee].tier,
		"Tierlist should be in descending order."
	)
end

function monstertiers.FindRoleForMonster(monster)
	kassert.typeof("string", monster) -- prefab name
	for role, horde in pairs(monstertiers.roles) do
		if horde[monster] then
			return role
		end
	end
end

function monstertiers.ConvertRoleToMonster(biome_location, role, tier, count, rng)
	TheLog.ch.Spawn:printf("monstertiers.ConvertRoleToMonster(%s, %s%d, %s)", biome_location.id, role, tier, count)

	kassert.assert_fmt(role, "Unknown role name format: %s%d", role, tier)
	tier = tonumber(tier or 1) -- optional for roles where there's only one level.

	assert(not monstertiers.is_dirty, "Forgot to call monstertiers.FinalizeTiers.")

	local allowed = biome_location.monsters.allowed_mobs

	local candidates = monstertiers.tierlist[role]
	rng:Shuffle(candidates)

	kassert.assert_fmt(candidates, "Unknown role: %s", role)
	for _, monster in ipairs(candidates) do
		local delta = tier - monster.tier

		-- We can use easier enemies for fallbacks, not harder ones.
		if allowed[monster.prefab] and delta >= 0 then
			if delta > 0 then
				count = count * ((1 + delta) * monster.additional_spawns_per_tier_delta)
			end

			if monster.spawn_multiplier then
				count = count * monster.spawn_multiplier
			end

			count = math.max(1, math.floor(count))

			if count > 0 then
				return monster.prefab, count
			end
		end
	end
	TheLog.ch.Spawn:printf("Error: failed to find monster in biome '%s' for role '%s'.", biome_location.id, role)
	return nil, 0
end

function monstertiers.GetSpawnMultiplier(prefab)
	local data
	for role, roledata in pairs(monstertiers.roles) do
		for monstername, monsterdata in pairs(roledata) do
			if monstername == prefab then
				data = monsterdata
				break
			end
		end
	end
	assert(data, "Trying to GetSpawnMultiplier for something that doesn't have a monstertier")
	return data.spawn_multiplier
end

local function test_biomecoverage()
	local biomes = require "defs.biomes"

	local all_roles = lume(monstertiers.roles)
		:keys()
		:invert()
		:result()
	for id,biome_location in pairs(biomes.locations) do
		if biome_location.type == biomes.location_type.DUNGEON then
			local biome_roles = {}
			for _, prefab in ipairs(biome_location.monsters.mobs) do
				local role = monstertiers.FindRoleForMonster(prefab)
				kassert.assert_fmt(all_roles[role], "No role for monster '%s' living in biome '%s'.", prefab, id)
				biome_roles[role] = true
			end
			for role in pairs(all_roles) do
				kassert.assert_fmt(biome_roles[role], "Missing monster with role '%s' in biome '%s'.", role, id)
			end
		end
	end
end

local function test_monstertiers()
	local krandom =  require "util.krandom"
	local rng = krandom.CreateGenerator()
	local mock = require "util.mock"
	mock.set_globals()

	local biomes = require "defs.biomes"
	local b = biomes.locations.treemon_forest
	local prefab, count = monstertiers.ConvertRoleToMonster(b, "melee", 6, 1, rng)
	kassert.equal(prefab, "yammo")
	kassert.equal(count, 1)
	prefab, count = monstertiers.ConvertRoleToMonster(b, "bombtrap", 1, 1, rng)
	kassert.equal(prefab, "trap_bomb_pinecone")
	prefab, count = monstertiers.ConvertRoleToMonster(b, "melee", 3, 3, rng)
	kassert.equal(prefab, "cabbagerolls")
	kassert.equal(count, 3)
	prefab, count = monstertiers.ConvertRoleToMonster(b, "melee", 3, 3, rng)
	kassert.equal(prefab, "cabbagerolls")
	kassert.equal(count, 3)

	b = biomes.locations.kanft_swamp
	local battier = monstertiers.roles.melee.battoad.tier
	prefab, count = monstertiers.ConvertRoleToMonster(b, "melee", battier, 1, rng)
	kassert.equal(prefab, "battoad")
	kassert.equal(count, 1)
	prefab, count = monstertiers.ConvertRoleToMonster(b, "melee", (battier + 1), 2, rng)
	kassert.equal(prefab, "battoad")
	kassert.equal(count, 4, "Expected one extra per tier")
end

monstertiers.FinalizeTiers()

return monstertiers
