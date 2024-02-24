local Convo = require "questral.convo"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require ("strings.strings_npc_armorsmith_dungeon").QUESTS.dgn_shop_armorsmith

local Q = Quest.CreateRecurringChat()

Q:SetIsUnimportant()

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForRole("dungeon_armorsmith")

------OBJECTIVE DECLARATIONS------

Q:AddObjective("shop")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	-- :OnComplete(function(quest)
	-- 	quest:ActivateObjective("done")
	-- end)

------CONVERSATIONS AND QUESTS------

Q:OnAttract("shop", "giver")
	:SetPriority(Convo.PRIORITY.LOWEST)
	:Strings(quest_strings.shop)
	:Fn(function(cx)
		cx:Talk("TALK")

		cx:AddEnd()
	end)

return Q
