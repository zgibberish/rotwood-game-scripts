local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local playerutil = require "util.playerutil"
local monsterutil = require "util.monsterutil"
local TargetRange = require "targetrange"

local SPRAY_SPEED = 5

local function ChooseIdleBehavior(inst)
	--[[if not inst.components.timer:HasTimer("idlebehavior_cd") then
		local threat = playerutil.GetRandomLivingPlayer()
		if not threat then
			inst.sg:GoToState("idle_behaviour")
			return true
		end
	end]]
	return false
end

--[[local function DropAoE(inst)
	-- if not TheWorld.components.roomclear:IsRoomComplete() then
	local aoe = SGCommon.Fns.SpawnAtDist(inst, "trap_acid", 0) -- This trap sits in the "init" state until we have told it to proceed. We need to tell it what its transform size + hitbox sizes should be first.
	local trapdata =
	{
		size = "small",
		temporary = true,
	}

	EffectEvents.MakeNetEventPushEventOnMinimalEntity(aoe, "acid_start", trapdata)

	-- TODO: networking2022, effectevents?
	local burst = SGCommon.Fns.SpawnAtDist(inst, "mosquito_trail_burst", 0)
	burst:DoTaskInAnimFrames(15, function()
		burst.components.particlesystem:StopThenRemoveEntity()
	end)
	burst:ListenForEvent("onremove", function() burst:Remove() end, aoe)
end]]

local function OnDeath(inst, data)
	--Spawn death fx
	local fx_name = inst:HasTag("elite") and "death_woworm_elite" or "death_woworm"
	EffectEvents.MakeEventFXDeath(inst, data.attack, fx_name, { y = 1.5 })

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
	--[[State({
		name = "spray",
		tags = { "attack", "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("spray_loop_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("spray_loop")
			end),
		},
	}),

	State({
		name = "spray_loop",
		tags = { "attack", "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("spray_loop", true)
			inst.sg:SetTimeoutAnimFrames(45)
			local speed = inst:HasTag("elite") and SPRAY_SPEED_ELITE or SPRAY_SPEED
			SGCommon.Fns.SetMotorVelScaled(inst, speed)
			inst.sg.statemem.next_spawn = inst.tuning.spray_interval or 1
			inst.Physics:StartPassingThroughObjects()

			DropDeathAoE(inst)--DropAoE(inst)
		end,

		onupdate = function(inst)
			inst.sg.statemem.next_spawn = inst.sg.statemem.next_spawn - 1
			if inst.sg.statemem.next_spawn <= 0 then
				DropDeathAoE(inst)--DropAoE(inst)
				inst.sg.statemem.next_spawn = inst.tuning.spray_interval or 1
			end
		end,

		ontimeout = function(inst)
			inst.sg.statemem.spray_done = true -- don't transition yet... set a flag that it -can- transition on the next anim loop
		end,

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.Physics:Stop()
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.spray_done then
					inst.sg:GoToState("spray_pst")
				end
			end),
		},
	}),

	State({
		name = "spray_pst",
		tags = { "attack", "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("spray_pst")
			local speed = inst:HasTag("elite") and SPRAY_SPEED_ELITE or SPRAY_SPEED
			SGCommon.Fns.SetMotorVelScaled(inst, speed * 0.33)
		end,

		onexit = function(inst)
			inst.Physics:Stop()
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),]]
}

--[[SGCommon.States.AddAttackPre(states, "spray")
SGCommon.States.AddAttackHold(states, "spray")]]

SGCommon.States.AddSpawnBattlefieldStates(states,
{
	anim = "spawn",
	fadeduration = 0.33,
	fadedelay = 0,
	timeline =
	{
		FrameEvent(0, function(inst) inst:PushEvent("leave_spawner") end),

		FrameEvent(1, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),

		FrameEvent(37, function(inst)
			inst.sg:RemoveStateTag("airborne")
			inst.sg:AddStateTag("caninterrupt")
			inst.Physics:Stop()
		end),
	},

	onexit_fn = function(inst)
		inst.Physics:Stop()
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
SGCommon.States.AddWalkStates(states)
SGCommon.States.AddTurnStates(states)

SGCommon.States.AddMonsterDeathStates(states)

return StateGraph("sg_woworm", states, events, "idle")
