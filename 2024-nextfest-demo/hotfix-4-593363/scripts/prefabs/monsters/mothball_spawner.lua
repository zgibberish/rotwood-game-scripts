local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"

local assets =
{
	Asset("ANIM", "anim/mothball_nest_spawner_bank.zip"),
	-- Asset("ANIM", "anim/mothball_nest_spawner_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_mothball"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "mothball_spawner")

local attacks =
{
	spawn =
	{
		priority = 1,
		damage_mod = 0,
		startup_frames = 30,
		cooldown = 0.67,
		initialCooldown = 0,
		loop_hold_anim = true,
		pre_anim = "spawn_pre",
		hold_anim = "spawn_loop",
		start_conditions_fn = function(inst, data, trange)
			-- keep track of mothballs you've spawned & determine eligibility to spawn
			return inst.components.periodicspawner:CanSpawn()
		end
	}
}

local MONSTER_SIZE = 1.33

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeStationaryMonster(inst, MONSTER_SIZE)
	inst.Transform:SetScale(1.2, 1.2, 1.2)
	inst.components.scalable:SnapshotBaseSize()

	inst.AnimState:SetBank("mothball_nest_spawner_bank")
	inst.AnimState:SetBuild("mothball_nest_spawner_bank")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:AddComponent("periodicspawner")
	inst.components.periodicspawner:SetMaxBankedSpawns(6)
	inst.components.periodicspawner:SetSpawnsAvailable(6)
	inst.components.periodicspawner:SetCooldown(6)

	inst:SetStateGraph("sg_mothball_spawner")
	inst:SetBrain("brain_basic_stationary")

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)
	inst.components.attacktracker:AddAttacks(attacks)
	return inst
end

return Prefab("mothball_spawner", normal_fn, assets, prefabs, nil, NetworkType_HostAuth)
