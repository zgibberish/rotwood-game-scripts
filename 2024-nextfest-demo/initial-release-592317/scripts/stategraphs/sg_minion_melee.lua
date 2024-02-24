local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local TargetRange = require "targetrange"
local monsterutil = require "util.monsterutil"

local function OnJumpHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "jump",
		hitstoplevel = HitStopLevel.MEDIUM,
		combat_attack_fn = "DoBasicAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
	})
end


local function ChooseAttack(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		local attacktracker = inst.components.attacktracker
		local trange = TargetRange(inst, data.target)
		local next_attack = attacktracker:PickNextAttack(data, trange)

		if next_attack == "jump" then
			local state_name = attacktracker:GetStateNameForAttack(next_attack)
			SGCommon.Fns.TurnAndActOnTarget(inst, data, true, state_name)
			return true
		end
	end
	return false
end

local function OnDeath(inst)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, nil, "death_minion1")
	if inst.summoner ~= nil then
		inst.summoner:PushEvent("minion_unsummoned", inst)
	end
end

local events =
{
	SGCommon.Events.OnAttacked(),
	SGCommon.Events.OnDying(),
	SGCommon.Events.OnQuickDeath(OnDeath),
	SGCommon.Events.OnAttack(ChooseAttack),
}

local states =
{
	State({
		name = "spawn",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("spawn", true)
		end,

		timeline =
		{
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(3) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(15, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(.25) end),
			FrameEvent(20, function(inst) inst.Physics:Stop() end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			if not inst.AnimState:IsCurrentAnimation("idle") then
				inst.AnimState:PlayAnimation("idle", true)
			end

			--Used by brain behaviors in case our size varies a lot
			if inst.sg.mem.idlesize == nil then
				inst.sg.mem.idlesize = inst.Physics:GetSize()
			end
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "jump",
		tags = { "attack", "busy"},

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("jump")
			inst.sg.statemem.speedmult = 1
			if target ~= nil and target:IsValid() then
				inst.sg.statemem.target = target
				inst:Face(target)
			end
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(0, 1.5, 1.3, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			--physics
			FrameEvent(5, function(inst) inst.Physics:SetMotorVel(11 * inst.sg.statemem.speedmult) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(12 * inst.sg.statemem.speedmult) end),
			--FrameEvent(11, function(inst) inst.sg.statemem.speedmult = math.sqrt(inst.sg.statemem.speedmult) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(9 * inst.sg.statemem.speedmult) end),
			FrameEvent(16, function(inst) inst.Physics:SetMotorVel(8 * inst.sg.statemem.speedmult) end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(7 * inst.sg.statemem.speedmult) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(6.5 * inst.sg.statemem.speedmult) end),
			FrameEvent(19, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(5, function(inst)
				inst.sg:AddStateTag("airborne")
			end),

			FrameEvent(6, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.hitting = true
			end),

			FrameEvent(20, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.components.attacktracker:CompleteActiveAttack()
			end),
			FrameEvent(22, function(inst)
				inst.sg.statemem.hitting = false
				inst.components.hitbox:StopRepeatTargetDelay()
			end),
			FrameEvent(23, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(29, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnJumpHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "despawn",
		tags = { "busy" },

		onenter = function(inst)
			inst.Physics:Stop()
			inst:DoTaskInAnimFrames(math.random(10), function(inst)
				inst.AnimState:PlayAnimation("despawn")
			end)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if inst:IsValid() then
					inst:Remove()
				end
			end),
		},
	}),
}

SGCommon.States.AddAttackPre(states, "jump",
{
	timeline =
	{
		--physics
		-- FrameEvent(1, function(inst) inst.Physics:MoveRelFacing(-12 / 150) end),
		-- FrameEvent(3, function(inst) inst.Physics:SetSize(1) end),
		-- FrameEvent(3, function(inst) inst.Physics:MoveRelFacing(-32 / 150) end),
		-- FrameEvent(5, function(inst) inst.Physics:MoveRelFacing(-16 / 150) end),
	},
})

SGCommon.States.AddAttackHold(states, "jump",
{
	timeline =
	{
		-- FrameEvent(3, function(inst) inst.Physics:MoveRelFacing(-8 / 150) end),
		-- FrameEvent(9, function(inst) inst.Physics:MoveRelFacing(-4 / 150) end),
	}
})

SGCommon.States.AddHitStates(states, ChooseAttack)

SGCommon.States.AddMonsterDeathStates(states)

return StateGraph("sg_minion_melee", states, events, "spawn")