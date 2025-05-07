local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local TargetRange = require "targetrange"

local function ChooseAttack(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		local attacktracker = inst.components.attacktracker
		local trange = TargetRange(inst, data.target)
		local next_attack = attacktracker:PickNextAttack(data, trange)

		if next_attack == "shoot" then
			local state_name = attacktracker:GetStateNameForAttack(next_attack)
			SGCommon.Fns.TurnAndActOnTarget(inst, data, true, state_name)
			return true
		end
	end
	return false
end

local function OnDeath(inst)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, nil, "death_minion2")
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
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(3) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(7, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVel(.25) end),
			FrameEvent(12, function(inst) inst.Physics:Stop() end),
		},

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
		name = "shoot",
		tags = { "attack", "busy"},

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("shoot")
			inst.sg.statemem.speedmult = 1
			if target ~= nil and target:IsValid() then
				inst.sg.statemem.target = target
				inst:Face(target)
			end
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				-- detect angle towards target
				local target = inst.components.combat:GetTarget()
				if target ~= nil and target:IsValid() then
					local dir = inst:GetAngleTo(target)
					-- snap angle to 8 direction (0, 45, 90, 135, 180, 225, 270, 315)
					-- face bullet in that direction

					local bullet = SGCommon.Fns.SpawnAtDist(inst, "minion_ranged_bullet", 1)
					bullet.Transform:SetRotation(dir)
					bullet:Setup(inst)
				end
				inst.components.attacktracker:CompleteActiveAttack()
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

SGCommon.States.AddAttackPre(states, "shoot", {})

SGCommon.States.AddAttackHold(states, "shoot", {})

SGCommon.States.AddHitStates(states, ChooseAttack)

SGCommon.States.AddMonsterDeathStates(states)

return StateGraph("sg_minion_ranged", states, events, "spawn")
