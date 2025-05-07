local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local spawnutil = require "util.spawnutil"
local fmodtable = require "defs.sound.fmodtable"
local SGCommon = require("stategraphs/sg_common")

local assets =
{
	Asset("ANIM", "anim/meowl_bank.zip"),
	Asset("ANIM", "anim/meowl_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/meowl_bank.zip"),
	Asset("ANIM", "anim/meowl_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_meowl"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "meowl")

local attacks =
{
	snowball =
	{
		priority = 1,
		damage_mod = 0.33,
		startup_frames = 30,
		cooldown = 4,
		initialCooldown = 0,
		pre_anim = "snowball_pre",
		hold_anim = "snowball_loop",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			return trange:TestDetachedBeam(0, 17, 0.5)
		end
	},

	taunt =
	{
		priority = 1,
		startup_frames = 48,
		cooldown = 4,
		initialCooldown = 0,
		pre_anim = "taunt_pre",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(8)
		end
	},
}

--[[local elite_attacks = lume.merge(attacks,
{
})]]

local MONSTER_SIZE = 1

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.SMALL)

	inst.HitBox:SetNonPhysicsRect(0.9)
	--inst.Transform:SetScale(1, 1, 1) --TEMP
	inst.components.scalable:SnapshotBaseSize()

	inst.AnimState:SetBank("meowl_bank")
	inst.AnimState:SetBuild("meowl_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:SetStateGraph("sg_meowl")
	inst:SetBrain("brain_basic_melee")

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

--[[local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("meowl_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	monsterutil.AddOffsetHitbox(inst)
	inst:AddTag("nointerrupt")
	inst.components.combat:SetHasKnockback(false)
	inst.components.combat:SetHasKnockdown(false)

	return inst
end]]

---------------------------------------------------------------------------------------
-- Projectile setup

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

return Prefab("meowl", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	--, Prefab("meowl_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("meowl_projectile", bullet_fn, bullet_assets, bullet_prefabs, nil, NetworkType_SharedAnySpawn)