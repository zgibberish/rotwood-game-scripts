local Convo = require "questral.convo"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local primary_quest_strings = require ("strings.strings_npc_blacksmith").QUESTS.primary_dgn_meeting_blacksmith
local town_intro_talk_strings = require ("strings.strings_npc_blacksmith").QUESTS.twn_function_unlocked
local secondary_quest_strings = require ("strings.strings_npc_blacksmith").QUESTS.secondary_dgn_meeting_blacksmith
local tertiary_quest_strings = require ("strings.strings_npc_blacksmith").QUESTS

------QUEST SETUP------

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGHEST)
	:TitleString(primary_quest_strings.TITLE)
	:SetIsImportant()

Q:SetRateLimited(false)

Q:UnlockWorldFlagsOnComplete{"wf_town_has_blacksmith"}

Q:UnlockPlayerFlagsOnComplete{
	"pf_met_blacksmith", --has this player ever interacted with the blacksmith before
	"pf_actively_recruited_blacksmith", --this tag is for unlocking flitt friendly chats
}

function Q:Quest_Complete()
	-- spawn next quest in chain
	self:GetQuestManager():SpawnQuest("twn_shop_weapon")
	self:GetQuestManager():SpawnQuest("twn_gem_intro")
end

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForPrefab("npc_blacksmith")

--------------- Meet Hamish in dungeon, invite him back to camp ---------------

-- Objectives

Q:AddObjective("meet_in_dungeon")
	:NetworkSyncStates{QUEST_OBJECTIVE_STATE.s.COMPLETED}
	:AppearInDungeon_Hype_Exclusive(function(quest)
		return false -- With the shop changes, Hamish currently has no functionality. Temporarily disabled.

		-- local has_hamish = TheWorld:IsFlagUnlocked("wf_town_has_blacksmith") -- the town already has hamish
		-- local in_owl_forest = quest_helper.IsInDungeon("owlitzer_forest") -- is in the owl forest
		-- return not has_hamish and in_owl_forest
	end)
	:UnlockWorldFlagsOnComplete{"wf_town_has_blacksmith"} -- the blacksmith will now appear in this player's town
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:LockRoom()
	:OnComplete(function(quest, playerID)
		quest_helper.UnlockRoom(quest)
		TheDungeon.progression.components.runmanager:SetHasMetTownNPCInDungeon(true)

        local local_players = TheNet:GetLocalPlayerList()
        if table.contains(local_players, playerID) then
            -- was this quest completed by a local player?
            quest:ActivateObjective("town_intro_talked")
        else
            -- was this quest completed by a remote player?
            quest:ActivateObjective("town_intro_no_talk")
        end

        quest:Cancel("meet_in_town")
	end)

-- You saw this NPC in the dungeon, but weren't the one to recruit them.
Q:AddObjective("town_intro_no_talk")
    :OnComplete(function(quest)
        quest:Complete()
    end)

-- You saw this NPC in the dungeon and were the one to recruit them.
Q:AddObjective("town_intro_talked")
    :OnComplete(function(quest)
        quest:Complete()
    end)

--- Chats

Q:OnDungeonChat("meet_in_dungeon", "giver", function(...) return quest_helper.Filter_FirstMeetingNPC(Quest.Filters.InDungeon_Hype, ...) end)
	:FlagAsTemp()
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(primary_quest_strings.invite_to_town)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx:Talk("OPT1_RESPONSE")
		cx:Opt("OPT_2A")
			:MakePositive()
			:Fn(function()
				cx:Talk("TALK2")
				cx:Talk("OPT2A_RESPONSE")
			end)
		cx:Opt("OPT_2B")
			:MakePositive()
			:Fn(function()
				cx:Talk("TALK2")
				cx:Talk("OPT2B_RESPONSE")
			end)
		cx:JoinAllOpt_Fn(function()
			cx:Talk("TALK3")
			cx.quest:Complete("meet_in_dungeon")
		end)
	end)

Q:OnTownChat("town_intro_no_talk", "giver", Quest.Filters.InTown)
	:FlagAsTemp()
	:Strings(secondary_quest_strings)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Fn(function(cx)

		local function Opt3B()
			cx:AddEnd("OPT_3B")
				:MakePositive()
				:Fn(function()
					cx.quest:Complete("town_intro_no_talk")
					cx:Talk("OPT3B_RESPONSE")
				end)
		end

		cx:Talk("TALK")

		cx:Opt("OPT_1A")
			:MakePositive()
		cx:Opt("OPT_1B")
			:MakePositive()

		--JoinAllOpt_Fn bottlenecks all the options above into this route
		cx:JoinAllOpt_Fn(function(cx)
			cx:Talk("TALK2")

			cx:Opt("OPT_2")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("TALK3")
					cx:Opt("OPT_3A")
						:MakePositive()
						:Fn(function()
							cx:Talk("OPT3A_RESPONSE")

							--OPT_3B
							Opt3B()
						end)

					--OPT_3B
					Opt3B()
				end)
		end)
	end)

Q:OnTownChat("town_intro_talked", "giver", Quest.Filters.InTown)
	:FlagAsTemp()
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(town_intro_talk_strings)
	:Fn(function(cx)
		--button is reused a few times in "talk_in_town" (this is the one that places the station and ends the convo)
		local function EndConvoOpt(cx)
			cx:AddEnd("OPT_3")
				:Fn(function(cx)
					cx.quest:Complete("town_intro_talked")
				end)
		end
		cx:Talk("TALK")
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1A_RESPONSE")
				cx:Opt("OPT_2")
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("OPT2_RESPONSE")
						EndConvoOpt(cx)
					end)
				EndConvoOpt(cx)
			end)
		EndConvoOpt(cx)
	end)

--------------- Hamish is in the town, fulfill his request ---------------

Q:AddVar("request_material", "konjur_soul_lesser")

-- Temp Materials. Something from the miniboss of each zone.
-- Ideally this is something unique from Alphonse in each dungeon
Q:AddVar("treemon_material", "yammo_stem")
Q:AddVar("owlitzer_material", "gourdo_skin")
Q:AddVar("bandicoot_material", "floracrane_beak")

-- Alternate Entrance to this quest.
-- Happens when Hamish was already recruited inside the dungeon by other players in the town.
Q:AddObjective("meet_in_town")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:UnlockWorldFlagsOnComplete{"wf_town_has_blacksmith"} -- the blacksmith will now appear in this player's town
	:UnlockPlayerFlagsOnComplete{
		"pf_met_blacksmith", --has this player ever interacted with the blacksmith before
		"pf_passively_recruited_blacksmith", --this tag is for unlocking flitt friendly chats
		"pf_friendlychat_active", --FLAG allows Flitt to comment on recruiting a character
	}
	:OnComplete(function(quest)
		quest:Cancel("meet_in_dungeon")
		quest:ActivateObjective("hand_in_stone")
		quest:ActivateObjective("stone_fetch_reminder")
	end)

--give hamish a corestone to unlock the shop function
Q:AddObjective("stone_fetch_reminder")

--give hamish a corestone to unlock the shop function
Q:AddObjective("hand_in_stone")
	:OnComplete(function(quest)
		quest:Complete()
	end)

-- Alternate Entrance to this quest.
Q:OnTownChat("meet_in_town", "giver", function(quest, node, sim) return Quest.Filters.InTown(quest, node, sim) end)
	:FlagAsTemp()
	:Strings(tertiary_quest_strings.tertiary_twn_meeting_blacksmith)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Fn(function(cx)

		local function EndConditions()
			cx:End()
			cx.quest:Complete("meet_in_town")
		end

		--end of a conversation with an arrow icon
		local function OptAddEnd(btn_str)
			cx:AddEnd(btn_str)
				:MakePositive()
				:Fn(function()
					cx:Talk("END")
					EndConditions()
				end)
		end

		local function OptMenu(Opt2B_clicked, Opt3A_clicked)
			--if the player already has a corestone, let them hand it in without having to do another convo
			if quest_helper.HasFetchMaterialCx(cx, "meet_in_town") then
				cx:Opt("OPT_2A")
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT2A_RESPONSE")
						cx.quest:ActivateObjective("hand_in_stone")
						quest_helper.DeliverFetchMaterial(cx)
						cx.quest:Complete("hand_in_stone")
						EndConditions()
					end)
			end

			--ask why you need a corestone to forge
			if Opt2B_clicked == false then
				--opt to explain why a stones needed
				cx:Opt("OPT_2B")
					:MakePositive()
					:Fn(function(cx)
						Opt2B_clicked = true
						cx:Talk("OPT2B_RESPONSE")
						OptMenu(Opt2B_clicked, Opt3A_clicked)
					end)
				--end convo
				OptAddEnd("OPT_2C")
			else
				--more detailed follow up on why you need a corestone
				if Opt3A_clicked == false then
					cx:Opt("OPT_3A")
						:MakePositive()
						:Fn(function()
							Opt3A_clicked = true
							cx:Talk("OPT3A_RESPONSE")
							OptMenu(Opt2B_clicked, Opt3A_clicked)
						end)
					--end convo
				end
				OptAddEnd("OPT_3B")
			end
		end

		--START OF CONVO CODE--
		cx:Talk("TALK")
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1A_RESPONSE")
				cx:Opt("OPT_1B")
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("OPT1B_RESPONSE")
						OptMenu(false, false)
					end)
			end)
		cx:Opt("OPT_1B")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1B_RESPONSE")
				OptMenu(false, false)
			end)
	end)

Q:OnTownChat("stone_fetch_reminder", "giver", function(quest, node, sim) return Quest.Filters.InTown and not quest_helper.HasFetchMaterial(quest, node, sim, "stone_fetch_reminder") end)
	:FlagAsTemp()
	:SetPriority(Convo.PRIORITY.HIGH)
	:Strings(tertiary_quest_strings.tertiary_twn_meeting_blacksmith.stone_fetch_reminder)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx:End()
	end)

Q:OnTownChat("hand_in_stone", "giver", function(quest, node, sim) return Quest.Filters.InTown and quest_helper.HasFetchMaterial(quest, node, sim, "hand_in_stone") end)
	:FlagAsTemp()
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(tertiary_quest_strings.tertiary_twn_meeting_blacksmith.hand_in_stone)
	:Fn(function(cx)
		local function ConvoEnd(response_str)
			cx:Talk(response_str)
			cx:End()
			cx.quest:Complete("hand_in_stone")
		end

		cx:Talk("TALK")

		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function(cx)
				quest_helper.DeliverFetchMaterial(cx)
				ConvoEnd("OPT1A_RESPONSE")
			end)

		cx:AddEnd("OPT_1B") --exit out without giving the stone, shouldnt complete the objective
	end)

return Q
