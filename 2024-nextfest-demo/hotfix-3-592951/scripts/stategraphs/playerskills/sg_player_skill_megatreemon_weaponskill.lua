local fmodtable = require "defs.sound.fmodtable"
local PlayerSkillState = require "playerskillstate"

local events = {}

local states =
{
	PlayerSkillState({
		name = "skill_megatreemon_weaponskill",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("skill_megatreek")
		end,

		timeline =
		{
			FrameEvent(14, function(inst) inst.SoundEmitter:PlaySound(fmodtable.Event.Skill_Megatreek_Cast_Impact) end),
			FrameEvent(14, function(inst) inst.SoundEmitter:PlaySound(fmodtable.Event.Skill_Megatreek_Cast_Roar) end),
			FrameEvent(17, function(inst) inst:PushEvent("activate_skill") end),
			FrameEvent(25, function(inst) inst.sg:RemoveStateTag("busy") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

return StateGraph("sg_player_skill_megatreemon_weaponskill", states, events, "skill_megatreemon_weaponskill")
