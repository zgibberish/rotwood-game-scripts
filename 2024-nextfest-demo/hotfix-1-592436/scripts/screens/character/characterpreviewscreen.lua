local Widget = require "widgets.widget"	
local Panel = require "widgets.panel"
local PlayerPuppet = require "widgets.playerpuppet"
local Screen = require "widgets.screen"
local templates = require "widgets.ftf.templates"

local lume = require "util.lume"
local Cosmetic = require "defs.cosmetics.cosmetics"

local anims = 
{
	"turnaround",
	"poses",
	"head_sheet",
	"head_rotations",
}

-- DEFAULT_CHARACTERS_SETUP is found in contants.lua

local CharacterPreviewScreen = Class(Screen, function(self)
	Screen._ctor(self, "CharacterPreviewScreen")

	self.current_anim = 1

	self.puppet = self:AddChild(PlayerPuppet())
	self.puppet:CloneCharacterWithEquipment(ThePlayer)
	self.puppet:PlayAnim(anims[self.current_anim], true)

	self.next_anim_btn = self:AddChild(templates.Button("Next Anim"))
		:SetOnClick(function() 
			self.current_anim = self.current_anim + 1
			if self.current_anim > #anims then
				self.current_anim = 1
			end
			self.puppet:PlayAnim(anims[self.current_anim], true)
		end)
		:LayoutBounds("center", "below", self.puppet)
		:Offset(-290, -650)

	self.random_btn = self:AddChild(templates.Button("Randomize"))
		:SetOnClick(function() 
			local species = self.puppet.components.charactercreator:GetSpecies()
			self.puppet.components.charactercreator:Randomize(species, nil, true)

			if self.bodypart_def then
				self.puppet.components.charactercreator:OverrideBodyPartSymbols(self.bodypart_def.bodypart, self.bodypart_def.build, self.bodypart_def.colorgroup)
			end

			if self.color_def then
				self.puppet.components.charactercreator:SetSymbolColorShift(self.color_def.colorgroup, table.unpack(self.color_def.hsb))
			end
		end)
		:LayoutBounds("after", "center", self.next_anim_btn)
		:Offset(10, 0)

	self.close_btn = self:AddChild(templates.CancelButton())
		:SetOnClick(function() TheFrontEnd:PopScreen(self) end)
		:LayoutBounds("center", "below", self.next_anim_btn)
		:Offset(290, 0)

	self.default_focus = self.next_anim_btn
end)

function CharacterPreviewScreen:RefreshSpecies(species)
	if species ~= self.puppet.components.charactercreator:GetSpecies() then
		self.puppet.components.charactercreator:SetSpecies(species)
		for i, data in ipairs(DEFAULT_CHARACTERS_SETUP) do
			if data.species == species then
				self.puppet.components.charactercreator:OnLoad(data)
			end
		end
	end
end

function CharacterPreviewScreen:PreviewBodyPart(def)
	self.bodypart_def = def
	self:RefreshSpecies(self.bodypart_def.species)
	self.puppet.components.charactercreator:OverrideBodyPartSymbols(self.bodypart_def.bodypart, self.bodypart_def.build, self.bodypart_def.colorgroup)
end

function CharacterPreviewScreen:PreviewColor(def)
	self.color_def = def
	self:RefreshSpecies(self.color_def.species)
	self.puppet.components.charactercreator:SetSymbolColorShift(self.color_def.colorgroup, table.unpack(self.color_def.hsb))
end

function CharacterPreviewScreen:PreviewEmote(def)
	if def.emote_species ~= "none" and def.emote_species ~= nil then
		self:RefreshSpecies(def.emote_species)
	end
	self.puppet:PlayAnim(def.anim, true)
end

function CharacterPreviewScreen:PreviewArmorDye(def)
	self.puppet.components.inventory:Debug_ForceEquipVisuals(def)
end

return CharacterPreviewScreen