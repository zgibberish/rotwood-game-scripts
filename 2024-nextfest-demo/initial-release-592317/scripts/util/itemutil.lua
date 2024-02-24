local itemutil = {}

local Consumable = require "defs.consumable"
local Equipment = require("defs.equipment")
local EquipmentStatDisplay = require "defs.equipmentstatdisplay"

local lume = require"util/lume"

local DISPLAY_STATS_PER_SLOT =
{
	[Equipment.Slots.WEAPON] = { EQUIPMENT_STATS.s.DMG, EQUIPMENT_STATS.s.WEIGHT },
	[Equipment.Slots.HEAD] = { EQUIPMENT_STATS.s.ARMOUR, EQUIPMENT_STATS.s.WEIGHT },
	[Equipment.Slots.BODY] = { EQUIPMENT_STATS.s.ARMOUR, EQUIPMENT_STATS.s.WEIGHT },
	[Equipment.Slots.WAIST] = { EQUIPMENT_STATS.s.ARMOUR, EQUIPMENT_STATS.s.WEIGHT },
}

function itemutil.BuildStatsTable(delta, stats, slot)
	-- build a stats table that includes all stats that have changed
	local data = {}
	for i, stat in ipairs(EQUIPMENT_STATS:Ordered()) do
		if delta[stat] or stats[stat] then
			if DISPLAY_STATS_PER_SLOT[slot] == nil or table.contains(DISPLAY_STATS_PER_SLOT[slot], stat) then
				table.insert(data,
				{
					stat = stat,
					icon = EquipmentStatDisplay[stat].icon,
					value = (EquipmentStatDisplay[stat].default or 0) + (stats[stat] or 0),
					delta = delta[stat] or 0,
				})
			end
		end
	end
	return data
end

function itemutil.CollectItemDropsForBiome(biome, elite_monsters, elite_miniboss, elite_boss)
	-- global drops
	local global_drops = Consumable.GetItemList(Consumable.Slots.MATERIALS, { LOOT_TAGS.GLOBAL, "drops_generic" })

	-- biome drops
	local biome_drops = Consumable.GetItemList(Consumable.Slots.MATERIALS, { LOOT_TAGS.BIOME, "drops_"..biome.region_id })

	local bosses = shallowcopy(biome.monsters.bosses)
	local minibosses = shallowcopy(biome.monsters.minibosses)
	local mobs = shallowcopy(biome.monsters.mobs)
	mobs = lume.filter(mobs, function(mob) return not lume.find(minibosses, mob) end)

	local monster_drops = {}

	for i, name in ipairs(mobs) do
		monster_drops = lume.concat(monster_drops, Consumable.GetItemList(Consumable.Slots.MATERIALS, { LOOT_TAGS.NORMAL, "drops_"..name }))
		if elite_monsters then
			monster_drops = lume.concat(monster_drops, Consumable.GetItemList(Consumable.Slots.MATERIALS, { LOOT_TAGS.ELITE, "drops_"..name }))
		end
	end

	for i, name in ipairs(minibosses) do
		monster_drops = lume.concat(monster_drops, Consumable.GetItemList(Consumable.Slots.MATERIALS, { LOOT_TAGS.NORMAL, "drops_"..name }))
		if elite_miniboss then
			monster_drops = lume.concat(monster_drops, Consumable.GetItemList(Consumable.Slots.MATERIALS, { LOOT_TAGS.ELITE, "drops_"..name }))
		end
	end

	for i, name in ipairs(bosses) do
		monster_drops = lume.concat(monster_drops, Consumable.GetItemList(Consumable.Slots.MATERIALS, { LOOT_TAGS.NORMAL, "drops_"..name }))
		if elite_boss then
			monster_drops = lume.concat(monster_drops, Consumable.GetItemList(Consumable.Slots.MATERIALS, { LOOT_TAGS.ELITE, "drops_"..name }))
		end
	end

	monster_drops = lume.unique(monster_drops)
	biome_drops = lume.unique(biome_drops)
	global_drops = lume.unique(global_drops)

	return monster_drops, biome_drops, global_drops
end

function itemutil.GetOrderedArmourSlots()
	return {
		Equipment.Slots.HEAD,
		Equipment.Slots.BODY,
		Equipment.Slots.WAIST
	}
end

function itemutil.GetArmourForMonster(monster_id)
	local armour_slots = itemutil.GetOrderedArmourSlots()
	local armour_pieces = {}

	for slot, items in pairs(Equipment.Items) do
		if table.contains(armour_slots, slot) then
			for name, def in pairs(items) do
				if name == monster_id and not def.tags.hide then
					armour_pieces[slot] = def
				end
			end
		end
	end

	return armour_pieces
end

function itemutil.GetBiomeArmourSets(biome)
	local mobs_with_armour = {}

	local monsterutil = require "util/monsterutil"
	local mobs = monsterutil.GetMonstersInRegion(biome)

	-- Hacky way to get the "basic" armour set to be in the forest biome menu
	if biome.id == "forest" then
		table.insert(mobs, 1, "basic")
	end

	for i, monster_id in ipairs(mobs) do
		local armour = itemutil.GetArmourForMonster(monster_id)
		if next(armour) then
			table.insert(mobs_with_armour, monster_id)
		end
	end

	return mobs_with_armour
end

function itemutil.GetLocationArmourSets(location)
	local mobs_with_armour = {}

	local monsterutil = require "util/monsterutil"
	local mobs = monsterutil.GetMonstersInLocation(location)

	-- Hacky way to get the "basic" armour set to be in the forest biome menu
	if location.id == "treemon_forest" then
		table.insert(mobs, 1, "basic")
	end

	for i, monster_id in ipairs(mobs) do
		local armour = itemutil.GetArmourForMonster(monster_id)
		if next(armour) then
			local valid = false
			for slot,piece in pairs(armour) do
				if piece.crafting_data and piece.crafting_data.craftable_location then
					if table.contains(piece.crafting_data.craftable_location, location.id) then
						valid = true
						break
					end
				end
			end

			if valid then
				table.insert(mobs_with_armour, monster_id)
			end
		end
	end

	return mobs_with_armour
end

return itemutil
