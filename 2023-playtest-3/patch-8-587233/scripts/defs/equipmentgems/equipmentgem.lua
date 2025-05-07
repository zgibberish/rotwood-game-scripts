local lume = require "util.lume"
local slotutil = require "defs.slotutil"
local icons_inventory = require "gen.atlas.icons_inventory"
require "class"

local EquipmentGem = {
	Slots = {},
	SlotDescriptor = {},
	Items = {},
}

EquipmentGem.Type = MakeEnum{ 
	"DAMAGE",
	"SUPPORT",
	"SUSTAIN",
	"ANY", -- Gem: can be placed into any slot. Slot: any gem can be placed here.
	"SKILL",
}

--[[
https://www.dcode.fr/combinations-with-repetitions

Some examples of combinations given 4 types:
	One value (4 total)
		ANY
		DAMAGE
		SUPPORT
		SUSTAIN

	Two values (10 total)
		DAMAGE,DAMAGE
		DAMAGE,SUPPORT
		DAMAGE,SUSTAIN
		ANY,DAMAGE
		SUPPORT,SUPPORT
		SUPPORT,SUSTAIN
		ANY,SUPPORT
		SUSTAIN,SUSTAIN
		ANY,SUSTAIN
		ANY,ANY

	Three values (20 total)
		DAMAGE,DAMAGE,DAMAGE
		DAMAGE,DAMAGE,SUPPORT
		DAMAGE,DAMAGE,SUSTAIN
		ANY,DAMAGE,DAMAGE
		DAMAGE,SUPPORT,SUPPORT
		DAMAGE,SUPPORT,SUSTAIN
		ANY,DAMAGE,SUPPORT
		DAMAGE,SUSTAIN,SUSTAIN
		ANY,DAMAGE,SUSTAIN
		ANY,ANY,DAMAGE
		SUPPORT,SUPPORT,SUPPORT
		SUPPORT,SUPPORT,SUSTAIN
		ANY,SUPPORT,SUPPORT
		SUPPORT,SUSTAIN,SUSTAIN
		ANY,SUPPORT,SUSTAIN
		ANY,ANY,SUPPORT
		SUSTAIN,SUSTAIN,SUSTAIN
		ANY,SUSTAIN,SUSTAIN
		ANY,ANY,SUSTAIN
		ANY,ANY,ANY

	Four Values (35 total)
		DAMAGE,DAMAGE,DAMAGE,DAMAGE
		DAMAGE,DAMAGE,DAMAGE,SUPPORT
		DAMAGE,DAMAGE,DAMAGE,SUSTAIN
		ANY,DAMAGE,DAMAGE,DAMAGE
		DAMAGE,DAMAGE,SUPPORT,SUPPORT
		DAMAGE,DAMAGE,SUPPORT,SUSTAIN
		ANY,DAMAGE,DAMAGE,SUPPORT
		DAMAGE,DAMAGE,SUSTAIN,SUSTAIN
		ANY,DAMAGE,DAMAGE,SUSTAIN
		ANY,ANY,DAMAGE,DAMAGE
		DAMAGE,SUPPORT,SUPPORT,SUPPORT
		DAMAGE,SUPPORT,SUPPORT,SUSTAIN
		ANY,DAMAGE,SUPPORT,SUPPORT
		DAMAGE,SUPPORT,SUSTAIN,SUSTAIN
		ANY,DAMAGE,SUPPORT,SUSTAIN
		ANY,ANY,DAMAGE,SUPPORT
		DAMAGE,SUSTAIN,SUSTAIN,SUSTAIN
		ANY,DAMAGE,SUSTAIN,SUSTAIN
		ANY,ANY,DAMAGE,SUSTAIN
		ANY,ANY,ANY,DAMAGE
		SUPPORT,SUPPORT,SUPPORT,SUPPORT
		SUPPORT,SUPPORT,SUPPORT,SUSTAIN
		ANY,SUPPORT,SUPPORT,SUPPORT
		SUPPORT,SUPPORT,SUSTAIN,SUSTAIN
		ANY,SUPPORT,SUPPORT,SUSTAIN
		ANY,ANY,SUPPORT,SUPPORT
		SUPPORT,SUSTAIN,SUSTAIN,SUSTAIN
		ANY,SUPPORT,SUSTAIN,SUSTAIN
		ANY,ANY,SUPPORT,SUSTAIN
		ANY,ANY,ANY,SUPPORT
		SUSTAIN,SUSTAIN,SUSTAIN,SUSTAIN
		ANY,SUSTAIN,SUSTAIN,SUSTAIN
		ANY,ANY,SUSTAIN,SUSTAIN
		ANY,ANY,ANY,SUSTAIN
		ANY,ANY,ANY,ANY
]]
EquipmentGem.GemSlotConfigs =
{
	-- jambell:
	-- General idea for first pass: start generic, allowing players to place anything anywhere.
	-- Later weapons get more specific but better.
	-- See how it feels and modify it later!

	BASIC =
	{
		-- EquipmentGem.Type.SKILL
	},

	-- FOREST
	FOREST =
	{
		-- EquipmentGem.Type.SKILL,
		EquipmentGem.Type.ANY,
	},
	MEGATREEMON =
	{
		-- EquipmentGem.Type.SKILL,
		EquipmentGem.Type.ANY,
		EquipmentGem.Type.ANY,
	},
	OWLITZER =
	{
		-- EquipmentGem.Type.SKILL,
		EquipmentGem.Type.ANY,
	},

	--SWAMP
	SWAMP =
	{
		-- EquipmentGem.Type.SKILL,
		EquipmentGem.Type.ANY,
	},

	BANDICOOT =
	{
		-- EquipmentGem.Type.SKILL,
		EquipmentGem.Type.ANY,
		EquipmentGem.Type.ANY,
		EquipmentGem.Type.ANY,
	},
}

function EquipmentGem.AddEquipmentGemSlot(slot, tags)
	slotutil.AddSlot(EquipmentGem, slot, tags)
end

EquipmentGem.AddEquipmentGemSlot("GEMS")

function EquipmentGem.AddEquipmentGem(slot, name, data)
	local items = EquipmentGem.Items[slot]
	assert(items ~= nil and items[name] == nil, "Nonexistent slot " .. slot)

	local def = {
		name = name,
		slot = slot,
		tags = lume.invert(data.tags or {}),
		pretty = slotutil.GetPrettyStrings(slot, name),
		hide = data.hide or false,

		rarity = ITEM_RARITY.s.COMMON,
		icon = icons_inventory.tex["icon_gem_"..data.gem_type:lower()],
		-- stat_mods = data.stat_mods or {},
		-- stat_mults = data.stat_mults or {},

		-- leveling stats
		-- a hand-designed table of exp needed for each level.
		base_exp = data.base_exp or { 1000, 2000, 4000, 8000, 16000 },--{ 1000, 2000, 4000, 8000, 16000 },
		max_ilvl = data.max_ilvl or 5,
	}

	if data.update_thresholds then
		def.update_thresholds = data.update_thresholds
	else
		def.update_thresholds = TUNING.GEM_DEFAULT_UPDATE_THRESHOLDS
	end

	for k, v in pairs(data) do
		if not def[k] then
			def[k] = v
		end
	end

	items[name] = def

	return def
end

function EquipmentGem.FindGemByName(gem_name)
	for _, slot in pairs(EquipmentGem.Items) do
		for name, def in pairs(slot) do
			if gem_name == name then
				return def
			end
		end
	end
	error("Invalid gem name: ".. gem_name)
end

function EquipmentGem.GetItemList(slot, tags)
	return slotutil.GetOrderedItemsWithTag(EquipmentGem.Items[slot], tags)
end

-- Validation

return EquipmentGem

-- GEM IDEAS:
--[[

Weapon Themed
- Weapon Specific Gems that increase damage of specific attacks
- General Damage Gems are weak, compared to this ^

Mob Themed
-- extra damage to MOB
-- extra drops from MOB


]]