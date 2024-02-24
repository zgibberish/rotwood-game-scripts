--[[
	Desired power drop behaviour

	For Weapon Powers:
		At the start of a run:
			Select families for each class of power that will be shown throughout the run
				(IE: Damage -> Lightning, Support -> Seed, Sustain -> Shield)
		At the end of a room:
			- Do a rarity roll, all powers shown will be of that rarity
			- Select two classes of powers to show (IE: Damage and Support, but not Sustain)
			- Collect a list of powers that can be dropped for each class (per-party)
				- Must be the rarity rolled for this room
				- It's ok to show powers that players have seen already
			- Save those drops, show the same options to all players.
				- Two players can pick the same upgrade
				- Once a player has picked a class of power they cannot back out and look at the other class

	For Player Powers:
		At the end of a room:
			- Collect a list of powers that can be dropped (per-player)
				- Look at the tags on all players. If one player is eligible for a power, all players can see it
				- Roll rarity per-power, powers do not have to be the same rarity
				- Each player sees unique choices.
				- Players can not see the same power twice in the same run.
			- Show these options to the player.

	Bad Luck Protection:
		Each time rarity is rolled, increase the chances of seeing a legendary item.
			- This persists between runs.
			- This is per-type. (Weapon and Player powers have seperate bad luck protection)
			- When a legendary is seen, reset the bad luck protection.
--]]

local krandom = require "util.krandom"
local Power = require "defs.powers"
local PropAutogenData = require "prefabs.prop_autogen_data"
local itemforge = require "defs.itemforge"
local kassert = require "util.kassert"
local lume = require "util.lume"
local mapgen = require "defs.mapgen"



local PowerDropManager = Class(function(self, inst)
	self.inst = inst
	local seed = TheDungeon:GetDungeonMap():GetRNG():Integer(2^32 - 1)
	-- Offset RNG per client so they don't generate the exact same stuff
	local seed_offset = TheNet:IsInGame() and TheNet:GetClientID() or 0
	seed = seed + seed_offset
	TheLog.ch.Random:printf("PowerDropManager Random Seed: %d (offset: %d)", seed, seed_offset)
	self.rng = krandom.CreateGenerator(seed)
	self.spawners = {}

	self.drop_families = nil
	self.num_families_per_run = 3
	self.spawned_reward = nil

	self._new_run_fn =  function() self:InitializePowerDrops() end
	self._end_run_fn = function() self:ResetData() end
	self._on_room_complete_fn = function(_, data) self:OnRoomComplete(data) end
	-- start_new_run is usually called from town.
	self.inst:ListenForEvent("start_new_run", self._new_run_fn, TheDungeon)
	if not TheWorld:HasTag("town")
		and not TheWorld:HasTag("debug")
	then
		self.inst:ListenForEvent("end_current_run", self._new_run_fn, TheDungeon)
		self.inst:ListenForEvent("room_complete", self._on_room_complete_fn)
	end
end)

function PowerDropManager:InitializePowerDrops()
	-- pick families of powers that will drop over the course of this run
	-- self.drop_families = krandom.PickSome(self.num_families_per_run, shallowcopy(Power.Slots))
	-- we want to pick a power family for each slot type
end

function PowerDropManager:ResetData()
	self.drop_families = nil
	self.spawned_reward = nil
end

function PowerDropManager:AddSpawner(spawner_ent)
	table.insert(self.spawners, spawner_ent)
end

local function BuildPowerDropLibrary()
	local t = {
		[Power.Types.RELIC] = {},
		[Power.Types.FABLED_RELIC] = {},
		[Power.Types.SKILL] = {},
	}
	for prefab,val in pairs(PropAutogenData) do
		if val.script == "powerdrops" then
			local power_type = val.script_args.power_type
			local power_family = val.script_args.power_family
			if power_type and power_family then
				t[power_type][power_family] = prefab
			end
		end
	end
	-- Player powers are a special case and always use this prefab.
	t[Power.Types.RELIC].PLAYER = "power_drop_player"
	t[Power.Types.SKILL] = "power_drop_skill"
	return t
end

-- uses data.enemy_highwater (only to test > 0), data.last_enemy (indirectly for position)
function PowerDropManager:OnRoomComplete(data)
	assert(not TheWorld:HasTag("town"))

	if not TheNet:IsHost() then
		return
	end

	local worldmap = TheDungeon:GetDungeonMap()
	local dungeonentrance = worldmap:IsCurrentRoomDungeonEntrance()
	local seenpower = TheWorld:IsFlagUnlocked("wf_seen_room_bonus") -- FLAG

	local should_spawn_power
	should_spawn_power = ((dungeonentrance and seenpower)
		or data.enemy_highwater > 0)
		and not worldmap:HasEnemyForCurrentRoom('boss')
		and not self.spawned_reward
	if should_spawn_power then
		table.sort(self.spawners, EntityScript.OrderByXZDistanceFromOrigin)
		self.rng:Shuffle(self.spawners)

		local power_drop_legend = BuildPowerDropLibrary()

		local difficulty = worldmap:GetDifficultyForCurrentRoom()
		local reward = worldmap:GetRewardForCurrentRoom()

		if reward == mapgen.Reward.s.plain then
			self.spawned_reward = true
			local power_to_spawn = power_drop_legend.RELIC[Power.Slots.PLAYER]
			assert(power_to_spawn, "Missing powerdrop prop for RELIC.")
			local plaindrop = self:SpawnPowerDrop(power_to_spawn, self.spawners[1])
			plaindrop.components.powerdrop:PrepareToShowGem({
					appear_delay_ticks = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES,
				})

			-- local plaindrop = self:SpawnPowerItems(power_to_spawn, self.spawners[1])

		elseif reward == mapgen.Reward.s.skill then
			self.spawned_reward = true
			local power_to_spawn = power_drop_legend.SKILL
			assert(power_to_spawn, "Missing powerdrop prop for SKILL.")
			local skilldrop = self:SpawnPowerDrop(power_to_spawn, self.spawners[1])
			skilldrop.components.powerdrop:PrepareToShowGem({
					appear_delay_ticks = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES,
				})
		elseif reward == mapgen.Reward.s.fabled then
			self.spawned_reward = true
			-- Always spawn two fabled powers. Singleplayer gets just one.
			-- Multiplayer only two players get a power.
			-- TODO: Only pick non empty categories.
			local picks = self.rng:PickSome(2, {
					Power.Slots.ELECTRIC,
					--~ Power.Slots.SEED,
					Power.Slots.SHIELD,
					Power.Slots.SUMMON,
				})
			local spawned_drops = {}
			for i,power_family in ipairs(picks) do
				local power_to_spawn = power_drop_legend.FABLED_RELIC[power_family]
				kassert.assert_fmt(power_to_spawn, "Missing powerdrop prop for FABLED_RELIC '%s'.", power_family)
				local drop = self:SpawnPowerDrop(power_to_spawn, self.spawners[i])
				drop.components.powerdrop:PrepareToShowGem({
						use_limit_count = 1,
						appear_delay_ticks = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES,
						spawn_order = i,
					})
				table.insert(spawned_drops, drop)
			end
			if #AllPlayers == 1 then
				assert(#spawned_drops == 2)
				spawned_drops[1].components.powerdrop:SetExclusiveWith(spawned_drops[2])
			end
		end

		if data.last_enemy then
			TheWorld.components.konjurrewardmanager:OnLastEnemyDeath(data.last_enemy)
		end
	end
end

local function PickPowerDropSpawnPosition()
	local angle = math.rad(math.random(360))
	local dist_mod = math.random(3, 6)
	local target_offset = Vector2.unit_x:rotate(angle) * dist_mod
	return Vector3(target_offset.x, 0, target_offset.y)
end

local TEMP_POSITIONS =
{
	{ x = - 5, z =  5 },
	{ x =   5, z =  5 },
	{ x = - 5, z = -10 },
	{ x =   5, z = -10 },
}
local TEMP_X_DISTANCE = 2

function PowerDropManager:SpawnPowerItems(name, spawner)
	local target_pos
	if spawner then
		target_pos = spawner:GetPosition()
	else
		-- Fallback to random position near the centre of the world if we
		-- didn't have enough spawners.
		TheLog.ch.Power:print("No room_loot for this power drop. Use self.spawners to place them to avoid appearing inside of something.")
		target_pos = PickPowerDropSpawnPosition()
	end

	for num,player in ipairs(TheNet:GetPlayersOnRoomChange()) do
		target_pos = TEMP_POSITIONS[num]
		local powers = self:GetNumRelics(player, 2)

		local spawned_poweritems = {}
		local x_offset = -TEMP_X_DISTANCE
		for i,drop in ipairs(powers) do
			ThePlayer.components.powermanager:AddSeenPower(drop.name, drop.slot)

			local poweritem = SpawnPrefab("proto_power_item", self.inst)
			poweritem.components.poweritem:SetPower(drop.name)
			poweritem.components.poweritem:SetOwningPlayer(player)

			poweritem.components.interactable:SetRadius(1)

			poweritem.Transform:SetPosition(target_pos.x + x_offset, 0, target_pos.z)
			x_offset = x_offset + TEMP_X_DISTANCE
			table.insert(spawned_poweritems, poweritem)

			if i > 1 then
				spawned_poweritems[1].components.poweritem:SetExclusiveWith(poweritem)
			end
		end
		-- z_offset = z_offset - 10
	end
end


function PowerDropManager:SpawnPowerDrop(name, spawner)
	local target_pos
	if spawner then
		target_pos = spawner:GetPosition()
	else
		-- Fallback to random position near the centre of the world if we
		-- didn't have enough spawners.
		TheLog.ch.Power:print("No room_loot for this power drop. Use self.spawners to place them to avoid appearing inside of something.")
		target_pos = PickPowerDropSpawnPosition()
	end

	local drop = SpawnPrefab(name, self.inst)
	drop.Transform:SetPosition(target_pos:Get())

	return drop
end

function PowerDropManager:FilterByFamilies(powers, families)
	return lume.filter(powers, function(def)
		for _, family in ipairs(families) do
			if def.slot == family then
				return true
			end
		end
		return false
	end)
end

function PowerDropManager:FilterByTypes(powers, types)
	return lume.filter(powers, function(def)
		for _, type in ipairs(types) do
			if def.power_type == type then
				return true
			end
		end
		return false
	end)
end

function PowerDropManager:FilterByCategories(powers, categories)
	return lume.filter(powers, function(def)
		for _, category in ipairs(categories) do
			if def.power_category == category then
				return true
			end
		end
		return false
	end)
end

function PowerDropManager:FilterByRarities(powers, rarities)
	return lume.filter(powers, function(def)
		for _, rarity in ipairs(rarities) do
			if Power.GetBaseRarity(def) == rarity then
				return true
			end
		end
		return false
	end)
end

function PowerDropManager:FilterByDroppable(powers)
	return lume.filter(powers, function(def) return def.can_drop end)
end

function PowerDropManager:FilterByFamily(powers, family)
	return lume.filter(powers, function(def) return def.slot == family end)
end

function PowerDropManager:FilterByType(powers, type)
	return lume.filter(powers, function(def) return def.power_type == type end)
end

function PowerDropManager:FilterByCategory(powers, category)
	return lume.filter(powers, function(def) return def.power_category == category end)
end

function PowerDropManager:FilterByRarity(powers, rarity)
	return lume.filter(powers, function(def)
		-- printf("Filter Power By Rarity: %s %s", def.name, rarity)
		-- return def.tuning[rarity] ~= nil
		return Power.GetBaseRarity(def) == rarity
	end)
end

function PowerDropManager:FilterByAllHas(powers)
	-- remove stuff ALL of the players have
	return lume.filter(powers, function(def)
		local all_players_have = true
		for _, player in ipairs(AllPlayers) do
			if not player.components.powermanager:HasPower(def) then
				all_players_have = false
				break
			end
		end
		return not all_players_have
	end)
end

function PowerDropManager:FilterByPlayerCount(powers)
	local players = #AllPlayers -- QUESTION: should this use TheNet:GetNrPlayersOnRoomChange() instead? Using AllPlayers means spectators about to join are counted, which may be good.
	return lume.filter(powers, function(def)
		return players >= def.minimum_player_count and players <= def.maximum_player_count
	end)
end

function PowerDropManager:FilterBySeen(powers, player)
	return lume.filter(powers, function(def) return not player.components.powermanager:HasSeenPower(def) end)
end

function PowerDropManager:FilterByHas(powers, player)
	return lume.filter(powers, function(def) return not player.components.powermanager:HasPower(def) end)
end

local function IsPlayerEligible(def, player)
	local is_eligible = true

	if def.required_tags then
		for i, tag in ipairs(def.required_tags) do
			local hastag = player:HasTag(tag) -- Tags from other powers
			local hasinventorytag = player.components.inventory:HasTag(tag) -- Tags for equipped items
			if not hastag and not hasinventorytag then
				is_eligible = false
				break
			end
		end
	end

	if def.exclusive_tags and is_eligible then
		for i, tag in ipairs(def.exclusive_tags) do
			if player:HasTag(tag) or player.components.inventory:HasTag(tag) then -- Tags from other powers or equipped items
				is_eligible = false
				break
			end
		end
	end

	return is_eligible
end

function PowerDropManager:FilterByEligible(powers, player)
	return lume.filter(powers, function(def) return IsPlayerEligible(def, player) end)
end

function PowerDropManager:FilterByAnyEligible(powers)
	-- if any player can get this power, show it to all players
	return lume.filter(powers, function(def)
		if not def.required_tags then
			return true
		else
			local any_eligible = false
			for _, player in ipairs(AllPlayers) do
				any_eligible = any_eligible or IsPlayerEligible(def, player)
			end
			return any_eligible
		end
	end)
end

function PowerDropManager:FilterByUnlocked(powers, player)
	return lume.filter(powers, function(def) return player.components.unlocktracker:IsPowerUnlocked(def.name) end)
end

function PowerDropManager:FilterByAnyUnlocked(powers)
	return lume.filter(powers, function(def)
		local any_unlocked = false
		for _, player in ipairs(AllPlayers) do
			any_unlocked = any_unlocked or player.components.unlocktracker:IsPowerUnlocked(def.name)
		end
		return any_unlocked
	end)
end

---------------

function PowerDropManager:PickTypesOfWeaponDrops()

end

function PowerDropManager:RollRarity(roller, id)
	-- printf("PowerDropManager:RollRarity(%s, %s)", roller.prefab, id)
	local lr = roller and roller.components.lootroller
	if lr then
		local rarity_ids = table.reverse(Power.RarityIdx)
		--return lr:DoLootRollWeighted(id, TUNING.POWERS.DROP_CHANCE)
		return lr:DoLootRollPercent(id, TUNING.POWERS.DROP_CHANCE, rarity_ids, rarity_ids[#rarity_ids])
	else
		return self.rng:WeightedChoice(TUNING.POWERS.DROP_CHANCE)
	end
end

function PowerDropManager:GetRandomPowerOfRarity(powers, rarity, include_lower_rarities)
	-- printf("PowerDropManager:GetRandomPowerOfRarity %s", rarity)
	local rarity_powers = self:FilterByRarity(powers, rarity)

	if #rarity_powers == 0 and include_lower_rarities then
		local current_idx = lume.find(Power.RarityIdx, rarity)
		-- printf("Could not find power of rarity %s", rarity)
		-- Since we failed to find desired rarity, walk backwards down rarity
		-- list to find one.
		for i = current_idx - 1, Power.Rarities.id.COMMON, -1 do
			-- printf("-Trying to find power of rarity %s", Power.RarityIdx[i])
			rarity_powers = self:FilterByRarity(powers, Power.RarityIdx[i])
			if #rarity_powers > 0 then
				-- printf("--Fell back to %s!", Power.RarityIdx[i])
				rarity = Power.RarityIdx[i]
				break
			end
		end

		if #rarity_powers == 0 then
			return
		end
	elseif #rarity_powers == 0 and not include_lower_rarities then
		return
	end

	table.sort(rarity_powers, function(a,b) return a.name < b.name end)
	local pick = self.rng:PickFromArray(rarity_powers)
	local idx = lume.find(powers, pick)
	table.remove(powers, idx)
	-- printf("GetRandomPowerOfRarity: %s, %s", rarity, pick.name)
	return pick, rarity
end

function PowerDropManager:CollectFabledRelicDrops(player, category)

	-- TODO: Look at World Unlocks to determine what power families can drop in the current biome
	local TEMP_CATEGORY_TO_FAMILY =
	{
		[Power.Categories.DAMAGE] = "ELECTRIC",
		[Power.Categories.SUSTAIN] = "SHIELD",
		[Power.Categories.SUPPORT] = "SUMMON",
	}

	-- TODO: Are these per-player now? then it should be filtered based on that specific player's powers

	local family = TEMP_CATEGORY_TO_FAMILY[category]
	kassert.assert_fmt(family, "Failed to handle power category '%s'.", category)
	local powers = Power.GetAllPowersOfFamily(family)
	powers = self:FilterByType(powers, Power.Types.FABLED_RELIC)
	powers = self:FilterByCategory(powers, category)
	powers = self:FilterByEligible(powers, player)
	powers = self:FilterByDroppable(powers)
	powers = self:FilterByPlayerCount(powers)
	powers = self:FilterByHas(powers, player)
	return powers
end

function PowerDropManager:MakePower(def, rarity)
	local power = itemforge.CreateEquipment(def.slot, def)
	rarity = rarity or Power.GetBaseRarity(def)
	power:SetRarity(rarity)
	return power
end

function PowerDropManager:GetNumFabledRelics(player, category, num)
	-- printf("PowerDropManager:GetNumFabledRelics(%s, %s)", category, num)
	local options = self:CollectFabledRelicDrops(player, category)
	num = math.min(#options, num)
	local picks = {}
	for i = 1, num do
		local pick, result_rarity = self:GetRandomPowerOfRarity(options, Power.RarityIdx[3], true)
		if pick then
			table.insert(picks, { name = pick.name, slot = pick.slot, rarity = result_rarity, lucky = false })
		end
	end
	return picks
end

function PowerDropManager:CollectRelicDrops(player)
	local powers = Power.GetAllPowers()
	powers = self:FilterByType(powers, Power.Types.RELIC)
	powers = self:FilterByDroppable(powers)
	powers = self:FilterByHas(powers, player)
	powers = self:FilterBySeen(powers, player)
	-- powers = self:FilterByAnyEligible(powers)
	powers = self:FilterByEligible(powers, player)
	powers = self:FilterByPlayerCount(powers)
	TheLog.ch.PowerDropManager:printf("eligible powers before unlocked: %d", #powers)
	powers = self:FilterByUnlocked(powers, player)

	return powers
end

function PowerDropManager:GetNumRelics(player, num)
	-- printf("PowerDropManager:GetNumRelics(%s, %s)", player, num)
	local options = self:CollectRelicDrops(player)
	num = math.min(#options, num)
	TheLog.ch.PowerDropManager:printf("GetNumRelics num=%d options#=%d", num, #options)
	local picks = {}
	for i = 1, num do
		local rarity, lucky = self:RollRarity(player, "player_power")
		local pick, result_rarity = self:GetRandomPowerOfRarity(options, rarity, true)
		if pick then
			table.insert(picks, { name = pick.name, slot = pick.slot, rarity = result_rarity, lucky = lucky })
--			local power = self:MakePower(pick, result_rarity)
--			table.insert(picks, { power = power, lucky = lucky })
		end
	end
	return picks
end

function PowerDropManager:CollectSkillDrops(player)
	local powers = Power.GetAllPowers()
	powers = self:FilterByType(powers, Power.Types.SKILL)
	powers = self:FilterByDroppable(powers)
	powers = self:FilterByHas(powers, player)
	powers = self:FilterBySeen(powers, player)
	-- powers = self:FilterByAnyEligible(powers)
	powers = self:FilterByEligible(powers, player)
	powers = self:FilterByPlayerCount(powers)
	powers = self:FilterByUnlocked(powers, player)
	return powers
end

function PowerDropManager:GetNumSkills(player, num)
	-- printf("PowerDropManager:GetNumRelics(%s, %s)", player, num)
	local options = self:CollectSkillDrops(player)
	num = math.min(#options, num)
	local picks = {}
	for i = 1, num do
		local rarity, lucky = self:RollRarity(player, "skill_power")
		local pick, result_rarity = self:GetRandomPowerOfRarity(options, rarity, true)
		if pick then
			table.insert(picks, { name = pick.name, slot = pick.slot, rarity = result_rarity, lucky = lucky })
--			local power = self:MakePower(pick, result_rarity)
--			table.insert(picks, { power = power, lucky = lucky })
		end
	end
	return picks
end

---------------

--- Return the *name* of the chosen power. Note that this relies on power names being unique across all categories.
--- Also the look-up by name will be relatively inefficient with respect to performance.
--- The reason for returning a name is that it is serializable, whereas a power table (containing functions) is not.
function PowerDropManager:GetPowerForMarket(type, rarity, include_lower_rarities)
	local options = Power.GetAllPowers()
	options = self:FilterByType(options, type)
	options = self:FilterByAllHas(options)
	options = self:FilterByDroppable(options)
	options = self:FilterByAnyEligible(options)
	options = self:FilterByPlayerCount(options)
	options = self:FilterByAnyUnlocked(options)

	local choice = self:GetRandomPowerOfRarity(options, rarity, include_lower_rarities)
	return choice.name
end

function PowerDropManager:OnSave()
	local data = {}
	return next(data) and data or nil
end

function PowerDropManager:OnLoad(data)

end

return PowerDropManager
