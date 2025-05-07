local Quip = require "questral.quip"

local quip_strings = require ("strings.strings_npc_scout").QUIPS.quip_scout_generic

local C = Quip.CreateGlobalQuipContent()
C:AddQuips {
	Quip("scout", "instruction", "startrun")
		:PossibleStrings(quip_strings)
}

return C
