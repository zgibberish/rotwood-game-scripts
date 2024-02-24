--[[local Convo = require "questral.convo"
local Quest = require "questral.quest"
local recipes = require "defs.recipes"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require ("strings.strings_npc_potionmaker_dungeon").QUESTS.seen_missing_friends

local admission_recipe = recipes.ForSlot.PRICE.potion_refill
local hoggins_tip_recipe = recipes.ForSlot.PRICE.hoggins_tip

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

--the player's hunter species will be inserted here at runtime
Q:AddVar("species", "PLACEHOLDER")

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForRole("travelling_salesman")

function Q:Quest_Start()
	-- Set param here to use as "{primary_ingredient_name}" in strings.
	self:SetParam("primary_ingredient_name", quest_helper.GetPrettyRecipeIngredient(admission_recipe))
	self:SetParam("admission_recipe", admission_recipe)
	self:SetParam("hoggins_tip_recipe", hoggins_tip_recipe)
end

Q:UnlockWorldFlagsOnComplete{"wf_travelling_salesman"}

------OBJECTIVE DECLARATIONS------
--plays right after you meet the salesman-- mix of shop function and conversation
Q:AddObjective("seen_missing_friends")
	:OnActivate(function(quest)
		if quest_helper.AlreadyHasCharacter("blacksmith") then
			quest:Complete("seen_missing_friends")
		end
	end)
	:OnEvent("playerentered", function(quest)
		-- runs every room
		if quest_helper.AlreadyHasCharacter("blacksmith") then
			quest:Complete("seen_missing_friends")
		end
	end)	
	:OnComplete(function(quest)
		quest_helper.CompleteQuestOnRoomExit(quest)
		giver.inst.components.timer:StartTimer("talk_cd", 3)
	end)

quest_helper.AddCompleteQuestOnRoomExitObjective(Q)

------CONVERSATIONS AND QUESTS------

--if you havent bought a potion this conversation will allow you another chance to buy one, in addition to letting you ask about your missing buds
Q:OnAttract("seen_missing_friends", "giver", function(quest, node, sim) return not quest_helper.AlreadyHasCharacter("blacksmith") end)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings)
	:Fn(function(cx)
		quest_helper.SetPlayerSpecies(cx)

		local giver = quest_helper.GetGiver(cx)
		local player = cx.quest:GetPlayer()
		local met_blacksmith = quest_helper.AlreadyHasCharacter("blacksmith")
		local met_armorsmith = quest_helper.AlreadyHasCharacter("armorsmith")
		
		cx:Talk("TALK")

		--player has no money for a potion
		if not admission_recipe:CanPlayerCraft(player) then
			cx:Talk("TALK2_NO_RESOURCES")
		--player has no room for a potion
		elseif not quest_helper.PlayerNeedsPotion(player) then
			cx:Talk("TALK2_NO_SPACE")
		--player can buy a potion
		else
			cx:Talk("TALK2_CAN_BUY")
		end

		local function OPT1A(button_str)
			cx:Opt(button_str)
				:MakePositive()
				:Fn(function(cx)
					if met_armorsmith then
						cx:Talk("OPT1A_BLACKSMITHONLY")
					else
						cx:Talk("OPT1A_BOTH")
					end

					--Doc Hoggins offers to give the player information in exchange for some konjur (it's a scam lol)
					cx:Talk("TALK3")

					--If the player hits this point we consider them as having completed the inquiry about their friends with Doc, even if they exit out and don't buy the tip
					cx.quest:Complete("seen_missing_friends")

					--missing friends "Tip" options
					if hoggins_tip_recipe:CanPlayerCraft(player) then
						--player has the money to buy the tip and does
						cx:Opt("OPT_2A")
							:MakePositive()
							:Fn(function(cx)
								hoggins_tip_recipe:TakeIngredientsFromPlayer(player)
								cx:Talk("OPT2A_RESPONSE")
								cx:End()
							end)
						--player has the money to buy the tip but doesnt
						cx:AddEnd("OPT_2B")
							:MakePositive()
							:Fn(function(cx)
								cx:Talk("OPT2B_RESPONSE")
							end)
					else
						--player doesn't have enough money to buy the tip, exit out
						cx:AddEnd("OPT_2B_ALT")
							:MakePositive()
							:Fn(function(cx)
								cx:Talk("OPT2B_RESPONSE")
							end)
					end
				end)			
		end

		--impossible to recruit blacksmith before the armorsmith
		if not met_armorsmith then
			--opt 1A button asking about 1 friend
			OPT1A("OPT_1A_TWOFRIENDS")
		else
			--opt 1A button asking abou 2 friends
			OPT1A("OPT_1A_ONEFRIEND")
		end

		--OPT1B options (give the player a chance to buy a potion if they havent already)
		--check if player has resources to make a potion
		if admission_recipe:CanPlayerCraft(player) then
			--check if player has potion space available
			if player.components.potiondrinker:CanGetMorePotionUses() then
				cx:Opt("OPT_1B")
					:MakePositive()
					:Fn(function(cx)
						OnStartCooking(giver.inst, giver:GetInteractingPlayerEntity())
						cx:Talk("OPT1B_RESPONSE")

						--opt 1A button but with the alt text
						OPT1A("OPT_1A_ALT")

						cx:AddEnd("OPT_1C")
							:MakePositive()
					end)
			end
		end

		cx:AddEnd("OPT_1C")
			:MakePositive()
end)

--KRIS TODO add a second convo to give the player another chance to ask if they didnt have
--money the first time
--Q:OnAttract("seen_missing_friends2", "giver", function(quest, node, sim) return not quest_helper.AlreadyHasCharacter("blacksmith") and hoggins_tip_recipe:CanPlayerCraft(player) end)

return Q]]
