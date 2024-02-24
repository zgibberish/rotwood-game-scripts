local icons_inventory = require "gen.atlas.icons_inventory"
local missinglist = require "util.missinglist"
local lume = require "util.lume"
local slotutil = require "defs.slotutil"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"
require "constants"
require "strings.strings"

local Consumable = {
	Items = {},
	Slots = {},
	SlotDescriptor = {},
}

local ordered_slots = {}

function Consumable.AddSlot(slot, tags)
	slotutil.AddSlot(Consumable, slot, tags)
	-- Maintain an ordered list of slots.
	table.insert(ordered_slots, slot)
end

-- Hard code some icons since we use them elsewhere and don't want duplicate
-- art in icons_inventory.
local hardcoded_icons = {
	-- icon_konjur_drops_currency = "images/ui_ftf_icons/konjur.tex",
	-- icon_glitz_drops_currency = "images/hud_images/hud_glitz_drops_currency.tex",
}
local function GetIcon(prefab_name, build)
	-- consumable item icon name format: icon_[symbol]_[build]
	local icon_name = ("icon_%s_%s"):format(prefab_name, build)
	if not build then
		icon_name = ("icon_%s"):format(prefab_name)
	end
	local icon = hardcoded_icons[icon_name] or icons_inventory.tex[icon_name]
	if not icon then
		missinglist.AddMissingItem("Consumable", prefab_name, ("Missing icon '%s' for '%s'.\t\tExpected tex: %s.tex"):format(prefab_name, build, icon_name))
		icon = "images/icons_ftf/item_temp.tex"
	end
	return icon
end

-- If locked, the icon returned will be a silhouette of that material
local function GetLockableIcon(def, locked)
	if locked then
		-- TODO: return silhouettes of the locked items
		return def.icon
		--~ return "images/global/square.tex"
	else
		return def.icon
	end
end

function Consumable.AddItem(slot, name, build, data)
	local items = Consumable.Items[slot]
	assert(items ~= nil and items[name] == nil, "Nonexistent slot " .. slot)

	local def = {
		name = name,
		slot = slot,
		icon = GetIcon(name, build),
		GetLockableIcon = GetLockableIcon,
		pretty = slotutil.GetPrettyStrings(slot, name),
		tags = lume.invert(data.tags or {}),
		rarity = data.rarity or ITEM_RARITY.s.UNCOMMON,
		weight = data.weight or 10,
		source = build,
		stackable = true,
		recipes = data.recipes or nil,
		add_sound = data.add_sound or nil,
		remove_sound = data.remove_sound or nil,
	}

	if data.stackable == false then
		def.stackable = false
	end

	items[name] = def
	return def
end

function Consumable.FindItem(query)
	for slot_name, slot_items in pairs(Consumable.Items) do
		for name, def in pairs(slot_items) do
			if name == query then
				return def
			end
		end
	end
end

-- Compare function for use with table.sort or iterators.sorted_pairs.
function Consumable.CompareDef_ByRarityAndName(a_def, b_def)
	local a_rarity = ITEM_RARITY.id[a_def.rarity] --lume.find(ITEM_RARITY_IDX, a_def.rarity)
	local b_rarity = ITEM_RARITY.id[b_def.rarity] --lume.find(ITEM_RARITY_IDX, b_def.rarity)
	if a_rarity == b_rarity then
		return a_def.pretty.name < b_def.pretty.name
	end
	return a_rarity > b_rarity
end

-- Compare function for use with table.sort or iterators.sorted_pairs.
function Consumable.CompareId_ByRarityAndName(a, b)
	local a_def = Consumable.Items.MATERIALS[a]
	local b_def = Consumable.Items.MATERIALS[b]
	assert(a_def, a)
	assert(b_def, b)
	return Consumable.CompareDef_ByRarityAndName(a_def, b_def)
end

--------------------------------------------------------------------------

function Consumable.GetItemList(slot, tags)
	return slotutil.GetOrderedItemsWithTag(Consumable.Items[slot], tags)
end

function Consumable.GetOrderedSlots()
	return ordered_slots
end

--------------------------------------------------------------------------

Consumable.AddSlot("MATERIALS")
Consumable.AddSlot("PLACEABLE_PROP")
Consumable.AddSlot("KEY_ITEMS")

--------------------------------------------------------------------------

Consumable.AddItem(Consumable.Slots.MATERIALS, 'konjur', 'drops_currency',
{
	tags = { 'glory', 'drops_currency', 'currency', 'netserialize' },
	rarity = ITEM_RARITY.s.COMMON,
	add_sound = fmodtable.Event.add_currency_konjur,
	remove_sound = fmodtable.Event.remove_currency_konjur,
})

Consumable.Items.MATERIALS.konjur.pretty = STRINGS.ITEMS.KONJUR

Consumable.AddItem(Consumable.Slots.MATERIALS, 'glitz', 'drops_currency',
{
	tags = { 'derived_resources', 'playercraftable', 'currency' },
	rarity = ITEM_RARITY.s.COMMON,
})

Consumable.AddItem(Consumable.Slots.MATERIALS, 'konjur_soul_lesser', 'drops_currency',
{
	tags = { 'crafting_resource', 'currency', 'netserialize' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})

Consumable.AddItem(Consumable.Slots.MATERIALS, 'konjur_soul_greater', 'drops_currency',
{
	tags = { 'crafting_resource', 'currency' },
	rarity = ITEM_RARITY.s.EPIC,
})

Consumable.AddItem(Consumable.Slots.MATERIALS, 'konjur_heart', 'drops_currency',
{
	tags = { 'crafting_resource', 'currency' },
	rarity = ITEM_RARITY.s.LEGENDARY,
})

Consumable.AddItem(Consumable.Slots.MATERIALS, 'konjur_heart_megatreemon', 'drops_currency',
{
	tags = { 'crafting_resource', 'currency', "konjur_heart" },
	rarity = ITEM_RARITY.s.LEGENDARY,
})

Consumable.AddItem(Consumable.Slots.MATERIALS, 'konjur_heart_owlitzer', 'drops_currency',
{
	tags = { 'crafting_resource', 'currency', "konjur_heart" },
	rarity = ITEM_RARITY.s.LEGENDARY,
})

Consumable.AddItem(Consumable.Slots.MATERIALS, 'konjur_heart_bandicoot', 'drops_currency',
{
	tags = { 'crafting_resource', 'currency', "konjur_heart" },
	rarity = ITEM_RARITY.s.LEGENDARY,
})

Consumable.AddItem(Consumable.Slots.MATERIALS, 'konjur_heart_thatcher', 'drops_currency',
{
	tags = { 'crafting_resource', 'currency', "konjur_heart" },
	rarity = ITEM_RARITY.s.LEGENDARY,
})

------------- GLOBAL DROPS

-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'generic_meat', 'drops_generic',
-- {
-- 	tags = { LOOT_TAGS.GLOBAL, 'drops_generic', LOOT_TAGS.COOKING, LOOT_TAGS.MEAT },
-- 	rarity = ITEM_RARITY.s.COMMON,
-- })
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'generic_leaf', 'drops_generic',
-- {
-- 	tags = { LOOT_TAGS.GLOBAL, 'drops_generic', LOOT_TAGS.COOKING, LOOT_TAGS.VEG },
-- 	rarity = ITEM_RARITY.s.COMMON,
-- })

-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'generic_bone', 'drops_generic',
-- {
-- 	tags = { LOOT_TAGS.GLOBAL, 'drops_generic', LOOT_TAGS.EQUIPMENT },
-- 	rarity = ITEM_RARITY.s.UNCOMMON,
-- })
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'generic_hide', 'drops_generic',
-- {
-- 	tags = { LOOT_TAGS.GLOBAL, 'drops_generic', LOOT_TAGS.EQUIPMENT },
-- 	rarity = ITEM_RARITY.s.UNCOMMON,
-- })

------------- STARTING FOREST DROPS

-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'forest_sap', 'drops_startingforest',
-- {
-- 	tags = { LOOT_TAGS.BIOME, 'drops_forest' },
-- 	rarity = ITEM_RARITY.s.COMMON,
-- })
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'forest_twigs', 'drops_startingforest',
-- {
-- 	tags = { LOOT_TAGS.BIOME, LOOT_TAGS.EQUIPMENT, 'drops_forest'  },
-- 	rarity = ITEM_RARITY.s.COMMON,
-- })
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'forest_fern', 'drops_startingforest',
-- {
-- 	tags = { LOOT_TAGS.BIOME, LOOT_TAGS.EQUIPMENT, 'drops_forest'  },
-- 	rarity = ITEM_RARITY.s.UNCOMMON,
-- })
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'forest_seed', 'drops_startingforest',
-- {
-- 	tags = { LOOT_TAGS.BIOME, LOOT_TAGS.EQUIPMENT, 'drops_forest'  },
-- 	rarity = ITEM_RARITY.s.UNCOMMON,
-- })

------ STARTING FOREST CREATURE DROPS

-- Cabbage Roll

Consumable.AddItem(Consumable.Slots.MATERIALS, 'cabbageroll_skin', 'drops_cabbageroll',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_cabbageroll' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'cabbageroll_leg', 'drops_cabbageroll',
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_cabbageroll' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, 'cabbageroll_baby', 'drops_cabbageroll',
{
	tags = { LOOT_TAGS.ELITE, 'drops_cabbageroll' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Blarmadillo
Consumable.AddItem(Consumable.Slots.MATERIALS, 'blarmadillo_hide', 'drops_blarmadillo',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_blarmadillo' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'blarmadillo_scale', 'drops_blarmadillo',
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_blarmadillo' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, 'blarmadillo_trunk', 'drops_blarmadillo',
{
	tags = { LOOT_TAGS.ELITE, 'drops_blarmadillo' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Treemon

Consumable.AddItem(Consumable.Slots.MATERIALS, 'treemon_arm', 'drops_treemon',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_treemon' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'treemon_stick', 'drops_treemon',
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_treemon' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, 'treemon_cone', 'drops_treemon',
{
	tags = { LOOT_TAGS.ELITE, 'drops_treemon' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Yammo
Consumable.AddItem(Consumable.Slots.MATERIALS, 'yammo_skin', 'drops_yammo',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_yammo' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'yammo_tail', 'drops_yammo',
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_yammo' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, 'yammo_stem', 'drops_yammo',
{
	tags = { LOOT_TAGS.ELITE, 'drops_yammo' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Zucco
Consumable.AddItem(Consumable.Slots.MATERIALS, 'zucco_skin', 'drops_zucco',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_zucco' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'zucco_stem', 'drops_zucco',
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_zucco' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, 'zucco_claw', 'drops_zucco',
{
	tags = { LOOT_TAGS.ELITE, 'drops_zucco' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Gourdo
Consumable.AddItem(Consumable.Slots.MATERIALS, 'gourdo_hat', 'drops_gourdo',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_gourdo' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'gourdo_finger', 'drops_gourdo',
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_gourdo' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, 'gourdo_skin', 'drops_gourdo',
{
	tags = { LOOT_TAGS.ELITE, 'drops_gourdo' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Eye-V
Consumable.AddItem(Consumable.Slots.MATERIALS, "eyev_vine", "drops_eyev",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_eyev' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, "eyev_eyeball", "drops_eyev",
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_eyev' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, "eyev_eyelashes", "drops_eyev",
{
	tags = { LOOT_TAGS.ELITE, 'drops_eyev' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Beets
Consumable.AddItem(Consumable.Slots.MATERIALS, "beets_body", "drops_beets",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_beets' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
Consumable.AddItem(Consumable.Slots.MATERIALS, "beets_leaf", "drops_beets",
{
	tags = { LOOT_TAGS.ELITE, 'drops_beets' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Gnarlic
Consumable.AddItem(Consumable.Slots.MATERIALS, "gnarlic_cloves", "drops_gnarlic",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_gnarlic' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
Consumable.AddItem(Consumable.Slots.MATERIALS, "gnarlic_sprouts", "drops_gnarlic",
{
	tags = { LOOT_TAGS.ELITE, 'drops_gnarlic' },
	rarity = ITEM_RARITY.s.EPIC,
})
-- Windmon
Consumable.AddItem(Consumable.Slots.MATERIALS, 'windmon_trunk', 'drops_windmon',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_windmon' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'windmon_stick', 'drops_windmon',
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_windmon' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, 'windmon_horn', 'drops_windmon',
{
	tags = { LOOT_TAGS.ELITE, 'drops_windmon' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Megatreemon
Consumable.AddItem(Consumable.Slots.MATERIALS, 'megatreemon_bark', 'drops_megatreemon',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_megatreemon' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'megatreemon_wood', 'drops_megatreemon',
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_megatreemon' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, 'megatreemon_hand', 'drops_megatreemon',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_megatreemon' },
	rarity = ITEM_RARITY.s.EPIC,
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'megatreemon_cone', 'drops_megatreemon',
{
	tags = { LOOT_TAGS.ELITE, 'drops_megatreemon' },
	rarity = ITEM_RARITY.s.LEGENDARY,
})


-- Owlitzer
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'owlitzer_foot', 'drops_owlitzer',
-- {
-- 	tags = { 'drops_owlitzer', 'hide' }
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, 'owlitzer_fur', 'drops_owlitzer',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_owlitzer' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'owlitzer_skull', 'drops_owlitzer',
-- {
-- 	tags = { 'drops_owlitzer', 'hide' }
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, 'owlitzer_pelt', 'drops_owlitzer',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_owlitzer' },
	rarity = ITEM_RARITY.s.EPIC,
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'owlitzer_claw', 'drops_owlitzer',
{
	tags = { LOOT_TAGS.ELITE, 'drops_owlitzer' },
	rarity = ITEM_RARITY.s.LEGENDARY,
})


------------- SWAMP BIOME DROPS

-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'swamp_vines', 'drops_swamp',
-- {
-- 	tags = { LOOT_TAGS.BIOME, 'drops_swamp' },
-- 	rarity = ITEM_RARITY.s.COMMON,
-- })
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'swamp_slime', 'drops_swamp',
-- {
-- 	tags = { LOOT_TAGS.BIOME, 'drops_swamp', LOOT_TAGS.EQUIPMENT },
-- 	rarity = ITEM_RARITY.s.COMMON,
-- })
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'swamp_moss', 'drops_swamp',
-- {
-- 	tags = { LOOT_TAGS.BIOME, 'drops_swamp', LOOT_TAGS.EQUIPMENT },
-- 	rarity = ITEM_RARITY.s.UNCOMMON,
-- })
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'swamp_spore', 'drops_swamp',
-- {
-- 	tags = { LOOT_TAGS.BIOME, 'drops_swamp', LOOT_TAGS.EQUIPMENT },
-- 	rarity = ITEM_RARITY.s.UNCOMMON,
-- })

------ SWAMP CREATURE DROPS

-- Battoad

Consumable.AddItem(Consumable.Slots.MATERIALS, 'battoad_leg', 'drops_battoad',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_battoad' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'battoad_tongue', 'drops_battoad',
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_battoad' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, 'battoad_wing', 'drops_battoad',
{
	tags = { LOOT_TAGS.ELITE, 'drops_battoad' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Mothball
Consumable.AddItem(Consumable.Slots.MATERIALS, "mothball_fluff", "drops_mothball",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_mothball', 'drops_mothball_teen', 'drops_mothball_spawner' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, "mothball_eyeballs", "drops_mothball",
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_mothball', 'drops_mothball_teen', 'drops_mothball_spawner' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })

-- Mothball Teen
Consumable.AddItem(Consumable.Slots.MATERIALS, "mothball_teen_ear", "drops_mothball_teen",
{
	tags = { LOOT_TAGS.ELITE, 'drops_mothball', 'drops_mothball_teen', 'drops_mothball_spawner' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Bulbug
Consumable.AddItem(Consumable.Slots.MATERIALS, "bulbug_jaw", "drops_bulbug",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_bulbug' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, "bulbug_claw", "drops_bulbug",
-- {
-- 	tags = { LOOT_TAGS.ELITE, 'drops_bulbug' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, "bulbug_bulb", "drops_bulbug",
{
	tags = { LOOT_TAGS.ELITE, 'drops_bulbug' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Slowpoke
Consumable.AddItem(Consumable.Slots.MATERIALS, "slowpoke_tail", "drops_slowpoke",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_slowpoke' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, "slowpoke_jaw", "drops_slowpoke",
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_slowpoke' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, "slowpoke_eye", "drops_slowpoke",
{
	tags = { LOOT_TAGS.ELITE, 'drops_slowpoke' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Mossquito
Consumable.AddItem(Consumable.Slots.MATERIALS, "mossquito_cap", "drops_mossquito",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_mossquito' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, "mossquito_nose", "drops_mossquito",
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_mossquito' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, "mossquito_tooth", "drops_mossquito",
{
	tags = { LOOT_TAGS.ELITE, 'drops_mossquito' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Floracrane
Consumable.AddItem(Consumable.Slots.MATERIALS, "floracrane_feather", "drops_floracrane",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_floracrane' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, "floracrane_feet", "drops_floracrane",
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_floracrane' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, "floracrane_beak", "drops_floracrane",
{
	tags = { LOOT_TAGS.ELITE, 'drops_floracrane' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Groak
Consumable.AddItem(Consumable.Slots.MATERIALS, "groak_tentacle", "drops_groak",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_groak' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, "groak_chin", "drops_groak",
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_groak' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, "groak_elite", "drops_groak",
{
	tags = { LOOT_TAGS.ELITE, 'drops_groak' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Totolili
Consumable.AddItem(Consumable.Slots.MATERIALS, "totolili_arm", "drops_totolili",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_totolili' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
Consumable.AddItem(Consumable.Slots.MATERIALS, "totolili_hat", "drops_totolili",
{
	tags = { LOOT_TAGS.ELITE, 'drops_totolili' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Woworm
Consumable.AddItem(Consumable.Slots.MATERIALS, "woworm_lip", "drops_woworm",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_woworm' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
Consumable.AddItem(Consumable.Slots.MATERIALS, "woworm_shield", "drops_woworm",
{
	tags = { LOOT_TAGS.ELITE, 'drops_woworm' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Swarmy
Consumable.AddItem(Consumable.Slots.MATERIALS, "swarmy_slime", "drops_swarmy",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_swarmy' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
Consumable.AddItem(Consumable.Slots.MATERIALS, "swarmy_arm", "drops_swarmy",
{
	tags = { LOOT_TAGS.ELITE, 'drops_swarmy' },
	rarity = ITEM_RARITY.s.EPIC,
})

-- Bandicoot

Consumable.AddItem(Consumable.Slots.MATERIALS, 'bandicoot_tail', 'drops_bandicoot',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_bandicoot' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
-- Consumable.AddItem(Consumable.Slots.MATERIALS, 'bandicoot_skull', 'drops_bandicoot',
-- {
-- 	tags = { LOOT_TAGS.NORMAL, 'drops_bandicoot' },
-- 	rarity = ITEM_RARITY.s.RARE,
-- })
Consumable.AddItem(Consumable.Slots.MATERIALS, 'bandicoot_wing', 'drops_bandicoot',
{
	tags = { LOOT_TAGS.NORMAL, 'drops_bandicoot' },
	rarity = ITEM_RARITY.s.EPIC,
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'bandicoot_hand', 'drops_bandicoot',
{
	tags = { LOOT_TAGS.ELITE, 'drops_bandicoot' },
	rarity = ITEM_RARITY.s.LEGENDARY,
})


-- Seeker
Consumable.AddItem(Consumable.Slots.MATERIALS, "seeker_wood_stick", "drops_seeker",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_seeker' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
Consumable.AddItem(Consumable.Slots.MATERIALS, "seeker_leaf", "drops_seeker",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_seeker' },
	rarity = ITEM_RARITY.s.UNCOMMON,
})
Consumable.AddItem(Consumable.Slots.MATERIALS, "seeker_wood_plank", "drops_seeker",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_seeker' },
	rarity = ITEM_RARITY.s.RARE,
})
Consumable.AddItem(Consumable.Slots.MATERIALS, "seeker_beard", "drops_seeker",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_seeker' },
	rarity = ITEM_RARITY.s.EPIC,
})
Consumable.AddItem(Consumable.Slots.MATERIALS, "seeker_boquet", "drops_seeker",
{
	tags = { LOOT_TAGS.NORMAL, 'drops_seeker' },
	rarity = ITEM_RARITY.s.LEGENDARY,
})

--------------------------------------------------------------------------

-- Arak
Consumable.AddItem(Consumable.Slots.MATERIALS, 'arak_eye', 'drops_arak',
{
	tags = { 'drops_arak', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'arak_leg', 'drops_arak',
{
	tags = { 'drops_arak', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'arak_shell', 'drops_arak',
{
	tags = { 'drops_arak', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'arak_skull', 'drops_arak',
{
	tags = { 'drops_arak', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'arak_web', 'drops_arak',
{
	tags = { 'drops_arak', 'hide' }
})



-- Bonejaw
Consumable.AddItem(Consumable.Slots.MATERIALS, 'bonejaw_claw', 'drops_bonejaw',
{
	tags = { 'drops_bonejaw', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'bonejaw_hide', 'drops_bonejaw',
{
	tags = { 'drops_bonejaw', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'bonejaw_skull', 'drops_bonejaw',
{
	tags = { 'drops_bonejaw', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'bonejaw_spike', 'drops_bonejaw',
{
	tags = { 'drops_bonejaw', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'bonejaw_tail', 'drops_bonejaw',
{
	tags = { 'drops_bonejaw', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'bonejaw_tooth', 'drops_bonejaw',
{
	tags = { 'drops_bonejaw', 'hide' }
})

-- Rotwood
Consumable.AddItem(Consumable.Slots.MATERIALS, 'rotwood_bark', 'drops_rotwood',
{
	tags = { 'drops_rotwood', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'rotwood_face', 'drops_rotwood',
{
	tags = { 'drops_rotwood', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'rotwood_root', 'drops_rotwood',
{
	tags = { 'drops_rotwood', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'rotwood_twig', 'drops_rotwood',
{
	tags = { 'drops_rotwood', 'hide' }
})

-- Thatcher
Consumable.AddItem(Consumable.Slots.MATERIALS, 'thatcher_antennae', 'drops_thatcher',
{
	tags = { 'drops_thatcher', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'thatcher_fur', 'drops_thatcher',
{
	tags = { 'drops_thatcher', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'thatcher_limb', 'drops_thatcher',
{
	tags = { 'drops_thatcher', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'thatcher_shell', 'drops_thatcher',
{
	tags = { 'drops_thatcher', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'thatcher_skull', 'drops_thatcher',
{
	tags = { 'drops_thatcher', 'hide' }
})
Consumable.AddItem(Consumable.Slots.MATERIALS, 'thatcher_wing', 'drops_thatcher',
{
	tags = { 'drops_thatcher', 'hide' }
})

-- auto-generated through constructable.lua
function Consumable.MakePlaceablePropItem(constructable_def)
	local slot = Consumable.Slots.PLACEABLE_PROP
	local items = Consumable.Items[slot]
	local name = constructable_def.name
	assert(items ~= nil and items[name] == nil, "Nonexistent slot " .. slot)

	local def = {
		name = name,
		slot = slot,
		icon = constructable_def.icon,
		pretty = constructable_def.pretty,
		tags = constructable_def.tags,
		rarity = ITEM_RARITY.s.COMMON,
		weight = 1,
		stackable = false,
	}

	items[name] = def
	return def
end

local function GetIconForRecipeItem(prefab_name, recipes)
	local icon_name = nil

	if #recipes > 1 then
		local recipe_type = "book"
		if recipes[1].slot == "WEAPON" then
			icon_name = "icon_recipe_book_weapon"
		else
			icon_name = "icon_recipe_book_armour"
		end
	else
		local armour_slots = 
		{
			["HEAD"] = true,
			["BODY"] = true,
			["SHOULDERS"] = true,
			["ARMS"] = true,
			["WAIST"] = true,
			["LEGS"] = true,
		}

		local recipe = recipes[1]
		if recipe.slot == "WEAPON" then
			icon_name = ("icon_recipe_scroll_%s_%s"):format(recipe.slot, recipe.def.weapon_type)
		elseif armour_slots[recipe.slot] then
			icon_name = ("icon_recipe_scroll_armour_%s"):format(recipe.slot)
		else
			icon_name = ("icon_recipe_scroll_%s"):format(recipe.slot)
		end
	end

	icon_name = string.lower(icon_name)

	local icon = icons_inventory.tex[icon_name]
	if not icon then
		missinglist.AddMissingItem("Consumable", prefab_name, ("Missing icon for recipe item: '%s'.\t\tExpected tex: %s.tex"):format(prefab_name, icon_name))
		icon = "images/icons_ftf/item_temp.tex"
	end

	return icon
end

local function BuildStringsForRecipeScroll(item_def)
	local pretty = {}
	assert(STRINGS.ITEMS.KEY_ITEMS.recipe_generic.name ~= nil, string.format("Cannot find recipe name and desc for [%s]. Please add at STRINGS.ITEMS.KEY_ITEMS.recipe_generic.", item_def.name))
	assert(item_def.pretty ~= nil, string.format("'item_def.pretty not found for [%s]. Please add strings in STRINGS.ITEMS.", item_def.name))
	pretty.name = string.format(STRINGS.ITEMS.KEY_ITEMS.recipe_generic.name, STRINGS.ITEM_CATEGORIES[item_def.slot], item_def.pretty.name)
	pretty.desc = string.format(STRINGS.ITEMS.KEY_ITEMS.recipe_generic.desc, STRINGS.ITEM_CATEGORIES[item_def.slot], item_def.pretty.name)
	return pretty
end

-- auto-generated through constructable.lua
function Consumable.MakeRecipeScroll(item_name, item_def, item_slot)
	local name = string.lower(string.format("recipe_scroll_%s_%s", item_slot, item_def.name))
	local slot = Consumable.Slots.KEY_ITEMS
	local items = Consumable.Items[slot]

	assert(items ~= nil, "Nonexistent slot " .. slot)
	assert(items[name] == nil, string.format("Item with name/ slot already exists (%s/%s)", name, slot))

	local recipes = { { name = item_name, slot = item_slot, def = item_def } }

	local def = {
		name = name,
		slot = slot,
		icon = GetIconForRecipeItem(item_name, recipes),
		-- TODO(dbriscoe): Convert to a Pretty() function so the localization string swaps will be detected.
		pretty = BuildStringsForRecipeScroll(item_def),
		tags = lume.invert({"recipe"}),
		rarity = item_def.rarity or ITEM_RARITY.s.COMMON,
		weight = 1,
		recipes = recipes,
		stackable = false,
	}

	items[name] = def
	return def
end

function Consumable.MakeRecipeBook(item_name, item_defs)
	local collection_type = "armourset"
	if item_defs[1].slot == "WEAPON" then
		collection_type = "weapons"
	end

	local name = string.lower(string.format("recipe_book_%s_%s", collection_type, item_name))
	local slot = Consumable.Slots.KEY_ITEMS
	local items = Consumable.Items[slot]

	assert(items ~= nil, "Nonexistent slot " .. slot)
	assert(items[name] == nil, string.format("Item with name/ slot already exists (%s/%s)", name, slot))

	local recipes = {}

	for _, def in ipairs(item_defs) do
		table.insert(recipes, { name = item_name, slot = def.slot, def = def })
	end

	local def = {
		name = name,
		slot = slot,
		icon = GetIconForRecipeItem(item_name, recipes),
		pretty = slotutil.GetPrettyStrings(slot, item_name),
		tags = lume.invert({"recipe"}),
		rarity = item_defs[1].rarity or ITEM_RARITY.s.UNCOMMON,
		weight = 1,
		recipes = recipes,
		stackable = false,
	}

	items[name] = def
	return def
end

--~ local inspect = require "inspect"
--~ print("all_consumables =", inspect(Consumable.Items, { depth = 5, }))

slotutil.ValidateSlotStrings(Consumable)

-- When we want to expose AddSlot and AddItem for mods, we should expose
-- wrappers around them that accept names and icons and stuff those into the
-- appropriate places.
return Consumable
