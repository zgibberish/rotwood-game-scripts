local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local Quip = require "questral.quip"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local quest_strings = require("strings.strings_npc_dojo_master").QUESTS.twn_shop_dojo

local Q = Quest.CreateRecurringChat()

Q:SetRateLimited(false)

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForPrefab("npc_dojo_master")

------OBJECTIVE DECLARATIONS------

Q:AddObjective("resident")
	:SetIsUnimportant()
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("dodge_tutorial")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:UnlockPlayerFlagsOnComplete{"pf_dodge_pop_quiz_complete"}
	:SetPriority(Convo.PRIORITY.HIGH)

Q:AddObjective("focus_hit_tutorial")
	:SetPriority(Convo.PRIORITY.HIGH)
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:UnlockPlayerFlagsOnComplete{"pf_focus_hit_pop_quiz_complete"}

Q:AddQuips {
    Quip("dojo_master", "tip_quip")
        :PossibleStrings(quest_strings.LESSONS.GOODBYE_QUIPS),
    Quip("dojo_master", "tip_quip_mp")
        :PossibleStrings(quest_strings.LESSONS.GOODBYE_QUIPS_MP)
}

local unlock_tiers = {1, 3, 8} --number of unlocked flags required to trigger a reward tier. There are actually 4 tiers but the fourth is award for completing all tutorials, so the existing tutorials are counted programmatically
local unlockable_title_IDs = {"teacherspet", "hunterphd"}

--use "unlockable_title_IDs" to choose which title to unlock-- and remember lua starts at base 1 lmao
local function UnlockCosmeticTitle(player, unlockable_title_index)
	local Cosmetics = require "defs.cosmetics.cosmetics"
	local unlock_tracker = player.components.unlocktracker
	local title_key = Cosmetics.PlayerTitles[unlockable_title_IDs[unlockable_title_index]].title_key

	--unlock the title
	unlock_tracker:UnlockCosmetic(unlockable_title_IDs[unlockable_title_index], "PLAYER_TITLE")

	--pop a notif on screen
	TheDungeon.HUD:MakePopText({ 
		target = player, 
		button = string.format(STRINGS.UI.INVENTORYSCREEN.TITLE_UNLOCKED, STRINGS.COSMETICS.TITLES[title_key]), 
		color = UICOLORS.KONJUR, 
		size = 100, 
		fade_time = 3.5,
		y_offset = 650,
	})
end

local function GiveItemReward(player, item_type, reward_amount)
	local Consumable = require "defs.consumable"
	local reward_item = Consumable.FindItem(item_type)
	local invscreen_str

	--couldnt figure out how to turn the resource name into part of the inventoryscreen str path lmao
	if reward_item.name == "glitz" then
		invscreen_str = STRINGS.UI.INVENTORYSCREEN.GLITZ
	elseif reward_item.name == "konjur_soul_lesser" then 
		invscreen_str = STRINGS.UI.INVENTORYSCREEN.KONJUR_SOUL_LESSER
	end
	
	player.components.inventoryhoard:AddStackable(reward_item, reward_amount)
	TheDungeon.HUD:MakePopText({ 
		target = player, 
		button = string.format(invscreen_str, reward_amount), 
		color = UICOLORS.KONJUR, 
		size = 100, 
		fade_time = 3.5,
		y_offset = 650,
	})
end

------CONVERSATIONS AND QUESTS------

Q:OnTownChat("dodge_tutorial", "giver")
	:Strings(quest_strings.DODGE_CONVERSATION)
	:ForbiddenPlayerFlags{"pf_dodge_pop_quiz_complete"}
	:Fn(function(cx)
		local opt1B_clicked = false --"its more important than attacking"
		local opt1C_clicked = false --"you dodge with SPACE"
		local opt1D_clicked = false --"dodgings for wimps"
		local player = cx.GetPlayer(cx).inst

		local function EndConvo(treat)
			if treat == true then
				GiveItemReward(player, "konjur_soul_lesser", 1)
			end
			cx.quest:Complete("dodge_tutorial")
			cx:End()
		end
		cx:Talk("TALK")
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1A_RESPONSE")
		end)
		cx:Opt("OPT_1B")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1B_RESPONSE")
				opt1B_clicked = true
		end)
		cx:Opt("OPT_1C")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1C_RESPONSE")
				opt1C_clicked = true
		end)
		cx:Opt("OPT_1D")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1D_RESPONSE")
				opt1D_clicked = true
		end)

		cx:JoinAllOpt_Fn(function()
			cx:Talk("TALK2")
			if opt1C_clicked == false then
				cx:Opt("OPT_2A")
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT2A_RESPONSE")
						cx:Talk("TALK3")
						EndConvo(true)
				end)
			end
			if opt1B_clicked == false then
				cx:Opt("OPT_2B")
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT2B_RESPONSE")
						cx:Talk("TALK3")
						EndConvo(true)
				end)
			end
			cx:Opt("OPT_2C")
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT2C_RESPONSE")
						cx:Talk("TALK3")
						EndConvo(true)
				end)
			if opt1D_clicked == true then
				cx:Opt("OPT_2D")
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT2D_RESPONSE")
						cx:Opt("OPT_3A")
							:MakePositive()
							:Fn(function()
								cx:Talk("OPT3A_RESPONSE")
								EndConvo(true)
							end)
						cx:Opt("OPT_3B")
							:MakePositive()
							:Fn(function()
								cx:Talk("OPT3B_RESPONSE")
								EndConvo(false)
							end)
				end)
			end
		end)
end)

Q:OnTownChat("focus_hit_tutorial", "giver", function(quest, node, sim)
		local num_runs = quest:GetPlayer().components.progresstracker:GetValue("total_num_runs") or 0
		return num_runs >= 3
	end)
	:Strings(quest_strings.FOCUS_HIT_CONVERSATION)
	:ForbiddenPlayerFlags{"pf_focus_hit_pop_quiz_complete"}
	:Fn(function(cx)
		local player = cx.GetPlayer(cx).inst

		local opt2B_clicked = false --"focus hit damage appears in blue"
		local opt2C_clicked = false --"focus hits are necessary to reach full damage potential"
		local opt2D_clicked = false --"focus hits are for nerds"

		local function EndConvo(treat)
			if treat == true then
				GiveItemReward(player, "konjur_soul_lesser", 1)
			end
			cx:End()
			cx.quest:Complete("focus_hit_tutorial")
		end

		cx:Talk("TALK")

		cx:Opt("OPT_1A")
			:MakePositive()
		cx:Opt("OPT_1B")
			:MakePositive()

		cx:JoinAllOpt_Fn(function()
			cx:Talk("TALK2")

			cx:Opt("OPT_2A")
				:MakePositive()
				:Fn(function()
					cx:Talk("OPT2A_RESPONSE")
				end)
			cx:Opt("OPT_2B")
				:MakePositive()
				:Fn(function()
					cx:Talk("OPT2B_RESPONSE")
					opt2B_clicked = true
				end)
			cx:Opt("OPT_2C")
				:MakePositive()
				:Fn(function()
					cx:Talk("OPT2C_RESPONSE")
					opt2C_clicked = true
				end)
			cx:Opt("OPT_2D")
				:MakePositive()
				:Fn(function()
					cx:Talk("OPT2D_RESPONSE")
					opt2D_clicked = true
				end)

			cx:JoinAllOpt_Fn(function()
				local function FinalOpt(button_str)
					cx:Opt(button_str)
					:MakePositive()
					:Fn(function()
						cx:Talk("TALK3")
						EndConvo(true)
					end)
				end

				--regular options
				FinalOpt("OPT_3A")
				if opt2C_clicked == false then
					FinalOpt("OPT_3B")
				end
				if opt2B_clicked == false then
					FinalOpt("OPT_3C")
				end
				--jerk option
				if opt2D_clicked == true then
					cx:Opt("OPT_3D")
						:MakePositive()
						:Fn(function()
							cx:Talk("OPT3D_RESPONSE")

							cx:Opt("OPT_4A")
								:MakePositive()
								:Fn(function()
									cx:Talk("OPT4A_RESPONSE")
									EndConvo(true)
								end)
							cx:Opt("OPT_4B")
								:MakePositive()
								:Fn(function()
									cx:Talk("OPT4B_RESPONSE")
									EndConvo(false)
								end)
						end)
				end
			end)
		end)		
end)

--this logic is hellish to read and has string concatenation i am so sorry for my crimes -kris
Q:OnTownShopChat("resident", "giver")
	:FlagAsTemp()
	:Strings(quest_strings)
	:Fn(function(cx)
		local general_cat = { "POWER_DROPS", "REVIVE_MECHANICS", "FRENZIED_HUNTS"}
		local combat_cat = { "FOCUS_HITS", "CRITICAL_HITS", "HIT_STREAKS"}
		local defense_cat = { "DODGE", "PERFECT_DODGE", "DODGE_CANCEL"}
		--local weapons_cat = { "HAMMER", "SPEAR", "SHOTPUT", "CANNON"}
		local equipment_cat = { "POTIONS", "WEIGHT_SYSTEM", "LUCK_STAT"}

		local player = cx.GetPlayer(cx).inst
		--DECLARE FUNCTIONS--
		--count how many of the tutorials the player has read
		local function NumTutorialCompletions(current_tutorial) --current tutorial is the tutorial the player just read
			if not player:IsFlagUnlocked("pf_" .. current_tutorial) then
				--unlock flag for this tutorial
				player:UnlockFlag("pf_" .. current_tutorial)

				--check how many flags are unlocked total
				--flags are based on the string name of the tutorial only, so lessons can be shuffled around the different lesson categories without affecting existing unlocks
				local total_num_tutorials = 0
				local unlock_count = 0
				for _,list in pairs({general_cat, combat_cat, defense_cat, equipment_cat}) do
					for _,tutorial in pairs(list) do
						total_num_tutorials = total_num_tutorials + 1
						if player:IsFlagUnlocked("pf_" .. tutorial) then
							unlock_count = unlock_count + 1
						end
					end
				end
				
				--REWARDS--
				--unlocking your very first tutorial flag gives some glitz
				if unlock_count == unlock_tiers[1] and not player:IsFlagUnlocked("pf_tier_one_tutorial_reward") then
					cx:Talk("LESSONS.TUTORIALS.REWARD_TIER_ONE.TALK")
					--KRIS review reward after nextfest
					--GiveItemReward(player, "glitz", 500)
					GiveItemReward(player, "konjur_soul_lesser", 1)
					TheFrontEnd:GetSound():PlaySound(fmodtable.Event.reward_corestone)

					--prevent re-giving the tutorial reward if more tutorials are added at a later date
					player:UnlockFlag("pf_tier_one_tutorial_reward")
				--unlocking the number of flags needed for the second tier gives the "Teacher's Pet" title
				elseif unlock_count == unlock_tiers[2] and not player:IsFlagUnlocked("pf_tier_two_tutorial_reward") then
					cx:Talk("LESSONS.TUTORIALS.REWARD_TIER_TWO.TALK")
					--KRIS review reward after nextfest
					--UnlockCosmeticTitle(player, 1)
					GiveItemReward(player, "konjur_soul_lesser", 1)
					TheFrontEnd:GetSound():PlaySound(fmodtable.Event.reward_corestone)
					--prevent re-giving the tutorial reward if more tutorials are added at a later date
					player:UnlockFlag("pf_tier_two_tutorial_reward")
				--unlocking the number of flags needed for the third tier gives a corestone
				elseif unlock_count == unlock_tiers[3] and not player:IsFlagUnlocked("pf_tier_three_tutorial_reward") then
					cx:Talk("LESSONS.TUTORIALS.REWARD_TIER_THREE.TALK")
					--KRIS review reward after nextfest
					--GiveItemReward(player, "konjur_soul_lesser", 1)
					GiveItemReward(player, "konjur_soul_lesser", 1)
					TheFrontEnd:GetSound():PlaySound(fmodtable.Event.reward_corestone)

					--prevent re-giving the tutorial reward if more tutorials are added at a later date
					player:UnlockFlag("pf_tier_three_tutorial_reward")
				--unlocking the number of flags needed for the second tier gives the "Hunter, PhD" title
				elseif unlock_count == total_num_tutorials and not player:IsFlagUnlocked("pf_tier_four_tutorial_reward")then
					cx:Talk("LESSONS.TUTORIALS.REWARD_TIER_FOUR.TALK")
					--KRIS review reward after nextfest
					--UnlockCosmeticTitle(player, 2)
					GiveItemReward(player, "konjur_soul_lesser", 2)
					TheFrontEnd:GetSound():PlaySound(fmodtable.Event.reward_corestone)

					--prevent re-giving the tutorial reward if more tutorials are added at a later date
					player:UnlockFlag("pf_tier_four_tutorial_reward")
					--[[cx:Opt("LESSONS.TUTORIALS.REWARD_TIER_FOUR.OPT_1A")
						:MakePositive()
						:Fn(function()
							cx:Talk("LESSONS.TUTORIALS.REWARD_TIER_FOUR.OPT1A_RESPONSE")
							cx:End()
						end)
					cx:Opt("LESSONS.TUTORIALS.REWARD_TIER_FOUR.OPT_1B")
						:MakePositive()
						:Fn(function()
							cx:Talk("LESSONS.TUTORIALS.REWARD_TIER_FOUR.OPT1B_RESPONSE")
							cx:End()
						end)
					cx:Opt("LESSONS.TUTORIALS.REWARD_TIER_FOUR.OPT_1C")
						:MakePositive()
						:Fn(function()
							cx:Talk("LESSONS.TUTORIALS.REWARD_TIER_FOUR.OPT1C_RESPONSE")
							cx:End()
						end)
					]]
				end

			end
		end

		--Home menu where player can select from the lesson categories (General, Combat, Weapons, Equipment)
		local function LessonMenu()
			--see whether or not the player has completed all the lessons under a category heading so the button string can change
			local function EvalueCatCompletion(category)
				for k,tutorial in pairs(category) do
					--PLAYER HASN'T READ THIS TUTORIAL YET
					if not player:IsFlagUnlocked("pf_" .. tostring(tutorial)) then
						return false
					end
				end
				return true
			end

			local function SubMenu(category, lessons_table) --category is the category (General/Combat/Defense/etc) and lessons_table is a table of all the individual tutorials in that category
				cx:Opt("LESSONS.BACK_BTN")
					:MakePositive()
					:Fn(function()
						cx:Talk("LESSONS.BACK_BTN_RESPONSE")
						LessonMenu()
					end)

				for k,tutorial in pairs(lessons_table) do
					--PLAYER HASN'T READ THIS TUTORIAL YET
					if not player:IsFlagUnlocked("pf_" .. tostring(tutorial)) then
						cx:Opt("LESSONS.TUTORIALS." .. category .. "." .. tostring(tutorial) .. "_BTN")
							:MakePositive()
							:Fn(function()
								--play lesson message
								cx:Talk("LESSONS.TUTORIALS." .. category .. "." .. tostring(tutorial))
								
								--see how many tutorials the player has completed, give a reward if needed
								NumTutorialCompletions(tostring(tutorial))
								
								--go back to the lesson menu
								SubMenu(category, lessons_table)
							end)
					--PLAYERS ALREADY READ THIS TUTORIAL BUT IS REPEATING IT
					else
						cx:Opt("LESSONS.TUTORIALS." .. category .. "." .. tostring(tutorial) .. "_BTN_ALT")
							:MakePositive()
							:Fn(function()
								cx:Talk("LESSONS.REPEAT_LESSON_FIRST_LINE")
								--play lesson message
								cx:Talk("LESSONS.TUTORIALS." .. category .. "." .. tostring(tutorial))
								
								--see how many tutorials the player has completed, give a reward if needed
								NumTutorialCompletions(tostring(tutorial))
								
								--go back to the lesson menu
								SubMenu(category, lessons_table)
							end)
					end
				end

				cx:AddEnd("LESSONS.END_BTN_SUBMENU")
					:MakePositive()
					:Fn(function()
						cx:Talk("LESSONS.END_BTN_SUBMENU_RESPONSE")
					end)
			end
			
			cx:Talk("LESSONS.TALK_SELECT_CATEGORY")

			--CATEGORY MENU--
			--General Concepts SubMenu
			if EvalueCatCompletion(general_cat) then
				cx:Opt("LESSONS.TUTORIALS.GENERAL_BTN_ALT")
					:MakePositive()
					:Fn(function()
						cx:Talk("LESSONS.TALK_SELECT_GENERAL")
						SubMenu("GENERAL", general_cat)
					end)
			else
				cx:Opt("LESSONS.TUTORIALS.GENERAL_BTN")
					:MakePositive()
					:Fn(function()
						cx:Talk("LESSONS.TALK_SELECT_GENERAL")
						SubMenu("GENERAL", general_cat)
					end)
			end

			--Combat Concepts SubMenu
			if EvalueCatCompletion(combat_cat) then
				cx:Opt("LESSONS.TUTORIALS.COMBAT_BTN_ALT")
					:MakePositive()
					:Fn(function()
						cx:Talk("LESSONS.TALK_SELECT_COMBAT")
						SubMenu("COMBAT", combat_cat)
					end)
			else
				cx:Opt("LESSONS.TUTORIALS.COMBAT_BTN")
					:MakePositive()
					:Fn(function()
						cx:Talk("LESSONS.TALK_SELECT_COMBAT")
						SubMenu("COMBAT", combat_cat)
					end)
			end

			--Defense Concepts SubMenu
			if EvalueCatCompletion(defense_cat) then
				cx:Opt("LESSONS.TUTORIALS.DEFENSE_BTN_ALT")
					:MakePositive()
					:Fn(function()
						cx:Talk("LESSONS.TALK_SELECT_DEFENSE")
						SubMenu("DEFENSE", defense_cat)
					end)
			else
				cx:Opt("LESSONS.TUTORIALS.DEFENSE_BTN")
					:MakePositive()
					:Fn(function()
						cx:Talk("LESSONS.TALK_SELECT_DEFENSE")
						SubMenu("DEFENSE", defense_cat)
					end)
			end

			--Weapons SubMenu (WIP)
		--[[
			if EvalueCatCompletion(weapons_cat) then
				cx:Opt("LESSONS.TUTORIALS.WEAPONS_BTN_ALT")
					:MakePositive()
					:Fn(function()
						cx:Talk("LESSONS.TALK_SELECT_WEAPONS")
						SubMenu("WEAPONS", weapons_cat)
					end)
			else
				cx:Opt("LESSONS.TUTORIALS.WEAPONS_BTN")
					:MakePositive()
					:Fn(function()
						cx:Talk("LESSONS.TALK_SELECT_WEAPONS")
						SubMenu("WEAPONS", weapons_cat)
					end)
			end
		]]

			--Equipment SubMenu
			if EvalueCatCompletion(equipment_cat) then
				cx:Opt("LESSONS.TUTORIALS.EQUIPMENT_BTN_ALT")
					:MakePositive()
					:Fn(function()
						cx:Talk("LESSONS.TALK_SELECT_EQUIPMENT")
						SubMenu("EQUIPMENT", equipment_cat)
					end)
			else
				cx:Opt("LESSONS.TUTORIALS.EQUIPMENT_BTN")
					:MakePositive()
					:Fn(function()
						cx:Talk("LESSONS.TALK_SELECT_EQUIPMENT")
						SubMenu("EQUIPMENT", equipment_cat)
					end)
			end

			cx:AddEnd("LESSONS.END_BTN_MAINMENU")
					:MakePositive()
					:Fn(function()
						cx:Talk("LESSONS.END_BTN_MAINMENU_RESPONSE")
					end)
		end

		--CONVO LOGIC--
		local agent = cx.quest:GetCastMember("giver")

		if not agent.skip_talk then
			cx:Quip("giver", { "dojo_master", "tip_quip" })
			--[[if AllPlayers[2] == nil then
				cx:Quip("giver", { "dojo_master", "tip_quip" })
			else
				cx:Quip("giver", { "dojo_master", "tip_quip_mp, tip_quip" })
			end]]
		else
			agent.skip_talk = nil -- HACK
		end

		cx:Opt("OPT_TEACH")
			:MakePositive()
			:Fn(function()
				LessonMenu()
			end)

		cx:AddEnd()
	end)

return Q
