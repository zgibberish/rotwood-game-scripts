local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"

local quest_strings = require("strings.strings_npc_dojo_master").QUESTS.twn_shop_dojo

local Q = Quest.CreateRecurringChat()

Q:SetIsUnimportant()
Q:SetRateLimited(false)

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForPrefab("npc_dojo_master")

------OBJECTIVE DECLARATIONS------

Q:AddObjective("resident")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

------CONVERSATIONS AND QUESTS------

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
			:Fn(function()
				cx:End()
			end)

		cx:AddEnd()
	end)

return Q
