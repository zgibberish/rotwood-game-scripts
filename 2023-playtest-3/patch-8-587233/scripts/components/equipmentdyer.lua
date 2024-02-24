local Cosmetic = require("defs.cosmetics.cosmetics")
local krandom = require("util.krandom")
local lume = require("util.lume")
local Equipment = require("defs.equipment")

local EquipmentDyer = Class(function(self, inst)
	self.inst = inst
	self.applied_dyes = {}
end)

-- The owner parameter is a Bit of a hack since we need to check if the player has unlocked something, but we might be randomizing a puppet
-- function EquipmentDyer:IsBodyPartUnlocked(name, owner)
-- 	owner = owner or self.inst
-- 	return owner.components.unlocktracker:IsCosmeticUnlocked(name, "PLAYER_BODYPART")
-- end

-- function EquipmentDyer:IsBodyPartPurchased(name, owner)
-- 	owner = owner or self.inst
-- 	return owner.components.unlocktracker:IsCosmeticPurchased(name, "PLAYER_BODYPART")
-- end

function EquipmentDyer:IsDyeEquipped(armour_slot, armour_set, name)
	local slot_dyes = self.applied_dyes[armour_slot]
	local equipped_dye = slot_dyes and slot_dyes[armour_set]
	return equipped_dye == name
end

-- function EquipmentDyer:IsColorPurchased(name, owner)
-- 	owner = owner or self.inst
-- 	return owner.components.unlocktracker:IsCosmeticPurchased(name, "PLAYER_COLOR")
-- end

function EquipmentDyer:GetActiveDye(armour_slot, armour_set)
	local slot_dyes = self.applied_dyes[armour_slot]
	if slot_dyes and slot_dyes[armour_set] then
		local active_dye = slot_dyes[armour_set]
		return Cosmetic.EquipmentDyes[armour_slot][armour_set][active_dye]
	end
end

function EquipmentDyer:SetEquipmentDye(armour_slot, armour_set, name)
	local slot_dyes = self.applied_dyes[armour_slot]

	local current_dye = slot_dyes and slot_dyes[armour_set]

	if current_dye == name then
		return false -- Already equipped.
	end

	-- A nil dye_def is a request to clear the slot.
	if not name then
		if slot_dyes then
			slot_dyes[armour_set] = nil
		end
	else
		local items = Cosmetic.EquipmentDyes[armour_slot]
		if not items then
			print("[EquipmentDyer] Invalid armour slot: "..armour_slot)
			return false
		end

		local set = items[armour_set]
		if not set then
			printf("[EquipmentDyer] Invalid armour set for %s: %s", armour_slot, armour_set)
			return false
		end

		local def = set[name]
		if not def then
			printf("[EquipmentDyer] Invalid %s dye for %s: %s", armour_slot, armour_set, name)
			return false
		end

		-- Ensure slot exists.
		self.applied_dyes[armour_slot] = slot_dyes or {}
		slot_dyes = self.applied_dyes[armour_slot]

		slot_dyes[armour_set] = name
	end

	self.inst:PushEvent("onequipmentdyechanged", { 
		equipment_slot = armour_slot,
		olddye = current_dye,
		newpart = slot_dyes and slot_dyes[armour_set]
	})
	self.inst.components.inventory:RebuildCharacterArmour()
	return true
end

function EquipmentDyer:OverrideArmourSymbols(bodypart, build, colorgroup)

end

function EquipmentDyer:DEBUG_EquipDye()
	self:SetEquipmentDye(Equipment.Slots.HEAD, "yammo", "yammo_dye_1")
	self:SetEquipmentDye(Equipment.Slots.BODY, "yammo", "yammo_dye_2")
	self:SetEquipmentDye(Equipment.Slots.WAIST, "yammo", "yammo_dye_3")
end

function EquipmentDyer:OnSave()
	local data = {}
	if next(self.applied_dyes) ~= nil then
		data.dyes = {}
		for slot, slot_data in pairs(self.applied_dyes) do
			data.dyes[slot] = {}
			for armor_name, equipped_dye in pairs(slot_data) do
				data.dyes[slot][armor_name] = equipped_dye
			end
		end
	end

	return next(data) ~= nil and data or nil
end

function EquipmentDyer:OnLoad(data)
	if data.dyes ~= nil then
		for slot, slot_data in pairs(data.dyes) do
			for armor_name, equipped_dye in pairs(slot_data) do
				self:SetEquipmentDye(slot, armor_name, equipped_dye)
			end
		end
	end
end

local SERIALIZATION_SLOTS =
{
	Equipment.Slots.HEAD,
	Equipment.Slots.BODY,
	Equipment.Slots.WAIST
}
function EquipmentDyer:OnNetSerialize()
	-- Compared to OnSave and OnLoad, for networking we only need to know the -current- dyes.
	-- Only serialize a dye if it is for the currently equipped armor.

	local e = self.inst.entity

	for _, slot in ipairs(SERIALIZATION_SLOTS) do
		local slot_data = self.applied_dyes[slot]
		local equipped_item = self.inst.components.inventoryhoard:GetEquippedItem(slot)

		local equipped_dye = nil
		if equipped_item and slot_data then
			for armor_name, dye in pairs(slot_data) do
				if armor_name == equipped_item.id then
					equipped_dye = dye
				end
			end
		end

		if equipped_item then
			e:SerializeBoolean(true)
			e:SerializeString(equipped_item.id)
		else
			e:SerializeBoolean(false)
		end

		if equipped_dye then
			e:SerializeBoolean(true)
			e:SerializeString(equipped_dye)
		else
			e:SerializeBoolean(false)
		end
	end
end

function EquipmentDyer:OnNetDeserialize()
	local e = self.inst.entity

	for _, slot in ipairs(SERIALIZATION_SLOTS) do
		local armor_name
		if e:DeserializeBoolean() then
			armor_name = e:DeserializeString();
		end

		local equipped_dye
		if e:DeserializeBoolean() then
			equipped_dye = e:DeserializeString()
		end

		if armor_name then
			local dyes_changed = self:SetEquipmentDye(slot, armor_name, equipped_dye)
		end
	end
end

return EquipmentDyer
