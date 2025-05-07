local Consumable = require "defs.consumable"
local Image = require("widgets/image")
local Text = require("widgets/text")
local Widget = require("widgets/widget")

-------------------------------------------------------------------------------------------------
--- Displays an horizontal listing of crafting/forging material requirements
local CraftingMaterialsList = Class(Widget, function(self, icon_size, font_size)
	Widget._ctor(self, "CraftingMaterialsList")

	self.icon_size = icon_size or 50
	self.font_size = font_size or 30
	self.spacing_h = 20

	self.normal_color = UICOLORS.LIGHT_TEXT
	self.insufficient_color = UICOLORS.PENALTY
end)

--- So it can show if there are enough materials to build the item
function CraftingMaterialsList:SetPlayer(player)
	self.player = player
	return self
end

function CraftingMaterialsList:SetTextColor(normal_color, insufficient_color)
	self.normal_color = normal_color or UICOLORS.LIGHT_TEXT
	self.insufficient_color = insufficient_color or UICOLORS.PENALTY
	return self
end

function CraftingMaterialsList:SetRecipe(recipe)
	return self:SetIngredients(recipe.ingredients)
end

function CraftingMaterialsList:ShowOnlyCost(show_only_cost)
	self.show_only_cost = show_only_cost
	return self
end

--- Takes in a list in this format
-- {glitz: 200, generic_bone: 4, ...}
function CraftingMaterialsList:SetIngredients(requiredMaterials)
	-- Remove old ingredients
	self:RemoveAllChildren()

	-- Add new ingredients
	if requiredMaterials then
		for id, quantity in pairs(requiredMaterials) do
			local mat_def = Consumable.Items.MATERIALS[id]
			assert(mat_def, id)

			-- Assemble our widget
			local requiredMaterialRoot = self:AddChild(Widget())
				:SetToolTip(mat_def.pretty.name)

			-- Add an icon
			requiredMaterialRoot.icon = requiredMaterialRoot:AddChild(Image(mat_def.icon))
				:SetSize(self.icon_size, self.icon_size)

			-- Check if we have a player to gauge material availability
			local requiredMaterialTextColor = self.normal_color
			local quantityText = quantity
			if self.player then
				local material_count = self.player.components.inventoryhoard:GetStackableCount(mat_def)
				local hasRequiredMaterials = material_count >= quantity
				requiredMaterialTextColor = hasRequiredMaterials and self.normal_color or self.insufficient_color
				if id == "glitz" then -- Don't show the player's total glitz
					quantityText = quantity
				elseif self.show_only_cost then
					quantityText = quantity
				else
					quantityText = material_count .. "/" .. quantity
				end
			end

			requiredMaterialRoot:AddChild(Text(FONTFACE.DEFAULT, self.font_size, quantityText, requiredMaterialTextColor))
				:LayoutBounds("after", "center", requiredMaterialRoot.icon)
				:Offset(5, 0)

			-- So glitz shows first
			local def = Consumable.Items.MATERIALS[id]
			if def.tags.currency then requiredMaterialRoot:SendToBack() end
		end

		-- Layout materials
		self:LayoutChildrenInGrid(3, self.spacing_h)
	end
    return self
end

--- Returns the icons for the various items, so they can be animated elsewhere
function CraftingMaterialsList:GetMaterialIconWidgets()
	local list = {}
	for k, v in ipairs(self.children) do
		table.insert(list, v.icon)
	end
	return list
end

return CraftingMaterialsList
