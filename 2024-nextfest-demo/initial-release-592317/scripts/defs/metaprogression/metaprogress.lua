local lume = require "util.lume"
local slotutil = require "defs.slotutil"
require "class"

local MetaProgress = {
	Slots = {},
	SlotDescriptor = {},
	Items = {},
}

function MetaProgress.AddProgressionType(slot, tags)
	slotutil.AddSlot(MetaProgress, slot, tags)
end

function MetaProgress.AddProgression(slot, name, data)
	local items = MetaProgress.Items[slot]
	assert(items ~= nil and items[name] == nil, "Nonexistent slot " .. slot)

	local def = {
		name = name,
		slot = slot,
		tags = data.tags or {},
		pretty = slotutil.GetPrettyStrings(slot, name),

		hide = data.hide or false,

		-- leveling stats
		-- a hand-designed table of exp needed for each level.
		base_exp = data.base_exp or { 50, 100, 200, 300 },
		-- after the base_exp table is exshausted, exp for the level will be equal to
		-- base_exp[#base_exp] * (1 + exp_growth) ^ (level - #base_exp)
		exp_growth = data.exp_growth or 0.05,

		-- reward data
		rewards = data.rewards or {},
	}

	for k, v in pairs(data) do
		if not def[k] then
			def[k] = v
		end
	end

	items[name] = def

	return def
end

function MetaProgress.FindProgressByName(progress_name)
	for _, slot in pairs(MetaProgress.Items) do
		for name, def in pairs(slot) do
			if progress_name == name then
				return def
			end
		end
	end
	error("Invalid progress name: ".. progress_name)
end

function MetaProgress.GetEXPForLevel(def, level)
	if def.base_exp[level + 1] then
		return def.base_exp[level + 1]
	end

	local last_defined_level = #def.base_exp - 1
	local base = def.base_exp[#def.base_exp]
	return math.floor(base * (1 + def.exp_growth) ^ (level - last_defined_level))
end

function MetaProgress.GetRewardForLevel(def, level)
	if level == 0 then
		return nil
	end

	if level >= #def.rewards and def.endless_reward then
		-- We've leveled past our designed rewards -- give a repeatedable endless reward
		return def.endless_reward
	else
		return def.rewards[level]
	end

end

-- Validation

return MetaProgress