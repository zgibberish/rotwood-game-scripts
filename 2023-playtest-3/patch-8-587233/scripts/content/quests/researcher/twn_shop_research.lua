local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_refiner").QUESTS.twn_shop_research

local Q = Quest.CreateRecurringChat()

Q:SetIsUnimportant()
Q:SetRateLimited(false)

Q:AddTags({"shop"})

Q:UpdateCast("giver")
	:FilterForRole(Npc.Role.s.refiner)

Q:AddObjective("resident")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:OnTownShopChat("resident", "giver")
	:FlagAsTemp()
	:Strings(quest_strings.shop_chat_resident)
	:Fn(function(cx)
		local agent = cx.quest:GetCastMember("giver")
		if not agent.skip_talk then
			cx:Talk("TALK_RESIDENT")
		else
			agent.skip_talk = nil -- HACK
		end

		cx:AddEnd("OPT_RESEARCH")
			:MakePositive()
			:Fn(function()
				-- quest_helper.OpenShop(cx, require("screens.town.researchscreen"))
			end)

		cx:AddEnd()
	end)

Q:OnAttract("resident", "giver")
	:Strings(quest_strings.attract_resident)
	:Fn(function(cx)
		cx:Talk("TALK_RESIDENT")
	end)

return Q
