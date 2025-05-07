local Equipment = require("defs.equipment")
local Power = require "defs.powers"

local MAIN_POTION = "POTIONS"
local TONICS = "TONICS"

local SLOTS =
{
	MAIN_POTION,
	TONICS
}

local PotionDrinker = Class(function(self, inst)
	self.inst = inst
	dbassert(self.inst.components.timer, "Requires timer component.")

	self.time_spent_updating = {}
	self.next_repeat_time = {}

	self.equipped_potions = {} --item instances of potions for local use only
	-- networking: do not cache potion stats, usage data, etc. as they will not be updated remotely
	-- see comments for network-synced API of potion stats, usage_data, etc.

	inst:ListenForEvent("end_current_run", function()
		local equip_tonic_def = self:GetEquippedPotionDef("TONICS")
		if equip_tonic_def then
			self.inst.components.inventoryhoard:RemoveStackable(equip_tonic_def, 1)
		end
	end, TheWorld)

	inst:ListenForEvent("start_gameplay", function()
		if TheWorld.components.roomlockable and TheWorld.components.roomlockable:IsLocked() then
			self.inst.components.timer:ResumeTimer("potion_cd")
		end
	end)

	inst:ListenForEvent("room_locked", function() self.inst.components.timer:ResumeTimer("potion_cd") end, TheWorld)
	inst:ListenForEvent("room_unlocked", function() self.inst.components.timer:PauseTimer("potion_cd") end, TheWorld)

    self._new_run_fn =  function() self:InitializePotions() end
    self.inst:ListenForEvent("start_new_run", self._new_run_fn)
end)

function PotionDrinker:_SetEquippedPotion(SLOT, potion)
	if potion == nil then
		return
	end

	self.equipped_potions[SLOT] = potion
	local potion_def = potion:GetDef()
	self.inst.components.usetracker:AddTrackedUse(potion_def.name, "refreshpotiondata")
end

function PotionDrinker:ApplyPower(power_name, stacks)
	local def = Power.FindPowerByName(power_name)
	local power = self.inst.components.powermanager:CreatePower(def)
	self.inst.components.powermanager:AddPower(power)
	if stacks then
		self.inst.components.powermanager:DeltaPowerStacks(def, stacks)
	end
end

function PotionDrinker:DrinkPotionSlot(SLOT)
	if not self.inst:IsLocal() then
		return
	end

	self.inst.components.usetracker:Use(self:GetEquippedPotionDef(SLOT).name)

	local potion_usage_data = self:GetEquippedPotionUsageData(SLOT)
	if potion_usage_data.power then
		self:ApplyPower(potion_usage_data.power, potion_usage_data.power_stacks)
	end

	if potion_usage_data.cooldown then
		self.inst.components.timer:StartTimer("potion_cd_" .. SLOT, potion_usage_data.cooldown, true)
	end

	self.inst:PushEvent("drink_potion", self.equipped_potions[SLOT])
end

function PotionDrinker:DrinkPotion()
	if not self.inst:IsLocal() then
		return
	end

	self:CheckPotions()
	if not self.equipped_potions or not self.equipped_potions[MAIN_POTION] then
		print("ERROR: TRIED TO DRINK POTION WITHOUT AN EQUIPPED POTION INITIALIZED")
		return
	end

	local lifetime_drinks = TheSaveSystem.progress:GetValue("potion_drinks") or 0
	TheSaveSystem.progress:SetValue("potion_drinks", lifetime_drinks + 1)

	self:DrinkPotionSlot(MAIN_POTION)

	if self.equipped_potions[TONICS] then
		self:DrinkPotionSlot(TONICS)
	end
end

function PotionDrinker:InitializePotions()
	if not self.inst:IsLocal() then
		return
	end

	for i, v in ipairs(SLOTS) do
		if self.equipped_potions[v] then
			self:InitializePotion(v)
		end
	end
end

function PotionDrinker:InitializePotion(SLOT)
	if not self.inst:IsLocal() then
		return
	end

	self:CheckPotions()
	self.inst.components.timer:StopTimer("potion_cd")
	local def = self:GetEquippedPotionDef(SLOT)
	if def then
		self.inst.components.usetracker:ResetUses(def.name)
	end
	self.inst:PushEvent("refreshpotiondata")
end

function PotionDrinker:RefillPotion()
	if not self.inst:IsLocal() then
		return
	end

	self:InitializePotions()
	self.inst:PushEvent("potion_refilled", self.equipped_potions[MAIN_POTION])
	self.did_potion_fill = true
end

function PotionDrinker:HasRefilledPotionThisRoom()
	return self.did_potion_fill
end

--- Potion Utility Functions
function PotionDrinker:CheckPotions(force)
	if not self.inst:IsLocal() then
		return
	end
	-- There seems to be some init order issues with this where sometimes the potion just doesn't get properly initialized.
	-- For now, the solution is to check for the potion before attempting to access it's data

	if self.equipped_potions == nil then
		self.equipped_potions = {}
	end

	for i, SLOT in ipairs(SLOTS) do
		if not self.equipped_potions[SLOT] or force then 
			self:_SetEquippedPotion(SLOT, self:_GetEquippedPotion(SLOT))
		end
	end
end

function PotionDrinker:GetMaxUses()
	self:CheckPotions()
	local potion_usage_data = self:GetEquippedPotionUsageData(MAIN_POTION)
	return potion_usage_data and potion_usage_data.max_uses or 0
end

function PotionDrinker:GetRemainingPotionUses()
	self:CheckPotions()
	local main_potion_def = self:GetEquippedPotionDef(MAIN_POTION)
	if main_potion_def then
		local potion_uses = self.inst.components.usetracker:GetNumUses(main_potion_def.name)
		return self:GetMaxUses() - potion_uses
	else
		return 0
	end
end

function PotionDrinker:CanGetMorePotionUses()
	local uses_left = self:GetRemainingPotionUses()
	return self:GetMaxUses() > uses_left
end

function PotionDrinker:PotionIsOnCooldown()
	return self.inst.components.timer:HasTimer("potion_cd")
end

function  PotionDrinker:GetRemainingPotionCooldown()
	return self.inst.components.timer:GetTicksRemaining("potion_cd")
end

function PotionDrinker:CanDrinkPotion()

	if TheWorld:HasTag("town") then
		return false
	end

	local canDrink = self:GetRemainingPotionUses() > 0 and not self:PotionIsOnCooldown()
	-- TODO: check gameplay option to allow specific players to have esoteric use cases
	-- like health gain procs for a TBD power?
	local checkHealthAndPotionType = true
	if canDrink and checkHealthAndPotionType then
		-- allow potion drinking if player is not at full health or not single-use healing effect
		-- do allow full health heals if it has a repeat effect (i.e. start a periodic heal before entering battle)

		local can_drink_slot = {}
		for _, v in ipairs(SLOTS) do
			local potion_stats = self:GetEquippedPotionStats(v)
			if potion_stats then
				local doesPotionHeal = false
				local doesPotionHaveOtherTraits = false

				if next(potion_stats) == nil then
					doesPotionHaveOtherTraits = true
				else
					for k,v in pairs(potion_stats) do
						if k == "heal" and v ~= nil then
							doesPotionHeal = true
						else
							doesPotionHaveOtherTraits = true
						end
					end
				end

				local potion_usage_data = self:GetEquippedPotionUsageData(v)
				local doesPotionHaveRepeatEffects = potion_usage_data and potion_usage_data.repeat_duration
				local isPotionSingleUseHeal = doesPotionHeal and not doesPotionHaveOtherTraits and not doesPotionHaveRepeatEffects
				local isPlayerHealthFull = self.inst.components.health:GetPercent() == 1.0

				can_drink_slot[v] = (not isPlayerHealthFull or not isPotionSingleUseHeal)
			end
		end

		for k,v in pairs(can_drink_slot) do
			if can_drink_slot[k] then
				return true
			end
		end

		return false
	end

	return canDrink
end

-- this is not network-synced
function PotionDrinker:_GetEquippedPotion(slot)
	return self.inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots[slot])
end

-- this is network-synced
function PotionDrinker:GetEquippedPotionDef(slot)
	local potion_name = self.inst.components.inventory:GetEquip(Equipment.Slots[slot])
	if potion_name then
		return Equipment.Items[slot][potion_name]
	end
end

-- this is network-synced
function PotionDrinker:GetEquippedPotionUsageData(slot)
	local def = self:GetEquippedPotionDef(slot)
	if def then
		return def.usage_data
	end
end

-- This is network-synced
-- This will need additional work if the local item instance stats can be modified
function PotionDrinker:GetEquippedPotionStats(slot)
	local def = self:GetEquippedPotionDef(slot)
	if def then
		return def.stats
	end
end

return PotionDrinker
