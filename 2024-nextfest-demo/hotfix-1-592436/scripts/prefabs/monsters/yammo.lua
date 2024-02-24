local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local fmodtable = require "defs.sound.fmodtable"
local lume = require "util.lume"

local assets =
{
	Asset("ANIM", "anim/yammo_bank.zip"),
	Asset("ANIM", "anim/yammo_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/yammo_bank.zip"),
	Asset("ANIM", "anim/yammo_elite_build.zip"),
}

local prefabs =
{
	"cine_yammo_intro",
	"fx_hurt_sweat",
	"fx_low_health_ring",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_yammo"),
}
local elite_prefabs = lume.merge(prefabs,
{
})

prefabutil.SetupDeathFxPrefabs(prefabs, "yammo")
prefabutil.SetupDeathFxPrefabs(elite_prefabs, "yammo_elite")

local attacks =
{
	swing =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 30,
		cooldown = 4,
		pre_anim = "swing_pre",
		hold_anim = "swing_loop",
		loop_hold_anim = true,
		--max_interrupts = 1,
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			if trange:TestBeam(0, 7, 4.5) then
				return true
			end
		end
	},
	slam =
	{
		priority = 1,
		damage_mod = 0.9,
		startup_frames = 20,
		cooldown = 2.67,
		initialCooldown = 4,
		pre_anim = "heavy_slam_pre",
		hold_anim = "heavy_slam_hold",
		--max_interrupts = 1,
		start_conditions_fn = function(inst, data, trange)
			if trange:TestBeam(0, 6.5, 1.5) then
				return true
			end
		end
	}
}

local elite_attacks =
{
	charge_swing =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 30,
		cooldown = 4,
		initialCooldown = 0,
		pre_anim = "elite_swing_pre",
		hold_anim = "elite_swing_loop",
		loop_hold_anim = true,
		--max_interrupts = 1,
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			if trange:IsInRange(25) and trange:IsInZRange(7) then
				return true
			end
		end
	},
	charge_slam =
	{
		priority = 1,
		damage_mod = 0.9,
		startup_frames = 25,
		cooldown = 2.67,
		initialCooldown = 4,
		pre_anim = "elite_heavy_slam_pre",
		hold_anim = "elite_heavy_slam_hold",
		--max_interrupts = 1,
		start_conditions_fn = function(inst, data, trange)
			if trange:IsInRange(25) then
				return true
			end
		end
	},

	charge =
	{
		priority = -1,
		damage_mod = 0.5,
		startup_frames = 0,
		cooldown = 0,
		start_conditions_fn = function(inst, data, trange) return false end
	},
}

local MONSTER_SIZE = 1.8

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.LARGE)

	inst.AnimState:SetBank("yammo_bank")
	inst.AnimState:SetBuild("yammo_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst.components.hitbox:SetHitFlags(HitGroup.ALL)

	inst.components.combat:SetFrontKnockbackOnly(true)
	inst.components.combat:SetVulnerableKnockdownOnly(true)
	inst.components.combat:SetBlockKnockback(true)

	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.yammo_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.yammo_pre_knockdown)
	
    -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.yammo_hit_vo)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.yammo_knockdown)

	inst:SetStateGraph("sg_yammo")
	inst:SetBrain("brain_yammo")

	inst:AddComponent("cineactor")
	inst.components.cineactor:AfterEvent_PlayAsLeadActor("cine_play_miniboss_intro", "cine_yammo_intro")

	inst:AddTag("nointerrupt")

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	monsterutil.AddOffsetHitbox(inst)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("yammo_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	monsterutil.AddOffsetHitbox(inst)

	return inst
end

---------------------------------------------------------------------------------------

return Prefab("yammo", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("yammo_elite", elite_fn, elite_assets, elite_prefabs, nil, NetworkType_SharedHostSpawn)
