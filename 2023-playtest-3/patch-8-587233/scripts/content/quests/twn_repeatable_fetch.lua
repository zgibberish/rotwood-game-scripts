local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_generic").QUESTS.twn_repeatable_fetch

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.NORMAL)

Q:AddTags({"repeatable"})
Q:AddVar("request_material", "PLACEHOLDER")
Q:AddVar("reward", "PLACEHOLDER")

function Q:Quest_DebugSpawned()
	-- TODO: Can we do this from Quest_Start instead?
	local fake_cx = {
		quest = self,
	}
	quest_helper.PickFetchMaterial(fake_cx)
	quest_helper.PickReward(fake_cx)
end

Q:TitleString(quest_strings.TITLE)

Q:SetCastCandidates({"npc_blacksmith", "npc_armorsmith", "npc_refiner", "npc_cook", "npc_apothecary"})

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

Q:OnTownChat("present_quest", "giver")
	:FlagAsTemp()
	:Strings(quest_strings.present_quest)
	:Fn(function(cx)
		quest_helper.PickFetchMaterial(cx)
		-- TODO: What to do when there's no rewards left to give?
		quest_helper.PickReward(cx)

		cx:Talk("INTRODUCE_QUEST")
		
		cx:Opt("OPT_OK")
			:CompleteObjective()
			:Fn(function(cx) 
				cx:Talk("TALK_THANKS")
				quest_helper.PushShopChat(cx, true)
			end)
		
		cx:Opt("CANCEL")
			:Fn(function()
				quest_helper.PushShopChat(cx, true)
			end)
	end)


Q:OnTownChat("do_quest", "giver", quest_helper.Not(quest_helper.HasFetchMaterial))
	:Strings(quest_strings.do_quest_reminder)
	:Fn(function(cx)
		local agent = cx.quest:GetCastMember("giver")
		if not agent.reminded then -- HACK
			agent.reminded = true
			cx:Talk("TALK_REMINDER")
			quest_helper.PushShopChat(cx, true)
		else
			quest_helper.PushShopChat(cx)
		end
	end)

Q:OnTownChat("do_quest", "giver", quest_helper.HasFetchMaterial)
	:Strings(quest_strings.do_quest)
	:Fn(function(cx)
		cx:Talk("TALK_DELIVERY")

		cx:Opt("OPT_YES")
			:Fn(function()
				quest_helper.DeliverFetchMaterial(cx)
				quest_helper.GiveReward(cx)
				cx:Talk("TALK_THANKS")
			end)
			:CompleteObjective()

		cx:Opt("OPT_NO")
			:Fn(function(cx) 
				quest_helper.PushShopChat(cx, true)
			end)
	end)

return Q
