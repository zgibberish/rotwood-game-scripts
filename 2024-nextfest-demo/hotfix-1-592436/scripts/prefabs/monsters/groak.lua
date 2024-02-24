local monsterutil = require "util.monsterutil"
local spawnutil = require "util.spawnutil"
local prefabutil = require "prefabs.prefabutil"
local fmodtable = require "defs.sound.fmodtable"
local lume = require "util.lume"

local assets =
{
	Asset("ANIM", "anim/groak_bank.zip"),
	Asset("ANIM", "anim/groak_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/groak_bank.zip"),
	Asset("ANIM", "anim/groak_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",
	"groak_spawn_swallow",
	"fx_bandicoot_groundring_solid",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_groak"), -- Not created yet; uncomment once it's created!
}

local elite_prefabs = lume.merge(prefabs,
{
})

prefabutil.SetupDeathFxPrefabs(prefabs, "groak")
prefabutil.SetupDeathFxPrefabs(elite_prefabs, "groak_elite")

local attacks =
{
	groundpound =
	{
		priority = 2,
		damage_mod = 0.25,
		startup_frames = 30,
		cooldown = 6.67,
		initialCooldown = 0,
		pre_anim = "groundpound_pre",
		hold_anim = "groundpound_pre_hold",
		loop_hold_anim = true,
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(6)
		end
	},

	swallow =
	{
		priority = 1,
		damage_mod = 0.5,
		startup_frames = 30,
		cooldown = 10,
		initialCooldown = 0,
		pre_anim = "swallow_pre",
		hold_anim = "swallow_pre_hold",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			return trange:TestCone(0, 0, 16, 4)
		end
	},
}

local elite_attacks = lume.merge(attacks,
{
	swallow =
	{
		priority = 1,
		damage_mod = 0.5,
		startup_frames = 30,
		cooldown = 3,
		initialCooldown = 0,
		pre_anim = "swallow_pre",
		hold_anim = "swallow_pre_hold",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			return trange:TestCone(0, 0, 16, 4)
		end
	},

	burrow =
	{
		priority = 3,
		damage_mod = 0.1,
		startup_frames = 64,
		cooldown = 10,
		initialCooldown = 0,
		pre_anim = "burrow_pre",
		hold_anim = "burrow_loop",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			return inst.components.health:GetPercent() < 0.5
		end
	},
})

local MONSTER_SIZE = 1.5

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.LARGE)
	inst.Transform:SetScale(1.2, 1.2, 1.2)
	inst.components.scalable:SnapshotBaseSize()

	inst.AnimState:SetBank("groak_bank")
	inst.AnimState:SetBuild("groak_build")
	inst.AnimState:PlayAnimation("idle", true)
	--inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst.components.hitbox:SetHitFlags(HitGroup.ALL)

	inst.components.combat:SetFrontKnockbackOnly(true)
	inst.components.combat:SetVulnerableKnockdownOnly(true)
	inst.components.combat:SetBlockKnockback(true)

	inst:SetStateGraph("sg_groak")
	inst:SetBrain("brain_basic_melee")

	inst:AddComponent("auraapplyer")
	inst.components.auraapplyer:SetEffect("groak_suck")

	---foleysounder
	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.groak_footstep_big)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.groak_bodyfall)

    -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.groak_hit)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.groak_knockdown)

	inst:AddComponent("groaksync")

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	inst.components.auraapplyer:SetupBeamHitbox(1.5, 14.00, 2.00)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("groak_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	inst.components.auraapplyer:SetupBeamHitbox(1.5, 14.00, 2.00)

	inst:AddComponent("cineactor")
	inst.components.cineactor:AfterEvent_PlayAsLeadActor("cine_play_miniboss_intro", "cine_groak_intro")

	monsterutil.ExtendToEliteMonster(inst)

	return inst
end

------------------------------------------------------------------------------
-- Shockwave projectile
local function Setup(inst, owner)
	inst.owner = owner
	inst.components.combat:SetBaseDamage(owner, owner.components.combat.basedamage:Get())
end

local function shockwave_fn(prefabname)
	local inst = spawnutil.CreateProjectile(
	{
		name = prefabname,
		physics_size = 0.5,
		hits_targets = true,
		hit_group = HitGroup.NONE,
		hit_flags = HitGroup.ALL,
		does_hitstop = true,
		no_healthcomponent = true,
		stategraph = "sg_groak_shockwave",
		fx_prefab = "fx_bandicoot_groundring_solid",
	})

	inst.Setup = Setup

	return inst
end


return Prefab("groak", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("groak_elite", elite_fn, elite_assets, elite_prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("groak_shockwave", shockwave_fn, nil, nil, nil, NetworkType_SharedAnySpawn)