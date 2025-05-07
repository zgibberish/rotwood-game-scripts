local Consumable = require "defs.consumable"
local lume = require "util.lume"
local missinglist = require "util.missinglist"
local slotutil = require "defs.slotutil"
require "strings.strings"

-- Items that can be placed in the world.
local Constructable = {
	Slots = {},
	SlotDescriptor = {},
	Items = {},
}

local ordered_slots = {}

local function AddSlot(slot, tags)
	slotutil.AddSlot(Constructable, slot, tags)
	Constructable.SlotDescriptor[slot].icon = ("images/icons_ftf/build_%s.tex"):format(slot:lower())
	-- Maintain an ordered list of slots.
	table.insert(ordered_slots, slot)
end

local function GetIcon(prefab_name)
	-- consumable item icon name format: icon_[symbol]_[build]
	local icon_name = ("icon_%s"):format(prefab_name)
	missinglist.AddMissingItem("Constructable", prefab_name, ("Missing icon '%s'.\t\tExpected tex: %s.tex"):format(prefab_name, icon_name))
	return "images/icons_ftf/item_temp.tex"
end

local function AddItem(slot, name, category, tags)
	local items = Constructable.Items[slot]
	assert(items ~= nil and items[name] == nil, "Nonexistent slot " .. slot)

	local def = {
		name = name,
		slot = slot,
		category = category,
		icon = GetIcon(name),
		pretty = slotutil.GetPrettyStrings(slot, name),
		tags = lume.invert(tags or {}),
	}

	def.tags[category] = true
	def.tags.placeable = true
	items[name] = def

	return def
end

-- an NPC's home. Cannot build more than one of these, and they are not built through the normal crafting menu
local function AddBuilding(...)
	local def = AddItem(Constructable.Slots.BUILDINGS, ...)
	def.tags.playercraftable = false
	return def
end

-- a purely decorative item in the base, has no functionality other than looking nice
local function AddDecor( ... )
	local def = AddItem(Constructable.Slots.DECOR, ...)
	def.tags.playercraftable = true
	Consumable.MakePlaceablePropItem(def)
	Consumable.MakeRecipeScroll(def.name, def, Constructable.Slots.DECOR)
	return def
end

-- furniture that may or may not have interactions attached
local function AddFurnishing( ... )
	local def = AddItem(Constructable.Slots.FURNISHINGS, ...)
	def.tags.playercraftable = true
	Consumable.MakePlaceablePropItem(def)
	Consumable.MakeRecipeScroll(def.name, def, Constructable.Slots.FURNISHINGS)
	return def
end

--------------------------------------------------------------------------

function Constructable.GetItemList(slot, tags)
	return slotutil.GetOrderedItemsWithTag(Constructable.Items[slot], tags)
end

function Constructable.GetOrderedSlots()
	return ordered_slots
end

function Constructable.CollectPrefabs(prefabs)
	for slot, items in pairs(Constructable.Items) do
		for name in pairs(items) do
			prefabs[#prefabs + 1] = name
		end
	end
end

--------------------------------------------------------------------------

AddSlot("FAVOURITES") -- only exists for descriptor
Constructable.SlotDescriptor.FAVOURITES.is_favourites = true

AddSlot("BUILDINGS")
AddSlot("FURNISHINGS")
AddSlot("DECOR")

--------------------------------------------------------------------------

AddBuilding("kitchen",   		"kitchen")
AddBuilding("kitchen_1",   		"kitchen")

AddBuilding("apothecary",  		"potion")

AddBuilding("armorer",     		"armor")
AddBuilding("armorer_1",   		"armor")

AddBuilding("chemist",     		"chemist")
AddBuilding("chemist_1",   		"chemist")

AddBuilding("forge",       		"weapon")
AddBuilding("forge_1",     		"weapon")

AddBuilding("scout_tent",  		"scout")
AddBuilding("scout_tent_1",		"scout")

AddBuilding("refinery_1",		"refiner")
AddBuilding("refinery",		    "refiner")

AddBuilding("dojo_1",			"dojo_master")

AddBuilding("marketroom_shop",	"dungeon_armorsmith")

--------------------------------------------------------------------------

AddDecor("flower_bush",    		"flora")
AddDecor("flower_violet",  		"flora")
AddDecor("tree",     			"flora")
AddDecor("shrub",     			"flora")
AddDecor("flower_bluebell",		"flora")

AddDecor("plushies_lrg",   		"decor")
AddDecor("plushies_mid",   		"decor")
AddDecor("plushies_sm",    		"decor")
AddDecor("plushies_stack", 		"decor")
AddDecor("basket",         		"decor")

AddDecor("bulletin_board", 		"town")
AddDecor("bread_oven",     		"town")
AddDecor("dye1",     	   		"town")
AddDecor("dye2",     	   		"town")
AddDecor("dye3",     	   		"town")
AddDecor("kitchen_sign",   		"town")
AddDecor("leather_rack",   		"town")
AddDecor("tanning_rack",   		"town")
AddDecor("pergola",        		"town")
AddDecor("travel_pack",    		"town")
AddDecor("weapon_rack",    		"town")
AddDecor("well",     	   		"town")
AddDecor("wooden_cart",    		"town")

AddDecor("stone_lamp",     		"light_fixture")
AddDecor("street_lamp",    		"light_fixture")

--------------------------------------------------------------------------

AddFurnishing("dummy_bandicoot",		   	"dummy")
AddFurnishing("dummy_cabbageroll",		 	"dummy")

AddFurnishing("chair1",		            	"chair")
AddFurnishing("chair2",		            	"chair")
AddFurnishing("bench_megatreemon",		    "chair")
AddFurnishing("bench_rotwood",		   	  	"chair")
AddFurnishing("kitchen_chair",		   	  	"chair")
AddFurnishing("outdoor_seating_stool",		"chair")

AddFurnishing("hammock",		   			"furnishing")
AddFurnishing("kitchen_barrel",		   	  	"furnishing")
AddFurnishing("outdoor_seating",		   	"furnishing")
AddFurnishing("character_customizer_vshack","furnishing")

--------------------------------------------------------------------------

--~ local inspect = require "inspect"
--~ print("all_constructables =", inspect(Constructable.Items, { depth = 5, }))

assert(next(Constructable.Items.FAVOURITES) == nil, "No items should exist in favourites")
slotutil.ValidateSlotStrings(Constructable)

-- crafting menu uses ids as unique lookups
local craft_ids = {}
for slot, items in pairs(Constructable.Items) do
	for name, def in pairs(items) do
		local qualified = ("Constructable.Items.%s.%s"):format(slot, name)
		assert(
			craft_ids[name] == nil,
			("Duplicate item id '%s' used by: '%s' and '%s'"):format(name, qualified, craft_ids[name])
		)
		craft_ids[name] = qualified
	end
end
craft_ids = nil

-- When we want to expose AddSlot and AddItem for mods, we should expose
-- wrappers around them that accept names and icons and stuff those into the
-- appropriate places.

return Constructable
