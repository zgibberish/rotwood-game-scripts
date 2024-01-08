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

function playerutil.AreAllPlayersNotAlive()
	return lume.all(AllPlayers, function(player)
		return not player:IsAlive()
	end)
end

function playerutil.AreAllMultiplayerPlayersDead()
	return lume.all(AllPlayers, function(player)
		return player:IsDead() or player:IsRevivable()
	end)
end

function playerutil.AreAllPlayersDead()
	return lume.all(AllPlayers, EntityScript.IsDead)
end

function playerutil.AreAllLocalPlayersDeadOrRevivable()
	for _i,player in ipairs(AllPlayers) do
		if player:IsLocal()
			and not player:IsInLimbo() -- spectators / pending join
			and (not player:IsDead() and not player:IsRevivable()) then
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

function playerutil.DoForAllLocalPlayers(fn)
    local local_players = TheNet:GetLocalPlayerList()
    for _, playerID in ipairs(local_players) do
        local player = GetPlayerEntityFromPlayerID(playerID)
        if player then
        	fn(player)
        end
    end
end

------------------------------


return playerutil
