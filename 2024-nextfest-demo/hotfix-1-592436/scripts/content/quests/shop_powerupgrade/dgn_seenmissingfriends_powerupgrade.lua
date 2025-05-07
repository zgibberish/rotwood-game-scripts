local Convo = require "questral.convo"
local Quest = require "questral.quest"
local recipes = require "defs.recipes"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_konjurist").QUESTS.seen_missing_friends

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGHEST)

local function GetUpgradeablePowerCount(player)
	local powers = player.components.powermanager:GetUpgradeablePowers()
	return #powers
end

-- TODO(dbriscoe): Handle upgrade tracking with an objective.
local function CountUpgradesCompletedThisMeeting(inst, player)
	return inst.components.conversation.temp.upgrades_done and inst.components.conversation.temp.upgrades_done[player] or 0
end

local function OnDoUpgrade(inst, player)
	-- Only persists in the current room -- not in next room.
	if not inst.components.conversation.temp.upgrades_done then
		inst.components.conversation.temp.upgrades_done = {}
	end

	if not inst.components.conversation.temp.upgrades_done[player] then
		inst.components.conversation.temp.upgrades_done[player] = 0
	end

	inst.components.conversation.temp.upgrades_done[player] = inst.components.conversation.temp.upgrades_done[player] + 1
end

local function OpenUpgradeScreen(inst, player, cx)
	dbassert(inst, "Need the giver entity.")
	--TheDungeon.HUD:HidePrompt(inst)

	local PowerSelectionScreen = require "screens.dungeon.powerselectionscreen"
	local powers = player.components.powermanager:GetUpgradeablePowers()
	local screen = PowerSelectionScreen(player, powers, PowerSelectionScreen.SelectAction.s.Upgrade, function()
		OnDoUpgrade(inst, player)
		quest_helper.ConvoCooldownGiver(cx, 145 * TICKS)
		inst:DoTaskInTicks(145, function()
			if GetUpgradeablePowerCount(player) > 0 then
				OpenUpgradeScreen(inst, player, cx)
			end
		end) --TODO: Roughly timed to upgrade anim length. With new conversation system, can maybe sequence this instead?
	end,
	inst.components.conversation.temp.upgrades_done == nil or -- Nobody has done any upgrades yet
		(inst.components.conversation.temp.upgrades_done and not inst.components.conversation.temp.upgrades_done[player]) or -- This player joined late and isn't in the list yet
		(inst.components.conversation.temp.upgrades_done and inst.components.conversation.temp.upgrades_done[player] and inst.components.conversation.temp.upgrades_done[player] == 0)) -- Someone has upgraded, they know about us, and we haven't done an upgrade yet.
	TheFrontEnd:PushScreen(screen)

	-- TODO(dbriscoe): We should do it like this:
	--~ while GetUpgradeablePowerCount(player) > 0 do
	--~ 	cx:PresentCallbackScreen(PowerSelectionScreen, player, powers, "Upgrade", function()
	--~ 		OnDoUpgrade(inst, player)
	--~ 	end)
	--~ 	-- TODO(dbriscoe): can we support a wait like this? How to make it robust?
	--~ 	cx:WaitForAnimOver(player)
	--~ end
end

local function OpenRemoveScreen(inst, player)
	-- Close prompt to ensure it doesn't activate during song.
	TheDungeon.HUD:HidePrompt(inst)
end

local function OnDoRemove(inst, player)
	-- remove_price:TakeIngredientsFromPlayer(player)
end

--the player's hunter species will be inserted here at runtime
Q:AddVar("species", "PLACEHOLDER")

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForRole("konjurist")

Q:UnlockWorldFlagsOnComplete{"wf_konjurist"}

------OBJECTIVE DECLARATIONS------
--ask Alki if she's seen your missing friends (most likely happens in starting forest)
Q:AddObjective("seen_missing_friends")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
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
		quest:ActivateObjective("seen_blacksmith_in_owlitzer")
	end)

--player makes it to Owlitzer forest. Alki tells you she's heard Hamish further inside
Q:AddObjective("seen_blacksmith_in_owlitzer")
	:OnActivate(function(quest)
		if quest_helper.AlreadyHasCharacter("blacksmith") then
			quest:Complete("seen_blacksmith_in_owlitzer")
		end
	end)
	:OnEvent("playerentered", function(quest)
		-- runs every room
		if quest_helper.AlreadyHasCharacter("blacksmith") then
			quest:Complete("seen_blacksmith_in_owlitzer")
		end
	end)
	:OnComplete(function(quest)
		quest_helper.CompleteQuestOnRoomExit(quest)
	end)

quest_helper.AddCompleteQuestOnRoomExitObjective(Q)

------CONVERSATIONS AND QUESTS------

Q:OnAttract("seen_missing_friends", "giver", function(quest, node, sim)	return not quest_helper.AlreadyHasCharacter("blacksmith") end)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings.starting_forest)
	:Fn(function(cx)

		local function CompleteObjective()
			cx.quest:Complete("seen_missing_friends")
		end

		local function AddEndBtn(btnStr)
			cx:AddEnd(btnStr)
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("TALK4")
					CompleteObjective()
				end)
		end

		local giver = quest_helper.GetGiver(cx)
		local player = cx.quest:GetPlayer()

		--switches buttons and responses based on your interactions with the Yammo miniboss
		local function AltResponseSwitch(choiceBtnStr, responseStr, upgradeBtnStr, endStr)
			cx:Opt(choiceBtnStr)
				:MakePositive()
				:Fn(function(cx)
					cx:Talk(responseStr)

					if GetUpgradeablePowerCount(player) > 0 then
						--player opens the upgrade screen
						cx:Opt(upgradeBtnStr)
							:MakePositive()
							:Fn(function(cx)
								--Open Upgrade Panel
								OpenUpgradeScreen(giver.inst, player, cx)
								CompleteObjective()
								cx:End()
							end)
					end

					--player ends the convo
					cx:AddEnd("OPT_3B")
						:MakePositive()
						:Fn(function(cx)
							cx:Talk("TALK4")
							CompleteObjective()
						end)
				end)
			--exit button is available regard of what the above option is
			AddEndBtn("OPT_END")
		end

		--switches based on which npcs you still need to recruit
		local function BernaHamishSwitch(btnStr)
			cx:Opt(btnStr)
				:MakePositive()
				:Fn(function()
					--!! YAMMO !!--
					if quest_helper.IsInDungeon("treemon_forest") then 
						cx:Talk("TALK3_YAMMO")
						--check if the players already killed yammo
						if player:IsFlagUnlocked("pf_first_miniboss_defeated") then
							AltResponseSwitch(
								"OPT_ALT_KILLED_YAMMO", 
								"OPT_KILLED_YAMMO_RESPONSE", 
								"OPT_3A_ALT")

						--player hasnt seen yammo yet
						elseif player:IsFlagUnlocked("pf_owlitzer_miniboss_seen") == nil or player:IsFlagUnlocked("pf_owlitzer_miniboss_seen") == false then
							AltResponseSwitch(
								"OPT_ALT_EXPLAIN_YAMMO", 
								"OPT_EXPLAIN_YAMMO_RESPONSE", 
								"OPT_3A")

						--players seen yammo but hasnt killed it
						else
							AltResponseSwitch(
								"OPT_ALT_SEEN_YAMMO", 
								"OPT_SEEN_YAMMO_RESPONSE", 
								"OPT_3A")
						end
					--!! GOURDOS !!--
					elseif quest_helper.IsInDungeon("owlitzer_forest") then
						cx:Talk("TALK3_GOURDO")
						--check if the players already killed gourdos
						if player:IsFlagUnlocked("pf_owltizer_miniboss_defeated") then
							AltResponseSwitch(
								"OPT_ALT_KILLED_GOURDO", 
								"OPT_KILLED_GOURDO_RESPONSE", 
								"OPT_3A_ALT")

						--player hasnt seen gourdos yet
						elseif player:IsFlagUnlocked("pf_owlitzer_miniboss_seen") == nil or player:IsFlagUnlocked("pf_owlitzer_miniboss_seen") == false then
							AltResponseSwitch(
								"OPT_ALT_EXPLAIN_GOURDO", 
								"OPT_EXPLAIN_GOURDO_RESPONSE", 
								"OPT_3A")

						--players seen gourdos but hasnt killed them
						else
							AltResponseSwitch(
								"OPT_ALT_SEEN_GOURDO", 
								"OPT_SEEN_GOURDO_RESPONSE", 
								"OPT_3A")
						end
					end
				end)
			--exit button is available regard of what the above option is
			AddEndBtn("OPT_1B_ALT")
		end

		cx:Talk("TALK")

		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function(cx)
				--npc response
				cx:Talk("TALK2")

				--check who to ask alki about
				if not TheWorld:IsFlagUnlocked("wf_town_has_armorsmith") then
					--player doesnt have Berna or Hamish
					if not TheWorld:IsFlagUnlocked("wf_town_has_blacksmith") then
						BernaHamishSwitch("OPT_BERNA_AND_HAMISH")
					--player is missing Berna only
					else
						BernaHamishSwitch("OPT_NEED_BERNA")
					end
				else
					--player is missing Hamish only
					if not TheWorld:IsFlagUnlocked("wf_town_has_blacksmith") then
						BernaHamishSwitch("OPT_NEED_HAMISH")
					end
				end
			end)

		AddEndBtn("OPT_1B")
	end)

Q:OnAttract("seen_blacksmith_in_owlitzer", "giver", function(quest, node, sim) print("HEY\n\n") print(quest_helper.IsInDungeon("owlitzer_forest"))	return quest_helper.IsInDungeon("owlitzer_forest") and not quest_helper.AlreadyHasCharacter("blacksmith") end)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings.owlitzer_forest)
	:Fn(function(cx)
		local function CompleteObjective()
			cx.quest:Complete("seen_blacksmith_in_owlitzer")
		end

		cx:Talk("TALK")

		cx:Opt("OPT_1A")
			:MakePositive()
		cx:Opt("OPT_1B")
			:MakePositive()
		cx:Opt("OPT_1C")
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
				end)

			cx:JoinAllOpt_Fn(function()
				cx:Talk("TALK3")

				local giver = quest_helper.GetGiver(cx)
				local player = cx.quest:GetPlayer()
				if GetUpgradeablePowerCount(player) > 0 then
					--player opens the upgrade screen
					cx:Opt("OPT_3A")
						:MakePositive()
						:Fn(function(cx)
							--Open Upgrade Panel
							OpenUpgradeScreen(giver.inst, player, cx)
							CompleteObjective()
							cx:End()
						end)
				end
				cx:AddEnd("OPT_3B")
					:MakePositive()
					:Fn(function()
						CompleteObjective()
						cx:Talk("BYE")
					end)
			end)
		end)
	end)

return Q
