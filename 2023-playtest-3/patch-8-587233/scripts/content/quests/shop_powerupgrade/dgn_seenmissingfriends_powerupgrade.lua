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
	-- upgrade_price:TakeIngredientsFromPlayer(player)
	-- Only persists in the current room -- not in next room.
	if not inst.components.conversation.temp.upgrades_done then
		inst.components.conversation.temp.upgrades_done = {}
		for i=1,#AllPlayers do
			inst.components.conversation.temp.upgrades_done[AllPlayers[i]] = 0
		end
	end

	inst.components.conversation.temp.upgrades_done[player] = inst.components.conversation.temp.upgrades_done[player] + 1
end

local function OpenUpgradeScreen(inst, player, cx)
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
	end)
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

		cx:Talk("TALK")

		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("BLACKSMITH")

				--npc response
				cx:Talk("TALK2")

				--check if a yammos been seen in this world before and build hype if not
				if TheWorld:IsFlagUnlocked("first_miniboss_seen") == nil or TheWorld:IsFlagUnlocked("first_miniboss_seen") == false then
					cx:Talk("TALK2_A")

					cx:Opt("OPT_2A")
						:MakePositive()
						:Fn(function(cx)
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

							--player ends the convo
							cx:AddEnd("OPT_3B")
								:MakePositive()
								:Fn(function(cx)
									cx:Talk("TALK4")
									CompleteObjective()
								end)
						end)
				end

				cx:AddEnd("OPT_2B")
					:MakePositive()
					:Fn(function(cx)
						CompleteObjective()
					end)
			end)
		cx:AddEnd("OPT_1B")
			:MakePositive()
			:Fn(function(cx)
				CompleteObjective()
			end)
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