local kassert = require "util.kassert"
local kstring = require "util.kstring"
local missinglist = require "util.missinglist"

local mastery_icons = require "gen.atlas.ui_ftf_mastery_icons"

local slotutil = require "defs.slotutil"

require "strings.strings"

local Mastery = {
	Items = {},
	Slots = {},
	SlotDescriptor = {},
	Paths = {},
}

local ordered_slots = {}

function Mastery.AddMasteryFamily(slot, tags)
	slotutil.AddSlot(Mastery, slot, tags)
	table.insert(ordered_slots, slot)
end

Mastery.AddMasteryFamily("WEAPON_MASTERY")
Mastery.AddMasteryFamily("MONSTER_MASTERY")

local function GetIcon(mastery_type)
	-- mastery icon name format: icon_mastery_[mastery_type]
	local icon_name = ("icon_mastery_%s"):format(mastery_type)

	icon_name = string.lower(icon_name)

	local icon = mastery_icons.tex[icon_name]

	if not icon then
		missinglist.AddMissingItem("Mastery", mastery_type, ("Missing mastery icon for '%s'.\t\tExpected tex: %s.tex"):format(mastery_type, icon_name))
		icon = mastery_icons.tex.icon_mastery_temp
	end

	return icon
end

local _default_update_thresholds =
{
	-- percentage completion, gets put into persistdata on creation of a mastery with an associated bool for whether that threshold has been updated or not
	0.85,
	0.75,
	0.5,
	0.25,
	0.01, -- Basically, update the first time it happens
}

function Mastery.AddMastery(slot, name, mastery_type, data)
	local items = Mastery.Items[slot]
	assert(items ~= nil and items[name] == nil, "Nonexistent slot " .. slot)

	local def = {
		name = name,
		slot = slot,
		icon = GetIcon(mastery_type),
		pretty = slotutil.GetPrettyStringsByType(slot, mastery_type, name),
		-- Used both as organizational tags (for querying mastery defs) and tags
		-- applied to the entity! Added to the entity while the mastery is active.
		tags = data.tags or {},
		assets = data.assets,
		mastery_type = mastery_type,

		on_update_fn = data.on_update_fn,
		on_add_fn = data.on_add_fn,
		on_remove_fn = data.on_remove_fn,
		event_triggers = data.event_triggers or {},
		remote_event_triggers = data.remote_event_triggers or {},

		update_thresholds = data.update_thresholds or _default_update_thresholds,
		progress = data.progress,
		starting_progress = data.starting_progress or 0,
		max_progress = data.max_progress or 20, -- default to 20?
		tooltips = data.tooltips or {},

		next_step = data.next_step or nil,
	}

	items[name] = def
	return def
end

function Mastery.FindMasteryByQualifiedName(qualified_name)
	local mastery_name = qualified_name:match("^mst_(%S+)$")
	kassert.assert_fmt(mastery_name, "Invalid mastery '%s'", qualified_name)
	return Mastery.FindMasteryByName(mastery_name)
end

function Mastery.FindMasteryByName(mastery_name)
	for _, slot in pairs(Mastery.Items) do
		for name, def in pairs(slot) do
			if mastery_name == name then
				return def
			end
		end
	end
	error("Invalid mastery name: ".. mastery_name)
end

function Mastery.GetDesc(mastery)
	local def = mastery:GetDef()
	local desc = kstring.subfmt(def.pretty.desc, mastery:GetTuning())
	return kstring.subfmt("{desc}", {desc = desc})
end

function Mastery.CollectAssets(tbl)
	for _, slot in pairs(Mastery.Items) do
		for name, def in pairs(slot) do
			if def.assets then
				for _, asset in ipairs(def.assets) do
					table.insert(tbl, asset)
				end
			end
		end
	end
end

function Mastery.CollectPrefabs(tbl)
	for _, slot in pairs(Mastery.Items) do
		for name, def in pairs(slot) do
			if def.prefabs then
				for _, prefab in ipairs(def.prefabs) do
					table.insert(tbl, prefab)
				end
			end
		end
	end
end

function Mastery.GetOrderedSlots()
	return ordered_slots
end

------ Mastery Paths --------

-- This is unfinished. The intent is that you would activate a mastery path in mastery manager and that would start you down the line
-- of the masteries in the table related to it. Whenever you complete a mastery, it will evaluate all your current mastery paths
-- and if any of the paths is currently on that mastery, it will advance the path and spawn the next one.

-- It should also check if you are already done the next mastery in the path just in case, and in that event it could skip forward
-- until it finds a mastery you have not completed.

-- Mastery paths could be activated when an enemy is first discovered or killed, or when a weapon type is unlocked for example.

-- Activating a mastery path could create a 'mastery path instance' type item in the mastery manager that can save/load information about
-- your progress down that mastery path, but ideally this is a realatively simple piece of data that doesn't require much internal logic

-- You can optionally entirely define the path when creating the path...
function Mastery.AddMasteryPath(id, mastery_ids)
	assert(Mastery.Paths[id] == nil, ("Mastery Path with ID [%s] already exists!"):format(id))
	Mastery.Paths[id] = mastery_ids or {}
end

-- ... Or, you can create the path by adding masteries one at a time. The path will progress in the order that they are created.
function Mastery.AddMasteryToPath(id, mastery_id)
	assert(Mastery.Paths[id] ~= nil, ("Tried to add to invalid Mastery Path [%s]"):format(id))
	table.insert(Mastery.Paths[id], mastery_id)
end

function Mastery.GetMasteryPath(id)
	return Mastery.Paths[id]
end

return Mastery

-- MASTERY IDEAS:

-- General, applicable to any mob
-- Perfect Dodge an attack from [mob]
-- Kill a [mob] using a trap
-- Do an x-hit combo on [mob]
-- Land a critical hit on [mob]
-- Knockdown [mob]

-- Do X in a single run