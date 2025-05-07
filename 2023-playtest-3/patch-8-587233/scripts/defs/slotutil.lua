local kassert = require "util.kassert"
local lume = require "util.lume"

-- Utilities for working with Equipment, Consumable, powers, mastery, and other
-- defs that follow similar patterns.
local slotutil = {}

function slotutil.AddSlot(t, slot, tags, max_count)
	assert(type(max_count) == "nil" or (type(max_count) == "number" and max_count > 0))
	assert(t.Slots[slot] == nil)
	t.Slots[slot] = slot
	t.Items[slot] = {}
	local slot_tags = lume.invert(tags or {})
	t.SlotDescriptor[slot] = {
		slot = slot,
		-- TODO(dbriscoe): Convert to a Pretty() function so the localization string swaps will be detected.
		pretty = {
			name = STRINGS.ITEM_CATEGORIES[slot],
		},
		icon = ("images/icons_ftf/inventory_%s.tex"):format(slot:lower()),
		tags = slot_tags,
	}
	if max_count then
		assert(t.MaxCount, "Need to define MaxCount table for this slot usage")
		t.MaxCount[slot] = max_count
	end
end

function slotutil.SortByItemName(a, b)
	return a.name < b.name
end

function slotutil.GetOrderedItemsWithTag(items, required_tags)
	kassert.typeof('table', items)
	if not required_tags or not next(required_tags) then
		required_tags = nil
	end
	local t = {}
	for name,def in pairs(items) do
		local has_all_tags = true
		if required_tags then
			has_all_tags = def.tags and lume.all(required_tags, function(input_tag)
				return def.tags[input_tag]
			end)
		end
		if has_all_tags then
			table.insert(t, def)
		end
	end
	table.sort(t, slotutil.SortByItemName)
	return t
end

function slotutil.GetPrettyStrings(slot, name)
	local slot_strings = STRINGS.ITEMS[slot]
	return slot_strings and slot_strings[name]
end

function slotutil.GetPrettyStringsByType(slot, type, name)
	local slot_strings = STRINGS.ITEMS[slot][type]
	return slot_strings and slot_strings[name]
end

function slotutil.ValidateSlotStrings(t)
	for _,slot in pairs(t.Slots) do
		assert(STRINGS.ITEM_CATEGORIES[slot], "Missing category name string for slot [".. slot .."]. Please add to STRINGS.ITEM_CATEGORIES."..slot)
		for name,def in pairs(t.Items[slot]) do
			if def.show_in_ui or def.show_in_ui == nil then
				-- Only check for slot string if there are items to support runtime
				-- slot placeholders.
				assert(STRINGS.ITEMS[slot], "Missing strings for slot [".. slot.."]. Please add to STRINGS.ITEMS."..slot)
				local msg = ("Missing strings for item STRINGS.ITEMS.%s.%s"):format(slot, name)
				assert(def.pretty, msg)
				assert(def.pretty.name, msg)
				assert(def.pretty.desc, msg)
			end
		end
	end
end

local function GetToolTipAsString(def, tt)
	if type(tt) == "function" then
		-- Define a tooltip as a function when it needs to be more elaborate
		-- (refer to other powers).
		return tt()
	end
	return STRINGS.UI.TOOLTIPS[tt]
end

-- We only store tooltip keys so when we get their value, we always get the
-- translated string.
function slotutil.BuildToolTip(def, config)
	config = config or table.empty
	local tooltip
	if config.is_lucky then
		tooltip = STRINGS.UI.TOOLTIPS.LUCKY
	end
	for i,tt in ipairs(def.tooltips) do
		local str = GetToolTipAsString(def, tt)
		tooltip = tooltip and tooltip.."\n\n"..str or str
	end
	return tooltip
end

function slotutil.ValidateAllTooltipsExist(def)
	local is_valid = true
	for i,tt in ipairs(def.tooltips) do
		local str = GetToolTipAsString(def, tt)
		kassert.assert_fmt(str, "Def '%s' used undefined tooltip string 'STRINGS.UI.TOOLTIPS.%s' (or tooltip function returned nil).", def.name, tt)
		is_valid = str and is_valid
	end
	return is_valid
end


return slotutil
