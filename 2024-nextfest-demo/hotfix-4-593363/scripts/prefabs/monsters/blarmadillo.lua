local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local spawnutil = require "util.spawnutil"
local fmodtable = require "defs.sound.fmodtable"
local SGCommon = require("stategraphs/sg_common")

local assets =
{
	Asset("ANIM", "anim/blarmadillo_bank.zip"),
	Asset("ANIM", "anim/blarmadillo_build.zip"),
	Asset("ANIM", "anim/blarmadillo_dirt.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/blarmadillo_bank.zip"),
	Asset("ANIM", "anim/blarmadillo_elite_build.zip"),
	Asset("ANIM", "anim/blarmadillo_dirt.zip"),
}


local prefabs =
{
	"blarmadillo_bullet",
	"fx_hurt_sweat",
	"fx_low_health_ring",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_blarmadillo"),
	GroupPrefab("drops_currency"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "blarmadillo")

local attacks =
{
	shoot =
	{
		priority = 5,
		startup_frames = 60,
		cooldown = 1.33,
		pre_anim = "shoot_single_pre",
		hold_anim = "shoot_single_pre_loop",
		loop_hold_anim = true,
		--max_interrupts = 2,
		start_conditions_fn = function(inst, data, trange)
			if trange:TestDetachedBeam(0, 17, 0.5) then
				return true
			end
		end
	},
	roll =
	{
		priority = 10,
		startup_frames = 20,
		cooldown = 5.33,
		initialCooldown = 0,
		pre_anim = "roll_pre",
		hold_anim = "roll_pre_hold",
		start_conditions_fn = function(inst, data, trange)
			-- TODO(dbriscoe): Is this logic inverted?
			if trange:IsInRange(7) -- if your target is too close to you
			or trange:IsOutOfRange(22) -- or if you're just way too far away
			or trange:IsOutOfZRange(7) then -- if you're more than 5 Z units away from your target
				return true
			end
		end
	}
}

local elite_attacks =
{
	elite_shoot =
	{
		priority = 5,
		damage_mod = 1.5,
		startup_frames = 60,
		cooldown = 1.33,
		pre_anim = "elite_shoot_pre",
		hold_anim = "elite_shoot_pre_loop",
		loop_hold_anim = true,
		--max_interrupts = 2,
		start_conditions_fn = function(inst, data, trange)
			if trange:TestDetachedBeam(0, 17, 0.5) then
				return true
			end
		end
	},
	roll =
	{
		priority = 10,
		startup_frames = 15,
		cooldown = 5.33,
		initialCooldown = 0,
		pre_anim = "roll_pre",
		hold_anim = "roll_pre_hold",
		start_conditions_fn = function(inst, data, trange)
			if trange:IsInRange(7) -- if your target is too close to you
			or trange:IsOutOfRange(22) -- or if you're just way too far away
			or trange:IsOutOfZRange(7) then -- if you're more than 5 Z units away from your target
				return true
			end
		end
	}
}

local MONSTER_SIZE = 1.1

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.MEDIUM)

	inst.AnimState:SetBank("blarmadillo_bank")
	inst.AnimState:SetBuild("blarmadillo_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst.components.combat:SetVulnerableKnockdownOnly(false)
	inst.components.combat:SetKnockdownLengthModifier(0.3)
	inst.components.combat:SetBlockKnockback(true)

	inst:SetStateGraph("sg_blarmadillo")
	inst:SetBrain("brain_blarmadillo")

	-- inst:AddComponent("foleysounder")
	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.blarmadillo_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.blarmadillo_bodyfall)
	-- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.blarmadillo_hit)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.blarmadillo_knockdown)

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("blarmadillo_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	-- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    -- inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.blarmadillo_Elite_knockback)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.blarmadillo_Elite_knockdown)

	return inst
end

---------------------------------------------------------------------------------------

local bullet_assets =
{
	Asset("ANIM", "anim/blarmadillo_dirt.zip"),
}

local bullet_prefabs =
{
	"hits_dirt",
}

local function OnHitBoxTriggered(inst, data)
	SGCommon.Events.OnProjectileHitboxTriggered(inst, data, {
		attackdata_id = "shoot",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.4,
		hitflags = Attack.HitFlags.PROJECTILE,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 2,
	})
end

local function bullet_fn(prefabname)
	local inst = spawnutil.CreateProjectile(
	{
		name = prefabname,
		physics_size = 0.5,
		hits_targets = true,
		twofaced = true,
		bank = "blarmadillo_dirt",
		build = "blarmadillo_dirt",
		stategraph = "sg_blarmadillo_projectile",
		motor_vel = 14,
	})

	inst.Setup = monsterutil.BasicProjectileSetup
	inst.components.projectilehitbox:PushBeam(-1.5, 1, 0.75, HitPriority.MOB_PROJECTILE, true)	-- true = initial hitbox
									:PushBeam(-2, -1.5, 1.25, HitPriority.MOB_PROJECTILE, true)	-- true = initial hitbox
									:PushBeam(0, 0.75, 0.33, HitPriority.MOB_PROJECTILE)
									:SetTriggerFunction(OnHitBoxTriggered)

	return inst
end

---------------------------------------------------------------------------------------

return Prefab("blarmadillo", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("blarmadillo_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("blarmadillo_bullet", bullet_fn, bullet_assets, bullet_prefabs, nil, NetworkType_SharedAnySpawn)
