local SpecialEventRoom = require("defs.specialeventrooms")

local SupportChanceModification = true

local MysteryManager = Class(function(self, inst)
	self.inst = inst
	self.mystery_data = {}
end)

MysteryManager.Choices =
-- Tuning percentage values in TUNING.MYSTERIES.ROOMS
{
	[1] = 'monster',
	[2] = 'potion',
	[3] = 'powerupgrade',
	[4] = 'wanderer',
	-- [5] = 'ranger',
}
--------

MysteryManager.LoggingEnabled = true

function MysteryManager:Log(...)
	if MysteryManager.LoggingEnabled then
		TheLog.ch.MysteryManager:printf(...)
	end
end

function MysteryManager:ValidateData(id, choices)
	local wipe_data = false
	local has_data = self.mystery_data[id] ~= nil
	if has_data then
		for choice, percent in pairs(choices) do
			if not self.mystery_data[id][choice] then
				wipe_data = true
			end
		end
	end

	if wipe_data then
		self.mystery_data[id] = nil
		has_data = false
	end

	if not has_data then
		self:AddNewMysteryData(id, choices)
	end
end

function MysteryManager:AddNewMysteryData(id, choices)
	self.mystery_data[id] = {}
	for choice, percent in pairs(choices) do
		self.mystery_data[id][choice] = 0
	end
end

function MysteryManager:SumPercents(id, choices)
	local total = 0
	for choice, percentage in pairs(choices) do
		local tweaked_percentage = percentage + self.mystery_data[id][choice]
		total = total + tweaked_percentage
	end
	dbassert(total == 100, "Percents should sum to 100.")
	return total
end

function MysteryManager:DoMysteryRoll(id, choices, bankchoice, rng)
	self:ValidateData(id, choices)

	local total = self:SumPercents(id, choices)
	local roll = total - rng:Float(total)
	self:Log("DoMysteryRoll %s, %s", total, roll)
	local last_choice
	local picked_choice

	local previous_percentage = 0
	for i, mystery in ipairs(MysteryManager.Choices) do
		if picked_choice then break end
		local chance = choices[mystery]
		local tweaked_percentage = chance + self.mystery_data[id][mystery]
		self:Log("-Rolling for %s, (%s + %s = %s)", mystery, chance, self.mystery_data[id][mystery], tweaked_percentage)
		if roll <= (tweaked_percentage + previous_percentage) and not picked_choice then
			self:Log("--Picked Choice: %s", mystery)
			picked_choice = mystery
		end
		last_choice = mystery
		previous_percentage = tweaked_percentage
	end

	if not picked_choice then
		picked_choice = last_choice
	end

	for choice, percent in pairs(choices) do
		if choice ~= picked_choice then
			-- increase the percents of everything that didn't drop
			self:IncreaseMysteryChance(id, choice, bankchoice)
		else
			-- reset the percents of what did drop
			self:ResetMysteryChance(id, choice, bankchoice)
		end
	end

	return picked_choice
end

function MysteryManager:IncreaseMysteryChance(id, choice, bankchoice)
	if SupportChanceModification and choice ~= bankchoice then
		self:Log("IncreaseMysteryChance(%s, %s). Subtracting from [%s]", id, choice, bankchoice)
		self.mystery_data[id][choice] = self.mystery_data[id][choice] + TUNING.MYSTERIES.ROOMS.CHANCE_INCREASE[choice]
		self.mystery_data[id][bankchoice] = self.mystery_data[id][bankchoice] - TUNING.MYSTERIES.ROOMS.CHANCE_INCREASE[choice]
		self:Log("- INCREASED: %s: %s (+%s)", choice, self.mystery_data[id][choice], TUNING.MYSTERIES.ROOMS.CHANCE_INCREASE[choice])
		self:Log("- DECREASED: %s: %s (-%s)", bankchoice, self.mystery_data[id][bankchoice], TUNING.MYSTERIES.ROOMS.CHANCE_INCREASE[choice])
	end
end

function MysteryManager:ResetMysteryChance(id, choice, bankchoice)
	if SupportChanceModification and choice ~= bankchoice then
		self.mystery_data[id][bankchoice] = self.mystery_data[id][bankchoice] + self.mystery_data[id][choice]
		self.mystery_data[id][choice] = 0
		-- printf("MysteryManager:ResetMysteryChance(%s) [%s -> %s] [%s -> %s]", id, choice, self.mystery_data[id][choice], bankchoice, mystery_data.loot_data[id][bankchoice])
	end
end

function MysteryManager:ResetAllMysteryChances()
	self:Log("Resetting Loot Chances...")
	self:Log("BEFORE:")
	if MysteryManager.LoggingEnabled then
		dumptable(self.mystery_data)
	end
	for drop_id, v in pairs(self.mystery_data) do
		for choice, bonus in pairs(self.mystery_data[drop_id]) do
			self.mystery_data[drop_id][choice] = 0
		end
	end
	self:Log("AFTER:")
	if MysteryManager.LoggingEnabled then
		dumptable(self.mystery_data)
	end
	self:Log("--")
end

function MysteryManager:GetMonsterDifficulty(rng)
	local choice = rng:WeightedChoice(TUNING.MYSTERIES.MONSTER_CHANCES.DIFFICULTIES)
	return choice
end
function MysteryManager:GetMonsterReward(difficulty, rng)
	local choice = rng:WeightedChoice(TUNING.MYSTERIES.MONSTER_CHANCES.REWARDS[difficulty])
	return choice
end

-------------------- SPECIALEVENTROOM EVENT SELECTION --------------------

-- These live in here so that we can pre-select the specialeventroom while leaving a room, rather than on entering a room. 
-- This means we can assess prerequisites reliably AND tell networked players what room we'll be loading sooner.

function MysteryManager:GetRandomEventByType(rng, type)
	local possibleevents = {}

	for eventname,eventdata in pairs(SpecialEventRoom.Events) do
		if eventdata.category == type then
			if eventdata.prerequisite_fn == nil or eventdata.prerequisite_fn(self.inst, AllPlayers) then
				possibleevents[eventname] = eventdata
			end
		end
	end
	local pick = rng:PickValue(possibleevents)
	return pick
end

--------

function MysteryManager:SaveData()
	if not SupportChanceModification then
		return
	end

	local data = nil
	if next(self.mystery_data) then
		self:Log("Saving Data...")
		data = deepcopy(self.mystery_data)
	else
		self:Log("No data to save.")
	end
	return data
end

function MysteryManager:LoadData(data)
	if not SupportChanceModification then
		return
	end

	if data then
		self:Log("Loading Data...")
		self.mystery_data = deepcopy(data)
	else
		self:Log("No data to load.")
	end
end

return MysteryManager
