local Equipment = require("defs.equipment")
local RecipeScreen = require("screens.town.recipescreen")

local function get_slots()
	local slots = {
		{ slot = Equipment.Slots.POTIONS },
		{ slot = Equipment.Slots.TONICS }
	}
	return slots
end

local CreateElixirScreen = Class(RecipeScreen, function(self, player)
	RecipeScreen._ctor(self, "CreateElixirScreen", player, get_slots())
	self:SetTitle(STRINGS.UI.CREATEELIXIRSCREEN.MENU_TITLE)
end)

return CreateElixirScreen
