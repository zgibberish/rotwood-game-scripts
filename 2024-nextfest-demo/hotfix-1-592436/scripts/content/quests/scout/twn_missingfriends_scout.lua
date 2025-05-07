local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local berna_chats = require("strings.strings_npc_scout").QUESTS.twn_chat_scout.missing_friends.BERNA_ONLY
local hamish_chats = require("strings.strings_npc_scout").QUESTS.twn_chat_scout.missing_friends.HAMISH_ONLY
local berna_and_hamish_chats = require("strings.strings_npc_scout").QUESTS.twn_chat_scout.missing_friends.BERNA_AND_HAMISH
--for "any" chats you could have one, both, or neither of the missing NPCs
local any_chats = require("strings.strings_npc_scout").QUESTS.twn_chat_scout.missing_friends.ANY
local quip_strings = require("strings.strings_npc_scout").QUIPS

local function GetScoutLevel(inst)
	-- Scout level is currently global: only one scout per player.
	return TheSaveSystem.friends:GetValue("scout") or 1
end

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.NORMAL)
	--:SetIsUnimportant()

Q:SetRateLimited(true)

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForPrefab("npc_scout")

------OBJECTIVE DECLARATIONS------
--UNLOCK VIA NUMBER OF RUNS--
	--missing berna only, unlocks run 5
	Q:AddObjective("flitts_morale")
		:OnActivate(function(quest)
			if quest_helper.AlreadyHasCharacter("armorsmith") then
				quest:Complete("flitts_morale")
			end
		end)
		:OnEvent("playerentered", function(quest)
			-- runs every room
			if quest_helper.AlreadyHasCharacter("armorsmith") then
				quest:Complete("flitts_morale")
			end
		end)

	--missing berna only, unlocks run 6
	Q:AddObjective("itch_cream")
		:OnActivate(function(quest)
			if quest_helper.AlreadyHasCharacter("armorsmith") then
				quest:Complete("itch_cream")
			end
		end)
		:OnEvent("playerentered", function(quest)
			-- runs every room
			if quest_helper.AlreadyHasCharacter("armorsmith") then
				quest:Complete("itch_cream")
			end
		end)

	--missing both, unlocks run 15
	Q:AddObjective("no_bath")
		:OnActivate(function(quest)
			if quest_helper.AlreadyHasCharacter("armorsmith") or quest_helper.AlreadyHasCharacter("blacksmith") then
				quest:Complete("no_bath")
			end
		end)
		:OnEvent("playerentered", function(quest)
			-- runs every room
			if quest_helper.AlreadyHasCharacter("armorsmith") or quest_helper.AlreadyHasCharacter("blacksmith") then
				quest:Complete("no_bath")
			end
		end)

	--missing hamish only, unlocks run 16
	Q:AddObjective("hamishs_book")
		:OnActivate(function(quest)
			if quest_helper.AlreadyHasCharacter("blacksmith") then
				quest:Complete("hamishs_book")
			end
		end)
		:OnEvent("playerentered", function(quest)
			-- runs every room
			if quest_helper.AlreadyHasCharacter("blacksmith") then
				quest:Complete("hamishs_book")
			end
		end)

--UNLOCK IN COMPLETION ORDER--
	--missing both
	Q:AddObjective("who_am_i_looking_for")
		:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
		:OnActivate(function(quest)
			if quest_helper.AlreadyHasCharacter("armorsmith") or quest_helper.AlreadyHasCharacter("blacksmith") then
				quest:Complete("who_am_i_looking_for")
			end
		end)
		:OnEvent("playerentered", function(quest)
			-- runs every room
			if quest_helper.AlreadyHasCharacter("armorsmith") or quest_helper.AlreadyHasCharacter("blacksmith") then
				quest:Complete("who_am_i_looking_for")
			end
		end)
		:OnComplete(function(quest)
			quest:ActivateObjective("risk_assessment")
		end)

	--missing berna only
	Q:AddObjective("risk_assessment")
		:OnActivate(function(quest)
			if quest_helper.AlreadyHasCharacter("armorsmith") then
				quest:Complete("risk_assessment")
			end
		end)
		:OnEvent("playerentered", function(quest)
			-- runs every room
			if quest_helper.AlreadyHasCharacter("armorsmith") then
				quest:Complete("risk_assessment")
			end
		end)
		:OnComplete(function(quest)
			quest:ActivateObjective("no_armorsmith_in_camp")
		end)

	--missing berna only
	Q:AddObjective("no_armorsmith_in_camp")
		:OnActivate(function(quest)
			if quest_helper.AlreadyHasCharacter("armorsmith") then
				quest:Complete("no_armorsmith_in_camp")
			end
		end)
		:OnEvent("playerentered", function(quest)
			-- runs every room
			if quest_helper.AlreadyHasCharacter("armorsmith") then
				quest:Complete("no_armorsmith_in_camp")
			end
		end)
		:OnComplete(function(quest)
			if not quest:IsComplete("tea") then
				quest:ActivateObjective("tea")
			end
			quest:ActivateObjective("smushed_rations")
			quest:ActivateObjective("cards")
		end)

	--any combination
	Q:AddObjective("cards")

	--missing both
	Q:AddObjective("tea")
		:OnActivate(function(quest)
			if quest_helper.AlreadyHasCharacter("armorsmith") or quest_helper.AlreadyHasCharacter("blacksmith") then
				quest:Complete("tea")
			end
		end)
		:OnEvent("playerentered", function(quest)
			-- runs every room
			if quest_helper.AlreadyHasCharacter("armorsmith") or quest_helper.AlreadyHasCharacter("blacksmith") then
				quest:Complete("tea")
			end
		end)
		:OnComplete(function(quest)
			-- HELLOWRITER: This was causing an infinite loop if you use
			-- d_quickstart(1) and start a run or load that save. Objective tea
			-- activates no_armorsmith_in_camp and no_armorsmith_in_camp
			-- activates tea. Since they complete themselves in OnActivate,
			-- they keep activating each other endlessly. I think they should
			-- probably guard their convos with AlreadyHasCharacter instead of
			-- completing themselves, but I'm not entirely sure of the desired
			-- behaviour. For now, checking inactive to prevent the loop.
			if not quest:IsComplete("no_armorsmith_in_camp") then
				quest:ActivateObjective("no_armorsmith_in_camp")
			end
		end)

	--any combination
	Q:AddObjective("smushed_rations")

------CONVERSATIONS AND QUESTS------

--MISSING BERNA ONLY CHATS--
Q:OnTownChat("risk_assessment", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:ForbiddenWorldFlags("wf_town_has_armorsmith")
	:Strings(berna_chats.risk_assessment)
	:Fn(function(cx)
		cx:Talk("TALK")
		quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 5)
		cx.quest:Complete("risk_assessment")
	end)

Q:OnTownChat("no_armorsmith_in_camp", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:ForbiddenWorldFlags("wf_town_has_armorsmith")
	:Strings(berna_chats.no_armorsmith_in_camp)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx:End()
		cx.quest:Complete("no_armorsmith_in_camp")
		quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 5)
	end)

Q:OnTownChat("flitts_morale", "giver", function(quest, node, sim)
		local num_runs = quest:GetPlayer().components.progresstracker:GetValue("total_num_runs") or 0
		return (num_runs >= 5)
	end)
	:SetPriority(Convo.PRIORITY.NORMAL)
	:ForbiddenWorldFlags("wf_town_has_armorsmith")
	:Strings(berna_chats.flitts_morale)
	:Fn(function(cx)
		local function EndConvo()
			cx:End()
			quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 5)
			cx.quest:Complete("flitts_morale")
		end
		cx:Talk("TALK")
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1A_RESPONSE")
				EndConvo()
			end)
		cx:Opt("OPT_1B")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1B_RESPONSE")
				EndConvo()
			end)
	end)

Q:OnTownChat("itch_cream", "giver", function(quest, node, sim)
		local num_runs = quest:GetPlayer().components.progresstracker:GetValue("total_num_runs") or 0
		return (num_runs >= 6)
	end)
	:SetPriority(Convo.PRIORITY.NORMAL)
	:ForbiddenWorldFlags("wf_town_has_armorsmith")
	:Strings(berna_chats.itch_cream)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx:End()
		cx.quest:Complete("itch_cream")
		quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 5)
	end)

--MISSING HAMISH ONLY CHATS--
Q:OnTownChat("hamishs_book", "giver", function(quest, node, sim)
		local num_runs = quest:GetPlayer().components.progresstracker:GetValue("total_num_runs") or 0
		return (num_runs >= 16)
	end)
	:SetPriority(Convo.PRIORITY.NORMAL)
	:ForbiddenWorldFlags("wf_town_has_blacksmith")
	:Strings(hamish_chats.hamishs_book)
	:Fn(function(cx)
		local function EndConvo()
			quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 5)
			cx.quest:Complete("hamishs_book")
		end
		cx:Talk("TALK")
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1A_RESPONSE")
			end)
		cx:AddEnd("OPT_1B")
			:MakePositive()
			:Fn(function()
				EndConvo()
			end)
	end)

--MISSING BERNA AND HAMISH CHATS--
Q:OnTownChat("who_am_i_looking_for", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:ForbiddenWorldFlags("wf_town_has_armorsmith", "wf_town_has_blacksmith")
	:Strings(berna_and_hamish_chats.who_am_i_looking_for)
	:Fn(function(cx)
		local function CompleteObjective()
			quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 5)
			cx.quest:Complete("who_am_i_looking_for")
		end

		local function AddEndBtn(btnStr, response)
			cx:AddEnd("OPT_2D")
				:MakePositive()
				:Fn(function()
					cx:Talk("OPT2D_RESPONSE")
					CompleteObjective()
				end)
		end

		local function BtnMenu(clicked2A, clicked2B, clicked2C, clicked3C)
			if not clicked2A then
				if not clicked2B then
					if not clicked2C then
						cx:Opt("OPT_2A")
							:MakePositive()
							:Fn(function()
								clicked2A = true
								cx:Talk("OPT2A_RESPONSE")

								BtnMenu(clicked2A, clicked2B, clicked2C, clicked3C)
							end)
					else
						cx:Opt("OPT_2A_ALT2")
						:MakePositive()
						:Fn(function()
							clicked2A = true
							cx:Talk("OPT2A_RESPONSE")

							BtnMenu(clicked2A, clicked2B, clicked2C, clicked3C)
						end)
					end
				else
					cx:Opt("OPT_2A_ALT")
						:MakePositive()
						:Fn(function()
							clicked2A = true
							cx:Talk("OPT2A_RESPONSE")

							BtnMenu(clicked2A, clicked2B, clicked2C, clicked3C)
						end)
				end
			end

			if not clicked2B then
				if not clicked2A then
					cx:Opt("OPT_2B")
						:MakePositive()
						:Fn(function()
							clicked2B = true
							cx:Talk("OPT2B_RESPONSE")

							BtnMenu(clicked2A, clicked2B, clicked2C, clicked3C)
						end)
				else
					cx:Opt("OPT_2B_ALT")
						:MakePositive()
						:Fn(function()
							clicked2B = true
							cx:Talk("OPT2B_RESPONSE")

							BtnMenu(clicked2A, clicked2B, clicked2C, clicked3C)
						end)
				end
			end

			if not clicked2C then
				cx:Opt("OPT_2C")
					:MakePositive()
					:Fn(function()
						clicked2C = true
						cx:Talk("OPT2C_RESPONSE")

						cx:Opt("OPT_3A")
							:MakePositive()
							:Fn(function()
								cx:Talk("OPT3A_RESPONSE")
								BtnMenu(clicked2A, clicked2B, clicked2C, clicked3C)
							end)
						cx:Opt("OPT_3B")
							:MakePositive()
							:Fn(function()
								cx:Talk("OPT3B_RESPONSE")
								BtnMenu(clicked2A, clicked2B, clicked2C, clicked3C)
							end)
						cx:Opt("OPT_3C")
							:MakePositive()
							:Fn(function()
								clicked3C = true
								cx:Talk("OPT3C_RESPONSE")
								BtnMenu(clicked2A, clicked2B, clicked2C, clicked3C)
							end)
					end)
			end
		print("--------------------------------------------------------")
		print(clicked2C)
		print(clicked3C)
			if not clicked3C then
				if not clicked2C then
					AddEndBtn("OPT_2D", "OPT2D_RESPONSE")
				else
					AddEndBtn("OPT_2D_ALT", "OPT2D_RESPONSE")
				end
			else
				AddEndBtn("OPT_2D_ALT", "OPT2D_RESPONSE_ALT")
			end
		end

		--CONVO LOGIC START--
		cx:Talk("TALK")
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1A_RESPONSE")
				BtnMenu(false, false, false, false)
			end)
		cx:AddEnd("OPT_1B")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1B_RESPONSE")
				CompleteObjective()
			end)
	end)

Q:OnTownChat("tea", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:ForbiddenWorldFlags("wf_town_has_armorsmith", "wf_town_has_blacksmith")
	:Strings(berna_and_hamish_chats.tea)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx:End()
		cx.quest:Complete("tea")
		quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 5)
	end)

Q:OnTownChat("no_bath", "giver", function(quest, node, sim)
		local num_runs = quest:GetPlayer().components.progresstracker:GetValue("total_num_runs") or 0
		return (num_runs >= 15)
	end)
	:SetPriority(Convo.PRIORITY.NORMAL)
	:ForbiddenWorldFlags("wf_town_has_armorsmith", "wf_town_has_blacksmith")
	:Strings(berna_and_hamish_chats.no_bath)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx:End()
		cx.quest:Complete("no_bath")
		quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 5)
	end)

--ANY COMBINATION CHATS--
Q:OnTownChat("smushed_rations", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:Strings(any_chats.smushed_rations)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx:End()
		cx.quest:Complete("smushed_rations")
		quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 5)
	end)

Q:OnTownChat("cards", "giver")
	:SetPriority(Convo.PRIORITY.NORMAL)
	:Strings(any_chats.cards)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx:End()
		cx.quest:Complete("cards")
		quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 5)
	end)

return Q
