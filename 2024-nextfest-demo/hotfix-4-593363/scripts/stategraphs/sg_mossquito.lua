local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"
local TargetRange = require "targetrange"

local CHARGE_SPEED = 22
local CHARGE_SPEED2 = 22
--local SPRAY_SPEED = 5
--local SPRAY_SPEED_ELITE = 8
local PIERCE_HEAL_MAX = 150

local function OnPierceHitboxTriggered(inst, data)
	-- Process the targets we've hit to determine possible heal candidates; only living targets are considered.
	local can_heal_off_target = false
	for _, target in ipairs(data.targets) do
		local target_hit_flags = target.components.hitbox and target.components.hitbox:GetHitGroup() or nil
		if target_hit_flags and target:IsAlive() and
			target_hit_flags & ( HitGroup.MOB | HitGroup.BOSS | HitGroup.PLAYER | HitGroup.NPC ) ~= 0 then
				can_heal_off_target = true
				break
		end
	end

	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "pierce",
		hitstoplevel = HitStopLevel.MEDIUM,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		pushback = 0.2,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		hit_target_pst_fn = function(attacker, v, attack)
			if attacker.sg.statemem.canheal then return end

			-- Must have actually dealt damage to heal.
			local damage_calc = v.components.combat:CalculateProcessedDamage(attack)
			if damage_calc > 0 then
				attacker.sg.statemem.canheal = true
			end
		end,
	})

	if hit then
		SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED * 0.33)
		-- heal a bit if we need it and aren't dead.
		if not inst:IsDead() then
			inst:DoTaskInTicks(math.random(5, 10), function()
				if inst:IsValid()
					and not inst:IsDead()
					and not inst:HasTag("prop")
					and inst.components.health:GetPercent() < 1
					and inst.sg.statemem.canheal
					and can_heal_off_target
				then
					inst.sg.statemem.do_taunt = true
					local healamount = math.min(PIERCE_HEAL_MAX, inst.components.health:GetMissing())
					local heal = Attack(inst, inst)
					heal:SetHeal(healamount)
					inst.components.combat:ApplyHeal(heal)
				end
			end)
		end
	end
end

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
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_mossquito", { y = 1.5 })

	inst.components.lootdropper:DropLoot()
	if inst:HasTag("elite") then
		EffectEvents.MakeEventSpawnLocalEntity(inst, "mossquito_heal_drop", "burst")
		EffectEvents.MakeEventSpawnLocalEntity(inst, "fx_spores_heal_all", "idle")
	end
end

local function ClampPierceAngle(inst, angle)
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
	diff = math.clamp(diff, -angle, angle)
	inst.Transform:SetRotation(facingrot + diff)
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
		name = "pierce",
		tags = { "attack", "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("pierce")
			inst.sg.statemem.target = target
			ClampPierceAngle(inst, 30)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(-0.5, 1.8, 0.50, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.Physics:StartPassingThroughObjects()
				SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED)
			end),

			FrameEvent(5, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.hitting = true
			end),

			FrameEvent(12, function(inst)
				inst.sg.statemem.hitting = false
				SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED * 0.5)
			end),

			FrameEvent(16, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED * 0.25)
			end),

			FrameEvent(21, function(inst)
				inst.Physics:StopPassingThroughObjects()
				SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED * 0.1)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnPierceHitboxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.do_taunt then
					inst.sg:GoToState("taunt")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "pierce_elite",
		tags = { "attack", "busy", "flying" },

		default_data_for_tools = function(inst, cleanup)
			inst.sg.statemem.target = nil
		end,

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("pierce_elite")
			inst.sg.statemem.target = target
			ClampPierceAngle(inst, 45)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(-0.5, 1.8, 0.50, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.Physics:StartPassingThroughObjects()
				SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED)
			end),

			FrameEvent(5, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.hitting = true
			end),

			FrameEvent(11, function(inst)
				inst.sg.statemem.hitting = false
				inst.Physics:StopPassingThroughObjects()
				SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED * 0.33)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnPierceHitboxTriggered),
			EventHandler("animover", function(inst)
				-- Turn around if not facing the target
				inst.sg.statemem.target = SGCommon.Fns.SanitizeTarget(inst.sg.statemem.target)
				if inst.sg.statemem.target and inst.sg.statemem.target.entity then
					local trange = TargetRange(inst, inst.sg.statemem.target)
					if not trange:IsFacingTarget() then
						SGCommon.Fns.TurnAndActOnTarget(inst, inst.sg.statemem.target, true, "pierce2_elite_pre_turn")
						return
					end
				end

				inst.sg:GoToState("pierce2_elite_pre")
			end),
		},

		onexit = function(inst)
			SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED * 0.1)
			inst.Physics:StopPassingThroughObjects()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "pierce2_elite_pre",
		tags = { "attack", "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("pierce2_elite_pre")
			inst.sg.statemem.target = target
		end,

		timeline =
		{
			-- Code Generated by PivotTrack.jsfl
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -1) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -2) end),
			-- End Generated Code
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("pierce2_elite")
			end),
		},
	}),

	State({
		name = "pierce2_elite_pre_turn",
		tags = { "attack", "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("pierce2_pre_turn_elite")
		end,

		timeline =
		{
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 0.5) end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("pierce2_elite", inst.sg.statemem.target)
			end),
		},
	}),

	State({
		name = "pierce2_elite",
		tags = { "attack", "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("pierce2_elite")
			inst.sg.statemem.target = target
			ClampPierceAngle(inst, 30)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(-0.5, 1.8, 0.50, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				inst.Physics:StartPassingThroughObjects()
				SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED2 * 0.5)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.hitting = true
			end),
			FrameEvent(4, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED2)
			end),
			FrameEvent(12, function(inst)
				inst.sg.statemem.hitting = false
				inst.Physics:StopPassingThroughObjects()
				SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED2 * 0.33)
			end),
			FrameEvent(16, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, CHARGE_SPEED2 * 0.1)
			end),
			FrameEvent(21, function(inst)
				inst.Physics:Stop()
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnPierceHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

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

	State({
		name = "taunt",
		tags = { "busy", "flying" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("behavior")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

SGCommon.States.AddAttackPre(states, "pierce",
{
	addtags = { "flying" },
	timeline =
	{
		-- Code Generated by PivotTrack.jsfl
		FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-16/150) end),
		FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-27/150) end),
		-- End Generated Code
	},
})
SGCommon.States.AddAttackHold(states, "pierce",
{
	addtags = { "flying" },
	timeline =
	{
		-- Code Generated by PivotTrack.jsfl
		FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-3/150) end),
		FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-3/150) end),
		FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(12, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(16, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(18, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(20, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(24, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(26, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(28, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(30, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(32, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(34, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(38, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		-- End Generated Code
	},
})

SGCommon.States.AddAttackPre(states, "pierce_elite",
{
	addtags = { "flying" },
	timeline =
	{
		-- Code Generated by PivotTrack.jsfl
		FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-8/150) end),
		FrameEvent(5, function(inst) inst.Physics:MoveRelFacing(-6/150) end),
		-- End Generated Code
	},
})
SGCommon.States.AddAttackHold(states, "pierce_elite",
{
	addtags = { "flying" },
	timeline =
	{
		-- Code Generated by PivotTrack.jsfl
		FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-3/150) end),
		FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-3/150) end),
		FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(12, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(16, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(18, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(20, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(24, function(inst) inst.Physics:MoveRelFacing(-2/150) end),
		FrameEvent(26, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(28, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(30, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(32, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(34, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		FrameEvent(38, function(inst) inst.Physics:MoveRelFacing(-1/150) end),
		-- End Generated Code
	},
})

--[[SGCommon.States.AddAttackPre(states, "spray",
{
	addtags = { "flying" },
})
SGCommon.States.AddAttackHold(states, "spray",
{
	addtags = { "flying" },
})]]

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

SGCommon.States.AddHitStates(states, nil,
{
	addtags = { "flying" },
})
SGCommon.States.AddKnockbackStates(states,
{
	addtags = { "flying" },
	movement_frames = 7,
})
SGCommon.States.AddKnockdownStates(states,
{
	addtags = { "flying" },
	movement_frames = 12,
	onenter_idle_fn = function(inst)
		inst.sg:RemoveStateTag("flying")
	end,
})
SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddIdleStates(states,
{
	addtags = { "flying" },
})
SGCommon.States.AddWalkStates(states,
{
	addtags = { "flying" },
})
SGCommon.States.AddTurnStates(states,
{
	addtags = { "flying" },
})

SGCommon.States.AddMonsterDeathStates(states)

SGRegistry:AddData("sg_mossquito", states)

return StateGraph("sg_mossquito", states, events, "idle")
