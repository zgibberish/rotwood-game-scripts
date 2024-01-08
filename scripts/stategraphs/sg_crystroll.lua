local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"

local function OnBiteHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = inst.sg.statemem.attack_id or "bite",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 1.5,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		reduce_friendly_fire = true,
	})
end

local function OnGroundPoundHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = inst.sg.statemem.attack_id or "ground_pound",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 1.8,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		reduce_friendly_fire = true,
	})
end

local function OnBodySlamHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = inst.sg.statemem.attack_id or "bodyslam",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 1.8,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		reduce_friendly_fire = true,
	})
end

local function OnBlizzardBreathHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = inst.sg.statemem.attack_id or "blizzardbreath",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 1.5,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		reduce_friendly_fire = true,
	})
end



local function OnDeath(inst, data)
	--Spawn death fx
	--EffectEvents.MakeEventFXDeath(inst, data.attack, "death_crystroll")
	--Spawn loot (lootdropper will attach hitstopper)
	inst.components.lootdropper:DropLoot()
end

local events =
{
}
monsterutil.AddMinibossCommonEvents(events,
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

local BLIZZARD_BREATH_TIME = 4

local states =
{
	--[[State({
		name = "introduction",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior2")
			inst.AnimState:PushAnimation("behavior1")
			inst.sg.statemem.animovers = 0
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.animovers = inst.sg.statemem.animovers + 1
				if inst.sg.statemem.animovers >= 2 then
					inst.sg:GoToState("idle")
				end
			end),
		},
	}),]]


	---- ATTACKS ----
	State({
		name = "bite",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("bite")
			inst.sg.statemem.target = target
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnBiteHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "groundpound",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("ground_pound")
			inst.sg.statemem.target = target
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnGroundPoundHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "bodyslam",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("body_slam")
			inst.sg.statemem.target = target
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnBodySlamHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "blizzardbreath",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("blizzard_breath")
			inst.sg.statemem.target = target
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnBlizzardBreathHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("blizzardbreath_loop")
			end),
		},

		onexit = function(inst)
		end,
	}),

	State({
		name = "blizzardbreath_loop",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("blizzard_breath_loop", true)
			inst.sg.statemem.target = target
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.sg:SetTimeout(BLIZZARD_BREATH_TIME)
		end,

		onupdate = function(inst)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnBlizzardBreathHitboxTriggered),
		},

		ontimeout = function(inst)
				inst.sg:GoToState("blizzardbreath_pst")
		end,

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "blizzardbreath_pst",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("blizzard_breath_pst")
			inst.sg.statemem.target = target
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
		end,
	}),
}

SGCommon.States.AddAttackPre(states, "bite",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "bite",
{
	tags = { "attack", "busy", "nointerrupt" }
})

SGCommon.States.AddAttackPre(states, "groundpound",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "groundpound",
{
	tags = { "attack", "busy", "nointerrupt" }
})

SGCommon.States.AddAttackPre(states, "bodyslam",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "bodyslam",
{
	tags = { "attack", "busy", "nointerrupt" }
})

SGCommon.States.AddAttackPre(states, "blizzardbreath",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "blizzardbreath",
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
SGCommon.States.AddMinibossDeathStates(states)

local fns =
{
	OnResumeFromRemote = SGCommon.Fns.ResumeFromRemoteHandleKnockingAttack,
}

SGRegistry:AddData("sg_crystroll", states)

return StateGraph("sg_crystroll", states, events, "idle", fns)
