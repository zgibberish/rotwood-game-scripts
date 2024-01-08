local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local fmodtable = require "defs.sound.fmodtable"
local assets =
{
	Asset("ANIM", "anim/bunippy_bank.zip"),
	Asset("ANIM", "anim/bunippy_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/bunippy_bank.zip"),
	Asset("ANIM", "anim/bunippy_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_bunippy"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "bunippy")

local attacks =
{
	kick =
	{
		priority = 1,
		damage_mod = 0.33,
		startup_frames = 20,
		cooldown = 3,
		initialCooldown = 0,
		pre_anim = "kick_pre",
		hold_anim = "kick_hold",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(6)
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

	inst.AnimState:SetBank("bunippy_bank")
	inst.AnimState:SetBuild("bunippy_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:SetStateGraph("sg_bunippy")
	inst:SetBrain("brain_basic_melee")

	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.totolili_bodyfall)
    inst.components.foleysounder:SetFootstepSound(fmodtable.Event.totolili_footstep)

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

--[[local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("bunippy_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	monsterutil.AddOffsetHitbox(inst)
	inst:AddTag("nointerrupt")
	inst.components.combat:SetHasKnockback(false)
	inst.components.combat:SetHasKnockdown(false)

	return inst
end]]

return Prefab("bunippy", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	--, Prefab("bunippy_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)