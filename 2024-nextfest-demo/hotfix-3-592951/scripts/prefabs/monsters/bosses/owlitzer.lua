local bossutil = require "prefabs.bossutil"
local monsterutil = require "util.monsterutil"
local spawnutil = require "util.spawnutil"
local krandom = require "util.krandom"
local fmodtable = require "defs.sound.fmodtable"
local SGCommon = require("stategraphs/sg_common")

local ParticleSystemHelper = require "util.particlesystemhelper"
local easing = require "util.easing"

local assets =
{
	Asset("ANIM", "anim/owlitzer_bank.zip"),
	Asset("ANIM", "anim/owlitzer_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_ground_target_red",

	"owlitzer_spikeball",
	"owlitzer_target",
	"owlitzer_fly_by_left",
	"owlitzer_fly_by_right",
	"owlitzer_super_flap_right",
	"owlitzer_super_flap_left",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_owlitzer"),
}

local function is_in_phase(inst, phase)
	return inst.boss_coro:CurrentPhase() == phase
end

local attacks =
{

	-- All phases
	wind_gust =
	{
		priority = 1,
		damage_mod = 0.6,
		startup_frames = 15,
		cooldown = 2,
		initialCooldown = 0,
		pre_anim = "wind_gust_fly_pre",
		hold_anim = "wind_gust_hold",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(10)
		end,
	},

	-- All Phases
	dive_bomb =
	{
		priority = 0,
		damage_mod = 1.3,
		startup_frames = 85 + 48, -- pre anim is 48 frames long
		cooldown = 0,
		pre_anim = "dive_bomb_pre",
		hold_anim = "dive_bomb_hold",
		start_conditions_fn = function(inst, data, trange)
			return false -- This gets called via the boss coroutine.
		end
	},

	-- Phase 1
	slash_air =
	{
		priority = 1,
		damage_mod = 0.7,
		startup_frames = 25,
		cooldown = 0.33,
		initialCooldown = 0,
		pre_anim = "slash_air_pre",
		hold_anim = "slash_air_hold",
		start_conditions_fn = function(inst, data, trange)
			return (is_in_phase(inst, 1) or is_in_phase(inst, 4)) and trange:IsInRange(6)
		end,
	},

	-- Phase 1
	slash2_air =
	{
		priority = 0,
		damage_mod = 0.9,
		startup_frames = 10,
		cooldown = 0.33,
		initialCooldown = 0,
		pre_anim = "slash2_air_pre",
		hold_anim = "slash2_air_hold",
		start_conditions_fn = function(inst, data, trange)
			return false -- This gets called from slash_air.
		end,
	},

	-- Phase 2
	dive_slam =
	{
		priority = 2,
		damage_mod = 1.1,
		startup_frames = 25,
		cooldown = 3.33,
		initialCooldown = 3,
		pre_anim = "dive_slam_pre",
		hold_anim = "dive_slam_hold",
		start_conditions_fn = function(inst, data, trange)
			return (is_in_phase(inst, 2) or is_in_phase(inst, 4)) and trange:IsInRange(6)
		end
	},

	-- Phase 3
	snatch =
	{
		priority = 1,
		damage_mod = 1.0,
		startup_frames = 25,
		cooldown = 0,
		initialCooldown = 0,
		pre_anim = "snatch_pre",
		hold_anim = "snatch_hold",
		start_conditions_fn = function(inst, data, trange)
			return (is_in_phase(inst, 3) or is_in_phase(inst, 4)) and trange:IsInRange(12)
		end,
	},

	fly_by =
	{
		priority = 0,
		damage_mod = 1.5,
		startup_frames = 90,
		cooldown = 0,
		start_conditions_fn = function(inst, data, trange)
			return false -- This gets called via the boss coroutine.
		end
	},

	spikeball =
	{
		priority = 0,
		damage_mod = 0.5,
		cooldown = 0,
		start_conditions_fn = function(inst, data, trange)
			return false -- Used by owlitzer_spikeball prefab.
		end
	},

	phase_transition_get_off_me =
	{
		priority = 0,
		cooldown = 0,
		startup_frames = 60,
		pre_anim = "phase_transition_get_off_me_pre",
		hold_anim = "phase_transition_get_off_me_hold",
		start_conditions_fn = function(inst, data, trange)
			return false -- Transition attack, manually called by owlitzer.
		end
	}
}

local function OnCombatTargetChanged(inst, data)
	if data.old == nil and data.new ~= nil then
		inst.boss_coro:Start()
	end
end

local MONSTER_SIZE = 2.8

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.GIANT)

	inst.AnimState:SetBank("owlitzer_bank")
	inst.AnimState:SetBuild("owlitzer_build")
	--inst.AnimState:PlayAnimation("idle", true)

	-- Eye bloom
	local r, g, b = HexToRGBFloats(StrToHex("A5FFEB67"))
	local intensity = 0.6
	inst.AnimState:SetSymbolBloom("eye_untex", r, g, b, intensity)

	TheFocalPoint.components.focalpoint:StartFocusSource(inst, FocusPreset.BOSS)

	inst.components.combat:SetFrontKnockbackOnly(true)
	inst.components.combat:SetVulnerableKnockdownOnly(true)
	inst.components.combat:SetBlockKnockback(true)

	inst.components.attacktracker:AddAttacks(attacks)

	inst:SetStateGraph("sg_owlitzer")
	inst:SetBrain("brain_owlitzer")
	inst:SetBossCoro("bc_owlitzer")

	monsterutil.ExtendToBossMonster(inst)

	inst:ListenForEvent("combattargetchanged", OnCombatTargetChanged)
	bossutil.SetupLastPlayerDeadEventHandlers(inst)

	-- Assign the base anim name used for locomotion state names
	inst.sg.mem.walkname = "fly"

	-- Allow for players to roll through it, since it's considered to be floating in the air
	monsterutil.ExtendToFlyingMonster(inst)

	inst:AddComponent("auraapplyer")

	inst:AddComponent("patternspawner")

	inst:AddComponent("cineactor")
	inst.components.cineactor:AfterEvent_PlayAsLeadActor("dying", "cine_boss_death_hit_hold", { "cine_owlitzer_death" })
	inst.components.cineactor:QueueIntro("cine_owlitzer_intro")

	---foleysounder
	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.cabbageroll_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.cabbageroll_bodyfall)
	inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.AAAA_default_event)

	return inst
end

---------------------------------------------------------------------------------------
-- Spike ball projectile

local projectile_assets =
{
	Asset("ANIM", "anim/trap_owlitzer_hairball.zip")
}

local projectile_prefabs =
{
}

local function OnPhysicsCollide(inst, other)
	if other and other == TheWorld then -- Set spikeballs to get removed when colliding with level physics.
		inst.components.health:SetCurrent(0)
	end
end

local function OnHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "spikeball",
		hitstoplevel = HitStopLevel.LIGHT,
		hitstun_anim_frames = 0,
		pushback = 0.5,
		combat_attack_fn = "DoKnockbackAttack",
		hitflags = inst.sg.mem.inair and Attack.HitFlags.AIR_HIGH or Attack.HitFlags.LOW_ATTACK,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = -5,
		can_hit_self = data and data.self_damage or nil,
		ignore_tags = { "spikeball" },
	})

	-- If hit, do damage to itself
	--[[if hit and not data.self_damage then
		data.targets = {}
		data.self_damage = true
		table.insert(data.targets, inst)
		OnHitBoxTriggered(inst, data)
	end]]
	if hit then
		inst.components.health:SetCurrent(0)
	end
end

local function projectile_fn(prefabname)
	local inst = spawnutil.CreateComplexProjectile(
	{
		name = prefabname,
		hits_targets = true,
		hit_group = HitGroup.NEUTRAL,
		hit_flags = HitGroup.CHARACTERS,
		health = 120,
		bank = "trap_owlitzer_hairball",
		build = "trap_owlitzer_hairball",
		stategraph = "sg_owlitzer_spikeball",
		--collision_callback = OnPhysicsCollide,
	})

	inst.Setup = monsterutil.BasicProjectileSetup

	-- The object has physics when it's on the floor, so it needs physics.
	MakeSmallMonsterPhysics(inst, 0.8)
	inst.Physics:SetCollisionCallback(OnPhysicsCollide) -- For colliding with level bounds when getting blown.

	inst:AddTag("spikeball")

	local tuning = TUNING.TRAPS["owlitzer_spikeball"]
	inst.components.combat:SetBaseDamage(inst, tuning.BASE_DAMAGE)

	-- Setup hitbox
	inst.components.projectilehitbox:SetTriggerFunction(OnHitBoxTriggered)
	inst.components.projectilehitbox:PushCircle(0.00, 0.00, 0.8, HitPriority.MOB_DEFAULT)
	inst.components.projectilehitbox:SetEnabled(false)

	inst.components.hitbox:SetHitFlags(HitGroup.PLAYER | HitGroup.NPC)

	-- Need to add these to allow it to get blown by Owlitzer.
	inst:AddComponent("powermanager")
	inst.components.powermanager:EnsureRequiredComponents()
	--inst.components.powermanager:IgnorePower("owlitzer_super_flap") -- Spike balls don't get blown by super flap until this is removed.

	inst:AddComponent("locomotor")
	inst:AddComponent("pushforce")

	-- Spikeballs have slight variance in their weights (0.7 +/- 0.1)
	local weight = krandom.Float(1.6, 2.1)
	inst.components.pushforce:AddPushForceModifier("weight", weight)

	inst.AnimState:SetShadowEnabled(true)
	inst.serializeHistory = true -- TODO: networking2022, rework death implementation as this is expensive to enable given how many spikeballs are often in play

	-- Add bloom to the spikes.
	local r, g, b = HexToRGBFloats(StrToHex("FF88F4FF"))
	local intensity = 1
	inst.AnimState:SetLayerBloom("glow", r, g, b, intensity)

	-- Randomly flip the anim to make the spikeballs on the ground look more varied.
	if math.random() < 0.5 then
		inst.AnimState:SetScale(-1, 1)
	end

	inst.OnSetSpawnInstigator = function(_, instigator)
		if instigator then
			inst.spawner = instigator -- save the owning projectile on the entity
			inst.spawner:ListenForEvent("onremove", function()
				inst.spawner = nil
			end)
		end
	end

	return inst
end

---------------------------------------------------------------------------------------
-- Targeting FX

local target_assets =
{
	Asset("ANIM", "anim/fx_owlitzer_target_eyes.zip"),
}

local target_prefabs =
{
	"fx_ground_target_red"
}

local function SetProgress(inst, start_scale, end_scale, progress)
	if not inst.fx then return end
	local scale = easing.linear(progress, start_scale, end_scale - start_scale, 1)
	inst.fx.AnimState:SetScale(scale, scale)
end

local function target_fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()

	inst.SetProgress = SetProgress

	inst.AnimState:SetBank("fx_owlitzer_target_eyes")
	inst.AnimState:SetBuild("fx_owlitzer_target_eyes")
	inst.AnimState:SetBloom( 255/255, 200/255, 0/255, 0.66)

	inst:AddComponent("dropshadow")
	inst.components.dropshadow:SetBank("fx_ground_target")
	inst.components.dropshadow:SetBuild("fx_ground_target")
	inst.components.dropshadow:PlayAnimation("idle", true)
	inst.components.dropshadow:SetMultColor(1, 0.56, 0.56, 0.90)
	inst.components.dropshadow:SetBloom(1, 0, 0, 0.5)
	inst.components.dropshadow:SetBrightness(1)
	inst.fx = inst.components.dropshadow:GetDropShadow()

	inst:AddComponent("coloradder")

	inst:SetStateGraph("sg_owlitzer_target")

	return inst
end

---------------------------------------------------------------------------------------
-- Super Flap FX

local super_flap_prefabs =
{
	"owlitzer_fullscreen_superflap",
}

local function SpawnSuperFlapFX(inst)
	local fx_params =
	{
		name = "super_flap_wind",
		particlefxname = "owlitzer_fullscreen_superflap",
		use_entity_facing = true,
		ischild = true,
	}

    ParticleSystemHelper.MakeEventSpawnParticles(inst, fx_params)
end

local function DespawnSuperFlapFX(inst)
	ParticleSystemHelper.MakeEventStopParticles(inst, { name = "super_flap_wind" })
	inst.components.auraapplyer:EnableRampDown(true)
	inst.components.auraapplyer:Disable()
	inst:DoTaskInTime(5, function() inst:Remove() end)
end

local function super_flap_fn_right(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddHitBox()
	inst.entity:AddTransform()

	inst.Transform:SetTwoFaced()

	inst.SpawnFX = SpawnSuperFlapFX
	inst.DespawnFX = DespawnSuperFlapFX

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitFlags(HitGroup.ALL)

	inst:AddComponent("powermanager")
	inst:AddComponent("auraapplyer")

	local beam_length = 50
	local beam_height = 30

	inst.components.auraapplyer:SetEffect("owlitzer_super_flap")
	inst.components.auraapplyer:SetupBeamHitbox(0, beam_length, beam_height)
	inst.components.auraapplyer:EnableRampUp(true)
	inst.components.auraapplyer:Enable()

	inst:SetStateGraph("sg_blank") -- ParticleSystemHelper requires a stategraph.

	return inst
end

-- for ease of networking
local function super_flap_fn_left(prefabname)
	local inst = super_flap_fn_right(prefabname)
	inst.Transform:SetRotation(180)
	return inst
end

---------------------------------------------------------------------------------------
-- Fly By FX

local fly_by_prefabs =
{
	"owlitzer_flyby_warning_wind",
}

local function SpawnFlyByFX(inst)
    local fx_params =
    {
        name = "flyby_warning",
        particlefxname = "owlitzer_flyby_warning_wind",
        use_entity_facing = true,
        ischild = true,
    }

    ParticleSystemHelper.MakeEventSpawnParticles(inst, fx_params)
end

local function DespawnFlyByFX(inst)
	ParticleSystemHelper.MakeEventStopParticles(inst, { name = "flyby_warning" })
	inst.components.auraapplyer:EnableRampDown(true)
	inst.components.auraapplyer:Disable()
	inst:DoTaskInTime(5, function() inst:Remove() end)
end

local function fly_by_fn_right(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddHitBox()
	inst.entity:AddTransform()

	inst.Transform:SetTwoFaced()

	inst.SpawnFX = SpawnFlyByFX
	inst.DespawnFX = DespawnFlyByFX

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitFlags(HitGroup.ALL)

	inst:AddComponent("powermanager")
	inst:AddComponent("auraapplyer")

	local beam_length = 100
	local beam_height = 5

	inst.components.auraapplyer:SetEffect("push")
	inst.components.auraapplyer:SetupBeamHitbox(0, beam_length, beam_height)
	inst.components.auraapplyer:EnableRampUp(true)
	inst.components.auraapplyer:Enable()

	inst:SetStateGraph("sg_blank") -- ParticleSystemHelper requires a stategraph.

	return inst
end

-- for ease of networking
local function fly_by_fn_left(prefabname)
	local inst = fly_by_fn_right(prefabname)
	inst.Transform:SetRotation(180)
	return inst
end

return Prefab("owlitzer", fn, assets, prefabs, nil, NetworkType_HostAuth)
	, Prefab("owlitzer_spikeball", projectile_fn, projectile_assets, projectile_prefabs, nil, NetworkType_SharedAnySpawn)
	, Prefab("owlitzer_target", target_fn, target_assets, target_prefabs, nil, NetworkType_HostAuth)
	, Prefab("owlitzer_fly_by_right", fly_by_fn_right, nil, fly_by_prefabs, nil, NetworkType_HostAuth)
	, Prefab("owlitzer_fly_by_left", fly_by_fn_left, nil, fly_by_prefabs, nil, NetworkType_HostAuth)
	, Prefab("owlitzer_super_flap_right", super_flap_fn_right, nil, super_flap_prefabs, nil, NetworkType_HostAuth)
	, Prefab("owlitzer_super_flap_left", super_flap_fn_left, nil, super_flap_prefabs, nil, NetworkType_HostAuth)