local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"

local POKE_SPEED = 11
local POKE_LENGTH_FRAMES = 10
local POKE_SPEED_ELITE = 9
local POKE_LENGTH_FRAMES_ELITE = 8
local POKE_DECEL_PERCENT = 0.25

local function OnPierceHitboxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "pierce",
		hitstoplevel = inst:HasTag("elite") and HitStopLevel.HEAVY or HitStopLevel.LIGHT,
		pushback = 1,
		hitstun_anim_frames = 2,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})

	SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.mem.poke_speed * 0.25)
	inst.sg.statemem.hit = hit
end

local function OnSlamHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "elite_slam",
		hitstoplevel = HitStopLevel.LIGHT,
		pushback = 1.5,
		hitstun_anim_frames = 2,
		hitflags = Attack.HitFlags.GROUND,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		local target = inst.components.combat:GetTarget()
		if target ~= nil then
			if not inst.components.timer:HasTimer("taunt_cd") then
				if inst.components.health:GetPercent() > 0.75 and not inst:IsNear(target, 5) then
					SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "taunt")
					return true
				end
			end
		end
	end
	return false
end

local function OnDeath(inst, data)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_gnarlic")
	inst.components.lootdropper:DropLoot()
end

local events =
{
}
monsterutil.AddMonsterCommonEvents(events,
{
	ondeath_fn = OnDeath,
})
monsterutil.AddOptionalMonsterEvents(events,
{
	idlebehavior_fn = ChooseIdleBehavior,
	spawn_battlefield = true,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local states =
{
		State({
		name = "poke",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("poke_run_pre")
			inst.sg.statemem.target = target
			inst.sg.mem.poke_speed = inst:HasTag("elite") and POKE_SPEED_ELITE or POKE_SPEED
			inst.sg.mem.poke_length = inst:HasTag("elite") and POKE_LENGTH_FRAMES_ELITE or POKE_LENGTH_FRAMES
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.mem.poke_speed * 1.1) -- Start running a little faster
				inst.Physics:StartPassingThroughObjects()

				local facingrot = inst.Transform:GetFacingRotation()
				local target = inst.sg.statemem.target
				local diff
				if target ~= nil and target:IsValid() then
					local dir = inst:GetAngleTo(target)
					diff = ReduceAngle(dir - facingrot)
					if math.abs(diff) >= 90 then
						diff = nil
					end
				end
				if diff == nil then
					local dir = inst.Transform:GetRotation()
					diff = ReduceAngle(dir - facingrot)
				end
				diff = math.clamp(diff, -45, 45)
				inst.Transform:SetRotation(facingrot + diff)
			end),
			FrameEvent(5, function(inst)
				inst.sg.statemem.hitting = true
			end)
		},

		onupdate = function(inst)
			if inst.sg.statemem.hit then
				if (inst:HasTag("elite")) then
					inst.sg:GoToState("elite_slam_pre", inst.sg.statemem.target)
				else
					inst.sg:GoToState("poke_pst")
				end
			elseif inst.sg.statemem.hitting then
				local beam_length = inst:HasTag("elite") and 2.2 or 1.6
				inst.components.hitbox:PushBeam(0, beam_length, 0.8, HitPriority.MOB_DEFAULT)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("poke_loop")
			end),
			EventHandler("hitboxtriggered", OnPierceHitboxTriggered),
		},

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "poke_loop",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("poke_run_loop", true)
			inst.sg.statemem.target = target
			inst.sg:SetTimeoutAnimFrames(inst.sg.mem.poke_length)
			inst.Physics:StartPassingThroughObjects()
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hit then
				if (inst:HasTag("elite")) then
					inst.sg:GoToState("elite_slam_pre", inst.sg.statemem.target)
				else
					inst.sg:GoToState("poke_pst")
				end
			else
				local beam_length = inst:HasTag("elite") and 2.2 or 1.6
				inst.components.hitbox:PushBeam(0, beam_length, 0.8, HitPriority.MOB_DEFAULT)
			end

			local stop_frame = inst.sg.mem.poke_length
			local current_frame = inst.AnimState:GetCurrentAnimationFrame()
			local deceleration = math.max(current_frame / stop_frame, 0)
			SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.mem.poke_speed - ((inst.sg.mem.poke_speed * POKE_DECEL_PERCENT) * deceleration))
		end,

		ontimeout = function(inst)
			if (inst:HasTag("elite")) then
				inst.sg:GoToState("elite_slam_pre", inst.sg.statemem.target)
			else
				inst.sg:GoToState("poke_pst")
			end
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnPierceHitboxTriggered),
		},

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "poke_pst",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("poke_pst")
			inst.Physics:StartPassingThroughObjects()
		end,

		onupdate = function(inst)
			local stop_frame = 6
			local current_frame = inst.AnimState:GetCurrentAnimationFrame()
			local deceleration = math.max(1 - (current_frame / stop_frame), 0)
			SGCommon.Fns.SetMotorVelScaled(inst, (inst.sg.mem.poke_speed - (inst.sg.mem.poke_speed * POKE_DECEL_PERCENT)) * deceleration)

			if (current_frame < (stop_frame * 0.5)) then
				inst.components.hitbox:PushBeam(0, 1.6, 0.8, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(7, function(inst) inst.Physics:StopPassingThroughObjects() end)
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
			EventHandler("hitboxtriggered", OnPierceHitboxTriggered),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "elite_slam",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("elite_slam")
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, 2.5)
			end),
			FrameEvent(3, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.Physics:StartPassingThroughObjects()
			end),
			FrameEvent(14, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, 1.5)
			end),
			FrameEvent(21, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 2.5, HitPriority.MOB_DEFAULT)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:Stop()
				inst.Physics:StopPassingThroughObjects()
			end),
			FrameEvent(22, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 3, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:StopRepeatTargetDelay()
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
			EventHandler("hitboxtriggered", OnSlamHitboxTriggered),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "taunt",
		tags = { "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior1")
			inst.components.timer:StartTimer("taunt_cd", 12, true)
			inst.components.timer:StartTimer("idlebehavior_cd", 8, true)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

SGCommon.States.AddAttackPre(states, "poke")
SGCommon.States.AddAttackHold(states, "poke", { loop_anim = true })
SGCommon.States.AddAttackPre(states, "elite_slam",
{
	timeline =
	{
		FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.mem.poke_speed * 0.6) end),
		FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.mem.poke_speed * 0.3) end),
	},
	onexit_fn = function(inst)
		inst.Physics:Stop()
	end,
})
SGCommon.States.AddAttackHold(states, "elite_slam")

SGCommon.States.AddSpawnBattlefieldStates(states,
{
	anim = "spawn",
	fadeduration = 0.33,
	fadedelay = 0,
	onenter_fn = function(inst)
		local vel = math.random(5, 8)
		SGCommon.Fns.SetMotorVelScaled(inst, vel)
	end,
	timeline =
	{
		FrameEvent(0, function(inst) inst:PushEvent("leave_spawner") end),

		FrameEvent(18, function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
		end),
	},
	onexit_fn = function(inst)
		inst.Physics:Stop()
		inst.Physics:StopPassingThroughObjects()
	end,
})

SGCommon.States.AddHitStates(states)
SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 7,
})
SGCommon.States.AddKnockdownStates(states,
{
	movement_frames = 12,
})
SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddIdleStates(states, { num_idle_behaviours = 1 })
SGCommon.States.AddWalkStates(states)
SGCommon.States.AddTurnStates(states)

SGCommon.States.AddMonsterDeathStates(states)

SGRegistry:AddData("sg_gnarlic", states)

return StateGraph("sg_gnarlic", states, events, "idle")
