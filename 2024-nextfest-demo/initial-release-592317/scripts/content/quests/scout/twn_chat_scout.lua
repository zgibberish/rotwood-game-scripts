local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quip = require "questral.quip"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_scout").QUESTS.twn_chat_scout
local quip_strings = require("strings.strings_npc_scout").QUIPS

local function GetScoutLevel(inst)
	-- Scout level is currently global: only one scout per player.
	return TheSaveSystem.friends:GetValue("scout") or 1
end

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.LOWEST)

Q:SetRateLimited(false)

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForPrefab("npc_scout")

------OBJECTIVE DECLARATIONS------

Q:AddObjective("resident")
	:SetIsUnimportant()
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("tutorial_feedback")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:SetIsUnimportant()

Q:AddObjective("bandages")
	:SetRateLimited(true)
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

--[[Q:AddObjective("glitz_allergy")
	:SetRateLimited(true)
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)]]

Q:AddObjective("beautiful_future")
	:SetRateLimited(true)
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("foraging_part_one")
	:SetRateLimited(true)
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)
		--quest:ActivateObjective("foraging_part_two")
	end)

Q:AddObjective("foraging_part_two")
	:SetRateLimited(true)
	:SetIsImportant()
	:OnComplete(function(quest)
		quest:ActivateObjective("foraging_part_three")
	end)

Q:AddObjective("foraging_part_three")
	:SetRateLimited(true)
	:SetIsImportant()
	:OnComplete(function(quest)
		quest:ActivateObjective("upgrade_home_celebrate")
	end)

Q:AddObjective("gathering_data")
	:SetRateLimited(true)
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("bonion_cry")
	:SetRateLimited(true)
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddQuips {
	--general
    Quip("scout", "attract")
        :PossibleStrings(quip_strings.quip_scout_generic),

    --comments on townsfolk
    Quip("scout","wf_town_has_armorsmith")
        :PossibleStrings(quip_strings.quip_scout_has_armoursmith),
    Quip("scout","wf_town_has_armorsmith_false")
        :PossibleStrings(quip_strings.quip_scout_no_armoursmith),
    Quip("scout","wf_town_has_blacksmith")
        :PossibleStrings(quip_strings.quip_scout_has_blacksmith),
    Quip("scout","wf_town_has_blacksmith_false")
        :PossibleStrings(quip_strings.quip_scout_no_blacksmith),
    Quip("scout","wf_town_has_dojo")
        :PossibleStrings(quip_strings.quip_scout_has_dojo),
    Quip("scout","wf_town_has_dojo_false")
        :PossibleStrings(quip_strings.quip_scout_no_dojo),
    Quip("scout","wf_town_has_cook")
        :PossibleStrings(quip_strings.quip_scout_has_cook),

    --quips remarking on the last run
    Quip("scout","won_last_run")
        :PossibleStrings(quip_strings.quip_won_last_run),
    Quip("scout","lost_last_run")
        :PossibleStrings(quip_strings.quip_lost_last_run),
    Quip("scout","abandoned_last_run")
        :PossibleStrings(quip_strings.quip_abandoned_last_run),

    --quips that are only active before a particular quest is started

    --quips remaking on active quests
    Quip("scout","recharge_inhaler_complete")
        :PossibleStrings(quip_strings.dojo_inhalerquest_one.mid_quest_quips),

    --quips remarking on completed quests
    Quip("scout","tutorial_glitz_start_complete")
        :PossibleStrings(quip_strings.quip_scout_done_mirror_quest),
}

------CONVERSATIONS AND QUESTS------

Q:OnTownChat("foraging_part_one", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:Strings(quest_strings.foraging.part_one)
	:Fn(function(cx)
		cx:Talk("TALK")

		cx:Opt("OPT_1A")
			:MakePositive()
		cx:Opt("OPT_1B")
			:MakePositive()
		cx:Opt("OPT_1C")
			:MakePositive()

		cx:JoinAllOpt_Fn(function()
			cx:Talk("TALK2")
			cx.quest:Complete("foraging_part_one")
			cx:End()
		end)
	end)
Q:OnTownChat("foraging_part_two", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:Strings(quest_strings.foraging.part_two)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx:Opt("OPT_1")
			:MakePositive()
			:Fn(function()
				cx:Talk("TALK2")
				cx:End()
				cx.quest:Complete("foraging_part_two")
			end)
	end)
Q:OnTownChat("foraging_part_three", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:Strings(quest_strings.foraging.part_three)
	:Fn(function(cx)
		local function AddEndBtn(btn_str)
			cx:AddEnd(btn_str)
				:MakePositive()
				:Fn(function()
					cx.quest:Complete("foraging_part_three")
				end)
		end

		cx:Talk("TALK")
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1A_RESPONSE")
				AddEndBtn("OPT_1B_ALT")
			end)
		AddEndBtn("OPT_1B")
	end)

Q:OnTownChat("bandages", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:Strings(quest_strings.bandages)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1A_RESPONSE")
				cx:End()
				cx.quest:Complete("bandages")
			end)
		cx:AddEnd("OPT_1B")
			:Fn(function()
				cx.quest:Complete("bandages")
			end)
	end)

Q:OnTownChat("gathering_data", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:Strings(quest_strings.gathering_data)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx.quest:Complete("gathering_data")
		cx:End()
	end)

Q:OnTownChat("bonion_cry", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:Strings(quest_strings.bonion_cry)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx.quest:Complete("bonion_cry")
		cx:End()
	end)

--[[Q:OnTownChat("glitz_allergy", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:Strings(quest_strings.glitz_allergy)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function()
				cx:Talk("TALK2")

				cx:Opt("OPT_2A")
					:MakePositive()
				cx:Opt("OPT_2B")
					:MakePositive()
				cx:Opt("OPT_2C")
					:MakePositive()

				cx:JoinAllOpt_Fn(function()
					cx:Talk("TALK3")
					cx:End()
					cx.quest:Complete("glitz_allergy")
				end)
			end)
	end)]]

Q:OnTownChat("beautiful_future", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:Strings(quest_strings.beautiful_future)
	:Fn(function(cx)
		local function OptBtn(btnStr, responseStr)
			cx:Opt(btnStr)
			:MakePositive()
			:Fn(function()
				cx:Talk(responseStr)
				cx:End()
				cx.quest:Complete("beautiful_future")
			end)
		end

		cx:Talk("TALK")
		OptBtn("OPT_1A", "OPT1A_RESPONSE")
		OptBtn("OPT_1B", "OPT1B_RESPONSE")
		OptBtn("OPT_1C", "OPT1C_RESPONSE")
	end)

Q:OnTownChat("tutorial_feedback", "giver",
	function(quest, node, sim)
		local num_runs = quest:GetPlayer().components.progresstracker:GetValue("total_num_runs") or 0
		return num_runs >= 2
	end)
	:SetPriority(Convo.PRIORITY.LOWEST)
	:FlagAsTemp()
	:Strings(quest_strings.tutorial_feedback)
	:TalkAndCompleteQuestObjective("TALK_FEEDBACK_REMINDER")


Q:OnTownChat("resident", "giver")
	:SetPriority(Convo.PRIORITY.LOWEST)
	:Strings(quest_strings.resident)
	:Fn(function(cx)
		local _player = cx.GetPlayer(cx)
		--local qman = player.components.questcentral:GetQuestManager()

		local assess_flags = {"wf_town_has_armorsmith", "wf_town_has_blacksmith", "wf_town_has_dojo", "wf_town_has_cook"}
		local assess_quests = {"recharge_inhaler", "tutorial_glitz_start"}
		local quip_tags = {"scout", "attract"} --include the general category by default

		--check which flags are tripped, mainly to see which NPCs are recruited already
		for _,flag in ipairs(assess_flags) do
			if TheWorld:IsFlagUnlocked(flag) then
				table.insert(quip_tags, flag)
			else
				table.insert(quip_tags, flag .. "_false")
			end
		end

		--check the condition of the last run-- did the player win, lose, or abandon?
		if _player.inst.components.progresstracker:AbandonedLastRun() then
			table.insert(quip_tags, "abandoned_last_run")
		elseif _player.inst.components.progresstracker:WonLastRun() then
			table.insert(quip_tags, "won_last_run")
		else
			table.insert(quip_tags, "lost_last_run")
		end

		--[[
		print("-----------HEY----------------")
		for _,quip in ipairs(quip_tags) do
			print(quip)
		end
		--]]

		--check notable quests to see if theyre active, completed, or failed/havent been started
		--[[for _,_quest in ipairs(assess_quests) do
			if quest_helper.HasDoneQuest(_player.inst, _quest) then
				table.insert(quip_tags, _quest .. "_complete")
			elseif quest_helper:IsQuestActive(_player.inst, _quest) then
				table.insert(quip_tags, _quest .. "_active")
			else
				table.insert(quip_tags, _quest .. "_notstarted")
			end
		end]]

		cx:Quip("giver", quip_tags)
		cx:End()
	end)


return Q
