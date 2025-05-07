local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local lume = require "util.lume"
local fmodtable = require "defs.sound.fmodtable"

local assets =
{
	Asset("ANIM", "anim/gnarlic_bank.zip"),
	Asset("ANIM", "anim/gnarlic_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/gnarlic_bank.zip"),
	Asset("ANIM", "anim/gnarlic_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_gnarlic"),
}

local elite_prefabs = lume.merge(prefabs,
{
})

prefabutil.SetupDeathFxPrefabs(prefabs, "gnarlic")
prefabutil.SetupDeathFxPrefabs(elite_prefabs, "gnarlic_elite")

local attacks =
{
	poke =
	{
		priority = 1,
		damage_mod = 0.8,
		startup_frames = 25,
		cooldown = 0.67, -- Always Be Attacking
		initialCooldown = 1,
		pre_anim = "poke_pre",
		hold_anim = "poke_loop",
		start_conditions_fn = function(inst, data, trange)
			return true -- Always Be Attacking
		end
	},
	elite_slam =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 10,
		cooldown = 0.5,
		initialCooldown = 0,
		pre_anim = "elite_slam_pre",
		hold_anim = "elite_slam_hold",
		start_conditions_fn = function(inst, data, trange)
			return false -- put into this manually
		end
	}
}

local elite_attacks = lume.merge(attacks,
{
})

local MONSTER_SIZE = 1

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.MEDIUM)

	inst.HitBox:SetNonPhysicsRect(1)
	inst.components.scalable:SnapshotBaseSize()

	inst.AnimState:SetBank("gnarlic_bank")
	inst.AnimState:SetBuild("gnarlic_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:SetStateGraph("sg_gnarlic")
	inst:SetBrain("brain_basic_melee")

	inst.components.attacktracker:SetMinimumCooldown(0)

	---foleysounder
	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.gnarlic_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.gnarlic_bodyfall)

    -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    -- inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.AAAA_default_event)
    -- inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.AAAA_default_event)


	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("gnarlic_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)
	inst.components.scalable:AddScaleModifier("elite", 1.5)

	return inst
end

return Prefab("gnarlic", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("gnarlic_elite", elite_fn, elite_assets, elite_prefabs, nil, NetworkType_SharedHostSpawn)