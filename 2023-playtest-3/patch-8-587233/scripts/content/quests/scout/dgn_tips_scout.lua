local Convo = require "questral.convo"
local Equipment = require "defs.equipment"
local Quest = require "questral.quest"
local Quip = require "questral.quip"

local quest_strings = require("strings.strings_npc_scout").QUIPS.dgn_tips_scout

-- Grab the enum strings, for brevity.
local weapon = Equipment.WeaponTag.s


local Q = Quest.CreateRecurringChat()

Q:SetIsUnimportant()

Q:UpdateCast("giver")
	:FilterForPrefab("npc_scout")

Q:AddCast("current_dungeon")
	:CastFn(function(quest, root)
		return root:GetCurrentLocation()
	end)

Q:AddObjective("give_tip")
	:AppearInDungeon_Entrance()
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)
		quest:Complete()
	end)


Q:AddQuips {
	Quip("gameplay_tip")
		:Tag("gameplay_tip") -- need a scoring tag to tie with other weapon tips.
		:Not(weapon.cannon) -- cannon dodge is very different TODO(jambell): right?
		:PossibleStrings(quest_strings.DODGE_NO_CANNON),

	Quip("gameplay_tip", weapon.hammer)
		:PossibleStrings(quest_strings.HAMMER),

	Quip("gameplay_tip", weapon.polearm)
		:PossibleStrings(quest_strings.POLEARM),

	-- Fallback if nothing else matches.
	Quip("gameplay_tip")
		:Tag("gameplay_tip", 0) -- contribute nothing to score so we don't choose it over another quip.
		:PossibleStrings(quest_strings.FALLBACK)
}

Q:OnDungeonChat("give_tip", "giver", Quest.Filters.InDungeon_Entrance)
	:SetPriority(Convo.PRIORITY.LOW)
	:Fn(function(cx)
		local giver = cx.quest:GetCastMember("giver")
		local player = giver:GetInteractingPlayerEntity()
		local weapontag = player.components.inventory:GetEquippedWeaponTag()
		-- The first tag must match. The following ones are optional.
		cx:Quip(giver, { "gameplay_tip", weapontag, })
	end)

return Q
