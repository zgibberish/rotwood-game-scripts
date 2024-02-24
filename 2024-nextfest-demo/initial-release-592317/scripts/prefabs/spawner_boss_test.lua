local spawnutil = require "util.spawnutil"


local assets = spawnutil.GetEditableAssets()

-- Must also add to biome where boss spawns.
local spawn_prefabs =
{
	"thatcher",
	"megatreemon",
	-- "bandicoot",
}

local function DoSpawn(inst, boss)
	assert(boss)
	local worldmap = TheDungeon:GetDungeonMap()
	local ent = spawnutil.Spawn(inst, boss)
	local cardinal = worldmap:GetCardinalDirectionForEntrance()
	if cardinal == "east" then
		--face right, don't need to rotate
	elseif cardinal == "west" then
		--face left
		ent.Transform:SetRotation(180)
	else
		local x, z = inst.Transform:GetWorldXZ()
		local haseastexit = worldmap:GetDestinationForCardinalDirection("east") ~= nil
		local haswestexit = worldmap:GetDestinationForCardinalDirection("west") ~= nil
		if haseastexit and not haswestexit then
			--face right, don't need to rotate
		elseif haswestexit and not haseastexit then
			--face left
			ent.Transform:SetRotation(180)
		elseif x < 0 then
			--face right, don't need to rotate
		elseif x > 0 then
			--face left
			ent.Transform:SetRotation(180)
		elseif math.random() < .5 then
			--randomize facing
			ent.Transform:SetRotation(180)
		end
	end

	-- All bosses must have dormant_idle: it's their initial state before the
	-- intro cinematic triggers. It doesn't need animation if there's no anim
	-- before the cinematic.
	ent.sg:GoToState("dormant_idle")


	spawnutil.FlagForRemoval(inst)
end

local function OnPostLoadWorld(inst)
	local worldmap = TheDungeon:GetDungeonMap()
	if worldmap:HasEnemyForCurrentRoom("boss") then
		DoSpawn(inst, worldmap.nav:GetDungeonBoss())
	end
end

local function fn()
	local inst = spawnutil.CreateBasicSpawner()

	inst.components.snaptogrid:SetDimensions(4, 4, -2)

	if TheDungeon:GetDungeonMap():IsDebugMap() then
		spawnutil.MakeEditable(inst, "square")
		inst.AnimState:SetScale(2, 2)
		spawnutil.SetupPreviewPhantom(inst, spawn_prefabs[1])
	else
		inst.OnPostLoadWorld = OnPostLoadWorld
	end

	return inst
end

return Prefab("spawner_boss_test", fn, assets, spawn_prefabs, nil, NetworkType_HostAuth)
