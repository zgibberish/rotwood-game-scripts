local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Panel = require("widgets/panel")
local Text = require("widgets/text")
local InventorySlot = require"widgets.ftf.inventoryslot"

local itemforge = require "defs.itemforge"

------------------------------------------------------------------------------------------
--- Displays a prettied up icon for a selected recipe

local RecipeIconHeader = Class(Widget, function(self, max_width)
	Widget._ctor(self, "RecipeIconHeader")

	self.icon_size = 400
	self.max_width = max_width or 1000
	self.min_text_width = self.icon_size + 10
	self.max_text_width = self.max_width - 100

	-- Icon
	self.icon = self:AddChild(InventorySlot(self.icon_size))
		:IgnoreInput(true) -- Just act like an icon, not a button
		:SetBackground("images/ui_ftf_crafting/RecipeSlotSelection.tex", "images/ui_ftf_crafting/RecipeSlotOverlay.tex", "images/ui_ftf_crafting/RecipeSlotBackground.tex")

	-- Name tag
	self.title_bg = self:AddChild(Panel("images/ui_ftf_crafting/RecipeResultName.tex"))
		:SetNineSliceCoords(6, 74, 506, 80)
	self.title_left = self:AddChild(Image("images/ui_ftf_crafting/RecipeResultNameLeft.tex"))
		:SetSize(60, 100)
		:SendToBack()
	self.title_right = self:AddChild(Image("images/ui_ftf_crafting/RecipeResultNameRight.tex"))
		:SetSize(60, 100)
		:SendToBack()
	self.title = self:AddChild(Text(FONTFACE.DEFAULT, 46, "Recipe Details", UICOLORS.BLACK))
		:SetAutoSize(self.max_text_width)

	-- Rarity tag
	self.rarity_bg = self:AddChild(Panel("images/ui_ftf_crafting/RecipeResultRarity.tex"))
		:SetNineSliceCoords(100, 2, 408, 74)
		:SetNineSliceBorderScale(0.5)
		:SendToBack()
	self.rarity = self:AddChild(Text(FONTFACE.DEFAULT, 44, "Recipe Details", UICOLORS.LIGHT_TEXT_TITLE))
		:SetAutoSize(self.max_text_width)


	self:Layout()
end)

function RecipeIconHeader:SetRecipe(recipe)
	self.recipeData = recipe
	self.recipeDef = recipe.def

	-- Set item title
	local dummyItem = itemforge.CreateEquipment(self.recipeData.slot, self.recipeData.def)
	self.icon:SetItem(dummyItem)
	self.title:SetText(dummyItem:GetLocalizedName())

	-- Set item rarity
	local itemDef = dummyItem:GetDef()
	local rarity = itemDef.rarity or ITEM_RARITY.s.COMMON
	self.rarity:SetText(STRINGS.ITEMS.RARITY_CAPS[rarity])
		:SetGlyphColor(UICOLORS[rarity])
	self:Layout()
	return self
end

function RecipeIconHeader:SetItem(item)
	self.item = item

	-- Set item title
	self.icon:SetItem(self.item)
	self.title:SetText(self.item:GetLocalizedName())

	-- Set item rarity
	local itemDef = self.item:GetDef()
	local rarity = itemDef.rarity or ITEM_RARITY.s.COMMON
	self.rarity:SetText(STRINGS.ITEMS.RARITY_CAPS[rarity])
		:SetGlyphColor(UICOLORS[rarity])
	self:Layout()
	return self
end

function RecipeIconHeader:HideRarity()
	self.rarity_bg:Hide()
	self.rarity:Hide()
	return self
end

function RecipeIconHeader:Layout()

	-- Resize title label to text
	local title_w, title_h = self.title:GetSize()
	self.title_bg:SetSize(math.max(title_w, self.min_text_width) + 20, title_h + 32 * HACK_FOR_4K)
		:LayoutBounds("center", "below", self.icon)
		:Offset(0, 40)
	self.title_left:LayoutBounds("before", "bottom", self.title_bg)
		:Offset(1, 4)
	self.title_right:LayoutBounds("after", "bottom", self.title_bg)
		:Offset(-1, 4)
	self.title:LayoutBounds("center", "center", self.title_bg)
		:Offset(0, 4)

	-- Resize rarity label to text
	local rarity_w, rarity_h = self.rarity:GetSize()
	self.rarity_bg:SetSize(rarity_w + 130 * HACK_FOR_4K, rarity_h + 8)
		:LayoutBounds("center", "below", self.title_bg)
		:Offset(0, 1)
	self.rarity:LayoutBounds("center", "center", self.rarity_bg)
		:Offset(0, 1)

	return self
end

return RecipeIconHeader
