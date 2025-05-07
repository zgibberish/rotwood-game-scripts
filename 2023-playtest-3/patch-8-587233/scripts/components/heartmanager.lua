local Heart = require "defs.hearts"
local kassert = require "util.kassert"
local itemforge = require "defs.itemforge"
require "util"

local STACKS_PER_LEVEL = 25

local function create_default_data()
	local data =
	{
		hearts = {
			-- a list of pairs of hearts that exist in the game
		},

		-- SAVED DATA:
		heart_levels = {
			-- a list of current levels for each heart
		},
		active_hearts = {
			-- per heart pairing, which of the pairs is currently active?
				-- 0 = none active
				-- 1 = first active
				-- 2 = second active
		},
	}

	-- Make a slot for each of the biomes
	for _, slot in pairs(Heart.Slots) do
		assert(not data.hearts[slot] and not data.active_hearts[slot], "The following slot already exists:"..slot)
		data.hearts[slot] = {}
		data.heart_levels[slot] = {}
		data.active_hearts[slot] = 0
	end

	-- Put the Heart definitions into those slots
	for slot, slot_data in pairs(Heart.Items) do
		for __, heart in pairs(slot_data) do
			data.hearts[slot][heart.idx] = heart
			data.heart_levels[slot][heart.idx] = 0
		end
	end

	return data
end

local HeartManager = Class(function(self, inst)
	self.inst = inst

	self.data = create_default_data()

	self._new_run_fn = function() self:_AddAllPowers() end
	self.inst:ListenForEvent("start_new_run", self._new_run_fn)

	self._on_deposit_heart_fn = function() self:_ShowUpgradeDetails() end

	self.inst:ListenForEvent("deposit_heart_finished", self._on_deposit_heart_fn)
end)

function HeartManager:_OpenHeartScreen(slot, idx)
	local HeartScreen = require "screens.town.heartscreen"
	local screen = HeartScreen(self.inst)
	TheFrontEnd:PushScreen(screen)
	if slot ~= nil then
		screen:RevealNewPower(slot, idx)
	end
end

function HeartManager:_ShowUpgradeDetails()
	if not self.last_leveled_heart then
		return
	end

	if self.last_leveled_heart.old_level == 0 then
		-- If the last level was 0 (AKA, undiscovered) then open the screen and do presentation stuff
		self.inst:DoTaskInTime(0.66, function() self:_OpenHeartScreen(self.last_leveled_heart.slot, self.last_leveled_heart.idx) end)
	else
		-- Otherwise, just show how that specific power changed
		local def = Heart.GetHeartDef(self.last_leveled_heart.slot, self.last_leveled_heart.idx)
		local popup_data =
		{
			icon_override = def.icon,
			owner = self.inst,
			target = self.inst,
			power = "heart_"..def.name,
			x_offset = -325,
			y_offset = 400,
			width = 750,
			fade_time = 4,
			stacks = self.last_leveled_heart.new_level * def.stacks_per_level,
		}

		TheDungeon.HUD:MakePopPowerDisplay(popup_data)
	end
end

function HeartManager:EquipHeart(slot, idx)
	local old_equip = self.data.active_hearts[slot]

	if old_equip and old_equip ~= 0 and old_equip ~= idx then
		self:_RemovePowerForSlot(slot)
	end

	self.data.active_hearts[slot] = idx
	self:_AddPowerForSlot(slot)
end

function HeartManager:GetEquippedIdxForSlot(slot)
	local idx = self.data.active_hearts[slot]
	return idx
end

function HeartManager:GetEquippedHeartForSlot(slot)
	local idx = self.data.active_hearts[slot]
	return self.data.hearts[slot][idx]
end

function HeartManager:GetHeartLevelsForSlot(slot)
	return self.data.heart_levels[slot]
end

function HeartManager:ConsumeHeartAndUpgrade(heart_def)
	self.inst.components.inventoryhoard:RemoveStackable(heart_def, 1)
	local slot, idx = self:GetSlotAndIdxFromID(heart_def.name)
	self:LevelUpHeart(slot, idx)
end

function HeartManager:GetSlotAndIdxFromID(id)
	local heart_slot = nil
	local heart_idx = nil

	-- Put the Heart definitions into those slots
	for slot, slot_data in pairs(Heart.Items) do
		for _, heart_def in pairs(slot_data) do
			if heart_def.heart_id == id then
				heart_slot = slot
				heart_idx = heart_def.idx
				break
			end
		end
	end

	return heart_slot, heart_idx
end

function HeartManager:GetHeartLevel(slot, idx)
	return self.data.heart_levels[slot][idx] or 0
end

function HeartManager:SetHeartLevel(slot, idx, level)
	local old_level = self:GetHeartLevel(slot, idx)

	self.data.heart_levels[slot][idx] = level

	if old_level ~= level and self.data.active_hearts[slot] == idx then -- If the level has changed And we have this heart currently equipped
		self:_UpdatePowerForSlot(slot)
	end
end

function HeartManager:LevelUpHeart(slot, idx)
	local old_level = self:GetHeartLevel(slot, idx)
	local new_level = old_level + 1
	self:SetHeartLevel(slot, idx, new_level)

	if self:GetEquippedIdxForSlot(slot) == 0 then
		self:EquipHeart(slot, idx)
	end

	self.last_leveled_heart = { slot = slot, idx = idx, old_level = old_level, new_level = new_level }
end

function HeartManager:_AddAllPowers()
	for slot,idx in pairs(self.data.active_hearts) do
		if idx ~= 0 then
			self:_AddPowerForSlot(slot)
		end
	end
end

function HeartManager:_AddPowerForSlot(slot)
	local active_idx = self.data.active_hearts[slot]
	local heart = self.data.hearts[slot][active_idx]

	local stacks = self.data.heart_levels[slot][active_idx] * heart.stacks_per_level

	self.inst.components.powermanager:AddPowerByName(heart.power, stacks)
end

function HeartManager:_UpdatePowerForSlot(slot)
	local active_idx = self.data.active_hearts[slot]

	local heart = self.data.hearts[slot][active_idx]
	local level = self.data.heart_levels[slot][active_idx]

	local pow_def = self.inst.components.powermanager:GetPowerByName(heart.power).def

	local new_stacks = level * heart.stacks_per_level

	self.inst.components.powermanager:SetPowerStacks(pow_def, new_stacks)
end

function HeartManager:_RemovePowerForSlot(slot)
	local active_idx = self.data.active_hearts[slot]
	local heart = self.data.hearts[slot][active_idx]

	self.inst.components.powermanager:RemovePowerByName(heart.power, true)
end

function HeartManager:OnSave()
	local data = deepcopy(self.data)

	--TODO(jambell): don't save the heart data - reload it so we get tuning updates

	-- hearts
	-- heart_levels
	-- active_hearts

	return data
end

function HeartManager:OnLoad(data)
	if data ~= nil then

		-- TODO(jambell): do something better here


		------------------
		-- Add slots that have been added after this save data was created.
		-- for _,slot in pairs(Equipment.Slots) do
		-- 	if not data.inventory[slot] then
		-- 		data.inventory[slot] = {}
		-- 	end
		-- end

		-- for _,slot in pairs(Consumable.Slots) do
		-- 	if not data.inventory[slot] then
		-- 		data.inventory[slot] = {}
		-- 	end
		-- end
		------------------

		-- kassert.typeof('table', data.inventory.WEAPON)
		-- for slot_name, slot_items in pairs(data.inventory) do
		-- 	itemforge.ConvertToListOfRuntimeItems(slot_items)

		-- 	for _, item in ipairs(slot_items) do
		-- 		if item.gem_slots then
		-- 			for _, gem_slot in ipairs(item.gem_slots) do
		-- 				if gem_slot.gem then
		-- 					itemforge.ConvertToRuntimeItem(gem_slot.gem)
		-- 				end
		-- 			end
		-- 		end
		-- 	end
		-- end

		self.data = data

		-- refresh the definitions
		for slot, slot_data in pairs(Heart.Items) do
			for __, heart in pairs(slot_data) do
				data.hearts[slot][heart.idx] = heart
			end
		end

		-- if DEV_MODE then
		-- 	self:RefreshItemStats()
		-- end
	end
end

return HeartManager
