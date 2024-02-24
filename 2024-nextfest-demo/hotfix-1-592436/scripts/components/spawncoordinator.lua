local DebugDraw = require "util.debugdraw"
local EffectEvents = require "effectevents"
local encounters = require "encounter.encounters"
local kassert = require "util.kassert"
local krandom = require "util.krandom"
local lume = require "util.lume"
local mapgen = require "defs.mapgen"
local waves = require "encounter.waves"
local prop_data = require("prefabs.prop_autogen_data")
local monstertiers = require "defs.monstertiers"
local monsterutil = require("util.monsterutil")
local SceneGen = require "components.scenegen"

require "class"
require "util"

local DumpSpawnerInfo = function(spawners)
	for i,v in ipairs(spawners) do
		TheLog.ch.Spawn:printf("%d %1.3f %s", i, Vector2.len2(Vector2(v.Transform:GetWorldXZ())), tostring(v))
	end
end

local SpawnCoordinator = Class(function(self, inst)
	self.inst = inst
	self.data = {
		total_stationary_enemy_count = 0,
		total_spawn_count = 0,
		total_trap_count = 0,
		total_propdestructible_count = 0,
		is_room_complete = true,
	}

	self.spawners = {}
	self.stationary_spawners = {}
	self.trap_locations = {}
	self.propdestructible_locations = {}
	self.seconds_before_spawn = 0

	self.initial_scenario_entities = {}
	self.limbo_entities = {}

	self.elite_current = 0
	self.elite_miniboss = false

	self._onroomcleared = function(...)
		self:_OnRoomCleared(...)
	end

	self._onplayeractivated = function(...)
		self:_OnPlayerActivated(...)
	end

	if not inst.components.cororun then
		inst:AddComponent("cororun")
	end
end)

-- Spawners register themselves with these Add functions on load.

function SpawnCoordinator:AddSpawner(spawner_ent)
	table.insert(self.spawners, spawner_ent)
end

function SpawnCoordinator:AddStationarySpawner(spawner_ent)
	table.insert(self.stationary_spawners, spawner_ent)
end

function SpawnCoordinator:AddTrapSpawner(spawner_ent, trap_types)
	-- trap_types is expected to come in as a dictionary (k: trap prefab name, v: true)
	assert(not trap_types or next(trap_types) == nil or not lume.isarray(trap_types), "trap_types expected as nil, empty, or dictionary for SpawnTraps")
	table.insert(self.trap_locations, { spawner_ent = spawner_ent, trap_types = trap_types } )
end

function SpawnCoordinator:AddPropDestructibleSpawner(spawner_ent, prop_types)
	table.insert(
		self.propdestructible_locations,
	{
			spawner_ent = spawner_ent,
			prop_types = prop_types,
			likelihood_total = lume(prop_types)
				:map(function(destructible) return destructible.likelihood or 1 end)
				:reduce(function(a, b) return a + b end)
				:result()
		}
	)
end


local function is_too_close(entrance_pos, ent)
	local max_dist_sq = 10*10
	local delta = ent:GetPosition() - entrance_pos
	return delta:LengthSq() < max_dist_sq
end

-- Wave spawning currently only supports basic monster and miniboss rooms.
function SpawnCoordinator:_GetRoomType()
	local worldmap = TheDungeon:GetDungeonMap()
	if worldmap:HasEnemyForCurrentRoom("monster") then
		return "monster"
	elseif worldmap:HasEnemyForCurrentRoom("miniboss") then
		return "miniboss"
	end
end

function SpawnCoordinator:Debug_GetEncounterListForCurrentRoom()
	local room_type = self:_GetRoomType()
	return room_type and TheDungeon:GetDungeonMap().encounter_deck.room_type_encounters(room_type)
end

function SpawnCoordinator:Debug_GetEncounterCallstack()
	return self.thread and debug.traceback(self.thread.c) or "<none>"
end

function SpawnCoordinator:OnStartRoom()
	self:_PrepareForSpawn()
	-- Delay to ensure we're not still in StartRoom.
	self.inst:DoTaskInTime(0, function(inst_)
		-- SpawnCoordinator is ready to do spawning (and may have already
		-- spawned some things).
		self.inst:PushEvent("spawncoordinator_ready")
	end)
end

function SpawnCoordinator:_RemoveFromScene(ent)
	self.limbo_entities[ent] = true
	ent:RemoveFromScene()
end

function SpawnCoordinator:_ReturnToScene(ent)
	self.limbo_entities[ent] = nil
	ent:ReturnToScene()
end

function SpawnCoordinator:_PrepareForSpawn()
	-- Always want to fire room_complete via room_cleared when enemies are cleared.
	self.inst:ListenForEvent("room_cleared", self._onroomcleared, TheWorld)
	self.inst:ListenForEvent("playeractivated", self._onplayeractivated, TheWorld)

	-- Always want room to be locked until we unlock in _EndEncounter.
	self.inst.components.roomlockable:AddLock(self.inst)

	local worldmap = TheDungeon:GetDungeonMap()

	local seed = worldmap:GetRNG():Integer(2^32 - 1)
	TheLog.ch.Random:printf("SpawnCoordinator Random Seed: %d", seed)
	self.rng = krandom.CreateGenerator(seed)

	if self.data.total_spawn_count > 0
		or worldmap:IsDebugMap()
	then
		return
	end

	local selected_encounter_name = nil
	local forced_encounter = worldmap:GetForcedEncounterForCurrentRoom()
	if forced_encounter then
		-- Forced encounters return an encounter (a function) rather than a
		-- table of possible encounters.
		self.encounter = encounters.bespoke[forced_encounter].exec_fn
		self.encounter_idx = -1
		TheLog.ch.Spawn:printf("Spawning forced encounter bespoke.%s", forced_encounter)
		selected_encounter_name = forced_encounter
	else
		local room_type = self:_GetRoomType()
		if room_type then
			local encounter_name, encounter = worldmap.encounter_deck:Draw(self, room_type, worldmap:GetDifficultyForCurrentRoom())
			if encounter then
				self.encounter = encounter
				self.encounter_idx = encounter_name
				selected_encounter_name = encounter_name
			end
		end
	end

	if not selected_encounter_name then
		if worldmap:HasEnemyForCurrentRoom("boss") then
			-- If boss doesn't use encounters, they're the last wave.
			self.data.is_last_wave = true
			self:_SetRoomComplete(false)
		else
			-- We don't have other enemy rooms so end to ensure
			-- room_complete fires.
			if TheNet:IsHost() then
				self.end_encounter_on_player_spawn = true
			end
			if ALLOW_SIMRESET_BETWEEN_ROOMS then
				assert(#AllPlayers == 0, "Expected players to spawn *after* world.")
			else
				-- TODO: networking2022, nosimreset - allow remote players to linger for now
				for _i,player in ipairs(AllPlayers) do
					if player:IsLocal() then
						assert(false, "Why are there local players still around?")
						break
					end
				end
			end
		end
		return
	end

	-- GetLastPlayerCount is used for tuning, so this can help us track down
	-- what spawn numbers were occurring during failures.
	local last_count = TheDungeon:GetDungeonMap():GetLastPlayerCount() or -1
	TheLog.ch.Spawn:printf("Starting encounter [%s] with last player count %i.", selected_encounter_name, last_count)

	self.data.is_last_wave = false

	-- sort spawners by distance from origin as entity GUIDs are session-based
	-- and at insertion time, the spawner entity isn't in its final world position
	table.sort(self.spawners, EntityScript.OrderByXZDistanceFromOrigin)
	-- sort traps, destructible props?

	if TheNet:IsHost() then
		self.thread = self.inst.components.cororun:StartCoroutine(SpawnCoordinator._Spawn_coro, self)
	end
end

function SpawnCoordinator:_OnPlayerActivated()
	if TheNet:IsHost() then
		-- This code path is used to fire off the room_complete event flow
		-- for non-combat encounters (intro room, shops, wanderer, etc.)
		-- It's possible for this to trigger before all players have spawned
		-- into the world.
		if not self.end_encounter_on_player_spawn then
			return
		end
		self.end_encounter_on_player_spawn = false
		self:_EndEncounter({
				enemy_highwater = 0,
			})
	end
end

function SpawnCoordinator:GetRNG()
	return self.rng
end

function SpawnCoordinator:_StopEncounter()
	if self.thread then
		TheLog.ch.SpawnCoordinator:printf("Encounter thread was still running: Stopping...")
		self.thread:Stop()
	end
	self.thread = nil
end

-- Normally only used for debug/development testing and boss clears
function SpawnCoordinator:SetEncounterCleared(clear_non_enemies, cb)
	-- limbo entities should only be host-controlled because it is only put into limbo by wave spawning
	assert(TheNet:IsHost() or lume.count(self.limbo_entities) == 0)

	for ent,_ in pairs(self.limbo_entities) do
		TheLog.ch.SpawnCoordinator:printf("Removing limbo entity %s GUID %d EntityID %s",
			ent.prefab, ent.GUID,
			ent:IsNetworked() and tostring(ent.Network:GetEntityID()) or "<non-networked>")
		assert(ent:IsLocal())
		ent:Remove()
	end
	lume.clear(self.limbo_entities)

	if clear_non_enemies then
		-- We're clearing everything back to original state.
		self.has_spawned_any_waves = false
	end

	self.inst.components.roomclear:Debug_ForceClear()
	self:_StopEncounter()
	if clear_non_enemies then
		for ent in pairs(self.initial_scenario_entities) do
			if ent:IsValid() then
				ent:Remove()
			end
			self.initial_scenario_entities[ent] = nil
		end
	end
	-- Do on a long delay for enemies that spawn other enemies on defeat (cabbagetowers).
	self.inst:DoTaskInTime(0.5, function(inst_)
		self.inst.components.roomclear:Debug_ForceClear()
		self.data.is_last_wave = true
		self:_OnRoomCleared(TheWorld, self.last_clear_data or {
				enemy_highwater = 0,
			})
		if cb and type(cb) == "function" then
			cb()
		end
	end)
end

function SpawnCoordinator:StartCustomEncounter(encounter)
	self:_StopEncounter()
	self.encounter = encounter
	self.data.is_last_wave = false

	local last_count = TheDungeon:GetDungeonMap():GetLastPlayerCount() or -1
	TheLog.ch.Spawn:printf("Starting custom encounter [%s] with last player count %i.", encounter, last_count)

	if TheNet:IsHost() then
		self.thread = self.inst.components.cororun:StartCoroutine(SpawnCoordinator._Spawn_coro, self)
	end
end

function SpawnCoordinator:_OnRoomCleared(world, data)
	self.last_clear_data = data
	if self.data.is_last_wave then
		self.last_clear_data = nil
		self:_EndEncounter(data)
	end
end

function SpawnCoordinator:_Spawn_coro()
	self:_SetRoomComplete(false)
	coroutine.yield()
	assert(self.encounter)

	self.encounter(self)

	self.data.is_last_wave = true
	if self.inst.components.roomclear:GetEnemyCount() == 0 then
		-- Don't assert since it can occur when using d_clearwave on a single
		-- wave encounter. However, we don't ever want to enter this state.
		TheLog.ch.Spawn:print("WARN: Don't call WaitForEnemyCount at the end of an encounter or we can't properly clean up room state.")
		self:_OnRoomCleared(TheWorld, self.last_clear_data)
	end
end

function SpawnCoordinator:_EndEncounter(data)
	TheLog.ch.Spawn:print("Encounter complete")
	self:_SetRoomComplete(true, data)

	-- Remove lock after firing to ensure spawns from room_complete maintain
	-- lock state.
	self.inst.components.roomlockable:RemoveLock(self.inst)
end

-- Multiple room events for dungeons fire on *TheWorld* in this order:
-- * room_cleared: The enemies in this room are currently gone. May fire
--   multiple times in one room. Never fires in noncombat rooms.
-- * room_complete: The task required for this room is over (usually
--   combat). Fires in all rooms.
-- * room_unlocked: The player is now allowed to advance to the next room.
--   Fires in all rooms.
function SpawnCoordinator:_SetRoomComplete(is_complete, data)
	if TheNet:IsHost() then
		self.data.is_room_complete = is_complete
		-- data contains enemy_highwater (number), last_enemy (entity inst)
		if is_complete then
			self.inst:PushEvent("room_complete", data)
			TheNet:HostSetRoomCompleteState(is_complete, data.enemy_highwater, data.last_enemy and data.last_enemy.GUID or 0)
		else
			TheNet:HostSetRoomCompleteState(is_complete)
		end
	end
end

function SpawnCoordinator:GetIsRoomComplete()
	if TheNet:IsHost() then
		return self.data.is_room_complete
	else
		local _seqNr, isComplete = TheNet:GetRoomCompleteState()
		return isComplete
	end
end

function SpawnCoordinator:OnSave()
	return self.data
end

function SpawnCoordinator:OnLoad(data)
	self.data = data
end

function SpawnCoordinator:DebugDraw_Spawner(spawner_inst)
	local spawner_pos = spawner_inst:GetPosition()
	for portal in pairs(TheWorld.components.playerspawner.portals) do
		local portal_pos = portal:GetPosition()
		local too_close = is_too_close(portal_pos, spawner_inst)
		local c = too_close and WEBCOLORS.RED or WEBCOLORS.SPRINGGREEN
		DebugDraw.GroundLine_Vec(spawner_pos, portal_pos, c)
	end
end

function SpawnCoordinator:DebugDrawEntity(ui, panel, colors)
	ui:Value("GetEnemyCount", self.inst.components.roomclear:GetEnemyCount())
	ui:Value("IsClearOfEnemies", self.inst.components.roomclear:IsClearOfEnemies())
	ui:Value("data", table.inspect(self.data))
end


-- Elite configuration should be set once and not from encounters.

function SpawnCoordinator:SetEliteMiniboss(toggle)
	self.elite_miniboss = toggle
end


--
-- Encounter API
--

function SpawnCoordinator:GetProgressThroughDungeon()
	return TheDungeon:GetDungeonMap().nav:GetProgressThroughDungeon()
end

-- If you want all waves to play their spawn anim.
function SpawnCoordinator:StartSpawningFromHidingPlaces()
	self.has_spawned_any_waves = true
end

local default_spawn_areas =
{
	battlefield = true,
	perimeter = true,
}

function SpawnCoordinator:SetupValidSpawnerList(spawner_list, spawn_area_data)
	local valid_spawners = {}

	-- If data spawn area parameters are not defined, set them to true by default
	if spawn_area_data == nil then
		spawn_area_data = default_spawn_areas
	end

	-- Iterate through all spawn points and check if they meet spawn area requirements
	for _, spawner in ipairs(spawner_list) do
		if next(spawner.spawn_areas) == nil then
			spawner.spawn_areas = default_spawn_areas
		end
		for key, _ in pairs(spawn_area_data) do
			if spawner.spawn_areas[key] then
				table.insert(valid_spawners, spawner)
				break
			end
		end
	end

	valid_spawners = self.rng:ShuffleCopy(valid_spawners)
	return valid_spawners
end

-- We don't spawn more enemies than locations.
function SpawnCoordinator:SpawnStationaryEnemies(wave, data)
	dbassert(not self.has_spawned_any_waves, "Call SpawnStationaryEnemies *before* SpawnWave or SpawnAdaptiveWave so they exist on level reveal instead of popping into existence.")
	wave = waves.EnsureWave(wave)
	local valid_spawners = self:SetupValidSpawnerList(self.stationary_spawners, data)
	local enemies_to_spawn = wave:BuildSpawnList(self.rng, EnemyModifierNames.s.StationarySpawnCountMult)
	enemies_to_spawn = self.rng:Shuffle(enemies_to_spawn)

	assert(#valid_spawners > 0, "Must have spawners or we'll loop forever.")

	local enemy_idx = 1

	for i, enemy in ipairs(enemies_to_spawn) do
		if not enemies_to_spawn[enemy_idx] then
			break
		end

		if #valid_spawners == 0 then
			break
		end

		enemy = self:_MakeEnemyElite(enemy)

		local ent = valid_spawners[1]:SpawnStationaryEnemy(enemy)
		SceneGen.ClaimSoleOccupancy(ent)
		table.remove(valid_spawners, 1) -- this spawner is now used up, so remove it from the list of valid spawners

		enemy_idx = enemy_idx + 1
	end

	-- end
	self.data.total_stationary_enemy_count = enemy_idx - 1
end

-- We don't spawn more traps than locations.
function SpawnCoordinator:SpawnTraps(wave)
	dbassert(not self.has_spawned_any_waves, "Call SpawnTraps *before* SpawnWave or SpawnAdaptiveWave so they exist on level reveal instead of popping into existence.")
	wave = waves.EnsureWave(wave)
	local valid_spawners = self.rng:ShuffleCopy(self.trap_locations)
	local traps_to_spawn = self.rng:Shuffle(wave:BuildSpawnList(self.rng))
	local trap_idx = 1

	for trap_index, trap in ipairs(traps_to_spawn) do
		if not traps_to_spawn[trap_idx] then
			break
		end

		if #valid_spawners == 0 then
			break
		end

		-- iterate through valid spawners, find a spawner that will allow this trap type
		local spawned = false
		local trap_prop = prop_data[trap]
		for spawner_index, spawner in ipairs(valid_spawners) do
			if spawner.trap_types then --JAMBELLTRAP should I assert here? trying to check a spawner which is not configured.
				for key, _ in pairs(spawner.trap_types) do
					-- if the spawner supports this trap, spawn a trap there and remove it from the valid spawners list
					if trap_prop
						and trap_prop.script_args
						and key == trap_prop.script_args.trap_type
					then
						local ent = spawner.spawner_ent:SpawnTrap(traps_to_spawn[trap_idx])
						SceneGen.ClaimSoleOccupancy(ent)
						self.initial_scenario_entities[ent] = trap_index
						table.remove(valid_spawners, spawner_index) -- this spawner is now used up, so remove it from the list of valid spawners
						spawned = true
						break
					end
				end
			end
			if spawned then --if we've already found a valid spawner, stop trying to spawn this trap and move onto the next one
				break
			end
		end

		trap_idx = trap_idx + 1
	end

	-- end
	self.data.total_trap_count = trap_idx - 1
end

function SpawnCoordinator:SpawnPropDestructibles(max_amount, force_max)
	dbassert(not self.has_spawned_any_waves, "Call SpawnPropDestructibles *before* SpawnWave or SpawnAdaptiveWave so they exist on level reveal instead of popping into existence.")
	local valid_spawners = self.rng:ShuffleCopy(self.propdestructible_locations)
	local props_to_spawn = force_max and max_amount or self.rng:Integer(0,max_amount) --JAMBELL maybe do random calculation outside of this function?
	local prop_idx = 1

	TheLog.ch.Spawn:print("SpawnPropDestructibles count", props_to_spawn)


	for i = 1, props_to_spawn do
		if #valid_spawners == 0 then
			break
		end

		-- iterate through valid spawners, find a spawner that will allow this prop type
		local spawned = false
		for count,spawner in ipairs(valid_spawners) do
			if spawned then --if we've already found a valid spawner, stop trying to spawn this trap and move onto the next one
				break
			end

			assert(lume.isarray(spawner.prop_types), "Prop Types container changed-- AddPropDestructibleSpawner parameters need to be reviewed")
			-- Choose a prop from those available via likelihood.
			assert(spawner.likelihood_total ~= 0)
			local choice = self.rng:Float(spawner.likelihood_total)
			local prop
			for _, prop_type in ipairs(spawner.prop_types) do
				if prop_type.likelihood ~= 0 then
					prop = prop_type.prop
				end
				choice = choice - prop_type.likelihood
				if choice <= 0 then
					break
				end
			end

			local ent = spawner.spawner_ent:SpawnPropDestructible(prop)
			SceneGen.ClaimSoleOccupancy(ent)
			self.initial_scenario_entities[ent] = i
			table.remove(valid_spawners,count) -- this spawner is now used up, so remove it from the list of valid spawners
			spawned = true
		end

		prop_idx = prop_idx + 1
	end

	-- end
	self.data.total_propdestructible_count = prop_idx - 1
end

function SpawnCoordinator:_SpawnPrefabNow(enemy)
	if TheNet:IsHost() then
		return SpawnPrefab(enemy, self.inst)
	end
	return nil
end

function SpawnCoordinator:SpawnMiniboss(wave, delay_between_spawns, data)
	dbassert(not self.has_spawned_any_waves, "Call SpawnMiniboss *before* SpawnWave or SpawnAdaptiveWave so they exist on level reveal instead of popping into existence. (They don't have spawn anims and must exist for cine.)")
	wave = waves.EnsureWave(wave)
	delay_between_spawns = delay_between_spawns or 0

	local is_first_wave = not self.has_spawned_any_waves
	self.has_spawned_any_waves = true

	if is_first_wave then
		delay_between_spawns = 0
	end

	--~ TheLog.ch.Spawn:printf("Spawning miniboss: %s", table.inspect(wave, { process = table.inspect.processes.skip_mt, }))

	local valid_spawners = self:SetupValidSpawnerList(self.spawners, data)
	local enemies = wave:BuildSpawnList(self.rng, EnemyModifierNames.s.MinibossSpawnCountMult)
	-- enemies = self.rng:Shuffle(enemies)

	assert(#valid_spawners > 0, "Must have spawners or we'll loop forever.")

	-- Figure out if it should be elite or not
	--~ TheLog.ch.Spawn:print("Wave enemy list:", table.inspect(enemies, { process = table.inspect.processes.skip_mt, }))
	local enemy_entities = {}
	for i, enemy in ipairs(enemies) do
		if self.elite_miniboss and PrefabExists(enemy.."_elite") then
			enemy = enemy.."_elite"
		end
		local ent = self:_SpawnPrefabNow(enemy)
		if ent then
			table.insert(enemy_entities, ent)
			monsterutil.MakeMiniboss(ent)
			self:_RemoveFromScene(ent)
		end
	end

	while #enemy_entities > 0 do
		local spawner_enemy_pairs = {}
		local to_remove = {}

		for i, ent in ipairs(enemy_entities) do
			local miniboss_spawner = nil
			for spawner_idx,s in ipairs(valid_spawners) do
				if not spawner_enemy_pairs[s] and s:CanSpawnCreature(ent) then
					for tag_idx, tag in ipairs(s.required_tags) do
						if tag == "miniboss" then
							miniboss_spawner = s
							break
						end
					end
				end
			end
			assert(miniboss_spawner, "Trying to spawn a miniboss without a spawner_miniboss. Please add one!")
			if miniboss_spawner then
				table.insert(to_remove, i)
				spawner_enemy_pairs[miniboss_spawner] = ent
				miniboss_spawner:ReserveSpawner(ent)
			end
		end

		if not is_first_wave then
			local tell_time = 1
			for spawner, ent in pairs(spawner_enemy_pairs) do
--				spawner:PushEvent("do_tell", tell_time)
				EffectEvents.MakeNetEventPushEventOnMinimalEntity(spawner, "do_tell", tell_time)
			end
			self:WaitForSeconds(tell_time)
		end

		local can_play_intro = is_first_wave
		local spawners = lume.keys(spawner_enemy_pairs)
		table.sort(spawners, EntityScript.OrderByXZDistanceFromOrigin)
		local cine_lead = nil
		local possible_sub_actors = {}
		for _i, spawner in ipairs(spawners) do
			local ent = spawner_enemy_pairs[spawner]
			self:_ReturnToScene(ent)
			spawner:SpawnCreature(ent, is_first_wave)
			self.data.total_spawn_count = self.data.total_spawn_count + 1
			if can_play_intro and ent.components.cineactor then
				can_play_intro = false
				cine_lead = ent
			else
				-- If there's multiple minibosses, and the cinematic has sub actors to be assigned at runtime, handle this.
				table.insert(possible_sub_actors, ent)
			end
			self:WaitForSeconds(delay_between_spawns)
		end

		-- Not every miniboss necessarily has a cine, but we only play
		-- one (don't want to try to start two cines for multi boss).
		-- So we fire and forget. Possibly, we should add the
		-- minibosses as other actors.
		if cine_lead then
			cine_lead:PushEvent("cine_play_miniboss_intro")
			local cine_entity = cine_lead.components.cineactor.cine_entity

			-- Set up sub actors in real-time. Fill up the assigned_at_runtime subactor slots with real entities.
			if cine_entity and cine_entity.cine.subactors and cine_entity.subactor_data then
				local current_cine_subactors = shallowcopy(cine_entity.cine.subactors)
				local current_subactor_idx = 1
				local current_possible_subactor_idx = 1
				cine_entity.cine.subactors = {}
				for i, subactor in ipairs(cine_entity.subactor_data) do
					if subactor.assigned_at_runtime then
						cine_entity.cine.subactors[i] = possible_sub_actors[current_possible_subactor_idx]
						current_possible_subactor_idx = current_possible_subactor_idx + 1
					else
						cine_entity.cine.subactors[i] = current_cine_subactors[current_subactor_idx]
						current_subactor_idx = current_subactor_idx + 1
					end
				end
			end
		end

		for i = #to_remove, 1, -1 do
			table.remove(enemy_entities, to_remove[i])
		end
	end
end

function SpawnCoordinator:SpawnWave(wave, delay_between_spawns, delay_between_reuse, data, refill_wave)

	if not TheNet:IsHost() then
		return	-- only spawn waves on the host.
	end

	wave = waves.EnsureWave(wave)
	local is_first_wave = not self.has_spawned_any_waves
	self.has_spawned_any_waves = true

	delay_between_spawns = delay_between_spawns or 0.1
	delay_between_reuse = delay_between_reuse or 1
	if is_first_wave then
		delay_between_spawns = 0
		delay_between_reuse = 0
	end

	--~ TheLog.ch.Spawn:printf("Spawning wave: %s", table.inspect(wave, { process = table.inspect.processes.skip_mt, }))

	local valid_spawners = self:SetupValidSpawnerList(self.spawners, data)
	local enemies = wave:BuildSpawnList(self.rng, EnemyModifierNames.s.SpawnCountMult)
	-- enemies = self.rng:Shuffle(enemies)

	-- Refill waves will spawn in enemies of the specified wave that arent already on the field
	if (refill_wave) then
		local current_enemies = self.inst.components.roomclear:GetEnemies()
		for enemy in pairs(current_enemies) do
			lume.remove(enemies, enemy.prefab)
		end
	end

	assert(#valid_spawners > 0, "Must have spawners or we'll loop forever.")

	--~ TheLog.ch.Spawn:print("Wave enemy list:", table.inspect(enemies, { process = table.inspect.processes.skip_mt, }))
	local enemy_entities = {}
	for i, enemy in ipairs(enemies) do
		enemy = self:_MakeEnemyElite(enemy)

		local ent = self:_SpawnPrefabNow(enemy)
		if ent then
			table.insert(enemy_entities, ent)
			self:_RemoveFromScene(ent)
		end
	end

	-- Assert that we can spawn our enemies with our selection of spawners.
	for _, enemy in ipairs(enemy_entities) do
		local reasons = {}
		if enemy:HasTag("spawn_walkable") then
			break
		else
			table.insert(reasons, "  Cannot spawn directly on the stage")
		end
		local can_spawn = false
		for _, spawner in ipairs(valid_spawners) do
			local can_spawn_from_spawner, reason = spawner:CanSpawnCreature(enemy)
			if can_spawn_from_spawner then
				can_spawn = true
				break
			else
				table.insert(reasons, "  Cannot spawn because "..reason)
			end
		end
		if not can_spawn then
			local msg = "Error in SpawnCoordinator:SpawnWave\nLast player count: %i.\nFailed to spawn [%s] from any available spawner:\n"
			local last_count = TheDungeon:GetDungeonMap():GetLastPlayerCount() or -1
			-- SetupValidSpawnerList omits some of the spawners and they won't have reasons, so mention them.
			table.insert(reasons, ("  Cannot use %i invalid spawners (%i total)."):format(#self.spawners - #valid_spawners, #self.spawners))
			assert(can_spawn, msg:format(last_count, enemy.prefab)..table.concat(reasons, "\n"))
		end
	end

	while #enemy_entities > 0 do
		local spawner_enemy_pairs = {}
		local spawn_walkable = {}
		local to_remove = {}
		local tell_time = 1

		for i, ent in ipairs(enemy_entities) do
			if ent:HasTag("spawn_walkable") then
				-- this entity doesn't use a spawner
				table.insert(to_remove, i)
				table.insert(spawn_walkable, ent)
			else
				for spawner_idx,s in ipairs(valid_spawners) do
					if not spawner_enemy_pairs[s] and s:CanSpawnCreature(ent) then
						table.insert(to_remove, i)
						spawner_enemy_pairs[s] = ent
						s:ReserveSpawner(ent)
						break
					end
				end
			end
		end

		if not is_first_wave then
			for spawner, ent in pairs(spawner_enemy_pairs) do
				EffectEvents.MakeNetEventPushEventOnMinimalEntity(spawner, "do_tell", tell_time)
			end
			self:WaitForSeconds(tell_time)
		end

		local spawners = lume.keys(spawner_enemy_pairs)
		table.sort(spawners, EntityScript.OrderByXZDistanceFromOrigin)
		for _i, spawner in ipairs(spawners) do
			local ent = spawner_enemy_pairs[spawner]
			self:_ReturnToScene(ent)
			spawner:SpawnCreature(ent, is_first_wave)
			self.data.total_spawn_count = self.data.total_spawn_count + 1
			self:WaitForSeconds(delay_between_spawns)
		end

		for _, ent in ipairs(spawn_walkable) do
			local pos = TheWorld.Map:GetRandomPointInWalkable(ent.Physics:GetSize())
			self:_ReturnToScene(ent)
			ent.Transform:SetRotation(math.random(1, 360))
			ent.Transform:SetPosition(pos.x, 0, pos.z)
			ent:PushEvent("spawn_walkable", { pos = pos })
		end

		for i = #to_remove, 1, -1 do
			table.remove(enemy_entities, to_remove[i])
		end
		-- WARN: This delay means the room could be cleared before the next
		-- part of this wave spawns.
		self:WaitForSeconds(delay_between_reuse)
	end
end

function SpawnCoordinator:GetCountForAdaptiveWave(difficulty, progress)
	local difficulty_name = mapgen.Difficulty:FromId(difficulty)
	local tuning = waves.adaptive_counts[difficulty_name]
	kassert.assert_fmt(tuning, "Unknown difficulty: %s (%s)", difficulty_name, difficulty)
	for _,tier in ipairs(tuning) do
		if tier.progress >= progress then
			return tier.count
		end
	end
	error("adaptive_counts should handle progress values from 0 to 1. Unhandled progress: ".. progress)
end

function SpawnCoordinator:GetCurrentAdaptiveWaveSize(difficulty)
	local progress = self:GetProgressThroughDungeon()
	return self:GetCountForAdaptiveWave(difficulty, progress)
end

function SpawnCoordinator:FilterAdaptiveWaveByProgress(adaptive_wave, progress)
	local distribution = deepcopy(adaptive_wave.distribution)
	for prefab,depth in pairs(adaptive_wave.min_progress) do
		if depth > progress then
			distribution[prefab] = nil
		end
	end

	return distribution
end

function SpawnCoordinator:PopulateAndApplySpawnCountOverrides(distribution, count)
	-- BEWARE: The distribution controls the maximum spawn count.
	-- Distribution is not purely a weighting when filling each slot of the spawn count. Many playtests have been done with this
	-- system as is and it seems to be working, as it does prevent from spawning only one enemy type in a wave. However if
	-- more control is ever needed over the mob counts in a wave we may want to separate the selection-weight and distribution.

	-- Use a bit more than the desired population to allow some deviation from
	-- the distribution.
	local population = self.rng:WeightedFill(distribution, math.floor(count * 1.66))
	population = lume.first(population, count)
	local spawned = 0
	for i,prefab in ipairs(population) do
		if spawned + (waves.adaptive.slot_count_override[prefab] or 1) > count then
			-- Once we've spawned enough enemies, do not add more.
			population[i] = nil
		else
			-- This used to always go at least one enemy over what we asked for, but it did so regardless of enemy weight.
			-- This meant that a room asking for count=6 would pretty frequently give us a spawn=9, which was quite difficult.
			-- TODO: an Ascension that affects spawn counts, and add a bit of randomness to boosting 'count' by a little bit
			spawned = spawned + (waves.adaptive.slot_count_override[prefab] or 1)
		end
	end

	return population
end

function SpawnCoordinator:ApplySpawnMultiplierToListOfMobs(list_to_spawn)
	for mob,amount in pairs(list_to_spawn) do
		local spawn_multiplier = monstertiers.GetSpawnMultiplier(mob) or 1
		amount = math.floor(amount * spawn_multiplier) -- Apply the spawn weight, and floor the value so we don't have fractionals.
		list_to_spawn[mob] = math.max(1, amount) -- Never spawn less than 1 of a thing.
	end
end

function SpawnCoordinator:_AdaptWaveToProgress(difficulty, adaptive_wave, progress)
	local count = self:GetCountForAdaptiveWave(difficulty, progress)
	local distribution = self:FilterAdaptiveWaveByProgress(adaptive_wave, progress)

	local population = self:PopulateAndApplySpawnCountOverrides(distribution, count)

	local list_to_spawn = lume.frequency(population)

	-- TODO: Applying monstertier weights since our Raw wave won't go through
	-- ConvertRoleToMonster. However, that means we have three ways of
	-- manipulating spawn counts:
	-- 1. waves.adaptive.slot_count_override
	-- 2. monstertiers spawn_multiplier
	-- 3. monstertiers additional_spawns_per_tier_delta

	-- Now that we know how many mobs total we should be spawning, adjust for monstertiers spawn_multiplier.
	-- e.g. If adaptive wave calls for '1' mothball, we actually want them to spawn 4 mothballs because they should be more plentiful. Adjust here.
	self:ApplySpawnMultiplierToListOfMobs(list_to_spawn)

	return waves.Raw(list_to_spawn)
end

function SpawnCoordinator:_MakeEnemyElite(enemy)
	local is_first_wave = not self.has_spawned_any_waves
	local progress = self:GetProgressThroughDungeon()
	local elite_max = self:_GetEliteMaxFromProgress(progress)
	local elite_chance = TUNING:GetEnemyModifiers(enemy).EliteChance

	if elite_chance > 0 and self.elite_current < elite_max then
		-- jambell: Possible alternative implementation: every enemy has an "elite value" tuned per creature, and an encounter rolls an "elite budget" which scales up on Dungeon Progress, or gets modified by ascension/powers/etc
		-- 			When we spawn an elite version of a mob, spend some of that elite budget.

		local roll = self.rng:Float(1)
		local to_beat = is_first_wave and elite_chance * .25 or elite_chance -- Less likely to spawn elites in the first wave
		local elite = roll >= 1 - to_beat

		if elite and PrefabExists(enemy.."_elite") then
			enemy = enemy.."_elite"
			self.elite_current = self.elite_current + 1
		end
	end

	return enemy
end

function SpawnCoordinator:_GetEliteMaxFromProgress(progress)
	local difficulty = TheDungeon:GetDungeonMap():GetDifficultyForCurrentRoom()
	local difficulty_name = mapgen.Difficulty:FromId(difficulty)
	local tuning = waves.elite_counts[difficulty_name]
	kassert.assert_fmt(tuning, "Unknown difficulty: %s (%s)", difficulty_name, difficulty)
	local elite_count_mod = TUNING:GetEnemyModifiers().EliteSpawnCount

	for _,tier in ipairs(tuning) do
		if tier.progress >= progress then
			return tier.count + elite_count_mod
		end
	end
	error("elite_counts should handle progress values from 0 to 1. Unhandled progress: ".. progress)
end

function SpawnCoordinator:_GetAdaptiveWaveForBiome(biome_location)
	return waves.adaptive.biome[biome_location.id]
end

-- Spawn a wave that scales to the depth into the dungeon.
function SpawnCoordinator:SpawnAdaptiveWave(difficulty, delay_between_spawns, delay_between_reuse, refill_wave)
	local worldmap = TheDungeon:GetDungeonMap()
	local biome_location = worldmap.nav:GetBiomeLocation()
	local adaptive_wave = self:_GetAdaptiveWaveForBiome(biome_location)
	if not adaptive_wave then
		return
	end
	local progress = self:GetProgressThroughDungeon()
	local wave = self:_AdaptWaveToProgress(difficulty, adaptive_wave, progress)
	return self:SpawnWave(wave, delay_between_spawns, delay_between_reuse, nil, refill_wave)
end

function SpawnCoordinator:WaitForSeconds(duration)
	self.inst.components.cororun:WaitForSeconds(self.thread, duration)
end

function SpawnCoordinator:WaitForEnemyCount(count)
	assert(self.thread:IsRunning())
	while self.inst.components.roomclear:GetEnemyCount() > count do
		coroutine.yield()
	end
end

-- Wait for this many to be defeated (not total enemies defeated).
function SpawnCoordinator:WaitForDefeatedCount(count)
	assert(self.thread:IsRunning())
	local current = self.inst.components.roomclear:GetEnemyCount()
	local desired = current - count
	while self.inst.components.roomclear:GetEnemyCount() > desired do
		coroutine.yield()
	end
end

function SpawnCoordinator:WaitForDefeatedPercentage(percentage)
	local current = TheWorld.components.roomclear:GetEnemyCount()
	local desired = math.floor(current * (1 - percentage))
	while TheWorld.components.roomclear:GetEnemyCount() > desired do
		coroutine.yield()
	end
end

function SpawnCoordinator:WaitForMinibossHealthPercent(percentage)
	local above_threshold = true
	while (above_threshold) do
		local total_health = 0
		local current_health = 0
		local enemies = TheWorld.components.roomclear:GetEnemies()
		for enemy in pairs(enemies) do
			if (enemy:HasTag("miniboss")) then
				total_health = total_health + enemy.components.health:GetMax()
				current_health = current_health + enemy.components.health:GetCurrent()
			end
		end

		if (total_health <= 0) then
			total_health = 1 -- Dont divide by 0, no minibosses were found so exit so exit loop
		end

		above_threshold = (current_health / total_health) > percentage

		coroutine.yield()
	end
end

function SpawnCoordinator:WaitForMinibossHealthPercentWithReinforcement(percentage, wave, delay)
	local above_threshold = true
	local spawn_delay = delay or 2.5
	local spawn_timer = spawn_delay
	while (above_threshold) do
		local total_health = 0
		local current_health = 0
		local enemies = TheWorld.components.roomclear:GetEnemies()
		for enemy in pairs(enemies) do
			if (enemy:HasTag("miniboss")) then
				total_health = total_health + enemy.components.health:GetMax()
				current_health = current_health + enemy.components.health:GetCurrent()
			end
		end

		if (total_health <= 0) then
			total_health = 1 -- Dont divide by 0, no minibosses were found so exit so exit loop
		end

		above_threshold = (current_health / total_health) > percentage

		if (above_threshold and wave) then
			if (spawn_timer <= 0) then
				self:SpawnWave(wave, 0, 0, nil, true)
				spawn_timer = spawn_delay
			else
				spawn_timer = spawn_timer - TICKS
			end
		end

		coroutine.yield()
	end
end

function SpawnCoordinator:WaitForRoomClear()
	assert(self.thread:IsRunning())
	while not self.inst.components.roomclear:IsClearOfEnemies() do
		coroutine.yield()
	end
end

-- /end Encounter API

return SpawnCoordinator
