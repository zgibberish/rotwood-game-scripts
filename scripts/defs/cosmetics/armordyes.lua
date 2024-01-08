local Cosmetic = require("defs.cosmetics.cosmetic")
local Equipment = require "defs.equipment"
Cosmetic.EquipmentDyes = {}

local function AddDyeSlot(slot)
	assert(Cosmetic.EquipmentDyes[slot] == nil)
	Cosmetic.EquipmentDyes[slot] = {}
end

-- Passing nil for filtertags or symboltags will match as if we supported every tag.
-- TODO(dbriscoe): POSTVS Pass tags as named keys in a tags table to avoid errors.
function Cosmetic.AddEquipmentDye(name, data)
	local cosmetic_data = data.cosmetic_data

	local slots = { Equipment.Slots.HEAD, Equipment.Slots.BODY, Equipment.Slots.WAIST }

	for i,slot in ipairs(slots) do
		local full_name = name.."_"..slot
		local def = Cosmetic.AddCosmetic(full_name, data)

		def.armour_set = cosmetic_data.armour_set -- "yammo", "cabbageroll", etc
		def.armour_slot = slot -- HEAD, BODY or WAIST
		def.dye_number = cosmetic_data.dye_number   -- for the slot + armour name combo, which colour is this?
		def.build_override = cosmetic_data.build_override -- when equipped, what build override should we apply for this slot?

		def.uitags = Cosmetic.MakeTagsDict(cosmetic_data.uitags) or {} -- always have ui tags

		if Cosmetic.EquipmentDyes[def.armour_slot][def.armour_set] == nil then
			Cosmetic.EquipmentDyes[def.armour_slot][def.armour_set] = {}
		end
		Cosmetic.EquipmentDyes[def.armour_slot][def.armour_set][name] = def
	end

end

function Cosmetic.CollectEquipmentDyeAssets(assets)
	local dupe = {}
	for slot, armour_set in pairs(Cosmetic.EquipmentDyes) do
		for set_name, set_data in pairs(armour_set) do
			for dye_name,dye_def in pairs(set_data) do
				if dye_def.build_override ~= nil and not dupe[dye_def.build_override] then

					local file_path = "anim/"..dye_def.build_override..".zip"

					dupe[dye_def.build_override] = true
					assets[#assets + 1] = Asset("ANIM", "anim/"..dye_def.build_override..".zip")
				end
			end

		end
	end
end

AddDyeSlot("HEAD")
AddDyeSlot("BODY")
AddDyeSlot("WAIST")

return Cosmetic