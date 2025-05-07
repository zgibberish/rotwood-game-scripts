local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local spawnutil = require "util.spawnutil"
local fmodtable = require "defs.sound.fmodtable"
local lume = require "util.lume"
local SGCommon = require("stategraphs/sg_common")

local assets =
{
	Asset("ANIM", "anim/eye_v_bank.zip"),
	Asset("ANIM", "anim/eye_v_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/eye_v_bank.zip"),
	Asset("ANIM", "anim/eye_v_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",

	--Drops
	GroupPrefab("drops_generic"),
    GroupPrefab("drops_eyev"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "eyev")

local attacks =
{
	pierce =
	{
		priority = 2,
		damage_mod = 0.5,
		startup_frames = 7,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "pierce_pre",
		hold_anim = "pierce_loop",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(4)
		end
	},

	spin =
	{
		priority = -1,
		damage_mod = 2,
		startup_frames = 5,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "spin_pre",
		hold_anim = "spin_pre_hold",
		start_conditions_fn = function(inst, data, trange)
			return false -- This attack only gets used after playing its 'COUNTER' animation
		end
	},

	-- Fishes for a counter hit -- if Eye-V is struck during this state, they'll go into their counter spin attack.
	counter =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 22,
		cooldown = 6, -- This attack is also triggered by taking too much damage
		initialCooldown = 2,
		pre_anim = "counter_pre",
		hold_anim = "counter_loop",
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(4)
		end
	},

	-- Not really an attack, but something that can be done instead of an attack
	evade =
	{
		priority = -1,
		startup_frames = 8,
		cooldown = 6.67,
		initialCooldown = 5,
		pre_anim = "evade_pre",
		start_conditions_fn = function(inst, data, trange)
			return false -- trange:IsInRange(4) this should not be entered randomly since it confuses the counter behavior
		end
	},
}

local elite_attacks = lume.merge(attacks,
{
	razor_leaf =
	-- Goes into a state almost visually similiar to the counter-attack pose, but goes into a shoot projectiles all-around attack if ignored.
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 12,
		cooldown = 9,
		initialCooldown = 3,
		pre_anim = "counter_pre",
		hold_anim = "counter_loop",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(8)
		end
	},
})

local MONSTER_SIZE = 0.75

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.SMALL)

	inst.AnimState:SetBank("eye_v_bank")
	inst.AnimState:SetBuild("eye_v_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:SetStateGraph("sg_eyev")
	inst:SetBrain("brain_basic_melee")

	inst.components.combat:SetVulnerableKnockdownOnly(true)

	-- Assign the base anim name used for locomotion state names
	inst.sg.mem.walkname = "fly"

	-- Allow for players to roll through it, since it's considered to be floating in the air
	monsterutil.ExtendToFlyingMonster(inst)

	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.eyev_bodyfall)
	-- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    -- inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.eyev_knockback)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.eyev_knockdown)



	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("eye_v_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	return inst
end

---------------------------------------------------------------------------------------
-- Projectile setup

local projectile_assets = elite_assets
local projectile_prefabs = {}

local function OnHitBoxTriggered(inst, data)
	SGCommon.Events.OnProjectileHitboxTriggered(inst, data, {
		damage_mod = 0.5,
		attackdata_id = "shoot",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.4,
		hitflags = Attack.HitFlags.PROJECTILE,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 2,
	})
end

local function projectile_fn(prefabname)
	local inst = spawnutil.CreateProjectile(
	{
		name = prefabname,
		physics_size = 0.5,
		hits_targets = true,
		twofaced = true,
		bank = "eye_v_bank",
		build = "eye_v_elite_build",
		stategraph = "sg_eyev_projectile",
		start_anim = "razor_leaf",
		motor_vel = 16,
	})

	inst.Setup = monsterutil.BasicProjectileSetup
	inst.components.projectilehitbox:PushCircle(0, 0, 0.5, HitPriority.MOB_PROJECTILE)
									:SetTriggerFunction(OnHitBoxTriggered)

	return inst
end

---------------------------------------------------------------------------------------

return Prefab("eyev", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("eyev_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("eyev_projectile", projectile_fn, projectile_assets, projectile_prefabs, nil, NetworkType_SharedAnySpawn)
