local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_konjurist").QUESTS.dgn_shop_powerupgrade

local Q = Quest.CreateRecurringChat()
	:SetPriority(QUEST_PRIORITY.HIGH)


Q:SetIsUnimportant()

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
	TheDungeon.HUD:HidePrompt(inst)

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

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForRole(Npc.Role.s.konjurist)

Q:AddCast("refiner")
	:FilterForPrefab("npc_refiner")
	:SetOptional()

------OBJECTIVE DECLARATIONS------

Q:AddObjective("chat_only")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("done")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("shop")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)
		quest:ActivateObjective("done")
	end)

-- Re-useable within multiple convos.
Q:AddStrings(quest_strings.lottie_desc)

------CONVERSATIONS AND QUESTS------

Q:OnAttract("shop", "giver", function(quest, node, sim)
	local player = quest:GetPlayer()
	return GetUpgradeablePowerCount(player) > 0
end)
	:FlagAsTemp()
	:SetPriority(Convo.PRIORITY.HIGH)
	:Strings(quest_strings.shop)
	:Fn(function(cx)
		cx:Talk("TALK_STORE")

		cx:Opt("OPT_UPGRADE")
			:MakePositive()
			--~ :CompleteObjective() -- allow re-entering upgrade state
			:Fn(function()
				local node = quest_helper.GetGiver(cx)
				local player = cx.quest:GetPlayer()
				OpenUpgradeScreen(node.inst, player, cx)

				-- We aren't preventing re-entering the shop, so activate that
				-- objective but don't complete this one.
				cx.quest:ActivateObjective("done")
				-- TODO: Should do something like this instead?
				--~ if GetUpgradeablePowerCount(player) == 0 then
				--~ 	cx:CompleteObjective()
				--~ end

				-- TODO(dbriscoe): This should use loop
				cx:End()
			end)

		if quest_helper.IsCastPresent(cx.quest, "refiner") then
			cx:Opt("OPT_LOTTIE_PRESENT")
				:MakePositive()
				:Fn(function()
					cx:Talk("TALK_LOTTIE_DESC")
					cx:AddEnd()
						:MakePositive()
				end)
		end

		cx:AddEnd("OPT_BACK")
	end)

Q:OnAttract("chat_only", "giver", function(quest, node, sim)
	local player = quest:GetPlayer()
	-- if the player doesn't have any upgradeable powers
	if GetUpgradeablePowerCount(player) == 0 then
		return CountUpgradesCompletedThisMeeting(node.inst, player) == 0
	end
end)
	:FlagAsTemp()
	:SetPriority(Convo.PRIORITY.HIGH)
	:Strings(quest_strings.chat_only)
	:Fn(function(cx)
		cx:Talk("TALK")

		if quest_helper.IsCastPresent(cx.quest, "refiner") then
			cx:Opt("OPT_LOTTIE_PRESENT")
				:MakePositive()
				:Fn(function()
					cx:Talk("TALK_LOTTIE_DESC")
					cx:AddEnd()
						:MakePositive()
				end)
		end

		cx:AddEnd("OPT_NEXT_TIME")
	end)

Q:OnAttract("done", "giver", function(quest, node, sim)
	local player = quest:GetPlayer()
	-- the player has no upgradeable powers, but upgraded something this room
	return GetUpgradeablePowerCount(player) == 0
		and CountUpgradesCompletedThisMeeting(node.inst, player) > 0
end)
	:FlagAsTemp()
	:SetPriority(Convo.PRIORITY.HIGH)
	:Strings(quest_strings.done)
	:Fn(function(cx)
		cx:Talk("TALK_DONE")

		cx:AddEnd()
			:MakePositive()
	end)


return Q
