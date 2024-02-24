local Consumable = require "defs.consumable"
local Enum = require "util.enum"
local lume = require "util.lume"
local slotutil = require "defs.slotutil"
local Item = require "defs.equipment.item"
require "prefabs"
require "strings.strings"
require "util.tableutil"

local Equipment = {
	Slots = {},
	Symbols = {},
	Items = {},
	SlotDescriptor = {},
	ArmourSets = {},
	WeaponTag = Enum(lume(WEAPON_TYPES) -- lowercase version of WEAPON_TYPES
			:keys()
			:map(string.lower)
			:sort()
			:result()),
}

local _ordered_slots = {}

local function AddItem(item)
	local items = Equipment.Items[item.slot]
	assert(items ~= nil and items[item.name] == nil, "Nonexistent slot "..item.slot)
	items[item.name] = item
	return item
end

local function ConstructAndAddItem(slot, name, build, data)
	return AddItem(Item.Construct(slot, name, build, data))
end

function Equipment.CollectAssets(assets, prefabs)
	local dupe = {}
	for slot, items in pairs(Equipment.Items) do
		local slot_tags = Equipment.SlotDescriptor[slot].tags
		if slot_tags.attachable then
			for name, def in pairs(items) do
				if def.build ~= nil and not dupe[def.build] then
					dupe[def.build] = true
					assets[#assets + 1] = Asset("ANIM", "anim/".. def.build ..".zip")
				end
			end
		end
	end
	for key,weapon_type in pairs(WEAPON_TYPES) do
		-- Weapon types are uppercase, but assets are lower.
		weapon_type = weapon_type:lower()
		-- Weapon-specific art is in the weapon type bank.
		assets[#assets + 1] = Asset("ANIM", "anim/player_bank_".. weapon_type ..".zip")
		table.insert(prefabs, GroupPrefab("fx_".. weapon_type))

		-- The animation data is in the _basic bank.
		assets[#assets + 1] = Asset("ANIM", "anim/player_bank_".. weapon_type .."_basic.zip")
		table.insert(prefabs, GroupPrefab("fx_".. weapon_type .."_basic"))
	end
	--MIKERproto: Add the banks for the weapon you're prototyping
	--table.insert(assets, Asset("ANIM", "anim/player_bank_ropedart.zip"))
	--table.insert(assets, Asset("ANIM", "anim/player_bank_ropedart_basic.zip"))
	return assets, prefabs
end

--------------------------------------------------------------------------

function Equipment.GetItemList(slot, tags)
	return slotutil.GetOrderedItemsWithTag(Equipment.Items[slot], tags)
end

function Equipment.GetOrderedSlots()
	return _ordered_slots
end

function Equipment.FindItem(query)
	for slot_name, slot_items in pairs(Equipment.Items) do
		for name, def in pairs(slot_items) do
			if name == query then
				return def
			end
		end
	end
end

function Equipment.GetPrettyNameForWeaponType(weapon_type)
	local key = "weapon_".. weapon_type:lower()
	return STRINGS.NAMES[key]
end

-- Compare functions for use with table.sort or iterators.sorted_pairs.
function Equipment.CompareDef_ByRarityAndName(a_def, b_def)
	local a_rarity = ITEM_RARITY.id[a_def.rarity]
	local b_rarity = ITEM_RARITY.id[b_def.rarity]
	if a_rarity == b_rarity then
		return a_def.pretty.name < b_def.pretty.name
	end
	return a_rarity > b_rarity
end
function Equipment.CompareId_ByRarityAndName(a, b)
	local a_def = Equipment.Items.MATERIALS[a]
	local b_def = Equipment.Items.MATERIALS[b]
	assert(a_def, a)
	assert(b_def, b)
	return Equipment.CompareDef_ByRarityAndName(a_def, b_def)
end

--------------------------------------------------------------------------

lume(require "defs.equipment.slots"):each(function(slot)
	slotutil.AddSlot(Equipment, slot.name, slot.tags)
	Equipment.Symbols[slot.name] = slot.symbols
	local slot_tags = Equipment.SlotDescriptor[slot.name].tags
	if not slot_tags.hidden then
		assert(slot_tags.attachable == nil)
		-- Visually attached to the character.
		slot_tags.attachable = true
	end
	-- To distinguish in itemcatalog.
	slot_tags.equippable = true
	-- Maintain an ordered list of slots of equipment for display.
	table.insert(_ordered_slots, slot.name)
end)

--------------------------------------------------------------------------

lume(require "defs.equipment.weapon.weapons"):each(function(weapon)
	AddItem(weapon)
	Consumable.MakeRecipeScroll(weapon.name, weapon, Equipment.Slots.WEAPON)
end)

--------------------------------------------------------------------------

function Equipment.GetArmourSets()
	return Equipment.ArmourSets
end

lume(require "defs.equipment.armour_sets"):each(function(armor_set)
	table.insert(Equipment.ArmourSets, armor_set.name)
	for _, armor_piece in ipairs(armor_set.pieces) do
		AddItem(armor_piece)
		-- Consumable.MakeRecipeScroll(armor_set.name, armor_piece, armor_piece.slot)
	end
	-- Consumable.MakeRecipeBook(armor_set.name, armor_set.pieces)
end)

--------------------------------------------------------------------------

local Potions = require "defs.potions"
for _, potion in ipairs(Potions) do
	if potion.slot == Equipment.Slots.TONICS then
		potion.data.stackable = true
	end
	local def = ConstructAndAddItem(potion.slot, potion.name, potion.build, potion.data)
	Consumable.MakeRecipeScroll(def.name, def, def.slot)
end

local Foods = require "defs.foods"
for _, food in ipairs(Foods) do

	food.data.stackable = true

	if food.data.tags then
		table.insert(food.data.tags, "food")
	else
		food.data.tags = { "food" }
	end

	local def = ConstructAndAddItem("FOOD", food.name, food.build, food.data)
	Consumable.MakeRecipeScroll(def.name, def, def.slot)
end

--------------------------------------------------------------------------

--~ local inspect = require "inspect"
--~ print("all_equipment =", inspect(Equipment.Items, { depth = 5, }))

slotutil.ValidateSlotStrings(Equipment)

-- When we want to expose AddSlot and ConstructAndAddItem for mods, we should expose
-- wrappers around them that accept names and icons and stuff those into the
-- appropriate places.
return Equipment
