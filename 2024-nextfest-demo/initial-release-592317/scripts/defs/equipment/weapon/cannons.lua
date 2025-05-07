local Weapon = require "defs.equipment.weapon.weapon"
local lume = require "util.lume"
local EquipmentGem = require "defs.equipmentgems.equipmentgem"
local Weight = require "components/weight"

local function Construct(id, build_id, rarity, data)
	return Weapon.Construct(WEAPON_TYPES.CANNON, "cannon_" .. id, "weapon_back_cannon_" .. build_id, rarity,
		lume.merge(data, {
			fx_type = data.fx_type or "basic",
			crafting_data = data.crafting_data or {},
		}))
end

return {
	Construct("basic", "basic", ITEM_RARITY.s.COMMON,
		{
			ammo = 6,
			usage_data = { power_on_equip = "cannon_butt", },
			gem_slots = EquipmentGem.GemSlotConfigs.BASIC,
		}),

	-- OWLITZER
	-- Battoad Themed
	Construct("swamp1", "swamp1", ITEM_RARITY.s.UNCOMMON,
		{
			ammo = 6,
			crafting_data =
			{
				monster_source = { "battoad", "windmon" },
				craftable_location = { "owlitzer_forest" },
			},
			usage_data = { power_on_equip = "cannon_butt", },
			gem_slots = EquipmentGem.GemSlotConfigs.SWAMP,
			weight = Weight.EquipmentWeight.s.Normal,
		}),

	-- BANDICOOT
	-- Groak themed
	Construct("swamp2", "swamp2", ITEM_RARITY.s.UNCOMMON,
		{
			tags = { }, --jambell: hide while reworking equipment
			ammo = 6,
			crafting_data =
			{
				monster_source = { "groak", "floracrane" },
				craftable_location = { "kanft_swamp" },
			},
			usage_data = { power_on_equip = "cannon_butt", },
			gem_slots = EquipmentGem.GemSlotConfigs.SWAMP,
			weight = Weight.EquipmentWeight.s.Heavy,
		}),

-- BOSSES:

	Construct("bandicoot", "bandicoot", ITEM_RARITY.s.EPIC,
		{
			tags = { "hide" }, --jambell: hide while reworking equipment
			ammo = 6,
			crafting_data =
			{
				monster_source = { "bandicoot" },
			},
			usage_data = { power_on_equip = "parry", }, -- TODO bandicoot skill
			gem_slots = EquipmentGem.GemSlotConfigs.BANDICOOT,
		}),
	Construct("megatreemon", "megatreemon", ITEM_RARITY.s.EPIC,
		{
			tags = { "hide" }, --jambell: hide while reworking equipment
			ammo = 6,
			crafting_data =
			{
				monster_source = { "megatreemon" },
			},
			usage_data = { power_on_equip = "megatreemon_weaponskill", },
			gem_slots = EquipmentGem.GemSlotConfigs.MEGATREEMON,
		})
}
