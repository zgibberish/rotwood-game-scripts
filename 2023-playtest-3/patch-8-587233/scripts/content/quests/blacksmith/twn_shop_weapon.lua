local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"
local Equipment = require"defs.equipment"

local quest_strings = require ("strings.strings_npc_blacksmith").QUESTS.twn_shop_weapon

local Q = Quest.CreateRecurringChat()
	:SetPriority(QUEST_PRIORITY.NORMAL)

Q:SetIsUnimportant()
Q:SetRateLimited(false)

Q:AddTags({"shop"})

Q:UpdateCast("giver")
	:FilterForPrefab("npc_blacksmith")

Q:AddObjective("resident")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

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

		-- cx:Opt("OPT_SHOP")
		-- 	:MakePositive()
		-- 	:MakeWeapon()
		-- 	:Fn(function()
		-- 		quest_helper.OpenShop(cx, require("screens.town.forgeweaponscreen"))
		-- 		cx:End()
		-- 	end)

		cx:Opt("OPT_GEM")
			:MakePositive()
			:MakeWeapon()
			:Fn(function()
				quest_helper.OpenShop(cx, require("screens.town.gemscreen"))
				cx:End()
			end)

		cx:AddEnd()
	end)


return Q
