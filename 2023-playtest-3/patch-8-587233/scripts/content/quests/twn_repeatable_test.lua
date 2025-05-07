local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_generic").QUESTS.twn_repeatable_test

--function ConvoPlayer:TryPushHook(hook, object, default_state)
-- OnAttract for shop hub

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.NORMAL)

--Q:AddTags({"repeatable"})

Q:TitleString(quest_strings.TITLE)

--Q:UpdateCast("giver")

Q:SetCastCandidates({"npc_scout", "npc_blacksmith", "npc_armorsmith"})

Q:AddObjective("present_quest")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)
		quest:ActivateObjective("do_quest")
	end)

Q:AddObjective("do_quest")
	:OnComplete(function(quest)
		quest:Complete()
	end)

function Q:Quest_Complete()
	-- TODO: Mark it as done and add it back to the pool?
	print("###### QUEST COMPLETED")

end

Q:OnTownChat("present_quest", "giver", Quest.Filters.InTown)
	:FlagAsTemp()
	:Strings(quest_strings.present_quest)
	:Fn(function(cx)
		cx:Talk("INTRODUCE_QUEST")
		cx:Opt("OPT_FUN")
			:Fn(function() 
				cx:Talk("EXPLANATION")
				cx:Opt("OPT_OK")
					:End()
					:CompleteObjective()
				
				cx:Opt("CANCEL")
					:Fn(function()
						cx:Talk("WHATEVER")
						quest_helper.PushShopChat(cx)
					end)
			end)
	end)

Q:OnAttract("do_quest", "giver", Quest.Filters.InTown)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:FlagAsTemp()
	:Strings(quest_strings.do_quest)
	:Fn(function(cx)
		cx:Talk("INSTRUCTIONS_QUEST")

		cx:Opt("OPT_YES")
			:MakePositive()
			:Fn(function()
				cx:Talk("COMPLETED")
			end)
			:CompleteObjective()

		cx:Opt("OPT_CANCEL")
			:Fn(function(cx)
				cx:Talk("CANCEL")
				quest_helper.PushShopChat(cx)
			end)
	end)
return Q
