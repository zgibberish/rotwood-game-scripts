local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local fmodtable = require "defs.sound.fmodtable"
local assets =
{
	Asset("ANIM", "anim/beets_bank.zip"),
	Asset("ANIM", "anim/beets_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/beets_bank.zip"),
	Asset("ANIM", "anim/beets_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_beets"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "beets")

local attacks =
{
	headslam =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 10,
		cooldown = 0, -- Always attack if in range
		initialCooldown = 0,
		pre_anim = "headslam_pre",
		hold_anim = "headslam_hold",
		start_conditions_fn = function(inst, data, trange)
			if trange:IsBetweenRange(0, 2) then
				return true
			end
		end
	},
}

local elite_attacks =
{
	elite_headslam =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 10,
		cooldown = 0, -- Always attack if in range
		initialCooldown = 0,
		pre_anim = "headslam_elite_pre",
		hold_anim = "headslam_elite_hold",
		start_conditions_fn = function(inst, data, trange)
			if trange:IsBetweenRange(0, 2.35) then
				return true
			end
		end
	},
}

local MONSTER_SIZE = 1

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.SMALL)

	inst.HitBox:SetNonPhysicsRect(0.9)
	inst.Transform:SetScale(1, 1, 1) --TEMP
	inst.components.scalable:SnapshotBaseSize()

	inst.AnimState:SetBank("beets_bank")
	inst.AnimState:SetBuild("beets_build")
	inst.AnimState:PlayAnimation("idle", true)
	-- inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	-- inst.components.coloradder:PushColor("gnarlic_temp", 255/255, 0/255, 0/255, 1)
	-- inst.components.colormultiplier:PushColor("gnarlic_temp", 255/255, 100/255, 100/255, 1)

	inst:SetStateGraph("sg_beets")
	inst:SetBrain("brain_basic_melee")

	---foleysounder
	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.beets_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.beets_bodyfall)    
	-- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    -- inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.beets_hit)
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

	inst.AnimState:SetBuild("beets_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	monsterutil.AddOffsetHitbox(inst)
	inst:AddTag("nointerrupt")
	inst.components.combat:SetHasKnockback(false)
	inst.components.combat:SetHasKnockdown(false)

	return inst
end

return Prefab("beets", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("beets_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)