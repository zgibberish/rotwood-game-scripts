local icons_inventory = require "gen.atlas.icons_inventory"
local kstring = require "util.kstring"
local lume = require "util.lume"
local missinglist = require "util.missinglist"
local slotutil = require "defs.slotutil"

local Item = {}

local DEFAULT_ITEM = {
	name = nil,
	slot = nil,
	build = nil,
	icon = nil,
	pretty = nil,
	tags = {},
	stats = nil,
	base_damage_mod = nil,
	base_armour_mod = nil,
	rarity = ITEM_RARITY.s.COMMON,
	usage_data = {},
	max_level = 5,
	fx_type = nil,
	weapon_type = nil,
	gem_slots = nil,
	ilvl = nil,
	crafting_data = nil,
	stackable = false,
	symbol_overrides = nil,
	conditional_symbols = nil,
	symbol_flags = nil,
	hidden_symbols = nil,
	sound_events = {},
}

-- Anim icons use a confusing naming scheme: they have both legs and pants and
-- are inconsistent about what's plural.
local slot_to_icon = {
	ARMS = "hand",
	SHOULDERS = "shoulder",
	WAIST = "pants",
	POTIONS = "potion",
	TONICS = "tonic",
	FOOD = "food",
}

local function GetIcon(slot, build, name)
	slot = slot_to_icon[slot] or string.lower(slot)
	-- Reverse logic in FlashExporter/DontStarveExporter.cs:171
	local icon_name = ("icon_%s"):format(build)

	if slot == "potion" then
		-- Potion build and icon export names both include "potion_".
		icon_name = ("icon_potion_%s_%s"):format(name, build)
	elseif slot == "tonic" then
		icon_name = ("icon_tonic_%s"):format(name)
	elseif slot == "food" then
		icon_name = ("icon_%s_food_cooked"):format(name)
	elseif not kstring.startswith(build, slot) then
		-- Subpart (like armor): requires slot
		icon_name = ("icon_%s_%s"):format(slot, build)
	end
	local icon = icons_inventory.tex[icon_name]
	if not icon then
		missinglist.AddMissingItem("Equipment", build, ("Missing '%s' icon for '%s'.\t\tExpected tex: %s.tex"):format(slot, build, icon_name))
	end
	return icon
end

local sound_events =
{
	equip = "inventory_equip_%s",
	craft = "inventory_craft_%s",
}

local function GetSoundEvents(slot, name, data)
	local sub
	if data.armour_type then
		sub = data.armour_type
	elseif data.weapon_type then
		sub = data.weapon_type
	else
		sub = slot
	end
	return lume(sound_events):map(function(str) return (str):format((sub):lower()) end):result()
end

local function GetUIIcon(slot, build)
	slot = slot_to_icon[slot] or string.lower(slot)
	-- Reverse logic in FlashExporter/DontStarveExporter.cs:171
	local icon_name = ("icon_ui_%s"):format(build)
	if not kstring.startswith(build, slot) then
		-- Subpart (like armor): requires slot
		icon_name = ("icon_ui_%s_%s"):format(slot, build)
	end
	local icon = icons_inventory.tex[icon_name]
	if not icon then
		missinglist.AddMissingItem("Equipment", build, ("Missing '%s' ui icon for '%s'.\t\tExpected tex: %s.tex\nFalling back to inventory art."):format(slot, build, icon_name))
	end
	return icon
end

local function GetWeaponUnlockIcon(weapon_name)
	return ("images/item_images/itemimage_weapon_back_%s.tex"):format(weapon_name)
end

function Item.Construct(slot, name, build, data)
	return lume.merge(deepcopy(DEFAULT_ITEM), data, { ui_icon = data.icon }, {
		-- Specialize further, being particularly careful to deepcopy tables that cannot be shared.
		-- mandatory stuff that all equipment has
		name = name,
		slot = slot,
		build = build,
		icon = GetIcon(slot, build, name),
		pretty = slotutil.GetPrettyStrings(slot, name),
		tags = lume.invert(data.tags or {}),

		-- Copy to prevent ItemEditor from changing shared stats. Changing this
		-- file and hot loading should still work.
		stats = deepcopy(data.stats),
		sound_events = GetSoundEvents(slot, name, data),

		-- Currently using same art for hud and inventory.
		ui_icon = slot == "POTIONS" and GetUIIcon(slot, build),

		-- Weapons can be unlocked with a large popup, and have icons to be shown then
		unlock_icon = slot == "WEAPON" and GetWeaponUnlockIcon(name) -- or def.icon
	})
end

return Item
