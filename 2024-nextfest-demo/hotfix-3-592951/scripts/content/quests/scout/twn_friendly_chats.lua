local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"
local quest_strings = require("strings.strings_npc_scout").QUESTS.twn_friendlychat
local quip_strings = require("strings.strings_npc_scout").QUIPS.twn_friendlychat

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.LOWEST)
	:SetIsUnimportant()

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForPrefab("npc_scout")

Q:AddCast("berna")
	:FilterForPrefab("npc_armorsmith")

------OBJECTIVE DECLARATIONS------
Q:AddObjective("twn_friendlychat")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

--flitt backstory stuff--

--(respond to recruiting a villager)--

Q:AddObjective("pf_actively_recruited_blacksmith")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("pf_passively_recruited_blacksmith")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

--

--[[Q:AddObjective("pf_actively_recruited_armorsmith")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

	Q:AddObjective("pf_passively_recruited_armorsmith")
		:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)]]

--

Q:AddObjective("pf_actively_recruited_dojo")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("pf_passively_recruited_dojo")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

--

Q:AddObjective("pf_actively_recruited_cook")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("pf_passively_recruited_cook")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

--

Q:AddObjective("pf_actively_recruited_apothecary")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("pf_passively_recruited_apothecary")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

--

Q:AddObjective("pf_actively_recruited_researcher")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("pf_passively_recruited_researcher")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

------CONVERSATIONS AND QUESTS------

local function MenuLoop(cx, available_convo_count, completed_chat_count)
	local player = cx.quest:GetPlayer()

	--Each convo checks how many options are available on the menu and only adds itself if there than the (cap - 1) so the menu doesn't get too crowded with options
	--The reason it's (cap - 1) and not just (cap) is because the final option will always be the exit conversation button
	local opt_cap = 4

	local function RestartMenuLoop(cx, completed_chat_count, objective_name)
		completed_chat_count = completed_chat_count + 1
		cx.quest:Complete(objective_name)
		MenuLoop(cx, 0, completed_chat_count)
	end

	--VILLAGER RECRUITMENT CHATS--
		--Blacksmith
		--prevent more than 4 convo topics from ever appearing on the list (5th option will be the backout button)
		if available_convo_count < (opt_cap - 1) and cx.quest:GetObjectiveState("pf_actively_recruited_blacksmith") == QUEST_OBJECTIVE_STATE.s.ACTIVE then
			if TheWorld:IsFlagUnlocked("wf_town_has_blacksmith") then
				available_convo_count = available_convo_count + 1
				cx:Opt("BLACKSMITH_QUESTION")
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("BLACKSMITH_TALK")
						RestartMenuLoop(cx, completed_chat_count, "pf_actively_recruited_blacksmith")
				end)
			end
		end

		--Armorsmith
		--prevent more than 4 convo topics from ever appearing on the list (5th option will be the backout button)
		--[[if available_convo_count < (opt_cap - 1) and cx.quest:GetObjectiveState("pf_actively_recruited_armorsmith") == QUEST_OBJECTIVE_STATE.s.ACTIVE then
			if TheWorld:IsFlagUnlocked("wf_town_has_armorsmith") then
				available_convo_count = available_convo_count + 1
				cx:Opt("ARMORSMITH_QUESTION")
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("ARMORSMITH_TALK")
						RestartMenuLoop(cx, completed_chat_count, "pf_actively_recruited_armorsmith")
				end)
			end
		end]]

		--Dojo Master
		if available_convo_count < (opt_cap - 1) and cx.quest:GetObjectiveState("pf_actively_recruited_dojo") == QUEST_OBJECTIVE_STATE.s.ACTIVE then
			if TheWorld:IsFlagUnlocked("wf_town_has_dojo") then
				available_convo_count = available_convo_count + 1
				cx:Opt("DOJO_QUESTION")
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("DOJO_TALK")
						RestartMenuLoop(cx, completed_chat_count, "pf_actively_recruited_dojo")
				end)
			end
		end

		--Cook
		if available_convo_count < (opt_cap - 1) and cx.quest:GetObjectiveState("pf_actively_recruited_cook") == QUEST_OBJECTIVE_STATE.s.ACTIVE then
			if TheWorld:IsFlagUnlocked("wf_town_has_cook") then
				available_convo_count = available_convo_count + 1
				cx:Opt("COOK_QUESTION")
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("COOK_TALK")
						RestartMenuLoop(cx, completed_chat_count, "pf_actively_recruited_cook")
				end)
			end
		end

		--Apothecary
		if available_convo_count < (opt_cap - 1) and cx.quest:GetObjectiveState("pf_actively_recruited_apothecary") == QUEST_OBJECTIVE_STATE.s.ACTIVE then
			if TheWorld:IsFlagUnlocked("wf_town_has_apothecary") then
				available_convo_count = available_convo_count + 1
				cx:Opt("APOTHECARY_QUESTION")
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("APOTHECARY_TALK")
						RestartMenuLoop(cx, completed_chat_count, "pf_actively_recruited_apothecary")
				end)
			end
		end

		--Researcher
		if available_convo_count < (opt_cap - 1) and cx.quest:GetObjectiveState("pf_actively_recruited_researcher") == QUEST_OBJECTIVE_STATE.s.ACTIVE then
			if TheWorld:IsFlagUnlocked("wf_town_has_research") then
				available_convo_count = available_convo_count + 1
				cx:Opt("RESEARCHER_QUESTION")
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("RESEARCHER_TALK")
						RestartMenuLoop(cx, completed_chat_count, "pf_actively_recruited_researcher")
				end)
			end
		end
	--END VILLAGER RECRUITMENT CHATS--

	--HANDLE EXIT CONVO OPTION--
	if available_convo_count == 0 then
		--technically an error state-- happens if there are no available chats but the player also didnt complete any chats in this dialogue event (shouldnt be able to happen)
		if completed_chat_count == 0 then
			cx:Talk("EMPTY_LIST")
			cx:End()
		--end chat normally
		else
			cx:AddEnd("END_CHITCHAT")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("END_CHITCHAT_RESPONSE")
			end)
		end

		
		player:LockFlag("pf_friendlychat_active") --turn off friendly chats
	else
		cx:AddEnd("END_CHITCHAT")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("END_CHITCHAT_RESPONSE")
		end)
	end
end

--friend_chat_active is a flag that gets flipped on each time a new friend conversation is unlocked
	--once a friendly chat gets played its removed from the rotation forever
Q:OnTownChat("twn_friendlychat", "giver", function(quest) return quest:GetPlayer():IsFlagUnlocked("pf_friendlychat_active") end) --FLAG allows Flitt to comment on recruiting a character == "TRUE"
	:SetPriority(Convo.PRIORITY.LOWEST)
	:Strings(quest_strings)
	:Fn(function(cx)
		cx:Talk("INITIATE_CHITCHAT")

		--[[ 
			the integers in MenuLoop here represent
				-how many chats are both unlocked and appearing on the player-facing list of options
			and
				-how many chats has the player cycled through in this dialogue event
		]]
		MenuLoop(cx, 0, 0) --(both start at 0)

	end)

return Q
