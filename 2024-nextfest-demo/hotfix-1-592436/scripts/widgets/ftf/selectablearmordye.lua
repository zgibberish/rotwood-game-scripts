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

local SelectableArmorDye = Class(Clickable, function(self, size)
	Clickable._ctor(self, "SelectableArmorDye")

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

function SelectableArmorDye:OnFocusChange(has_focus)
	self.focus_brackets:AlphaTo(has_focus and 1 or 0, has_focus and 0.1 or 0.3, easing.outQuad)
	return self
end

function SelectableArmorDye:SetLocked(is_locked)
	self.is_locked = is_locked
	
	if self.is_hidden then
		self.lock_badge:SetShown(false)
		return self
	end
	
	if self.is_locked then
		self.puppet:SetMultColor(HexToRGB(0x090909ff))
			:SetAddColor(HexToRGB(0xBCA693ff))
	else
		self.puppet:SetMultColor(1,1,1,1)
			:SetAddColor(0,0,0,0)
	end
	return self
end

function SelectableArmorDye:SetPurchased(is_purchased)
	self.is_purchased = is_purchased

	if self.is_hidden then
		return self
	end

	if self.is_purchased then
		self.lock_badge:SetShown(false)
	else
		self.lock_badge:SetShown(true)
	end

	return self
end

function SelectableArmorDye:SetHidden(is_hidden)
	self.is_hidden = is_hidden
	self.hidden_label:SetShown(is_hidden)
	
	if is_hidden then
		self.lock_badge:SetShown(false)
		self.puppet:SetMultColor(HexToRGB(0x090909ff))
				:SetAddColor(HexToRGB(0xBCA693ff))
	end

	return self
end

function SelectableArmorDye:SetPuppetOffset(x, y)
	self.puppet_bg:LayoutBounds("center", "center", self.image)
		:Offset(x, y)
	self.puppet:LayoutBounds("center", "center", self.image)
		:Offset(x, y)
	return self
end

function SelectableArmorDye:SetPuppetScale(scale)
	self.puppet_bg:SetScale(scale)
	self.puppet:SetScale(scale)
	return self
end

function SelectableArmorDye:SetPuppetSpecies(species)
	self.puppet_bg.components.charactercreator:SetSpecies(species)
	self.puppet.components.charactercreator:SetSpecies(species)
	return self
end

function SelectableArmorDye:SetCharacterData(data)
	self.puppet_bg.components.charactercreator:OnLoad(data)
	self.puppet.components.charactercreator:OnLoad(data)
	return self
end

function SelectableArmorDye:SetPuppetArmorDye(slot, set, dye)
	self.puppet.components.equipmentdyer:SetEquipmentDye(slot, set, dye)
	return self
end

function SelectableArmorDye:HighlightParts(parts)
	if self.selected or self.is_locked then
		return self
	end

	-- self.puppet.components.inventory:ClearEquipSlotSymbols("BODY", self.puppet.components.inventory:GetArmourDef("BODY"))
	-- self.puppet.components.charactercreator:ClearAllExceptTable(parts)
	return self
end

function SelectableArmorDye:GetPuppet()
	return self.puppet
end

function SelectableArmorDye:SetDyeId(id)
	self.dye_id = id
	return self
end

function SelectableArmorDye:GetDyeId()
	return self.dye_id
end

function SelectableArmorDye:CloneCharacterAppearance(character)
	self.puppet_bg:CloneCharacterWithEquipment(character, true)
	self.puppet:CloneCharacterWithEquipment(character, true)
	return self
end

function SelectableArmorDye:SetSelected(is_selected)
	self.selected = is_selected
	self.image:TintTo(nil, self.selected and self.selected_bg_color or self.normal_bg_color, self.selected and 0.1 or 0.3, easing.outQuad)
	return self
end

function SelectableArmorDye:IsSelected()
	return self.selected
end

return SelectableArmorDye