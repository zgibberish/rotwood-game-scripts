local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local playerutil = require "util.playerutil"
local monsterutil = require "util.monsterutil"

local POKE_SPEED = 10
local POKE_LENGTH_FRAMES = 15
local POKE_SPEED_ELITE = 8
local POKE_LENGTH_FRAMES_ELITE = 3

local function OnPierceHitboxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "pierce",
		hitstoplevel = inst:HasTag("elite") and HitStopLevel.HEAVY or HitStopLevel.LIGHT,
		pushback = inst:HasTag("elite") and 1 or 1,
		hitstun_anim_frames = 2,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = inst:HasTag("elite") and "DoKnockdownAttack" or "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})

	SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.mem.poke_speed * 0.25)

	inst.sg.statemem.hit = hit
end

-- TODO: change num_idle_behaviours in AddIdleStates call when implementing this
--[[local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		local threat = playerutil.GetRandomLivingPlayer()
		if not threat then
			inst.sg:GoToState("idle_behaviour")
			return true
		end
	end
	return false
end]]

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
	--idlebehavior_fn = ChooseIdleBehavior,
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
			-- TODO: get angle between me + target
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.mem.poke_speed * 1.25) -- Start running a little faster
				inst.sg.statemem.hitting = true
			end),
		},

		onupdate = function(inst)
			if inst.sg.statemem.hit then
				inst.sg:GoToState("poke_pst")
			elseif inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(0, 1.6, 0.8, HitPriority.MOB_DEFAULT)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("poke_loop")
			end),

			EventHandler("hitboxtriggered", OnPierceHitboxTriggered),
		},
	}),

	State({
		name = "poke_loop",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("poke_run_loop", true)
			inst.sg.statemem.target = target

			inst.sg:SetTimeoutAnimFrames(inst.sg.mem.poke_length)
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hit then
				inst.sg:GoToState("poke_pst")
			else
				inst.components.hitbox:PushBeam(0, 1.6, 0.8, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.mem.poke_speed)
			end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("poke_pst")
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnPierceHitboxTriggered),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "poke_pst",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("poke_pst")
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		onupdate = function(inst)
			local stop_frame = 6
			local current_frame = inst.AnimState:GetCurrentAnimationFrame()
			local deceleration = math.max(1 - (current_frame / stop_frame), 0)
			SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.mem.poke_speed * deceleration)

			if (current_frame < stop_frame) then
				inst.components.hitbox:PushBeam(0, 1.6, 0.8, HitPriority.MOB_DEFAULT)
			end
		end,

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
		end,

	}),
}

SGCommon.States.AddAttackPre(states, "poke")
SGCommon.States.AddAttackHold(states, "poke", { loop_anim = true })

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

SGCommon.States.AddIdleStates(states, { num_idle_behaviours = 0 })
SGCommon.States.AddWalkStates(states)
SGCommon.States.AddTurnStates(states)

SGCommon.States.AddMonsterDeathStates(states)

SGRegistry:AddData("sg_gnarlic", states)

return StateGraph("sg_gnarlic", states, events, "idle")
