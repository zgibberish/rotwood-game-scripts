local Enum = require "util.enum"
local lume = require "util.lume"
local missinglist = require "util.missinglist"
local slotutil = require "defs.slotutil"
require "class"

local Cosmetic = {
	Items = {},
	Slots = {},
	SlotDescriptor = {},
}

Cosmetic.Rarities = {"COMMON", "EPIC", "LEGENDARY"}
Cosmetic.Species = {"mer", "ogre", "canine"}

function Cosmetic.MakeTagsDict(taglist)
	if taglist ~= nil and #taglist > 0 then
		local tags = {}
		for i = 1, #taglist do
			tags[taglist[i]] = true
		end
		return tags
	end
end

function Cosmetic.AddTagsToDict(dict, taglist)
	if taglist ~= nil and #taglist > 0 then
		for i = 1, #taglist do
			dict[taglist[i]] = true
		end
		return dict
	end
end

function Cosmetic.SortByItemName(a, b)
	return a.name < b.name
end

-- True if no input tags, item has no tags, or item has all required tags.
function Cosmetic.MatchesTags(item_tags, required_tags)
	if item_tags and required_tags then

		if next(item_tags) == nil or next(required_tags) == nil then
			return true
		end
		
		for tag in pairs(required_tags) do
			if not item_tags[tag] then
				return false
			end
		end
	end

	-- If the item doesn't define tags, then it matches all tags.
	return true
end

local ordered_slots = {}
function AddSlot(slot, tags)
	slotutil.AddSlot(Cosmetic, slot, tags)
	table.insert(ordered_slots, slot)
end

function Cosmetic.GetOrderedSlots()
	return ordered_slots
end

-- TODO: figure out how we are handling the UNLOCKED stuff
function Cosmetic.AddCosmetic(name, data)
	local items = Cosmetic.Items[data.group]
	assert(items ~= nil and items[name] == nil, "Nonexistent slot " .. data.group)

	local def = {
		name = name,
		slot = data.group,
		group = data.group,
		locked = data.locked,
		purchased = data.purchased,
		rarity = data.rarity or "COMMON",
		hidden = data.hidden
	}

	if data.mastery ~= nil and string.lower(data.mastery) ~= "none" then
		def.mastery = data.mastery
	end

	def.filtertags = {}
	if not data.locked then
		def.filtertags["default_unlocked"] = true
	end

	if data.purchased then
		def.filtertags["default_purchased"] = true
	end

	items[name] = def
	return def
end

function Cosmetic.FindDyeByNameAndSlot(cosmetic_name, equipment_slot)
	for name, def in pairs(Cosmetic.Items.EQUIPMENT_DYE) do
		if cosmetic_name.."_"..equipment_slot == name then
			return def
		end
	end
	error("Invalid cosmetic name: ".. cosmetic_name)
end

AddSlot("PLAYER_TITLE")
AddSlot("PLAYER_EMOTE")
AddSlot("PLAYER_COSMETIC")

AddSlot("PLAYER_COLOR")
AddSlot("PLAYER_BODYPART")

AddSlot("ARMOR_COSMETIC")
AddSlot("TOWN_COSMETIC")

AddSlot("EQUIPMENT_DYE")

return Cosmetic
