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
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_meowl")

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

local TAUNT_TIME = 3

local states =
{
	State({
		name = "snowball",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("snowball")
			inst.sg.statemem.target = target
		end,

		timeline =
		{
			FrameEvent(24, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				local snowball = SGCommon.Fns.SpawnAtDist(inst, "meowl_projectile", 3.5)
				if snowball then
					snowball:Setup(inst)
				end
			end),
			FrameEvent(25, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "taunt",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("taunt_loop", true)
			inst.sg.statemem.target = target
			inst.sg:SetTimeout(TAUNT_TIME)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("taunt_pst")
		end,

		events =
		{
			EventHandler("attacked", function(inst, data)
				inst.sg:GoToState("taunt_hit", data)
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "taunt_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("taunt_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "taunt_hit",
		tags = { "hit", "busy", "nointerrupt" },

		onenter = function(inst, data)
			local anim = data.front and "taunt_hit_hold" or "taunt_hit_back_hold"
			inst.AnimState:PlayAnimation(anim)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("taunt_hit_pst")
			end),
		},
	}),

	State({
		name = "taunt_hit_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("taunt_hit_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("rage_loop")
			end),
		},
	}),

	State({
		name = "rage_loop",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("rage_loop", true)
			inst.sg:SetTimeout(2)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("idle")
		end,
	}),
}

SGCommon.States.AddAttackPre(states, "snowball")
SGCommon.States.AddAttackHold(states, "snowball")

SGCommon.States.AddAttackPre(states, "taunt")

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

return StateGraph("sg_meowl", states, events, "idle")
