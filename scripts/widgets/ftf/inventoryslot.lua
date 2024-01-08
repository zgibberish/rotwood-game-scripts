local Image = require("widgets/image")
local Panel = require("widgets/panel")
local ImageButton = require("widgets/imagebutton")
local ItemUpgradeDisplayWidget = require("widgets/ftf/itemupgradedisplaywidget")
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local easing = require "util.easing"
local itemcatalog = require "defs.itemcatalog"
local ItemTooltip = require "widgets/itemtooltip"


-------------------------------------------------------------------------------------------------
--- An item slot displayed in the inventory list
local InventorySlot = Class(Widget, function(self, size, default_icon)
	Widget._ctor(self, "InventorySlot")

	self.size = size or 130 * HACK_FOR_4K
	self.default_icon = default_icon
	self.item_size = 0 -- The size offset of the button when it has an item icon
	self.empty_size = 0 -- The size offset of the button when it has a default icon
	self.available = true -- If false, the icon won't animate and will look desaturated
	self.showing_brackets = true
	self.showing_background = true
	self.hover_effect_enabled = true

	-- Textures
	self.selection_texture = "images/ui_ftf_inventory/ItemSlotSelection.tex"
	self.mask_texture = "images/ui_ftf_inventory/ItemSlotBackground.tex"
	self.overlay_texture = "images/ui_ftf_inventory/ItemSlotOverlay.tex"

	-- Assemble widget
	self.selection = self:AddChild(Image(self.selection_texture))
		:SetSize(self.size, self.size)
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.FOCUS)
		:SetMultColorAlpha(0)
		:Hide()
	self.mask = self:AddChild(Image(self.mask_texture))
		:SetSize(self.size, self.size)
		:SetMask()
	self.background = self:AddChild(Image(self.mask_texture))
		:SetSize(self.size, self.size)
		:SetMasked()
	self.button = self:AddChild(ImageButton()) -- Displays the actual item icon
		:SetSize(self.size + self.item_size, self.size + self.item_size)
		:SetScaleOnFocus(false)
		:SetMasked()
		:SetToolTipClass(ItemTooltip)
	self.overlay = self:AddChild(Image(self.overlay_texture))
		:SetSize(self.size, self.size)
		-- :SetMasked()

	-- A "new" badge for when stuff is unlocked
	self.unseenBadge = self:AddChild(Image("images/ui_ftf_shop/item_unseen.tex"))
		:SetHiddenBoundingBox(true)
		:SetToolTip(STRINGS.CRAFT_WIDGET.ITEM_UNSEEN_BADGE_TT)
		:SetSize(self.size * 0.35, self.size * 0.35)
		:LayoutBounds("left", "top", self.background)
		:Offset(-self.size * 0.07, self.size * 0.04)
		:Hide()

	-- Add upgrade status
	local upgradeSize = 12 * HACK_FOR_4K
	self.upgrade = self:AddChild(ItemUpgradeDisplayWidget(upgradeSize))
		:SetColour(UICOLORS.BACKGROUND_DARK)
		:ShowLabel(false)
		:IgnoreInput()

	-- Add quantity
	self.quantity = self:AddChild(Text(FONTFACE.DEFAULT, 40 * HACK_FOR_4K, "", UICOLORS.LIGHT_TEXT_TITLE))
		:SetOutlineColor(UICOLORS.BACKGROUND_LIGHT)
		:EnableOutline(0.005)
		:LayoutBounds("right", "bottom", self.background)
		:Offset(-25 * HACK_FOR_4K, 25 * HACK_FOR_4K)

	self.equippedBadge = self:AddChild(Image("images/ui_ftf_inventory/ItemSlotEquipped.tex"))
		:SetSize(self.size, self.size)
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:LayoutBounds("center", "center", self.button)
		:Offset(2 * HACK_FOR_4K, -2 * HACK_FOR_4K)
		:Hide()

	-- Add selection brackets
	self.selection_brackets = self:AddChild(Panel("images/ui_ftf_crafting/RecipeFocus.tex"))
		:SetNineSliceCoords(54, 56, 54, 56)
		:SetSize(self.size + 16 * HACK_FOR_4K, self.size + 16 * HACK_FOR_4K)
		:SetHiddenBoundingBox(true)
		:IgnoreInput()
		:LayoutBounds("center", "center", self.button)

	-- Add callbacks
	self.button:SetOnGainFocus(function() self:OnButtonGainFocus() end)
	self.button:SetOnLoseFocus(function() self:OnButtonLoseFocus() end)

	self.focus_forward = self.button

	self:SetSelectionSize(0)
	self:ShowSelectionBrackets()
end)

function InventorySlot:ApplyTheme_DungeonSummary(tooltip_fn)
	return self:HideBackground()
		:SetIconSize(0, -15 * HACK_FOR_4K)
		:ShowSelectionOutline()
		:DisableHoverEffect()
end

function InventorySlot:ApplyTheme_DungeonSummaryPotion(tooltip_fn)
	self.button:SetMasked(false)
	return self:HideBackground()
		:SetIconSize(0, -15 * HACK_FOR_4K)
		:ShowSelectionOutline()
		:DisableHoverEffect()
end

function InventorySlot:ApplyTheme_DungeonSummaryTonic(tooltip_fn)
	self.button:SetMasked(false)
	return self:HideBackground()
		:SetIconSize(0, -15 * HACK_FOR_4K)
		:ShowSelectionOutline()
		:DisableHoverEffect()
end

-- Add an invisible hitbox around the button
function InventorySlot:AddHitbox(padding)
	padding = padding * 2 -- on both sides
	if not self.hitbox then
		local size = self.button:GetSize()
		self.hitbox = self.button:AddChild(Image("images/global/square.tex"))
			:SetName("Hitbox")
			:SetSize(size + padding, size + padding)
			:SetMultColor(0xff00ff00)
			:SendToBack()
	end
    return self
end

function InventorySlot:SetNavFocusable(focusable)
	InventorySlot._base.SetNavFocusable(self, focusable)
	self.button:SetNavFocusable(focusable)
	return self
end

function InventorySlot:SetMoveOnClick(move_on_click)
	self.button:SetMoveOnClick(move_on_click)
    return self
end

function InventorySlot:SetOnGainFocus(fn)
	self.onGainFocus = fn
    return self
end

function InventorySlot:SetOnLoseFocus(fn)
	self.onLoseFocus = fn
    return self
end

function InventorySlot:SetOnClick(fn)
    self.button:SetOnClick(fn)
    return self
end

function InventorySlot:SetOnClickAlt(fn)
    self.button:SetOnClickAlt(fn)
    return self
end

function InventorySlot:Click()
    self.button:Click()
    return self
end

function InventorySlot:ClickAlt()
    self.button:ClickAlt()
    return self
end

-- Default. Shows animated brackets around the selected element
function InventorySlot:ShowSelectionBrackets()
	self.showing_brackets = true
    self.selection:Hide()
    self.selection_brackets:Show()
    return self
end

-- In some circumstances, we show an outline instead of the brackets
function InventorySlot:ShowSelectionOutline()
	self.showing_brackets = false
    self.selection:SetShown(self.showing_background)
		:SetMultColorAlpha(0)
    self.selection_brackets:Hide()
    return self
end

function InventorySlot:DisableHoverEffect()
	self.hover_effect_enabled = false
	return self
end

function InventorySlot:SetItem(item, player, showzero)
	if item then
		self.item = item
		self.itemDef = self.item:GetDef()
		local tt = { item = item, player = player }

		-- -- Set rarity-specific background
		self:_SetRarity(self.itemDef.rarity or ITEM_RARITY.s.COMMON)

		self.button:SetTextures(self.item:GetDef().icon)
			:SetToolTip(tt)
			:SetMultColor(UICOLORS.WHITE)
			:SetMultColorAlpha(1)
			:SetSize(self.size + self.item_size, self.size + self.item_size)

		-- Update upgrade info
		self.upgrade:SetItem(self.item)
			:LayoutBounds("right", "bottom", self.background)
			:Offset(-5, 5)
			:Show()
		self.overlay:SetShown(self.showing_background)

		-- Show quantity if available
		if self.item.count and (self.item.count > 0) then
			self.quantity:SetText(self.item.count)
		else
			if showzero then
				self.quantity:SetText("0")
			else
				self.quantity:SetText("")
			end
		end
	else
		self.item = nil

		self.background:SetTexture(self.mask_texture)
			:SetMultColor(0xEFE9E6ff)

	    self.button:SetTextures(self.default_icon)
			:SetToolTip(nil)
			:SetMultColor(UICOLORS.DARK_TEXT)
			:SetMultColorAlpha(0.4)
			:SetSize(self.size + self.empty_size, self.size + self.empty_size)

		self.upgrade:Hide()
		self.overlay:Hide()

		self.quantity:SetText("")
	end
    return self
end

function InventorySlot:HasItem()
	return self.item ~= nil
end

-- Doesn't display a rarity background
function InventorySlot:SetFlatBackground(colour)
	self.flat_background_colour = colour
	self.background:SetTexture(self.mask_texture)
		:SetMultColor(self.flat_background_colour)
	return self
end

function InventorySlot:_SetRarity(rarity)
	if not self.flat_background_colour then
		local tex = itemcatalog.GetRarityIcon(rarity)
		self.background:SetTexture(tex)
			:SetMultColor(0xFFFFFFff)
	end
	return self
end

function InventorySlot:SetToolTip(...)
	self.button:SetToolTip(...)
	return self
end

function InventorySlot:SetToolTipClass(...)
	self.button:SetToolTipClass(...)
	return self
end

function InventorySlot:SetToolTipLayoutFn(fn)
	self.button:SetToolTipLayoutFn(fn)
	return self
end

function InventorySlot:ShowToolTipOnFocus(show)
	self.button:ShowToolTipOnFocus(show)
	return self
end

function InventorySlot:GetToolTipLayoutFn()
	return self.button:GetToolTipLayoutFn()
end

function InventorySlot:SetSelectionColor(color)
	self.selection:SetMultColor(color or UICOLORS.FOCUS)
	return self
end

function InventorySlot:SetSelectionSize(size)
	self.selection_size = size
	self.selection:SetSize(self.size + self.selection_size, self.size + self.selection_size)
	return self
end

-- Item size offset from the widget's size
function InventorySlot:SetIconSize(item_size, empty_size)
	-- I think we multiply by two to pad on both sides?
	self.item_size = item_size * 2
	self.empty_size = empty_size * 2
	if self.item then
		self.button:SetSize(self.size + self.item_size, self.size + self.item_size)
	else
		self.button:SetSize(self.size + self.empty_size, self.size + self.empty_size)
	end
	return self
end

function InventorySlot:SetIconMultColor(color)
	self.button:SetMultColor(color)
	return self
end

function InventorySlot:SetBackgroundMultColor(color)
	self.background:SetMultColor(color)
	return self
end

function InventorySlot:SetBackground(selection_texture, overlay_texture, mask_texture)
	if selection_texture then
		self.selection_texture = selection_texture
		self.selection:SetTexture(self.selection_texture)
	end
	if overlay_texture then
		self.overlay_texture = overlay_texture
		self.overlay:SetTexture(self.overlay_texture)
	end
	if mask_texture then
		self.mask_texture = mask_texture
		self.mask:SetTexture(self.mask_texture)
	end
    return self
end

function InventorySlot:HideBackground()
	self.showing_background = false
	self.background:Hide()
	self.selection:Hide()
	self.overlay:Hide()
	return self
end

function InventorySlot:GetBackgroundWidget()
	return self.background
end

function InventorySlot:GetItemInstance()
	return self.item
end

function InventorySlot:SetUnseen(unseen)
	self.unseenBadge:SetShown(unseen)
    return self
end

function InventorySlot:SetEquipped(equipped)
	self.equippedBadge:SetShown(equipped)
    return self
end

function InventorySlot:SetHighlighted(highlighted)
	-- self.background:SetTexture("images/ui_ftf_shop/"..(highlighted and "inventory_slot_selected.tex" or "inventory_slot_bg.tex"))
	self.highlighted = highlighted
	if self.showing_brackets then
		self.selection_brackets:AlphaTo(self.highlighted and 1 or 0, 0.01, easing.inOutQuad)
			:ScaleTo(self.highlighted and 1.1 or 1, self.highlighted and 1 or 1.1, 0.15, easing.inOutQuad)
	elseif self.showing_background then
		self.selection:AlphaTo(self.highlighted and 1 or 0, 0.05, easing.inOutQuad)
			:ScaleTo(self.highlighted and 0.9 or 1, self.highlighted and 1 or 0.9, 0.15, easing.inOutQuad)
	end
    return self
end

-- If this is selectable. True by default. If false, the icon is desaturated and darkened, and won't animate on hover
function InventorySlot:SetAvailable(available)
	-- self.background:SetTexture("images/ui_ftf_shop/"..(highlighted and "inventory_slot_selected.tex" or "inventory_slot_bg.tex"))
	self.available = available
	if self.available then
		self.button:SetMultColor(UICOLORS.WHITE)
			:SetSaturation(1)
			:SetMoveOnClick(true)
		self.background:SetMultColor(UICOLORS.WHITE)
			:SetSaturation(1)
	else
		self.button:SetMultColor(HexToRGB(0x524643FF))
			:SetSaturation(0.1)
			:SetMoveOnClick(false)
		self.background:SetMultColor(HexToRGB(0xCEB6A5FF))
			:SetSaturation(0.1)
	end
    return self
end

function InventorySlot:OnButtonGainFocus()
	if self.hover_effect_enabled == false then return end
	if self.available then
		self.background:ScaleTo(nil, 1.15, 0.6, easing.outQuad)
		self.button:ScaleTo(nil, 1.1, 0.15, easing.outQuad)
			:RotateTo(-5, 0.15, easing.outQuad)
	end
	if not self.highlighted then
		if self.showing_brackets then
			self.selection_brackets:AlphaTo(1, 0.01, easing.inOutQuad)
				:ScaleTo(1.1, 1, 0.15, easing.inOutQuad)
		elseif self.showing_background then
			self.selection:AlphaTo(1, 0.05, easing.inOutQuad)
				:ScaleTo(0.9, 1, 0.15, easing.inOutQuad)
		end
	end
	if self.onGainFocus then self.onGainFocus() end
end

function InventorySlot:OnButtonLoseFocus()
	if self.hover_effect_enabled == false then return end
	self.background:ScaleTo(nil, 1, 0.6, easing.outQuad)
	self.button:ScaleTo(nil, 1, 0.3, easing.outQuad)
		:RotateTo(0, 0.3, easing.outQuad)
	if not self.highlighted then
		if self.showing_brackets then
			self.selection_brackets:AlphaTo(0, 0.2, easing.inOutQuad)
				:ScaleTo(1, 0.9, 0.3, easing.inOutQuad)
		else
			self.selection:AlphaTo(0, 0.2, easing.inOutQuad)
				:ScaleTo(1, 0.9, 0.3, easing.inOutQuad)
		end
	end
	if self.onLoseFocus then self.onLoseFocus() end
end

return InventorySlot
