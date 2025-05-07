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
local Cosmetic = require "defs.cosmetics.cosmetics"
local fmodtable = require "defs.sound.fmodtable"

local easing = require "util.easing"
----

local SelectablePuppet = Class(Clickable, function(self, font_size)
	Clickable._ctor(self, "SelectablePuppet")

	-- sound
	self:SetControlDownSound(fmodtable.Event.input_down)
	self:SetControlUpSound(fmodtable.Event.input_up)
	self:SetGainFocusSound(fmodtable.Event.hover)

	-- Our clickable area
	self.hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetName("Hitbox")
		:SetSize(500, 700)
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0.0)

	-- Add our puppet
	self.puppet = self:AddChild(PlayerPuppet())
		:SetName("Puppet")
		:SetHiddenBoundingBox(true)
		:SetScale(1.6)
		:SetFacing(FACING_RIGHT)
		:LayoutBounds(nil, "bottom", self.hitbox)
	self.shadow = self:AddChild(Image("images/ui_ftf_inventory/CharacterShadow.tex"))
		:SetName("Shadow")
		:SetHiddenBoundingBox(true)
		:SendToBack()
		:SetScale(0.85)
		:SetMultColorAlpha(0.3)
		:LayoutBounds(nil, "center", self.puppet)
	self.selection_floor = self:AddChild(Image("images/ui_ftf_character/CharacterSelectionFloorGlow.tex"))
		:SetName("Selection floor")
		:SetHiddenBoundingBox(true)
		:SendToBack()
		:SetScale(1.05)
		:LayoutBounds(nil, "bottom", self.shadow)
		:Offset(0, -45)
		:SetMultColorAlpha(0)
	self.selection_glow = self:AddChild(Image("images/ui_ftf_character/CharacterSelectionGlow.tex"))
		:SetName("Selection glow")
		:SetHiddenBoundingBox(true)
		:SetScale(1.05)
		:LayoutBounds(nil, "bottom", self.selection_floor)
		:SetMultColorAlpha(0)

	-- Name tag
	self.name_bg = self:AddChild(Image("images/ui_ftf_character/NameTagsBg.tex"))
		:SetName("Name background")
		:SetHiddenBoundingBox(true)
		:SetMultColorAlpha(0.4)
		:LayoutBounds(nil, "below", self.selection_floor)
		:Offset(0, -20)
	self.name_label = self:AddChild(Text(FONTFACE.DEFAULT, font_size or FONTSIZE.DIALOG_TEXT))
		:SetName("Name label")
		:SetHiddenBoundingBox(true)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)

	-- Randomize the current animation, so multiple buttons don't all breathe together
	local random_frame = math.random(self.puppet:GetAnimState():GetCurrentAnimationNumFrames() - 1)
	self.puppet:GetAnimState():SetFrame(random_frame)

	-- Setup interactions
	self:SetOnGainFocus(function() self:OnFocusChange(true) end)
	self:SetOnLoseFocus(function() self:OnFocusChange(false) end)

	-- local color = self.name_label:GetColour()
	-- local r1,g1,b1,a1 = table.unpack(self.name_label:GetColour())
	-- print("get color", color)
	-- print("unpack", table.unpack(color))
	-- print("r1,g1,b1,a1", r1,g1,b1,a1)
	-- print("ui colors", UICOLORS.LIGHT_TEXT_DARKER)

	return self
end)

function SelectablePuppet:SetOnFocusChangedFn(fn)
	self.on_focus_changed = fn
	return self
end

function SelectablePuppet:OnFocusChange(has_focus)

	if self.on_focus_changed then self.on_focus_changed(has_focus) end
	self:_UpdateFocusLook(has_focus)

	return self
end

function SelectablePuppet:_UpdateFocusLook(has_focus)

	local show_glow = has_focus or self.selected
	self.selection_floor:AlphaTo(show_glow and 1 or 0, show_glow and 0.1 or 0.3, easing.outQuad)
	self.selection_glow:AlphaTo(show_glow and 1 or 0, show_glow and 0.7 or 0.9, easing.outQuad)
	self.name_bg:AlphaTo(show_glow and 0.8 or 0.4, show_glow and 0.6 or 0.9, easing.outQuad)
	self.name_label:ColorTo(nil, show_glow and UICOLORS.BACKGROUND_DARK or UICOLORS.LIGHT_TEXT_DARKER, show_glow and 0.6 or 0.9, easing.outQuad)

	return self
end

function SelectablePuppet:SetSelected(is_selected)
	self.selected = is_selected
	self:_UpdateFocusLook()
	return self
end

function SelectablePuppet:Equip(slot, item)
	self.puppet.components.inventory:Equip(slot, item)
	return self
end

function SelectablePuppet:SetSpecies(species)
	self.species = species
	self.puppet.components.charactercreator:SetSpecies(species)
	self:UpdateName(string.upper(STRINGS.SPECIES_NAME[species]))
	return self
end

function SelectablePuppet:GetSpecies()
	return self.puppet.components.charactercreator:GetSpecies()
end

-- Sets what species this puppet is
function SelectablePuppet:SetHead(head_name)
	self.head_name = head_name
	self.puppet.components.charactercreator:SetBodyPart(Cosmetic.BodyPartGroups.HEAD, self.head_name)

	local species = "ogre"
	if string.find(self.head_name, "mer") then
		species = "mer"
	elseif string.find(self.head_name, "canine") then
		species = "canine"
	end

	-- Update the displayed species name
	self:UpdateName(string.upper(STRINGS.SPECIES_NAME[species]))

	return self
end

-- Randomizes the various body parts
-- If maintain_head is true, it'll keep the same species as before
function SelectablePuppet:Randomize(species)
	-- Randomize the character's setup
	self.puppet.components.charactercreator:Randomize(species)
	species = self.puppet.components.charactercreator:GetSpecies() -- We get the species again in case nil was passed originally

	-- Update the displayed species name
	self:UpdateName(string.upper(STRINGS.SPECIES_NAME[species]))

	return self
end

function SelectablePuppet:RefreshCharacterData()
	local data = self:GetCharacterData()
	self:SetCharacterData(data)
	return self
end

function SelectablePuppet:SetCharacterData(data)
	self.puppet.components.charactercreator:OnLoad(data)
	return self
end

function SelectablePuppet:GetCharacterData()
	return self.puppet.components.charactercreator:OnSave()
end

function SelectablePuppet:SetInventoryData(data)
	self.puppet.components.inventory:OnLoad(data)
	return self
end

function SelectablePuppet:SetEquipmentDyerData(data)
	if data then
		self.puppet.components.equipmentdyer:OnLoad(data)
	end
	return self
end

function SelectablePuppet:SetPlayerData(data)
	self:SetCharacterData(data.charactercreator)
	self:SetInventoryData(data.inventory)
	self:SetEquipmentDyerData(data.equipmentdyer)
	return self
end

function SelectablePuppet:UpdateName(str)
	self.name_label:SetText(str)
		:LayoutBounds("center", "center", self.name_bg)
		:Offset(0, 20)
	return self
end

function SelectablePuppet:Layout()
	return self
end

return SelectablePuppet
