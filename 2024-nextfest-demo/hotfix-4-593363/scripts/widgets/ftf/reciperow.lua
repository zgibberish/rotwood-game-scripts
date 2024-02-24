local PanelButton = require "widgets.panelbutton"
local Widget = require "widgets.widget"
local Image = require "widgets.image"
local Panel = require "widgets.panel"
local Text = require "widgets.text"
local CraftingMaterialsList = require "widgets.ftf.craftingmaterialslist"
local InventorySlot = require "widgets.ftf.inventoryslot"

local Consumable = require "defs.consumable"
local itemforge = require "defs.itemforge"
local lume = require "util.lume"
local easing = require "util.easing"

------------------------------------------------------------------------------------------
--- A simple holder for something else. It takes up a fixed width and then displays
--- an icon or text inside it centered within it
----

local RecipeRow = Class(Widget, function(self, width, height)
	Widget._ctor(self, "RecipeRow")

	self.width = width
	self.height = height
	self.icon_v_margin = 4
	self.button_v_margin = 9
	self.ingredient_v_margin = 16
	self.left_inset = 10 -- Amount of space between the left edge of the icon and the button
	self.icon_size = self.height - self.icon_v_margin*2
	self.ingredient_size = self.height - self.ingredient_v_margin*2

	self.button = self:AddChild(PanelButton("images/global/square.tex"))
		:SetNineSliceCoords(10, 10, 54, 54)
		:SetSize(self.width - self.left_inset, self.height-self.button_v_margin*2)
		:SetScaleOnFocus(false)
		:SetImageNormalColour(HexToRGB(0x59494966)) -- 40%
		:SetImageSelectedColour(HexToRGB(0x594949ff))
		:SetImageFocusColour(UICOLORS.FOCUS)

	self.hitbox = self.button:AddChild(Image("images/global/square.tex"))
		:SetName("Hitbox")
		:SetSize(self.width, self.height)
		:SetMultColor(0xff00ff00)
		:LayoutBounds("right", "center", self.button:GetImageWidget())
		:SendToBack()

	-- Item icon
	self.recipe_icon = self.button:AddChild(InventorySlot(self.icon_size))
		:IgnoreInput(true) -- Just act like an icon, not a button
		:ShowSelectionOutline() -- Prevents the brackets from showing up

	-- Item ingredients
	self.ingredientsList = self.button:AddChild(CraftingMaterialsList(height * 0.66, height * 0.3))

	self.selection_brackets = self.button:AddChild(Panel("images/ui_ftf_crafting/RecipeFocus.tex"))
		:SetNineSliceCoords(54, 56, 54, 56)
		:SetNineSliceBorderScale(0.7)
		:SetSize(self.icon_size + 8, self.icon_size + 8)
		:SetHiddenBoundingBox(true)

	self.owned = self.button:AddChild(Image("images/ui_ftf/ItemOwned.tex"))
		:SetSize(self.height * 0.33, self.height * 0.33)
		:SetHiddenBoundingBox(true)
		:SetToolTip("Owned")
		:Hide()
end)

--- So it can show if there are enough materials to build the item
function RecipeRow:SetPlayer(player)
	self.player = player
	self.ingredientsList:SetPlayer(self.player)

	self.inst:ListenForEvent("inventory_stackable_changed", function(owner, itemDef)
		self:OnInventoryChanged()
	end, self.player)

	return self
end

--- Displays a recipe in this row, for a recipe list
function RecipeRow:SetRecipeData(recipeData)
	self:SetName("RecipeRow Recipe " .. recipeData.def.name)

	-- Check if the player already owns this
	local owned = false
	local items = self.player.components.inventoryhoard:GetSlotItems(recipeData.def.slot)
	for _, item in ipairs(items) do
		if item.id == recipeData.def.name then
			owned = true
			break
		end
	end
	-- printf("SetRecipeData %s - %s", recipeData.def.name, owned)

	self.owned:SetShown(owned)

	self.recipeData = recipeData
	local item = itemforge.CreateEquipment(self.recipeData.slot, self.recipeData.def)

	self.recipe_icon:SetItem(item, self.player)

	self:OnInventoryChanged()
	return self
end

function RecipeRow:SortAndAddIngredientWidgets(widgets, test_fn)
	local filtered_ing = lume.filter(widgets, test_fn)

	filtered_ing = lume.sort(filtered_ing, function(a, b)
		local a_rarity = ITEM_RARITY.id[a.def.rarity]
		local b_rarity = ITEM_RARITY.id[b.def.rarity]
		if a_rarity == b_rarity then
			return a.cost > b.cost
		end
		return a_rarity < b_rarity
	end)

	for _, data in ipairs(filtered_ing) do
		self.costIngredientIcons:AddChild(data.w)
	end
end

--- When the player inventory changes, update the materials
function RecipeRow:OnInventoryChanged()
	if self.recipeData ~= nil then
		-- Refresh ingredients
		self.ingredientsList:SetIngredients(self.recipeData.ingredients)
		self:SetCanCraft(self.owned:IsShown() or self.recipeData:CanPlayerCraft(self.player))
		self:Layout()
	end
	return self
end

function RecipeRow:SetCanCraft(can_craft)
	if can_craft then
		self.button:SetTextures("images/global/square.tex")
		self.recipe_icon:SetIconMultColor(0xffffffff)
			:SetBackgroundMultColor(0xffffffff)
	else
		self.button:SetTextures("images/ui_ftf_crafting/RecipeUnavailable.tex")
		self.recipe_icon:SetIconMultColor(0x443e3eff)
			:SetBackgroundMultColor(0x4e4747ff)
	end
end

function RecipeRow:Click()
	self.button:OnGainFocus()
	self.button:Click()
	return self
end

function RecipeRow:SetOnClick(fn)
	self.button:SetOnClick(fn)
	return self
end

function RecipeRow:SetSelected(selected)
	-- Animate if newly selected
	if not self.button:IsSelected() and selected then
		self.selection_brackets:ScaleTo(1.1, 1.0, 0.1, easing.cubicinout)
	end
	self.selection_brackets:SetShown(selected)
	return self
end

function RecipeRow:Layout()
	self.recipe_icon:LayoutBounds("left", "center", self.button)
		:Offset(0, 0)
	self.selection_brackets:LayoutBounds("center", "center", self.recipe_icon)
	self.ingredientsList:LayoutBounds("after", "center", self.recipe_icon)
		:Offset(20)
	self.owned:LayoutBounds("right", "top", self.button:GetImageWidget())
		:Offset(5, 5)
	return self
end

return RecipeRow