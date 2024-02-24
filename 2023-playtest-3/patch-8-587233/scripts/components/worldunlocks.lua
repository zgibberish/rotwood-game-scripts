local Equipment = require"defs.equipment"
local itemcatalog = require"defs.itemcatalog"

local lume = require "util.lume"
require "util"

local function create_default_data()
	local data =
	{
		[UNLOCKABLE_CATEGORIES.s.FLAG] = {},
		[UNLOCKABLE_CATEGORIES.s.LOCATION] = {},
		[UNLOCKABLE_CATEGORIES.s.REGION] = {},
	}
	return data
end

-- Total collection of everything the player's unlocked
local WorldUnlocks = Class(function(self, inst)
	self.inst = inst
	self.data = create_default_data()
end)

function WorldUnlocks:OnSave()
	return self.data
end

function WorldUnlocks:OnLoad(data)
	assert(data)
	self.data = data
end

function WorldUnlocks:OnPostSpawn()
	self:GiveDefaultUnlocks()
end

function WorldUnlocks:ResetUnlocksToDefault()
	self.data = create_default_data()
	self:GiveDefaultUnlocks()
end

function WorldUnlocks:GiveDefaultUnlocks()
	-- Default location and region unlocks and handled in unlocktracker.
	-- When the player unlocks a location or region, it also unlocks it for TheWorld
end

function WorldUnlocks:IsUnlocked(id, category)
	return self.data[category][id]
end

function WorldUnlocks:SetIsUnlocked(id, category, unlocked)
	if unlocked then
		self.data[category][id] = true
		self.inst:PushEvent("global_item_unlocked", {id = id, category = category})
	else
		self.data[category][id] = nil
		self.inst:PushEvent("global_item_locked", {id = id, category = category})
	end
end

function WorldUnlocks:GetAllUnlocked(category)
	assert(self.data[category] ~= nil, "INVALID UNLOCKABLE CATEGORY:", category)
	return deepcopy(self.data[category])
end

------------------------------------------------------------------------------------------------------------
--------------------------------------------- ACCESS FUNCTIONS ---------------------------------------------
------------------------------------------------------------------------------------------------------------


--------------------------------------------- LOCATIONS ---------------------------------------------
function WorldUnlocks:IsLocationUnlocked(id)
	return self:IsUnlocked(id, UNLOCKABLE_CATEGORIES.s.LOCATION)
end

function WorldUnlocks:UnlockLocation(location)
	self:SetIsUnlocked(location, UNLOCKABLE_CATEGORIES.s.LOCATION, true)
	self.inst:PushEvent("location_unlocked", location)
end

function WorldUnlocks:LockLocation(location)
	self:SetIsUnlocked(location, UNLOCKABLE_CATEGORIES.s.LOCATION, false)
end

--------------------------------------------- FLAGS ---------------------------------------------
function WorldUnlocks:IsFlagUnlocked(id)
	return self:IsUnlocked(id, UNLOCKABLE_CATEGORIES.s.FLAG)
end

function WorldUnlocks:UnlockFlag(flag)
	self:SetIsUnlocked(flag, UNLOCKABLE_CATEGORIES.s.FLAG, true)
end

function WorldUnlocks:LockFlag(flag)
	self:SetIsUnlocked(flag, UNLOCKABLE_CATEGORIES.s.FLAG, false)
end

--------------------------------------------- REGIONS ---------------------------------------------
function WorldUnlocks:IsRegionUnlocked(id)
	return self:IsUnlocked(id, UNLOCKABLE_CATEGORIES.s.REGION)
end

function WorldUnlocks:UnlockRegion(region)
	self:SetIsUnlocked(region, UNLOCKABLE_CATEGORIES.s.REGION, true)
end

function WorldUnlocks:LockRegion(region)
	self:SetIsUnlocked(region, UNLOCKABLE_CATEGORIES.s.REGION, false)
end
----------------------------------------------------------------------------------------------------

return WorldUnlocks
