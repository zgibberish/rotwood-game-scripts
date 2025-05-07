local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local Quip = require "questral.quip"
local iterator = require "util.iterator"
local kassert = require "util.kassert"
local lume = require "util.lume"
local quest_helper = require "questral.game.rotwoodquestutil"

-- For this super generic fallback, let's keep all of this together instead of
-- duplicating this quest for every npc. We can additional write more specific
-- fallback quests for each npc with custom behaviour.
local role_strings = {
	--
	--
	--
	--
	-- Hi writers! To give an npc a fallback quip, open their string file and
	-- ensure QUESTS.twn_fallback_chat is setup with a list of lines for them
	-- to say.
	--
	--
	--
	apothecary          = require("strings.strings_npc_apothecary").QUESTS.twn_fallback_chat,
	armorsmith          = require("strings.strings_npc_armorsmith").QUESTS.twn_fallback_chat,
	blacksmith          = require("strings.strings_npc_blacksmith").QUESTS.twn_fallback_chat,
	cook                = require("strings.strings_npc_cook").QUESTS.twn_fallback_chat,
	dojo_master         = require("strings.strings_npc_dojo_master").QUESTS.twn_fallback_chat,
	konjurist           = require("strings.strings_npc_konjurist").QUESTS.twn_fallback_chat,
	refiner             = require("strings.strings_npc_refiner").QUESTS.twn_fallback_chat,
	scout               = require("strings.strings_npc_scout").QUESTS.twn_fallback_chat,
	specialeventhost    = require("strings.strings_npc_specialeventhost").QUESTS.twn_fallback_chat,
	travelling_salesman = require("strings.strings_npc_potionmaker_dungeon").QUESTS.twn_fallback_chat,
}
local quest_strings = require("strings.strings_npc_generic").QUESTS.twn_fallback_chat


local Q = Quest.CreateRecurringChat()

Q:AddTags({"fallback"})

Q:AllowDuplicates(true)
Q:SetIsTemporary(true)

-- Should/can we make this a single fallback quest instance shared by all npcs?
Q:UpdateCast("giver")
	:SetDeferred()

Q:AddObjective("chitchat")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:SetRateLimited(false)
Q:SetIsUnimportant()

-- Default all roles to fallback
local role_to_str = lume(Npc.Role:Ordered())
	:invert()
	:enumerate(function(k, v)
		return quest_strings.QUIP_CHITCHAT
	end)
	:result()
for role,quip_strings in iterator.sorted_pairs(role_strings) do
	kassert.assert_fmt(Npc.Role:Contains(role), "Invalid role '%s'.", role)
	if quip_strings.QUIP_CHITCHAT then
		-- Once a writer populates the string, we can override the fallback string.
		role_to_str[role] = quip_strings.QUIP_CHITCHAT
	end
end
-- Build quips
local quips = {}
for role,quip_strings in pairs(role_to_str) do
	kassert.typeof("table", quip_strings)
	kassert.typeof("string", quip_strings[1]) -- quips are a table of strings
	local q = Quip(role, "chitchat")
		:PossibleStrings(quip_strings)
	table.insert(quips, q)
end

Q:OnAttract("chitchat", "giver")
	:SetPriority(Convo.PRIORITY.LOWEST)
	:Quips(quips)
	:Fn(function(cx)
		cx:FlagAsUnimportantConvo()
		local node = quest_helper.GetGiver(cx)
		local role = node.inst.components.npc:GetRole()
		-- The role must always match, so we should never see cross-character
		-- mixups. You can write chitchat quips in a CreateGlobalQuipContent
		-- and they can show up here or Q:AddQuips on a quest and they'll show
		-- up when the giver is cast in that quest.
		cx:Quip("giver", { role, "chitchat" })
		cx:AddEnd()
	end)

return Q
