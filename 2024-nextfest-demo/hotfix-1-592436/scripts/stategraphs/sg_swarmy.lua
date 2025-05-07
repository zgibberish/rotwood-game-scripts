local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"

local function OnDashHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "dash",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 1.5,
		hitstun_anim_frames = 2,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX, --"hits_fire"
		hit_fx_offset_x = 0.5,
	})

	if hit then
		inst.Physics:SetMotorVel(2)
	end
	--SpawnHitFx("hits_fire", inst, v, 0, 0, dir, hitstoplevel)
	--SpawnHurtFx(inst, v, 0, dir, hitstoplevel)
end

local function OnBurstHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "burst",
		hitstoplevel = HitStopLevel.LIGHT,
		pushback = 1,
		hitstun_anim_frames = 2,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnDeath(inst)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, nil, "death_swarmy")
	--Spawn loot (lootdropper will attach hitstopper)
	inst.components.lootdropper:DropLoot()
end

local function SyncHair(inst)
	local frame = inst.hair.AnimState:GetCurrentAnimationFrame()
	if (frame & 1) ~= 0 then
		inst.hair.AnimState:SetFrame(frame < inst.hair.lastframe and frame + 1 or 0)
	end
end

local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") and inst.components.health:GetPercent() >= 0.5 then
		inst.sg:GoToState("idlebehavior")
		return true
	end
	return false
end

local function SpawnAcid(inst, trap_size)
	local trap = SGCommon.Fns.SpawnAtDist(inst, "trap_acid", 0)
	local trapdata =
	{
		size = trap_size, -- small, medium, large
		temporary = true,
	}

	EffectEvents.MakeNetEventPushEventOnMinimalEntity(trap, "acid_start", trapdata)
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
	--battlecry_fn = function(inst) inst.sg:GoToState("battlecry") end,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local states =
{
	State({
		name = "battlecry",
		tags = { "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior1")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:MoveRelFacing(10 / 150) end),
			FrameEvent(3, function(inst) inst.Physics:MoveRelFacing(10 / 150) end),
			FrameEvent(51, function(inst) inst.Physics:MoveRelFacing(-10 / 150) end),
			FrameEvent(54, function(inst) inst.Physics:MoveRelFacing(-10 / 150) end),
			--hair sync
			FrameEvent(3, SyncHair),
			FrameEvent(18, SyncHair),
			FrameEvent(41, SyncHair),
			FrameEvent(60, SyncHair),
			--
			FrameEvent(60, function(inst)
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
		name = "idlebehavior",
		tags = { "busy", "caninterrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior2")
			inst.components.timer:StartTimer("idlebehavior_cd", math.random(8, 16), true)
		end,

		timeline =
		{
			--hair sync
			FrameEvent(0, SyncHair),
			FrameEvent(7, SyncHair),
			FrameEvent(26, SyncHair),
			--
			FrameEvent(46, function(inst)
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
		name = "dash_pre",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			local attack_data = inst.components.attacktracker:GetAttackData("dash")
			inst.components.attacktracker:StartActiveAttack(attack_data.id)
			inst.AnimState:PlayAnimation("acid_dash_pre") -- 2 frames
			inst.AnimState:PushAnimation("acid_dash_hold") -- 31 frames
			inst.sg.statemem.target = target
		end,

		timeline =
		{
			--hair sync
			FrameEvent(0, SyncHair),
			--early exit
			FrameEvent(18, function(inst)
				inst.sg:GoToState("dash", inst.sg.statemem.target)
			end),
		},

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.Physics:MoveRelFacing(-12 / 150)
				inst.sg:GoToState("dash", inst.sg.statemem.target)
			end),
		},
	}),

	State({
		name = "dash",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("acid_dash")
			inst.sg.statemem.target = target
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(0.5, 2.2, 0.5, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(16 / 150) end),
			FrameEvent(17, function(inst)
				local facingrot = inst.Transform:GetFacingRotation()
				local target = inst.sg.statemem.target
				local diff
				if target and target:IsValid() then
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
				diff = math.clamp(diff, -45, 45)
				inst.Transform:SetRotation(facingrot + diff)
				inst.Physics:StartPassingThroughObjects()
				inst.Physics:SetMotorVel(30)
			end),
			FrameEvent(24, function(inst) inst.Physics:SetMotorVel(12) end),
			FrameEvent(30, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(35, function(inst)
				inst.Physics:StopPassingThroughObjects()
				inst.Physics:Stop()
			end),

			--hair sync
			FrameEvent(0, SyncHair),
			FrameEvent(33, SyncHair),
			--attack
			FrameEvent(17, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.hitting = true
				inst.sg.statemem.dashvar = math.random(3)
				inst:SpawnDashTrail(inst.sg.statemem.dashvar)
			end),
			FrameEvent(19, function(inst)
				inst.sg.statemem.dashvar = (inst.sg.statemem.dashvar % 3) + 1
				inst:SpawnDashTrail(inst.sg.statemem.dashvar)
			end),
			FrameEvent(21, function(inst)
				inst.sg.statemem.dashvar = (inst.sg.statemem.dashvar % 3) + 1
				inst:SpawnDashTrail(inst.sg.statemem.dashvar)
			end),
			FrameEvent(26, function(inst)
				inst.sg.statemem.hitting = false
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnDashHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("burst_hold") --idle
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			--inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "burst_pre",
		tags = { "attack", "busy" },

		onenter = function(inst)
			local attack_data = inst.components.attacktracker:GetAttackData("burst")
			inst.components.attacktracker:StartActiveAttack(attack_data.id)
			inst.AnimState:PlayAnimation("acid_burst2_pre") -- 20 frames
		end,

		timeline =
		{
			--physics
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(16 / 150) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-16 / 150) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-44 / 150) end),
			--hair sync
			FrameEvent(0, SyncHair),
		},

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:GoToState("burst_hold")
			end),
		},
	}),

	State({
		name = "burst_hold",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("acid_burst2_hold") -- 31 frames
		end,

		timeline =
		{
			--early exit
			FrameEvent(6, function(inst) inst.sg:GoToState("burst") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("burst")
			end),
		},
	}),

	State({
		name = "burst",
		tags = { "attack", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("acid_burst2") -- 35 frames
		end,

		timeline =
		{
			--hair sync
			FrameEvent(0, SyncHair),
			--attack
			FrameEvent(14, function(inst)
				SpawnAcid(inst, "medium")
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushCircle(0, 0, 3, HitPriority.MOB_DEFAULT)
			end)
		},

		events =
		{
			EventHandler("hitboxtriggered", OnBurstHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),
}

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

return StateGraph("sg_swarmy", states, events, "idle")