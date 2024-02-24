local SGCommon = require "stategraphs.sg_common"
local SGBossCommon = require "stategraphs.sg_boss_common"
local TargetRange = require "targetrange"
local monsterutil = require "util.monsterutil"
local bossutil = require "prefabs.bossutil"
local spawnutil = require "util.spawnutil"
local ParticleSystemHelper = require "util.particlesystemhelper"

local lume = require "util.lume"
local krandom = require "util.krandom"
local easing = require "util.easing"

local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local function OnSlashHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "slash_air",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.8,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnSlash2HitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "slash2_air",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 1.4,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnWindGustHitBoxTriggered(inst, data)
	if inst.sg.statemem.is_wind_gust then
		return
	end

	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "wind_gust",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 2.0,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnSnatchHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "snatch",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 2.0,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnDiveSlamHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "dive_bomb",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 2.0,
		set_dir_angle_to_target = true,
		hitflags = inst.sg.statemem.is_ground_attack and Attack.HitFlags.LOW_ATTACK or Attack.HitFlags.DEFAULT,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnDiveBombHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "dive_bomb",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 2.0,
		set_dir_angle_to_target = true,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnFlyByHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "fly_by",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 2.0,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnGetOffMeHitBoxTriggered(inst, data)
	if inst.sg.statemem.is_wind_gust then
		return
	end

	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "phase_transition_get_off_me",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 2.0,
		set_dir_angle_to_target = true,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnDodgingHitBoxTriggered(inst, data)
	-- Stop moving if the hitbox hits a trap.
	for _, target in ipairs(data.targets) do
		if target:HasTag("trap") then
			inst.Physics:Stop()
		end
	end
end

local function RemoveStatusEffects(inst)
	inst.components.powermanager:ResetData()
	inst.components.powermanager:SetCanReceivePowers(false)
end

local MELEE_RANGE = 6

local events =
{
	EventHandler("specialmovement", function(inst, target)
		local trange = TargetRange(inst, target)

		-- Dash toward target. Different state depending on facing angle to target.
		if trange:IsOutOfRange(MELEE_RANGE) then
			SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "fly_dash", target)
		end
	end),

	EventHandler("getup", function(inst)
		local duration = inst.sg.mem.knockdown_duration or inst.components.combat:GetKnockdownDuration()
		inst.components.combat:SetKnockdownDuration(duration)
	end),

	EventHandler("divebomb", function(inst)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.FaceActionTarget(inst, target, true)
		end
		bossutil.DoEventTransition(inst, "dive_bomb_pre")
		soundutil.PlayCodeSound(inst, fmodtable.Event.Mus_Owlitzer_SwoopStinger_Dive)
	end),

	EventHandler("superflap", function(inst)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.FaceActionTarget(inst, target, true)
		end
		bossutil.DoEventTransition(inst, "float_to_super_flap_pre")
	end),

	EventHandler("barf", function(inst)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.FaceActionTarget(inst, target, true)
		end
		bossutil.DoEventTransition(inst, "float_to_barf_pre")
	end),

	EventHandler("do_phase_change", function(inst)
		if inst.sg:HasStateTag("knockdown") then
			inst.sg:GoToState("phase_transition_pre_getup")
		elseif inst.sg:GetCurrentState() == "super_flap_to_float_pre" then
			-- Owlitzer is already super flapping, do another transition
			inst.sg:GoToState("float_to_super_flap_pre", true)
			inst.boss_coro:SetMusicPhase(inst.boss_coro.phase + 1) -- manually incrementing because .phase is happening on a delay
		else
			inst.sg:GoToState("phase_transition_pre_fly")
		end
	end),

	-- Handlers if teleported while moving to a point/target
	EventHandler("teleport_start", function(inst)
		if inst.sg.statemem.movetotask then
			inst.sg.statemem.movetotask:Cancel()
			inst.sg.statemem.movetotask = nil
		end
	end),

	EventHandler("death", function(inst)
		-- Only cleans up possible lingering FX.
		-- Actual death flow is done through the death event handler in AddBossCommonEvents

		if inst.sg.mem.target_indicator then
			inst.sg.mem.target_indicator:PushEvent("done_attack")
			inst.sg.mem.target_indicator = nil
		end

		if inst.sg.mem.fly_by_fx then
			inst.sg.mem.fly_by_fx:DespawnFX()
			inst.sg.mem.fly_by_fx = nil
		end

	end),
}
monsterutil.AddBossCommonEvents(events)
-- Disabled for now until anims are tweaked. Use when all players dead.
--[[monsterutil.AddOptionalMonsterEvents(events,
{
	idlebehavior_fn = ChooseIdleBehavior,
})]]

local SNATCH_SPEED = 40

local BARF_TIMES = 1
local MAX_BARF_BALLS = 30
local NUM_BALLS_PER_BARF =
{
	12,
	12,
	12,
	12,
}
local MAX_BARF_DISTANCE = 16

local FLY_BY_WARN_TIME = 3

local LEFT_PERCENT, RIGHT_PERCENT = -0.5, 1.5

local PHASE_TRANSITION_DAMAGE_REDUCTION = 0

local states =
{
	State({
		name = "introduction",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, attack_fn)
			inst.AnimState:PlayAnimation("intro1")
			inst.sg.statemem.start_pos = inst:GetPosition()
		end,

		events =
		{
			EventHandler("cine_skipped", function(inst)
				local pos = inst.sg.statemem.start_pos
				inst.Transform:SetPosition(pos.x, pos.y, pos.z) -- Bandicoot appears 9.6 units from the starting point at the end of the animation.
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "introduction2",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, attack_fn)
			inst.AnimState:PlayAnimation("intro2")
		end,
	}),

	State({
		name = "float_pre",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("float_pre")
		end,

		timeline =
		{
			FrameEvent(13, function(inst)
				inst.sg:AddStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "float_pst",
		tags = { "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("float_pst")
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	-- Dash
	State({
		name = "fly_dash",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, target)
			local direction = SGCommon.Fns.GetSpecialMovementDirection(inst, target)
			local anim = (direction == SGCommon.SPECIAL_MOVEMENT_DIR.UP and "fly_dash_above") or
						(direction == SGCommon.SPECIAL_MOVEMENT_DIR.DOWN and "fly_dash_below") or
						"fly_dash_forward"
			inst.AnimState:PlayAnimation(anim)
			inst.components.hitbox:StartRepeatTargetDelay()

			inst.sg.statemem.target = target
		end,

		timeline =
		{
			-- FrameEvent(3, function(inst) inst.SoundEmitter:PlaySound(fmodtable.Event.owlitzer_faster_move) end),
			FrameEvent(4, function(inst)
				inst.Physics:StartPassingThroughObjects()
				inst.sg.mem.is_dodging = true

				-- Move right in front of the target
				if inst.sg.statemem.target then
					local facing = inst.Transform:GetFacing() == FACING_LEFT and 1 or -1
					inst.sg.statemem.movetotask = SGCommon.Fns.MoveToTarget(inst, { target = inst.sg.statemem.target, offset = Vector3.unit_x * 2 * facing, duration = 10 * ANIM_FRAMES / SECONDS })
				end
			end),
			FrameEvent(20, function(inst)
				inst.sg.mem.is_dodging = nil
				inst.Physics:Stop()
			end),
		},

		onupdate = function(inst)
			-- Stop before it hits a thorns trap
			if inst.sg.mem.is_dodging then
				inst.components.hitbox:PushOffsetBeam(0.00, 4.00, 4.00, 0.50, HitPriority.BOSS_DEFAULT)
			end
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnDodgingHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.sg.mem.is_dodging = nil
		end,
	}),

	State({
		name = "phase_transition_pre_getup",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("phase_transition_pre_getup")
		end,

		timeline =
		{
			FrameEvent(14, function(inst)
				inst.sg:AddStateTag("flying")
			end),

			FrameEvent(26, function(inst)
				inst.sg:RemoveStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("phase_transition")
			end),
		},
	}),

	State({
		name = "phase_transition_pre_fly",
		tags = { "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("phase_transition_pre_fly")
			inst.Physics:Stop()
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("phase_transition")
			end),
		},
	}),

	State({
		name = "phase_transition",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("phase_transition")
			inst.boss_coro:SetMusicPhase(inst.boss_coro.phase + 1) -- manually incrementing because .phase is happening on a delay
			RemoveStatusEffects(inst)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				-- Face towards the center of the map:
				local center_pt = spawnutil.GetStartPointFromWorld(0.5, 0.5)
				SGCommon.Fns.TurnAndActOnLocation(inst, center_pt.x, center_pt.z, true, "phase_transition_leap", center_pt)
			end),
		},
	}),

	State({
		name = "phase_transition_leap",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, target_pos)
			inst.AnimState:PlayAnimation("phase_transition_leap")

			local leap_frames = 25 - 10
			local distance = inst:GetDistanceSqToPoint(target_pos)
			inst.sg.statemem.leap_speed = math.sqrt(distance)/(leap_frames/30)
		end,

		timeline =
		{
			FrameEvent(10, function(inst)
				inst.sg:AddStateTag("flying")
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.leap_speed)
			end),
			FrameEvent(25, function(inst)
				inst.sg:RemoveStateTag("flying")
				inst.Physics:Stop()
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("phase_transition_get_off_me_pre")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end,
	}),

	State({
		name = "phase_transition_get_off_me",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("phase_transition_get_off_me")
			inst.components.combat:SetDamageReceivedMult("phase_transition", PHASE_TRANSITION_DAMAGE_REDUCTION)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.hitbox:SetHitFlags(HitGroup.ALL)
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 3.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 5.50, HitPriority.BOSS_DEFAULT)
				inst.components.hitbox:StopRepeatTargetDelay()
				inst.components.combat:RemoveDamageReceivedMult("phase_transition")
			end),
			FrameEvent(6, function(inst)
				inst.components.auraapplyer:SetEffect("owlitzer_transition_attack")
				inst.components.auraapplyer:SetRadius(100)
				inst.components.auraapplyer:Enable()
				inst.sg.statemem.is_wind_gust = true
			end),
			FrameEvent(18, function(inst)
				inst.components.auraapplyer:Disable()
			end),
			FrameEvent(27, function(inst)
				inst.sg:AddStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnGetOffMeHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("float_to_super_flap", true)
			end),
		},

		onexit = function(inst)
			inst.components.combat:RemoveDamageReceivedMult("phase_transition")
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.auraapplyer:Disable()
			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)
		end,
	}),


	-- Attacks
	State({
		name = "slash_air",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("slash_air")
			SGCommon.Fns.SetMotorVelScaled(inst, 15)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushOffsetBeam(3.50, 7.00, 2.00, 0.50, HitPriority.BOSS_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0.50, 3.50, 1.50, 0.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.Physics:Stop()
				inst.components.hitbox:PushOffsetBeam(2.50, 6.00, 2.50, 0.50, HitPriority.BOSS_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(0.50, 2.50, 1.50, 0.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushOffsetBeam(2.00, 5.50, 2.50, 0.50, HitPriority.BOSS_DEFAULT)
				inst.components.hitbox:PushBeam(0.50, 2.00, 1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushOffsetBeam(1.50, 4.50, 2.50, 0.50, HitPriority.BOSS_DEFAULT)
				inst.components.hitbox:PushBeam(0.50, 1.50, 1.50, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSlashHitBoxTriggered),
			EventHandler("animover", function(inst)
				local target = inst.components.combat:GetTarget()
				if target then
					--[[local trange = TargetRange(inst, target)
					if trange:IsFacingTarget() and trange:TestCone45(0, 10, 4) then]]
						SGCommon.Fns.FaceTarget(inst, target, true)
						inst.sg:GoToState("slash2_air_pre")
					--[[else
						inst.sg:GoToState("slash_pst")
					end]]
				else
					inst.sg:GoToState("slash_pst")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "slash_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("slash_pst")
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, 6)
				inst.sg:AddStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.Physics:Stop()
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "slash2_air",
		tags = { "attack", "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("slash2_air")
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(30) end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushOffsetBeam(-3.50, -0.50, 2.00, 0.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(-2.50, 1.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(1.00, 5.50, 1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushOffsetBeam(3.00, 5.50, 1.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushOffsetBeam(3.00, 5.50, 1.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(10) end),
			FrameEvent(15, function(inst) inst.Physics:Stop() end),
			FrameEvent(19, function(inst) inst.Physics:SetMotorVel(5) end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSlash2HitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "turn_fly_forward_ground",
		tags = { "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("turn_fly_forward_ground")
			inst.Physics:StartPassingThroughObjects()
			inst.components.hitbox:StartRepeatTargetDelay()

			inst.sg.statemem.target = inst.components.combat:GetTarget()
		end,

		timeline =
		{
			-- FrameEvent(4, function(inst) inst.SoundEmitter:PlaySound(fmodtable.Event.owlitzer_faster_move) end),
			FrameEvent(5, function(inst)
				inst.sg.mem.is_dodging = true
				if inst.sg.statemem.target then
					local facing = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
					inst.sg.statemem.movetotask = SGCommon.Fns.MoveToTarget(inst, { target = inst.sg.statemem.target, offset = Vector3.unit_x * 10 * facing, duration = 11 * ANIM_FRAMES / SECONDS })
				end
			end),


			FrameEvent(16, function(inst)
				inst.sg.mem.is_dodging = nil
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("flying")
			end),
		},

		onupdate = function(inst)
			-- Stop before it hits a thorns trap
			if inst.sg.mem.is_dodging then
				inst.components.hitbox:PushOffsetBeam(0.00, 4.00, 4.00, 0.50, HitPriority.BOSS_DEFAULT)
			end
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnDodgingHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("wind_gust_pre")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.sg.mem.is_dodging = nil

			if inst.sg.statemem.target then
				SGCommon.Fns.FaceTarget(inst, inst.sg.statemem.target, true)
			end
		end,
	}),

	State({
		name = "fly_back_ground",
		tags = { "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("fly_back_ground")
			inst.Physics:StartPassingThroughObjects()
			inst.components.hitbox:StartRepeatTargetDelay()

			inst.sg.statemem.target = inst.components.combat:GetTarget()
		end,

		timeline =
		{
			-- FrameEvent(4, function(inst) inst.SoundEmitter:PlaySound(fmodtable.Event.owlitzer_faster_move) end),
			FrameEvent(5, function(inst)
				inst.sg.mem.is_dodging = true
				if inst.sg.statemem.target then
					local facing = inst.Transform:GetFacing() == FACING_LEFT and 1 or -1
					inst.sg.statemem.movetotask = SGCommon.Fns.MoveToTarget(inst, { target = inst.sg.statemem.target, offset = Vector3.unit_x * 16 * facing, duration = 11 * ANIM_FRAMES / SECONDS })
				end
			end),

			FrameEvent(16, function(inst)
				inst.sg.mem.is_dodging = nil
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("flying")
			end),
		},

		onupdate = function(inst)
			-- Stop before it hits a thorns trap
			if inst.sg.mem.is_dodging then
				inst.components.hitbox:PushOffsetBeam(0.00, 4.00, 4.00, 0.50, HitPriority.BOSS_DEFAULT)
			end
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnDodgingHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("wind_gust_pre")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.sg.mem.is_dodging = nil
		end,
	}),

	State({
		name = "wind_gust",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("wind_gust")
			--inst.components.hitbox:StartRepeatTargetDelayAnimFrames(1)
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushOffsetBeam(0.00, 5.50, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			--[[FrameEvent(4, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.00, 5.50, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.00, 5.50, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),]]

			FrameEvent(4, function(inst)
				inst.components.auraapplyer:SetEffect("owlitzer_wind_gust")
				inst.components.auraapplyer:SetupBeamHitbox(1, 40, 5)
				inst.components.auraapplyer:Enable()
				inst.sg.statemem.is_wind_gust = true

				inst.components.hitbox:SetHitFlags(HitGroup.ALL)
			end),

			FrameEvent(16, function(inst)
				inst.components.auraapplyer:Disable()
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnWindGustHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("wind_gust_fly_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.auraapplyer:Disable()
			inst.sg.statemem.is_wind_gust = false
		end,
	}),

	State({
		name = "wind_gust_fly_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("wind_gust_fly_pst")
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "snatch",
		tags = { "attack", "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("snatch")
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
			local target = inst.components.combat:GetTarget()
			SGCommon.Fns.FaceTarget(inst, target, true)
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				inst.Physics:SetMotorVel(SNATCH_SPEED)
			end),
			FrameEvent(11, function(inst)
				inst.Physics:SetMotorVel(SNATCH_SPEED * 0.3)
			end),
			FrameEvent(12, function(inst)
				inst.Physics:SetMotorVel(SNATCH_SPEED * 0.1)
			end),
			FrameEvent(15, function(inst)
				inst.Physics:Stop()
			end),

			FrameEvent(3, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.80, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.80, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(11, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 1.9, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 1.9, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSnatchHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "dive_slam",
		tags = { "attack", "busy", "flying_high", "nointerrupt" },

		default_data_for_tools = function(inst)
			inst.sg.mem.dive_fx_list = {}
		end,

		onenter = function(inst)
			local target = inst.components.combat:GetTarget()
			SGCommon.Fns.FaceTarget(inst, target, true)

			inst.AnimState:PlayAnimation("dive_slam")
			inst.Physics:StartPassingThroughObjects()
			inst.Physics:SetEnabled(false)
			inst.HitBox:SetEnabled(false)
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				inst.Physics:Stop()
				inst.Physics:StopPassingThroughObjects()
				inst.Physics:SetEnabled(false)
				inst.sg:RemoveStateTag("flying_high")

				--RemoveLandFX(inst)
			end),

			FrameEvent(4, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.sg.statemem.is_ground_attack = true
				inst.components.hitbox:PushCircle(0.00, 0.00, 4.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 6.00, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnDiveSlamHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:SetEnabled(true)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.HitBox:SetEnabled(true)

			--RemoveLandFX(inst)
		end,
	}),

	State({
		name = "dive_bomb",
		tags = { "attack", "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("dive_bomb")
			--SGCommon.Fns.SetMotorVelScaled(inst, 15)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.Physics:StartPassingThroughObjects()
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)

			-- Set position so that it ends up at the target position.
			local targetpos = inst.sg.mem.dive_pos or Vector3.zero
			local x, y, z = targetpos:Get()
			local facing = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
			inst.Transform:SetPosition(x - (17.4 * facing), y, z) -- x-offset derived from adding the MoveRelFacing values below.
			inst:SnapToFacingRotation() -- Need to snap to facing rotation to get it to move in a straight line.
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushBeam(0.00, 3.50, 2.50, HitPriority.BOSS_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(-2.00, 0.00, 1.50, 0.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushBeam(-1.50, 5.50, 2.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.HitBox:SetInvincible(false)
				inst.HitBox:SetEnabled(true)
				inst.components.hitbox:PushBeam(0.00, 5.50, 2.50, HitPriority.BOSS_DEFAULT)

				if inst.sg.mem.target_indicator then
					inst.sg.mem.target_indicator:PushEvent("done_attack")
					inst.sg.mem.target_indicator = nil
				end
			end),

			-- Code Generated by PivotTrack.jsfl (slight modifications made to avoid crashing due to going over the 300 pixel/frame limit.)
			--[[FrameEvent(1, function(inst) inst.Physics:MoveRelFacing(247/150) end),
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(247/150) end),
			FrameEvent(3, function(inst) inst.Physics:MoveRelFacing(247/150) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(247/150) end),
			FrameEvent(5, function(inst) inst.Physics:MoveRelFacing(247/150) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(230/150) end),
			FrameEvent(7, function(inst) inst.Physics:MoveRelFacing(260/150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(295/150) end),
			FrameEvent(9, function(inst) inst.Physics:MoveRelFacing(300/150) end),
			FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(290/150) end),]]
			-- End Generated Code

			FrameEvent(1, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 49) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 46) end),
			FrameEvent(7, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 52) end),
			FrameEvent(8, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 59) end),
			FrameEvent(9, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 60) end),
			FrameEvent(10, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 58) end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnDiveBombHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("dive_bomb_miss")
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:Stop()
		end,
	}),

	State({
		name = "dive_bomb_miss",
		tags = { "busy", "nointerrupt", "knockdown", "vulnerable" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("dive_bomb_miss")
			inst.Physics:StartPassingThroughObjects()
			inst.components.hitbox:StartRepeatTargetDelay()

			inst:SnapToFacingRotation()
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.00, 5.50, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(1, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.00, 5.50, 3.00, 1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(2, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.00, 5.50, 3.00, 1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.00, 4.50, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.00, 4.50, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.50, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.50, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.50, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.50, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.50, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.50, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(11, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.50, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushBeam(-2.00, 3.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(13, function(inst)
				inst.components.hitbox:PushBeam(-2.00, 3.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				inst.components.hitbox:PushBeam(-2.00, 3.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(15, function(inst)
				inst.components.hitbox:PushBeam(-2.00, 3.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(16, function(inst)
				inst.components.hitbox:PushBeam(-2.00, 3.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(17, function(inst)
				inst.components.hitbox:PushBeam(-2.00, 3.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),

			-- Code Generated by PivotTrack.jsfl
			--[[FrameEvent(1, function(inst) inst.Physics:MoveRelFacing(100/150) end),
			FrameEvent(3, function(inst) inst.Physics:MoveRelFacing(230/150) end),
			FrameEvent(5, function(inst) inst.Physics:MoveRelFacing(273/150) end),
			FrameEvent(7, function(inst) inst.Physics:MoveRelFacing(272/150) end),
			FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(300/150) end),
			FrameEvent(12, function(inst) inst.Physics:MoveRelFacing(168/150) end),
			FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(107/150) end),
			FrameEvent(17, function(inst) inst.Physics:MoveRelFacing(170/150) end),
			FrameEvent(20, function(inst) inst.Physics:MoveRelFacing(96/150) end),
			FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(80/150) end),]]
			-- End Generated Code

			FrameEvent(1, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 10) end),
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 23) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 28) end),
			FrameEvent(7, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 29) end),
			FrameEvent(10, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 30) end),
			FrameEvent(12, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 13) end),
			FrameEvent(14, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 10) end),
			FrameEvent(17, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 7) end),
			FrameEvent(20, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4) end),
			FrameEvent(22, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(24, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 0) end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnDiveBombHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.Physics:Stop()
				inst.Transform:FlipFacingAndRotation() -- Animation ends up facing backwards, so need to flip to match knockdown_idle's anim facing.

				-- Save & reload the knockdown duration after knockdown
				inst.sg.mem.knockdown_duration = inst.components.combat:GetKnockdownDuration() -- Gets reset from the "getup" event handler.
				inst.components.combat:SetKnockdownDuration(4 + math.random() * 2 - 1)
				inst.components.timer:StartTimer("knockdown", inst.components.combat:GetKnockdownDuration(), true)
				inst.sg:GoToState("knockdown_idle")
				inst.sg.statemem.knockdown = true -- Need to set this to remain in knockdown_idle for knockdown duration!
			end),
		},

		onexit = function(inst)
			inst:PushEvent("divebomb_over")
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	--[[State({
		name = "dive_bomb_hit",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("dive_bomb_hit")
		end,

		timeline =
		{
			-- Code Generated by PivotTrack.jsfl
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(300/150) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(206/150) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(198/150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(180/150) end),
			FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(128/150) end),
			FrameEvent(11, function(inst) inst.Physics:MoveRelFacing(92/150) end),
			FrameEvent(13, function(inst) inst.Physics:MoveRelFacing(126/150) end),
			-- End Generated Code

			FrameEvent(13, function(inst) inst.Physics:Stop() end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("laugh_pre")
			end),
		},

		onexit = function(inst)
			inst:PushEvent("divebomb_over")
			inst.Physics:Stop()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),]]

	State({
		name = "laugh_pre",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("laugh_pre")
			local target = inst.components.combat:GetTarget()
			SGCommon.Fns.FaceTarget(inst, target, true)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("laugh_loop")
			end),
		},
	}),

	State({
		name = "laugh_loop",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("laugh_loop", true)
			inst.sg:SetTimeout(2)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("laugh_pst")
		end,
	}),

	State({
		name = "laugh_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("laugh_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "float_to_barf_pre",
		tags = { "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.Physics:Stop()
			inst.AnimState:PlayAnimation("float_pst")
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("barf_pre")
			end),
		},
	}),

	State({
		name = "barf_pre",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("barf_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				local num_loops = BARF_TIMES--inst.sg.mem.lowhealth and BARF_TIMES * 2 or BARF_TIMES
				inst.sg:GoToState("barf_loop", num_loops)
			end),
		},
	}),

	State({
		name = "barf_loop",
		tags = { "busy", "nointerrupt" },

		default_data_for_tools = function(inst, cleanup)
			return 1
		end,

		onenter = function(inst, loops)
			inst.AnimState:PlayAnimation("barf_loop")
			inst.sg.statemem.loops = loops or 1
		end,

		timeline =
		{
			FrameEvent(15, function(inst)
				-- Spawn spike balls. Do not spawn more than the limit!
				local spikeballs = TheSim:FindEntitiesXZ(0, 0, 1000, { "spikeball" })
				local num_spikeballs_on_map = spikeballs and #spikeballs or 0

				local num_balls_to_spawn = math.min(MAX_BARF_BALLS - num_spikeballs_on_map, NUM_BALLS_PER_BARF[#AllPlayers])
				local anglediff = 360 / num_balls_to_spawn
				local current_angle = 0
				for i = 1, num_balls_to_spawn do
					local ball = SpawnPrefab("owlitzer_spikeball")
					ball:Setup(inst)
					local x, z = inst:GetPosition():GetXZ()
					local facing = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
					ball.Transform:SetPosition(x + 0.5 * facing, 5, z)

					local distance = math.max(math.random() * MAX_BARF_DISTANCE, 3)
					local pos = inst:GetPosition()
					local target_pos = pos + Vector3(math.cos(math.rad(current_angle)), 0, -math.sin(math.rad(current_angle))) * distance
					if not TheWorld.Map:IsGroundAtPoint(target_pos) then
						target_pos = TheWorld.Map:FindClosestPointOnWalkableBoundary(target_pos)
					end
					ball.sg:GoToState("thrown", target_pos)

					current_angle = current_angle + anglediff + math.random() * 10 - 5

					--[[if inst.sg.mem.lowhealth then
						ball.components.powermanager:RemoveIgnorePower("owlitzer_super_flap")
					end]]
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.loops > 1 then
					inst.sg:GoToState("barf_loop", inst.sg.statemem.loops - 1)
				else
					inst.sg:GoToState("barf_pst")
				end
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "barf_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("barf_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("float_pre")
			end),
		},

		onexit = function(inst)
			inst:PushEvent("barf_over")
		end
	}),

	State({
		name = "float_to_super_flap_pre",
		tags = { "busy", "nointerrupt", "flying" },

		onenter = function(inst, skip_wait)
			inst.sg.statemem.skip_wait = skip_wait
			inst.Physics:Stop()
			inst.AnimState:PlayAnimation("return_fly")
			TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Owlitzer_IsFlapping", .5)
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				inst.HitBox:SetInvincible(true)
				inst.HitBox:SetEnabled(false)
				inst.sg:AddStateTag("flying_high")

				RemoveStatusEffects(inst)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("float_to_super_flap", inst.sg.statemem.skip_wait)
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
		end,
	}),

	State({
		name = "float_to_super_flap",
		tags = { "busy", "nointerrupt", "flying_high" },

		onenter = function(inst, skip_wait)
			inst.AnimState:PlayAnimation("float_idle", true)
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)

			inst.Physics:SetSnapToGround(false)
			inst.Physics:SetEnabled(false)

			-- Teleport to either the left or right side of the map. Go to the side with less spike balls if possible.
			local midpoint = spawnutil.GetStartPointFromWorld(0.5, 0.5)
			local spikeballs = TheSim:FindEntitiesXZ(0, 0, 1000, { "spikeball" })
			local left_side_balls = 0
			local right_side_balls = 0
			for _, ball in ipairs(spikeballs) do
				local x, y, z = ball:GetPosition():Get()
				if x < midpoint.x then
					left_side_balls = left_side_balls + 1
				else
					right_side_balls = right_side_balls + 1
				end
			end

			local left_side = 0
			if left_side_balls == right_side_balls then
				local rng = krandom.CreateGenerator()
				left_side = rng:Boolean() and 0 or 1
			else
				left_side = left_side_balls > right_side_balls and 0 or 1
			end

			local teleport_pt = spawnutil.GetStartPointFromWorld(left_side, 0.65) + Vector3.unit_y * 15
			inst.Transform:SetPosition(teleport_pt:Get())

			-- Face towards the center of the map.
			local facing_left = inst.Transform:GetFacing() == FACING_LEFT
			if left_side == 0 and facing_left or
				left_side == 1 and not facing_left then
					inst.Transform:FlipFacingAndRotation()
			end

			-- Move to target point.
			local target_pos = Vector3(teleport_pt.x, 5, teleport_pt.z)
			inst.sg.statemem.movetotask = SGCommon.Fns.MoveToPoint(inst, target_pos, 1)
			inst.sg:SetTimeoutAnimFrames(150)

			inst.sg.statemem.skip_wait = skip_wait
		end,

		ontimeout = function(inst)
			TheLog.ch.StateGraph:printf("Warning: Owlitzer state %s timed out.", inst.sg.currentstate.name)
			inst.sg:GoToState("super_flap_pre") -- TODO: someone, super_flap_wait?
		end,

		events =
		{
			EventHandler("movetopoint_complete", function(inst)
				if inst.sg.statemem.skip_wait then
					inst.sg:GoToState("super_flap_pre")
				else
					inst:PushEvent("super_flap_wait")
					inst.sg:GoToState("super_flap_wait")
				end
			end),

			EventHandler("do_super_flap", function(inst)
				inst.sg:GoToState("super_flap_pre")
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.movetotask then
				inst.sg.statemem.movetotask:Cancel()
				inst.sg.statemem.movetotask = nil
			end
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
			inst.Physics:SetEnabled(true)
		end,
	}),

	State({
		name = "super_flap_wait",
		tags = { "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("float_idle", true)
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
		end,

		events =
		{
			EventHandler("do_super_flap", function(inst)
				inst.sg:GoToState("super_flap_pre")
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
		end,
	}),

	State({
		name = "super_flap_pre",
		tags = { "attack", "busy", "nointerrupt", "flying_high" },

		onenter = function(inst, pattern)
			inst.AnimState:PlayAnimation("super_flap_pre")
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
			inst.sg.statemem.pattern = pattern
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("super_flap_loop", inst.sg.statemem.pattern)
			end),
		},

		timeline =
		{
			FrameEvent(1, function(inst)
				inst.sg.mem.wind_sound = soundutil.PlayCodeSound(
					inst,
					fmodtable.Event.owlitzer_super_flap_LP,
					{
						max_count = 1,
						is_autostop = true,  -- stop the sound when the thing's destroyed
						stopatexitstate = true, -- TODO(luca): stopatexitstate is for PlayCountedSound?
						fmodparams = {
							Music_BossPhase = inst.boss_coro.phase,
						},
					})
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
			-- inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)
		end,
	}),

	State({
		name = "super_flap_loop",
		tags = { "attack", "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
			inst.AnimState:PlayAnimation("super_flap_loop", true)
			TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Owlitzer_IsFlapping", 1)
			inst.components.hitbox:SetHitFlags(HitGroup.ALL)

			local fallback_pattern =
			{
				"xxxxxx-----",
				"-----xxxxxx",
				"xxxxxx-----",
				"-----xxxxxx",
				"xxxxxx-----",
			}

			local pattern = inst.boss_coro:GetSuperFlapPattern() or fallback_pattern -- what pattern to use
			local spawn_lines = inst.components.patternspawner:GetSpawnPositionsForPattern(pattern) -- convert to something usable

			local pos = inst:GetPosition()
			local spawn_pos = spawnutil.GetStartPointFromWorld(inst.Transform:GetFacing() == FACING_LEFT and 0.73 or 0.27, .075)

			local spike_line_interval = 1.5 -- time between spike lines
			local num_lines_spawned = 0 -- how many lines have spawned
			local num_spike_lines = #pattern -- how many lines will spawn
			local super_flap_time = ((num_spike_lines + 1) * spike_line_interval) -- how long the spawning will take
			inst.sg:SetTimeout(super_flap_time)

			local function _spawn_spike_line()
				num_lines_spawned = num_lines_spawned + 1

				for _, offset in ipairs(spawn_lines[num_lines_spawned]) do
					local spikeball = SGCommon.Fns.SpawnAtDist(inst, "owlitzer_spikeball", 0)
					if spikeball then
						spikeball.Transform:SetPosition(pos.x, pos.y + 1, pos.z) -- Set so the spikeball's y-position is set to be the same as Owlitzer's
						local target_pos = spawn_pos + offset
						spikeball.sg:GoToState("thrown", target_pos)
					end
				end

				if num_lines_spawned < num_spike_lines then
					inst:DoTaskInTime(spike_line_interval, _spawn_spike_line)
				end
			end

			_spawn_spike_line()


			local facing_left = inst.Transform:GetFacing() == FACING_LEFT
			local fx_point = spawnutil.GetStartPointFromWorld(facing_left and 1 or 0, 0.5)

			if facing_left then
				inst.sg.mem.super_flap_fx = SpawnPrefab("owlitzer_super_flap_left")
			else
				inst.sg.mem.super_flap_fx = SpawnPrefab("owlitzer_super_flap_right")
			end

			inst.sg.mem.super_flap_fx.Transform:SetPosition(fx_point:Get())
			inst.sg.mem.super_flap_fx:SpawnFX()
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("super_flap_pst")
		end,

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)

			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)

			if inst.sg.mem.wind_sound then
				soundutil.KillSound(inst, inst.sg.mem.wind_sound)
				inst.sg.mem.wind_sound = nil
			end

			inst.sg.mem.super_flap_fx:DespawnFX()
		end,
	}),

	State({
		name = "super_flap_pst",
		tags = { "attack", "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
			inst.AnimState:PlayAnimation("super_flap_pst")
			if inst.sg.mem.wind_sound then
				soundutil.KillSound(inst, inst.sg.mem.wind_sound)
				inst.sg.mem.wind_sound = nil
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Owlitzer_IsFlapping", 0)
				if inst.sg.mem.doflyby then
					inst.sg:GoToState("super_flap_to_fly_by")
				else
					inst.sg:GoToState("super_flap_to_float_pre")
				end
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
			inst.components.attacktracker:CompleteActiveAttack()
			inst:PushEvent("superflap_over")
			if inst.sg.mem.wind_sound then
				soundutil.KillSound(inst, inst.sg.mem.wind_sound)
				inst.sg.mem.wind_sound = nil
			end
		end,
	}),

	State({
		name = "super_flap_to_float_pre",
		tags = { "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
			inst.AnimState:PlayAnimation("return_fly")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("fly_high_to_float")
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
		end,
	}),

	State({
		name = "super_flap_to_fly_by",
		tags = { "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
			inst.AnimState:PlayAnimation("fly_by_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("fly_by_pre")
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
		end,
	}),

	State({
		name = "fly_by_pre",
		tags = { "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
			inst.sg:SetTimeout(FLY_BY_WARN_TIME)

			-- Select a random target.
			local target = inst:GetRandomEntityByTagInRange(1000, inst.components.combat:GetTargetTags(), true, true)

			if not target then
				inst.sg:GoToState("super_flap_to_float_pre")
				return
			end

			inst.components.combat:SetTarget(target)

			-- Teleport to either the left or right side of the map, and aligned with the target's position.
			local target_pos = target:GetPosition()

			local rng = krandom.CreateGenerator()
			inst.sg.mem.teleport_x = rng:Boolean() and LEFT_PERCENT or RIGHT_PERCENT

			-- Face towards the opposite side of the map.
			local facing_left = inst.Transform:GetFacing() == FACING_LEFT
			if inst.sg.mem.teleport_x == LEFT_PERCENT and facing_left or
				inst.sg.mem.teleport_x == RIGHT_PERCENT and not facing_left then
				inst.Transform:FlipFacingAndRotation()
			end

			facing_left = inst.Transform:GetFacing() == FACING_LEFT -- we might have flipped, so update this

			-- spawn fly by FX
			local fx_point = spawnutil.GetStartPointFromWorld(facing_left and 1 or 0, 0)
			fx_point.z = target_pos.z

			if facing_left then
				inst.sg.mem.fly_by_fx = SpawnPrefab("owlitzer_fly_by_left")
			else
				inst.sg.mem.fly_by_fx = SpawnPrefab("owlitzer_fly_by_right")
			end

			inst.sg.mem.fly_by_fx.Transform:SetPosition(fx_point:Get())
			inst.sg.mem.fly_by_fx:SpawnFX()

			inst.sg.mem.target_indicator = SGCommon.Fns.SpawnAtDist(target, "owlitzer_target", 0)
			--sound
			local params = {}
			params.fmodevent = fmodtable.Event.owlitzer_targetLock_LP
			params.sound_max_count = 1
			params.is_autostop = 1
			inst.sg.statemem.warningsound = soundutil.PlaySoundData(inst.sg.mem.target_indicator, params)
		end,

		onupdate = function(inst)
			local target = inst.components.combat:GetTarget()

			if not target then return end

			local fx_pos = inst.sg.mem.fly_by_fx:GetPosition()
			local targeting_pos = inst.sg.mem.target_indicator:GetPosition()

			local t_pos = target:GetPosition()

			local ease_fn = easing.linear
			local progress = 0.05

			local x = ease_fn(progress, targeting_pos.x, t_pos.x - targeting_pos.x, 1)
			local z = ease_fn(progress, targeting_pos.z, t_pos.z - targeting_pos.z, 1)

			inst.sg.mem.fly_by_fx.Transform:SetPosition(fx_pos.x, 0, z) -- for the FX, we only want to update the Z
			inst.sg.mem.target_indicator.Transform:SetPosition(x, 0, z)

			local warning_progress = inst.sg:GetTimeInState()/FLY_BY_WARN_TIME
			if inst.sg.statemem.warningsound then
				soundutil.SetInstanceParameter(inst.sg.mem.target_indicator, inst.sg.statemem.warningsound,"owlitzer_lockOn_progress", warning_progress)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("fly_by_loop")
		end,

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)

			if inst.sg.mem.target_indicator then
				inst.sg.mem.target_indicator:PushEvent("lock_on")
				if inst.sg.statemem.warningsound then
					soundutil.SetInstanceParameter(inst.sg.mem.target_indicator, inst.sg.statemem.warningsound,"owlitzer_lockOn_progress", 1)
					soundutil.KillSound(inst, inst.sg.statemem.warningsound)
					inst.sg.statemem.warningsound = nil
				end
				local target_pos = inst.sg.mem.target_indicator:GetPosition()
				local teleport_pt = spawnutil.GetStartPointFromWorld(inst.sg.mem.teleport_x, 0)
				teleport_pt.z = target_pos.z
				inst.Transform:SetPosition(teleport_pt:Get())
			end
		end,
	}),

	State({
		name = "fly_by_loop",
		tags = { "busy", "nointerrupt", "flying_high" },

		default_data_for_tools = function(inst)
			inst.sg.mem.teleport_x = RIGHT_PERCENT
			inst.sg.mem.teleport_z = 0.5
		end,

		onenter = function(inst)
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
			inst.AnimState:PlayAnimation("fly_by_loop", true)

			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.hitbox:SetHitFlags(HitGroup.ALL)

			-- Fly across to the opposite side.
			local FLY_TIME = 1.5
			inst.sg:SetTimeout(FLY_TIME)

			local x2 = (inst.sg.mem.teleport_x == LEFT_PERCENT and RIGHT_PERCENT) or LEFT_PERCENT
			local target_pt = spawnutil.GetStartPointFromWorld(x2, 0) -- get an x position on the opposite side of the map
			local pos = inst:GetPosition()
			target_pt.z = pos.z -- should always fight straight across

			inst.sg.statemem.movetotask = SGCommon.Fns.MoveToPoint(inst, target_pt, FLY_TIME)

			-- Calculate velocity so that if we're teleported, resume at this velocity.
			local distance = math.abs((target_pt - inst:GetPosition()):Length())
			inst.sg.statemem.moveto_speed = distance / FLY_TIME

			---sound
			-- inst.SoundEmitter:PlaySound(fmodtable.Event.owlitzer_flyby)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnFlyByHitBoxTriggered),
			EventHandler("teleport_end", function(inst)
				-- If teleported, keep moving
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.moveto_speed)
			end),
		},

		onupdate = function(inst)
			inst.components.hitbox:PushBeam(-1.00, 3.00, 5.00, HitPriority.BOSS_DEFAULT)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("super_flap_to_float_pre")
		end,

		onexit = function(inst)
			if inst.sg.statemem.movetotask then
				inst.sg.statemem.movetotask:Cancel()
				inst.sg.statemem.movetotask = nil
			end

			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)

			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)
			inst.components.hitbox:StopRepeatTargetDelay()

			if inst.sg.mem.fly_by_fx then
				inst.sg.mem.fly_by_fx:DespawnFX()
				inst.sg.mem.fly_by_fx = nil
			end

			if inst.sg.mem.target_indicator then
				inst.sg.mem.target_indicator:PushEvent("done_attack")
				inst.sg.mem.target_indicator = nil
			end
		end,
	}),

	State({
		name = "fly_high_to_float",
		tags = { "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("float_idle", true)
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)

			inst.Physics:SetSnapToGround(false)
			inst.Physics:SetEnabled(false)

			-- Teleport to the center of the map above the origin.
			inst.Transform:SetPosition(0, 10, 0)
			local target = inst.components.combat:GetTarget()
			SGCommon.Fns.FaceTarget(inst, target, true)

			-- Move to target point.
			local target_pos = Vector3.zero
			inst.sg.statemem.movetotask = SGCommon.Fns.MoveToPoint(inst, target_pos, 0.5)
			inst.sg:SetTimeoutAnimFrames(150)
		end,

		ontimeout = function(inst)
			TheLog.ch.StateGraph:printf("Warning: Owlitzer state %s timed out.", inst.sg.currentstate.name)
			inst.sg:GoToState("idle")
		end,

		timeline =
		{
			FrameEvent(12, function(inst)
				inst.HitBox:SetInvincible(false)
				inst.HitBox:SetEnabled(true)
				inst.Physics:SetEnabled(true)
			end),
		},

		events =
		{
			EventHandler("movetopoint_complete", function(inst)
				inst.HitBox:SetInvincible(false)
				inst.HitBox:SetEnabled(true)
				inst.Physics:SetEnabled(true)
				inst.Physics:SetSnapToGround(true)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.movetotask then
				inst.sg.statemem.movetotask:Cancel()
				inst.sg.statemem.movetotask = nil
			end
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
			inst.Physics:SetEnabled(true)
			inst.Physics:SetSnapToGround(true)

			inst.components.powermanager:SetCanReceivePowers(true)
		end,
	}),
}


local FLYING_TAGS = { "flying" }
local nointerrupttags = { "nointerrupt" }

SGCommon.States.AddIdleStates(states,
{
	modifyanim = "float_",
	num_idle_behaviours = 2,
	addtags = FLYING_TAGS,
})

SGCommon.States.AddTurnStates(states,
{
	modifyanim = "fly_turn",
	addtags = FLYING_TAGS,

	onenterpst = function(inst)
		SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.walk_speed * 0.5)
	end
})
SGCommon.States.AddLocomoteStates(states, "fly",
{
	addtags = lume.concat(nointerrupttags, FLYING_TAGS),
	--[[loopevents =
	{
		EventHandler("walktorun",
			function(inst)
				inst.sg:GoToState("walk_to_run")
			end),
	},]]
})

SGCommon.States.AddHitStates(states, SGCommon.Fns.ChooseAttack, { modifyanim = "hit_air", addtags = FLYING_TAGS })
SGCommon.States.AddKnockbackStates(states, { modifyanim = "flinch_air", addtags = FLYING_TAGS })
SGCommon.States.AddKnockdownStates(states)
SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddAttackPre(states, "slash_air",
{
	alwaysforceattack = true,
	addtags = FLYING_TAGS,
	onenter_fn = function(inst)
		inst.Physics:Stop()
	end,
})
SGCommon.States.AddAttackHold(states, "slash_air", { alwaysforceattack = true, addtags = FLYING_TAGS })

SGCommon.States.AddAttackPre(states, "slash2_air", { alwaysforceattack = true })
SGCommon.States.AddAttackHold(states, "slash2_air", { alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "wind_gust",
{
	alwaysforceattack = true,
	onenter_fn = function(inst)
		inst.Physics:Stop()

		-- Check the positioning of owlitzer to its target & determine what state to play:
		local target = inst.components.combat:GetTarget()
		if target and not inst.sg.mem.in_position then
			local minx, minz, maxx, maxz = TheWorld.Map:GetWalkableBounds()
			local targetpos = target:GetPosition()
			local pos = inst:GetPosition()
			local is_left_side_closer = pos.x - minx < maxx - pos.x

			if is_left_side_closer then
				-- In between the side of the level & target; fly through the player & turn around.
				if (pos.x >= minx and pos.x <= targetpos.x) then
					inst.sg:GoToState("turn_fly_forward_ground", target)
				-- The target is in between owlitzer & the side of the level, but too close to the side; jump backwards.
				elseif (targetpos.x >= minx and targetpos.x <= pos.x) then
					inst.sg:GoToState("fly_back_ground", target)
				end
			else -- right side is closer
				if (pos.x <= maxx and pos.x >= targetpos.x) then
					inst.sg:GoToState("turn_fly_forward_ground", target)
				elseif (targetpos.x <= maxx and targetpos.x >= pos.x and maxx - pos.x) then
					inst.sg:GoToState("fly_back_ground", target)
				end
			end

			inst.sg.mem.in_position = true
			return
		else
			inst.sg.mem.in_position = nil
		end

		if inst.sg.laststate.tags["flying"] then
			inst.AnimState:PlayAnimation("wind_gust_fly_pre")
		else
			inst.AnimState:PlayAnimation("wind_gust_ground_pre")
		end
	end,
})
SGCommon.States.AddAttackHold(states, "wind_gust", { alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "snatch",
{
	alwaysforceattack = true,
	timeline =
	{
		-- Code Generated by PivotTrack.jsfl
		FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-40/150) end),
		FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(-88/150) end),
		FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(-132/150) end),
		-- End Generated Code
	},
})
SGCommon.States.AddAttackHold(states, "snatch",
{
	alwaysforceattack = true,
	timeline =
	{
		-- Code Generated by PivotTrack.jsfl
		FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-16/150) end),
		FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-12/150) end),
		FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-8/150) end),
		-- End Generated Code
	},
})

SGCommon.States.AddAttackPre(states, "dive_slam",
{
	alwaysforceattack = true,
	addtags = FLYING_TAGS,
	timeline =
	{
		FrameEvent(2, function(inst)
			local target = inst.components.combat:GetTarget()
			if target then
				local pos = target:GetPosition()
				local duration = 8 * ANIM_FRAMES / SECONDS
				inst.sg.statemem.movetotask = SGCommon.Fns.MoveToPoint(inst, pos, duration, easing.inOutSine)
			end
		end),
		FrameEvent(4, function(inst)
			inst.sg:AddStateTag("flying_high")
			inst.HitBox:SetEnabled(false)
			inst.Physics:SetEnabled(false)
			TheCamera:SetZoom(12)
		end),
	},
	onexit_fn = function(inst)
		inst.HitBox:SetEnabled(true)
		inst.Physics:SetEnabled(true)
		TheCamera:SetZoom(0)
	end
})

SGCommon.States.AddAttackHold(states, "dive_slam",
{
	alwaysforceattack = true,
	addtags = lume.concat(FLYING_TAGS, { "flying_high" }),
	onenter_fn = function(inst)
		inst.Physics:Stop()
		inst.HitBox:SetEnabled(false)
		inst.Physics:SetEnabled(false)
		TheCamera:SetZoom(12)

		local target = inst.components.combat:GetTarget()
		if target then
			local targetpos = target:GetPosition()
			--SpawnLandFX(inst, targetpos)
		end
	end,
	onexit_fn = function(inst)
		inst.HitBox:SetEnabled(true)
		inst.Physics:SetEnabled(true)
		TheCamera:SetZoom(0)
	end
})

SGCommon.States.AddAttackPre(states, "dive_bomb",
{
	alwaysforceattack = true,
	addtags = FLYING_TAGS,
	timeline =
	{
		FrameEvent(43, function(inst)
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
			inst.Physics:SetEnabled(false)
			inst.sg:AddStateTag("flying_high")
		end),
	},

	onexit_fn = function(inst)
		inst.HitBox:SetInvincible(false)
		inst.HitBox:SetEnabled(true)
		inst.Physics:SetEnabled(true)
	end,
})

SGCommon.States.AddAttackHold(states, "dive_bomb",
{
	alwaysforceattack = true,
	addtags = { "flying_high" },

	onenter_fn = function(inst)
		inst.HitBox:SetInvincible(true)
		inst.HitBox:SetEnabled(false)
		inst.Physics:SetEnabled(false)

		-- Select a random target.
		local target = inst:GetRandomEntityByTagInRange(1000, inst.components.combat:GetTargetTags(), true, true)

		if not target then return end

		inst.components.combat:SetTarget(target)
		-- spawn "eyes" fx on that target
		inst.sg.mem.target_indicator = SGCommon.Fns.SpawnAtDist(target, "owlitzer_target", 0)
		inst.sg.statemem.tracking_target = true
		inst.sg.statemem.warning_ticks = 77 * 2 -- make sure this equals the FrameEvent in timeline that locks in the target
		--sound
		local params = {}
		params.fmodevent = fmodtable.Event.owlitzer_targetLock_LP
		params.sound_max_count = 1
		params.is_autostop = 1
		inst.sg.statemem.warningsound = soundutil.PlaySoundData(inst.sg.mem.target_indicator, params)
	end,

	update_fn = function(inst)
		if inst.components.combat:GetTarget() and inst.sg.statemem.tracking_target then
			local pos = inst.sg.mem.target_indicator:GetPosition()
			local t_pos = inst.components.combat:GetTarget():GetPosition()
			local ease_fn = easing.linear
			local progress = 0.05

			local x = ease_fn(progress, pos.x, t_pos.x - pos.x, 1)
			local z = ease_fn(progress, pos.z, t_pos.z - pos.z, 1)

			local warning_progress = inst.sg:GetTicksInState() / inst.sg.statemem.warning_ticks
			inst.sg.mem.target_indicator.Transform:SetPosition(x, t_pos.y, z)
			-- inst.sg.mem.target_indicator:SetProgress(2, 1, warning_progress)
			if inst.sg.statemem.warningsound then
				soundutil.SetInstanceParameter(inst.sg.mem.target_indicator, inst.sg.statemem.warningsound,"owlitzer_lockOn_progress",warning_progress)
			end
		end
	end,

	timeline =
	{
		-- Owlitzer spends 85 frames in hold state, signaling at 77 frames gives 8 frames before attack state starts.
		FrameEvent(77, function(inst)
			-- lock in the target position
			if inst.sg.statemem.tracking_target then
				inst.sg.statemem.tracking_target = false
				inst.sg.mem.target_indicator:PushEvent("lock_on")
				--soundutil.PlayCodeSound(inst, fmodtable.Event.owlitzer_divebomb_vo)
				if inst.sg.statemem.warningsound then
					soundutil.SetInstanceParameter(inst.sg.mem.target_indicator, inst.sg.statemem.warningsound,"owlitzer_lockOn_progress",1)
				end
				inst.sg.mem.dive_pos = inst.sg.mem.target_indicator:GetPosition()
			end
		end),
	},

	onexit_fn = function(inst)
		inst.HitBox:SetInvincible(false)
		inst.HitBox:SetEnabled(true)
		inst.Physics:SetEnabled(true)
		if inst.sg.statemem.warningsound then
			soundutil.KillSound(inst.sg.mem.target_indicator, inst.sg.statemem.warningsound)
			inst.sg.statemem.warningsound = nil
		end
	end,
})

SGCommon.States.AddAttackPre(states, "phase_transition_get_off_me",
{
	alwaysforceattack = true,
	onenter_fn = function(inst)
		inst.components.combat:SetDamageReceivedMult("phase_transition", PHASE_TRANSITION_DAMAGE_REDUCTION)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.FaceTarget(inst, target, true)
		end
	end,
	onexit_fn = function(inst)
		inst.components.combat:RemoveDamageReceivedMult("phase_transition")
	end,
})
SGCommon.States.AddAttackHold(states, "phase_transition_get_off_me",
{
	alwaysforceattack = true,
	onenter_fn = function(inst)
		inst.components.combat:SetDamageReceivedMult("phase_transition", PHASE_TRANSITION_DAMAGE_REDUCTION)
	end,
	onexit_fn = function(inst)
		inst.components.combat:RemoveDamageReceivedMult("phase_transition")
	end,
})

SGCommon.States.AddMonsterDeathStates(states)

SGBossCommon.States.AddBossStates(states,
{
	cine_timeline =
	{
		-- Code Generated by PivotTrack.jsfl
		FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-160/150) end),
		FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-206/150) end),
		FrameEvent(7, function(inst) inst.Physics:MoveRelFacing(-120/150) end),
		FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(-120/150) end),
		FrameEvent(13, function(inst) inst.Physics:MoveRelFacing(-92/150) end),
		FrameEvent(16, function(inst) inst.Physics:MoveRelFacing(-20/150) end),
		FrameEvent(20, function(inst) inst.Physics:MoveRelFacing(20/150) end),
		FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(44/150) end),
		FrameEvent(23, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(45, function(inst) inst.Physics:MoveRelFacing(24/150) end),
		FrameEvent(47, function(inst) inst.Physics:MoveRelFacing(92/150) end),
		FrameEvent(49, function(inst) inst.Physics:MoveRelFacing(102/150) end),
		FrameEvent(51, function(inst) inst.Physics:MoveRelFacing(100/150) end),
		FrameEvent(54, function(inst) inst.Physics:MoveRelFacing(76/150) end),
		FrameEvent(56, function(inst) inst.Physics:MoveRelFacing(58/150) end),
		FrameEvent(58, function(inst) inst.Physics:MoveRelFacing(56/150) end),
		FrameEvent(60, function(inst) inst.Physics:MoveRelFacing(56/150) end),
		FrameEvent(62, function(inst) inst.Physics:MoveRelFacing(60/150) end),
		FrameEvent(64, function(inst) inst.Physics:MoveRelFacing(84/150) end),
		FrameEvent(66, function(inst) inst.Physics:MoveRelFacing(68/150) end),
		FrameEvent(68, function(inst) inst.Physics:MoveRelFacing(48/150) end),
		FrameEvent(70, function(inst) inst.Physics:MoveRelFacing(52/150) end),
		FrameEvent(72, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(74, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(76, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(78, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(80, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(82, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(84, function(inst) inst.Physics:MoveRelFacing(56/150) end),
		FrameEvent(87, function(inst) inst.Physics:MoveRelFacing(56/150) end),
		FrameEvent(90, function(inst) inst.Physics:MoveRelFacing(64/150) end),
		FrameEvent(94, function(inst) inst.Physics:MoveRelFacing(52/150) end),
		FrameEvent(98, function(inst) inst.Physics:MoveRelFacing(36/150) end),
		FrameEvent(101, function(inst) inst.Physics:MoveRelFacing(52/150) end),
		FrameEvent(104, function(inst) inst.Physics:MoveRelFacing(48/150) end),
		FrameEvent(107, function(inst) inst.Physics:MoveRelFacing(60/150) end),
		FrameEvent(110, function(inst) inst.Physics:MoveRelFacing(64/150) end),
		FrameEvent(112, function(inst) inst.Physics:MoveRelFacing(76/150) end),
		FrameEvent(114, function(inst) inst.Physics:MoveRelFacing(76/150) end),
		FrameEvent(116, function(inst) inst.Physics:MoveRelFacing(48/150) end),
		FrameEvent(117, function(inst) inst.Physics:MoveRelFacing(80/150) end),
	},
})

SGRegistry:AddData("sg_owlitzer", states)

return StateGraph("sg_owlitzer", states, events, "idle")
