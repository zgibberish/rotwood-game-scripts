-- SceneGen component.
-- A SceneGen generates prop placements at runtime. Its member data specializes it for a particular dungeon.

local KRandom = require "util.krandom"
local Lume = require "util.lume"
local ZoneGrid = require "map.zone_grid"
local MapLayout = require "util.maplayout"
local ZoneGen = require "proc_gen.zone_gen"
local PropAutogenData = require "prefabs.prop_autogen_data"
local DungeonProgress = require "proc_gen.dungeon_progress"
local UnderlayPropGen = require "proc_gen.underlay_prop_gen"
local PropProcGen = require "proc_gen.prop_proc_gen"
local Hsb = require "util.hsb"
require "proc_gen.zone_gen_builder"
require "proc_gen.weighted_choice"

local SceneGen = Class(function(self, entity, params)
	self.name = entity.prefab
	for k, v in pairs(params) do
		self[k] = v
	end
	self.InjectClasses(self)
end)

SceneGen.TIER_COUNT = 10

SceneGen.ROOM_PARTICLE_SYSTEM_TAG = "ROOM_PARTICLE_SYSTEM_TAG"

-- Claim sole occupancy of the space in which the entity is located. That is, destroy all
-- other occupants.
function SceneGen.ClaimSoleOccupancy(entity, radius)
	entity:AddComponent("soleoccupant", radius or 2.0, {DecorTags[DecorLayer.id.Ground]}, { SceneGen.ROOM_PARTICLE_SYSTEM_TAG })
end

function SceneGen.InjectClasses(scene_gen)
	scene_gen.zone_gens = Lume(scene_gen.zone_gens)
		:enumerate(function(i, zone_gen)
			zone_gen.tag = "ZONE_GEN_TAG"..i
			return ZoneGen.FromRawTable(zone_gen)
		end)
		:result()
	scene_gen.underlay_props = scene_gen.underlay_props and Lume(scene_gen.underlay_props)
		:map(function(underlay_prop)
			return UnderlayPropGen.FromRawTable(underlay_prop)
		end)
		:result()
	Lume(scene_gen.creature_spawners)
		:each(function(creature_spawner_category)
			Lume(creature_spawner_category)
				:each(function(creature_spawner)
					creature_spawner.color = creature_spawner.color
						and Hsb.FromRawTable(creature_spawner.color)
						or Hsb()
				end)
		end)
end

local FEATURED_PROPS = { 
	room_loot = true, 
	flying_machine = true, 
	spawner_npc_dungeon = true,
	spawner_player = true
}

local function CollectDestructiblesInternal(destructibles)
	local progress = TheWorld:GetDungeonProgress()
	return Lume(destructibles)
		:map(function(destructible)
			return {
				prop = destructible.prop,
				likelihood = DungeonProgress.ComputeLikelihood(progress, destructible.dungeon_progress_constraints)
			}
		end)
		:result()
end

function SceneGen:CollectDestructibles()
	return CollectDestructiblesInternal(self.destructibles)
end

function SceneGen.CollectFeaturedLocations(layout, map_layout, world_map, authored_prop_placements)
	local featured_locations = {}

	-- Process the authored_props to determine the initial featured locations.
	for prop_name, placements in pairs(authored_prop_placements) do
		-- if string.match(prop_name, "spawner") or prop_name == "room_loot" then
		local autogen_prop = PropAutogenData[prop_name]
		local featured = FEATURED_PROPS[prop_name] or (autogen_prop and autogen_prop.script == "creaturespawner")
		if featured then
			for _, placement in ipairs(placements) do
				table.insert(featured_locations, { x = placement.x or 0, z = placement.z or 0 })
			end
		end
	end

	-- Objects placed in the layout may be considered features too.
	-- Skip the ground layer
	local exits = {}
	for i = 2, #layout.layers do
		local layer = layout.layers[i]
		if layer.objects then
			for _, object in ipairs(layer.objects) do
				if object.type == "room_portal" then
					local record = map_layout:ConvertLayoutObjectToSaveRecord(object)
					table.insert(exits, { x = record.x or 0, z = record.z or 0 })
				end
			end
		end
	end

	-- HACK @chrisp #proc_gen - register the origin as a featured location in the entrance rooms because that is where
	-- we spawn the player
	if world_map:IsCurrentRoomDungeonEntrance() then
		table.insert(featured_locations, {
			player = { x = 0, z = 0 },
			exits = exits
		})
	else
		featured_locations = table.appendarrays(featured_locations, exits)
	end

	return featured_locations
end

function SceneGen:GetTier()
	return self.tier or 1
end

-- global("scene_gen_execution_report")
scene_gen_execution_report = {}

local function MakeZoneSetKey(zones)
	return Lume(zones)
		:sort()
		:reduce(function(current, zone)	return current..", "..zone end)
		:result()
end

local function ExtractZonesFromZoneSetKey(zone_set_key)
	local zones = {}
	string.gsub(zone_set_key, "([%a_]+)", function(zone)
		table.insert(zones, zone)
	end)
	return zones
end

local function CollectCollisionCircles(decor_layer, zones)
	local circles = {}
	-- For each zone_set of circles in the decor_layer...
	for zone_set_key, decor_zone in pairs(decor_layer) do
		local zone_set = ExtractZonesFromZoneSetKey(zone_set_key)
		-- If any zone of the current ZoneGen is in that zone set, include those circles.
		if Lume(zones):any(function(zone) return Lume(zone_set):find(zone):result() end):result() then
			circles = table.appendarrays(circles, decor_zone)
		end
	end
	return circles
end

-- Static function to build a scene, used by SceneGenEditor and SceneGen prefab.
function SceneGen.StaticPlanScene
	( scene_gen
	, layout
	, world_map
	, authored_prop_placements
	, rng
	, zone_grid
	, zone_gens
	, dungeon_progress
	, room_type
	, underlay
	, room_particle_systems
	)
	TheSim:ProfilerPush("PlanScene")

	-- TODO @chrisp #scenegen - in release mode, we should set execution_report to nil?
	scene_gen_execution_report.name = scene_gen.__displayName
	scene_gen_execution_report.dungeon_progress = dungeon_progress
	scene_gen_execution_report.zone_gens = {}

	TheWorld.prop_rng = rng

	local map_layout = MapLayout(layout)
	
	local all_placements = {}

	if underlay then
		local underlay = WeightedChoice(rng, scene_gen.underlay_props, function(prop)
			if not prop.enabled then
				return 0
			elseif prop:GetDungeonProgressConstraints() then
				return DungeonProgress.ComputeLikelihood(dungeon_progress, prop:GetDungeonProgressConstraints())
			else
				return 1
			end
		end)
		if underlay then
			-- Find a cell in the underlay zone and use its z-value.
			local x = math.floor(zone_grid.width / 2)
			for z = 0, zone_grid.height - 1 do
				if zone_grid.position_filters[PropProcGen.Zone.s.underlay](x, z) then
					local prefab = underlay:GetPropName()
					all_placements[prefab] = all_placements[prefab] or {}
					table.insert(all_placements[prefab], zone_grid:GridToWorld({x=x, y=0, z=z}))
					break
				end
			end
		end
	end

	if room_particle_systems then
		Lume(scene_gen.particle_systems):each( function(particle_system)
			if not particle_system.enabled then
				return
			end
			if particle_system.dungeon_progress_constraints then
				local likelihood = DungeonProgress.ComputeLikelihood(dungeon_progress, particle_system.dungeon_progress_constraints)
				if likelihood < rng:Float(0.0, 1.0) then
					return
				end
			end
			local prefab = particle_system.particle_system
			all_placements[prefab] = all_placements[prefab] or {}
			table.insert(all_placements[prefab], {x=0, y=0, z=0, tags={SceneGen.ROOM_PARTICLE_SYSTEM_TAG}})
		end)
	end

	local featured_locations = SceneGen.CollectFeaturedLocations(
		layout, 
		map_layout, 
		world_map, 
		authored_prop_placements
	)
	scene_gen_execution_report.featured_locations = featured_locations

	-- decor_zones will track the collision circles of all placed props.
	-- DecorLayers will be mutually exclusive. So, for example, Ground prop collision circles are kept separate from
	-- Canopy prop collision circles such that the props in those two layers are permitted to overlap.
	-- Beneath the DecorLayer key, there is another dict-like table keyed by "zone set". Every ZoneGen may operate
	-- over multiple zones and those form a zone set. To compute the set of all extant collision circles for a ZoneGen 
	-- that is about to be built, every zone in the ZoneGen's set is considered individually, and for every zone set
	-- of which it is a part, those circles are included. This is a lot of relatively complex set intersection.
	local decor_layers = {}
	for _, decor_layer in ipairs(DecorLayer:Ordered()) do
		decor_layers[decor_layer] = {}
	end

	local active_zone_gens = Lume(zone_gens)
		:filter(function(zone_gen) return zone_gen.enabled end)
		:filter(function(zone_gen) return Lume(zone_gen.room_types):find(room_type):result() end)
		:result()
	for i, zone_gen in ipairs(active_zone_gens) do
		TheSim:ProfilerPush(zone_gen:GetLabel())
		local zone_report
		if scene_gen_execution_report then
			zone_report = {name = zone_gen:GetLabel()}
			table.insert(scene_gen_execution_report.zone_gens,  zone_report)
		end

		-- Collect collision circles from all zone_set_keys that contain any of our zones.
		local decor_layer = decor_layers[zone_gen.decor_layer or DecorLayer.s.Ground]
		local collision_circles = CollectCollisionCircles(decor_layer, zone_gen.zones)

		local zone_placements, spawn_health, zone_circles, placement_circles = BuildZone(
			scene_gen, 
			zone_gen, 
			rng, 
			zone_grid, 
			map_layout, 
			featured_locations, 
			collision_circles,
			zone_report,
			dungeon_progress
		)

		-- Accumulate the placements from this ZoneGen.
		for prefab, location_list in pairs(zone_placements) do
			all_placements[prefab] = table.appendarrays(all_placements[prefab] or {}, location_list)
		end

		if zone_circles and next(zone_circles) then
			-- Only write our circles to our specific zone_set_key.
			local zone_set_key = MakeZoneSetKey(zone_gen.zones)
			decor_layer[zone_set_key] = table.appendarrays(decor_layer[zone_set_key] or {}, zone_circles)
		end
		if zone_report then	
			zone_report.spawn_health = spawn_health
			zone_report.placement_circles = placement_circles
		end
		TheSim:ProfilerPop()
	end

	TheSim:ProfilerPop()

	return all_placements
end

-- Plan the parts of the scene as defined by zone_gens, underlay, and room_particle_systems.
-- Then spawn scene elements.
-- Then apply lighting and sky.
function SceneGen.StaticBuildScene(
	scene_gen, 
	world, 
	dungeon_progress, 
	authored_prop_placements, 
	rng, 
	zone_grid, 
	room_type, 
	zone_gens, 
	underlay, 
	room_particle_systems
)
	local dynamic_elements = SceneGen.StaticPlanScene
		( scene_gen
		, world.layout
		, TheDungeon:GetDungeonMap()
		, authored_prop_placements
		, rng
		, zone_grid
		, zone_gens
		, dungeon_progress
		, room_type
		, underlay
		, room_particle_systems
		)
	-- TODO @chrisp #scenegen - PropManager is an editor utility and we should not be using it
	-- If we need to spawn entities in a manner consistent with the PropManager, we need to factor
	-- that functionality.
	world.components.propmanager:SpawnDynamicProps(dynamic_elements)

	-- If the world prefab did not alreadby apply lighting, have TheSceneGen do it.
	SceneGen.ApplyEnvironment(world, scene_gen, dungeon_progress, room_type)
end

-- Plan the *entire* scene, and spawn elements.
function SceneGen:BuildScene(world, dungeon_progress, authored_prop_placements)
	local worldmap = TheDungeon:GetDungeonMap()
	local seed = worldmap:GetRNG():Integer(math.maxinteger)
	TheLog.ch.SceneGen:printf("SceneGen BuildScene Random Seed: %d", seed)

	world.zone_grid = ZoneGrid(MapLayout(world.layout))

	self.StaticBuildScene(
		self, 
		world, 
		dungeon_progress,
		authored_prop_placements, 
		KRandom.CreateGenerator(seed), -- @chrisp #proc_rng
		world.zone_grid, 
		worldmap:GetCurrentRoomType(), 
		self.zone_gens,
		true, 
		true
	)
end

function SceneGen.ApplyEnvironment(world, scene_gen, dungeon_progress, current_room_type_override)
	local current_room_type = current_room_type_override or TheDungeon:GetDungeonMap():GetCurrentRoomType()
	local dungeon_environment
	if not scene_gen.environments then
		dungeon_environment = scene_gen
	else
		local valid_environments = Lume(scene_gen.environments):filter(function(environment)
			return Lume(environment.room_types):any(function(room_type) 
				return current_room_type == room_type
			end):result()
		end):result()
		dungeon_environment = #valid_environments > 0 and world.prop_rng:PickValue(valid_environments)
		if not dungeon_environment then		
			TheLog.ch.SceneGen:printf("No environment for room type [%s]. Using first environment as fallback.", current_room_type)
			dungeon_environment = scene_gen.environments[1]
		end
		if not dungeon_environment then
			TheLog.ch.SceneGen:printf("No environments defined for SceneGen [%s]", scene_gen.name)
			return
		end
	end
	if not world.scene_gen_overrides.lighting then
		ApplyLighting(dungeon_environment.lighting, dungeon_progress)
	end
	if not world.scene_gen_overrides.sky then
		ApplySky(dungeon_environment.sky, dungeon_progress)
	end
	if not world.scene_gen_overrides.water then
		ApplyWater(dungeon_environment.water, dungeon_progress)
	end
end

return SceneGen
