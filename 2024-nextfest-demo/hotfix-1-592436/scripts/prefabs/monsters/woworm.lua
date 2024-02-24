local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local spawnutil = require "util.spawnutil"
local fmodtable = require "defs.sound.fmodtable"

local assets =
{
	Asset("ANIM", "anim/woworm_bank.zip"),
	Asset("ANIM", "anim/woworm_build.zip"),
}

--[[local elite_assets =
{
	Asset("ANIM", "anim/woworm_bank.zip"),
	Asset("ANIM", "anim/woworm_elite_build.zip"),
}]]

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",
	"trap_acid",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_woworm"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "woworm")

local attacks =
{
	--[[spray =
	{
		priority = 1,
		startup_frames = 30,
		cooldown = 13.33,
		initialCooldown = 0,
		max_attacks_per_target = 1,
		pre_anim = "spray_pre",
		hold_anim = "spray_hold",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			local result = false
			if trange:IsBetweenRange(5, 10) then
				result = monsterutil.MaxAttacksPerTarget(inst, data)
			end
			return result
		end
	},]]
	--[[bite =
	{
		priority = 1,
		startup_frames = 0.5,
		cooldown = 3,
		initialCooldown = 0,
		max_attacks_per_target = 1,
		pre_anim = "bite_pre",
		hold_anim = "bite_hold",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			return trange:IsBetweenRange(0, 3)
		end
	},]]
}

--[[local elite_attacks = lume.merge(attacks,
{
})]]

local MONSTER_SIZE = 1.0

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.MEDIUM)
	inst.HitBox:SetNonPhysicsRect(1)

	inst.components.scalable:SnapshotBaseSize()

	inst:AddTag("ACID_IMMUNE")
	inst.AnimState:SetBank("woworm_bank")
	inst.AnimState:SetBuild("woworm_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:SetStateGraph("sg_woworm")
	inst:SetBrain("brain_basic_melee")

	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.woworm_bodyfall)
    inst.components.foleysounder:SetFootstepSound(fmodtable.Event.woworm_footstep)

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

--[[local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("woworm_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	return inst
end]]

return Prefab("woworm", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	--, Prefab("woworm_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)