local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_scout").QUESTS.twn_chat_scout
local quip_strings = require("strings.strings_npc_scout").QUIPS

local function GetScoutLevel(inst)
	-- Scout level is currently global: only one scout per player.
	return TheSaveSystem.friends:GetValue("scout") or 1
end

local Q = Quest.CreateRecurringChat()

Q:AddTags({"shop"})

Q:SetRateLimited(false)

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForPrefab("npc_scout")


------OBJECTIVE DECLARATIONS------

Q:AddObjective("resident")
	:SetIsUnimportant()
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("upgrade_home")
	:SetIsUnimportant()
	:LogString("{giver} can scout further with a better camp.")
	:OnComplete(function(quest)
		quest:ActivateObjective("upgrade_home_celebrate")
	end)

Q:AddObjective("upgrade_home_celebrate")
	:SetIsUnimportant()

Q:AddObjective("tutorial_feedback")
	:SetIsUnimportant()



------CONVERSATIONS AND QUESTS------

Q:OnTownShopChat("tutorial_feedback", "giver",
	function(quest, node, sim)
		local num_runs = quest:GetPlayer().components.progresstracker:GetValue("total_num_runs") or 0
		return num_runs >= 2
	end)
	:SetPriority(Convo.PRIORITY.LOWEST)
	:FlagAsTemp()
	:Strings(quest_strings.tutorial_feedback)
	:TalkAndCompleteQuestObjective("TALK_FEEDBACK_REMINDER")


Q:OnTownShopChat("upgrade_home", "giver", Q.Filters.RequireMainPlayer)
	:FlagAsTemp()
	:Strings(quest_strings.upgrade_home)
	:Fn(function(cx)
		-- cx almost always refers to ConvoPlayer.
		local giver = cx.quest:GetCastMember("giver")
		local recipe = giver.components.npc:GetNextHouseRecipe()
		local can_upgrade = recipe:CanPlayerCraft(cx:GetPlayer())

		if can_upgrade then
			cx:Talk("TALK_CAN_UPGRADE")

			cx:Opt("OPT_UPGRADE")
				:MarkWithQuest() -- TODO(dbriscoe): What does this do?
				:ShowIngredients(recipe)
				--~ :BuildHouse(recipe) -- TODO(dbriscoe): Make this convenience function instead of Fn.
				:Fn(quest_helper.UpgradeGiverHome)
				:CompleteQuestObjective()
		else
			cx:Talk("TALK_HINT_UPGRADE")
		end
	end)

Q:OnTownChat("resident", "giver")
	:SetPriority(Convo.PRIORITY.LOWEST)
	:Strings(quest_strings.resident)
	:Fn(function(cx)
		cx:Talk("TALK_INTRO")
	end)


return Q
