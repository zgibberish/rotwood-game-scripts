local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local spawnutil = require "util.spawnutil"
local fmodtable = require "defs.sound.fmodtable"

local assets =
{
	Asset("ANIM", "anim/battoad_bank.zip"),
	Asset("ANIM", "anim/battoad_build.zip"),
	Asset("ANIM", "anim/battoad_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",
	"battoad_spit",
	"battoad_aoe",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_battoad"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "battoad")

local LocoState = MakeEnum{ "GROUND", "AIR" }

local function SetWalkSpeedFleeing(inst)
	inst.components.locomotor:SetWalkSpeed(inst.tuning.walk_speed_fleeing)
end

local function SetPhysicsSizeFleeing(inst)
	-- Make the battoad have smaller physics so it doesn't get tripped up on things while fleeing. Keep its physics box the same.
	local size = inst.Physics:GetSize()
	inst.Physics:SetSize(0.01)
	inst.HitBox:SetNonPhysicsRect(size)
end

local function SetLocoState(inst, state)
	local grounded = (state == LocoState.GROUND)
	inst.components.battoadsync.on_ground = grounded
	inst.components.combat:SetHasKnockback(grounded)
end

local function IsAirborne(inst)
	return not inst.components.battoadsync.on_ground
end

local FLIGHT_THRESHOLD = 0 --0.60 jambell: making this state impossible to simplify this mob for now.

local function OnHealthChanged(inst, data)
	if data.old/data.max > FLIGHT_THRESHOLD and data.new/data.max <= FLIGHT_THRESHOLD then
		-- reset combat cooldown
		inst.components.attacktracker:CancelActiveAttack()
		inst.components.combat:StopCooldown()
	end
end

local attacks =
{
	-- flying attacks

	-- spit =
	-- {
	-- 	priority = 5,
	-- 	damage_mod = 1,
	-- 	startup_frames = 30,
	-- 	cooldown = 10,
	-- 	initialCooldown = 0,
	-- 	pre_anim = "spit_pre",
	-- 	hold_anim = "spit_hold",
	-- 	start_conditions_fn = function(inst, data, trange)
	-- 		if not inst:IsAirborne() then return false end
	-- 		return trange:IsBetweenRange(10, 20)
	-- 	end
	-- },

	slash =
	{
		damage_mod = 1,
		startup_frames = 20,
		cooldown = 4.5,
		initialCooldown = 0,
		pre_anim = "slash_pre",
		hold_anim = "slash_hold",
		start_conditions_fn = function(inst, data, trange)
			return inst:IsAirborne() and trange:IsInRange(4)
		end
	},

	slash2 =
	{
		damage_mod = 1.2,
		startup_frames = 15,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "slash2_pre",
		hold_anim = "slash2_hold",
		start_conditions_fn = function(inst, data, trange)
			return inst:IsAirborne() and inst.sg.statemem.chainattack == 2
		end
	},

	-- sitting attacks

	tongue =
	{
		priority = 8,
		damage_mod = 0.5,
		startup_frames = 10,
		cooldown = 3.33,
		initialCooldown = 3,
		pre_anim = "tongue_pre",
		hold_anim = "tongue_hold",
		start_conditions_fn = function(inst, data, trange)
			return not inst:IsAirborne() and trange:TestBeam(0, 4.75, 1)
		end
	},

	upperwings =
	{
		priority = 10,
		damage_mod = 0.1,
		startup_frames = 60,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "upperwings_pre",
		hold_anim = "upperwings_hold",
		start_conditions_fn = function(inst, data, trange)
			return not inst:IsAirborne() and inst.components.health:GetPercent() < FLIGHT_THRESHOLD
		end
	},

	swallow =
	{
		startup_frames = 75,
		cooldown = 0, -- limited by how fast you can steal konjur with the tongue attack
		pre_anim = "swallow_pre",
		hold_anim = "swallow_loop",
		loop_hold_anim = true,
		start_conditions_fn = function()
			return false -- does not use this flow to evaluate start
		end
	},
}

local elite_attacks =
{
	-- flying attacks

	-- spit =
	-- {
	-- 	priority = 5,
	-- 	damage_mod = 1,
	-- 	startup_frames = 30,
	-- 	cooldown = 10,
	-- 	initialCooldown = 0,
	-- 	pre_anim = "spit_pre",
	-- 	hold_anim = "spit_hold",
	-- 	start_conditions_fn = function(inst, data, trange)
	-- 		if not inst:IsAirborne() then return false end
	-- 		return trange:IsBetweenRange(10, 20)
	-- 	end
	-- },
}

local MONSTER_SIZE = 1.2

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.SMALL)

	monsterutil.ExtendToFlyingMonster(inst)

	inst:AddComponent("battoadsync")
	inst.AnimState:SetBank("battoad_bank")
	inst.AnimState:PlayAnimation("sit_idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
	inst.AnimState:HideSymbol("cheeks")

	inst.components.combat:SetBlockKnockback(true)
	inst.components.combat:SetVulnerableKnockdownOnly(true)

	inst.LocoState = LocoState
	inst.IsAirborne = IsAirborne
	inst.SetLocoState = SetLocoState
	inst.SetWalkSpeedFleeing = SetWalkSpeedFleeing
	inst.SetPhysicsSizeFleeing = SetPhysicsSizeFleeing

	inst:SetStateGraph("sg_battoad")
	inst:SetBrain("brain_battoad")

	inst:ListenForEvent('healthchanged', OnHealthChanged)
	inst:SetLocoState(LocoState.GROUND)

	-- inst:AddComponent("foleysounder")
	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.battoad_land)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.battoad_bodyfall)
	-- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.battoad_hit1)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.battoad_hit1)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.battoad_knockdown)

	inst.components.attacktracker:AddAttacks(attacks) -- Elite battoad has the same attacks, but extras.

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("battoad_build")

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("battoad_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)
	inst.apply_on_lick = "confused"

	monsterutil.ExtendToEliteMonster(inst)

	monsterutil.AddOffsetHitbox(inst)

	return inst
end

---------------------------------------------------------------------------------------

local spit_prefabs =
{
	GroupPrefab("fx_battoad"),
}

local debug_battoad
local function OnEditorSpawn_dosetup(inst, editor)
	debug_battoad = debug_battoad or DebugSpawn("battoad")
	debug_battoad:Stupify("OnEditorSpawn")
	inst:Setup(debug_battoad)
end

local function spit_fn(prefabname)
	local inst = spawnutil.CreateComplexProjectile(
	{
		name = prefabname,
		hits_targets = true,
		stategraph = "sg_battoad_spit",
		fx_prefab = "fx_battoad_projectile"
	})

	inst.components.complexprojectile:SetHorizontalSpeed(30)
	inst.components.complexprojectile:SetGravity(-1)

	inst.Setup = monsterutil.BasicProjectileSetup
	inst.OnEditorSpawn = OnEditorSpawn_dosetup

	return inst
end

---------------------------------------------------------------------------------------

return Prefab("battoad", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("battoad_elite", elite_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("battoad_spit", spit_fn, nil, spit_prefabs, nil, NetworkType_SharedHostSpawn)
