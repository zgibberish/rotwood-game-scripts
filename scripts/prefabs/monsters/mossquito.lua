local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local spawnutil = require "util.spawnutil"
local fmodtable = require "defs.sound.fmodtable"

local assets =
{
	Asset("ANIM", "anim/mossquito_bank.zip"),
	Asset("ANIM", "anim/mossquito_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/mossquito_bank.zip"),
	Asset("ANIM", "anim/mossquito_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",
	"trap_acid",

	"mosquito_trail",
	"mosquito_trail_burst",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_mossquito"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "mossquito")

local attacks =
{
	pierce =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 30,
		cooldown = 3.33,
		initialCooldown = 0,
		max_attacks_per_target = 2,
		pre_anim = "pierce_pre",
		hold_anim = "pierce_hold",
		start_conditions_fn = function(inst, data, trange)
			local result = false
			if trange:IsInRange(8) then
				result = monsterutil.MaxAttacksPerTarget(inst, data)
			end
			return result
		end
	},

	--[[spray =
	{
		priority = 1,
		startup_frames = 30,
		cooldown = 13.33,
		initialCooldown = 0,
		max_attacks_per_target = 1,
		pre_anim = "spray_pre",
		hold_anim = "spray_hold",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			local result = false
			if trange:IsBetweenRange(5, 10) then
				result = monsterutil.MaxAttacksPerTarget(inst, data)
			end
			return result
		end
	},]]
}

local elite_attacks =
{
	pierce_elite =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 36,
		cooldown = 2.67,
		initialCooldown = 0,
		pre_anim = "pierce_pre",
		hold_anim = "pierce_hold",
		start_conditions_fn = function(inst, data, trange)
			if trange:IsInRange(8) then
				return true
			end
		end
	},

	--[[spray =
	{
		priority = 1,
		startup_frames = 30,
		cooldown = 13.33,
		initialCooldown = 0,
		pre_anim = "spray_pre",
		hold_anim = "spray_hold",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			if trange:IsBetweenRange(5, 10) then
				return true
			end
		end
	},]]
}

local MONSTER_SIZE = 0.50

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.SMALL)
	inst.HitBox:SetNonPhysicsRect(1)
	monsterutil.ExtendToFlyingMonster(inst)

	inst.components.scalable:SnapshotBaseSize()

	inst.AnimState:SetBank("mossquito_bank")
	inst.AnimState:SetBuild("mossquito_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:SetStateGraph("sg_mossquito")
	inst:SetBrain("brain_basic_melee")

	---foleysounder
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.mossquito_bodyfall)
	-- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.mossquito_hit)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.mossquito_knockdown)

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("mossquito_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	return inst
end

---------------------------------------------------------------------------------------
-- Elite heal drop
local heal_drop_prefabs =
{
	GroupPrefab("fx_mossquito"),
}

local function heal_drop_fn(prefabname)
	local inst = spawnutil.CreateComplexProjectile(
	{
		name = prefabname,
		hits_targets = true,
		stategraph = "sg_mossquito_heal",
		fx_prefab = "fx_battoad_projectile"
	})

	inst.components.complexprojectile:SetHorizontalSpeed(30)
	inst.components.complexprojectile:SetGravity(-1)

	inst.Setup = monsterutil.BasicProjectileSetup

	return inst
end

---------------------------------------------------------------------------------------

return Prefab("mossquito", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("mossquito_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("mossquito_heal_drop", heal_drop_fn, nil, heal_drop_prefabs, nil, NetworkType_ClientAuth)