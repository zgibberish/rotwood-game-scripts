local lume = require "util.lume"
local fmodtable = require "defs.sound.fmodtable"


local playerutil = {}

------------------------------
-- Find Player functions.
-- Many of these are available on Entities where the x,z is the entity
-- position.

function playerutil.FindClosestPlayerInRangeSq(x, z, rangesq, isalive)
	local closest = nil
	for i = 1, #AllPlayers do
		local v = AllPlayers[i]
		if (isalive == nil or isalive == v:IsAlive()) and v:IsVisible() then
			local distsq = v:GetDistanceSqToXZ(x, z)
			if distsq < rangesq then
				rangesq = distsq
				closest = v
			end
		end
	end
	return closest, closest ~= nil and rangesq or nil
end

function playerutil.FindClosestPlayerInRange(x, z, range, isalive)
	return playerutil.FindClosestPlayerInRangeSq(x, z, range * range, isalive)
end

function playerutil.FindClosestPlayer(x, z, isalive)
	return playerutil.FindClosestPlayerInRangeSq(x, z, math.huge, isalive)
end

function playerutil.FindPlayersInRangeSq(x, z, rangesq, isalive)
	local players = {}
	for i = 1, #AllPlayers do
		local v = AllPlayers[i]
		if (isalive == nil or isalive == v:IsAlive()) and v:IsVisible() and v:GetDistanceSqToXZ(x, z) < rangesq then
			players[#players + 1] = v
		end
	end
	return players
end

function playerutil.FindPlayersInRange(x, z, range, isalive)
	return playerutil.FindPlayersInRangeSq(x, z, range * range, isalive)
end

function playerutil.IsAnyPlayerInRangeSq(x, z, rangesq, isalive)
	for i = 1, #AllPlayers do
		local v = AllPlayers[i]
		if (isalive == nil or isalive == v:IsAlive()) and v:IsVisible() and v:GetDistanceSqToXZ(x, z) < rangesq then
			return true
		end
	end
	return false
end

function playerutil.IsAnyPlayerInRange(x, z, range, isalive)
	return playerutil.IsAnyPlayerInRangeSq(x, z, range * range, isalive)
end


-- pred: optional predicate function. nil to just get a truly random player
function playerutil.GetRandomPlayer(pred)
	if not pred then
		return AllPlayers[math.random(#AllPlayers)]
	end

	local players = {}
	for i,p in ipairs(AllPlayers) do
		if pred(p) then
			table.insert(players, p)
		end
	end

	local count = #players
	if count > 0 then
		return players[math.random(count)]
	end
	return nil
end

function playerutil.GetNextPlayer(current_player, should_loop)
	local i = lume.find(AllPlayers, current_player) or 1
	i = i + 1
	if should_loop and not AllPlayers[i] then
		i = 1
	end
	return AllPlayers[i]
end

function playerutil.GetRandomLivingPlayer()
	return playerutil.GetRandomPlayer(function(player) return player:IsVisible() and player:IsAlive() end)
end

-- Even if false, players could still come back to life (mulligan). Check
-- AreAllMultiplayerPlayersDead for Game Over.
function playerutil.IsAnyPlayerAlive()
	return lume.any(AllPlayers, function(player)
		return player:IsAlive()
	end)
end

-- Players have all settled in a game over state. (None are DYING so they
-- shouldn't be able to leave their current state without cheats.)
function playerutil.AreAllMultiplayerPlayersDead()
	return lume.all(AllPlayers, function(player)
		return player:IsDead() or player:IsRevivable()
	end)
end

function playerutil.AreAllLocalPlayersDeadOrRevivable()
	for _i,player in ipairs(AllPlayers) do
		if player:IsLocal()
			and not player:IsInLimbo() -- spectators / pending join
			and (not player:IsDead() and not player:IsRevivable())
		then
			return false
		end
	end

	return true
end


local function CompareHunterId(a, b)
	return a:GetHunterId() < b:GetHunterId()
end
function playerutil.SortByHunterId(player_list)
	assert(EntityScript.is_instance(player_list[1]))
	table.sort(player_list, CompareHunterId)
	return player_list
end

--- Recipe/ Crafting Util

function playerutil.CanUpgradeAnyHeldEquipment(player, slots)
	local Equipment = require"defs.equipment"
	local recipes = require"defs.recipes"
	slots = slots or { Equipment.Slots.WEAPON, Equipment.Slots.HEAD, Equipment.Slots.BODY }

	local inv = player.components.inventoryhoard

	for _, slot in ipairs(slots) do
		local items = inv:GetSlotItems(slot)
		for _, item in ipairs(items) do
			local recipe = recipes.FindUpgradeRecipeForItem(item)
			if recipe and recipe:CanPlayerCraft(player) then
				return true
			end
		end
	end

	return false
end

function playerutil.CanUnlockNewRecipes(player)
	local Equipment = require"defs.equipment"
	local recipes = require"defs.recipes"
	local unlocks = player.components.unlocktracker

	for _, id in ipairs(Equipment.ArmourSets) do
		if not unlocks:IsRecipeUnlocked(id) then
			local recipe = recipes.FindRecipeForItem('armour_unlock_'..id)
			if recipe and recipe:CanPlayerCraft(player) then
				return true
			end
		end
	end

	return false
end

function playerutil.UnlockBossWeapons(boss_id, player)
	-- get all weapons that use this id as a monster source and unlock the recipes
	local Equipment = require"defs.equipment"

	for id, def in pairs(Equipment.Items.WEAPON) do
		if def.crafting_data and def.crafting_data.monster_source then
			if lume.find(def.crafting_data.monster_source, boss_id) ~= nil then
	            player.components.unlocktracker:UnlockRecipe(def.name)
			end
		end
	end
end

function playerutil.GetLocationUnlockInfo(locationData)
	local invalid_players = {}

	for _, player in ipairs(AllPlayers) do
		for _, key in ipairs(locationData.required_unlocks) do
			if not player.components.unlocktracker:IsLocationUnlocked(key) then
				table.insert(invalid_players, player)
			end
		end
	end

	return #invalid_players == 0, invalid_players
end

-- See also playerutil.LocalPlayers()
function playerutil.DoForAllLocalPlayers(fn)
    local local_players = TheNet:GetLocalPlayerList()
    for _, playerID in ipairs(local_players) do
        local player = GetPlayerEntityFromPlayerID(playerID)
        if player then
        	fn(player)
        end
    end
end


-- Iterate list of local players:
--   for hunter_id,player in playerutil.LocalPlayers() do
--   	print("player", hunter_id, player)
--   end
--
-- returns: iterator
function playerutil.LocalPlayers()
    local local_players = TheNet:GetLocalPlayerList()
	local i = 0
	return function()
		i = i + 1
		local playerID = local_players[i]
        local player = playerID and GetPlayerEntityFromPlayerID(playerID)
		if player then
			return player:GetHunterId(), player
		else
			return nil, nil
		end
	end
end

function playerutil.CountLocalPlayers()
	return #TheNet:GetLocalPlayerList()
end

function playerutil.GetFirstLocalPlayer()
	-- luacheck: push ignore 512 "loop is executed at most once"
	for id,player in playerutil.LocalPlayers() do
		return player
	end
	-- luacheck: pop
end

-- Are there remote players spectating or playing?
--
-- Whether the current session is local-only (no other players connected),
-- whereas TheNet:IsGameTypeLocal() tells you the mode the player picked on
-- mainscreen.
function playerutil.HasRemotePlayers()
	return next(TheNet:GetRemotePlayerList()) ~= nil
end

function playerutil.CountActivePlayers()
	local count = 0

	local playerIDs = TheNet:GetPlayerIDsOnRoomChange()
	for _i,pID in ipairs(playerIDs) do
		local playerGUID = TheNet:FindGUIDForPlayerID(pID)
		if playerGUID and Ents[playerGUID]:IsValid() and not Ents[playerGUID]:IsInLimbo() then
			count = count + 1
		end
	end

	return count
end
------------------------------


return playerutil
