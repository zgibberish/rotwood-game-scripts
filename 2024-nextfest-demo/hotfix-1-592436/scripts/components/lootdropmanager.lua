local Consumable = require "defs.consumable"
local lume = require "util.lume"
local fmodtable = require "defs.sound.fmodtable"
local Recipe = require"defs/recipes"

-- This is a player component that contains persistent data used to decide
-- what loot to drop based on player progression, player's lucky status,
-- the enemy's loot table, etc.
local LootDropManager = Class(function(self, inst)
	self.inst = inst

	self.values = {
		[LOOT_TYPE.s.MONSTER] = {},
	}

    self._clear_mods =  function() self:ClearTemporaryModifiers() end
    self.inst:ListenForEvent("start_new_run", self._clear_mods)
    self.inst:ListenForEvent("end_current_run", self._clear_mods)

	self.global_modifiers = {}

	self.mob_modifiers = {}

	self.loot_drop_threshold = 1
	self.loot_drop_value = 1
end)

function LootDropManager:InitRNG()
	if not self.rng then
		self.rng = CreatePlayerRNG(self.inst, 0x7007D208, "LootDropManager")
	end
end

function LootDropManager:OnPostLoadWorld()
	self:InitRNG()
end

function LootDropManager:GetBiomeID()
	if TheWorld then
		return TheDungeon:GetDungeonMap().data.region_id
	end

	return nil
end

function LootDropManager:ClearTemporaryModifiers()
	self.global_modifiers = {}
	self.mob_modifiers = {}
end

function LootDropManager:ModifyDeltaByProgress(delta)
	local progress_bonus = 1 -- + TheDungeon:GetDungeonMap().nav:GetProgressThroughDungeon()
	return delta * progress_bonus
end

function LootDropManager:ModifyDeltaByAscension(delta)
	local ascension_bonus = 1 + (TheDungeon.progression.components.ascensionmanager:GetCurrentLevel() * 0.1)
	return delta * ascension_bonus
end

-- Global modifiers
function LootDropManager:AddGlobalDeltaModifier(source, modifier)
	if not self.global_modifiers then
		self.global_modifiers = {}
	end
	self.global_modifiers[source] = modifier
end

function LootDropManager:ModifyDeltaByGlobalModifiers(delta)
	if not self.global_modifiers then
		return delta
	end

	local total_mod = 0
	for source,mod in pairs(self.global_modifiers) do
		total_mod = total_mod + mod
	end

	total_mod = 1 + total_mod --If total_mod is meant to be 20%, multiply by 1.2.
	return delta * total_mod
end

-- Mob modifiers
function LootDropManager:AddMobDeltaModifier(source, ent, modifier)
	if not self.mob_modifiers then
		self.mob_modifiers = {}
	end

	if not self.mob_modifiers[ent] then
		self.mob_modifiers[ent] = {}
	end

	self.mob_modifiers[ent][source] = modifier
end

function LootDropManager:RemoveMobDeltaModifier(source, ent)
	assert(self.mob_modifiers[ent], "LootDropManager:RemoveMobDeltaModifier -- trying to remove a modifier which didn't exist")
	self.mob_modifiers[ent][source] = nil
end

function LootDropManager:ModifyDeltaByMobModifiers(delta, ent)
	if not self.mob_modifiers then
		return delta
	end

	local mob = ent.prefab

	local total_mod = 0
	local mods = self.mob_modifiers[mob]
	if mods ~= nil then
		for source,mod in pairs(mods) do
			total_mod = total_mod + mod
		end
	end

	total_mod = 1 + total_mod --If total_mod is meant to be 20%, multiply by 1.2.
	return delta * total_mod
end

---- Delta Loot Drops ----


function LootDropManager:DeltaMonsterDropValue(ent, delta)
	if not self.values[LOOT_TYPE.s.MONSTER][ent.prefab] then
		self.values[LOOT_TYPE.s.MONSTER][ent.prefab] = math.random() * self.loot_drop_threshold
	end
	self.values[LOOT_TYPE.s.MONSTER][ent.prefab] = self.values[LOOT_TYPE.s.MONSTER][ent.prefab] + delta
end

function LootDropManager:SetMonsterDropValue(ent, val)
	-- WIP for modifying the 'reset' drop value based on modifiers, disabling for now.
	-- local val_mod = 1
	-- if self.mob_modifiers[ent.prefab] then
	-- 	for source,mod in pairs(self.mob_modifiers[ent.prefab]) do
	-- 		val_mod = val_mod + mod
	-- 	end
	-- end
	self.values[LOOT_TYPE.s.MONSTER][ent.prefab] = val
end

---- Should Drop Loot? ----

function LootDropManager:IsOverDropThreshold(ent)
	-- print("IsOverDropThreshold?", self.values[LOOT_TYPE.s.MONSTER][ent.prefab], " >= ", self.loot_drop_threshold)
	return self.values[LOOT_TYPE.s.MONSTER][ent.prefab] >= self.loot_drop_threshold
end

function LootDropManager:CanUseAnyDrop(possible_drops)
	if not TheWorld:IsFlagUnlocked("wf_town_has_armorsmith") then
		return false
	end

	local drop_names = {}

	for _, drop_def in ipairs(possible_drops) do
		table.insert(drop_names, drop_def.name)
	end

	drop_names = lume.unique(drop_names)

	local UPGRADE_RECIPES = Recipe.FindRecipesForSlots({"PRICE"})

	for slot, slot_recipes in pairs(UPGRADE_RECIPES) do
		for id, recipe_def in pairs(slot_recipes) do

			local monster_name = id
			monster_name = monster_name:gsub("_upgrade_1", "")
			monster_name = monster_name:gsub("_upgrade_2", "")

			if self.inst.components.unlocktracker:IsRecipeUnlocked(monster_name) then
				for ing, count in pairs(recipe_def.ingredients) do
					if lume.find(drop_names, ing) then
						return true
					end
				end
			end
		end
	end

	return false
end

----

function LootDropManager:OnLootDropperDeath(ent)

	local hasAddedLoot = false

	local value = ent.components.lootdropper:GetLootDropperValue()
	-- TODO: networking2022, victorc- this should use some self.rng

	local delta = value
	-- print("Original delta:", delta)

	if not ent:HasTag("boss") then
		delta = delta + (math.random() * value)
		delta = self:ModifyDeltaByProgress(delta)
	end

	-- print("By progress:", delta)
	delta = self:ModifyDeltaByAscension(delta)
	-- print("By difficulty:", delta)
	delta = self:ModifyDeltaByGlobalModifiers(delta)
	-- print("By global mods:", delta)
	delta = self:ModifyDeltaByMobModifiers(delta, ent)
	-- print("By mob mods:", delta)

	-- TheLog.ch.Loot:printf("loot threshold: %1.3f", self.values[ent.prefab])
	self:DeltaMonsterDropValue(ent, delta)
	if self:IsOverDropThreshold(ent) then
		local possible_drops = self:CollectPossibleLootDrops(ent.components.lootdropper.loot_drop_tags)
		if self:CanUseAnyDrop(possible_drops) then
			hasAddedLoot = true
			local loot_to_drop, lucky_rolls, consumed = self:GenerateLootFromItems(possible_drops, self.values[LOOT_TYPE.s.MONSTER][ent.prefab])
			-- Loot drop values are now set randomly to 0-33% after dropping a piece of loot instead of simply removing the amount of value consumed.
			-- This should make loot drops feel much more "spikey", while still maintaining the intended minimum drop rates.
			self:SetMonsterDropValue(ent, math.random(33) * 0.01)
			-- self:DeltaMonsterDropValue(ent, -consumed)
			ent.components.lootdropper:AddLootToDrop(self.inst, loot_to_drop)

			if next(lucky_rolls) then
				ent.components.lootdropper:AddLuckyLoot(self.inst, lucky_rolls)
			end
		else
			self:SetMonsterDropValue(ent, math.random(33) * 0.01)
		end
	end

	return hasAddedLoot
end

-- ent (i.e. mob enemy) used for non-instanced, immutable data only:
-- prefab (string)
-- loot drop tags via ent.components.lootdropper.loot_drop_tags
function LootDropManager:GenerateLootFromItems(possible_drops, initial_value)
	local consumed = 0
	local rolled_drops = {}
	local luck_drops = {}
	local num_tries = initial_value * 3

	self:InitRNG() -- try init here in case we receive early loot events before OnPostLoadWorld is run

	while(initial_value >= self.loot_drop_threshold) and num_tries > 0 do
		-- printf("%s dropped some loot!", ent.prefab)
		num_tries = num_tries - 1

		local weighted_drops = {}
		for _, def in ipairs(possible_drops) do
			weighted_drops[def.name] = def.weight
		end
		-- printf("rolled rarity: %s", rarity)
		local drop = self.rng:WeightedChoice(weighted_drops)
		if drop then
			-- printf("---added %s to drops", drop)
			if not rolled_drops[drop] then
				rolled_drops[drop] = 0
			end
			rolled_drops[drop] = rolled_drops[drop] + 1
			if self.inst.components.lucky and self.inst.components.lucky:DoLuckRoll() then
				if not luck_drops[drop] then
					luck_drops[drop] = 0
				end
				luck_drops[drop] = luck_drops[drop] + 1
				--sound
				local soundutil = require "util.soundutil"
				local params = {}
				params.fmodevent = fmodtable.Event.lucky
				params.sound_max_count = 1
				soundutil.PlaySoundData(self.inst, params)
			end

			initial_value = initial_value - self.loot_drop_value
			consumed = consumed + 1
		else
			-- print("!!!!!!had nothing to add to drop!")
		end
	end

	return rolled_drops, luck_drops, consumed
end

function LootDropManager:CollectPossibleLootDrops(loot_tags)
	local loot = {}
	for _, tags in ipairs(loot_tags) do
		loot = lume.concat(loot, Consumable.GetItemList(Consumable.Slots.MATERIALS, tags))
	end
	return loot
end

function LootDropManager:OnSave()
	local data = {}
	if self.values ~= nil and next(self.values) then
		data.values = self.values
	end
	if self.global_modifiers ~= nil and next(self.global_modifiers) then
		data.global_modifiers = self.global_modifiers
	end

	if self.mob_modifiers ~= nil and next(self.mob_modifiers) then
		data.mob_modifiers = self.mob_modifiers
	end

	if data then
		return data
	end
end

function LootDropManager:OnLoad(data)
	if data ~= nil then
		self.values = data.values
		self.global_modifiers = data.global_modifiers
		self.mob_modifiers = data.mob_modifiers
	end
end

return LootDropManager
