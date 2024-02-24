local SGPlayerCommon = require "stategraphs.sg_player_common"
local PlayerSkillState = require "playerskillstate"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local events = {}

local states =
{
	PlayerSkillState({
		name = "skill_buffnextattack",
		tags = { "busy" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation("skill_crit")
			inst.Physics:Stop()
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", 1 * ANIM_FRAMES)
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				inst.components.playercontroller:FlushControlQueue()
				local power = inst.components.powermanager:GetPowerByName("buffnextattack")
				local critChance = inst.components.powermanager:GetPowerStacks(power.def)
				local isCritMaxed = false;
				if critChance == 100 then
					isCritMaxed = true;
				end
				inst.components.powermanager:DeltaPowerStacks(power.def, 10)
				local critChance = critChance + 10;

				-- SOUNDS
				if not isCritMaxed then
					soundutil.PlaySoundWithParams(inst, fmodtable.Event.Skill_BuffNextAttack_CritUp, { skill_buffNextAttack_critChance = critChance })
				end
			end),
			FrameEvent(10, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(13, SGPlayerCommon.Fns.SetCanDodge),
		},

		onexit = function(inst)
			inst.components.playercontroller:OverrideControlQueueTicks("dodge", nil)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("skill_pst")
			end),
		},
	}),
}

return StateGraph("sg_player_skill_buffnextattack", states, events, "skill_buffnextattack")
