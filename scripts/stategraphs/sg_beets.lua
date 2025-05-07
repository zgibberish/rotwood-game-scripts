local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local playerutil = require "util.playerutil"
local monsterutil = require "util.monsterutil"

local ELITE_HEADSLAM_SPEED = 4

local function OnHeadSlamHitboxTriggered(inst, data)
	local elite = inst:HasTag("elite")

	local hitstop = elite and HitStopLevel.HEAVY or HitStopLevel.MEDIUM
	local hitstun = elite and 10 or 2
	local pushback = elite and 0.5 or 1

	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "headslam",
		hitstoplevel = hitstop,
		pushback = pushback,
		hitstun_anim_frames = hitstun,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnEliteHeadSlamHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "elite_headslam",
		hitstoplevel = HitStopLevel.HEAVY,
		hitstun_anim_frames = 6,
		-- hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function ChooseIdleBehavior(inst)
	-- if not inst.components.timer:HasTimer("idlebehavior_cd") then
	-- 	local threat = playerutil.GetRandomLivingPlayer()
	-- 	if not threat then
	-- 		inst.sg:GoToState("idle_behaviour")
	-- 		return true
	-- 	end
	-- end
	return false
end

local function OnDeath(inst, data)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_beets")

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
		name = "headslam",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("headslam")
			inst.sg.statemem.target = target
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(0, 2, 1.3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(5, SGCommon.Fns.StartVulnerableToKnockdownWindow)
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHeadSlamHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "elite_headslam",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("headslam_elite")
			inst.sg.statemem.target = target
			inst.sg.statemem.attack_num = 1
		end,

		timeline =
		{
			-- First Headbutt
			FrameEvent(4, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(0, 2, 1.3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(0, 2, 1.3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:StopRepeatTargetDelay()
			end),

			-- Landing after flip Headbutt
			FrameEvent(28, function(inst)
				inst.sg.statemem.attack_num = 2
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-1.5, 2, 1.3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(29, function(inst)
				inst.components.hitbox:PushBeam(-1.5, 2, 1.3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(30, function(inst)
				inst.components.hitbox:PushBeam(-1.5, 2, 1.3, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(31, function(inst)
				inst.components.hitbox:StopRepeatTargetDelay()
			end),

			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.Physics:StartPassingThroughObjects()
				SGCommon.Fns.StartJumpingOverHoles(inst)
			end),
			FrameEvent(29, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:StopPassingThroughObjects()
				SGCommon.Fns.StopJumpingOverHoles(inst)
			end),

			-- PHYSICS
			FrameEvent(9, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, ELITE_HEADSLAM_SPEED * 0.15) end),
			FrameEvent(11, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, ELITE_HEADSLAM_SPEED) end),
			FrameEvent(19, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, ELITE_HEADSLAM_SPEED * 0.75) end),
			FrameEvent(29, function(inst) inst.Physics:Stop() end),
		},

		events =
		{
			EventHandler("hitboxtriggered", function(inst, data)
				if inst.sg.statemem.attack_num == 1 then
					OnHeadSlamHitboxTriggered(inst, data)
				else
					OnEliteHeadSlamHitboxTriggered(inst, data)
				end
			end),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),
}

SGCommon.States.AddAttackPre(states, "headslam")
SGCommon.States.AddAttackHold(states, "headslam")

SGCommon.States.AddAttackPre(states, "elite_headslam")
SGCommon.States.AddAttackHold(states, "elite_headslam")

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

SGCommon.States.AddIdleStates(states)

SGCommon.States.AddLocomoteStates(states, "walk",
{
	looptimeline =
	{
		--Some WIP attempts to try to make the footstep a bit 'heavier' feeling
		-- FrameEvent(0, function(inst)
		-- 	SGCommon.Fns.SetMotorVelScaled(inst, inst.components.locomotor:GetBaseWalkSpeed())
		-- end),
		-- FrameEvent(8, function(inst)
		-- 	SGCommon.Fns.SetMotorVelScaled(inst, inst.components.locomotor:GetBaseWalkSpeed() * 0.5)
		-- end),
		-- FrameEvent(15, function(inst)
		-- 	SGCommon.Fns.SetMotorVelScaled(inst, inst.components.locomotor:GetBaseWalkSpeed())
		-- end),

		-- FrameEvent(28, function(inst)
		-- 	SGCommon.Fns.SetMotorVelScaled(inst, inst.components.locomotor:GetBaseWalkSpeed() * 0.5)
		-- end),
	}
})

SGCommon.States.AddTurnStates(states)

SGCommon.States.AddMonsterDeathStates(states)

SGRegistry:AddData("sg_beets", states)

return StateGraph("sg_beets", states, events, "idle")
