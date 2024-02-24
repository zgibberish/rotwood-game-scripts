-- A shuffled "deck" of encounters.

local mapgen = require "defs.mapgen"
local lume = require "util.lume"
local encounters = require "encounter.encounters"

local EncounterDeck = Class(function(self, rng, location, room_type_encounter_sets)
	self.rng = rng
	self.location = location
	self.room_type_encounter_sets = room_type_encounter_sets

	-- If we are not restoring encounter_sets from a save, regenerate shuffled lists of encounter names.
	if not self.room_type_encounter_sets then
		self.room_type_encounter_sets = {}
		for room_type, difficulty_encounters in pairs(encounters.GetRoomTypeEncounters(location)) do
			self.room_type_encounter_sets[room_type] = {}
			for _, difficulty in ipairs(mapgen.Difficulty:Ordered()) do
				local encounter_set = {names = {}}
				self.room_type_encounter_sets[room_type][difficulty] = encounter_set
				local named_encounters = difficulty_encounters[difficulty]
				if named_encounters then
					local named_encounters_count = lume(named_encounters):count():result()
					for name, encounter in pairs(named_encounters) do
						local count = 1
						if encounter.factor then
							count = math.ceil(encounter.factor * named_encounters_count)
						end
						for i = 1, count do
							table.insert(encounter_set.names, name)
						end
					end
					self.rng:Shuffle(encounter_set.names)
					encounter_set.next = next(encounter_set.names)
				end
			end
		end
	end
end)

-- Return the next encounter in the deck that passes its constraint_fn. If the deck is empty, or no encounters in it
-- pass (i.e. it is effectively empty, return nil).
function EncounterDeck:_Draw(spawn_coordinator, encounter_set, named_encounters)
	if not encounter_set.next then
		return nil
	end
	local deck = lume(encounter_set.names):slice(encounter_set.next):result()
	for i, encounter_name in ipairs(deck) do
		local encounter = named_encounters[encounter_name]
		dbassert(encounter, encounter_name)
		if not encounter.constraint_fn or encounter.constraint_fn(spawn_coordinator) then
			local encounter_index = encounter_set.next + i - 1
			if i ~= 1 then
				-- Remove the encounter from the deck and re-shuffle.
				table.remove(deck, i)
				self.rng:Shuffle(deck)

				-- Add the chosen encounter to the back of the discard.
				local discard = lume(encounter_set.names):slice(1, encounter_set.next - 1):result()
				table.insert(discard, encounter_set.names[encounter_index])
				encounter_index = #discard

				-- Stitch the discard and deck back together.
				encounter_set.names = table.appendarrays({}, discard, deck)
			end
			encounter_set.next = next(encounter_set.names, encounter_index)
			return encounter_index
		end
	end
	return nil
end

-- Shuffle the discard and deck into a new deck.
function EncounterDeck:_Shuffle(encounter_set)
	self.rng:Shuffle(encounter_set.names)
	encounter_set.next = next(encounter_set.names)
end

-- Return name, encounter tuple of the next encounter in the shuffled deck for the specified room_type and difficulty.
function EncounterDeck:Draw(spawn_coordinator, room_type, difficulty_index)
	if not room_type then
		return nil
	end

	local difficulty = mapgen.Difficulty:FromId(difficulty_index)
	local encounter_set = self.room_type_encounter_sets[room_type][difficulty]

	local named_encounters = encounters.GetRoomTypeEncounters(self.location)[room_type][difficulty]
	local encounter_index = self:_Draw(spawn_coordinator, encounter_set, named_encounters)

	-- If we've drawn through our entire deck, re-shuffle.
	if not encounter_index then
		self:_Shuffle(encounter_set)
		encounter_index = self:_Draw(spawn_coordinator, encounter_set, named_encounters)

		-- If we still cannot draw after shuffling, our deck is effectively empty.
		if not encounter_index then
			return nil
		end
	end

	local encounter_name = encounter_set.names[encounter_index]
	local encounter = named_encounters[encounter_name]
	TheLog.ch.Spawn:printf("Next encounter %s.%s.%s.%s", self.location, room_type, difficulty, encounter_name)
	return encounter_name, encounter.exec_fn
end

return EncounterDeck
