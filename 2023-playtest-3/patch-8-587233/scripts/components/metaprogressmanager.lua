local MetaProgress = require("defs.metaprogression")
local Consumable = require"defs.consumable"
local Power = require"defs.powers"

local itemforge = require "defs.itemforge"
require "util"

local function create_default_data()
	local data =
	{
		progress = {
			-- a list of all the meta progress that are currently being tracked
			-- slot = { ["progress_name"] = progress_def, ... },
		},
	}

	for _, slot in pairs(MetaProgress.Slots) do
		assert(not data.progress[slot], "The following slot already exists:"..slot)
		data.progress[slot] = {}
	end

	return data
end

local MetaProgressManager = Class(function(self, inst)
	self.inst = inst
	self.data = create_default_data() -- power items (persistent data)
	self.progress_instances = {} -- transient data, not saved

    self._reset_data_fn =  function() self:ResetData() end
    self.inst:ListenForEvent("character_slot_changed", self._reset_data_fn)
end)

function MetaProgressManager:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("character_slot_changed", self._reset_data_fn)
end

function MetaProgressManager:OnRemoveEntity()
	self:OnRemoveFromEntity()
end

function MetaProgressManager:OnSave()
	-- Don't copy this implementation! Usually we should build a new table for
	-- our save data.
	local data = deepcopy(self.data)
	for _, slot in pairs(data.progress) do
		itemforge.ConvertToListOfSaveableItems(slot)
	end
	return data
end

function MetaProgressManager:OnLoad(data)
	if data ~= nil then
		for _,slot in pairs(data.progress) do
			itemforge.ConvertToListOfRuntimeItems(slot)
		end
		self.data = data
	end

	-- Init all first so powers that depend on each other are fully init
	-- before firing events.
	for _, slot in pairs(self.data.progress) do
		for _, progress in pairs(slot) do
			self:_InitProgress(progress)
		end
	end
end

function MetaProgressManager:ResetData()
	self.progress_instances = {}
	self.data = create_default_data()
end

function MetaProgressManager:_InitProgress(progress)
	local progress_instance = MetaProgress.ProgressInstance(progress)
	assert(self.progress_instances[progress_instance.def.name] == nil)
	self.progress_instances[progress_instance.def.name] = progress_instance
	return progress_instance
end

function MetaProgressManager:CreateProgress(def)
	local progress = itemforge.CreateMetaProgress(def)
	return progress
end

function MetaProgressManager:StartTrackingProgress(progress)
	local progress_def = progress:GetDef()
	assert(progress_def.name, "StartTrackingProgress takes a progress def from MetaProgress.Items")
	if not self.data.progress[progress_def.slot] then
		self.data.progress[progress_def.slot] = {}
	end
	local slot = self.data.progress[progress_def.slot]
	local progress_instance = self:_InitProgress(progress)
	assert(progress_instance)
	slot[progress_def.name] = progress_instance.persistdata
	return self:GetProgress(progress_def)
end

---------------------------------------------------------------------

function MetaProgressManager:GetAllProgressOfSlot(slot)
	return self.data.progress[slot]
end

function MetaProgressManager:GetProgressByName(name)
	return self.progress_instances[name]
end

function MetaProgressManager:GetProgress(def)
	return self.progress_instances[def.name]
end

function MetaProgressManager:GrantExperience( def, exp )
	local progress = self:GetProgress(def)
	if progress then
		local log, unlocks = progress:GrantExperience(exp)

		if #unlocks > 0 then
			for _, unlock in ipairs(unlocks) do
				if unlock.def.slot == Power.Slots.PLAYER then
					self.inst.components.unlocktracker:UnlockPower(unlock.def.name)
				elseif unlock.def.slot == Consumable.Slots.KEY_ITEMS then
					if unlock.def.recipes then
						for _, data in ipairs(unlock.def.recipes) do
							self.inst.components.unlocktracker:UnlockRecipe(data.name)
						end
					end
				else
					assert(true, string.format("Invalid progress Type! [%s - %s]", unlock.def.slot, unlock.def.name))
				end
			end
		end

		return log, unlocks
	end
end

-- TODO: Need some sort of "unlock validation" just in case we change the unlocks for an earlier level
-- TODO: Need validation that nothing is on two progress lists
-- TODO: Need to check if everything is unlockable?

return MetaProgressManager