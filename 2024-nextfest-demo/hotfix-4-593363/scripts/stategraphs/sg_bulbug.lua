local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local playerutil = require "util.playerutil"
local Power = require"defs.powers"
local TargetRange = require "targetrange"
local monsterutil = require "util.monsterutil"

local function OnStrikeHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "strike",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.4,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnEvadeHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "evade",
		hitstoplevel = HitStopLevel.MEDIUM,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		local threat = playerutil.GetRandomLivingPlayer()
		if not threat then
			inst.sg:GoToState("idle_behaviour")
			return true
		end
	end
	return false
end

local function OnDeath(inst, data)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_bulbug")

	inst.components.lootdropper:DropLoot()
end

local function GetEvadeTarget(inst, target)
	local x, z = inst.Transform:GetWorldXZ()
	local tx, tz = target.Transform:GetWorldXZ()
	local rollX, rollZ = tx, tz
	local direction_mod = x > tx and 1 or -1
	rollZ = tz + math.random(-2, 2)
	rollX = tx + (10 * direction_mod)

	return rollX, rollZ
end

local function ChooseAttack(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		local attacktracker = inst.components.attacktracker
		local trange = TargetRange(inst, data.target)
		local next_attack = attacktracker:PickNextAttack(data, trange)

		if next_attack == "evade" then
			local tarX, tarZ = GetEvadeTarget(inst, data.target)
			local state_name = attacktracker:GetStateNameForAttack(next_attack)
			SGCommon.Fns.TurnAndActOnLocation(inst, tarX, tarZ, false, state_name, { x = tarX, z = tarZ })
			return true
		elseif next_attack ~= nil then
			local state_name = attacktracker:GetStateNameForAttack(next_attack)
			SGCommon.Fns.TurnAndActOnTarget(inst, data, true, state_name)
			return true
		end
	end
	return false
end

local function ChooseBuff(inst, data)
	if not inst.sg:HasStateTag("busy") then
		if not inst.components.timer:HasTimer("buff_shield_cd") and inst.brain.brain.buff_type == "shield" then
			SGCommon.Fns.TurnAndActOnTarget(inst,data, true, "buff_shield_pre")
			return true
		elseif not inst.components.timer:HasTimer("buff_damage_cd") and inst.brain.brain.buff_type == "damage" then
			SGCommon.Fns.TurnAndActOnTarget(inst,data, true, "buff_damage_pre")
			return true
		end
	end
	return false
end

local function OnBuffDamageAttacked(inst, data)
	inst.components.attacktracker:CancelActiveAttack()
	inst.sg:RemoveStateTag("busy") -- Remove the busy tag in order to interrupt the attack.
	return true -- Return true to allow the standard stategraph attacked event handler to run.
end

local events =
{
	EventHandler("dobuff", ChooseBuff),
}
monsterutil.AddMonsterCommonEvents(events,
{
	chooseattack_fn = ChooseAttack,
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
	State({
		name = "buff_shield",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("spell_cast")
			inst.sg.statemem.target = target

			monsterutil.ReverseHitFlags(inst)

			local shield_def = Power.Items.SHIELD.shield
			inst.sg.statemem.power_def = shield_def
			inst.sg.statemem.power_stacks = shield_def.max_stacks
		end,

		timeline =
		{
			FrameEvent(10, function(inst)
				EffectEvents.MakeEventSpawnLocalEntity(inst, "bulbug_shield_buff", "idle")
				-- Also buff itself, if it's an elite
				if inst:HasTag("elite") then
					inst.components.powermanager:AddPower(inst.components.powermanager:CreatePower(inst.sg.statemem.power_def), inst.sg.statemem.power_stacks)
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				-- Elite bulbug attempts to juggernaut nearby enemies without the effect.
				if inst:HasTag("elite") then
					local x,z = inst.Transform:GetWorldXZ()
					local possible_targets = FindTargetTagGroupEntitiesInRange(x, z, 15, inst.components.combat:GetFriendlyTargetTags())
					local power_def = Power.Items.STATUSEFFECT.juggernaut

					for i, target in ipairs(possible_targets) do
						local pm = target.components.powermanager
						if target ~= inst and pm and pm:GetPowerStacks(power_def) == 0 then
							inst.sg:GoToState("buff_damage_pre")
							return
						end
					end
				end

				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			monsterutil.ReverseHitFlags(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			if inst.brain.brain then
				inst.brain.brain:ResetBuffData()
			end
		end,
	}),

	State({
		name = "buff_damage",
		tags = { "attack", "busy", "caninterrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("spell_cast")
			inst.sg.statemem.target = target
			monsterutil.ReverseHitFlags(inst)

			local damage_def = Power.Items.STATUSEFFECT.juggernaut
			inst.sg.statemem.power_def = damage_def
			inst.sg.statemem.power_stacks = 20
			inst.sg.statemem.apply_once = true
		end,

		timeline =
		{
			FrameEvent(10, function(inst)
				EffectEvents.MakeEventSpawnLocalEntity(inst, "bulbug_damage_buff", "idle")
			end),
		},

		events =
		{
			EventHandler("attacked", OnBuffDamageAttacked),
			EventHandler("knockback", OnBuffDamageAttacked),
			EventHandler("knockdown", OnBuffDamageAttacked),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			monsterutil.ReverseHitFlags(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			if inst.brain.brain then
				inst.brain.brain:ResetBuffData()
			end
		end,
	}),

	State({
		name = "strike",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("strike")
			inst.sg.statemem.target = target
		end,

		timeline =
		{
			FrameEvent(14, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(0.5, 3.2, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(15, function(inst)
				inst.components.hitbox:PushBeam(0.5, 3.2, 1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(16, function(inst)
				inst.components.hitbox:PushBeam(0.8, 3.4, 1, HitPriority.MOB_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnStrikeHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "evade",
		tags = { "attack", "busy" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("evade")
			inst.sg.statemem.target = target

		end,

		onupdate = function(inst)
			if inst.sg.statemem.hitting then
				inst.components.hitbox:PushBeam(0.00, 1.75, 1.32, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.hitting = true

				SGCommon.Fns.SetMotorVelScaled(inst, 15)
				inst.Physics:StartPassingThroughObjects()
			end),
			FrameEvent(14, function(inst)
				inst.sg.statemem.hitting = false
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:Stop()
				inst.Physics:StopPassingThroughObjects()
			end),
			-- Code Generated by PivotTrack.jsfl
			FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(106/150) end),
			FrameEvent(15, function(inst) inst.Physics:MoveRelFacing(94/150) end),
			FrameEvent(16, function(inst) inst.Physics:MoveRelFacing(38/150) end),
			-- End Generated Code
		},

		events =
		{
			EventHandler("hitboxtriggered", OnEvadeHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.Physics:StopPassingThroughObjects()
		end,
	}),
}

SGCommon.States.AddAttackPre(states, "strike")
SGCommon.States.AddAttackHold(states, "strike")

SGCommon.States.AddAttackPre(states, "buff_shield")
SGCommon.States.AddAttackHold(states, "buff_shield")

SGCommon.States.AddAttackPre(states, "buff_damage", {
	addevents =
	{
		EventHandler("attacked", OnBuffDamageAttacked),
		EventHandler("knockback", OnBuffDamageAttacked),
		EventHandler("knockdown", OnBuffDamageAttacked),
	},
})
SGCommon.States.AddAttackHold(states, "buff_damage", {
	addevents =
	{
		EventHandler("attacked", OnBuffDamageAttacked),
		EventHandler("knockback", OnBuffDamageAttacked),
		EventHandler("knockdown", OnBuffDamageAttacked),
	},
})

SGCommon.States.AddAttackPre(states, "evade")
SGCommon.States.AddAttackHold(states, "evade")

SGCommon.States.AddSpawnBattlefieldStates(states,
{
	anim = "spawn",

	fadeduration = 0.33,
	fadedelay = 0,

	timeline =
	{
		FrameEvent(2, function(inst) inst:PushEvent("leave_spawner") end),

		FrameEvent(2, function(inst)
			SGCommon.Fns.SetMotorVelScaled(inst, 4)
		end),

		FrameEvent(17, function(inst)
			inst.sg:RemoveStateTag("airborne")
			inst.sg:AddStateTag("caninterrupt")
			inst.Physics:Stop()
		end),

		FrameEvent(25, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),
	},

	onexit_fn = function(inst)
		inst.Physics:Stop()
	end,
})

SGCommon.States.AddHitStates(states)
SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 3,
})
SGCommon.States.AddKnockdownStates(states,
{
	movement_frames = 7,
})
SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddIdleStates(states,{
	addtags_elite = { "nointerrupt" },
})

SGCommon.States.AddLocomoteStates(states, "walk", {
	addtags_elite = { "nointerrupt" },
})

SGCommon.States.AddTurnStates(states,{
	addtags_elite = { "nointerrupt" },
})

SGCommon.States.AddMonsterDeathStates(states)

SGRegistry:AddData("sg_bulbug", states)

return StateGraph("sg_bulbug", states, events, "idle")
