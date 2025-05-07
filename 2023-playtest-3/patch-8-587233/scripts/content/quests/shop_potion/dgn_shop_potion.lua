local Convo = require "questral.convo"
local Quest = require "questral.quest"
local recipes = require "defs.recipes"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require ("strings.strings_npc_potionmaker_dungeon").QUESTS.dgn_shop_potion

local admission_recipe = recipes.ForSlot.PRICE.potion_refill

local Q = Quest.CreateRecurringChat()


Q:SetIsUnimportant()

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
end

------OBJECTIVE DECLARATIONS------
Q:AddObjective("no_resources")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("no_space")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("done")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("shop")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	-- :OnComplete(function(quest)
	-- 	quest:ActivateObjective("done")
	-- end)

------CONVERSATIONS AND QUESTS------

Q:OnAttract("no_resources", "giver", function(quest, node, sim)
	local player = quest:GetPlayer()
	return not admission_recipe:CanPlayerCraft(player) 
		and not quest_helper.PlayerHasRefilledPotion(player) 
end)
	:SetPriority(Convo.PRIORITY.HIGH)
	:Strings(quest_strings.no_resources)
	:Fn(function(cx)
		quest_helper.SetPlayerSpecies(cx)
		cx:Talk("TALK_NO_RESOURCES")

		cx:AddEnd("OPT_NEXT_TIME")
		quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 5)
	end)


Q:OnAttract("no_space", "giver", function(quest, node, sim)
	local player = quest:GetPlayer()
	return not quest_helper.PlayerNeedsPotion(player) 
		and not quest_helper.PlayerHasRefilledPotion(player) 
end)
	:SetPriority(Convo.PRIORITY.HIGH - 1)
	:Strings(quest_strings.no_space)
	:Fn(function(cx)
		quest_helper.SetPlayerSpecies(cx)
		cx:Talk("TALK_NO_SPACE")

		cx:AddEnd("OPT_NEXT_TIME")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("BYE")
				quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 3)
			end)
	end)


Q:OnAttract("shop", "giver", function(quest, node, sim)
		local player = quest:GetPlayer()
		return admission_recipe:CanPlayerCraft(player) 
			and not quest_helper.PlayerHasRefilledPotion(player) 
	end)
	:SetPriority(Convo.PRIORITY.LOWEST)
	:Strings(quest_strings.shop)
	:Fn(function(cx)
		quest_helper.SetPlayerSpecies(cx)
		cx:Talk("TALK_MINIGAME")

		cx:Opt("OPT_CONFIRM")
			:MakePositive()
			:CompleteObjective()
			:Fn(function(cx)
				local giver = quest_helper.GetGiver(cx)
				OnStartCooking(giver.inst, cx.quest:GetPlayer())
				cx:End()
			end)

		cx:AddEnd()
	end)

Q:OnAttract("done", "giver", function(quest, node, sim)
		local player = quest:GetPlayer()
		return quest_helper.PlayerHasRefilledPotion(player)
	end)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings.done)
	:Fn(function(cx)
		cx:Talk("TALK_DONE_GAME")
		quest_helper.GetGiver(cx).inst.components.timer:StartTimer("talk_cd", 7)
		cx:AddEnd()
	end)

return Q
