local Power = require "defs.powers"
local lume = require "util.lume"

--[[
	Intent of the component:

	Handles rolling for powers for the player.
	Has bad luck protection built in, and helps to smooth out "dry streaks" of not seeing anything good.
		Bad luck protection should be saved between runs.
		When a roll is done, increase the weights of everything that did not drop by a %.
		Over time, this should ensure that the rarest stuff actually drops somewhat reliably.
--]]

local krandom = require "util.krandom"

local LootRoller = Class(function(self, inst)
	self.inst = inst

    self._new_run_fn =  function() self:ResetAllLootChancesPercent() end
    self.inst:ListenForEvent("start_new_run", self._new_run_fn)

	self.loot_data_weighted = {}
	self.loot_data_percent = {}
end)

function LootRoller:OnPostLoadWorld()
	self.rng = CreatePlayerRNG(self.inst, 0x70072077, "LootRoller")
end


-- WEIGHTED VERSION:

function LootRoller:SumWeights(id, choices)
	local total = 0
	for choice, weight in pairs(choices) do
		local tweaked_weight = weight + self.loot_data_weighted[id][choice]
		dbassert(tweaked_weight >= 0, "Weights must be nonnegative.")
		total = total + tweaked_weight
	end
	dbassert(total >= 0, "Weights should sum to 0.")
	return total
end

function LootRoller:ValidateDataWeighted(id, choices)
	local wipe_data = false
	local has_data = self.loot_data_weighted[id] ~= nil
	if has_data then
		for choice, weight in pairs(choices) do
			if not self.loot_data_weighted[id][choice] then
				wipe_data = true
			end
		end
	end

	if wipe_data then
		self.loot_data_weighted[id] = nil
		has_data = false
	end

	if not has_data then
		self:AddNewLootDataWeighted(id, choices)
	end
end

function LootRoller:AddNewLootDataWeighted(id, choices)
	self.loot_data_weighted[id] = {}
	for choice, weight in pairs(choices) do
		self.loot_data_weighted[id][choice] = 0
	end
end

function LootRoller:DoLootRollWeighted(id, choices)
	-- TODO: victorc, random - This iteration is not deterministic but it's also unused
	dbassert(false)

	self:ValidateDataWeighted(id, choices)

	-- basic logic for roll taken from krandom.WeightedChoice
	local total = self:SumWeights(id, choices)
	local threshold = self.rng:Float(total)
	printf("LootRoller:DoLootRollWeighted %s, %s", total, threshold)
	local last_choice
	local picked_choice
	for choice, weight in pairs(choices) do
		if picked_choice then break end
		local tweaked_weight = weight + self.loot_data_weighted[id][choice]
		printf("-Rolling for %s, (%s + %s = %s)", choice, weight, self.loot_data_weighted[id][choice], tweaked_weight)
		threshold = threshold - tweaked_weight
		if threshold <= 0 and not picked_choice then
			-- printf("--Picked Choice: %s", choice)
			picked_choice = choice
		end
		last_choice = choice
	end

	if not picked_choice then
		picked_choice = last_choice
	end

	for choice, weight in pairs(choices) do
		if choice ~= picked_choice then
			-- increase the weights of everything that didn't drop
			self:IncreaseLootChanceWeighted(id, choice, weight)
		else
			-- reset the weights of what did drop
			self:ResetLootChanceWeighted(id, choice)
		end
	end

	return picked_choice
end

function LootRoller:IncreaseLootChanceWeighted(id, choice, base_weight)
	printf("LootRoller:IncreaseLootChance(%s, %s, %s)", id, choice, base_weight)
	self.loot_data_weighted[id][choice] = self.loot_data_weighted[id][choice] + (base_weight * 0.1)
	printf("--- %s: %s", choice, self.loot_data_weighted[id][choice])
end

function LootRoller:ResetLootChanceWeighted(id, choice)
	printf("LootRoller:ResetLootChance(%s, %s)", id, choice)
	self.loot_data_weighted[id][choice] = 0
end

--------

-- PERCENT VERSION:

function LootRoller:ValidateDataPercent(id, choices)
	local wipe_data = false
	local has_data = self.loot_data_percent[id] ~= nil
	if has_data then
		for choice, percent in pairs(choices) do
			if not self.loot_data_percent[id][choice] then
				wipe_data = true
			end
		end
	end

	if wipe_data then
		self.loot_data_percent[id] = nil
		has_data = false
	end

	if not has_data then
		self:AddNewLootDataPercent(id, choices)
	end
end

function LootRoller:AddNewLootDataPercent(id, choices)
	self.loot_data_percent[id] = {}
	for choice, percent in pairs(choices) do
		self.loot_data_percent[id][choice] = 0
	end
end

function LootRoller:SumPercents(id, choices)
	local total = 0
	for choice, percentage in pairs(choices) do
		local tweaked_percentage = percentage + self.loot_data_percent[id][choice]
		total = total + tweaked_percentage
	end
	dbassert(total == 100, "Percents should sum to 100.")
	return total
end


function LootRoller:DoLootRollPercent(id, choices, idxtable, bankchoice)
	self:ValidateDataPercent(id, choices)

	local total = self:SumPercents(id, choices)
	local roll = total - self.rng:Float(total)
	-- printf("LootRoller:DoLootRollPercent %s, %s", total, roll)
	local last_choice
	local picked_choice

	local previous_percentage = 0
	for i, rarity in ipairs(idxtable) do
		if picked_choice then break end
		local rarity_percentage = choices[rarity]
		local tweaked_percentage = rarity_percentage + self.loot_data_percent[id][rarity]
		-- printf("-Rolling for %s, (%s + %s = %s)", rarity, rarity_percentage, self.loot_data_percent[id][rarity], tweaked_percentage)
		if roll <= (tweaked_percentage + previous_percentage) and not picked_choice then
			-- printf("--Picked Choice: %s", rarity)
			picked_choice = rarity
		end
		last_choice = rarity
		previous_percentage = tweaked_percentage
	end

	if not picked_choice then
		picked_choice = last_choice
	end

	local lucky = false
	if picked_choice ~= idxtable[1] and self.inst.components.lucky and self.inst.components.lucky:DoLuckRoll() then
		local picked_idx = lume.find(idxtable, picked_choice)
		picked_choice = idxtable[picked_idx - 1]
		lucky = true
	end

	for choice, weight in pairs(choices) do
		if choice ~= picked_choice then
			-- increase the weights of everything that didn't drop
			self:IncreaseLootChancePercent(id, choice, bankchoice)
		else
			-- reset the weights of what did drop
			self:ResetLootChancePercent(id, choice, bankchoice)
		end
	end

	return picked_choice, lucky
end

function LootRoller:IncreaseLootChancePercent(id, choice, bankchoice)
	if choice ~= bankchoice then
		local worldmap = TheDungeon:GetDungeonMap()
		local difficulty = math.clamp(worldmap:GetDifficultyForCurrentRoom(), 1, 3)
		-- printf("LootRoller:IncreaseLootChancePercent(%s, %s). Subtracting from [%s]", id, choice, bankchoice)
		self.loot_data_percent[id][choice] = self.loot_data_percent[id][choice] + TUNING.POWERS.DROP_CHANCE_INCREASE[difficulty][choice]
		self.loot_data_percent[id][bankchoice] = self.loot_data_percent[id][bankchoice] - TUNING.POWERS.DROP_CHANCE_INCREASE[difficulty][choice]
		-- printf("- INCREASED: %s: %s (+%s)", choice, self.loot_data_percent[id][choice], TUNING.POWERS.DROP_CHANCE_INCREASE[difficulty][choice])
		-- printf("- DECREASED: %s: %s (-%s)", bankchoice, self.loot_data_percent[id][bankchoice], TUNING.POWERS.DROP_CHANCE_INCREASE[difficulty][choice])
	end
end

function LootRoller:ResetLootChancePercent(id, choice, bankchoice)
	if choice ~= bankchoice then
		self.loot_data_percent[id][bankchoice] = self.loot_data_percent[id][bankchoice] + self.loot_data_percent[id][choice]
		self.loot_data_percent[id][choice] = 0
		-- printf("LootRoller:ResetLootChancePercent(%s) [%s -> %s] [%s -> %s]", id, choice, self.loot_data_percent[id][choice], bankchoice, loot_data_percent.loot_data[id][bankchoice])
	end
end

function LootRoller:ResetAllLootChancesPercent(id)
	-- print("Resetting Loot Chances...")
	-- print("BEFORE:")
	-- dumptable(self.loot_data_percent)
	for drop_id, v in pairs(self.loot_data_percent) do
		for choice, bonus in pairs(self.loot_data_percent[drop_id]) do
			self.loot_data_percent[drop_id][choice] = 0
		end
	end
	-- print("AFTER:")
	-- dumptable(self.loot_data_percent)
	-- print("--")
end

--------

function LootRoller:OnSave()
	local data = nil
	if next(self.loot_data_weighted) then
		data = { loot_data_weighted = self.loot_data_weighted }
	end
	if next(self.loot_data_percent) then
		data = { loot_data_percent = self.loot_data_percent }
	end
	return data
end

function LootRoller:OnLoad(data)
	if data and data.loot_data_weighted then
		self.loot_data_weighted = shallowcopy(data.loot_data_weighted)
	end
	if data and data.loot_data_percent then
		self.loot_data_percent = shallowcopy(data.loot_data_percent)
	end
end

return LootRoller
