local spawnutil = require "util.spawnutil"
local assets = spawnutil.GetEditableAssets()
local combatutil = require"util.combatutil"


-- This is an old spawner from when npcs spawned in town away from their homes.
-- It's not used for dungeons (see spawner_npc_dungeon.lua). It might become
-- spawner_npc_town with tagging for different town locations.


local npc_data = require("prefabs/npc_autogen_data")
local spawn_prefabs = {}

for id, _ in pairs(npc_data) do
	table.insert(spawn_prefabs, id)
end

local function TrySpawnNPCs(inst)
	inst.npc_requests = {}
	TheWorld.npcspawner = inst
	TheWorld:PushEvent("quest_start_town")

	-- local sorted_quests = lume.keys(inst.npc_requests)
	-- if #sorted_quests > 0 then

	-- sorted_quests = lume.sort(sorted_quests, function(a, b) return a:GetPriority() > b:GetPriority() end)
	-- local filtered_quests = lume.filter(sorted_quests, function(a) return a:GetPriority() == sorted_quests[1]:GetPriority() end)
	-- local best_quest = filtered_quests[math.random(#filtered_quests)]
	-- local npc_actor = inst.npc_requests[best_quest]

	for quest, npc_actor in pairs(inst.npc_requests) do
		if not npc_actor then
			TheLog.ch.Quest:print("Failed to find npc to spawn.")
			return
		end

		-- printf("SpawnNpcFromQuests: %s/ %s", best_quest, npc_actor)
		if npc_actor.is_reservation and not inst.components.npchome:HasAnyNpcs() then
			local ent = npc_actor:SpawnReservation()
			inst.components.npchome:AddNpc(ent)
		end
	end
	-- end
end

local function SpawnNpcFromQuests(inst)
	if not TheNet:IsHost() then
		return
	end
	-- HACK(dbriscoe): Delay to ensure quest system has loaded. Do this from
	-- with a master quest? On QuestCentral?
	inst:DoTaskInTime(0.1, TrySpawnNPCs)
end

local function RequestNpc(inst, npc_actor, quest)
	inst.npc_requests[quest] = npc_actor
end

local function GetSpawnPos(spawner, npc)
	local pos = combatutil.GetWalkableOffsetPositionFromEnt(spawner, 3, 8, 190, 210)
	return pos.x, pos.z
end

local function fn()
	local inst = spawnutil.CreateBasicSpawner()

	inst:AddTag("spawner_npc")

	inst.components.snaptogrid:SetDimensions(2, 2, -1)
	inst:AddComponent("npchome")
	inst.components.npchome:SetSpawnPosFn(GetSpawnPos)

	inst.RequestNpc = RequestNpc

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		spawnutil.MakeEditable(inst, "circle")
		spawnutil.SetupPreviewPhantom(inst, spawn_prefabs[1])
	else
		inst.OnPostLoadWorld = SpawnNpcFromQuests
	end

	return inst
end

return Prefab("spawner_npc", fn, assets, spawn_prefabs)
