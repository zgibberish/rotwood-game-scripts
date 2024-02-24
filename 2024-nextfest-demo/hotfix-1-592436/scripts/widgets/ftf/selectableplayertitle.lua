------------------------------------------------------------------------------------------
--- Displays a puppet that's player selectable
local Clickable = require "widgets.clickable"
local Widget = require "widgets.widget"
local Image = require "widgets.image"
local Panel = require "widgets.panel"
local Text = require "widgets.text"
local ImageCheckBox = require "widgets.imagecheckbox"
local ActionButton = require "widgets.actionbutton"
local fmodtable = require "defs.sound.fmodtable"

local easing = require "util.easing"
----

local SelectablePlayerTitle = Class(Clickable, function(self, width, height)
	Clickable._ctor(self, "SelectablePlayerTitle")

	self.width =  width or 400
	self.height = height or 250
	self.lock_size = 60

	self.normal_bg_color = HexToRGB(0xA5908333) -- 20%
	self.selected_bg_color = HexToRGB(0xFFFFFF80) -- 50%

	-- Clickable hitbox
	self.hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetName("Hitbox")
		:SetSize(self.width, self.height)
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0.0)

	-- Tintable button image
	self.image = self:AddChild(Image("images/ui_ftf_character/ItemBg.tex"))
		:SetName("Image")
		:SetHiddenBoundingBox(true)
		:SetSize(self.width, self.height)
		:SetMultColor(self.normal_bg_color)

	self.title_label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CHARACTER_CREATOR_TAB, "TITLE TITLE TITLE"))
		:LayoutBounds("center", "center")
		:SetHiddenBoundingBox(true)
		:SetGlyphColor(UICOLORS.BLACK)
		--:Offset(10, 0)

	-- Lock badge, if unavailable
	self.lock_badge = self:AddChild(Image("images/ui_ftf_character/LockBadge.tex"))
		:SetName("Lock badge")
		:SetHiddenBoundingBox(true)
		:SetSize(self.lock_size, self.lock_size)
		:LayoutBounds("right", "bottom", self.image)
		:Offset(-20, 20)

	self.price_bg = self:AddChild(Image("images/ui_ftf_character/ItemPriceBg.tex"))
		:SetName("Price BG")
		:SetScale(0.9)
		:LayoutBounds("left", "bottom", self.image)

	self.price_badge = self.price_bg:AddChild(Image("images/hud_images/hud_glitz_drops_currency.tex"))
		:SetName("Price badge")
		:SetHiddenBoundingBox(true)
		:SetSize(70,70)
		:LayoutBounds("left", "bottom", self.price_bg)
		:Offset(20, 10)

	self.price_label = self.price_bg:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CHARACTER_CREATOR_TAB, "500"))
		:LayoutBounds("after", "center", self.price_badge)
		:SetHiddenBoundingBox(true)
		:SetGlyphColor(UICOLORS.BLACK)
		:Offset(10, 0)

	self.hidden_label = self:AddChild(Text(FONTFACE.DEFAULT, 60, "HIDDEN\nHIDDEN\nHIDDEN\nHIDDEN"))
		:LayoutBounds("center", "center", self.image)
		:SetHiddenBoundingBox(true)
		:SetGlyphColor(UICOLORS.RED)
		:EnableOutline()
		:SetOutlineColor(UICOLORS.BLACK)
		:SetShown(false)

	-- Focus brackets
	self.focus_brackets = self:AddChild(Panel("images/ui_ftf_crafting/RecipeFocus.tex"))
		:SetName("Focus brackets")
		:SetHiddenBoundingBox(true)
		:SetNineSliceCoords(54, 56, 54, 56)
		:SetSize(self.width + 30, self.height + 30)
		:SetMultColorAlpha(0)
		:LayoutBounds("center", "center", self.hitbox)
		:Offset(0, 0)

	-- Setup interactions
	self:SetOnGainFocus(function() self:OnFocusChange(true) end)
	self:SetOnLoseFocus(function() self:OnFocusChange(false) end)

	return self
end)

function SelectablePlayerTitle:OnFocusChange(has_focus)
	self.focus_brackets:AlphaTo(has_focus and 1 or 0, has_focus and 0.1 or 0.3, easing.outQuad)
	return self
end

function SelectablePlayerTitle:SetTitle(def)
	self.title_key = def.title_key
	self.title_label:SetText(STRINGS.COSMETICS.TITLES[self.title_key])
	return self
end

function SelectablePlayerTitle:SetCost(cost)
	self.cost = cost
	self.price_label:SetText(tostring(cost))
	return self
end

function SelectablePlayerTitle:GetTitleKey()
	return self.title_key
end

function SelectablePlayerTitle:SetLocked(is_locked)
	self.is_locked = is_locked

	if self.is_hidden then
		self.lock_badge:SetShown(false)
		return self
	end

	self.lock_badge:SetShown(self.is_locked)
	if self.is_locked then
		self.title_label:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		local str = STRINGS.COSMETICS.TITLES[self.title_key]
		local locked_str = ""
		for i=1, string.len(str) do
			local char = str:sub(i,i)
			if char ~= " " then
				locked_str = locked_str .. "?"
			else
				locked_str = locked_str .. " "
			end
		end

		self.title_label:SetText(locked_str)

	end
	return self
end

function SelectablePlayerTitle:SetPurchased(is_purchased)
	self.is_purchased = is_purchased

	if self.is_hidden then
		self.price_bg:SetShown(false)
		return self
	end

	if self.is_locked then
		self.price_bg:SetShown(false)
	else
		self.price_bg:SetShown(not self.is_purchased)
		self.title_label:SetText(STRINGS.COSMETICS.TITLES[self.title_key])
		self.title_label:SetGlyphColor(self.is_purchased and UICOLORS.BLACK or UICOLORS.LIGHT_TEXT_DARK)
	end

	return self
end

function SelectablePlayerTitle:SetHidden(is_hidden)
	self.is_hidden = is_hidden
	self.hidden_label:SetShown(is_hidden)
	
	if is_hidden then
		self.price_bg:SetShown(false)
		self.lock_badge:SetShown(false)
		self.title_label:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
	end

	return self
end

function SelectablePlayerTitle:SetSelected(is_selected)
	self.selected = is_selected
	self.image:TintTo(nil, self.selected and self.selected_bg_color or self.normal_bg_color, self.selected and 0.1 or 0.3, easing.outQuad)
	return self
end

function SelectablePlayerTitle:IsSelected()
	return self.selected
end

return SelectablePlayerTitle