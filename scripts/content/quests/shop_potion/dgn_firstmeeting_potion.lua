local Convo = require "questral.convo"
local Quest = require "questral.quest"
local recipes = require "defs.recipes"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require ("strings.strings_npc_potionmaker_dungeon").QUESTS.first_meeting

local admission_recipe = recipes.ForSlot.PRICE.potion_refill

local Q = Quest.CreateJob()
    :SetPriority(QUEST_PRIORITY.HIGHEST)

local function OnStartCooking(inst, player)
    -- Close prompt to ensure it doesn't activate during song.
    -- TheDungeon.HUD:HidePrompt(inst)

    -- Don't CraftItemForPlayer because the recipe is the entry cost.
    admission_recipe:TakeIngredientsFromPlayer(player)

    player.components.potiondrinker:RefillPotion()
    TheDungeon:GetDungeonMap():RecordActionInCurrentRoom("travelling_salesman")
end

local function _CanPlayerDrinkPotion(player)
    return player.components.potiondrinker:CanDrinkPotion()
end

--the player's hunter species will be inserted here at runtime
Q:AddVar("species", "PLACEHOLDER")

------CAST DECLARATIONS------

Q:UpdateCast("giver")
    :FilterForRole("travelling_salesman")

------OBJECTIVE DECLARATIONS------
function Q:Quest_Start()
    -- Set param here to use as "{primary_ingredient_name}" in strings.
    self:SetParam("primary_ingredient_name", quest_helper.GetPrettyRecipeIngredient(admission_recipe))
    self:SetParam("admission_recipe", admission_recipe)
end

function Q:Quest_Complete()
    self:GetQuestManager():SpawnQuest("dgn_seenmissingfriends_potion")
    TheDungeon.progression.components.runmanager:SetHasMetNPC(true)
end

Q:UnlockWorldFlagsOnComplete{"wf_travelling_salesman"}

Q:AddVar("num_sales_attempts", 0)

--plays when you first meet the salesman
Q:AddObjective("first_meeting")
    :InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
    -- :LockRoom()
    :OnComplete(function(quest)
        if not quest:IsActive("wait_for_empty_flask") then
            -- If you didn't have enough money to buy a flask this visit, we go here.
            quest:ActivateObjective("no_teffra")
        end
    end)

--if player entered "first_meeting" but wasnt able to buy a potion, and is now meeting hoggins for a second time in a new room
Q:AddObjective("second_meeting")
    -- :LockRoom()
    :OnComplete(function(quest)
        if not quest:IsActive("wait_for_empty_flask") then
            -- If you didn't have enough money to buy a flask this visit, we go here.
            quest:ActivateObjective("no_teffra")
        end
    end)

--if you met hoggins with no money 3 times in a row (he is so tired)
Q:AddObjective("third_meeting_no_money")
    -- :LockRoom()
    :OnComplete(function(quest)
        quest:Complete()
    end)

local function _exit_room_after_failed_sale(quest)
    local num_attempts = quest:GetVar("num_sales_attempts")
    if num_attempts == 1 then
        quest:ActivateObjective("second_meeting")
    elseif num_attempts > 1 then
        quest:ActivateObjective("third_meeting_no_money")
    end
end

-- If the player can afford to buy a potion but needs to empty their flask first.
Q:AddObjective("wait_for_empty_flask")
    :OnEvent("exit_room", function(quest)
        -- if you exit the room with this event active, Hoggins failed to make a sale.
        if TheWorld:IsCurrentRoomType("potion") then
            quest:Cancel("wait_for_empty_flask")
            _exit_room_after_failed_sale(quest)
        end
    end)

-- if Hoggins tried to sell you a potion but you didn't have enough teffra
Q:AddObjective("no_teffra")
    :OnEvent("exit_room", function(quest)
        if TheWorld:IsCurrentRoomType("potion") then
            quest:Cancel("no_teffra")
            _exit_room_after_failed_sale(quest)
        end
    end)

------CONVERSATIONS AND QUESTS------

Q:OnAttract("first_meeting", "giver", function(quest, node, sim)
    return quest_helper.Filter_FirstMeetingSpecificNPC(quest, node, sim, "travelling_salesman")
end)
    :SetPriority(Convo.PRIORITY.HIGHEST)
    :Strings(quest_strings)
    :Fn(function(cx)
        quest_helper.SetPlayerSpecies(cx)
        local giver = quest_helper.GetGiver(cx)

        --used by CompleteQuestAndEnd and AddSecondObjectiveAndEnd, shouldnt be used raw
        local function EndConvo(endStr)
            cx.quest:IncrementVar("num_sales_attempts")

            cx:Talk(endStr)
            quest_helper.UnlockRoom(cx.quest)
            cx.quest:Complete("first_meeting")
            cx:End()
            giver.inst.components.timer:StartTimer("talk_cd", 5)
        end

        --If player successfully heard Hoggins' sales pitch (whether they bought a potion or not), complete the quest and end the convo
        local function CompleteQuestAndEnd(endStr)
            EndConvo(endStr)
            cx.quest:Complete()
        end

        --If the player couldn't buy a potion, exit them out of the pitch early and create another objective to try again next time they meet
        local function AddSecondObjectiveAndEnd(nextObjective, endStr)
            cx.quest:ActivateObjective(nextObjective)
            EndConvo(endStr)
        end

        --used in OPT_2_WHO and OPT_2_POTION (breaks if i use JoinAllOpt_Fn because the preceding buttons have functions)--
        local function ReusedSequence()
            cx:Talk("TALK2")

            --player says yes to buying a potion
            cx:Opt("OPT_4_BUY")
                :MakePositive()
                :Fn(function(cx)
                    --player buys a potion
                    local giver = quest_helper.GetGiver(cx)
                    OnStartCooking(giver.inst, giver:GetInteractingPlayerEntity())
                    CompleteQuestAndEnd("OPT4A_RESPONSE") --player buys a potion
                end)

            --player says no to buying a potion
            cx:Opt("OPT_4_NOTHANKS")
                :MakePositive()
                :Fn(function(cx)
                    cx:Talk("RESPONSE_4_NOTHANKS")

                    --player changes their mind
                    cx:Opt("OPT_6_ACCEPT")
                        :MakePositive()
                        :Fn(function()
                            --player buys a potion
                            local giver = quest_helper.GetGiver(cx)
                            OnStartCooking(giver.inst, giver:GetInteractingPlayerEntity())
                            CompleteQuestAndEnd("RESPONSE_6_ACCEPT")
                        end)

                    --player declines potion again
                    cx:AddEnd("OPT_6_DECLINE")
                        :MakePositive()
                        :Fn(function()
                            CompleteQuestAndEnd("RESPONSE_6_DECLINE")
                        end)
                end)
        end
        ------------------------

        cx:Talk("TALK")

        cx:Opt("OPT_1")
            :MakePositive()
            :Fn(function()
                --NO MONEY--
                --branch if player doesnt have the money to buy a potion (delays the sales pitch for next time they meet)
                if not admission_recipe:CanPlayerCraft(giver:GetInteractingPlayerEntity()) then
                    --hoggins realizes youre broke
                    cx:Talk("NO_RESOURCES_ALT")

                    --polite flavour response
                    cx:Opt("NO_RESOURCES_OPT1A")
                        :MakePositive()
                    --spicy flavour response
                    cx:Opt("NO_RESOURCES_OPT1B")
                        :MakePositive()

                    cx:JoinAllOpt_Fn(function()
                        cx:Talk("NO_RESOURCES_ALT2")
                        --say bye
                        cx:Opt("NO_RESOURCES_OPT2A")
                            :MakePositive()
                            :Fn(function()
                                --SECONDARY OBJECTIVE--
                                --Player couldn't buy a potion, give them the alt sales pitch next time they meet Doc
                                --AddSecondObjectiveAndEnd("second_meeting", "RESPONSE_NO_RESOURCES_OPT2A")
                                EndConvo("RESPONSE_NO_RESOURCES_OPT2A")
                            end)
                        cx:Opt("NO_RESOURCES_OPT2B")
                            :MakePositive()
                            :Fn(function()
                                --SECONDARY OBJECTIVE--
                                --Player couldn't buy a potion, give them the alt sales pitch next time they meet Doc
                                --AddSecondObjectiveAndEnd("second_meeting", "RESPONSE_NO_RESOURCES_OPT2B")
                                EndConvo("RESPONSE_NO_RESOURCES_OPT2B")
                            end)
                    end)

                --FLASK FULL--
                --branch if player has money to buy teffra but no room in their flask
                elseif not giver:GetInteractingPlayerEntity().components.potiondrinker:CanGetMorePotionUses() then
                    
                    --hoggins realizes your flask is full and that he cant sell you a pot
                    cx:Talk("POTION_FULL_ALT")

                    --player has taken damage and could drink their pot before leaving the room to talk to hoggins again
                    if _CanPlayerDrinkPotion(cx.quest:GetPlayer()) then
                    	cx:Talk("POT_FULL_LOST_HEALTH")

                    	local function PotionFullOpts(opt_text, response_text)
	                    	cx:Opt(opt_text)
	                    		:MakePositive()
	                    		:Fn(function()
	                    			AddSecondObjectiveAndEnd("wait_for_empty_flask", response_text)
	                    		end)
                		end
                		PotionFullOpts("POTION_FULL_OPT_A", "POTFULL_OPTA_RESPONSE")
                		PotionFullOpts("POTION_FULL_OPT_B", "POTFULL_OPTB_RESPONSE")
                	--player has full health and therefore cant drink their potion before leaving the room
                    else
                    	cx:Opt("OPT_FULL_HEALTH")
	                        :MakePositive()
	                        :Fn(function() 
	                        	--player has full health and cant empty their flask in this room, give them the second meeting objective
		                        AddSecondObjectiveAndEnd("second_meeting", "OPT_FULL_HEALTH_RESPONSE")
	                    	end)
                    end

                --TUTORIAL/BUY POTION--
                --regular route branch
                else
                    cx:Talk("RESPONSE_1")
                        cx:Opt("OPT_2_WHO") --player asks who doc is
                            :MakePositive()
                            :Fn(function(cx)
                                cx:Talk("RESPONSE_2_WHO")
                                cx:Opt("OPT_3_SELLWHAT")
                                    :MakePositive()
                                    :Fn(function()
                                        cx:Talk("RESPONSE_3_SELLWHAT")
                                        --KRIS todo
                                        --[[cx:Opt("OPT_4_WHYBUY")
                                            :MakePositive()
                                            :Fn(function()
                                                cx:Talk("RESPONSE_4_WHYBUY")
                                                ReusedSequence()
                                            end)]]
                                        ReusedSequence()
                                    end)
                            end)
                    cx:Opt("OPT_2_POTION") --player wants to skip introductions and go straight to buying
                        :MakePositive()
                        :Fn(function(cx)
                            cx:Talk("RESPONSE_2_POTION")
                            ReusedSequence()
                        end)
                end
            end)
    end)

--just wait for the player to leave the room
Q:OnAttract("no_teffra", "giver")
    :SetPriority(Convo.PRIORITY.HIGHEST)
    :Strings(quest_strings.buffer)
    :Fn(function(cx)
        quest_helper.SetPlayerSpecies(cx)
        cx:Talk("TALK")
        cx:End()
    end)

Q:OnAttract("wait_for_empty_flask", "giver", function(quest, node, sim)
        local player = quest:GetPlayer()
        -- has not emptied the flask yet.
        return not player.components.potiondrinker:CanGetMorePotionUses()
    end)
    :FlagAsTemp()
    :SetPriority(Convo.PRIORITY.HIGHEST)
    :Strings(quest_strings.player_emptied_flask)
    :Fn(function(cx)
        quest_helper.SetPlayerSpecies(cx)
        cx:Talk("WAIT_FOR_EMPTY")
    end)

Q:OnAttract("wait_for_empty_flask", "giver", function(quest, node, sim)
    local player = quest:GetPlayer()
    -- did empty their flask
    return player.components.potiondrinker:CanGetMorePotionUses()
end)
    :SetPriority(Convo.PRIORITY.HIGHEST)
    :Strings(quest_strings.player_emptied_flask)
    :Fn(function(cx)
        quest_helper.SetPlayerSpecies(cx)
        local giver = quest_helper.GetGiver(cx)

        --complete the quest and end the convo
        local function CompleteQuestAndEnd(endStr)
            cx:Talk(endStr)
            quest_helper.UnlockRoom(cx.quest)
            cx.quest:Complete()
            cx:End()
            giver.inst.components.timer:StartTimer("talk_cd", 3)
        end

        local function AcceptDenyOfferChoice(acceptBtnStr, declineBtnStr)
            --say you do want a potion, exit out and complete quest
            cx:Opt(acceptBtnStr)
                :MakePositive()
                :Fn(function()
                    --player buys a potion
                    local giver = quest_helper.GetGiver(cx)
                    OnStartCooking(giver.inst, giver:GetInteractingPlayerEntity())
                    CompleteQuestAndEnd("RESPONSE_OPT1B")
                end)

            --say you dont want a potion
            cx:Opt(declineBtnStr)
                :MakePositive()
                :Fn(function()
                    --hoggins wont give up after one "no" so he asks you one more time if you actually dont want a potion
                    cx:Talk("RESPONSE_OPT1C")
                    --cave and buy a potion
                    cx:Opt("OPT_2A")
                        :MakePositive()
                        :Fn(function()
                            --player buys a potion
                            local giver = quest_helper.GetGiver(cx)
                            OnStartCooking(giver.inst, giver:GetInteractingPlayerEntity())
                            CompleteQuestAndEnd("RESPONSE_OPT2A")
                        end)
                    --reiterate you dont want a pot and end the convo
                    cx:AddEnd("OPT_2B")
                        :MakePositive()
                        :Fn(function()
                            CompleteQuestAndEnd("RESPONSE_OPT2B")
                        end)
                end)
        end

        cx:Talk("TALK")

        --get mad this man told you to dump out your own potion to get one of his without telling you how much it costs
        cx:Opt("OPT_1A")
            :MakePositive()
            :Fn(function()
                --hoggins tries to guilt you to get out of having made you dump your pot
                cx:Talk("RESPONSE_OPT1A")
                AcceptDenyOfferChoice("OPT_1B_ALT", "OPT_1C_ALT")
            end)

        --this function holds the "buy potion" and "refuse potion" options
        AcceptDenyOfferChoice("OPT_1B", "OPT_1C")
    end)

Q:OnAttract("second_meeting", "giver")
    :SetPriority(Convo.PRIORITY.HIGHEST)
    :Strings(quest_strings.second_meeting)
    :Fn(function(cx)
        quest_helper.SetPlayerSpecies(cx)
        local giver = quest_helper.GetGiver(cx)

        --used by CompleteQuestAndEnd & AddSecondObjectiveAndEnd, shouldnt be used raw
        local function EndConvo(endStr)
            cx.quest:IncrementVar("num_sales_attempts")
            cx:Talk(endStr)
            quest_helper.UnlockRoom(cx.quest)
            cx:End()
            cx.quest:Complete("second_meeting")
            giver.inst.components.timer:StartTimer("talk_cd", 1.5)
        end

        --If player successfully heard Hoggins' sales pitch (whether they bought a potion or not), complete the quest and end the convo
        local function CompleteQuestAndEnd(endStr)
            EndConvo(endStr)
            cx.quest:Complete()
        end

        --If the player couldn't buy a potion, exit them out of the pitch early and create another objective to try again next time they meet
        local function AddSecondObjectiveAndEnd(nextObjective, endStr)
            cx.quest:ActivateObjective(nextObjective)
            EndConvo(endStr)
        end

        local function RefusePotionOpt()
            --player refuses a potion
            cx:Opt("OPT_2C")
                :MakePositive()
                :Fn(function()
                    cx:Talk("OPT2C_RESPONSE")
                    --final chance to get a pot
                    cx:Opt("OPT_3A")
                        :MakePositive()
                        :Fn(function()
                            --player buys a potion
                            local giver = quest_helper.GetGiver(cx)
                            OnStartCooking(giver.inst, giver:GetInteractingPlayerEntity())
                            CompleteQuestAndEnd("OPT3A_RESPONSE")
                        end)
                    --player doubles down that they dont want a potion
                    cx:AddEnd("OPT_3B")
                        :MakePositive()
                        :Fn(function()
                            CompleteQuestAndEnd("OPT3B_RESPONSE")
                        end)
                end)
        end

        cx:Talk("TALK")

        if admission_recipe:CanPlayerCraft(giver:GetInteractingPlayerEntity()) then
            --comment on whether they have money this time or not
            --if yes money, send them through the buying/refusing tree that was missed in the first meeting, then complete entire quest
            if giver:GetInteractingPlayerEntity().components.potiondrinker:CanGetMorePotionUses() then
                cx:Opt("OPT_1")
                    :MakePositive()
                    :Fn(function()
                        cx:Talk("OPT1_RESPONSE")
                        --player asks doc to introduce himself
                        cx:Opt("OPT_2A")
                            :MakePositive()
                            :Fn(function()
                                cx:Talk("OPT2A_RESPONSE")
                                --player buys a potion
                                cx:Opt("OPT_2B_ALT")
                                    :MakePositive()
                                    :Fn(function()
                                        --player buys a potion
                                        local giver = quest_helper.GetGiver(cx)
                                        OnStartCooking(giver.inst, giver:GetInteractingPlayerEntity())
                                        CompleteQuestAndEnd("OPT2BALT_RESPONSE")
                                    end)
                                --player refuses a potion
                                    RefusePotionOpt()
                            end)
                        --player buys a potion
                        cx:Opt("OPT_2B")
                            :MakePositive()
                            :Fn(function()
                                --player buys a potion
                                local giver = quest_helper.GetGiver(cx)
                                OnStartCooking(giver.inst, giver:GetInteractingPlayerEntity())
                                CompleteQuestAndEnd("OPT2BALT_RESPONSE")
                            end)
                        --player refuses a potion
                            RefusePotionOpt()
                    end)
            else
            	--players flask is full and hoggins cant sell them a pot
                cx:Opt("OPT1_NOROOM")
                    :MakePositive()
                    :Fn(function()
                        cx:Talk("OPT1_RESPONSE_NOROOM")

	                    --player has taken damage and could drink their pot before leaving the room to talk to hoggins again
	                    if _CanPlayerDrinkPotion(cx.quest:GetPlayer()) then
	                    	cx:Talk("OPT1_RESPONSE_NOROOM2")

	                    	local function PotionFullOpts(opt_text, response_text)
		                    	cx:Opt(opt_text)
		                    		:MakePositive()
		                    		:Fn(function()
		                    			AddSecondObjectiveAndEnd("wait_for_empty_flask", response_text)
		                    		end)
	                		end
	                		PotionFullOpts("POTION_FULL_OPT_A", "POTFULL_OPTA_RESPONSE")
	                		PotionFullOpts("POTION_FULL_OPT_B", "POTFULL_OPTB_RESPONSE")
	                	--player has full health and therefore cant drink their potion before leaving the room
	                    else
	                    	cx:AddEnd("OPT_FULL_HEALTH")
		                        :MakePositive()
		                        :Fn(function() 
		                        	--player has full health and cant empty their flask in this room, give them the second meeting objective
			                        AddSecondObjectiveAndEnd("second_meeting", "OPT_FULL_HEALTH_RESPONSE")
		                    	end)
	                    end
                    end)
            end
        else
            --if no money, ridicule them a bit and activate third meeting
            cx:Opt("OPT1_NOFUNDS")
                    :MakePositive()
                    :Fn(function()
                        cx:Talk("OPT1_RESPONSE_NOFUNDS")

                        --saying bye
                        cx:Opt("OPT_5A")
                        cx:Opt("OPT_5B")

                        --objective activates for if you meet hoggins for a _third_ time in a new room without having any money
                        cx:JoinAllOpt_Fn(function()
                            EndConvo("OPT5_RESPONSE")
                        end)
                    end)
        end
end)

--player meets hoggins for a third time in a row without any money, he's tired and dejected
Q:OnAttract("third_meeting_no_money", "giver", function(quest, node, sim)
        if admission_recipe:CanPlayerCraft(quest:GetPlayer()) then
            -- the player can afford it! Don't do this chat.
            quest:Complete("third_meeting_no_money")
            return false
        else
            -- the player STILL can't afford it... just give up.
            return true
        end
    end)
    :SetPriority(Convo.PRIORITY.HIGHEST)
    :Strings(quest_strings.third_meeting)
    :Fn(function(cx)
        quest_helper.SetPlayerSpecies(cx)
        cx:Talk("TALK")
        cx.quest:Complete()
        cx:End()
        quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 1.5)
    end)

return Q