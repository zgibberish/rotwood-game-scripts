local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local fmodtable = require "defs.sound.fmodtable"
local lume = require "util.lume"

local assets =
{
	Asset("ANIM", "anim/antleer_bank.zip"),
	Asset("ANIM", "anim/antleer_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/antleer_bank.zip"),
	Asset("ANIM", "anim/antleer_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_antleer"),
}
local elite_prefabs = lume.merge(prefabs,
{
})

prefabutil.SetupDeathFxPrefabs(prefabs, "antleer")
prefabutil.SetupDeathFxPrefabs(elite_prefabs, "antleer_elite")

local attacks =
{
	charge =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 30,
		cooldown = 4,
		pre_anim = "charge_pre",
		hold_anim = "charge_loop",
		loop_hold_anim = true,
		--max_interrupts = 1,
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			if trange:TestBeam(0, 7, 4.5) then
				return true
			end
		end
	},
}

local elite_attacks = lume.merge(attacks,
{
})

local MONSTER_SIZE = 1.5

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.LARGE)

	inst.AnimState:SetBank("antleer_bank")
	inst.AnimState:SetBuild("antleer_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst.components.hitbox:SetHitFlags(HitGroup.ALL)

	inst.components.combat:SetFrontKnockbackOnly(true)
	inst.components.combat:SetVulnerableKnockdownOnly(true)
	inst.components.combat:SetBlockKnockback(true)

	--[[inst.components.foleysounder:SetFootstepSound(fmodtable.Event.antleer_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.antleer_pre_knockdown)

    -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.antleer_hit_vo)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.antleer_knockdown)]]

	inst:SetStateGraph("sg_antleer")
	inst:SetBrain("brain_basic_melee")

	inst:AddTag("nointerrupt")

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	--inst.AnimState:SetBuild("antleer_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	monsterutil.AddOffsetHitbox(inst)

	return inst
end

---------------------------------------------------------------------------------------

return Prefab("antleer", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	--, Prefab("antleer_elite", elite_fn, elite_assets, elite_prefabs, nil, NetworkType_SharedHostSpawn)
