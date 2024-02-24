local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"
local lume = require "util.lume"

local PIERCE_SPEED = 3
local SPIN_SPEED = 20
local EVADE_SPEED = 25

local HIDING_TIME_FRAMES = 150 -- How long does EYEV fish for counter hits?

local HIDING_PROXIMITY_RADIUS = 0.5
local HIDING_PHYSICAL_COLLISION_TICKS_TIL_COUNTER = 30 -- During fishing for counter hits, for how many ticks must a player stand on EYEV before it goes into counter hit?
local HIDING_MOVEMENT_SPEED = 1.5 -- While hiding, how much should it move?

local HIDING_DISTANCESQ_TO_STOP_HIDING = 275 -- While hiding, if their target is this far away, stop hiding.

local COUNTER_HIT_HOLD_FRAMES = 2 -- How many frames does EYEV hold the 'taunt_hit' state?
local COUNTER_HIT_FLYBACK_SPEED = 24 -- When hit during counter fishing, how fast does EYEV fly backwards?
local COUNTER_HIT_FLYBACK_FRAMES = 4 -- And for how many frames does it fly for?

local function OnPierceHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "pierce",
		hitstoplevel = inst.sg.statemem.hitting and HitStopLevel.LIGHT or HitStopLevel.MEDIUM,
		pushback = 0.4,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		bypass_posthit_invincibility = true,
	})
end

local function OnSpinHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "spin",
		hitstoplevel = HitStopLevel.LIGHT,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		hit_target_pst_fn = function(attacker, target, _attack)
			-- Go to the taunt anim after hitting something
			attacker.sg.mem.spin_attack_hit = true
		end
	})
end

local function OnRazorLeafSpinHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "razor_leaf",
		hitstoplevel = HitStopLevel.MEDIUM,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function ChooseBattleCry(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		if not inst.components.timer:HasTimer("battlecry_cd") then
			if not inst:IsNear(data.target, 6) then
				SGCommon.Fns.TurnAndActOnTarget(inst, data.target, true, "battlecry")
				return true
			end
		end
	end
	return false
end

local function ChooseIdleBehavior(inst)
	local combatcomponent = inst.components.combat
	if not inst.components.timer:HasTimer("idlebehavior_cd") and (combatcomponent == nil or not inst:IsNear(combatcomponent:GetTarget(), 6)) then
		if not inst.components.timer:HasTimer("taunt_cd") then
			inst.sg:GoToState("taunt")
			return true
		end

		if not inst.components.timer:HasTimer("taunt2_cd") then
			inst.sg:GoToState("taunt2")
			return true
		end
	end
	return false
end

local function OnDeath(inst, data)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_eyev", { y = 2.25 })

	inst.components.lootdropper:DropLoot()
end

-- Create the timeline for spawning leaf razors around the eye-v
local function MakeLeafRazorTimeline(data)
	if data == nil then return end

	local timeline = {}
	local current_frame = data.start_frame or 0
	local interval = ((data.end_frame or 1) - (data.start_frame or 1)) / (data.num_projectiles or 1)
	local angle_interval = 360 / (data.num_directions or 1)

	for i = 1, data.num_projectiles or 1 do
		table.insert(timeline,
			FrameEvent(current_frame, function(inst)
				inst.sg.statemem.current_angle = inst.sg.statemem.current_angle or -45

				local razor_leaf = SGCommon.Fns.SpawnAtAngleDist(inst, "eyev_projectile", 0, inst.sg.statemem.current_angle)
				if razor_leaf then
					razor_leaf:Setup(inst)
					inst.sg.statemem.current_angle = inst.sg.statemem.current_angle + angle_interval
				end
			end))

		current_frame = current_frame + interval
	end

	return timeline
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
	battlecry_fn = ChooseBattleCry,
	idlebehavior_fn = ChooseIdleBehavior,
	spawn_battlefield = true,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local states =
{
	State({
		name = "battlecry",
		tags = { "busy", "caninterrupt", "flying" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior2")
			inst.components.timer:StartTimer("battlecry_cd", 12 + math.random() * 5, true)
			inst.components.timer:StartTimer("idlebehavior_cd", 8 + math.random() * 5, true)
		end,

		timeline =
		{
			FrameEvent(40, function(inst)
				inst.sg:RemoveStateTag("busy")
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
		name = "taunt",
		tags = { "busy", "caninterrupt", "flying" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior1")
			inst.components.timer:StartTimer("taunt_cd", 12 + math.random() * 5, true)
			inst.components.timer:StartTimer("idlebehavior_cd", 8 + math.random() * 5, true)
			SGCommon.Fns.StartVulnerableToKnockdownWindow(inst)
		end,

		timeline =
		{
			FrameEvent(30, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			SGCommon.Fns.StopVulnerableToKnockdownWindow(inst)
		end,
	}),

	State({
		name = "taunt2",
		tags = { "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior3")
			inst.components.timer:StartTimer("taunt2_cd", 12 + math.random() * 5, true)
			inst.components.timer:StartTimer("idlebehavior_cd", 8 + math.random() * 5, true)
			SGCommon.Fns.StartVulnerableToKnockdownWindow(inst)
		end,

		timeline =
		{
			FrameEvent(58, function(inst)
				inst.sg:AddStateTag("flying")
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			SGCommon.Fns.StopVulnerableToKnockdownWindow(inst)
		end,
	}),

	State({
		name = "taunt3",
		tags = { "busy", "caninterrupt", "flying" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior4")
			inst.components.timer:StartTimer("taunt3_cd", 12 + math.random() * 5, true)
			inst.components.timer:StartTimer("idlebehavior_cd", 8 + math.random() * 5, true)
			SGCommon.Fns.StartVulnerableToKnockdownWindow(inst)
		end,

		timeline =
		{
			FrameEvent(58, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			SGCommon.Fns.StopVulnerableToKnockdownWindow(inst)
		end,
	}),

	State({
		name = "pierce",
		tags = { "attack", "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("pierce")
			inst.sg.statemem.target = target
			SGCommon.Fns.SetMotorVelScaled(inst, -PIERCE_SPEED * 0.33)
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(4)
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, -PIERCE_SPEED * 0.1)
			end),
			FrameEvent(10, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, PIERCE_SPEED)
			end),
			-- Pierce 1
			FrameEvent(11, function(inst)
				inst.components.hitbox:PushBeam(0, 2, 1.5, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(-2, 0, 1.25, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushBeam(0, 2.5, 1.5, HitPriority.MOB_DEFAULT)
			end),
			-- Pierce 2
			FrameEvent(13, function(inst)
				inst.components.hitbox:PushBeam(0.5, 5, 1.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				inst.components.hitbox:PushBeam(0.5, 5, 1.5, HitPriority.MOB_DEFAULT)
			end),
			-- Pierce 3
			FrameEvent(17, function(inst)
				inst.components.hitbox:PushBeam(0.5, 5, 1.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(18, function(inst)
				inst.components.hitbox:PushBeam(0.5, 5, 1.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(21, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, PIERCE_SPEED * 0.4)
			end),
			FrameEvent(33, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, PIERCE_SPEED * 0.25)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnPierceHitBoxTriggered),
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
		name = "spin",
		tags = { "attack", "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("spin")
			inst.sg.statemem.target = target
			SGCommon.Fns.SetMotorVelScaled(inst, SPIN_SPEED * 0.25, SGCommon.SGSpeedScale.LIGHT)
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(-0.25, 2.25, 1.5, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(-0.25, 0.25, 3, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				inst.sg.statemem.hitting = true
				SGCommon.Fns.SetMotorVelScaled(inst, SPIN_SPEED, SGCommon.SGSpeedScale.LIGHT)
			end),

			FrameEvent(14, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, SPIN_SPEED * 0.8, SGCommon.SGSpeedScale.LIGHT)
			end),

			FrameEvent(24, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, SPIN_SPEED * 0.5, SGCommon.SGSpeedScale.LIGHT)
			end),

			FrameEvent(32, function(inst)
				inst.sg.statemem.hitting = false
				SGCommon.Fns.SetMotorVelScaled(inst, SPIN_SPEED * 0.4, SGCommon.SGSpeedScale.LIGHT)
			end),

			FrameEvent(38, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, SPIN_SPEED * 0.1, SGCommon.SGSpeedScale.LIGHT)
			end),

			FrameEvent(49, function(inst)
				inst.Physics:Stop()
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSpinHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.mem.spin_attack_hit then
					if inst.sg.statemem.target then
						SGCommon.Fns.TurnAndActOnTarget(inst, inst.sg.statemem.target, true, "taunt3")
					else
						inst.sg:GoToState("taunt")
					end
				else
					inst.sg:GoToState("idle")
				end
				inst.sg.mem.spin_attack_hit = false
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "evade",
		tags = { "hit", "busy", "flying" },

		onenter = function(inst, target)
			target = SGCommon.Fns.SanitizeTarget(target)
			inst.sg.statemem.target = target
			if target ~= nil then
				SGCommon.Fns.FaceTarget(inst, target, true)
			end
			inst.AnimState:PlayAnimation("evade")
			SGCommon.Fns.SetMotorVelScaled(inst, -EVADE_SPEED)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		timeline =
		{
			FrameEvent(10, function(inst)
				inst.sg.statemem.hitting = false
				SGCommon.Fns.SetMotorVelScaled(inst, -EVADE_SPEED * 0.5)
			end),

			FrameEvent(14, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, -EVADE_SPEED * 0.25)
			end),

			FrameEvent(18, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, -EVADE_SPEED * 0.1)
			end),

			FrameEvent(22, function(inst)
				inst.Physics:Stop()
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.Physics:Stop()
		end,
	}),

	State({
		name = "counter_hit_pst",
		tags = { "attack", "busy", "flying", "nointerrupt" },

		onenter = function(inst, attacker)
			inst.sg.statemem.target = SGCommon.Fns.SanitizeTarget(attacker and attacker.owner or attacker)
			inst.AnimState:PlayAnimation("flinch_pst")
			SGCommon.Fns.SetMotorVelScaled(inst, -COUNTER_HIT_FLYBACK_SPEED, SGCommon.SGSpeedScale.LIGHT)
			inst.sg:SetTimeoutAnimFrames(COUNTER_HIT_FLYBACK_FRAMES)
			inst.HitBox:SetInvincible(true)

			if inst.sg.statemem.target and not inst.sg.statemem.target:IsDead() then
				SGCommon.Fns.FaceTarget(inst, inst.sg.statemem.target, true)
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("spin_pre", inst.sg.statemem.target)
			end),
		},

		timeline =
		{
			FrameEvent(2, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, -COUNTER_HIT_FLYBACK_SPEED * 0.6, SGCommon.SGSpeedScale.LIGHT)
			end),

			FrameEvent(6, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, -COUNTER_HIT_FLYBACK_SPEED * 0.3, SGCommon.SGSpeedScale.LIGHT)
			end),

			FrameEvent(9, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, SPIN_SPEED * 0.2, SGCommon.SGSpeedScale.LIGHT)
			end),

			FrameEvent(12, function(inst)
				inst.Physics:Stop()
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.HitBox:SetInvincible(false)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("spin_pre", inst.sg.statemem.target)
		end,
	}),

	State({
		name = "counter",
		tags = { "busy", "flying", "nointerrupt", "attack" },

		-- If EYEV gets attacked or bumped into, transition into counter state.

		onenter = function(inst, target)
			target = SGCommon.Fns.SanitizeTarget(target)
			inst.sg.statemem.target = target
			if target ~= nil then
				SGCommon.Fns.FaceTarget(inst, target, true)
			end
			inst.AnimState:PlayAnimation("counter_pre_hold")
			inst.AnimState:PushAnimation("counter_hold", true)
			inst.sg:SetTimeoutAnimFrames(HIDING_TIME_FRAMES)
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetNonPhysicsRect(2) -- Make hitbox a bit bigger to make more likely to get errant swings.
		end,

		onupdate = function(inst)
			inst.sg.statemem.target = SGCommon.Fns.SanitizeTarget(inst.sg.statemem.target)
			local target = inst.sg.statemem.target
			if target ~= nil then
				if inst:GetDistanceSqTo(target) > HIDING_DISTANCESQ_TO_STOP_HIDING then
					-- If their target is too far away, stop countering.
					inst.sg:GoToState("counter_hit", target)
				else
					-- Otherwise, keep facing them so you walk towards them.
					SGCommon.Fns.FaceTarget(inst, target, true)
				end
			else
				-- If their target no longer exists, just stop countering.
				inst.sg:GoToState("counter_pst")
			end
			inst.components.hitbox:PushBeam(-HIDING_PROXIMITY_RADIUS, HIDING_PROXIMITY_RADIUS, HIDING_PROXIMITY_RADIUS, HitPriority.MOB_DEFAULT)
		end,

		events =
		{
			EventHandler("animover", function(inst, data)
				-- Start moving after the first anim
				inst.Physics:SetMotorVel(HIDING_MOVEMENT_SPEED)
			end),

			EventHandler("hitboxtriggered", function(inst, data)
				inst.sg.statemem.collidedticks = inst.sg.statemem.collidedticks and inst.sg.statemem.collidedticks + 1 or 1
				if inst.sg.statemem.collidedticks > HIDING_PHYSICAL_COLLISION_TICKS_TIL_COUNTER then
					inst.sg:GoToState("counter_hit", data)
				elseif inst.sg.statemem.collidedticks > HIDING_PHYSICAL_COLLISION_TICKS_TIL_COUNTER/2 then
					inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_LIGHT, 4)
				end
			end),

			EventHandler("hitboxcollided_invincible", function(inst, data)
				inst.components.combat:SetTarget(data.inst) -- Change target to attacker
				SGCommon.Fns.FaceTarget(inst, data.inst, true) -- Turn to face attacker
				inst.sg:GoToState("counter_hit", data)
			end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("counter_pst")
		end,

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.Physics:Stop()
			inst.HitBox:UsePhysicsShape()
			inst.HitBox:SetInvincible(false)
		end,
	}),

	State({
		name = "counter_hit",
		tags = { "busy", "nointerrupt", "attack" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("counter_hit_hold")
			inst.sg:SetTimeoutAnimFrames(COUNTER_HIT_HOLD_FRAMES)
			inst.sg.statemem.attacker = data.inst
			inst.HitBox:SetInvincible(true)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("counter_hit_pst", inst.sg.statemem.attacker)
		end,

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
		end,
	}),

	State({
		name = "counter_pst",
		tags = { "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("counter_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "razor_leaf",
		tags = { "attack", "busy", "flying", "caninterrupt" },

		-- If eye-v doesn't get interrupted out of the pre/hold state of this, do the razor_leaf attack
		onenter = function(inst)
			inst.AnimState:PlayAnimation("counter_pre_hold")
			inst.AnimState:PushAnimation("counter_elite_hold", true)
			inst.sg:SetTimeoutAnimFrames(71) -- 2 frames + 23 * 3 frames from the above animation lengths
		end,

		events =
		{
			-- If attacked with weak attacks, once it hits the threshold, do attack interrupt
			EventHandler("attacked", function(inst, data)
				inst.sg.statemem.num_weak_hits = inst.sg.statemem.num_weak_hits or 1
				if inst.sg.statemem.num_weak_hits >= 1 then
					inst.sg:GoToState("knockback", data)
					inst.components.attacktracker:CompleteActiveAttack()
				else
					inst.sg.statemem.num_weak_hits = inst.sg.statemem.num_weak_hits + 1

					-- Do some shake on the hit reactions leading up to the knockback hit.
					if inst.components.hitshudder and data.attack then
						inst.components.hitshudder:DoShudder(TUNING.HITSHUDDER_AMOUNT_HEAVY, data.attack:GetHitstunAnimFrames())
					end
				end
			end),
			-- If hit with heavy attacks handle the knockback and do attack interrupt
			EventHandler("knockback", function(inst, data)
				inst.sg:GoToState("knockback", data)
				inst.components.attacktracker:CompleteActiveAttack()
			end),
			EventHandler("knockdown", function(inst, data)
				inst.sg:GoToState("knockback", data)
				inst.components.attacktracker:CompleteActiveAttack()
			end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("razor_leaf_atk")
		end,
	}),

	State({
		name = "razor_leaf_atk",
		tags = { "attack", "busy", "flying", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("counter_razor_leaf_pre")
			inst.AnimState:PushAnimation("razor_leaf_loop", true)
			inst.sg:SetTimeoutAnimFrames(43) -- 9 frames + 11 x 3 frames from the above animation lengths
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnRazorLeafSpinHitBoxTriggered),
		},

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushCircle(0.00, 0.00, 2.20, HitPriority.MOB_DEFAULT)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("razor_leaf_pst")
		end,

		timeline = lume.concat(MakeLeafRazorTimeline( {start_frame = 11, end_frame = 43, num_projectiles = 24, num_directions = 16 }),
		{
			FrameEvent(10, function(inst) -- Make sure this doesn't interfere with the frame events defined in MakeRazorTimeline()
				inst.sg.statemem.hitting = true
			end),
		}),

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "razor_leaf_pst",
		tags = { "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("elite_razor_leaf_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

local flyingtags = { "flying" }
local spinflyingtags = { "flying", "nointerrupt" }

SGCommon.States.AddAttackPre(states, "pierce",
{
	addtags = flyingtags,
})
SGCommon.States.AddAttackHold(states, "pierce",
{
	addtags = flyingtags,
})

SGCommon.States.AddAttackPre(states, "spin",
{
	addtags = spinflyingtags,
})
SGCommon.States.AddAttackHold(states, "spin",
{
	addtags = spinflyingtags,
})

SGCommon.States.AddAttackPre(states, "counter",
{
	addtags = flyingtags,
})
SGCommon.States.AddAttackHold(states, "counter",
{
	addtags = flyingtags,
	loop_anim = true,
	onenter_fn = function(inst)
		inst.HitBox:SetInvincible(true)
	end,

	onexit_fn = function(inst)
		inst.HitBox:SetInvincible(false)
	end,
})

SGCommon.States.AddAttackPre(states, "razor_leaf",
{
	addtags = lume.merge(flyingtags, { "caninterrupt" })
})

SGCommon.States.AddAttackHold(states, "razor_leaf",
{
	addtags = lume.merge(flyingtags, { "caninterrupt" })
})

SGCommon.States.AddAttackPre(states, "evade",
{
	addtags = flyingtags,
	onenter_fn = function(inst)
		inst.HitBox:SetInvincible(true)
	end,

	onexit_fn = function(inst)
		inst.HitBox:SetInvincible(false)
	end,
})

SGCommon.States.AddSpawnBattlefieldStates(states,
{
	anim = "spawn",
	addtags = flyingtags,
	fadeduration = 0.5,
	fadedelay = 0.1,
	timeline =
	{
		FrameEvent(0, function(inst) inst:PushEvent("leave_spawner") end),
	},
})

SGCommon.States.AddHitStates(states, nil,
{
	addtags = flyingtags,
})
SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 9,
	addtags = flyingtags,
})

local function KnockdownOnEnter(inst)
	inst.Physics:StopPassingThroughObjects()
end
local function KnockdownOnExit(inst)
	inst.Physics:StartPassingThroughObjects()
end

SGCommon.States.AddKnockdownStates(states,
{
	movement_frames = 13,

	onenter_hold_fn = KnockdownOnEnter,
	onexit_hold_fn = KnockdownOnExit,
	onenter_pre_fn = KnockdownOnEnter,
	onexit_pre_fn = KnockdownOnExit,
	onenter_idle_fn = KnockdownOnEnter,
	onexit_idle_fn = KnockdownOnExit,
})
SGCommon.States.AddKnockdownHitStates(states,
{
	onenter_hit_fn = KnockdownOnEnter,
	onexit_hit_fn = KnockdownOnExit,
	onenter_pst_fn = KnockdownOnEnter,
	onexit_pst_fn = KnockdownOnExit,
})

local walkname = "fly"

SGCommon.States.AddIdleStates(states,
{
	addtags = flyingtags,
})
SGCommon.States.AddLocomoteStates(states, walkname,
{
	addtags = flyingtags,
})
SGCommon.States.AddTurnStates(states,
{
	addtags = flyingtags,
})

SGCommon.States.AddMonsterDeathStates(states)

SGRegistry:AddData("sg_eyev", states)

return StateGraph("sg_eyev", states, events, "idle")
