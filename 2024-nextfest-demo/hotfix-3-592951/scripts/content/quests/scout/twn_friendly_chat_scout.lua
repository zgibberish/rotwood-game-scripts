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
	:OnComplete(function(quest)
		quest:ActivateObjective("ask_flitt_about_toot")
    end)

Q:AddObjective("ask_flitt_about_toot")

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

--dungeon npc conversations

Q:AddObjective("pf_post_magpie_friendlychat")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("pf_identified_alphonse")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

--


------CONVERSATIONS AND QUESTS------

local function MenuLoop(cx, available_convo_count, completed_chat_count)
	local player = cx.quest:GetPlayer()

	--Each convo checks how many options are available on the menu and only adds itself if there than the (cap - 1) so the menu doesn't get too crowded with options
	--The reason it's (cap - 1) and not just (cap) is because the final option will always be the exit conversation button
	local opt_cap = 4

	local function CheckCanAddButton(objective)
		if available_convo_count < (opt_cap - 1) and cx.quest:GetObjectiveState(objective) == QUEST_OBJECTIVE_STATE.s.ACTIVE then
			available_convo_count = available_convo_count + 1
			return true
		else
			return false
		end
	end

	local function RestartMenuLoop(cx, completed_chat_count, objective_name)
		completed_chat_count = completed_chat_count + 1
		cx.quest:Complete(objective_name)
		MenuLoop(cx, 0, completed_chat_count)
	end

	--VILLAGER RECRUITMENT CHATS--
		--Blacksmith
		--prevent more than 4 convo topics from ever appearing on the list (5th option will be the backout button)
		if CheckCanAddButton("pf_actively_recruited_blacksmith") and TheWorld:IsFlagUnlocked("wf_town_has_blacksmith") then
			cx:Opt("BLACKSMITH_QUESTION")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("BLACKSMITH_TALK")
					RestartMenuLoop(cx, completed_chat_count, "pf_actively_recruited_blacksmith")
			end)
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
		if CheckCanAddButton("pf_actively_recruited_dojo") and TheWorld:IsFlagUnlocked("wf_town_has_dojo") then
			cx:Opt("DOJO_QUESTION")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("DOJO_TALK")
					RestartMenuLoop(cx, completed_chat_count, "pf_actively_recruited_dojo")
			end)
		end

		if CheckCanAddButton("ask_flitt_about_toot") and TheWorld:IsFlagUnlocked("wf_town_has_dojo") then
			cx:Opt("DOJO_QUESTION2")
				:MakePositive()
				:Fn(function(cx)
					q = "DOJO_TALK2."

					cx:Talk(q .. "TALK")

					cx:Opt(q .. "OPT_1A")
						:MakePositive()
						:Fn(function()
							cx:Talk(q .. "OPT1A_RESPONSE")
						end)
					cx:Opt(q .. "OPT_1B")
						:MakePositive()
						:Fn(function()
							cx:Talk(q .. "OPT1B_RESPONSE")
						end)

					cx:JoinAllOpt_Fn(function()
						cx:Talk(q .. "TALK2")

						cx:Opt(q .. "OPT_2A")
							:MakePositive()
							:Fn(function()
								cx:Talk(q .. "OPT2A_RESPONSE")
							end)
						cx:Opt(q .. "OPT_2B")
							:MakePositive()
							:Fn(function()
								cx:Talk(q .. "OPT2B_RESPONSE")
							end)

						cx:JoinAllOpt_Fn(function()
							cx:Talk(q .. "TALK3")
							
							cx:Opt(q .. "OPT_3A")
								:MakePositive()
							cx:Opt(q .. "OPT_3B")
								:MakePositive()

							cx:JoinAllOpt_Fn(function()
								cx:Talk(q .. "TALK4")
								cx:Opt(q .. "OPT_4")
									:MakePositive()
									:Fn(function()
										cx:Talk(q .. "OPT4_RESPONSE")

										cx:Opt(q .. "OPT_5A")
											:MakePositive()
											:Fn(function()
												cx:Talk(q .. "OPT5A_RESPONSE")
											end)
										cx:Opt(q .. "OPT_5B")
											:MakePositive()
											:Fn(function()
												cx:Talk(q .. "OPT5B_RESPONSE")
											end)

										cx:JoinAllOpt_Fn(function()
											cx:Opt(q .. "OPT_END")
												:MakePositive()
												:Fn(function()
													cx:Talk(q .. "END_RESPONSE")
												end)
										end)
									end)
							end)
						end)
					end)
					RestartMenuLoop(cx, completed_chat_count, "pf_actively_recruited_dojo")
				end)
		end

		--Cook
		if CheckCanAddButton("pf_actively_recruited_cook") and TheWorld:IsFlagUnlocked("wf_town_has_cook") then
			cx:Opt("COOK_QUESTION")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("COOK_TALK")
					RestartMenuLoop(cx, completed_chat_count, "pf_actively_recruited_cook")
			end)
		end

		--Apothecary
		if CheckCanAddButton("pf_actively_recruited_apothecary") and TheWorld:IsFlagUnlocked("wf_town_has_apothecary") then
			cx:Opt("APOTHECARY_QUESTION")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("APOTHECARY_TALK")
					RestartMenuLoop(cx, completed_chat_count, "pf_actively_recruited_apothecary")
			end)
		end

		--Researcher
		if CheckCanAddButton("pf_actively_recruited_researcher") and TheWorld:IsFlagUnlocked("wf_town_has_research") then
			cx:Opt("RESEARCHER_QUESTION")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("RESEARCHER_TALK")
					RestartMenuLoop(cx, completed_chat_count, "pf_actively_recruited_researcher")
			end)
		end
	--END VILLAGER RECRUITMENT CHATS--

		--Flitt talks about how he met Toot
		if CheckCanAddButton("ask_flitt_about_toot") then
			cx:Opt("RESEARCHER_QUESTION")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("RESEARCHER_TALK")
					RestartMenuLoop(cx, completed_chat_count, "ask_flitt_about_toot")
			end)
		end

	--DUNGEON NPC CHATS--
		--Alphonse (flitt encourages you to talk to berna about him)
		if CheckCanAddButton("pf_post_magpie_friendlychat") and TheWorld:IsFlagUnlocked("wf_town_has_armorsmith") then
			cx:Opt("ALPHONSE1_QUESTION")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("ALPHONSE1.TALK")
					cx:Opt("ALPHONSE1.OPT1")
						:MakePositive()
						:Fn(function()
							RestartMenuLoop(cx, completed_chat_count, "pf_post_magpie_friendlychat")
						end)
			end)
		end

	--[[
		--Alphonse (opinion on alphonse after youve loearned his name)
		if available_convo_count < (opt_cap - 1) and cx.quest:GetObjectiveState("pf_identified_alphonse") == QUEST_OBJECTIVE_STATE.s.ACTIVE then
			if TheWorld:IsFlagUnlocked("wf_town_has_armorsmith") then
				available_convo_count = available_convo_count + 1
				cx:Opt("RESEARCHER_QUESTION")
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("RESEARCHER_TALK")
						RestartMenuLoop(cx, completed_chat_count, "pf_identified_alphonse")
				end)
			end
		end
	]]
	--END DUNGEON NPC CHATS--

	local function EndConvoButton()
		cx:AddEnd("END_CHITCHAT")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("END_CHITCHAT_RESPONSE")
			end)
	end

	--HANDLE EXIT CONVO OPTION--
	if available_convo_count == 0 then
		player:LockFlag("pf_friendlychat_active") --turn off friendly chats

		--technically an error state-- happens if there are no available chats but the player also didnt complete any chats in this dialogue event (shouldnt be able to happen)
		if completed_chat_count == 0 then
			cx:Talk("EMPTY_LIST")
			cx:End()
		--end chat normally
		else
			--exit out of the conversation is there are no more chats available
			EndConvoButton()
		end
	else
		--if there are chats available, this adds a button to exit out of the menu-- its always the fourth button, bottom of the menu
		EndConvoButton()
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
				-how many chats are both unlocked *and* appearing on the player-facing list of options
			and
				-how many chats has the player has cycled through in this dialogue event
		]]
		MenuLoop(cx, 0, 0) --(both start at 0)

	end)

return Q
