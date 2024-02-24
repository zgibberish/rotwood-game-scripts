local Enum = require "util.enum"
local kassert = require "util.kassert"
local krandom = require "util.krandom"
local kstring = require "util.kstring"
local lume = require "util.lume"
local missinglist = require "util.missinglist"
local heart_icons = require "gen.atlas.icons_inventory"
local slotutil = require "defs.slotutil"
require "class"
require "strings.strings"

local Heart = {
	Items = {},
	Slots = {},
	SlotDescriptor = {},
	MaxCount = {},
}

local ordered_slots = {}

local function GetIcon(heart_id)
	local icon_name = ("icon_konjur_heart_%s_drops_currency"):format(heart_id)
	local icon = heart_icons.tex[icon_name]

	if not icon then
		missinglist.AddMissingItem("Heart", heart_id, ("Missing icon for heart '%s'.\t\tExpected tex: %s.tex"):format(heart_id, icon_name))
		icon = "images/icons_ftf/item_temp.tex"
	end

	return icon
end

function Heart.AddHeartFamily(slot, tags, max_count)
	max_count = max_count or Heart.MaxPerSlotDefault
	slotutil.AddSlot(Heart, slot, tags, max_count)
	table.insert(ordered_slots, slot)
end

function Heart.AddHeart(slot, name, build, data)
	local items = Heart.Items[slot]
	assert(items ~= nil and items[name] == nil, "Nonexistent slot " .. slot)

	local def = {
		name = name,
		idx = data.idx, -- 1 or 2, which slot of the biome is it in?
		slot = slot,
		icon = data.icon or GetIcon(name),
		pretty = data.pretty or slotutil.GetPrettyStrings(slot, name),
		-- Used both as organizational tags (for querying power defs) and tags
		-- applied to the entity! Added to the entity while the power is active.
		tags = data.tags or {},
		prefabs = data.prefabs,
		assets = data.assets,
		power = data.power,
		stacks_per_level = data.stacks_per_level,
		description_fn = data.description_fn,
		heart_id = "konjur_heart_"..name, -- the id of the heart_def that relates to this power
	}

	-- TODO(jambell): re-enable tooltip validation?
	-- dbassert(slotutil.ValidateAllTooltipsExist(def))

	items[name] = def
	return def
end

function Heart.GetItemList(slot, tags)
	return slotutil.GetOrderedItemsWithTag(Heart.Items[slot], tags)
end

function Heart.GetHeartDef(slot, idx)
	for name, def in pairs(Heart.Items[slot]) do
		if def.idx == idx then
			return def
		end
	end
end

function Heart.GetDescForHeart(heart)
	local def = heart:GetDef()
	local tuning = heart:GetTuning()
	local desc = kstring.subfmt(def.pretty.desc, tuning)
	return kstring.subfmt("{desc}", {desc = desc})
end

function Heart.GetAllHeartNames(tbl)
	for _, slot in pairs(Heart.Items) do
		for name, def in pairs(slot) do
			table.insert(tbl, name)
		end
	end
end

function Heart.GetAllHearts()
	local hearts = {}
	for _, slot in pairs(Heart.Items) do
		for name, def in pairs(slot) do
			table.insert(hearts, def)
		end
	end
	return hearts
end

function Heart.GetAllHeartsOfFamily(family)
	local hearts = {}
	for _, def in pairs(Heart.Items[family]) do
		table.insert(hearts, def)
	end
	return hearts
end

-- Validation
-- for _,power_type in pairs(Power.Types) do
-- 	assert(STRINGS.POWERS.POWER_TYPE[power_type], "STRINGS.POWERS.POWER_TYPE not found: "..power_type)
-- end
-- for _,power_category in pairs(Power.Categories) do
-- 	assert(STRINGS.POWERS.POWER_CATEGORY[power_category])
-- end
-- for _,power_rarity in pairs(Power.Rarity) do
-- 	assert(STRINGS.POWERS.POWER_RARITY[power_rarity])
-- end

return Heart