local Power = require "defs.powers"
local lume = require "util.lume"

--[[
	Intent of the component:

	Handles rolling for powers for all the players.

	Paces delivery of big powers so that big power spikes happen at desired times (typically further into the run).

	Has bad luck protection built in, and helps to smooth out "dry streaks" of not seeing anything good.
		When a roll is done, increase the weights of everything that did not drop by a %.
		Over time, this should ensure that the rarest stuff actually drops somewhat reliably.
--]]

local function create_default_seen_data()
	local data =
	{
	}

	for _, slot in pairs(Power.Slots) do
		data[slot] = {}
	end

	return data
end

local krandom = require "util.krandom"

local PowerRoller = Class(function(self, inst)
	self.inst = inst

    self._new_run_fn =  function()
    	self:ResetAllPowerChances()
    	self:ResetAllSeenPowers()
    	-- self:CreateRNGs()
	end
    self.inst:ListenForEvent("start_new_run", self._new_run_fn, TheDungeon)

    self.player_rngs = {}

	self.power_data = {} -- Each player's individual chances of dropping various power types: chances of Common, Epic, Legendary. Changes over time based on choices.
	self.seen_data = create_default_seen_data() -- What powers each individual player has drawn. If a power has been drawn for a player once, that power can no longer be presented as that player.
end)

function PowerRoller:GetRNG(player)
	local playerID = player.Network:GetPlayerID() + 1

	local rng
	if self.player_rngs[playerID] then
		rng = self.player_rngs[playerID]
	else
		self.player_rngs[playerID] = CreatePlayerRNG(player, 0x70C41F0F, "PowerRoller")
		rng = self.player_rngs[playerID]
	end
	return rng
end

function PowerRoller:AddSeenPower(player, name, slot)
	local playerID = player.Network:GetPlayerID() + 1

	if not self.seen_data[slot][name] then
		self.seen_data[slot][name] = {}
	end
	self.seen_data[slot][name][playerID] = true
end

function PowerRoller:HasSeenPower(player, power_def)
	local playerID = player.Network:GetPlayerID() + 1

	return self.seen_data[power_def.slot][power_def.name] ~= nil and self.seen_data[power_def.slot][power_def.name][playerID] ~= nil
end

function PowerRoller:ValidateData(type, choices)
	local wipe_data = false
	local has_data = self.power_data[type] ~= nil
	if has_data then
		for choice, percent in pairs(choices) do
			if not self.power_data[type][choice] then
				wipe_data = true
			end
		end
	end

	if wipe_data then
		self.power_data[type] = nil
		has_data = false
	end

	if not has_data then
		self:AddNewPowerData(type, choices)
	end
end

function PowerRoller:AddNewPowerData(type, choices)
	self.power_data[type] = {}
	for choice, percent in pairs(choices) do
		self.power_data[type][choice] = 0
	end
end

function PowerRoller:SumPercents(type, choices)
	local total = 0
	for choice, percentage in pairs(choices) do
		local tweaked_percentage = percentage + self.power_data[type][choice]
		total = total + tweaked_percentage
	end
	dbassert(total == 100, "Percents should sum to 100.")
	return total
end


function PowerRoller:DoPowerRoll(player, type, choices, idxtable, bankchoice)
	self:ValidateData(type, choices)

	local rng = self:GetRNG(player)

	local total = self:SumPercents(type, choices)
	local roll = total - rng:Float(total)
	-- printf("PowerRoller:DoPowerRoll %s, %s", total, roll)
	local last_choice
	local picked_choice

	local previous_percentage = 0
	for i, rarity in ipairs(idxtable) do
		if picked_choice then break end
		local rarity_percentage = choices[rarity]
		local tweaked_percentage = rarity_percentage + self.power_data[type][rarity]
		-- printf("-Rolling for %s, (%s + %s = %s)", rarity, rarity_percentage, self.power_data[type][rarity], tweaked_percentage)
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
			self:IncreasePowerChance(type, choice, bankchoice)
		else
			-- reset the weights of what did drop
			self:ResetPowerChance(type, choice, bankchoice)
		end
	end

	return picked_choice, lucky
end

function PowerRoller:IncreasePowerChance(type, choice, bankchoice)
	if choice ~= bankchoice then
		local worldmap = TheDungeon:GetDungeonMap()
		local difficulty = math.clamp(worldmap:GetDifficultyForCurrentRoom(), 1, 3)
		-- printf("PowerRoller:IncreasePowerChance(%s, %s). Subtracting from [%s]", type, choice, bankchoice)
		self.power_data[type][choice] = self.power_data[type][choice] + TUNING.POWERS.DROP_CHANCE_INCREASE[difficulty][choice]
		self.power_data[type][bankchoice] = self.power_data[type][bankchoice] - TUNING.POWERS.DROP_CHANCE_INCREASE[difficulty][choice]
		-- printf("- INCREASED: %s: %s (+%s)", choice, self.power_data[type][choice], TUNING.POWERS.DROP_CHANCE_INCREASE[difficulty][choice])
		-- printf("- DECREASED: %s: %s (-%s)", bankchoice, self.power_data[type][bankchoice], TUNING.POWERS.DROP_CHANCE_INCREASE[difficulty][choice])
	end
end

function PowerRoller:ResetPowerChance(type, choice, bankchoice)
	if choice ~= bankchoice then
		self.power_data[type][bankchoice] = self.power_data[type][bankchoice] + self.power_data[type][choice]
		self.power_data[type][choice] = 0
		-- printf("PowerRoller:ResetPowerChance(%s) [%s -> %s] [%s -> %s]", type, choice, self.power_data[type][choice], bankchoice, power_data.power_data[type][bankchoice])
	end
end

function PowerRoller:ResetAllPowerChances()
	-- print("Resetting Loot Chances...")
	-- print("BEFORE:")
	-- dumptable(self.power_data)
	for drop_id, v in pairs(self.power_data) do
		for choice, bonus in pairs(self.power_data[drop_id]) do
			self.power_data[drop_id][choice] = 0
		end
	end
end

function PowerRoller:ResetAllSeenPowers()
	self.seen_data = create_default_seen_data()
end

--------

function PowerRoller:OnSave()
	local data = nil
	if next(self.power_data) then
		data = { power_data = self.power_data }
	end

	if next(self.seen_data) then
		if not data then
			data = { seen_data = self.seen_data }
		else
			data.seen_data = self.seen_data
		end
	end
	return data
end

function PowerRoller:OnLoad(data)
	if data then
		if data.power_data then
			self.power_data = shallowcopy(data.power_data)
		end
		if data.seen_data then
			self.seen_data = shallowcopy(data.seen_data)
		end
	end
end

return PowerRoller
