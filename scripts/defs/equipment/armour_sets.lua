local Enum = require "util.enum"
local Item = require "defs.equipment.item"
local Lume = require "util.lume"
local Slots = require "defs.equipment.slots"
local Weight = require "components/weight"

local Slot = Enum(Lume(Slots):map(function(slot) return slot.name end):sort():result())

local function BuildTagsForSlot(slot, tags)
	if not tags then return end
	local base_tags = tags.BASE or {}
	local slot_tags = tags[slot] or {}
	local merged_tags = Lume.concat(base_tags, slot_tags)
	return merged_tags
end

local function ConstructPiece(name, build, rarity, data, slot)
	local usage_data
	if data.usage_data and data.usage_data.power_on_equip then
		usage_data = shallowcopy(data.usage_data)
		usage_data.power_on_equip = ("%s_%s"):format(usage_data.power_on_equip, slot):lower()
	end

	return Item.Construct(slot, name, build, Lume.merge(
		-- Defaults.
		{
			armour_type = ARMOUR_TYPES.s.CLOTH,
			weight = Weight.EquipmentWeight.s.Normal,
		},

		-- Client-supplied data.
		data,

		-- Dependent data.
		{
			tags = BuildTagsForSlot(slot, data.tags),
			rarity = rarity,
			usage_data = usage_data,

			-- Changes which symbols a piece of armour overrides
			symbol_overrides = data.symbol_overrides and data.symbol_overrides[slot],
			-- Set flags on your current set that other symbols can respond to using conditonal_symbols
			symbol_flags = data.symbol_flags and data.symbol_flags[slot],
			-- Symbols that may or may not be overridden based on symbol_flags
			conditional_symbols = data.conditional_symbols and data.conditional_symbols[slot],
			-- Symbols that get hidden when this piece of armour is equipped
			hidden_symbols = data.hidden_symbols and data.hidden_symbols[slot],
		}
	))
end

local function ConstructSet(name, build, rarity, data)
	local set_defs = {}
	for _, slot in ipairs(Slots) do
		if Lume(slot.tags):any(function(tag) return tag == "armor" end):result() then
			table.insert(set_defs, ConstructPiece(name, build, rarity, data, slot.name))
		end
	end
	return {name = name, pieces = set_defs}
end

return {
	ConstructSet("basic", "armor_basic", ITEM_RARITY.s.COMMON,
		{
			usage_data = {
				power_on_equip = "equipment_basic",
			},
			tags = {
				BASE = { "default_unlocked" },
				[Slot.s.BODY] = { "starting_equipment" },
				[Slot.s.WAIST] = { "starting_equipment" },
			},
			crafting_data =
			{
				monster_source = { "beets" }, -- Temp, but need something other than corestone
				craftable_location = { "treemon_forest" },
			},
			armour_type = ARMOUR_TYPES.s.CLOTH,
		}),
	ConstructSet("cabbageroll", "armor_cabbage", ITEM_RARITY.s.UNCOMMON,
		{
			usage_data = {
				power_on_equip = "equipment_cabbageroll",
			},
			crafting_data =
			{
				monster_source = { "cabbageroll" },
				craftable_location = { "treemon_forest" },
			},
			armour_type = ARMOUR_TYPES.s.SQUISHY,
			weight = Weight.EquipmentWeight.s.Light,
		}),
	-- evasive, combat's not his thing
	ConstructSet("blarmadillo", "armor_blarmadillo", ITEM_RARITY.s.UNCOMMON,
		{
			crafting_data =
			{
				monster_source = { "blarmadillo" },
				craftable_location = { "treemon_forest" },
			},
			usage_data = {
				power_on_equip = "equipment_blarmadillo",
			},
			hidden_symbols = {
				[Slot.s.HEAD] = { "hair_front01", "horn_rgt01", "horn_lft01", "ear_k9_rgt01", "ear_k9_rgt01_inner",
					"ear_k9_lft01", "ear_k9_lft01_inner" },
			},
		}),
	ConstructSet("yammo", "armor_yammo", ITEM_RARITY.s.EPIC,
		{
			crafting_data =
			{
				monster_source = { "yammo" },
				craftable_location = { "treemon_forest" },
			},
			usage_data = {
				power_on_equip = "equipment_yammo",
			},
			hidden_symbols = {
				[Slot.s.HEAD] = { "hair_front01" },
			},
			weight = Weight.EquipmentWeight.s.Heavy,
		}),


-- Owlitzer Forest

	ConstructSet("battoad", "armor_battoad", ITEM_RARITY.s.UNCOMMON,
		{
			usage_data = { power_on_equip = "equipment_battoad" },
			tags = {
				BASE = { },
			},
			crafting_data =
			{
				monster_source = { "battoad" },
				craftable_location = { "owlitzer_forest" },
			},
			armour_type = ARMOUR_TYPES.s.GRASS,
		}),

	ConstructSet("zucco", "armor_zucco", ITEM_RARITY.s.UNCOMMON,
		{
			tags = {
				BASE = { "hide"  },
			},
			usage_data = {
				power_on_equip = "equipment_zucco",
			},
			crafting_data =
			{
				monster_source = { "zucco" },
				craftable_location = { "owlitzer_forest" },
			},
			hidden_symbols = {
				[Slot.s.HEAD] = { "ear_rgt01", "ear_rgt01_inner", "ear_lft01", "ear_lft01_inner", "earring_lft01", "earring_rgt01" },
			},
			weight = Weight.EquipmentWeight.s.Light,
		}),

	ConstructSet("gourdo", "armor_gourdo", ITEM_RARITY.s.EPIC,
		{
			usage_data = { power_on_equip = "equipment_gourdo" },
			tags = {
				BASE = { },
			},
			crafting_data =
			{
				monster_source = { "gourdo" },
				craftable_location = { "owlitzer_forest" },
			},
			hidden_symbols = {
				[Slot.s.HEAD] = { "hair_front01" },
			},
			weight = Weight.EquipmentWeight.s.Heavy,
		}),


	ConstructSet("megatreemon", "armor_megatreemon", ITEM_RARITY.s.EPIC,
		{
			usage_data = {
				power_on_equip = "equipment_megatreemon",
			},
			tags = {
				BASE = { "hide" },
			},
			crafting_data =
			{
				monster_source = { "megatreemon" },
				craftable_location = { "treemon_forest" },
			},
			hidden_symbols = {
				[Slot.s.HEAD] = { "hair_front01" },
			},
		}),
	ConstructSet("owlitzer", "armor_owlitzer", ITEM_RARITY.s.EPIC,
		{
			usage_data = { power_on_equip = "equipment_owlitzer" },
			tags = {
				BASE = { "hide" },
			},
			crafting_data =
			{
				monster_source = { "owlitzer" },
				craftable_location = { "owlitzer_forest" },
			},
			hidden_symbols = {
				[Slot.s.HEAD] = { "hair_front01", "hair01", "ear_rgt01", "ear_rgt01_inner", "ear_lft01", "ear_lft01_inner",
					"horn_rgt01", "horn_lft01", "ear_k9_rgt01", "ear_k9_rgt01_inner", "ear_k9_lft01",
					"ear_k9_lft01_inner", "earring_lft01", "earring_rgt01" },
			},
		}),
	ConstructSet("eyev", "armor_eyev", ITEM_RARITY.s.UNCOMMON,
		{
			usage_data = {
				power_on_equip = "equipment_eyev",
			},
			crafting_data =
			{
				monster_source = { "eyev" },
				craftable_location = { "kanft_swamp" },
			},
			hidden_symbols = {
				[Slot.s.HEAD] = { "hair_front01" },
			},
			weight = Weight.EquipmentWeight.s.Light,
		}),
	ConstructSet("bandicoot", "armor_bandicoot", ITEM_RARITY.s.EPIC,
		{
			usage_data = {
				power_on_equip = "equipment_bandicoot",
			},
			tags = {
				BASE = { "hide", },
				[Slot.s.BODY] = { "hide" },
			},
			location = "owlitzer_forest",
			crafting_data =
			{
				monster_source = { "bandicoot" },
			},
			hidden_symbols = {
				[Slot.s.HEAD] = { "hair_front01", "horn_rgt01", "horn_lft01", "ear_k9_rgt01", "ear_k9_rgt01_inner",
					"ear_k9_lft01", "ear_k9_lft01_inner" },
			},
		}),

	ConstructSet("treemon", "armor_treemon", ITEM_RARITY.s.UNCOMMON,
		{
			tags = {
				BASE = { "hide" },
			},
			crafting_data =
			{
				monster_source = { "treemon" },
				craftable_location = { "treemon_forest" },
			},
		}),

	ConstructSet("windmon", "armor_windmon", ITEM_RARITY.s.UNCOMMON,
		{
			tags = {
				BASE = { },
			},
			usage_data = {
				power_on_equip = "equipment_windmon",
			},
			crafting_data =
			{
				monster_source = { "windmon" },
				craftable_location = { "owlitzer_forest" },
			},
			hidden_symbols = {
				[Slot.s.HEAD] = { "hair_front01", "horn_rgt01", "horn_lft01"},
			},
			weight = Weight.EquipmentWeight.s.Heavy,
		}),

	ConstructSet("gnarlic", "armor_gnarlic", ITEM_RARITY.s.COMMON,
		{
			tags = {
				BASE = { },
			},
			usage_data = {
				power_on_equip = "equipment_gnarlic",
			},
			crafting_data =
			{
				monster_source = { "gnarlic" },
				craftable_location = { "owlitzer_forest" },
			},
			weight = Weight.EquipmentWeight.s.Light,
		}),

	ConstructSet("floracrane", "armor_floracrane", ITEM_RARITY.s.UNCOMMON,
		{
			tags = {
				BASE = { "hide" },
			},
			usage_data = {
				power_on_equip = "equipment_floracrane",
			},
			crafting_data =
			{
				monster_source = { "floracrane" },
				craftable_location = { "kanft_swamp" },
			},
			hidden_symbols = {
				[Slot.s.HEAD] = { "hair_front01" },
			},
			weight = Weight.EquipmentWeight.s.Light,
		}),

	-- so many coming at you quickly. easily passable. +bigspeed, -hp
	ConstructSet("mothball", "armor_mothball", ITEM_RARITY.s.COMMON,
		{
			usage_data = {
				power_on_equip = "equipment_mothball",
			},
			crafting_data =
			{
				monster_source = { "mothball" },
				craftable_location = { "kanft_swamp" },
			},
			hidden_symbols = {
				[Slot.s.HEAD] = { "hair_front01", "horn_rgt01", "horn_lft01", "ear_k9_rgt01", "ear_k9_rgt01_inner",
					"ear_k9_lft01", "ear_k9_lft01_inner" },
			},
			weight = Weight.EquipmentWeight.s.Light,
		})
	,
	ConstructSet("bulbug", "armor_bulbug", ITEM_RARITY.s.UNCOMMON,
		{
			usage_data = {
				power_on_equip = "equipment_bulbug",
			},
			crafting_data =
			{
				monster_source = { "bulbug" },
				craftable_location = { "kanft_swamp" },
			},
			hidden_symbols = {
				[Slot.s.HEAD] = { "hair_front01" },
			},
			weight = Weight.EquipmentWeight.s.Heavy,
		})
	,
	ConstructSet("groak", "armor_groak", ITEM_RARITY.s.EPIC,
		{
			usage_data = {
				power_on_equip = "equipment_groak",
			},
			crafting_data =
			{
				monster_source = { "groak" },
				craftable_location = { "kanft_swamp" },
			},
			weight = Weight.EquipmentWeight.s.Heavy,
		})
	,
	--[[
ConstructSet("seeker", "armor_seeker", ITEM_RARITY.s.LEGENDARY,
{
	stats = seeker_stats,
}),
--]]
	ConstructSet("bonejaw", "armor_bonejaw", ITEM_RARITY.s.LEGENDARY,
		{
			tags = { BASE = { "hide" } },
		}),
	ConstructSet("rotwood", "armor_rotwood", ITEM_RARITY.s.LEGENDARY,
		{
			tags = { BASE = { "hide" } },
		}),
	ConstructSet("thatcher", "armor_thatcher", ITEM_RARITY.s.LEGENDARY,
		{
			tags = { BASE = { "hide" }
			},
			hidden_symbols = {
				[Slot.s.HEAD] = { "hair_front01", "hair01", "ear_rgt01", "ear_rgt01_inner", "ear_lft01", "ear_lft01_inner",
					"horn_rgt01", "horn_lft01", "ear_k9_rgt01", "ear_k9_rgt01_inner", "ear_k9_lft01",
					"ear_k9_lft01_inner", "earring_lft01", "earring_rgt01" },
			},
		}),

	--~ ConstructSet("owlitzer",  "armor_owlitzer", { defend = low * 2,  weight = light * 0.5, }),

	-- miker says basic isn't a complete set. Also, we don't give the full set to
	-- the player so they have something to craft from the start.
}
