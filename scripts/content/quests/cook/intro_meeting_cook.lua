local Convo = require "questral.convo"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local primary_quest_strings = require ("strings.strings_npc_cook").QUESTS.primary_dgn_meeting_cook
local town_intro_talk_strings = require ("strings.strings_npc_cook").QUESTS.twn_function_unlocked
local secondary_quest_strings = require ("strings.strings_npc_cook").QUESTS.secondary_dgn_meeting_cook
local tertiary_quest_strings = require ("strings.strings_npc_cook").QUESTS.tertiary_twn_meeting_cook

------QUEST SETUP------

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGHEST)
	:SetIsImportant()
	:SetRateLimited(false)
	:TitleString(primary_quest_strings.TITLE)


Q:UnlockWorldFlagsOnComplete{"wf_town_has_cook"}

Q:UnlockPlayerFlagsOnComplete{
	"pf_met_cook", --has this player ever interacted with the cook before
	"pf_actively_recruited_cook" --this tag is for unlocking flitt friendly chats
}

function Q:Quest_Complete()
	-- spawn next quest in chain
	self:GetQuestManager():SpawnQuest("twn_shop_cook")
end

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForPrefab("npc_cook")

--------------- DUNGEON ROUTE ---------------

Q:AddObjective("meet_in_dungeon")
	:NetworkSyncStates{QUEST_OBJECTIVE_STATE.s.COMPLETED}
	:AppearInDungeon_QuestRoom_Exclusive(function(quest)
		local has_glorabelle = TheWorld:IsFlagUnlocked("wf_town_has_cook") -- the town already has glorabelle
		local can_meet_glorabelle = quest:GetPlayer():IsFlagUnlocked("pf_can_meet_cook") -- the player can meet glorabelle
		local in_owl_forest = quest_helper.IsInDungeon("owlitzer_forest") -- is in the owl forest
		return not has_glorabelle and can_meet_glorabelle and in_owl_forest
	end)
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:UnlockWorldFlagsOnComplete{"wf_town_has_cook"}
	:LockRoom()
	:OnComplete(function(quest, playerID)
		quest_helper.UnlockRoom(quest)
		TheDungeon.progression.components.runmanager:SetHasMetNPC(true)

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

Q:OnDungeonChat("meet_in_dungeon", "giver", function(...) return quest_helper.Filter_FirstMeetingNPC(Quest.Filters.InDungeon_QuestRoom, ...) end)
	:FlagAsTemp()
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(primary_quest_strings.invite_to_town)
	:Fn(function(cx)
		cx:Talk("TALK_INTRODUCE_SELF")
		cx:Opt("OPT_1A")
			:MakePositive()
		cx:Opt("OPT_1B")
			:MakePositive()
		cx:JoinAllOpt_Fn(function()
			-- both options go here

			cx:Talk("TALK_INTRODUCE_SELF2")
			cx:Opt("OPT_2A")
				:MakePositive()
			cx:Opt("OPT_2B")
				:MakePositive()
			cx:JoinAllOpt_Fn(function()
				-- then both options go here

				cx:Talk("TALK_INTRODUCE_SELF3")
				cx:Opt("OPT_3B")
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT3B_RESPONSE")
						cx:AddEnd("OPT_4")
							:MakePositive()
							:Fn(function()
								local giver = cx.quest:GetCastMember("giver")
								cx:Talk("OPT4_RESPONSE")
								cx.quest:Complete("meet_in_dungeon")
								giver.inst.components.timer:StartTimer("talk_cd", 7.5)
							end)
					end)
				cx:AddEnd("OPT_3A")
					:MakePositive()
					:Fn(function()
						local giver = cx.quest:GetCastMember("giver")
						cx:Talk("OPT3A_RESPONSE")
						cx.quest:Complete("meet_in_dungeon")
						giver.inst.components.timer:StartTimer("talk_cd", 7.5)
					end)
			end)
		end)
	end)

Q:OnTownChat("town_intro_no_talk", "giver", Quest.Filters.InTown)
	:FlagAsTemp()
	:Strings(secondary_quest_strings)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Fn(function(cx)
		local function EndConvo()
			cx:Talk("TALK3")
			cx:End()
			cx.quest:Complete("town_intro_no_talk")
		end

		cx:Talk("TALK")
		cx.quest:Complete()

		cx:Opt("OPT_1A")
			:MakePositive()
		cx:Opt("OPT_1B")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1B_RESPONSE")
			end)

		--JoinAllOpt_Fn bottlenecks all the options above into this route
		cx:JoinAllOpt_Fn(function()
			cx:Talk("TALK2")

			cx:Opt("OPT_2A")
				:MakePositive()
				:Fn(function()
					cx:Talk("OPT2A_RESPONSE")
					cx:AddEnd("OPT_2B_ALT")
						:MakePositive()
						:Fn(function()
							EndConvo()
						end)
				end)
			cx:AddEnd("OPT_2B")
				:MakePositive()
				:Fn(function()
					EndConvo()
				end)
		end)
	end)

Q:OnTownChat("town_intro_talked", "giver", Quest.Filters.InTown)
	:FlagAsTemp()
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(town_intro_talk_strings)
	:Fn(function(cx)
		local function EndConvo(response_str)
			cx:Talk(response_str)
			cx:AddEnd("OPT_4")
				:Fn(function(cx)
					cx.quest:Complete("town_intro_talked")
				end)
		end

		cx:Talk("TALK")
		cx:Opt("OPT_1")
			:MakePositive()
			:Fn(function()
				cx:Talk("TALK2")
				cx:Opt("OPT_2")
					:MakePositive()
					:Fn(function()
						cx:Talk("TALK3")
						cx:Opt("OPT_3A")
							:MakePositive()
							:Fn(function()
								EndConvo("OPT3A_RESPONSE")
							end)
						cx:Opt("OPT_3B")
							:MakePositive()
							:Fn(function()
								EndConvo("OPT3B_RESPONSE")
							end)
					end)
			end)
	end)

--------------- TOWN ROUTE ---------------

Q:AddVar("request_material", "konjur_soul_lesser")

Q:AddObjective("meet_in_town")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:UnlockWorldFlagsOnComplete{"wf_town_has_cook"} -- the cook will now appear in this player's town
	:UnlockPlayerFlagsOnComplete{
		"pf_met_cook", --has this player ever interacted with the cook before
		"pf_passively_recruited_cook", --this tag is for unlocking flitt friendly chats
		"pf_friendlychat_active", --FLAG allows Flitt to comment on recruiting a character
	}
	:OnComplete(function(quest)
		--activate next objective
		quest:Cancel("meet_in_dungeon")
		quest:ActivateObjective("hand_in_stone")
		quest:ActivateObjective("stone_fetch_reminder")
	end)

--give hamish a corestone to unlock the shop function
Q:AddObjective("stone_fetch_reminder")

--give glorabelle a corestone to unlock the shop function
Q:AddObjective("hand_in_stone")
	:OnComplete(function(quest)
		quest:Complete()
	end)

Q:OnTownChat("meet_in_town", "giver", Quest.Filters.InTown)
	:FlagAsTemp()
	:Strings(tertiary_quest_strings)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Fn(function(cx)
		local function EndConvo()
			cx:End()
			cx.quest:Complete("meet_in_town")
		end

		cx:Talk("TALK")

		cx:Opt("OPT_1A")
			:MakePositive()
		cx:Opt("OPT_1B")
			:MakePositive()

		--JoinAllOpt_Fn bottlenecks all the options above into this route
		cx:JoinAllOpt_Fn(function()
			cx:Talk("TALK2")

			cx:Opt("OPT_2A")
				:MakePositive()
			cx:Opt("OPT_2B")
				:MakePositive()

			--JoinAllOpt_Fn bottlenecks all the options above into this route
			cx:JoinAllOpt_Fn(function()
				cx:Talk("TALK3")

				local function OptMenu(opt3b_clicked)
					if quest_helper.HasFetchMaterialCx(cx, "meet_in_town") then 
						cx:Opt("OPT_3A")
							:MakePositive()
							:Fn(function(cx)
								cx:Talk("OPT3A_RESPONSE")
								cx.quest:ActivateObjective("hand_in_stone")
								quest_helper.DeliverFetchMaterial(cx)
								cx.quest:Complete("hand_in_stone")
								EndConvo()
							end)
					end

					if opt3b_clicked == false then
						cx:Opt("OPT_3B")
							:MakePositive()
							:Fn(function(cx)
								opt3b_clicked = true
								cx:Talk("OPT3B_RESPONSE")
								OptMenu(opt3b_clicked)
							end)
					end

					cx:AddEnd("OPT_3C")
						:MakePositive()
						:Fn(function(cx)
							cx:Talk("OPT3C_RESPONSE")
							EndConvo()
						end)
				end

				OptMenu(false)
			end)
		end)
	end)

Q:OnTownChat("stone_fetch_reminder", "giver", function(quest, node, sim) return Quest.Filters.InTown and not quest_helper.HasFetchMaterial(quest, node, sim, "stone_fetch_reminder") end)
	:SetPriority(Convo.PRIORITY.HIGH)
	:FlagAsTemp()
	:Strings(tertiary_quest_strings.stone_fetch_reminder)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx:End()
	end)

Q:OnTownChat("hand_in_stone", "giver", function(quest, node, sim) return Quest.Filters.InTown and quest_helper.HasFetchMaterial(quest, node, sim, "hand_in_stone") end)
	:FlagAsTemp()
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(tertiary_quest_strings.hand_in_stone)
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
		cx:AddEnd("OPT_1B")
			:MakePositive()
	end)

return Q