local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local playerutil = require "util.playerutil"
local monsterutil = require "util.monsterutil"

local KICK_SPEED = 8

--[[local function OnRageHitboxTriggered(inst, data)
	local elite = inst:HasTag("elite")

	local hitstop = elite and HitStopLevel.MEDIUM or HitStopLevel.LIGHT
	local hitstun = elite and 4 or 2
	local pushback = elite and 0.5 or 1

	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "rage",
		hitstoplevel = hitstop,
		pushback = pushback,
		hitstun_anim_frames = hitstun,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end]]

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
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_totolili")

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

local TOSS_TIME = 2
local TOSS_SPIN_TIME = 3

local states =
{
	State({
		name = "lily_toss",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("lily_toss")
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				local projectile = SGCommon.Fns.SpawnAtDist(inst, "totolili_projectile", 3.5)
				if projectile then
					projectile:Setup(inst)
				end

				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("lily_toss_loop")
			end),
		},
	}),

	State({
		name = "lily_toss_loop",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("lily_toss_loop", true)
			inst.sg:SetTimeout(TOSS_TIME)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("lily_toss_pst")
		end,

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "lily_toss_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("lily_toss_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "lily_toss_spin",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("lily_toss_spin")
		end,

		timeline =
		{
			FrameEvent(30, function(inst)
				local projectile = SGCommon.Fns.SpawnAtDist(inst, "totolili_projectile", 3.5)
				if projectile then
					projectile:Setup(inst)
				end

				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("lily_toss_spin_idle_loop")
			end),
		},
	}),

	State({
		name = "lily_toss_spin_idle_loop",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("lily_toss_spin_idle_loop", true)
			inst.sg:SetTimeout(TOSS_SPIN_TIME)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("lily_toss_spin_pst")
		end,

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "lily_toss_spin_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("lily_toss_spin_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

SGCommon.States.AddAttackPre(states, "lily_toss")
SGCommon.States.AddAttackHold(states, "lily_toss")

SGCommon.States.AddAttackPre(states, "lily_toss_spin")
SGCommon.States.AddAttackHold(states, "lily_toss_spin")

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

return StateGraph("sg_totolili", states, events, "idle")
