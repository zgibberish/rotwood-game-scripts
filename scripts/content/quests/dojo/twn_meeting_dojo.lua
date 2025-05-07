local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local Quip = require "questral.quip"
local quest_strings = require("strings.strings_npc_dojo_master").QUESTS.twn_meeting_dojo

------QUEST SETUP------

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGH)

Q:TitleString(quest_strings.TITLE)

function Q:Quest_Complete(quest)
	-- spawn next quest in chain
	self:GetQuestManager():SpawnQuest("twn_shop_dojo")
end

Q:UnlockWorldFlagsOnComplete{ "wf_town_has_dojo" }
Q:UnlockPlayerFlagsOnComplete{ "pf_friendlychat_active" } --FLAG allows Flitt to comment on recruiting a character

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForPrefab("npc_dojo_master")

Q:AddCast("flitt")
	:FilterForPrefab("npc_scout")

------OBJECTIVE DECLARATIONS------

Q:AddObjective("talk_in_town")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

------CONVERSATIONS AND QUESTS------

--TEMP CONVO FOR PLAYTEST
Q:OnTownChat("talk_in_town", "giver")
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings.talk_in_town)
	:Fn(function(cx)
		cx:Talk("TEMP_INTRO")

		cx:AddEnd("TEMP_OPT")
			:MakePositive()
			:Fn(function()
				cx:Talk("TEMP_INTRO2")
				cx.quest:Complete()
			end)
end)

--[[Q:OnTownChat("talk_in_town", "giver")
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings.talk_in_town)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx:Opt("OPT_1A")
			:MakePositive()
			:Talk("OPT1A_RESPONSE")
		cx:Opt("OPT_1B")
			:MakePositive()
			:Talk("OPT1B_RESPONSE")

		cx:JoinAllOpt_Fn(function()
			cx:Talk("TALK2")
			cx:Opt("OPT_2A")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("TALK3")
					cx:Talk("OPT2A_RESPONSE")
				end)
			cx:Opt("OPT_2B")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("TALK3")
					cx:Talk("OPT2B_RESPONSE")
				end)

			cx:JoinAllOpt_Fn(function(cx)
				cx:AddEnd("OPT_3")
					:MakePositive()
					:Fn(function(cx)
						cx.quest:Complete("talk_in_town")
					end)
			end)
		end)
	end)]]

return Q
