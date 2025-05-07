------------------------------------------------------------------------------------------
--- Displays a puppet that's player selectable
local Clickable = require "widgets.clickable"
local Widget = require "widgets.widget"
local Image = require "widgets.image"
local Panel = require "widgets.panel"
local Text = require "widgets.text"
local PlayerPuppet = require "widgets.playerpuppet"
local ImageCheckBox = require "widgets.imagecheckbox"
local ActionButton = require "widgets.actionbutton"
local fmodtable = require "defs.sound.fmodtable"

local easing = require "util.easing"
----

local SelectableBodyPart = Class(Clickable, function(self, size)
	Clickable._ctor(self, "SelectableBodyPart")

	self.width = size or 300
	self.height = size or 300
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

	-- Masking of the puppet
	self.mask = self:AddChild(Image("images/ui_ftf_character/ItemBg.tex"))
		:SetName("Mask")
		:SetHiddenBoundingBox(true)
		:SetSize(self.width, self.height)
		:SetMask()
	
	self.puppet_bg = self:AddChild(PlayerPuppet())
		:SetName("Puppet")
		:SetHiddenBoundingBox(true)
		:LayoutBounds("center", "center", self.image)
		:SetFacing(FACING_RIGHT)
		:PauseInAnim("idle", 0)
		:SetMasked()
		:SetMultColor(HexToRGB(0x090909ff))
		:SetAddColor(HexToRGB(0xBCA693ff))
		--:SetShown(false)
	
	-- Puppet
	self.puppet = self:AddChild(PlayerPuppet())
		:SetName("Puppet")
		:SetHiddenBoundingBox(true)
		:LayoutBounds("center", "center", self.image)
		:SetFacing(FACING_RIGHT)
		:PauseInAnim("idle", 0)
		:SetMasked()

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

	self.hidden_label = self:AddChild(Text(FONTFACE.DEFAULT, 80, "HIDDEN\nHIDDEN\nHIDDEN\nHIDDEN"))
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

function SelectableBodyPart:OnFocusChange(has_focus)
	self.focus_brackets:AlphaTo(has_focus and 1 or 0, has_focus and 0.1 or 0.3, easing.outQuad)
	return self
end

function SelectableBodyPart:SetLocked(is_locked)
	self.is_locked = is_locked
	
	if self.is_hidden then
		self.lock_badge:SetShown(false)
		return self
	end
	
	self.lock_badge:SetShown(self.is_locked)
	if self.is_locked then
		self.puppet:SetMultColor(HexToRGB(0x090909ff))
			:SetAddColor(HexToRGB(0xBCA693ff))
	end
	return self
end

function SelectableBodyPart:SetPurchased(is_purchased)
	self.is_purchased = is_purchased

	if self.is_hidden then
		self.price_bg:SetShown(false)
		return self
	end

	if self.is_locked then
		self.price_bg:SetShown(false)
	else
		self.price_bg:SetShown(not self.is_purchased)
		self.puppet:SetMultColor(1,1,1,1)
			:SetAddColor(0,0,0,0)
	end

	return self
end

function SelectableBodyPart:SetCost(cost)
	self.cost = cost
	self.price_label:SetText(tostring(cost))
	return self
end

function SelectableBodyPart:SetHidden(is_hidden)
	self.is_hidden = is_hidden
	self.hidden_label:SetShown(is_hidden)
	
	if is_hidden then
		self.price_bg:SetShown(false)
		self.lock_badge:SetShown(false)
		self.puppet:SetMultColor(HexToRGB(0x090909ff))
				:SetAddColor(HexToRGB(0xBCA693ff))
	end

	return self
end

function SelectableBodyPart:SetPuppetOffset(x, y)
	self.puppet_bg:LayoutBounds("center", "center", self.image)
		:Offset(x, y)
	self.puppet:LayoutBounds("center", "center", self.image)
		:Offset(x, y)
	return self
end

function SelectableBodyPart:SetPuppetScale(scale)
	self.puppet_bg:SetScale(scale)
	self.puppet:SetScale(scale)
	return self
end

function SelectableBodyPart:SetPuppetSpecies(species)
	self.puppet_bg.components.charactercreator:SetSpecies(species)
	self.puppet.components.charactercreator:SetSpecies(species)
	return self
end

function SelectableBodyPart:SetCharacterData(data)
	self.puppet_bg.components.charactercreator:OnLoad(data)
	self.puppet.components.charactercreator:OnLoad(data)
	return self
end

function SelectableBodyPart:SetPuppetBodyPart(bodypart, name)
	self.puppet_bg.components.charactercreator:SetBodyPart(bodypart, name)
	self.puppet.components.charactercreator:SetBodyPart(bodypart, name)
	return self
end

function SelectableBodyPart:HighlightBodyPart(bodypart)
	if self.selected or self.is_locked then
		return self
	end

	self.puppet.components.charactercreator:ClearAllExcept(bodypart)
	return self
end

function SelectableBodyPart:GetPuppet()
	return self.puppet
end

function SelectableBodyPart:SetBodyPartId(part_id)
	self.part_id = part_id
	return self
end

function SelectableBodyPart:GetBodyPartId()
	return self.part_id
end

function SelectableBodyPart:CloneCharacterAppearance(character)
	self.puppet_bg:CloneCharacterAppearance(character)
	self.puppet:CloneCharacterAppearance(character)
end

function SelectableBodyPart:SetSelected(is_selected)
	self.selected = is_selected
	self.image:TintTo(nil, self.selected and self.selected_bg_color or self.normal_bg_color, self.selected and 0.1 or 0.3, easing.outQuad)
	return self
end

function SelectableBodyPart:IsSelected()
	return self.selected
end

return SelectableBodyPart