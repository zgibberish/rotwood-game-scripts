-- lives on the world, and manages quest marks
-- every player should be aware of what quests other players are on
-- this component collects all of the requested marks for players in the session
-- and then creates and manages the marks that appear above NPCs, objects, and world locations.
local RotwoodActor = require "questral.game.rotwoodactor"
local RotwoodInteractable = require "questral.game.rotwoodinteractable"

local QuestMarkManager = Class(function(self, inst)
	self.inst = inst
	self.marked_actors = {}
	self.marked_locations = {}

	self.inst:ListenForEvent("playerdeactivated", function(_, player) self:OnPlayerDeactivated(player) end)
end)

function QuestMarkManager:_SpawnMarkerForCast(cast, importance, player)
	local marker = self.marked_actors[cast]

	if not self.marked_actors[cast] then
		marker = SpawnPrefab("questmarker", cast)
	    marker.entity:SetParent(cast.entity)
	    self.marked_actors[cast] = marker
	end

	if cast:is_a(RotwoodActor) then
		marker.components.questmarker:FollowNPC(cast.inst)
	elseif cast:is_a(RotwoodInteractable) then
		marker.components.questmarker:FollowInteractable(cast.inst)
	end
	marker.components.questmarker:AddTrackedPlayer(player, importance)
end

function QuestMarkManager:_RemoveMarkerForCast(cast, player)
	local marker = self.marked_actors[cast]
	marker.components.questmarker:RemoveTrackedPlayer(player)

	if marker.components.questmarker:GetNumTrackedPlayers() <= 0 then
		marker.components.questmarker:DespawnMarkerFX(function() self.marked_actors[cast] = nil end)
	end
end

function QuestMarkManager:RefreshQuestMarks(quest_central)
	-- each player keeps an up-to-date list of what should be marked in their own QuestCentral
	-- this function polls each player and aggregates the requested marks, then creates the marks
	local player = quest_central:GetPlayer()
	local actors, locations = quest_central:CollectQuestMarks()

	-- spawn markers for each cast member the player wants them spawned for
	for cast, importance in pairs(actors) do
		self:_SpawnMarkerForCast(cast, importance, player)
	end

	-- loop through existing quest marks.
	for actor, marker in pairs(self.marked_actors) do
		-- if the player no longer wants this actor to be marked, remove them.
		if marker.components.questmarker:IsPlayerTracked(player) and not actors[actor] then
			self:_RemoveMarkerForCast(actor, player)
		end
	end

	for location, importance in pairs(locations) do
		self:_MarkLocation(location, importance, player)
	end

	local to_remove = {}
	-- loop through existing location marks
	for location, mark_data in pairs(self.marked_locations) do
		-- if the player no longer wants this location to be marked, remove them.
		if mark_data[player] and not locations[location] then
			-- remove
			mark_data[player] = nil
		end

		if table.count(mark_data) == 0 then
			-- if the table is empty, remove this marked location
			table.insert(to_remove, location)
		end
	end

	for _, location in ipairs(to_remove) do
		self.marked_locations[location] = nil
	end
end

function QuestMarkManager:IsLocationMarked(location)
	return self.marked_locations[location] ~= nil
end

function QuestMarkManager:GetLocationMarkData(location)
	return self.marked_locations[location]
end

function QuestMarkManager:_MarkLocation(location, importance, player)
	if not self.marked_locations[location] then
		self.marked_locations[location] = {}
	end

	local prev_importance = self.marked_locations[location][player]
	if prev_importance ~= nil and QUEST_IMPORTANCE.id[prev_importance] > QUEST_IMPORTANCE.id[importance] then
		-- has this player already marked this location?
		return
	end

	self.marked_locations[location][player] = importance
end

function QuestMarkManager:OnPlayerDeactivated(player)
	for actor, marker in pairs(self.marked_actors) do
		-- if the player no longer wants this actor to be marked, remove them.
		if marker.components.questmarker:IsPlayerTracked(player) then
			self:_RemoveMarkerForCast(actor, player)
		end
	end

	local to_remove = {}

	for location, mark_data in pairs(self.marked_locations) do
		if mark_data[player] then
			mark_data[player] = nil
		end

		if table.count(mark_data) == 0 then
			-- if the table is empty, remove this marked location
			table.insert(to_remove, location)
		end
	end

	for _, location in ipairs(to_remove) do
		self.marked_locations[location] = nil
	end
end

return QuestMarkManager