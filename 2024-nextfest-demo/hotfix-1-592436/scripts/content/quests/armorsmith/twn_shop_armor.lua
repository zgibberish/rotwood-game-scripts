local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"
local Equipment = require"defs.equipment"

local quest_strings = require ("strings.strings_npc_armorsmith").QUESTS.twn_shop_armor

local Q = Quest.CreateRecurringChat()

Q:SetIsUnimportant()
Q:SetRateLimited(false)

Q:AddTags({"shop"})
Q:UpdateCast("giver")
	:FilterForPrefab("npc_armorsmith")

Q:AddObjective("resident")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:OnTownShopChat("resident", "giver")
	:FlagAsTemp()
	:Strings(quest_strings.resident)
	:Fn(function(cx)
		local agent = quest_helper.GetGiver(cx)

		if not agent.skip_talk then
			cx:Talk("TALK_RESIDENT")
		else
			agent.skip_talk = nil -- HACK
		end

		cx:Opt("OPT_SHOP")
			:MakePositive()
			:MakeArmor()
			:Fn(function()
				quest_helper.OpenShop(cx, require("screens.town.forgearmourscreen"))
				cx:End()
			end)

		cx:AddEnd("OPT_LEAVE")
	end)

return Q
