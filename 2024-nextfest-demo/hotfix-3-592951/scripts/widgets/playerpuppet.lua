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

function PlayerPuppet:CloneCharacterWithEquipment(character, skip_weapon)
	self:CloneCharacterAppearance(character)
	local inventory_data = character.components.inventory:OnSave()

	-- print ("CLONING CHARACTER", inventory_data ~= nil, inventory_data.equips ~= nil, skip_weapon)

	if inventory_data ~= nil and inventory_data.equips ~= nil and skip_weapon then
		inventory_data.equips["WEAPON"] = nil
	end

	self.components.inventory:OnLoad(inventory_data)

	local Cosmetic = require "defs.cosmetics.cosmetics"
	for _, slot in ipairs(Cosmetic.DyeSlots) do
		local set = character.components.inventory.equips[slot]
		local active_dye = character.components.equipmentdyer:GetActiveDye(slot, set)
		local dye_name = active_dye ~= nil and active_dye.short_name or nil

		self.components.equipmentdyer:SetEquipmentDye(slot, set, dye_name)
	end

	return self
end

function PlayerPuppet:RemoveWeapon()
	self.components.inventory:Equip("WEAPON", nil)
	return self
end

return PlayerPuppet
