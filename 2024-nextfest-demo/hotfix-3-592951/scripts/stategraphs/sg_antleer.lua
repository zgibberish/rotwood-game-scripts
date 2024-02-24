local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"

local function OnChargeHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = inst.sg.statemem.attack_id or "charge",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 2,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		reduce_friendly_fire = true,
	})
end

local function OnDeath(inst, data)
	--Spawn death fx
	--EffectEvents.MakeEventFXDeath(inst, data.attack, "death_antleer")
	--Spawn loot (lootdropper will attach hitstopper)
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
	--battlecry_fn = ChooseBattleCry,
	spawn_perimeter = true,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local CHARGE_SPEED = 10

local states =
{
	State({
		name = "charge",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("charge_run_pre")
			inst.AnimState:PushAnimation("charge_run_loop", true)

			inst.sg:SetTimeout(3)

			inst.sg.statemem.attack_state = "charge_pst"
			inst.sg.statemem.target = target

			inst.sg.statemem.initial_rot = inst.Transform:GetRotation()
			inst.sg.statemem.turning_speed = 45 * TICKS

			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		onupdate = function(inst)
			--inst.components.hitbox:PushBeam(1.8, 3.0, 2, HitPriority.MOB_DEFAULT)
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg.statemem.charging = true
				SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnChargeHitboxTriggered),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("charge_pst")
		end,

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "charge_pst",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.sg.statemem.numanims = 0
			inst.AnimState:PlayAnimation("charge_run_pst")
		end,

		timeline = {
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED * 0.8) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED * 0.6) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED * 0.4) end),
			FrameEvent(8, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED * 0.2) end),
			FrameEvent(10, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED * 0) end),
		},

		events = {
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end)
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end
	}),
}

SGCommon.States.AddAttackPre(states, "charge",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "charge",
{
	tags = { "attack", "busy", "nointerrupt" }
})

SGCommon.States.AddHitStates(states, SGCommon.Fns.ChooseAttack)

--[[SGCommon.States.AddSpawnPerimeterStates(states,
{
	pre_anim = "spawn_jump_pre",
	hold_anim = "spawn_jump_hold",
	land_anim = "spawn_jump_land",
	pst_anim = "spawn_jump_pst",

	pst_timeline =
	{
		FrameEvent(0, function(inst) inst.Physics:MoveRelFacing(71/150) end),
	},

	fadeduration = 0.5,
	fadedelay = 0.5,
	jump_time = 0.66,
})]]

SGCommon.States.AddWalkStates(states,
{
	addtags = { "nointerrupt" },
})

SGCommon.States.AddTurnStates(states,
{
	addtags = { "nointerrupt" },
})

SGCommon.States.AddIdleStates(states,
{
	addtags = { "nointerrupt" },
})

--[[SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 12
})]]

SGCommon.States.AddKnockdownStates(states,
{
	movement_frames = 11,
	knockdown_size = 1.45,
})

SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddMonsterDeathStates(states)

local fns =
{
	OnResumeFromRemote = SGCommon.Fns.ResumeFromRemoteHandleKnockingAttack,
}

SGRegistry:AddData("sg_antleer", states)

return StateGraph("sg_antleer", states, events, "idle", fns)
