local Equipment = require("defs.equipment")
local RecipeScreen = require("screens.town.recipescreen")
local FoodCraftingPanel = require"widgets.ftf.foodcraftingpanel"

local itemforge = require "defs.itemforge"

local function get_slots()
	return {{ slot = Equipment.Slots.FOOD }}
end

local FoodScreen = Class(RecipeScreen, function(self, player, npc)
	local equipment_slots = get_slots()
	RecipeScreen._ctor(self, "FoodScreen", player, equipment_slots)

	self:SetTitle(STRINGS.UI.FOODSCREEN.MENU_TITLE)

	-- self.craftingPanel:Remove()
	-- self.craftingPanel = self:AddChild(FoodCraftingPanel(player, equipment_slots, npc))
	-- 	:SetOnCloseFn(function() self:OnCloseButton() end)
	-- 	:LayoutBounds("after", nil, self.recipeDetailsPanel)
	-- 	-- :SetMannequinPanel(self.mannequinPanel)
	-- 	:SetOnRecipeSelectedFn(function(recipeData)
	-- 		self.recipeDetailsPanel:SetRecipe(recipeData)
	-- 		-- Update the character panel
	-- 		local dummy_item = itemforge.CreateEquipment(recipeData.slot, recipeData.def)
	-- 		self.equipmentPanel:EquipItem(recipeData.slot, dummy_item)
	-- 	end)

	self.default_focus = self.craftingPanel.closeButton
end)

return FoodScreen