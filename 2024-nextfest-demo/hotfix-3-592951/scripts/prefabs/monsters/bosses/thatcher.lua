local bossutil = require "prefabs.bossutil"
local monsterutil = require "util.monsterutil"
local spawnutil = require "util.spawnutil"
local fmodtable = require "defs.sound.fmodtable"
local SGCommon = require("stategraphs/sg_common")

local assets =
{
	Asset("ANIM", "anim/thatcher_bank.zip"),
	Asset("ANIM", "anim/thatcher_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_death_thatcher",

	"slowpoke_spit",
	"trap_acid",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_thatcher"),
}

local FIRST_PHASE = 1
local SECOND_PHASE = 2
local THIRD_PHASE = 3

local attacks =
{
	swing_short =
	{
		priority = 1,
		damage_mod = 1.0,
		startup_frames = 16,
		cooldown = 2,
		initialCooldown = 1,
		pre_anim = "swing_short_pre",
		start_conditions_fn = function(inst, data, trange)
			local current_phase = inst.boss_coro:CurrentPhase()
			return current_phase == SECOND_PHASE and trange:IsInRange(6)
		end,
	},

	swing_long =
	{
		priority = 1,
		damage_mod = 1.0,
		startup_frames = 24,
		cooldown = 2,
		initialCooldown = 1,
		pre_anim = "swing_short_pre",
		start_conditions_fn = function(inst, data, trange)
			local current_phase = inst.boss_coro:CurrentPhase()
			return current_phase == FIRST_PHASE and trange:IsInRange(6)
		end,
	},

	swing_uppercut =
	{
		priority = 1,
		damage_mod = 1.2,
		start_conditions_fn = function(inst, data, trange)
			return false -- Follow-up attack from swing_short
		end,
	},

	-- Acid projectiles will reference this attack for its damage_mod!
	acid_spit =
	{
		priority = 1,
		damage_mod = 0.3,
		startup_frames = 32,
		cooldown = 10,
		initialCooldown = 3,
		pre_anim = "acid_pre",
		hold_anim = "acid_hold",
		start_conditions_fn = function(inst, data, trange)
			local current_phase = inst.boss_coro:CurrentPhase()
			return current_phase <= SECOND_PHASE
		end,
	},

	hook =
	{
		priority = 1,
		damage_mod = 0.8,
		startup_frames = 27,
		cooldown = 3,
		initialCooldown = 2,
		pre_anim = "hook_pre",
		hold_anim = "hook_hold",
		start_conditions_fn = function(inst, data, trange)
			return false -- Phase 2 special attack called via the boss coroutine.
		end,
	},

	hook_uppercut =
	{
		priority = 1,
		damage_mod = 1.2,
		start_conditions_fn = function(inst, data, trange)
			return false -- Follow-up attack from hook
		end,
	},

	double_short_slash =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 28,
		cooldown = 3,
		initialCooldown = 3,
		pre_anim = "double_short_slash_pre",
		hold_anim = "double_short_slash_hold",
		start_conditions_fn = function(inst, data, trange)
			local current_phase = inst.boss_coro:CurrentPhase()
			return current_phase == THIRD_PHASE and trange:IsInRange(15)
		end,
	},

	full_swing =
	{
		priority = 1,
		damage_mod = 0.3,
		startup_frames = 44,
		cooldown = 0,
		initialCooldown = 0,
		pre_anim = "full_swing_pre",
		hold_anim = "full_swing_hold",
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			return false -- Phase 1 special attack called via the boss coroutine.
		end,
	},

	swing_smash =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 41,
		cooldown = 5,
		initialCooldown = 3,
		pre_anim = "swing_smash_pre",
		hold_anim = "swing_smash_hold",
		start_conditions_fn = function(inst, data, trange)
			return false -- Phase 3 special attack called via the boss coroutine.
		end,
	},

	--[[acid_coating =
	{
		start_conditions_fn = function(inst, data, trange)
			return false -- Special attack called via the boss coroutine.
		end,
	},]]

	acid_splash =
	{
		priority = 2,
		damage_mod = 0.3,
		startup_frames = 41,
		cooldown = 15,
		initialCooldown = 3,
		pre_anim = "acid_splash_pre",
		hold_anim = "acid_splash_hold",
		start_conditions_fn = function(inst, data, trange)
			local current_phase = inst.boss_coro:CurrentPhase()
			return current_phase == THIRD_PHASE
		end,
	},
}

--[[local function CreateHeadHitBox()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddHitBox()

	inst:AddTag("CLASSIFIED")

	inst.persists = false

	inst.HitBox:SetNonPhysicsRect(1.8)
	inst.HitBox:SetEnabled(false)

	return inst
end]]

--[[local function RetargetFn(inst)
	if inst.sg:HasStateTag("dormant") then
		return
	end

	local target = inst.components.combat:GetTarget()
	if target == nil then
		target = inst:GetClosestPlayerInRange(12, true)
	elseif not inst:IsNear(target, 12) then
		target = inst:GetClosestPlayerInRange(4, true)
	end
	return target
end]]

local function OnCombatTargetChanged(inst, data)
	if data.old == nil and data.new ~= nil then
		inst.boss_coro:Start()
	end
end

local MONSTER_SIZE = 1.9

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.GIANT)

	inst.AnimState:SetBank("thatcher_bank")
	inst.AnimState:SetBuild("thatcher_build")

	TheFocalPoint.components.focalpoint:StartFocusSource(inst, FocusPreset.BOSS)

	monsterutil.AddOffsetHitbox(inst, 1.8)

	inst.components.combat:SetFrontKnockbackOnly(true)
	inst.components.combat:SetVulnerableKnockdownOnly(true)
	inst.components.combat:SetBlockKnockback(true)

	inst.components.attacktracker:AddAttacks(attacks)

	inst:SetStateGraph("sg_thatcher")
	inst:SetBrain("brain_thatcher")
	inst:SetBossCoro("bc_thatcher")

	monsterutil.ExtendToBossMonster(inst)

	inst:ListenForEvent("combattargetchanged", OnCombatTargetChanged)
	bossutil.SetupLastPlayerDeadEventHandlers(inst)

	inst:AddComponent("monstertranslator")

	inst:AddComponent("cineactor")
	inst.components.cineactor:AfterEvent_PlayAsLeadActor("dying", "cine_boss_death_hit_hold", { "cine_thatcher_death" })
	inst.components.cineactor:QueueIntro("cine_thatcher_intro")

	---foleysounder
	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.thatcher_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.thatcher_bodyfall)
	inst.components.foleysounder:SetFootstepStopSound(fmodtable.Event.thatcher_footstep_stop)
	-- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
 --    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.AAAA_default_event)
 --    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.AAAA_default_event)

	return inst
end

---------------------------------------------------------------------------------------
-- Acid projectile
local acid_prefabs =
{
	GroupPrefab("fx_battoad"),
}

local debug_thatcher
local function OnEditorSpawn_dosetup(inst, editor)
	debug_thatcher = debug_thatcher or DebugSpawn("thatcher")
	debug_thatcher:Stupify("OnEditorSpawn")
	inst:Setup(debug_thatcher)
end

local function acid_fn(prefabname)
	local inst = spawnutil.CreateComplexProjectile(
	{
		name = prefabname,
		hits_targets = true,
		stategraph = "sg_thatcher_acidball",
		fx_prefab = "fx_battoad_projectile"
	})

	inst.components.complexprojectile:SetHorizontalSpeed(30)
	inst.components.complexprojectile:SetGravity(-1)

	inst.Setup = monsterutil.BasicProjectileSetup
	inst.OnEditorSpawn = OnEditorSpawn_dosetup

	return inst
end

---------------------------------------------------------------------------------------

--[[local deathfx_prefabs =
{
	"death_boss_frnt",
	"death_boss_grnd",
}

local function OnChildFxRemoved(child)
	local inst = child.entity:GetParent()
	inst._numchildren = inst._numchildren - 1
	if inst._numchildren == 0 then
		inst:DoTaskInTicks(0, inst.Remove)
	end
end

local function SetupDeathFxFor(inst, target)
	local x, z = target.Transform:GetWorldXZ()
	inst.Transform:SetPosition(x, 0, z)
	inst.frnt.Transform:SetRotation(target.Transform:GetRotation())
end

local function DoDeathFxTint(inst, tint)
	local k = 1 - tint
	inst.components.colormultiplier:PushColor("death", k, k, k, 1)
	inst.components.coloradder:PushColor("death", tint, tint, tint, 0)
	TheWorld.components.lightcoordinator:SetIntensity(k)
end

local function deathfx_fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	inst.persists = false

	inst.frnt = SpawnPrefab("death_boss_frnt", inst)
	inst.grnd = SpawnPrefab("death_boss_grnd", inst)

	inst.frnt.entity:SetParent(inst.entity)
	inst.grnd.entity:SetParent(inst.entity)

	inst:AddComponent("colormultiplier")
	inst.components.colormultiplier:AttachChild(inst.frnt)
	inst.components.colormultiplier:AttachChild(inst.grnd)

	inst:AddComponent("coloradder")
	inst.components.coloradder:AttachChild(inst.frnt)
	inst.components.coloradder:AttachChild(inst.grnd)

	inst._numchildren = 2
	inst:ListenForEvent("onremove", OnChildFxRemoved, inst.frnt)
	inst:ListenForEvent("onremove", OnChildFxRemoved, inst.grnd)

	inst.SetupDeathFxFor = SetupDeathFxFor

	DoDeathFxTint(inst, .8)
	inst:DoTaskInAnimFrames(1, DoDeathFxTint, .2)
	inst:DoTaskInAnimFrames(2, DoDeathFxTint, 0)

	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.cabbageroll_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.cabbageroll_bodyfall)

	inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.AAAA_default_event)
	return inst
end]]

---------------------------------------------------------------------------------------

return Prefab("thatcher", fn, assets, prefabs, nil, NetworkType_HostAuth)
	, Prefab("thatcher_acidball", acid_fn, nil, acid_prefabs, nil, NetworkType_ClientAuth)
	--, Prefab("fx_death_thatcher", deathfx_fn, nil, deathfx_prefabs, nil, NetworkType_HostAuth)
