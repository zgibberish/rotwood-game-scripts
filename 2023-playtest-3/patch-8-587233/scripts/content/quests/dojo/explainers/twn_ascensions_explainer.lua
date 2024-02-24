local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"

local quest_strings = require("strings.strings_npc_dojo_master").QUESTS.ASCENSIONS

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGHEST)
	:SetIsImportant()
	:SetRateLimited(false)

Q:UpdateCast("giver")
	:FilterForPrefab("npc_dojo_master")

Q:AddObjective("ascension_levels_unlocked")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)
		quest:Complete()
	end)

Q:OnTownChat("ascension_levels_unlocked", "giver")
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings.explain_frenzy)
	:Fn(function(cx)

		local function EndOpt(btn_str, response_str)
			cx:AddEnd(btn_str) --say thanks for the explainer
				:MakePositive()
				:Fn(function(cx)
					cx:Talk(response_str) --end the convo
					cx.quest:Complete("ascension_levels_unlocked")
				end)
		end

		cx:Talk("TALK")
		--Opt 1A: Player wants to hear the whole frenzy level explanation
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1A_RESPONSE")
				cx:Opt("OPT_2A") --player confirms they want the whole, lore-heavy spiel
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("OPT2A_RESPONSE") --full explainer
						cx:Opt("OPT_3A") --player notices its odd that were making rots more powerful by fighting them
							:MakePositive()
							:Fn(function(cx)
								cx:Talk("OPT3A_RESPONSE") --end the convo
								EndOpt("OPT_3B", "TALK_END") --say thanks for the explainer
							end)
						EndOpt("OPT_3B", "TALK_END") --say thanks for the explainer
					end)
				cx:Opt("OPT_2B") --player asks for a condensed version of the explainer
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("OPT2B_RESPONSE")
						EndOpt("OPT_3B", "TALK_END") --end the convo
					end)
		end)
		--Opt 1B: Player wants to skip the frenzy level explanation
		cx:Opt("OPT_1B") --player says they already know about frenzy levels
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1B_RESPONSE") --flitt checks to make sure you really want to leave the convo
				cx:Opt("OPT_4A") --ask for a refresher
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("OPT4A_RESPONSE") --get a condensed explanation of frenzy levels
						EndOpt("OPT_5", "TALK_END") --end the convo
					end)
				EndOpt("OPT_4B", "OPT4B_RESPONSE") --player's sure they don't wanna hear the spiel
		end)
	end)

return Q