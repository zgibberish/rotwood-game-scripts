local Convo = require "questral.convo"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_apothecary").QUESTS.twn_shop_apothecary

local Q = Quest.CreateRecurringChat()

Q:SetRateLimited(false)
Q:SetIsUnimportant()

Q:AddTags({"shop"})

Q:UpdateCast("giver")
	:FilterForPrefab("npc_apothecary")

Q:AddObjective("introduction")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)
		quest:ActivateObjective("build_home")
	end)

Q:AddObjective("build_home")
	:OnComplete(function(quest)
		quest:ActivateObjective("resident")
	end)

Q:AddObjective("resident")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:OnAttract("resident", "giver")
	:Strings(quest_strings.attract_resident)
	:Fn(function(cx)
		cx:Talk("TALK_RESIDENT")
	end)

Q:OnTownShopChat("resident", "giver")
	:Strings(quest_strings.shop_chat_resident)
	:Fn(function(cx)
		local agent = cx.quest:GetCastMember("giver")
		if not agent.skip_talk then
			cx:Talk("TALK_RESIDENT")
		else
			agent.skip_talk = nil -- HACK
		end

		cx:Opt("OPT_SHOP")
			:MakePositive()
			:MakePotion()
			:Fn(function()
				quest_helper.OpenShop(cx, require("screens.town.createelixirscreen"))
				cx:End()
			end)

		cx:AddEnd()
	end)

return Q
