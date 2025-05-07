local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local fmodtable = require "defs.sound.fmodtable"
local lume = require "util.lume"

local assets =
{
	Asset("ANIM", "anim/crystroll_bank.zip"),
	Asset("ANIM", "anim/crystroll_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/crystroll_bank.zip"),
	Asset("ANIM", "anim/crystroll_elite_build.zip"),
}

local prefabs =
{
	--"cine_crystroll_intro",
	"fx_hurt_sweat",
	"fx_low_health_ring",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_crystroll"),
}
local elite_prefabs = lume.merge(prefabs,
{
})

prefabutil.SetupDeathFxPrefabs(prefabs, "crystroll")
prefabutil.SetupDeathFxPrefabs(elite_prefabs, "crystroll_elite")

local attacks =
{
	bite =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 30,
		cooldown = 4,
		pre_anim = "bite_pre",
		hold_anim = "bite_hold",
		loop_hold_anim = true,
		--max_interrupts = 1,
		start_conditions_fn = function(inst, data, trange)
			if trange:TestBeam(0, 7, 4.5) then
				return true
			end
		end
	},

	groundpound =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 30,
		cooldown = 4,
		pre_anim = "ground_pound_pre",
		hold_anim = "ground_pound_hold",
		loop_hold_anim = true,
		--max_interrupts = 1,
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			if trange:TestBeam(0, 7, 4.5) then
				return true
			end
		end
	},

	bodyslam =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 30,
		cooldown = 4,
		pre_anim = "body_slam_pre",
		hold_anim = "body_slam_hold",
		loop_hold_anim = true,
		--max_interrupts = 1,
		start_conditions_fn = function(inst, data, trange)
			if trange:TestBeam(0, 7, 4.5) then
				return true
			end
		end
	},

	blizzardbreath =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 30,
		cooldown = 4,
		pre_anim = "blizzard_breath_pre",
		hold_anim = "blizzard_breath_loop",
		loop_hold_anim = true,
		--max_interrupts = 1,
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

local MONSTER_SIZE = 2.0

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.LARGE)

	inst.AnimState:SetBank("crystroll_bank")
	inst.AnimState:SetBuild("crystroll_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst.components.hitbox:SetHitFlags(HitGroup.ALL)

	inst.components.combat:SetFrontKnockbackOnly(true)
	inst.components.combat:SetVulnerableKnockdownOnly(true)
	inst.components.combat:SetBlockKnockback(true)

	--[[inst.components.foleysounder:SetFootstepSound(fmodtable.Event.crystroll_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.crystroll_pre_knockdown)

    -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.crystroll_hit_vo)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.crystroll_knockdown)]]

	inst:SetStateGraph("sg_crystroll")
	inst:SetBrain("brain_basic_melee")

	--inst:AddComponent("cineactor")
	--inst.components.cineactor:AfterEvent_PlayAsLeadActor("cine_play_miniboss_intro", "cine_crystroll_intro")

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

	--inst.AnimState:SetBuild("crystroll_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	monsterutil.AddOffsetHitbox(inst)

	return inst
end

---------------------------------------------------------------------------------------

return Prefab("crystroll", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	--, Prefab("crystroll_elite", elite_fn, elite_assets, elite_prefabs, nil, NetworkType_SharedHostSpawn)
