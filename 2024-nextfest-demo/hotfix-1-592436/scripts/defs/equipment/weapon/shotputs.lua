local Weapon = require "defs.equipment.weapon.weapon"
local EquipmentGem = require "defs.equipmentgems.equipmentgem"
local lume = require "util.lume"
local Weight = require "components/weight"

local function ConstructShotput(id, build_id, rarity, data)
	return Weapon.Construct(WEAPON_TYPES.SHOTPUT, "shotput_" .. id, "weapon_back_shotput_" .. build_id, rarity,
		lume.merge(data, {
			fx_type = data.fx_type or "basic",
			crafting_data = data.crafting_data or {},
		}))
end

return {
	ConstructShotput("basic", "basic", ITEM_RARITY.s.COMMON,
		{
			ammo = 2,
			usage_data = { power_on_equip = "shotput_recall", },
			gem_slots = EquipmentGem.GemSlotConfigs.BASIC,
			weight = Weight.EquipmentWeight.s.Light,
		}),

-- MOTHER TREEK:
	-- Yammo Themed
	ConstructShotput("startingforest1", "startingforest1",
		ITEM_RARITY.s.UNCOMMON,
		{
			tags = { }, --jambell: hide while reworking equipment
			ammo = 2,
			crafting_data = {
				monster_source = { "yammo", "treemon" },
				craftable_location = { "treemon_forest" }
			},
			usage_data = { power_on_equip = "shotput_recall", },
			gem_slots = EquipmentGem.GemSlotConfigs.FOREST,
			weight = Weight.EquipmentWeight.s.Heavy,
		}),

-- OWLITZER:
	-- Blarmadillo themed, kind of wrong but use for now.
	ConstructShotput("startingforest2", "startingforest2",
		ITEM_RARITY.s.UNCOMMON,
		{
			tags = { }, --jambell: hide while reworking equipment
			ammo = 2,
			crafting_data = {
				monster_source = { "zucco", "windmon" },
				craftable_location = { "owlitzer_forest" }
			},
			usage_data = { power_on_equip = "shotput_recall", },
			gem_slots = EquipmentGem.GemSlotConfigs.FOREST,
			weight = Weight.EquipmentWeight.s.Light,
		}),

-- BANDICOOT:
	--Bulbug themed
	ConstructShotput("swamp1", "swamp1", ITEM_RARITY.s.UNCOMMON,
		{
			ammo = 2,
			crafting_data = {
				monster_source = { "slowpoke", "bulbug" },
				craftable_location = { "kanft_swamp" }
			},
			usage_data = { power_on_equip = "shotput_summon", },
			gem_slots = EquipmentGem.GemSlotConfigs.SWAMP,
			weight = Weight.EquipmentWeight.s.Heavy,
		}),

-- THATCHER:
	-- Floracrane themed
	ConstructShotput("swamp2", "swamp2", ITEM_RARITY.s.UNCOMMON,
		{
			tags = { "hide" }, --jambell: hide while reworking equipment
			ammo = 2,
			crafting_data = {
				monster_source = { "groak", "floracrane" },
				craftable_location = { "kanft_swamp" } -- thatcher_swamp
			},
			usage_data = { power_on_equip = "shotput_summon", },
			gem_slots = EquipmentGem.GemSlotConfigs.SWAMP,
			weight = Weight.EquipmentWeight.s.Light,
		}),


-- Bosses
	ConstructShotput("megatreemon", "megatreemon", ITEM_RARITY.s.EPIC,
		{
			tags = { "hide" }, --jambell: hide while reworking equipment
			crafting_data =
			{
				monster_source = { "megatreemon" },
			},
			usage_data = { power_on_equip = "megatreemon_weaponskill", },
			gem_slots = EquipmentGem.GemSlotConfigs.MEGATREEMON,
		}),
	ConstructShotput("bandicoot", "bandicoot", ITEM_RARITY.s.EPIC,
		{
			tags = { "hide" }, --jambell: hide while reworking equipment
			crafting_data =
			{
				monster_source = { "bandicoot" },
			},
			usage_data = { power_on_equip = "parry", }, --TODO: bandicoot skill
			gem_slots = EquipmentGem.GemSlotConfigs.BANDICOOT,
		})
}
