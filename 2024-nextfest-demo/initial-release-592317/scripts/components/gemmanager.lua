local mapgen = require "defs.mapgen"
local krandom = require "util.krandom"
local LootEvents = require "lootevents"
local lume = require "util.lume"
local Equipment = require "defs.equipment"
local itemforge = require "defs.itemforge"
local EquipmentGem = require "defs.equipmentgems.equipmentgem"
-- local prefabutil = require "prefabs.prefabutil"
require "util.tableutil"

-- Every mob gives all equipped gems some XP, based on Max Health
local mobhealth_to_xp =
{
	-- mob max health, gem XP for killing this mob

	-- jambell:
	-- This list is a bit designed... killing 3 mothballs is not the same effort as killing 1 Cabbage Roll, so shouldn't necessarily give the same XP.
	-- I don't -think- a simple linear / exponential / logarithmic expression would give the right feel here.
	{0,		0 },
	{75,	1 }, -- Moth Ball
	{300,	3 }, -- Cabbage Roll
	{500, 	5 }, -- Blarmadillo
	{1000, 	10 }, -- Zucco
	{1500,  15 }, -- Yammo

	-- Elites typically live above this line
	-- Minibosses: (normal elites will eventually sneak up here... this should be on "BASE" health, not biome-modified health if that system ever exists.)
	{2250,  25 }, -- Elite Yammo (miniboss 1)
	{5000,  25 }, -- Elite Gourdo (miniboss 2)

	-- Bosses:
	{17000,  50 }, -- Megatreemon
	-- Let's try: Bosses should all give the same XP... anything up here and above is capped out.
}

local EquipmentGemManager = Class(function(self, inst)
	self.inst = inst

	self._onkill = function(inst, data) self:_OnKill(data) end

    self.inst:ListenForEvent("kill", self._onkill)
end)

function EquipmentGemManager:GiveGem(def)
	local gem = self:MakeGem(def)
	self.inst.components.inventoryhoard:AddToInventory(def.slot, gem)
end

function EquipmentGemManager:MakeGem(def)--, rarity)
	local gem = itemforge.CreateEquipment(def.slot, def)
	gem.exp = 0

	self:CreateUpdateThresholds(gem, def)

	return gem
end

function EquipmentGemManager:GetGemInSlot(slot_number)
	local equipped_weapon = self.inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)
	return equipped_weapon.gem_slots[slot_number].gem
end

function EquipmentGemManager:EquipGem(gem, slot_number)
	local equipped_weapon = self.inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)
	local gem_def = gem:GetDef()

	assert(equipped_weapon.gem_slots[slot_number].slot_type == gem_def.gem_type or equipped_weapon.gem_slots[slot_number].slot_type == EquipmentGem.Type.ANY, "Trying to force a gem into a slot that it doesn't support.")
	assert(equipped_weapon.gem_slots[slot_number].gem == nil, "Trying to force a gem into a slot that already has a gem equipped. Unequip first!")

	self.inst.components.inventoryhoard:RemoveFromInventory(gem)
	equipped_weapon.gem_slots[slot_number].gem = gem

	self:UpdateWeaponStats()
end

function EquipmentGemManager:UnequipGem(slot_number)
	local equipped_weapon = self.inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)

	local gem = self:GetGemInSlot(slot_number)

	if gem then
		self.inst.components.inventoryhoard:AddToInventory(gem.slot, gem)
	end

	equipped_weapon.gem_slots[slot_number].gem = nil

	self:UpdateWeaponStats()
end

function EquipmentGemManager:ClearAllSlots()
	local equipped_weapon = self.inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)

	for i,slot in ipairs(equipped_weapon.gem_slots) do
		equipped_weapon.gem_slots[i].gem = nil
	end

	self:UpdateWeaponStats()
end

function EquipmentGemManager:_OnKill(data)
	local enemy = data.attack:GetTarget()
	local max_health = enemy.components.health:GetMax()
	local xp = PiecewiseFn(max_health, mobhealth_to_xp)
	xp = lume.round(xp)

	local isbadnumber = isbadnumber(xp)
	if isbadnumber then
		-- Gems that have non-
		local debug_data =
		{
			xp = xp,
			maxhealth = max_health,
			mobhealth_to_xp = mobhealth_to_xp,
		}
		dumptable(debug_data)
		dumptable(data)
		assert(false, "Something went wrong with giving XP to gems! Please send 'clipboard' to jambell.")
	end

	self:ApplyXP(xp)
	-- self:AddToLog(xp, enemy)
end

function EquipmentGemManager:ApplyXP(xp)
	local equipped_weapon = self.inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)

	if equipped_weapon.gem_slots ~= nil then
		for i,slot in ipairs(equipped_weapon.gem_slots) do
			local gem = slot.gem
			if gem then
				local def = gem:GetDef()
				local target_exp = def.base_exp[gem.ilvl]
				gem.exp = gem.exp + xp

				if gem.exp >= target_exp then
					
					-- If the gem can level up, do so.

					if gem.ilvl < def.max_ilvl then
						gem:SetItemLevel(gem.ilvl + 1)
						gem.exp = gem.exp - target_exp
						self:UpdateWeaponStats()
						self:NotifyLevelUp(gem)
					else
					
						-- If already max level, just cap the experience there.

						gem.exp = target_exp
					end
				else
					self:NotifyProgress(gem)
				end
			end
		end
	end
end

function EquipmentGemManager:CreateUpdateThresholds(gem, def)
	local thresholds
	if def.update_thresholds then
		thresholds = def.update_thresholds
	else
		thresholds = TUNING.GEM_DEFAULT_UPDATE_THRESHOLDS
	end

	gem.update_thresholds = {}

	for _,threshold in ipairs(def.update_thresholds) do
		table.insert(gem.update_thresholds, { threshold = threshold, updated = false })
	end
end

function EquipmentGemManager:NotifyLevelUp(gem)
	local def = gem:GetDef()
	local target_exp = def.base_exp[gem.ilvl]

	-- TEMP: NOTIFY PROGRESS
	local popup_data =
	{
		target = self.inst,
		gem = gem,
		fade_time = 5,
		-- offset_x = 0,
		y_offset = 300,
		levelup = true,
	}
	local popup = TheDungeon.HUD:MakePopGem(popup_data)

	for _,threshold in ipairs(gem.update_thresholds) do
		threshold.updated = false
	end
end

function EquipmentGemManager:NotifyProgress(gem)
	local def = gem:GetDef()
	local target_exp = def.base_exp[gem.ilvl]

	local exp = gem.exp

	local progress = exp / target_exp

	if gem.update_thresholds == nil then
		-- In case the gem was created before we had gem thresholds.
		self:CreateUpdateThresholds(gem, def)
	end

	for _,threshold_data in ipairs(gem.update_thresholds) do
		local threshold = threshold_data.threshold
		local already_updated = threshold_data.updated

		if progress >= threshold and not already_updated then
			-- TEMP: NOTIFY PROGRESS
			local popup_data =
			{
				target = self.inst,
				gem = gem,
				fade_time = 3,
				-- offset_x = 0,
				y_offset = 300,
			}
			local popup = TheDungeon.HUD:MakePopGem(popup_data)
			threshold_data.updated = true
		end
	end
end

function EquipmentGemManager:UpdateWeaponStats()
	local equipped_weapon = self.inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)

	equipped_weapon:RefreshItemStats()
	self.inst.components.inventoryhoard:EquipSavedEquipment() --TODO: better way to update stats
end

function EquipmentGemManager:AddToLog(amount, source)
	local tbl = self:GetLog()

	local worldmap = TheDungeon:GetDungeonMap()
	local dungeon_progress = worldmap.nav:GetProgressThroughDungeon()
	local rewardtype = worldmap:GetRewardForCurrentRoom()
	local difficulty = TheDungeon:GetDungeonMap():GetDifficultyForCurrentRoom()
	local diff_name = mapgen.Difficulty:FromId(difficulty)

	if tbl.total == nil then
		tbl.total = 0
	end
	if tbl[dungeon_progress] == nil then
		tbl[dungeon_progress] = {}

		tbl[dungeon_progress].roomdata = {}
		tbl[dungeon_progress].roomdata.difficulty = diff_name
		tbl[dungeon_progress].roomdata.rewardtype = rewardtype
		tbl[dungeon_progress].roomdata.total = 0
		tbl[dungeon_progress].entries = {}
	end

	local data =
	{
		amount = amount,
		source = source,
	}

	tbl.total = tbl.total + amount

	tbl[dungeon_progress].roomdata.total = tbl[dungeon_progress].roomdata.total + amount
	table.insert(tbl[dungeon_progress].entries, data)

	TheSaveSystem.progress.dirty = true
end

function EquipmentGemManager:GetLog()
	local log = TheSaveSystem.progress:GetValue("konjur_debug")
	if log == nil then
		TheSaveSystem.progress:SetValue("konjur_debug", {})
		log = TheSaveSystem.progress:GetValue("konjur_debug")
	end

	return log
end

return EquipmentGemManager
