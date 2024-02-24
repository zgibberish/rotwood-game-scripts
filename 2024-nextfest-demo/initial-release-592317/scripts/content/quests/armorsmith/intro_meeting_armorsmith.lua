local Convo = require "questral.convo"
local Quest = require "questral.quest"
local Quip = require "questral.quip"
local biomes = require "defs.biomes"
local quest_helper = require "questral.game.rotwoodquestutil"

local primary_quest_strings = require ("strings.strings_npc_armorsmith").QUESTS.primary_dgn_meeting_armorsmith
local town_intro_talk_strings = require ("strings.strings_npc_armorsmith").QUESTS.twn_function_unlocked
local secondary_quest_strings = require ("strings.strings_npc_armorsmith").QUESTS.secondary_twn_meeting_armorsmith
local tertiary_quest_strings = require ("strings.strings_npc_armorsmith").QUESTS.tertiary_twn_meeting_armorsmith

local quip_strings = require ("strings.strings_npc_armorsmith").QUIPS

------QUEST SETUP------

local Q = Quest.CreateJob()
    :SetPriority(QUEST_PRIORITY.HIGHEST)
    :SetIsImportant()
    :TitleString(primary_quest_strings.TITLE)

Q:SetRateLimited(false)

Q:UnlockWorldFlagsOnComplete{"wf_town_has_armorsmith"}  -- the armorsmith will now appear in this player's town

Q:UnlockPlayerFlagsOnComplete{
    "pf_met_armorsmith", --has this player ever interacted with the armorsmith before
    "pf_actively_recruited_armorsmith" --this tag is for unlocking flitt friendly chats
}

function Q:Quest_Complete()
    -- spawn next quest in chain
    self:GetQuestManager():SpawnQuest("twn_armorsmith_arrival")
end

------CAST DECLARATIONS------

Q:UpdateCast("giver")
    :FilterForPrefab("npc_armorsmith")
Q:AddCast("flitt")
    :FilterForPrefab("npc_scout")

------OBJECTIVE DECLARATIONS------

Q:AddObjective("meet_in_dungeon")
    :NetworkSyncStates{QUEST_OBJECTIVE_STATE.s.COMPLETED}
    :AppearInDungeon_QuestRoom_Exclusive(function(quest, biome_location)
        -- Example of requiring a specific dungeon:
        --~ return biome_location.id == biomes.locations.treemon_forest.id
        local has_berna = TheWorld:IsFlagUnlocked("wf_town_has_armorsmith") -- the town already has berna
        local has_seen_alphonse = TheWorld:IsFlagUnlocked("wf_seen_npc_market_merchant") -- this world has been to the market room before
        return not has_berna and has_seen_alphonse
    end)
    :InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
    :LockRoom()
    :UnlockWorldFlagsOnComplete{"wf_town_has_armorsmith"}  -- the armorsmith will now appear in this player's town
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

------CONVERSATIONS AND QUESTS------

Q:AddQuips {
    Quip("armorsmith", "attract")
        :PossibleStrings(quip_strings.quip_armorsmith_generic)
}

--------------- DUNGEON ROUTE ---------------

-- The 'normal' route for meeting the armoursmith. You see her in the dungeon & recruit her.
Q:OnDungeonChat("meet_in_dungeon", "giver", function(...) return quest_helper.Filter_FirstMeetingNPC(Quest.Filters.InDungeon_QuestRoom, ...) end)
    :FlagAsTemp()
    :SetPriority(Convo.PRIORITY.HIGHEST)
    :Strings(primary_quest_strings.invite_to_town)
    :Fn(function(cx)

        cx:Talk("TALK")
        cx:Opt("OPT_1")
            :MakePositive()
            :Fn(function()
                cx:Talk("TALK2")

                cx:Opt("OPT_2A")
                    :MakePositive()
                cx:Opt("OPT_2B")
                    :MakePositive()

                cx:JoinAllOpt_Fn(function()
                    local giver = quest_helper.GetGiver(cx)
                    cx:Talk("TALK3")
                    cx.quest:Complete("meet_in_dungeon")
                    giver.inst.components.timer:StartTimer("talk_cd", 7.5)
                end)
            end)
    end)

Q:OnTownChat("town_intro_no_talk", "giver", Quest.Filters.InTown)
    :FlagAsTemp()
    :Strings(secondary_quest_strings)
    :SetPriority(Convo.PRIORITY.HIGHEST)
    :Fn(function(cx)
        cx:Talk("TALK")
        cx:Opt("OPT_1")
            :MakePositive()
            :Fn(function(cx)
                cx:Talk("TALK2")
                cx:Opt("OPT_2")
                    :MakePositive()
                    :Fn(function(cx)
                        cx:Talk("TALK3")
                        cx.quest:Complete("town_intro_no_talk")
                        cx:End()
                    end)
            end)
    end)

Q:OnTownChat("town_intro_talked", "giver", Quest.Filters.InTown)
    :FlagAsTemp()
    :SetPriority(Convo.PRIORITY.HIGHEST)
    :Strings(town_intro_talk_strings)
    :Fn(function(cx)

        local function ConvoEnd(str)
            cx:Talk(str)
            cx:End()
            cx.quest:Complete("town_intro_talked")
        end

        cx:Talk("TALK_VISITOR")
        cx:Opt("OPT_0")
            :MakePositive()
            :Fn(function()
                cx:Talk("OPT0_RESPONSE")

                cx:Opt("OPT_1A")
                    :MakePositive()
                    :Fn(function()
                        cx:Talk("OPT1A_RESPONSE")
                    end)
                cx:Opt("OPT_1B")
                    :MakePositive()
                    :Fn(function()
                        cx:Talk("OPT1B_RESPONSE")
                    end)

                -- JoinAllOpt_Fn will make all above options do this step after their Talk.
                cx:JoinAllOpt_Fn(function()
                    cx:Talk("TALK_VISITOR2")
                    cx:Opt("OPT_2A")
                        :MakePositive()
                        :Fn(function()
                            ConvoEnd("OPT2A_RESPONSE")
                        end)
                    cx:Opt("OPT_2B")
                        :MakePositive()
                        :Fn(function()
                            ConvoEnd("OPT2B_RESPONSE")
                        end)
                end)
            end)
    end)

--------------- TOWN ROUTE ---------------

-- This NPC was recruited by other players before you joined the town & this is the first time you are seeing them.
Q:AddObjective("meet_in_town")
    :InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
    :UnlockWorldFlagsOnComplete{"wf_town_has_armorsmith"}  -- the armorsmith will now appear in this player's town
    :OnComplete(function(quest)
        quest:Cancel("meet_in_dungeon")
        quest:Complete()
    end)

Q:OnTownChat("meet_in_town", "giver", Quest.Filters.InTown)
    :ForbiddenPlayerFlags{"pf_met_armorsmith"}
    :FlagAsTemp()
    :Strings(tertiary_quest_strings)
    :SetPriority(Convo.PRIORITY.HIGHEST)
    :Fn(function(cx)
        cx:Talk("TALK")

        cx:Opt("OPT_1")
            :MakePositive()
            :Fn(function()
                cx:Talk("TALK2")

                cx:Opt("OPT_2A")
                    :MakePositive()
                cx:Opt("OPT_2B")
                    :MakePositive()

                --JoinAllOpt_Fn bottlenecks all the options above into this route
                cx:JoinAllOpt_Fn(function()
                    cx:Talk("TALK3")

                    cx:Opt("OPT_3")
                        :MakePositive()
                        :Fn(function()
                            local click_4A = false
                            local click_4B = false

                            local function OPT4C()
                                cx:AddEnd("OPT_4C")
                                    :MakePositive()
                                    :Fn(function(cx)
                                        cx:Talk("OPT4C_RESPONSE")
                                        cx.quest:Complete("meet_in_town")
                                        cx:End()
                                    end)
                            end

                            local function OPT4B()
                                if not click_4B then
                                    cx:Opt("OPT_4B")
                                        :MakePositive()
                                        :Fn(function(cx)
                                            click_4B = true
                                            cx:Talk("OPT4B_RESPONSE")

                                            if not click_4A then
                                                cx:Opt("OPT_4A")
                                                :MakePositive()
                                                :Fn(function(cx)
                                                    cx:Talk("OPT4A_RESPONSE")
                                                    cx:Opt("OPT_5A")
                                                        :MakePositive()
                                                        :Fn(function(cx)
                                                            cx:Talk("OPT5A_RESPONSE")
                                                        end)
                                                    cx:Opt("OPT_5B")
                                                        :MakePositive()
                                                        :Fn(function(cx)
                                                            cx:Talk("OPT5B_RESPONSE")
                                                        end)
                                                    --JoinAllOpt_Fn bottlenecks all the options above into this route
                                                    cx:JoinAllOpt_Fn(function()
                                                        --end convo
                                                        OPT4C()
                                                    end)
                                                end)
                                            end
                                            --end convo
                                            OPT4C()
                                        end)
                                end
                            end

                            cx:Talk("TALK4")

                            --ask about having to get rot materials to get armour
                            OPT4B()

                            cx:Opt("OPT_4A")
                                :MakePositive()
                                :Fn(function(cx)
                                    cx:Talk("OPT4A_RESPONSE")
                                    cx:Opt("OPT_5A")
                                        :MakePositive()
                                        :Fn(function(cx)
                                            cx:Talk("OPT5A_RESPONSE")
                                        end)
                                    cx:Opt("OPT_5B")
                                        :MakePositive()
                                        :Fn(function(cx)
                                            cx:Talk("OPT5B_RESPONSE")
                                        end)
                                    --JoinAllOpt_Fn bottlenecks all the options above into this route
                                    cx:JoinAllOpt_Fn(function()
                                        --ask about having to get rot materials to get armour
                                        OPT4B()
                                        --end convo
                                        OPT4C()
                                    end)
                                end)
                            
                            --end convo
                            OPT4C()
                        end)
                end)
            end)
    end)

return Q
