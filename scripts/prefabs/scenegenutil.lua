-- A SceneGen generates prop placements at runtime. Its member data specializes it for a particular dungeon.

local SceneGenAutogenData = require "prefabs.scenegen_autogen_data"
local kassert = require "util.kassert"
local Lume = require "util.lume"
local GroundTiles = require "defs.groundtiles"
require "prefabs.world_autogen" -- for CollectAssetsFor*


-- Store lookup of prefab_lookup[biome-name][location-name] = Prefab
-- Default to nil so we crash if we forget to call EnsurePrefabsExist.
local prefab_lookup

-- The constructor creates an Entity from this Prefab.
local function NewSceneGenEntity(name, params)
	local entity = CreateEntity()
	entity:SetPrefabName(name)

	-- TODO we can hook into external event points
	-- entity.OnLoad = OnLoadWorld
	-- entity.OnRemoveEntity = OnRemoveEntity
	-- entity.OnPreLoad = OnPreLoad

	-- TODO translate edit-time params into runtime state
	entity:AddComponent("scenegen", params)

	return entity
end

-- Register the SceneGen Prefab in a global dictionary so we can look it up via biome/dungeon later.
-- Mods may similarly register their SceneGens, or even stomp prior registrations.
local function RegisterSceneGenPrefab(scene_gen, prefab)
	if scene_gen.biome and scene_gen.dungeon then
		prefab_lookup[scene_gen.biome] = prefab_lookup[scene_gen.biome] or {}
		prefab_lookup[scene_gen.biome][scene_gen.dungeon] = prefab
	end
end

-- A prefab is a constructor function and all of its dependencies.
local function NewSceneGenPrefab(name, params)
	local Biomes = require "defs.biomes"
	local props = params.zone_gens
		and Lume(params.zone_gens)
			:map(function(zone_gen)
				return zone_gen.scene_props
					and Lume(zone_gen.scene_props)
						:map(function(scene_prop) return scene_prop.prop end)
						:result()
					or {}
			end)
			:result()
		or {}
	local destructibles = params.destructibles
		and Lume(params.destructibles)
			:map(function(destructible) return destructible.prop end)
			:result()
		or {}
	local underlay_props = params.underlay_props
		and Lume(params.underlay_props)
			:map(function(prop) return prop.prop end)
			:result()
		or {}
	local particle_systems = params.particle_systems
		and Lume(params.particle_systems)
			:map(function(particle_system) return particle_system.particle_system end)
			:result()
		or {}
	local creature_spawners = {}
	for _, category in pairs(params.creature_spawners) do
		for _, spawner in ipairs(category) do
			table.insert(creature_spawners, spawner.prop)
		end
	end

	local prefabs = {}
	local assets = {}
	prefabs = table.appendarrays(prefabs, table.unpack(props))
	prefabs = table.appendarrays(prefabs, creature_spawners)
	prefabs = table.appendarrays(prefabs, destructibles)
	prefabs = table.appendarrays(prefabs, underlay_props)
	prefabs = table.appendarrays(prefabs, particle_systems)	
	if params.rooms then
		prefabs = table.appendarrays(prefabs, params.rooms)
	end
	prefabs = Lume(prefabs):unique():result()
	local location_deps = Biomes.GetLocationDeps(params.biome, params.dungeon)
	if location_deps then
		table.insert(assets, location_deps.tile_bank)
		prefabs = table.appendarrays(prefabs, location_deps.prefabs)
	end
	
	for _, environment in ipairs(params.environments) do
		if environment.lighting.colorcube then 
			CollectAssetsForColorCube(assets, environment.lighting.colorcube.entrance)
			CollectAssetsForColorCube(assets, environment.lighting.colorcube.boss) 
		end
		CollectAssetsForCliffRamp(assets, environment.lighting.clifframp)
		CollectAssetsForCliffSkirt(assets, environment.lighting.cliffskirt)

		if environment.water then
			CollectAssetsForWaterRamp(assets, environment.water.water_settings and environment.water.water_settings.ramp)	
		end
	end

	if params.tile_group then
		GroundTiles.CollectAssetsForTileGroup(assets, params.tile_group)
	end

	local prefab = Prefab(
		name,
		function(_) return NewSceneGenEntity(name, params) end,
		assets,
		prefabs
	)
	RegisterSceneGenPrefab(params, prefab)
	return prefab
end

local groups = {}
for name, params in pairs(SceneGenAutogenData) do
	-- If the prefab specifies a group, manifest the group and add the prefab to it.
	if params.group ~= nil and string.len(params.group) > 0 then
		local group = groups[params.group] or {}
		table.insert(group, name)
		groups[params.group] = group
	end
end

-- In addition to all of the SceneGen prefabs, return all the group prefabs.
local group_prefabs = Lume(groups)
	:enumerate(function(name, group)
		return not name:lower():startswith("test")
			and Prefab(GroupPrefab(name), nil, nil, group)
	end)
	:result()




local scenegenutil = {}
scenegenutil.ASSERT_ON_FAIL = { "assert_on_fail" }

local all_prefabs

-- Semi-lazily create prefabs. When scenegenutil is only used for queries, we
-- only create the prefabs when one of the functions is called. When used in
-- game, collecting prefabs will immediately create all prefabs so they always
-- exist. Being slightly lazy helps speed up test code that might require this
-- file, but not call it.
local function EnsurePrefabsExist()
	if not all_prefabs then
		prefab_lookup = {}
		all_prefabs = Lume(SceneGenAutogenData)
			:enumerate(NewSceneGenPrefab)
			:merge(group_prefabs)
			:values()
			:result()
	end
end



-- Only for scenegen_autogen. Use GetSceneGenForBiomeLocation to look up scenegens.
function scenegenutil.GetAllPrefabs()
	EnsurePrefabsExist()
	return all_prefabs
end

-- Returns the prefab name for the input biome location.
function scenegenutil.GetSceneGenForBiomeLocation(region_id, location_id, assert_on_failure)
	EnsurePrefabsExist()
	local prefab_list = prefab_lookup[region_id]
	local scene_gen = prefab_list and prefab_list[location_id]
	kassert.assert_fmt(
		not assert_on_failure or scene_gen,
		"No SceneGen registered for %s.%s. Create one and assign it in SceneGenEditor. Then restart the game.",
		region_id,
		location_id
	)
	return scene_gen and scene_gen.name
end

-- Returns the prefab name matching the input location.
function scenegenutil.FindSceneGenForLocation(location_id)
	EnsurePrefabsExist()
	for _, scene_gens in pairs(prefab_lookup) do
		local scene_gen = scene_gens[location_id]
		if scene_gen then
			return scene_gen.name
		end
	end
end

function scenegenutil.FindLayoutsForRoomSuffix(scene_gen, suffix)
	kassert.typeof("string", scene_gen)
	local scene_data = SceneGenAutogenData[scene_gen]
	if scene_data and scene_data.rooms then
		return Lume(scene_data.rooms)
			:filter(function(scene_gen_room)
				return string.endswith(scene_gen_room, suffix)
			end)
			:result()
	end
end

function scenegenutil.GetAllLocations()
	EnsurePrefabsExist()
	local locations = {}
	for _, scene_gens in pairs(prefab_lookup) do
		locations = table.appendarrays(locations, Lume(scene_gens):keys():result())
	end
	table.sort(locations)
	return locations
end

return scenegenutil
