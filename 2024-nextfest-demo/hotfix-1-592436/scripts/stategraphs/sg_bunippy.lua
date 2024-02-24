local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local playerutil = require "util.playerutil"
local monsterutil = require "util.monsterutil"

local KICK_SPEED = 8

local function OnKickHitboxTriggered(inst, data)
	local elite = inst:HasTag("elite")

	local hitstop = elite and HitStopLevel.MEDIUM or HitStopLevel.LIGHT
	local hitstun = elite and 4 or 2
	local pushback = elite and 0.5 or 1

	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "kick",
		hitstoplevel = hitstop,
		pushback = pushback,
		combat_attack_fn = "DoKnockbackAttack",
		hitstun_anim_frames = hitstun,
		bypass_posthit_invincibility = true,
		hitflags = Attack.HitFlags.LOW_ATTACK,
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
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_bunippy")

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
		name = "kick",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("kick")
			inst.sg.statemem.target = target
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(4)
		end,

		timeline =
		{
			-- Hitboxes
			FrameEvent(8, function(inst) inst.components.hitbox:PushBeam(-0.50, 2.50, 1.00, HitPriority.MOB_DEFAULT) end),
			FrameEvent(9, function(inst) inst.components.hitbox:PushBeam(-0.50, 2.50, 1.00, HitPriority.MOB_DEFAULT) end),
			FrameEvent(10, function(inst) inst.components.hitbox:PushBeam(-0.50, 2.50, 1.00, HitPriority.MOB_DEFAULT) end),
			FrameEvent(11, function(inst) inst.components.hitbox:PushBeam(-0.50, 2.50, 1.00, HitPriority.MOB_DEFAULT) end),
			FrameEvent(12, function(inst) inst.components.hitbox:PushBeam(-0.50, 2.50, 1.00, HitPriority.MOB_DEFAULT) end),
			FrameEvent(13, function(inst) inst.components.hitbox:PushBeam(-0.50, 2.50, 1.00, HitPriority.MOB_DEFAULT) end),
			FrameEvent(14, function(inst) inst.components.hitbox:PushBeam(-0.50, 2.50, 1.00, HitPriority.MOB_DEFAULT) end),
			FrameEvent(15, function(inst) inst.components.hitbox:PushBeam(-0.50, 2.50, 1.00, HitPriority.MOB_DEFAULT) end),
			FrameEvent(16, function(inst) inst.components.hitbox:PushBeam(-0.50, 2.50, 1.00, HitPriority.MOB_DEFAULT) end),
			FrameEvent(17, function(inst) inst.components.hitbox:PushBeam(-0.50, 2.50, 1.00, HitPriority.MOB_DEFAULT) end),

			-- Movement
			FrameEvent(4, function(inst)
				inst.Physics:SetMotorVel(KICK_SPEED)
				inst.Physics:StartPassingThroughObjects()
			end),
			FrameEvent(25, function(inst)
				inst.Physics:Stop()
				inst.Physics:StopPassingThroughObjects()
			end),

			-- Other
			FrameEvent(6, SGCommon.Fns.StartVulnerableToKnockdownWindow),
			FrameEvent(24, SGCommon.Fns.StopVulnerableToKnockdownWindow),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnKickHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),
}

SGCommon.States.AddAttackPre(states, "kick")
SGCommon.States.AddAttackHold(states, "kick")

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

SGCommon.States.AddLocomoteStates(states, "walk")

SGCommon.States.AddTurnStates(states)

SGCommon.States.AddMonsterDeathStates(states)

return StateGraph("sg_bunippy", states, events, "idle")
