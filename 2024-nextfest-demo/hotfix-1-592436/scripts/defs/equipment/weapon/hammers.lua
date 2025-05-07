local Weapon = require "defs.equipment.weapon.weapon"
local lume = require "util.lume"
local EquipmentGem = require "defs.equipmentgems.equipmentgem"
local Weight = require "components/weight"

local function Construct(id, build_id, rarity, data)
	return Weapon.Construct(WEAPON_TYPES.HAMMER, "hammer_" .. id, "weapon_back_hammer_" .. build_id, rarity,
		lume.merge(data, {
			fx_type = data.fx_type or "basic",
			crafting_data = data.crafting_data or {},
		}))
end

return {
	Construct( "sledge", "sledge", ITEM_RARITY.s.COMMON,
		{
			tags = { "hide" },
			fx_type = "basic",
		}),

	Construct("basic", "basic", ITEM_RARITY.s.COMMON, {
		tags = { "starting_equipment", "default_unlocked" },
		usage_data = { power_on_equip = "hammer_thump", },
		gem_slots = EquipmentGem.GemSlotConfigs.BASIC,
	}),

	-- MOTHER TREEK:
	-- Yammo themed
	Construct("startingforest2", "startingforest_2", ITEM_RARITY.s.UNCOMMON, {
		tags = { },
		crafting_data =
		{
			monster_source = { "treemon", "yammo" },
			craftable_location = { "treemon_forest" },
		},
		usage_data = { power_on_equip = "hammer_thump", },
		gem_slots = EquipmentGem.GemSlotConfigs.FOREST,
		weight = Weight.EquipmentWeight.s.Heavy,
	}),

	-- OWLITZER:
	-- Battoad themed.
	Construct("swamp", "swamp", ITEM_RARITY.s.UNCOMMON,
		{
			crafting_data =
			{
				monster_source = { "windmon", "battoad" },
				craftable_location = { "owlitzer_forest" },
			},
			usage_data = { power_on_equip = "hammer_thump", },
			gem_slots = EquipmentGem.GemSlotConfigs.FOREST,
			weight = Weight.EquipmentWeight.s.Normal,
		}),

	-- BANDICOOT:
	Construct("swamp2", "swamp_2", ITEM_RARITY.s.UNCOMMON, {
		tags = { },
		crafting_data =
		{
			monster_source = { "groak", "eyev" },
			craftable_location = { "kanft_swamp" },
		},
		usage_data = { power_on_equip = "hammer_thump", },
		gem_slots = EquipmentGem.GemSlotConfigs.SWAMP,
		weight = Weight.EquipmentWeight.s.Heavy,
	}),

	-- THATCHER:
	-- nothing here yet

	-- Boss weapons:
	-- Super Frenzies Only
	Construct("megatreemon", "megatreemon", ITEM_RARITY.s.EPIC, {
		tags = { "hide" }, --jambell: hide while reworking equipment
		crafting_data =
		{
			monster_source = { "megatreemon" },
		},
		usage_data = { power_on_equip = "megatreemon_weaponskill", },
		gem_slots = EquipmentGem.GemSlotConfigs.MEGATREEMON,
	}),

	Construct("bandicoot", "bandicoot", ITEM_RARITY.s.EPIC, {
		tags = { "hide" }, --jambell: hide while reworking equipment
		crafting_data =
		{
			monster_source = { "bandicoot" },
		},
		usage_data = { power_on_equip = "parry", }, --TODO: bandicoot skill
		gem_slots = EquipmentGem.GemSlotConfigs.BANDICOOT,
	}),


	-- Blarmadillo themed, hide for now
	Construct("startingforest", "startingforest", ITEM_RARITY.s.UNCOMMON, {
		tags = { "hide" },
		crafting_data =
		{
			monster_source = { "treemon", "blarmadillo" },
			craftable_location = { "treemon_forest" },
		},
		usage_data = { power_on_equip = "hammer_thump", },
		gem_slots = EquipmentGem.GemSlotConfigs.FOREST,
		weight = Weight.EquipmentWeight.s.Normal,
	}),
}
