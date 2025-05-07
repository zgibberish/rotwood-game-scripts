local spawnutil = require "util.spawnutil"


local assets = spawnutil.GetEditableAssets()

-- Eventually, we'd pick the right prefab for this biome?
local spawn_prefabs = {
	"treemon",
}

local function DoSpawn(inst, prefab)
	spawnutil.Spawn(inst, prefab)
	spawnutil.FlagForRemoval(inst)
end

local function OnPostLoadWorld(inst)
	local can_spawn_resources = TheDungeon:GetDungeonMap():DoesCurrentRoomHaveResources()
	if can_spawn_resources then
		DoSpawn(inst, spawn_prefabs[1])
	end
end

local function fn()
	local inst = spawnutil.CreateBasicSpawner()
	inst.components.snaptogrid:SetDimensions(4, 4, 1)

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		spawnutil.MakeEditable(inst, "square")
		inst.AnimState:SetScale(2, 2)
		inst.AnimState:SetMultColor(table.unpack(WEBCOLORS.GREEN))
		spawnutil.SetupPreviewPhantom(inst, spawn_prefabs[1])
	else
		inst.OnPostLoadWorld = OnPostLoadWorld
	end

	return inst
end

return Prefab("spawner_resourcecreature", fn, assets, spawn_prefabs)
