local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local recipes = require "defs.recipes"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_cook").QUESTS.twn_shop_cook

local admission_recipe = recipes.ForSlot.PRICE.potion_refill

local function OnStartCooking(inst, player)
	-- Close prompt to ensure it doesn't activate during song.
	TheDungeon.HUD:HidePrompt(inst)

	-- Don't CraftItemForPlayer because the recipe is the entry cost.
	admission_recipe:TakeIngredientsFromPlayer(player)

	player.components.potiondrinker:RefillPotion()
	TheDungeon:GetDungeonMap():RecordActionInCurrentRoom("cook")
end

local Q = Quest.CreateRecurringChat()

Q:SetIsUnimportant()
Q:SetRateLimited(false)

Q:AddTags({"shop"})

Q:UpdateCast("giver")
	:FilterForPrefab("npc_cook")

Q:AddCast("berna")
	:FilterForPrefab("npc_armorsmith")

Q:AddCast("flitt")
	:FilterForPrefab("npc_scout")

Q:AddObjective("resident")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("minigame")
	-- :InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)
		quest:ActivateObjective("done")
	end)

Q:AddObjective("done")

Q:OnTownShopChat("resident", "giver")
	:FlagAsTemp()
	:Strings(quest_strings.resident)
	:Fn(function(cx)
		local agent = cx.quest:GetCastMember("giver")
		if not agent.skip_talk then
			cx:Talk("TALK_RESIDENT")
		else
			agent.skip_talk = nil -- HACK
		end

		cx:Opt("OPT_SHOP")
			:MakePositive()
			:SetRightText("<p img='images/ui_ftf_dialog/convo_food.tex' color=0>")
			:Fn(function()
				quest_helper.OpenShop(cx, require("screens.town.foodscreen"))
				cx:End()
			end)


		cx:AddEnd()
	end)

-- TODO(dbriscoe): Move minigame to a separate quest?
Q:OnAttract("minigame", "giver", function(quest, node, sim)
	local player = node:GetInteractingPlayerEntity()
	return admission_recipe:CanPlayerCraft(player)
end)
	:FlagAsTemp()
	:Strings(quest_strings.minigame)
	:Fn(function(cx)
		-- TODO: Setup primary_ingredient_name
		cx:Talk("TALK_MINIGAME")

		cx:Opt("OPT_CONFIRM")
			:MakePositive()
			:Fn(function()
				local node = quest_helper.GetGiver(cx)
				local inst = node.inst
				local player = node:GetInteractingPlayerEntity()
				OnStartCooking(inst, player)
				cx:End()
			end)

		cx:AddEnd()
	end)

Q:OnAttract("done", "giver")
	:FlagAsTemp()
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings.done)
	:Fn(function(cx)
		cx:Talk("TALK_DONE_GAME")

		cx:AddEnd()
	end)

return Q
