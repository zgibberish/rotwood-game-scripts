local Quip = require "questral.quip"

local quip_strings = require ("strings.strings_npc_armorsmith").QUIPS.quip_armorsmith_generic

-- These quips can appear from anywhere. If you want quips only while a quest
-- is active, then add them to that quest.
local C = Quip.CreateGlobalQuipContent()
C:AddQuips {
	Quip("armorsmith", "buystuff-pitch")
		:PossibleStrings(quip_strings)
}

return C
