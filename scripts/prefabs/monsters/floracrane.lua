local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local fmodtable = require "defs.sound.fmodtable"
local lume = require "util.lume"

local assets =
{
	Asset("ANIM", "anim/floracrane_bank.zip"),
	Asset("ANIM", "anim/floracrane_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/floracrane_bank.zip"),
	Asset("ANIM", "anim/floracrane_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_floracrane"),
}

local elite_prefabs = lume.merge(prefabs,
{
})

prefabutil.SetupDeathFxPrefabs(prefabs, "floracrane")
prefabutil.SetupDeathFxPrefabs(elite_prefabs, "floracrane_elite")

local attacks =
{
	flurry =
	{
		damage_mod = 0.25,
		startup_frames = 20,
		cooldown = 4,
		initialCooldown = 0,
		pre_anim = "flurry_pre",
		hold_anim = "flurry_loop",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			return trange:TestBeam(0, 3, 1.25)
		end
	},

	kick =
	{
		-- priority = 10,
		damage_mod = 0.5,
		startup_frames = 45,
		cooldown = 20, -- The entire kick sequence is about 7 seconds. Do it infrequently.
		initialCooldown = 0,
		pre_anim = "kick_pre",
		hold_anim = "kick_loop",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			return trange:TestBeam(3, 5, 0.75)
		end
	},

	dive_fast =
	{
		cooldown = 0.67,
		damage_mod = 0.75,
		startup_frames = 5,
		initialCooldown = 0,
		pre_anim = "dive_pre",
		hold_anim = "dive_hold",
		attack_state_override = "dive",
		start_conditions_fn = function(inst, data, trange)
			if inst.sg.statemem.do_dive then
				return true
			end
		end
	},

	dive =
	{
		cooldown = 13.33,
		damage_mod = 0.75,
		startup_frames = 15,
		initialCooldown = 15,
		pre_anim = "dive2_pre",
		hold_anim = "dive2_hold",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsBetweenRange(7, 13)
		end
	},

	spear =
	{
		priority = 5,
		damage_mod = 1,
		startup_frames = 15,
		cooldown = 13.33,
		initialCooldown = 0,
		pre_anim = "spear_pre",
		hold_anim = "spear_hold",
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			return trange:TestBeam(-5, 5, 0.75)
		end
	}
}

local elite_attacks = lume.merge(attacks,
{
	spinning_bird_kick =
	{
		damage_mod = 0.5,
		startup_frames = 21,
		cooldown = 5.33,
		initialCooldown = 0,
		pre_anim = "spinning_bird_kick_pre",
		hold_anim = "spinning_bird_kick_hold",
		loop_hold_anim = true,
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(4)
		end
	},
})

local MONSTER_SIZE = 0.75

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.SMALL)

	inst:AddTag("spawn_walkable")

	inst.AnimState:SetBank("floracrane_bank")
	inst.AnimState:SetBuild("floracrane_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst.components.hitbox:SetHitFlags(HitGroup.ALL)

	inst.components.combat:SetFrontKnockbackOnly(true)
	inst.components.combat:SetVulnerableKnockdownOnly(true)
	inst.components.combat:SetBlockKnockback(true)

	inst.HitBox:SetNonPhysicsRect(MONSTER_SIZE * 0.75)

	inst:SetStateGraph("sg_floracrane")
	inst:SetBrain("brain_basic_melee")

	inst:AddComponent("cineactor")
	inst.components.cineactor:AfterEvent_PlayAsLeadActor("cine_play_miniboss_intro", "cine_floracrane_intro")

---- foley sounder
	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.floracrane_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.floracrane_bodyfall)
	inst.components.foleysounder:SetFootstepStopSound(fmodtable.Event.floracrane_scrape)
    -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.floracrane_hit)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.floracrane_knockdown)



	monsterutil.AddOffsetHitbox(inst, nil, "head_hitbox")
	monsterutil.AddOffsetHitbox(inst, nil, "leg_hitbox")

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

	inst.AnimState:SetBuild("floracrane_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	return inst
end

return Prefab("floracrane", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("floracrane_elite", elite_fn, elite_assets, elite_prefabs, nil, NetworkType_SharedHostSpawn)
