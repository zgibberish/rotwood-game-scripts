local Weapon = require "defs.equipment.weapon.weapon"
local EquipmentGem = require "defs.equipmentgems.equipmentgem"

return {
	Weapon.Construct(WEAPON_TYPES.GREATSWORD, "cleaver_basic", "weapon_back_cleaver", ITEM_RARITY.s.COMMON,
		{
			tags = { "hide" }, -- TODO(jambell): add the "starting_equipment" tag when ready for public use
			fx_type = "basic",
			gem_slots = EquipmentGem.GemSlotConfigs.BASIC,
		})
}
