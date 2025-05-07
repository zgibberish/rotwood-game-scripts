local Equipment = require("defs.equipment")
local Power = require("defs.powers")
local itemcatalog = require "defs.itemcatalog"
local kassert = require "util.kassert"
local kstring = require "util.kstring"
local lume = require "util.lume"
local Biomes = require "defs.biomes"
local SceneGenAutogenData = require "prefabs.scenegen_autogen_data"
local Weight = require "components/weight"
local EquipmentStatDisplay = require "defs.equipmentstatdisplay"
require "class"

local printdebug = false

local function DebugPrint(str)
	if printdebug then
		print(str)
	end
end

local function DebugPrintStats(stats)
	if printdebug then
		DebugPrint("-- Stats total:")
		for stat,val in pairs(stats) do
			DebugPrint("-- -- ["..stat.."]: "..val)
		end
		DebugPrint("")
	end
end

-- Creates instances of items.
local itemforge = {}

local ItemInstance = {}

-- Definition of a specific item.
function ItemInstance:GetDef()
	local id = self.id
	local slot = self.slot
	local group = itemcatalog.All.Items[slot]
	local str = ("itemdef: Category missing in itemcatalog.lua: itemcatalog.All.Items.%s.%s"):format(slot, id)
	--~ print(str)
	local data = group and group[id]
	assert(data, str)
	return data
end

-- Definition of a category of item (i.e., all head items share the same common data).
function ItemInstance:GetCommon()
	local common = itemcatalog.All.SlotDescriptor[self.slot]
	assert(common, ("Bad itemdef: itemcatalog.All.SlotDescriptor.%s"):format(self.slot))
	return common
end

function ItemInstance:GetUsageData()
	local def = self:GetDef()
	return def.usage_data
end

function ItemInstance:GetFXType()
	local def = self:GetDef()
	return def.fx_type
end

function ItemInstance:ActivateLifetime()
	local def = self:GetDef()
	self.lifetime = def.stats.lifetime
end

function ItemInstance:DecreaseLifetime(amt)
	if not self.lifetime then
		return
	end

	amt = amt or 1
	self.lifetime = self.lifetime - amt
end

function ItemInstance:GetLifetime()
	return self.lifetime
end

function ItemInstance:GetItemLevel()
	return self.ilvl or 1
end

function ItemInstance:GetUsageLevel()
	return self.usagelvl or 1
end

function ItemInstance:SetItemLevel(level)
	self.ilvl = level
	self:RefreshItemStats()
end

function ItemInstance:SetUsageLevel(level)
	self.usagelvl = level
	self:RefreshItemStats()
end

function ItemInstance:UpgradeUsageLevel()
	if not self.usagelvl then
		self.usagelvl = 1
	end

	self:SetUsageLevel(self.usagelvl + 1)
end

function ItemInstance:UpgradeItemLevel()
	self:SetItemLevel(self.ilvl + 1)
end

function ItemInstance:GetMaxItemLevel()
	local def = self:GetDef()
	if def and def.usage_data and def.usage_data.power_on_equip then
		local power_def = Power.FindPowerByName(def.usage_data.power_on_equip)
		if power_def.stacks_per_usage_level then
			return #power_def.stacks_per_usage_level
		end
	end
	return 1
end

function ItemInstance:GetMaxUsageLevel()
	local def = self:GetDef()
	if def and def.usage_data and def.usage_data.power_on_equip then
		local power_def = Power.FindPowerByName(def.usage_data.power_on_equip)
		if power_def.stacks_per_usage_level then
			return #power_def.stacks_per_usage_level
		end
	end
	return 1
end

-- Computes the item's stats. They're always dependent on the base def's stats
-- plus modifiers from upgrades to the weapon.
function ItemInstance:GetStats()
	if not self.stats then
		self:RefreshItemStats()
	end
	dbassert(self.stats ~= nil, "RefreshItemStats always returns a valid table")
	return lume.clone(self.stats)
end

-- Difference is self minus other. To compare how stats change after switching
-- from a to b, use b:DiffStats(a).
function ItemInstance:DiffStats(other)
	local s_self = self:GetStats()
	if not other then
		return s_self, s_self
	end
	local s_other = other:GetStats()
	local delta = {}
	for _, stat in ipairs(EQUIPMENT_STATS:Ordered()) do
		if s_self[stat] or s_other[stat] then
			delta[stat] = (s_self[stat] or 0) - (s_other[stat] or 0)
		end
	end
	return delta, s_self
end

function ItemInstance:InverseStats()
	local s_self = self:GetStats()
	local delta = {}
	for stat,val in pairs(s_self) do
		delta[stat] = -val
	end
	return delta, s_self
end

function ItemInstance:GetLocalizedName()
	return self:GetDef().pretty.name
end

function ItemInstance:GetLocalizedDescription()
	local def = self:GetDef()
	local desc = def.pretty.desc
	local stats = def.stats
	local usage_data = def.usage_data

	if stats and next(stats) then
		desc = kstring.subfmt(desc, stats)
	end

	if usage_data and next(usage_data) then
		desc = kstring.subfmt(desc, usage_data)
	end

	-- if def.weapon_type then
	-- 	desc = desc..string.format("\n<z 1>%s</z>", STRINGS.WEAPONS.FOCUS_HIT[def.weapon_type])
	-- end

	return desc
end

function ItemInstance:GetStatsString()
	if not self.stats then return "" end
	local str = ""
	for i, stat in ipairs(EQUIPMENT_STATS:Ordered()) do
		local val = self.stats[stat]
		local colour = "LIGHT_TEXT"
		local symbol = "+"
		local percentage = ""
		if val then
			if EquipmentStatDisplay[stat] and EquipmentStatDisplay[stat].percent then
				percentage = "%"
				val = val * 100
			end
			if val < 0 then
				colour = "PENALTY"
				symbol = ""
			end
			str = str..string.format("\n%s <#%s>%s%s%s</> %s", STRINGS.UI.BULLET_POINT, colour, symbol, val, percentage, STRINGS.UI.EQUIPMENT_STATS[stat])
		end
	end
	return str
end

function ItemInstance:GetTuning()
	local rarity = self:GetRarity()
	assert(rarity ~= nil, "Invalid Rarity on Item")
	local def = self:GetDef()
	local tuning = shallowcopy(def.tuning[rarity])
	assert(tuning ~= nil, "No Tuning for Rarity on Item")

	for name, val in pairs(tuning) do
		if PowerVariable.is_instance(val) then
			tuning[name] = val:GetValue(self)
		end
	end

	return tuning
end

function ItemInstance:GetVar(var)
	local tuning = self:GetTuning()
	return tuning[var]
end

function ItemInstance:GetPrettyTuning()
	local rarity = self:GetRarity()
	assert(rarity ~= nil, "Invalid Rarity on Item")
	local def = self:GetDef()
	local tuning = shallowcopy(def.tuning[rarity])
	assert(tuning ~= nil, "No Tuning for Rarity on Item")

	for name, val in pairs(tuning) do
		if PowerVariable.is_instance(val) then
			tuning[name] = val:GetPretty(self)
		end
	end

	return tuning
end

local power_var_remap = {
	-- Use the same name as name.powerdesc to avoid updating this table. If you
	-- want powerdesc_damage_bonus, name your variable damagebonus.
	critchance_bonus              = "powerdesc_critchance",
	damage_mult_of_blocked_attack = "powerdesc_damage_bonus",
	boss_damage_reduction         = "powerdesc_damage_reduction",
	miniboss_damage_reduction     = "powerdesc_damage_reduction",
	projectile_damage_reduction   = "powerdesc_damage_reduction",
	trap_damage_reduction         = "powerdesc_damage_reduction",
	heal_percent                  = "powerdesc_heal_bonus",
	percent_extra_iframes         = "powerdesc_invincibilityduration",
	konjur                        = "powerdesc_konjur_bonus",
	health                        = "powerdesc_maxhealth",
	pull_factor                   = "powerdesc_pullstrength",
	speed_bonus_per_second        = "powerdesc_speed_bonus",
	damage_mod                    = "powerdesc_weapon_damage_bonus",
}
local function GetStandardPowerDescVarPrettyName(var)
	local key = power_var_remap[var] or "powerdesc_".. var
	return STRINGS.NAMES[key]
end

function ItemInstance:GetPrettyVar(var)
	local def = self:GetDef()
	local name = def.pretty.variables and def.pretty.variables[var] or GetStandardPowerDescVarPrettyName(var)

	local tuning = self:GetPrettyTuning()
	return name, tuning[var]
end

function ItemInstance:GetRarity()
	return self.rarity
end

function ItemInstance:SetRarity(rarity)
	self.rarity = rarity
end

function ItemInstance:HasTag(tag)
	return self:GetDef().tags[tag]
end

local function _AddStatsForGem(gem, stats)
	if not gem then
		return
	end

	-- If there's a Gem in that slot, apply its bonuses.
	local def = gem:GetDef()

	-- Stat Mods
	-- local function _ApplyStatMods(item, gem)
	if def.stat_mods then
		for stat, data in pairs(def.stat_mods) do
			local mod = data[gem.ilvl]
			if stats[stat] then
				stats[stat] = stats[stat] + mod
			else
				stats[stat] = mod
			end
		end
	end

	-- Stat Mults
	-- local function _ApplyStatMults(item, gem)
	if def.stat_mults then
		for stat, data in pairs(def.stat_mults) do
			local mult = data[gem.ilvl]
			local bonus = stats[stat] * mult
			stats[stat] = stats[stat] + bonus
		end
	end
end

local function _AddStatsForEquipmentGems(item)
	if item.gem_slots then
		-- print("Stats for this item:")
		-- dumptable(item.stats)

		-- Check each slot for a gem.
		for _, slot in pairs(item.gem_slots) do
			_AddStatsForGem(slot.gem, item.stats)
		end

		-- print("Stats AFTER for this item:")
		-- dumptable(item.stats)
	end
	return item.stats
end

function ItemInstance:RefreshItemStats()
	-- If self.stats has not yet been cached, cache it.
	local def = self:GetDef()
		if def.stats then
			self.stats = def.stats -- Has hard-coded stats.
		elseif self.slot == Equipment.Slots.WEAPON then
			self.stats = self:MakeWeaponStats()
		elseif self.slot == Equipment.Slots.ARMOUR
			or self.slot == Equipment.Slots.BODY
			or self.slot == Equipment.Slots.HEAD
			or self.slot == Equipment.Slots.WAIST
		then
			self.stats = self:MakeArmourStats()
		else
			self.stats = {} -- doesn't have stats
		end
	self.stats = _AddStatsForEquipmentGems(self)
end

function ItemInstance:MakeWeaponStats()
	dbassert(self.slot == Equipment.Slots.WEAPON)
	local def = self:GetDef()
	local base_weapon = TUNING.GEAR.WEAPONS[def.weapon_type]
	local weapon_modifiers = TUNING:GetWeaponModifiers(def.weapon_type, self.ilvl, def.weight, def.rarity)

	return {
		[EQUIPMENT_STATS.s.DMG] = base_weapon.BASE_DAMAGE * weapon_modifiers.DamageMult,
		[EQUIPMENT_STATS.s.CRIT] = base_weapon.BASE_CRIT + weapon_modifiers.CritChance,
		[EQUIPMENT_STATS.s.CRIT_MULT] = weapon_modifiers.CritDamageMult,
		[EQUIPMENT_STATS.s.FOCUS_MULT] = weapon_modifiers.FocusMult,
		[EQUIPMENT_STATS.s.SPEED] = weapon_modifiers.SpeedMult,
		[EQUIPMENT_STATS.s.WEIGHT] = Weight.EquipmentWeight_to_WeightMod[def.weight],
		AMMO = base_weapon.AMMO and math.ceil(base_weapon.AMMO * weapon_modifiers.AmmoMult) or 0,
	}
end

function ItemInstance:MakeArmourStats()
	dbassert(self.slot == Equipment.Slots.ARMOUR
		or self.slot == Equipment.Slots.BODY
		or self.slot == Equipment.Slots.HEAD
		or self.slot == Equipment.Slots.WAIST
	)
	local def = self:GetDef()
	local armour_modifiers = TUNING:GetArmourModifiers(self.ilvl, def.weight, def.rarity)
	local slot_multiplier = TUNING.GEAR.STAT_ALLOCATION_PER_SLOT[self.slot]
	return {
		[EQUIPMENT_STATS.s.ARMOUR] = lume.round(armour_modifiers.DungeonTierDamageReductionMult * slot_multiplier, 0.005), -- Round to nearest 0.5 for reliable presentation.
		[EQUIPMENT_STATS.s.WEIGHT] = Weight.EquipmentWeight_to_WeightMod[def.weight],
	}
end

local ItemInstance_mt = {
	__index = ItemInstance,
}

-- Functions for save/load
function itemforge.ConvertToListOfSaveableItems(list)
	for key,val in pairs(list) do
		setmetatable(val, nil)
	end
end
function itemforge.ConvertToListOfRuntimeItems(list)
	for key,val in pairs(list) do
		setmetatable(val, ItemInstance_mt)
	end
end
function itemforge.ConvertToSaveableItem(item)
	setmetatable(item, nil)
end
function itemforge.ConvertToRuntimeItem(item)
	setmetatable(item, ItemInstance_mt)
end
-- /end Functions for save/load

-- Create an item instance that can be passed to GetDef and GetCommon.
function itemforge._CreateItem(slot, def)
	local item = {}

	item.id = def.name
	item.slot = slot
	-- A bit of magic to add functions but keep the table pure data -- add a
	-- metatable that lets us call ItemInstance functions directly on the item
	-- table.
	setmetatable(item, ItemInstance_mt)
	return item, def
end

-------- Equipment Helpers --------

function itemforge.GetILvl(def)
	local location = def.crafting_data
		and def.crafting_data.craftable_location ~= nil
		and def.crafting_data.craftable_location[1]
	if not location then
		return 1
	end
	location = Biomes.locations[location]
	local scene_gen = location:GetSceneGen()
	scene_gen = SceneGenAutogenData[scene_gen]

	return math.floor(scene_gen.tier)
end

function itemforge.CreateEquipment(slot, def)
	local item,data = itemforge._CreateItem(slot, def)

	if not def.tags["food"] then
			item.ilvl = itemforge.GetILvl(def)

		if def.usage_data then
			item.usagelvl = 1
		end

		if def.gem_slots ~= nil then
			-- For gem slots, order matters (because some slots are linked)
			-- Slots can have nothing equipped in them.
			-- Slot 5 can have something while slots 1-4 are empty.

			item.gem_slots = {}
			for i,slot_type in ipairs(def.gem_slots) do
				item.gem_slots[i] = { slot_type = slot_type, gem = nil } -- When equipping a Gem, check to see if the slot_type matches the gem_type. If so, gem = that_gem.
			end
		end
	end

	item:RefreshItemStats()

	return item
end

function itemforge.CreateAllEquipmentWithTags(tags)
	local equipment = {}
	for _,slot in pairs(Equipment.GetOrderedSlots()) do
		for i,def in ipairs(Equipment.GetItemList(slot, tags)) do
			local item_instance = itemforge.CreateEquipment(slot, def)
			table.insert(equipment, item_instance)
		end
	end
	return equipment
end

function itemforge.GetWeaponsAndArmour()
	-- Return a list of all weapons and armour, and their stats.
	-- Use for debug purposes.

	local relevant_slots =
	{
		"WEAPON",
		"ARMS",
		"BODY",
		"HEAD",
		"LEGS",
		"SHOULDERS",
		"WAIST",
	}

	local equipment = {}
	for i, item in ipairs(itemforge.CreateAllEquipmentWithTags()) do
		if not item:GetDef().tags["hide"] then
			if not item:GetDef().stackable then
				if table.contains(relevant_slots, item.slot) then
					table.insert(equipment, item)
				end
			end
		end
	end
	return equipment
end

function itemforge.GetItemDefsBySlot(slot)
	-- Return a list of all items of a given slot.

	local equipment = {}
	for i, item in ipairs(itemforge.CreateAllEquipmentWithTags()) do
		if not item:GetDef().tags["hide"] then
			if not item:GetDef().stackable then
				if slot == item.slot then
					table.insert(equipment, item:GetDef())
				end
			end
		end
	end
	return equipment
end

function itemforge.SortItemsByStat(stat, a, b)
	local a_stats = a:GetStats()
	local b_stats = b:GetStats()

	local a_stat = a_stats[stat] or 0
	local b_stat = b_stats[stat] or 0

	if a_stat == b_stat then

		local a_def = a:GetDef()
		local b_def = b:GetDef()

		local a_rarity = ITEM_RARITY.id[a_def.rarity]
		local b_rarity = ITEM_RARITY.id[b_def.rarity]

		if a_rarity == b_rarity then
			if a.ilvl == b.ilvl then
				return a_def.pretty.name < b_def.pretty.name
			else
				return a.ilvl > b.ilvl
			end
		else
			return a_rarity > b_rarity
		end
	end

	return a_stat > b_stat
end

function itemforge.SortItemsByILvl(a, b)
	local a_ilvl = a.ilvl or 1
	local b_ilvl = b.ilvl or 1

	if a_ilvl == b_ilvl then
		-- If ilvl is the same, then sort by rarity.
		-- If rarity is the same, return alphabetical.

		local a_def = a:GetDef()
		local b_def = b:GetDef()

		local a_rarity = ITEM_RARITY.id[a_def.rarity]
		local b_rarity = ITEM_RARITY.id[b_def.rarity]

		if a_rarity == b_rarity then
			if a.ilvl == b.ilvl then
				return a_def.pretty.name < b_def.pretty.name
			else
				return a.ilvl > b.ilvl
			end
		else
			return a_rarity > b_rarity
		end
	end

	return a_ilvl > b_ilvl
end

-------- Consumable Helpers --------

function itemforge.CreateStack(slot, def)
	local item,data = itemforge._CreateItem(slot, def)
	item.count = 0
	item.is_consumable = true

	if def.rarity then
		item:SetRarity(def.rarity)
	end

	if def.ilvl then
		item.ilvl = def.ilvl or 1
	end

	if def.stats then
		item:RefreshItemStats()
	end

	return item
end

function itemforge.SortItemsBySource(a, b)
	local a_def = a:GetDef()
	local b_def = b:GetDef()

	local a_source = a_def.source
	local b_source = b_def.source

	if a_source == b_source then

		local a_rarity = ITEM_RARITY.id[a_def.rarity]
		local b_rarity = ITEM_RARITY.id[b_def.rarity]

		if a_rarity == b_rarity then
			if a.ilvl == b.ilvl then
				return a_def.pretty.name < b_def.pretty.name
			else
				return a.ilvl > b.ilvl
			end
		else
			return a_rarity > b_rarity
		end
	end

	return a_source < b_source
end

-------- Key Item Helpers --------

function itemforge.CreateKeyItem(def)
	local slot = def.slot
	local item,data = itemforge._CreateItem(slot, def)
	return item
end

-------- Craftable Helpers --------

function itemforge.CreateCraftable(def)
	local slot = def.slot
	local item,data = itemforge._CreateItem(slot, def)
	return item
end

function itemforge.GetAllCraftableItems()
	local craftables = {}
	for group_name,group in pairs(itemcatalog.All.Items) do
		for item_name,item in pairs(group) do
			if item.tags.playercraftable then
				craftables[item_name] = item
			end
		end
	end
	return craftables
end

-------- MetaProgress Helpers --------

function itemforge.CreateMetaProgress(def)
	local slot = def.slot
	local item, data = itemforge._CreateItem(slot, def)

	item.level = 0 -- we want to save level so even if we change the exp curve a player will never lose levels
	item.exp = 0

	return item
end

-------- Power Helpers --------

function itemforge.CreatePower(def, rarity, stacks)
	local slot = def.slot
	local power = itemforge._CreateItem(slot, def)
	power:SetRarity(rarity or Power.GetBaseRarity(def))

	if stacks ~= nil then
		power.stacks = stacks
	end

	return power
end

--------  --------

return itemforge
