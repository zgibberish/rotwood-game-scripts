local spawnutil = require "util.spawnutil"


local assets = spawnutil.GetEditableAssets()

local patterns = spawnutil.CenterPatternsOnOrigin({
		{
			{ prefab="tree",    x=-5.76, z=-6.23, },
			{ prefab="tree",    x=-7.76, z=1.77,  },
			{ prefab="tree",    x=-9.76, z=-4.23, },
			{ prefab="tree",    x=8.24,  z=4.77,  },
			{ prefab="tree",    x=-2.76, z=0.77,  },
			{ prefab="tree",    x=6.24,  z=-0.23, },
			{ prefab="treemon", x=1.24,  z=-5.23, },
			{ prefab="treemon", x=2.24,  z=4.77,  },
		},
		{
			{ prefab="tree",    x=-1.89, z=4.06,  },
			{ prefab="tree",    x=-1.89, z=-2.94, },
			{ prefab="tree",    x=-5.89, z=0.06,  },
			{ prefab="tree",    x=5.11,  z=5.06,  },
			{ prefab="tree",    x=5.11,  z=-1.94, },
			{ prefab="treemon", x=-6.89, z=-3.94, },
			{ prefab="treemon", x=2.11,  z=0.06,  },
			{ prefab="treemon", x=7.11,  z=-4.94, },
		},
		{
			{ prefab="tree",    x=-8.89, z=-5.94, },
			{ prefab="tree",    x=-8.89, z=3.06,  },
			{ prefab="tree",    x=-2.89, z=3.06,  },
			{ prefab="tree",    x=8.11,  z=6.06,  },
			{ prefab="tree",    x=-1.89, z=-2.94, },
			{ prefab="tree",    x=8.11,  z=-4.94, },
			{ prefab="treemon", x=-5.89, z=-1.94, },
			{ prefab="treemon", x=3.11,  z=3.06,  },
		},
		{
			{ prefab="tree",    x=4.11,  z=-1.94, },
			{ prefab="tree",    x=-7.89, z=-3.94, },
			{ prefab="tree",    x=-8.89, z=2.06,  },
			{ prefab="tree",    x=1.11,  z=3.06,  },
			{ prefab="tree",    x=8.11,  z=-5.94, },
			{ prefab="tree",    x=6.11,  z=2.06,  },
			{ prefab="treemon", x=-3.89, z=3.06,  },
			{ prefab="treemon", x=0.11,  z=-3.94, },
		},
	})

-- For now, lump these all into a single spawner. We might want to split these
-- out and place different spawners in each biome?
local biome_remap_prefabs = {
	kanft_swamp = {
		tree = {
			"bandiforest_grid_stump1",
			"bandiforest_grid_stump2",
			"bandiforest_grid_stump3",
		},
	},
}

local prefabs = spawnutil.GetPossiblePrefabsFromPatterns(patterns)
for _,biome_remap in pairs(biome_remap_prefabs) do
	for _,biome_prefabs in pairs(biome_remap) do
		table.appendarrays(prefabs, biome_prefabs)
	end
end

local function DrawDestinations(inst)
	if c_sel() == inst then
		spawnutil.DrawPatternLocation(inst, patterns)
	end
end

local function EditEditable(inst, ui)
	spawnutil.PatternsEditor(inst, ui, patterns)
end

local function DoSpawn(inst, difficulty)
	local rng = TheWorld.components.spawncoordinator:GetRNG()
	local pattern = rng:PickFromArray(patterns)
	local remap = biome_remap_prefabs[TheDungeon:GetDungeonMap():GetBiomeLocation().id]
	if remap then
		pattern = deepcopy(pattern)
		for _,s in ipairs(pattern) do
			local replacements = remap[s.prefab]
			if replacements then
				s.prefab = rng:PickFromArray(replacements)
			end
		end
	end
	spawnutil.SpawnPattern(inst, pattern)

	spawnutil.FlagForRemoval(inst)
end

local function OnPostLoadWorld(inst)
	inst.difficulty = TheDungeon:GetDungeonMap():GetDifficultyForCurrentRoom()
	local can_spawn_resources = TheDungeon:GetDungeonMap():DoesCurrentRoomHaveResources()
	if can_spawn_resources then
		DoSpawn(inst, inst.difficulty)
	end
end

local function fn()
	local inst = spawnutil.CreatePatternSpawner()

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		spawnutil.MakeEditable(inst, "square")
		-- In Tiled, we need grassy areas that are 5x3.
		inst.AnimState:SetScale(10, 6)
		inst.debug_draw_task = inst:DoPeriodicTask(0, DrawDestinations, 0)
		inst.EditEditable = EditEditable
	else
		inst.OnPostLoadWorld = OnPostLoadWorld
	end

	return inst
end

return Prefab("tree_spawner", fn, assets, prefabs)
