local Convo = require "questral.convo"
local Quest = require "questral.quest"
local recipes = require "defs.recipes"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require ("strings.strings_npc_armorsmith_dungeon").QUESTS.first_meeting

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGHEST)

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForRole("dungeon_armorsmith")

--[[Q:UpdateCast("nimble")
	:FilterForRole("npc_market_merchant")]]

------OBJECTIVE DECLARATIONS------

function Q:Quest_Complete()
	--self:GetQuestManager():SpawnQuest("dgn_seenmissingfriends_armorsmith")
end

Q:UnlockWorldFlagsOnComplete{"wf_dungeon_armorsmith"}

--plays when you first meet the salesman
Q:AddObjective("first_meeting")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	-- :LockRoom()
	:OnComplete(function(quest)
		quest_helper.UnlockRoom(quest)
	end)

quest_helper.AddCompleteQuestOnRoomExitObjective(Q)

------CONVERSATIONS AND QUESTS------

Q:OnAttract("first_meeting", "giver", function(quest, node, sim) 
	return quest_helper.Filter_FirstMeetingSpecificNPC(quest, node, sim, "npc_market_merchant")
end)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings)
	:Fn(function(cx)
		local function EndConvo(endStr)
			cx:Talk(endStr)
			cx:End()
			cx.quest:Complete()
		end

		cx:Talk("TALK")

		cx:Opt("OPT_1B")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1B_RESPONSE")
				cx:Opt("OPT_2A")
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT2A_RESPONSE")
						EndConvo("SUDDEN_END")
					end)
				--cx:Opt("OPT_2B")
			end)
	end)

return Q
