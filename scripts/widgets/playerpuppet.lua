local CharacterCreator = require("components/charactercreator")
local PlayerTitleHolder = require("components/playertitleholder")
local EquipmentDyer = require("components/equipmentdyer")
local Inventory = require("components/inventory")
local UIAnim = require "widgets.uianim"
local Widget = require "widgets.widget"
local krandom = require "util.krandom"

local PlayerPuppet = Class(Widget, function(self)
	Widget._ctor(self, "PlayerPuppet")

	self.puppet = self:AddChild(UIAnim())
	self.puppet:GetAnimState():SetBank("player")
	self.puppet:GetAnimState():SetBuild("player_bank_basic")
	self.puppet:GetAnimState():PlayAnimation("idle", true)

	self.components =
	{
		charactercreator = CharacterCreator(self.puppet.inst),
		playertitleholder = PlayerTitleHolder(self.puppet.inst),
		equipmentdyer = EquipmentDyer(self.puppet.inst),
		inventory = Inventory(self.puppet.inst),
	}

	-- The "least of all evils" work around for the equipment dyer
	self.puppet.inst.components = self.components
end)

function PlayerPuppet:GetAnimState()
	return self.puppet:GetAnimState()
end

function PlayerPuppet:SetFacing(facing)
	self.puppet:SetFacing(facing)
	return self
end

function PlayerPuppet:PauseAtRandomPointInAnim(anim)
	self.puppet:GetAnimState():Pause()
	self.puppet:GetAnimState():SetPercent(anim, krandom.Float())
	return self
end

function PlayerPuppet:Pause()
	self.puppet:GetAnimState():Pause()
	return self
end

function PlayerPuppet:PauseInAnim(anim, percent)
	self.puppet:GetAnimState():Pause()
	self.puppet:GetAnimState():SetPercent(anim, percent)
	return self
end

function PlayerPuppet:PlayAnimSequence(anims)
	for i = 1, #anims do
		if i == 1 then
			self.puppet:GetAnimState():PlayAnimation(anims[i])
		else
			self.puppet:GetAnimState():PushAnimation(anims[i], i == #anims)
		end
	end

	return self
end

function PlayerPuppet:PlayAnim(anim, loop)
	self.puppet:GetAnimState():PushAnimation(anim, loop)
	return self
end

function PlayerPuppet:CloneCharacterAppearance(character)
	self.components.charactercreator:OnLoad(character.components.charactercreator:OnSave())
	return self
end

function PlayerPuppet:CloneCharacterWithEquipment(character)
	self:CloneCharacterAppearance(character)
	local inventory_data = character.components.inventory:OnSave()
	self.components.inventory:OnLoad(inventory_data)

	local dye_data = character.components.equipmentdyer:OnSave()
	if dye_data ~= nil then
		self.components.equipmentdyer:OnLoad(dye_data)
	end
	return self
end

return PlayerPuppet
