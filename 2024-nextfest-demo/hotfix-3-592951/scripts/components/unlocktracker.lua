require "util"

local itemcatalog = require"defs.itemcatalog"
local biomes = require"defs.biomes"
local MetaProgress = require"defs.metaprogression"

local lume = require "util.lume"
local itemutil = require"util.itemutil"

local Cosmetics = require "defs.cosmetics.cosmetics"
local Power = require"defs.powers"



-- defaultunlocks.lua for powers
-- default_unlocked tag for equipment
local function create_default_data()
	local data =
	{
		[UNLOCKABLE_CATEGORIES.s.RECIPE] = {},
		[UNLOCKABLE_CATEGORIES.s.ENEMY] = {},
		[UNLOCKABLE_CATEGORIES.s.CONSUMABLE] = {},
		[UNLOCKABLE_CATEGORIES.s.ARMOUR] = {},
		[UNLOCKABLE_CATEGORIES.s.WEAPON_TYPE] = {},
		[UNLOCKABLE_CATEGORIES.s.POWER] = {},
		[UNLOCKABLE_CATEGORIES.s.UNLOCKABLE_COSMETIC] = {},
		[UNLOCKABLE_CATEGORIES.s.PURCHASABLE_COSMETIC] = {},
		[UNLOCKABLE_CATEGORIES.s.FLAG] = {},
		[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL] = {},
		[UNLOCKABLE_CATEGORIES.s.LOCATION] = {},
		[UNLOCKABLE_CATEGORIES.s.REGION] = {},
	}
	return data
end

-- Total collection of everything the player's unlocked
local UnlockTracker = Class(function(self, inst)
	self.inst = inst
	self.data = create_default_data()

	self.inst:ListenForEvent("location_unlocked", function(_, location) self:UnlockLocation(location) end, TheWorld)

	local function OnSpawnEnemy(_, enemy)
		local normal_prefab = nil
		if enemy:HasTag("elite") then
			normal_prefab = string.gsub(enemy.prefab, "_elite", "")
		end
		self:UnlockEnemy(enemy.prefab)

		if normal_prefab ~= nil then
			self:UnlockEnemy(normal_prefab)
		end
	end

	self.inst:ListenForEvent("spawnenemy", OnSpawnEnemy, TheWorld)
end)


function UnlockTracker:OnSave()
	return self.data
end

function UnlockTracker:ValidateSaveData()
	local default_data = create_default_data()

	for k, _ in pairs(default_data) do
		if self.data[k] == nil then
			print ("UnlockTracker Data missing", k, "possible outdated save. Validating.")
			self.data[k] = {}
		end
	end
end

function UnlockTracker:OnLoad(data)
	assert(data)
	self.data = data
	self:ValidateSaveData()

	-- The above line overrides the data table, so when we add new items that are supposed to unlocked by default they're locked
	-- Hence the line below
	self:GiveDefaultUnlocks()
	for location, weapon_types in pairs(self:GetAllAscensionData()) do
		local highest = -1
		for weapon_type, level in pairs(weapon_types) do
			if level > highest then
				highest = level
			end
		end
		self:_AlignUnlockLevels(location, highest)
	end

end

function UnlockTracker:ResetUnlockTrackerToDefault()
	self.data = create_default_data()
	self:GiveDefaultUnlocks()
end

-- Also Called directly in the player's load flow in OnSetOwner in player_side
function UnlockTracker:GiveDefaultUnlocks()
	-- loop through items and unlock items tagged as default_unlocked
	for slot, items in pairs(itemcatalog.All.Items) do
		for name, item in pairs(items) do
			if item.tags.default_unlocked then
				self:UnlockRecipe(name)
			end
		end
	end

	self:UnlockEnemy("basic") -- bit of a hack since basic armor is the only one that does not come from an enemy
	self:UnlockRecipe("basic")
	self:UnlockRecipe("armour_unlock_basic")

	self:UnlockRegion("town")
	self:UnlockRegion("forest")

	self:UnlockLocation("treemon_forest")
	self:UnlockFlag("treemon_forest_reveal") -- don't show reveal of first location

	self:UnlockWeaponType(WEAPON_TYPES.HAMMER)
	self:UnlockDefaultMetaProgress()

	self:UnlockDefaultCosmetics()
end

function UnlockTracker:UnlockDefaultMetaProgress()
	local default_def = MetaProgress.FindProgressByName("default")

	for _, unlock in ipairs(default_def.rewards) do
		unlock:UnlockRewardForPlayer(self.inst)
		-- self:UnlockPower(unlock.def.name)
	end
end

function UnlockTracker:UnlockDefaultCosmetics()
	for group_name, group in pairs(Cosmetics.Items) do
		for cosmetic_name, cosmetic_data in pairs (group) do

			if not cosmetic_data.locked then
				self:UnlockCosmetic(cosmetic_name, group_name)
			end

			if cosmetic_data.purchased then
				self:PurchaseCosmetic(cosmetic_name, group_name)
			end
		end
	end
end

function UnlockTracker:Debug_UnlockAllPowers()
	for slot, powers in pairs(itemcatalog.Power.Items) do
		for id, def in pairs(powers) do
			self:UnlockPower(id)
		end
	end
end

function UnlockTracker:DEBUG_UnlockAllRecipes()
	
	-- Unlocking the armor requires having seen the mobs, so we unlock those too
	local Biomes = require"defs.biomes"
	for id, def in pairs(Biomes.locations) do
        if def.type == Biomes.location_type.DUNGEON then
			for _, mob in ipairs(def.monsters.mobs) do
				if string.match(mob, "trap") == nil then
					self:UnlockEnemy(mob)
				end
        	end

			for _, mob in ipairs(def.monsters.bosses) do
				if string.match(mob, "trap") == nil then
					self:UnlockEnemy(mob)
				end
        	end

			for _, mob in ipairs(def.monsters.minibosses) do
				if string.match(mob, "trap") == nil then
					self:UnlockEnemy(mob)
				end
        	end
        end
    end
	
	local recipes = require "defs.recipes"
	-- d_view(recipes)
	for slot, slot_recipes in pairs(recipes.ForSlot) do
		if next(slot_recipes) then
			for name, _ in pairs(slot_recipes) do
				self:UnlockRecipe(name)
			end
		end
	end
end

function UnlockTracker:OnWeaponTypeUnlocked(weapon_type)
	local locations = TheWorld:GetAllUnlocked(UNLOCKABLE_CATEGORIES.s.LOCATION)
	for _, location in ipairs(locations) do
		self:SetAscensionLevelCompleted(location, weapon_type, -1)
	end
end

function UnlockTracker:SetIsUnlocked(id, category, unlocked)
	assert(category ~= UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL, "Ascension levels should use the SetAscensionLevelCompleted flow instead")

	if self.data[category] == nil then
		self.data[category] = {}
	end

	if unlocked then
		self.data[category][id] = true
		self.inst:PushEvent("item_unlocked", {id = id, category = category})
	else
		self.data[category][id] = nil
		self.inst:PushEvent("item_locked", {id = id, category = category})
	end
end

function UnlockTracker:IsUnlocked(id, category)
	return self.data[category] ~= nil and self.data[category][id]
end

function UnlockTracker:GetAllUnlocked(category)
	return deepcopy(self.data[category])
end

------------------------------------------------------------------------------------------------------------
--------------------------------------------- ACCESS FUNCTIONS ---------------------------------------------
------------------------------------------------------------------------------------------------------------

--------------------------------------------- RECIPES ---------------------------------------------

function UnlockTracker:IsRecipeUnlocked(id)
	return self:IsUnlocked(id, UNLOCKABLE_CATEGORIES.s.RECIPE)
end

function UnlockTracker:UnlockRecipe(recipe)
	self:SetIsUnlocked(recipe, UNLOCKABLE_CATEGORIES.s.RECIPE, true)
	self.inst:PushEvent("recipe_unlocked", recipe)
end

function UnlockTracker:LockRecipe(recipe)
	self:SetIsUnlocked(recipe, UNLOCKABLE_CATEGORIES.s.RECIPE, false)
end

function UnlockTracker:IsMonsterArmourSetUnlocked(monster_id)
	local armour = itemutil.GetArmourForMonster(monster_id)
	for slot, def in pairs(armour) do
		if self:IsRecipeUnlocked(def.name) then
			return true
		end
	end
	return false
end

function UnlockTracker:UnlockMonsterArmourSet(monster_id)
	local armour = itemutil.GetArmourForMonster(monster_id)
	for slot, def in pairs(armour) do
		self:UnlockRecipe(def.name)
	end
	return false
end

--------------------------------------------- ENEMIES ---------------------------------------------

function UnlockTracker:IsEnemyUnlocked(id)
	return self:IsUnlocked(id, UNLOCKABLE_CATEGORIES.s.ENEMY)
end

function UnlockTracker:UnlockEnemy(enemy)
	self:SetIsUnlocked(enemy, UNLOCKABLE_CATEGORIES.s.ENEMY, true)
end

function UnlockTracker:LockEnemy(enemy)
	self:SetIsUnlocked(enemy, UNLOCKABLE_CATEGORIES.s.ENEMY, false)
end


--------------------------------------------- CONSUMABLES ---------------------------------------------

function UnlockTracker:IsConsumableUnlocked(id)
	return self:IsUnlocked(id, UNLOCKABLE_CATEGORIES.s.CONSUMABLE)
end

function UnlockTracker:UnlockConsumable(consumable)
	self:SetIsUnlocked(consumable, UNLOCKABLE_CATEGORIES.s.CONSUMABLE, true)
	self.inst:PushEvent("unlock_consumable", consumable)
end

function UnlockTracker:LockConsumable(consumable)
	self:SetIsUnlocked(consumable, UNLOCKABLE_CATEGORIES.s.CONSUMABLE, false)
end

--------------------------------------------- WEAPON CLASS ---------------------------------------------

function UnlockTracker:IsWeaponTypeUnlocked(id)
	return self:IsUnlocked(id, UNLOCKABLE_CATEGORIES.s.WEAPON_TYPE)
end

function UnlockTracker:UnlockWeaponType(weapon_type)
	self:SetIsUnlocked(weapon_type, UNLOCKABLE_CATEGORIES.s.WEAPON_TYPE, true)
	self:OnWeaponTypeUnlocked(weapon_type)
end

function UnlockTracker:LockWeaponType(weapon_type)
	self:SetIsUnlocked(weapon_type, UNLOCKABLE_CATEGORIES.s.WEAPON_TYPE, false)
end

--------------------------------------------- POWERS ---------------------------------------------

function UnlockTracker:IsPowerUnlocked(id)
	return self:IsUnlocked(id, UNLOCKABLE_CATEGORIES.s.POWER)
end

function UnlockTracker:UnlockPower(power)
	self:SetIsUnlocked(power, UNLOCKABLE_CATEGORIES.s.POWER, true)
end

function UnlockTracker:LockPower(power)
	self:SetIsUnlocked(power, UNLOCKABLE_CATEGORIES.s.POWER, false)
end

--------------------------------------------- COSMETICS ---------------------------------------------

function UnlockTracker:GetAllUnlockedCosmetics(category)
	local unlocked_cosmetics = {}
	for name, _ in pairs(self.data[UNLOCKABLE_CATEGORIES.s.UNLOCKABLE_COSMETIC][category]) do
		table.insert(unlocked_cosmetics, name)
	end
	return unlocked_cosmetics
end

function UnlockTracker:IsCosmeticUnlocked(id, category)
	if not self.data[UNLOCKABLE_CATEGORIES.s.UNLOCKABLE_COSMETIC][category] then
		self.data[UNLOCKABLE_CATEGORIES.s.UNLOCKABLE_COSMETIC][category] = {}
		return false
	end

	-- Added ~= nil to stop this from returning nil instead of false
	return self.data[UNLOCKABLE_CATEGORIES.s.UNLOCKABLE_COSMETIC][category][id] ~= nil
end

function UnlockTracker:UnlockCosmetic(id, category)
	if not self.data[UNLOCKABLE_CATEGORIES.s.UNLOCKABLE_COSMETIC][category] then
		self.data[UNLOCKABLE_CATEGORIES.s.UNLOCKABLE_COSMETIC][category] = {}
	end
	
	self.data[UNLOCKABLE_CATEGORIES.s.UNLOCKABLE_COSMETIC][category][id] = true
	self.inst:PushEvent("cosmetic_unlocked", {id = id, category = category})
end

function UnlockTracker:LockCosmetic(id, category)
	if not self.data[UNLOCKABLE_CATEGORIES.s.UNLOCKABLE_COSMETIC][category] then
		self.data[UNLOCKABLE_CATEGORIES.s.UNLOCKABLE_COSMETIC][category] = {}
		return
	end
	
	self.data[UNLOCKABLE_CATEGORIES.s.UNLOCKABLE_COSMETIC][category][id] = nil
	self.inst:PushEvent("cosmetic_locked", {id = id, category = category})
end


function UnlockTracker:IsCosmeticPurchased(id, category)
	if not self.data[UNLOCKABLE_CATEGORIES.s.PURCHASABLE_COSMETIC][category] then
		self.data[UNLOCKABLE_CATEGORIES.s.PURCHASABLE_COSMETIC][category] = {}
		return false
	end

	-- Added ~= nil to stop this from returning nil instead of false
	return self.data[UNLOCKABLE_CATEGORIES.s.PURCHASABLE_COSMETIC][category][id] ~= nil
end

function UnlockTracker:PurchaseCosmetic(id, category)
	if not self.data[UNLOCKABLE_CATEGORIES.s.PURCHASABLE_COSMETIC][category] then
		self.data[UNLOCKABLE_CATEGORIES.s.PURCHASABLE_COSMETIC][category] = {}
	end
	
	self.data[UNLOCKABLE_CATEGORIES.s.PURCHASABLE_COSMETIC][category][id] = true
	self.inst:PushEvent("cosmetic_purchased", {id = id, category = category})
end

function UnlockTracker:UnpurchaseCosmetic(id, category)
	if not self.data[UNLOCKABLE_CATEGORIES.s.PURCHASABLE_COSMETIC][category] then
		self.data[UNLOCKABLE_CATEGORIES.s.PURCHASABLE_COSMETIC][category] = {}
		return
	end
	
	self.data[UNLOCKABLE_CATEGORIES.s.PURCHASABLE_COSMETIC][category][id] = nil
	self.inst:PushEvent("cosmetic_locked", {id = id, category = category})
end

function UnlockTracker:GetAllPurchasedCosmetics(category)
	local purchased_cosmetics = {}
	for name, _ in pairs(self.data[UNLOCKABLE_CATEGORIES.s.PURCHASABLE_COSMETIC][category]) do
		table.insert(purchased_cosmetics, name)
	end
	return purchased_cosmetics
end

--------------------------------------------- FLAG ---------------------------------------------

function UnlockTracker:IsFlagUnlocked(id)
	return self:IsUnlocked(id, UNLOCKABLE_CATEGORIES.s.FLAG)
end

function UnlockTracker:UnlockFlag(flag)
	self:SetIsUnlocked(flag, UNLOCKABLE_CATEGORIES.s.FLAG, true)
end

function UnlockTracker:LockFlag(flag)
	self:SetIsUnlocked(flag, UNLOCKABLE_CATEGORIES.s.FLAG, false)
end

--------------------------------------------- LOCATION ---------------------------------------------

function UnlockTracker:IsLocationUnlocked(location)
	return self:IsUnlocked(location, UNLOCKABLE_CATEGORIES.s.LOCATION)
end

function UnlockTracker:UnlockLocation(location)
	self:SetIsUnlocked(location, UNLOCKABLE_CATEGORIES.s.LOCATION, true)
	TheWorld:UnlockLocation(location)
	self:OnLocationUnlocked(location)
end

function UnlockTracker:LockLocation(location)
	self:SetIsUnlocked(location, UNLOCKABLE_CATEGORIES.s.LOCATION, false)
end

function UnlockTracker:OnLocationUnlocked(location)
	for _, weapon_type in ipairs(self.data[UNLOCKABLE_CATEGORIES.s.WEAPON_TYPE]) do
		self:SetAscensionLevelCompleted(location, weapon_type, -1)
	end
end

--------------------------------------------- REGIONS ---------------------------------------------

function UnlockTracker:IsRegionUnlocked(id)
	return self:IsUnlocked(id, UNLOCKABLE_CATEGORIES.s.REGION)
end

function UnlockTracker:UnlockRegion(region)
	self:SetIsUnlocked(region, UNLOCKABLE_CATEGORIES.s.REGION, true)
	TheWorld:UnlockRegion(region)
end

function UnlockTracker:LockRegion(region)
	self:SetIsUnlocked(region, UNLOCKABLE_CATEGORIES.s.REGION, false)
end

--------------------------------------------- ASCENSION LEVEL ---------------------------------------------
function UnlockTracker:_AlignUnlockLevels(location, level)
	-- If the level you just unlocked is BELOW the threshold for super frenzy, we want it to be completed for all weapon types.
	-- Once you being doing super frenzies, we no longer want the levels to be aligned across all weapons.
	level = math.min(level, NORMAL_FRENZY_LEVELS)
	for _, weapon_type in pairs(WEAPON_TYPES) do
		self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location][weapon_type] = level
	end
end

function UnlockTracker:SetAscensionLevelCompleted(location, weapon_type, level)
	-- TheLog.ch.UnlockTracker:printf("SetAscensionLevelCompleted: location %s weapon_type %s level %d",
	-- 	location, weapon_type, level)
	-- I strongly dislike how verbose this is and I'm sorry
	if not self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location] then
		self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location] = {}
	end
	self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location][weapon_type] = level
	self:_AlignUnlockLevels(location, level)
end

function UnlockTracker:GetCompletedAscensionLevel(location, weapon_type)
	assert(WEAPON_TYPES[weapon_type], "Invalid weapon type: check WEAPON_TYPES in constants.lua")
	-- print ("UnlockTracker:GetCompletedAscensionLevel", UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL, location, weapon_type)

	-- TEMP SOLUTION, we wanna actually pull all unlocked locations from the world and populated it then
	if self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location] == nil then
		self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location] = { [weapon_type] = -1 }
	elseif self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location][weapon_type] == nil then
		self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location][weapon_type] = -1
	end

	return self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location][weapon_type]
end

function UnlockTracker:GetAllAscensionData()
	return self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL]
end

------------------------------------------------------------------------------------------------------------
-- Goes through the locations and weapons and returns the highest ascension level
-- this player has seen, so it always shows in the UI, even if locked for a particular
-- weapon or location
function UnlockTracker:GetHighestSeenAscension()
	local highest_completed = -1
	for location_id, weapons in pairs(self:GetAllAscensionData()) do
		for weapon_type, ascension_level in pairs(weapons) do
			if ascension_level > highest_completed then
				highest_completed = ascension_level
			end
		end
	end
	return highest_completed + 1
end

-- NETWORKING
local sortedLocations
local sortedLocationsNrBits
local sortedRegions
local sortedRegionsNrBits
local sortedWeaponTypes
local sortedWeaponTypesNrBits
local sortedPowerItems	-- table of tables

local powerCategoriesToInclude = 
{
	Power.Slots.PLAYER,
	Power.Slots.ELECTRIC,
	Power.Slots.SHIELD,
	Power.Slots.SUMMON,
}

local function SortLocationsRegionsAndWeapons()
	-- This creates DETERMINISTIC location and weapon type lists. Should be the same array on all clients, so we can communicate using bits, rather than strings
	if not sortedLocations then
		local Biomes = require"defs.biomes"
		sortedLocations = {}
		local index = 1

		for key, def in pairs(biomes.locations) do
			if def.type == biomes.location_type.DUNGEON then
				sortedLocations[index] = key
				index = index + 1
			end
		end
		sortedLocationsNrBits = index-1
		
		table.sort(sortedLocations)
	end

	if not sortedRegions then
		local Biomes = require"defs.biomes"
		sortedRegions = {}
		local index = 1
		for key, def in pairs(biomes.regions) do
			sortedRegions[index] = key
			index = index + 1
		end
		sortedRegionsNrBits = index-1
		
		table.sort(sortedRegions)
	end


	if not sortedWeaponTypes then
		sortedWeaponTypes = {}
		local index = 1

		for key in pairs(WEAPON_TYPES) do
			sortedWeaponTypes[index] = key
			index = index + 1
		end
		sortedWeaponTypesNrBits = index-1

		table.sort(sortedWeaponTypes)
	end

	if not sortedPowerItems then
		sortedPowerItems = {}
		for _, category in pairs(powerCategoriesToInclude) do
			local index = 1

			for id, def in pairs(itemcatalog.Power.Items[category]) do
				sortedPowerItems[index] = id
				index = index + 1
			end
			table.sort(sortedPowerItems)
		end
	end
end

local function GetLocationBits(locations_table)
	local bits = 0;

	for idx, val in ipairs(sortedLocations) do
		if locations_table[val] then	-- If this location exists in our table
			bits = bits | (1 << (idx-1))						-- Set the bit
		end
	end 
	return bits
end

local function GetRegionBits(regions_table)
	local bits = 0;

	for idx, val in ipairs(sortedRegions) do
		if regions_table[val] then	-- If this region exists in our table
			bits = bits | (1 << (idx-1))						-- Set the bit
		end
	end 
	return bits
end

local function GetWeaponTypeBits(weapon_type_table)
	local bits = 0;

	for idx, val in ipairs(sortedWeaponTypes) do
		if weapon_type_table[val] and weapon_type_table[val]>=0 then	-- If the value for the weapon is higher than 0 (not -1)
			bits = bits | (1 << (idx-1))		-- Set the bit
		end
	end 
	return bits
end

function UnlockTracker:SerializePowerItems(e, powertable)
	for _, power in ipairs(sortedPowerItems) do	-- use ipairs to make sure the order is deterministic
		e:SerializeBoolean(self:IsPowerUnlocked(power))
	end
end

function UnlockTracker:DeserializePowerItems(e, powertable)
	for _, power in ipairs(sortedPowerItems) do	-- use ipairs to make sure the order is deterministic
		local unlocked = e:DeserializeBoolean()

		if unlocked ~= nil then
			self:SetIsUnlocked(power, UNLOCKABLE_CATEGORIES.s.POWER, unlocked)
		end
	end
end

local AscensionNrBits <const> = 6	-- max 1<<6 = 64
function UnlockTracker:OnNetSerialize()
	local e = self.inst.entity

	SortLocationsRegionsAndWeapons()

	-- Figure out which locations are in the data as a bitlist:
	local locationBits = GetLocationBits(self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL])
	e:SerializeUInt(locationBits, sortedLocationsNrBits)

	for locationidx, location in ipairs(sortedLocations) do
		if (locationBits & (1<<(locationidx-1))) ~= 0 then

			local weapontypeBits = GetWeaponTypeBits(self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location])
			e:SerializeUInt(weapontypeBits, sortedWeaponTypesNrBits)

			for weaponidx, weapontype in ipairs(sortedWeaponTypes) do
				if (weapontypeBits & (1<<(weaponidx-1))) ~= 0 then
					local value = self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location][weapontype]
					e:SerializeUInt(value, AscensionNrBits)
				end
			end
		end
	end

	-- Serialize Locations:
	locationBits = GetLocationBits(self.data[UNLOCKABLE_CATEGORIES.s.LOCATION])
	e:SerializeUInt(locationBits, sortedLocationsNrBits)

	-- Serialize Regions:
	local regionBits = GetRegionBits(self.data[UNLOCKABLE_CATEGORIES.s.REGION])
	e:SerializeUInt(regionBits, sortedRegionsNrBits)

	-- Serialize Power items:
	e:PushSerializationMarker("Unlocked Power Items")
	self:SerializePowerItems(e, self.data[UNLOCKABLE_CATEGORIES.s.POWER])
	e:PopSerializationMarker()
end

function UnlockTracker:OnNetDeserialize()
	local e = self.inst.entity

	SortLocationsRegionsAndWeapons()

	local locationBits = e:DeserializeUInt(sortedLocationsNrBits)

	for locationidx, location in ipairs(sortedLocations) do
		if (locationBits & (1<<(locationidx-1))) ~= 0 then
			if not self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location] then
				self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location] = {}
			end

			local weapontypeBits = e:DeserializeUInt(sortedWeaponTypesNrBits)

			for weaponidx, weapontype in ipairs(sortedWeaponTypes) do
				if (weapontypeBits & (1<<(weaponidx-1))) ~= 0 then

					local value = e:DeserializeUInt(AscensionNrBits)	-- 0-64

					self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location][weapontype] = value
				else
					self.data[UNLOCKABLE_CATEGORIES.s.ASCENSION_LEVEL][location][weapontype] = -1	-- If the weapon type does not exist, set it to -1
				end
			end
		end
	end

	-- Locations:
	locationBits = e:DeserializeUInt(sortedLocationsNrBits)
	for locationidx, location in ipairs(sortedLocations) do
		if (locationBits & (1<<(locationidx-1))) ~= 0 then
			self.data[UNLOCKABLE_CATEGORIES.s.LOCATION][location] = true
		else
			self.data[UNLOCKABLE_CATEGORIES.s.LOCATION][location] = nil
		end
	end

	-- Region:
	local regionBits = e:DeserializeUInt(sortedRegionsNrBits)
	for regionidx, region in ipairs(sortedRegions) do
		if (regionBits & (1<<(regionidx-1))) ~= 0 then
			self.data[UNLOCKABLE_CATEGORIES.s.REGION][region] = true
		else
			self.data[UNLOCKABLE_CATEGORIES.s.REGION][region] = nil
		end
	end
		
	-- Deserialize Power items:
	self:DeserializePowerItems(e, self.data[UNLOCKABLE_CATEGORIES.s.POWER])

end



------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------

return UnlockTracker


-- NOT YET NEEDED
-- function UnlockTracker:UnlockArmour(armour)
-- 	self:SetIsUnlocked(armour, UNLOCKABLE_CATEGORIES.s.ARMOUR, true)
-- end

-- function UnlockTracker:LockArmour(armour)
-- 	self:SetIsUnlocked(armour, UNLOCKABLE_CATEGORIES.s.ARMOUR, false)
-- end
