local CraftingMaterialsList = require("widgets/ftf/craftingmaterialslist")
local Image = require "widgets.image"
local Panel = require("widgets/panel")
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local easing = require "util.easing"
local recipes = require "defs.recipes"

local CraftableItemSlot = require"widgets.ftf.craftableitemslot"

------------------------------------------------------------------------------------------
--- A list of items that shows above the craft bar when a category is selected
local CraftableItemDetailsPanel = Class(Widget, function(self)
	Widget._ctor(self, "CraftableItemDetailsPanel")

	self.width = 500
	self.height = 120

	self.background = self:AddChild(Panel("images/ui_ftf_crafting/craft_details_bg.tex"))
		:SetNineSliceCoords(29, 29, 31, 31)
		:SetNineSliceBorderScale(0.5)
		:SetSize(self.width, self.height)
		:SetMultColor(UICOLORS.BACKGROUND_DARK)

	self.itemSlot = self:AddChild(CraftableItemSlot(self.height))
		:IgnoreInput()
		:LayoutBounds("left", "center", self.background)

	self.itemName = self:AddChild(Text(FONTFACE.BUTTON, FONTSIZE.BUTTON, "", UICOLORS.WHITE))
		:SetRegionSize(self.width - self.height - 40, 40)
		:SetHAlign(ANCHOR_LEFT)
		:LayoutBounds("after", "top", self.itemSlot)
		:Offset(20, -15)

	self.requiredMaterials = self:AddChild(CraftingMaterialsList())
		:SetPlayer(ThePlayer)

end)

function CraftableItemDetailsPanel:ShowCraftingInfo()
	self.inputHeight = 40
	self.inputOffset = 20

	self.craft_mode = true

	self.inputInfo = self:AddChild(Widget())

	self.inputBackground = self.inputInfo:AddChild(Panel("images/ui_ftf_crafting/craft_details_inputs_bg.tex"))
		:SetNineSliceCoords(29, 29, 31, 31)
		:SetNineSliceBorderScale(0.5)
		:SetMultColor(UICOLORS.FOCUS)
		:SetSize(self.width, self.inputHeight + self.inputOffset)

	self.inputText = self.inputInfo:AddChild(Widget())

	self.leftMouse = self.inputText:AddChild(Image("images/ui_ftf_crafting/craft_mouse_left_btn.tex"))
		:SetSize(30 * HACK_FOR_4K, 30 * HACK_FOR_4K)
		:SetMultColor(UICOLORS.BACKGROUND_DARK)

	self.leftMouseLabel = self.inputText:AddChild(Text(FONTFACE.BUTTON, 30, STRINGS.CRAFT_WIDGET.CRAFT_PLACE, UICOLORS.BACKGROUND_DARK))

	self.rightMouse = self.inputText:AddChild(Image("images/ui_ftf_crafting/craft_mouse_right_btn.tex"))
		:SetSize(30 * HACK_FOR_4K, 30 * HACK_FOR_4K)
		:SetMultColor(UICOLORS.BACKGROUND_DARK)

	self.rightMouseLabel = self.inputText:AddChild(Text(FONTFACE.BUTTON, 30, STRINGS.CRAFT_WIDGET.CRAFT_STORE, UICOLORS.BACKGROUND_DARK))

	return self
end

--- Displays a bar below the panel, with the mouse button info
function CraftableItemDetailsPanel:ShowPlacementInfo()
	self.inputHeight = 40
	self.inputOffset = 20

	self.craft_mode = false

	self.inputInfo = self:AddChild(Widget())

	self.inputBackground = self.inputInfo:AddChild(Panel("images/ui_ftf_crafting/craft_details_inputs_bg.tex"))
		:SetNineSliceCoords(29, 29, 31, 31)
		:SetNineSliceBorderScale(0.5)
		:SetMultColor(UICOLORS.FOCUS)
		:SetSize(self.width, self.inputHeight + self.inputOffset)

	self.inputText = self.inputInfo:AddChild(Widget())
	self.leftMouse = self.inputText:AddChild(Image("images/ui_ftf_crafting/craft_mouse_left_btn.tex"))
		:SetSize(30 * HACK_FOR_4K, 30 * HACK_FOR_4K)
		:SetMultColor(UICOLORS.BACKGROUND_DARK)

	self.leftMouseLabel = self.inputText:AddChild(Text(FONTFACE.BUTTON, 30, STRINGS.CRAFT_WIDGET.CRAFT_PLACE, UICOLORS.BACKGROUND_DARK))

	self.rightMouse = self.inputText:AddChild(Image("images/ui_ftf_crafting/craft_mouse_right_btn.tex"))
		:SetSize(30 * HACK_FOR_4K, 30 * HACK_FOR_4K)
		:SetMultColor(UICOLORS.BACKGROUND_DARK)

	self.rightMouseLabel = self.inputText:AddChild(Text(FONTFACE.BUTTON, 30, STRINGS.CRAFT_WIDGET.CANCEL, UICOLORS.BACKGROUND_DARK))

	return self
end

function CraftableItemDetailsPanel:RefreshInfoLayout()
	self.leftMouseLabel:LayoutBounds("after", "center", self.leftMouse):Offset(6, 0)
	self.rightMouse:LayoutBounds("after", "center", self.leftMouseLabel):Offset(40, 0)
	self.rightMouseLabel:LayoutBounds("after", "center", self.rightMouse):Offset(6, 0)
	self.inputText:LayoutBounds("center", "bottom", self.inputBackground):Offset(0, 4)
	self.inputInfo:LayoutBounds("center", "below", self.background):Offset(0, self.inputOffset):SendToBack()
end

function CraftableItemDetailsPanel:SetItem(itemId, itemSlot, itemData, existing)
	-- Get what items are favourites
	local favouriteIds = ThePlayer.components.playercrafter:GetFavourites()

	self.itemSlot:SetItem(itemData, ThePlayer)
		:SetFavourite(favouriteIds[itemId])

	self.itemName:SetText(itemData:GetLocalizedName())

	-- Refresh ingredients list
	local def = itemData:GetDef()
	local recipe = recipes.ForSlot[def.slot][def.name]
	self.requiredMaterials:SetRecipe(recipe)
		:LayoutBounds("left", "below", self.itemName)
		:Offset(0, -5)

	self.recipe = recipe
	self.consumable_recipe = recipes.ForSlot["PLACEABLE_PROP"][def.name]

	self.requiredMaterials:Show()
	self.leftMouseLabel:SetText(STRINGS.CRAFT_WIDGET.CRAFT_PLACE)

	if existing then
		self.leftMouseLabel:SetText(STRINGS.CRAFT_WIDGET.PLACE)
		if not self.craft_mode then
			self.requiredMaterials:Hide()
		end
	end

	self:RefreshInfoLayout()

	return self
end

function CraftableItemDetailsPanel:Open()
	if not self.isOpen then
		self.isOpen = true
		self:Show()
			:SetMultColorAlpha(0)
			:SetPosition(self.originalPositionX, self.originalPositionY - 30)
			:AlphaTo(1, 0.1, easing.inOutQuad)
			:MoveTo(self.originalPositionX, self.originalPositionY, 0.1, easing.inQuad)
	end
	return self
end

function CraftableItemDetailsPanel:Close(onDoneFn)
	if self.isOpen then
		self.isOpen = false
		self:AlphaTo(0, 0.1, easing.inOutQuad, function() self:Hide() end)
			:MoveTo(self.originalPositionX, self.originalPositionY - 30, 0.1, easing.inQuad, function() if onDoneFn then onDoneFn() end end)
	end
	return self
end

function CraftableItemDetailsPanel:IsOpen()
	return self.isOpen
end

-- So we can animate and return to the correct spot later
function CraftableItemDetailsPanel:MemorizePosition()
	self.originalPositionX, self.originalPositionY = self:GetPosition()
	return self
end

return CraftableItemDetailsPanel
