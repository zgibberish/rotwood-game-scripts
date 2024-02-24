local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local fmodtable = require "defs.sound.fmodtable"
local assets =
{
	Asset("ANIM", "anim/mothball_bank.zip"),
	Asset("ANIM", "anim/mothball_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/mothball_bank.zip"),
	Asset("ANIM", "anim/mothball_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_mothball"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "mothball")

local attacks =
{
	pierce =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 12,
		cooldown = 5,
		initialCooldown = 2.5,
		max_attacks_per_target = 2,
		pre_anim = "pierce_pre",
		hold_anim = "pierce_pre_hold",
		start_conditions_fn = function(inst, data, trange)
			local result = false
			if trange:IsInRange(5) then
				result = monsterutil.MaxAttacksPerTarget(inst, data)
			end
			return result
		end
	},

	claw =
	{
		priority = 2,
		damage_mod = 1.2,
		startup_frames = 8,
		cooldown = 0,
		initialCooldown = 0,
		max_attacks_per_target = 3,
		pre_anim = "claw_pre",
		hold_anim = "claw_loop",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			local result = false
			if trange:IsInRange(2) then
				result = monsterutil.MaxAttacksPerTarget(inst, data)
			end
			return result
		end
	},
}

local MONSTER_SIZE = 0.9

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.SMALL)

	inst.HitBox:SetNonPhysicsRect(0.9)
	inst.Transform:SetScale(1.1, 1.1, 1.1)
	inst.components.scalable:SnapshotBaseSize()

	inst.AnimState:SetBank("mothball_bank")
	inst.AnimState:SetBuild("mothball_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
	inst:AddTag("ACID_IMMUNE")

	inst:SetStateGraph("sg_mothball")
	inst:SetBrain("brain_basic_melee")

	---foleysounder
	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.mothball_footstep)
	-- inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.Dirt_bodyfall)

	-- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    -- inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.AAAA_default_event)
    -- inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.AAAA_default_event)



	inst.components.hitstopper:SetHitStopMultiplier(0.5) -- carve through these things!

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = normal_fn(prefabname)

	inst.AnimState:SetBuild("mothball_elite_build")

	monsterutil.ExtendToEliteMonster(inst)

	return inst
end

return Prefab("mothball", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("mothball_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)