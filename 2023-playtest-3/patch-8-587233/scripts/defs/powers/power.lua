local Enum = require "util.enum"
local kassert = require "util.kassert"
local krandom = require "util.krandom"
local kstring = require "util.kstring"
local lume = require "util.lume"
local missinglist = require "util.missinglist"
local power_icons = require "gen.atlas.ui_ftf_power_icons"
local skill_icons = require "gen.atlas.ui_ftf_skill_icons"
local food_icons = require "gen.atlas.ui_ftf_food_icons"
local slotutil = require "defs.slotutil"
require "class"
require "strings.strings"

local Power = {
	Items = {},
	Slots = {},
	SlotDescriptor = {},
	MaxCount = {},
}

Power.Types = MakeEnum{ "RELIC", "FABLED_RELIC", "SKILL", "MOVEMENT", "FOOD", "EQUIPMENT", "HEART" }
Power.Categories = MakeEnum{"ALL", "SUPPORT", "DAMAGE", "SUSTAIN"}
Power.Rarities = Enum{"COMMON", "EPIC", "LEGENDARY"}
Power.Rarity = Power.Rarities.s
Power.RarityIdx = Power.Rarities:Ordered()
Power.MaxPerSlotDefault = 4

Power.POWER_AS_TOOLTIP_FMT = "<#RED>{name}</>\n{desc}"

local ordered_slots = {}

local SLOT_TO_ATLAS =
{
	["SKILL"] = skill_icons,
	["FOOD_POWER"] = food_icons,
}

local function GetIcon(power_id, slot, build)
	-- power icon name format: icon_[symbol]_[build]
	local icon_name = ("icon_%s_%s"):format(build, power_id)
	if not build then
		icon_name = ("icon_%s"):format(power_id)
	end

	local atlas = SLOT_TO_ATLAS[slot] or power_icons
	local icon = atlas.tex[icon_name]

	if not icon then
		missinglist.AddMissingItem("Power", power_id, ("Missing '%s' icon for '%s'.\t\tExpected tex: %s.tex"):format(power_id, build, icon_name))
		icon = "images/icons_ftf/item_temp.tex"
	end

	return icon
end

-- Created by PowerManager and passed as 'pow' within powers.
Power.PowerInstance = Class(function(self, power)
	self.persistdata = power -- an ItemInstance
	self.def = power:GetDef()
	self.mem = {}
end)

function Power.PowerInstance:StartPowerTimer(inst, timer_name, var_name)
	timer_name = timer_name or self.def.name
	var_name = var_name or "time"
	local force = true
	inst.components.timer:StartTimer(timer_name, self.persistdata:GetVar(var_name), force)
end

function Power.PowerInstance:GetVar(var)
	return self.persistdata:GetVar(var)
end

function Power.CollectAssets(tbl)
	for _, slot in pairs(Power.Items) do
		for name, def in pairs(slot) do
			if def.assets then
				for _, asset in ipairs(def.assets) do
					table.insert(tbl, asset)
				end
			end
		end
	end
end

function Power.CollectPrefabs(tbl)
	for _, slot in pairs(Power.Items) do
		for name, def in pairs(slot) do
			if def.prefabs then
				for _, prefab in ipairs(def.prefabs) do
					table.insert(tbl, prefab)
				end
			end
		end
	end
end

function Power.AddPowerFamily(slot, tags, max_count)
	max_count = max_count or Power.MaxPerSlotDefault
	slotutil.AddSlot(Power, slot, tags, max_count)
	table.insert(ordered_slots, slot)
end

function Power.AddPower(slot, name, build, data)
	local items = Power.Items[slot]
	assert(items ~= nil and items[name] == nil, "Nonexistent slot " .. slot)

	local def = {
		name = name,
		slot = slot,
		icon = data.icon or GetIcon(name, slot, build),
		pretty = data.pretty or slotutil.GetPrettyStrings(slot, name),
		tuning = data.tuning or { [Power.Rarity.COMMON] = {} },
		-- Used both as organizational tags (for querying power defs) and tags
		-- applied to the entity! Added to the entity while the power is active.
		tags = data.tags or {},
		required_tags = data.required_tags, -- if the player DOESN'T HAVE ALL of these tags the power won't drop
		exclusive_tags = data.exclusive_tags, -- if the player HAS ANY of these tags this power won't drop
		prefabs = data.prefabs,
		assets = data.assets,
		power_type = data.power_type,
		power_category = data.power_category,
		is_ready_fn = data.is_ready_fn,
		on_update_fn = data.on_update_fn,
		on_add_fn = data.on_add_fn,
		on_remove_fn = data.on_remove_fn,
		on_stacks_changed_fn = data.on_stacks_changed_fn,
		damage_mod_fn = data.damage_mod_fn,
		defend_mod_fn = data.defend_mod_fn,
		heal_mod_fn = data.heal_mod_fn,
		prerequisite_fn = data.prerequisite_fn,
		description_fn = data.description_fn,
		event_triggers = data.event_triggers or {},
		remote_event_triggers = data.remote_event_triggers or {},
		stackable = data.stackable,
		works_on_nonalive = data.works_on_nonalive,
		reset_on_stack = data.reset_on_stack,
		starting_stacks = data.starting_stacks,
		max_stacks = data.max_stacks or 999,
		stacks_per_usage_level = data.stacks_per_usage_level or nil, -- equipment uses this
		permanent = data.permanent or false,
		can_drop = true,
		show_in_ui = true,
		selectable = true,
		upgradeable = true,
		attack_fx_mods = data.attack_fx_mods,
		tooltips = data.tooltips or {},
		has_sources = data.has_sources,
		minimum_player_count = data.minimum_player_count or 1,
		maximum_player_count = data.maximum_player_count or 4,
		get_counter_text = data.get_counter_text,
		on_net_serialize_fn = data.on_net_serialize_fn,			-- on_net_serialize_fn(entity)
		on_net_deserialize_fn = data.on_net_deserialize_fn,		-- on_net_deserialize_fn(entity)
	}

	dbassert(slotutil.ValidateAllTooltipsExist(def))

	if data.show_in_ui ~= nil then
		def.show_in_ui = data.show_in_ui
	end

	if data.selectable ~= nil then
		def.selectable = data.selectable
	end

	if data.upgradeable ~= nil then
		def.upgradeable = data.upgradeable
	end

	if data.can_drop ~= nil then
		def.can_drop = data.can_drop
	end

	items[name] = def
	return def
end

function Power.GetRandomPowers(count, families)
	local picks = krandom.PickSome(count, lume.keys(families))
	local picked_powers = {}
	for _,key in ipairs(picks) do
		table.insert(picked_powers, families[key])
	end
	return picked_powers
end

function Power.GetQualifiedNames()
	local t = {}
	local fmt = "pwr_%s"
	for slot_name, slot in pairs(Power.Items) do
		for name, def in pairs(slot) do
			table.insert(t, fmt:format(name))
		end
	end
	return t
end

function Power.GetQualifiedNamesToPrettyString()
	local t = {}
	local fmt = "pwr_%s"
	for slot_name, slot in pairs(Power.Items) do
		for name, def in pairs(slot) do
			if def.pretty then
				t[fmt:format(name)] = def.pretty.name
			end
		end
	end
	return t
end

function Power.FindPowerByQualifiedName(qualified_name)
	local power_name = qualified_name:match("^pwr_(%S+)$")
	kassert.assert_fmt(power_name, "Invalid power '%s'", qualified_name)
	for _, slot in pairs(Power.Items) do
		for name, def in pairs(slot) do
			if power_name == name then
				return def
			end
		end
	end
	error("Invalid power name: ".. qualified_name)
end

function Power.FindPowerByName(power_name)
	for _, slot in pairs(Power.Items) do
		for name, def in pairs(slot) do
			if power_name == name then
				return def
			end
		end
	end
	error("Invalid power name: ".. power_name)
end

function Power.FindPowerBySlotAndName(slot, power_name)
	if Power.Items[slot] then
		if Power.Items[slot][power_name] ~= nil then
			return Power.Items[slot][power_name]
		end
		error("Invalid power name: ".. power_name)
	end
	error("Invalid power slot: " .. slot)
end

function Power.GetOrderedSlots()
	return ordered_slots
end

function Power.GetItemList(slot, tags)
	return slotutil.GetOrderedItemsWithTag(Power.Items[slot], tags)
end

function Power.GetDescForPower(power)
	local def = power:GetDef()
	local tuning = power:GetTuning()
	local desc = kstring.subfmt(def.pretty.desc, tuning)
	return kstring.subfmt("{desc}", {desc = desc})
end

function Power.GetAllPowerNames(tbl)
	for _, slot in pairs(Power.Items) do
		for name, def in pairs(slot) do
			table.insert(tbl, name)
		end
	end
end

function Power.GetAllPowers()
	local powers = {}
	for _, slot in pairs(Power.Items) do
		for name, def in pairs(slot) do
			table.insert(powers, def)
		end
	end
	return powers
end

function Power.GetAllPowersOfFamily(family)
	local powers = {}
	for _, def in pairs(Power.Items[family]) do
		table.insert(powers, def)
	end
	return powers
end

function Power.GetBaseRarity(def)
	-- return the lowest rarity tuning for this power
	for i, rarity in ipairs(Power.RarityIdx) do
		if def.tuning[rarity] then
			return rarity
		end
	end
end

function Power.GetNextRarity(power)
	local current_rarity = power:GetRarity()
	local idx = lume.find(Power.RarityIdx, current_rarity)
	local def = power:GetDef()

	for i = idx + 1, #Power.RarityIdx do
		if def.tuning[Power.RarityIdx[i]] ~= nil then
			return Power.RarityIdx[i]
		end
	end
end

function Power.GetUpgradePrice(power)
	if not Power.GetNextRarity(power) then return nil end

	local rarity = power:GetRarity()
	return TUNING.POWERS.UPGRADE_PRICE[rarity]
end

function Power.GetRarityAsParameter(power)
	return lume.find(Power.RarityIdx, power:GetRarity())
end

-- Validation
for _,power_type in pairs(Power.Types) do
	assert(STRINGS.POWERS.POWER_TYPE[power_type], "STRINGS.POWERS.POWER_TYPE not found: "..power_type)
end
for _,power_category in pairs(Power.Categories) do
	assert(STRINGS.POWERS.POWER_CATEGORY[power_category])
end
for _,power_rarity in pairs(Power.Rarity) do
	assert(STRINGS.POWERS.POWER_RARITY[power_rarity])
end

return Power
