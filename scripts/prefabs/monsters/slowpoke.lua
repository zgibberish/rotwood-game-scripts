local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local spawnutil = require "util.spawnutil"
local Enum = require "util.enum"
local fmodtable = require "defs.sound.fmodtable"
local SGCommon = require "stategraphs.sg_common"

local assets =
{
	Asset("ANIM", "anim/slowpoke_bank.zip"),
	Asset("ANIM", "anim/slowpoke_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/slowpoke_bank.zip"),
	Asset("ANIM", "anim/slowpoke_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",
	"slowpoke_spit",
	"trap_acid",
	"slowpoke_aoe",
	"slowpoke_elite_aoe",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_slowpoke"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "slowpoke")

local LocoState = Enum{ "SITTING", "STANDING" }

local function SetLocoState(inst, state)
	inst.loco_state = state
end

local function GetLocoState(inst)
	return inst.loco_state
end

local function IsSitting(inst)
	return inst:GetLocoState() == LocoState.s.SITTING
end

local function GoToLocoState(inst, locostate, endstate, ...)
	if inst:GetLocoState() == locostate then
		-- If you're already in this loco state, we don't have to do anything
		return true
	end
	-- Enter the locomotion transition state & then return back to the state that called this.
	inst.sg:GoToState(string.lower(locostate), { endstate = endstate or inst.sg.currentstate.name, data = { ... } })
end

local attacks =
{
	mortar =
	{
		priority = 2,
		damage_mod = 0.27,
		startup_frames = 30,
		cooldown = 5.33,
		initialCooldown = 0,
		pre_anim = "spit_bomb_pre",
		hold_anim = "spit_bomb_hold",
		start_conditions_fn = function(inst, data, trange)
			-- if not inst:IsSitting() then return false end
			return inst:IsSitting() or trange:IsBetweenRange(6, 20)
		end
	},

	body_slam =
	{
		damage_mod = 0.33,
		startup_frames = 45,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "body_slam_pre",
		hold_anim = "body_slam_loop",
		loop_hold_anim = true,
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			return not inst:IsSitting() and trange:IsInRange(6)
		end
	},
}

local elite_attacks =
{
	mortar =
	{
		priority = 2,
		damage_mod = 0.33,
		startup_frames = 30,
		cooldown = 5.33,
		initialCooldown = 0,
		pre_anim = "spit_bomb_pre",
		hold_anim = "spit_bomb_hold",
		start_conditions_fn = function(inst, data, trange)
			-- if not inst:IsSitting() then return false end
			return inst:IsSitting() or trange:IsBetweenRange(6, 20)
		end
	},

	elite_body_slam =
	{
		damage_mod = 0.5,
		startup_frames = 45,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "body_slam_pre",
		hold_anim = "body_slam_loop",
		loop_hold_anim = true,
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			return not inst:IsSitting() and trange:IsInRange(6)
		end
	},
}

local MONSTER_SIZE = 1.5

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.LARGE)

	inst.HitBox:SetNonPhysicsRect(2)
	inst.Transform:SetScale(0.84, 0.84, 0.84)
	inst.components.scalable:SnapshotBaseSize()

	inst.components.hitbox:SetHitFlags(HitGroup.ALL) -- Slowpoke's only melee attack is butt slam, so this will let buttslam attack enemies

	inst.AnimState:SetBank("slowpoke_bank")
	inst.AnimState:SetBuild("slowpoke_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst.LocoState = LocoState
	inst.IsSitting = IsSitting
	inst.GoToLocoState = GoToLocoState
	inst.GetLocoState = GetLocoState
	inst.SetLocoState = SetLocoState

	inst:SetLocoState(LocoState.s.STANDING)

	inst:SetStateGraph("sg_slowpoke")
	inst:SetBrain("brain_slowpoke")

	---foleysounder
	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.slowpoke_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.slowpoke_body_slam_land)
	-- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.slowpoke_hit)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.slowpoke_knockdown)

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("slowpoke_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	return inst
end

---------------------------------------------------------------------------------------

local spit_prefabs =
{
	GroupPrefab("fx_battoad"),
}

local debug_battoad
local function OnEditorSpawn_dosetup(inst, editor)
	debug_battoad = debug_battoad or DebugSpawn("slowpoke")
	debug_battoad:Stupify("OnEditorSpawn")
	inst:Setup(debug_battoad)
end

local function spit_fn(prefabname)
	local inst = spawnutil.CreateComplexProjectile(
	{
		name = prefabname,
		hits_targets = true,
		stategraph = "sg_slowpoke_spit",
		fx_prefab = "fx_battoad_projectile"
	})

	inst.components.complexprojectile:SetHorizontalSpeed(30)
	inst.components.complexprojectile:SetGravity(-1)

	inst.Setup = monsterutil.BasicProjectileSetup
	inst.OnEditorSpawn = OnEditorSpawn_dosetup

	return inst
end
---------------------------------------------------------------------------------------
--aoe prefab functions
---------------------------------------------------------------------------------------
local function aoe_hitbox(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "body_slam",
		set_dir_angle_to_target = true,
		hitstoplevel = HitStopLevel.HEAVY,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		pushback = 1.5,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
	})
end

local function aoe_elite_hitbox(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "elite_body_slam",
		set_dir_angle_to_target = true,
		hitstoplevel = HitStopLevel.HEAVY,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		pushback = 1.5,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
	})
end

local function aoe_fn(prefabname)
	local inst = CreateEntity()

	-- This is called slightly after aoe_fn, same frame, and contains the instigator reference which is networked
	inst.OnSetSpawnInstigator = function(inst, instigator)
		inst.owner = instigator
		inst.components.hitbox:SetHitGroup(HitGroup.MOB) --instigator.components.hitbox:GetHitGroup())
		inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS) --instigator.components.hitbox:GetHitFlags())
		inst.components.hitbox:PushCircle(0.30, 0.00, 6, HitPriority.MOB_DEFAULT)
	end

	inst.entity:AddTransform()
	inst.entity:AddHitBox()
	inst:AddComponent("hitbox")
	inst:AddComponent("combat")
	inst:ListenForEvent("hitboxtriggered", aoe_hitbox)
	inst.components.hitbox:StartRepeatTargetDelay()
	inst:DelayedRemove()

	return inst
end

local function aoe_elite_fn(prefabname)
	local inst = CreateEntity()

	-- This is called slightly after aoe_fn, same frame, and contains the instigator reference which is networked
	inst.OnSetSpawnInstigator = function(inst, instigator)
		inst.owner = instigator
		inst.components.hitbox:SetHitGroup(HitGroup.MOB) --instigator.components.hitbox:GetHitGroup())
		inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS) --instigator.components.hitbox:GetHitFlags())
		inst.components.hitbox:PushCircle(0.30, 0.00, 6, HitPriority.MOB_DEFAULT)
	end

	inst.entity:AddTransform()
	inst.entity:AddHitBox()
	inst:AddComponent("hitbox")
	inst:AddComponent("combat")
	inst:ListenForEvent("hitboxtriggered", aoe_elite_hitbox)
	inst.components.hitbox:StartRepeatTargetDelay()
	inst:DelayedRemove()

	return inst
end
---------------------------------------------------------------------------------------

return Prefab("slowpoke", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("slowpoke_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("slowpoke_spit", spit_fn, nil, spit_prefabs, nil, NetworkType_ClientAuth)
	, Prefab("slowpoke_aoe", aoe_fn, nil, nil, nil, NetworkType_None)
	, Prefab("slowpoke_elite_aoe", aoe_elite_fn, nil, nil, nil, NetworkType_None)