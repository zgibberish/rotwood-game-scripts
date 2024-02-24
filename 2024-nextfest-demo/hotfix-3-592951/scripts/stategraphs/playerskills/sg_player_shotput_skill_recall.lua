local SGCommon = require "stategraphs.sg_common"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local fmodtable = require "defs.sound.fmodtable"
local PlayerSkillState = require "playerskillstate"


local function RecallOneBall(inst, horizontal)
	for projectile,_ in pairs(inst.sg.mem.active_projectiles) do
		if projectile:IsValid() and projectile.sg:HasStateTag("recallable") then
			projectile:TakeControl()
			if projectile:IsLocal() then 
				projectile.sg:GoToState("recalled_pre", { recaller = inst, horizontal = horizontal })
				inst.SoundEmitter:PlaySound(fmodtable.Event.Skill_Shotput_Recall)
				SGCommon.Fns.BlinkAndFadeColor(projectile, { 200/255, 200/255, 200/255 }, 4)
				SGCommon.Fns.BlinkAndFadeColor(inst, { 200/255, 200/255, 200/255 }, 4)
				break
			end
		end
	end
end

local events = {}
local states =
{
	PlayerSkillState({
		name = "skill_shotput_recall",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("shotput_empty")
		end,

		timeline =
		{
			FrameEvent(5, function(inst) RecallOneBall(inst) end),
			FrameEvent(12, function(inst) RecallOneBall(inst) end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("skill_pst")
			end),
		},

		onexit = function(inst)
		end,
	}),

	PlayerSkillState({
		name = "skill_shotput_summon",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("shotput_empty")
		end,

		timeline =
		{
			FrameEvent(5, function(inst) RecallOneBall(inst, true) end),
			FrameEvent(12, function(inst) RecallOneBall(inst, true) end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("skill_pst")
			end),
		},

		onexit = function(inst)
		end,
	}),
}

return StateGraph("sg_player_shotput_skill_recall", states, events, "skill_shotput_recall")
