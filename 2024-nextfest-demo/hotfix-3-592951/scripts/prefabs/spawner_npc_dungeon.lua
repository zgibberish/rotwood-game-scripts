local spawnutil = require "util.spawnutil"
local assets = spawnutil.GetEditableAssets()

local npc_data = require("prefabs/npc_autogen_data")
local spawn_prefabs = {}

for id, _ in pairs(npc_data) do
	table.insert(spawn_prefabs, id)
end

local function OnPostSpawn(inst)
	if not TheNet:IsHost() then
		return
	end
	TheDungeon.progression.components.meetingmanager:RegisterSpawner(inst)
end

local function fn()
	local inst = spawnutil.CreateBasicSpawner()
	inst:AddTag("spawner_npc")
	inst:AddTag("spawner_npc_dungeon")

	inst.components.snaptogrid:SetDimensions(2, 2, -1)
	inst:AddComponent("npchome")

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		spawnutil.MakeEditable(inst, "circle")
		spawnutil.SetupPreviewPhantom(inst, spawn_prefabs[1])
	else
		inst.OnPostSpawn = OnPostSpawn
	end

	return inst
end

return Prefab("spawner_npc_dungeon", fn, assets, spawn_prefabs)
