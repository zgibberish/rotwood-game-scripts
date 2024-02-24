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
local SGCommon = require "stategraphs.sg_common"
local easing = require "util.easing"

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

	self.spawned_poweritems = {} -- A list of all power items spawned, indexed by playerID (or 1 if shared).
	self.num_powers_to_start = {} -- A list of counts of how many power items were spawned to start with, index by playerID (or 1 if shared).
	self.choices_allowed = {} -- A list of how many choices each player is allowed to take, index by playerID (or 1 if shared).
	self.shared_drop = false -- If true, we'll spawn powers for everyone and they'll pick communally. Otherwise, drop pairs for every player.

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

			self.spawner_to_use = self.spawners[1]
			local plaindrop = self:SpawnPowerDrop(power_to_spawn, self.spawners[1])
			plaindrop.components.powerdrop:PrepareToShowGem({
					appear_delay_ticks = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES,
				})

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

			local picks = self.rng:PickSome(1, {
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

function PowerDropManager:PreparePowers()
	local worldmap = TheDungeon:GetDungeonMap()
	local dungeonentrance = worldmap:IsCurrentRoomDungeonEntrance()
	local reward = worldmap:GetRewardForCurrentRoom()

	if reward == mapgen.Reward.s.plain then
		if dungeonentrance then
			self:PreparePowers_RelicShared()
			self.shared_drop = true
		else
			self:PreparePowers_Relic()
		end
	elseif reward == mapgen.Reward.s.fabled then
		self:PreparePowers_FabledShared()
		self.shared_drop = true
	end
end

function PowerDropManager:PreparePowers_Relic()
	local player_IDs = TheNet:GetPlayerIDsOnRoomChange()

	local all_powers = {}
	for _, playerID in ipairs(player_IDs) do
		local playerGUID = TheNet:FindGUIDForPlayerID(playerID)
		local player
		if playerGUID then 
			player = Ents[playerGUID]
		end

		if player then
			all_powers[playerID] = {}
			local powers = self:GetNumRelics(player, player.components.powermanager.power_drop_options)
			for idx,power in ipairs(powers) do
				TheDungeon.progression.components.powerroller:AddSeenPower(player, power.name, power.slot)
				-- player.components.powermanager:AddSeenPower(power.name, power.slot)
				table.insert(all_powers[playerID], power)
			end
			self.choices_allowed[playerID] = player.components.powermanager.power_drop_selections

			-- self:SpawnCircleOfPowers(powers, i, #players, start_pos, player)
		end
	end

	self.powers_data = all_powers
end

function PowerDropManager:PreparePowers_RelicShared()
	local player_IDs = TheNet:GetPlayerIDsOnRoomChange()
	local double_spawner = self.rng:PickFromArray(player_IDs) -- one player will spawn two powers, so there are always num_players+1 powers. Which player idx should have two?

	local all_powers = {}
	all_powers[1] = {}

	for _, playerID in ipairs(player_IDs) do
		local playerGUID = TheNet:FindGUIDForPlayerID(playerID)
		local player
		if playerGUID then
			player = Ents[playerGUID]
		end

		if player then
			-- Roll powers for this player, then sort them by rarity.
			-- We'll prefer to take the highest rarity.
			local powers = self:GetNumRelics(player, player.components.powermanager.power_drop_options)
			self.choices_allowed[playerID] = player.components.powermanager.power_drop_selections

			local sorted_powers = lume.sort(powers, function(a, b) return Power.Rarities.id[a.rarity] > Power.Rarities.id[b.rarity] end)
			local num_spawned = 0

			local num_to_spawn = double_spawner == playerID and 2 or 1 -- This player was chosen to spawn two powers.

			for idx,power in ipairs(sorted_powers) do
				-- Spawn as many powers as we are meant to.
				if num_spawned < num_to_spawn then 
					TheDungeon.progression.components.powerroller:AddSeenPower(player, power.name, power.slot)
					-- player.components.powermanager:AddSeenPower(power.name, power.slot)
					table.insert(all_powers[1], power)
					num_spawned = num_spawned + 1
				end
			end
		end
	end
	self.powers_data = all_powers
end

function PowerDropManager:PreparePowers_FabledShared(power_drop_legend)
	local player_IDs = TheNet:GetPlayerIDsOnRoomChange()

	-- Always spawn two fabled families.
	local power_families = self.rng:PickSome(2, {
			Power.Slots.ELECTRIC,
			--~ Power.Slots.SEED,
			Power.Slots.SHIELD,
			Power.Slots.SUMMON,
		})

	local all_powers = {}
	all_powers[1] = {} -- Shared, so store it in one index.

	-- Disabling the "doubled family" for now
	-- Spawn 1 power of each fabled family
	-- Re-enable this rng to spawn 1x FamilyA, 2x FamilyB
	local doubled_family = -1 --self.rng:Integer(1, #power_families)

	for i,power_family in ipairs(power_families) do
		local playerGUID = TheNet:FindGUIDForPlayerID(player_IDs[1])
		local fabled_spawning_player
		if playerGUID then 
			fabled_spawning_player = Ents[playerGUID]
		end

		if fabled_spawning_player then
			-- Spawn 1 of each, then an extra for the one we chose to double.
			local powers = self:GetNumFabledRelics(fabled_spawning_player, power_family, doubled_family == i and 2 or 1)

			for power_idx,power in ipairs(powers) do
				table.insert(all_powers[1], power)
			end
		end
	end

	-- Add a normal Relic option to the mix: 1 relic for 1p and 2p, 2 relics for 3p and 4p.
	local relics_to_add = #player_IDs >= 3 and 2 or 1

	for i=1,relics_to_add do
		-- Roll powers for this player, then sort them by rarity.
		-- We'll prefer to take the highest rarity.
		local playerGUID = TheNet:FindGUIDForPlayerID(self.rng:PickFromArray(player_IDs))	-- Use a random player

		local spawning_player
		if playerGUID then 
			spawning_player = Ents[playerGUID]
		end

		if spawning_player then
			local power = self:GetNumRelics(spawning_player, 1, Power.Rarity.LEGENDARY)
			table.insert(all_powers[1], power[1])
		end
	end

	for _, playerID in ipairs(player_IDs) do
		self.choices_allowed[playerID] = 1 -- 1 Choice in this room.

		local playerGUID = TheNet:FindGUIDForPlayerID(playerID)
		local player
		if playerGUID then 
			player = Ents[playerGUID]
		end

		if player then
			for power_idx,power in ipairs(all_powers[1]) do
				-- Make each player "See" ALL the powers.
				TheDungeon.progression.components.powerroller:AddSeenPower(player, power.name, power.slot)
				-- player.components.powermanager:AddSeenPower(power.name, power.slot)
			end
		end
	end

	self.powers_data = all_powers
	return power_families
end

function PowerDropManager:SpawnPowerItems(drop, position)
	local start_pos = position

	local player_IDs = TheNet:GetPlayerIDsOnRoomChange()

	if self.shared_drop then
		-- Spawn one set of powers, selectable by all players
		self:SpawnCircleOfPowers(self.powers_data[1], 1, 1, 1, start_pos, nil) -- Shared drop is all in one list, using PlayerID 1
	else
		-- Spawn individual powers grouped by player
		local all_powers = {}
		for i,playerID in ipairs(player_IDs) do
			local playerGUID = TheNet:FindGUIDForPlayerID(playerID)
			local player
			if playerGUID then 
				player = Ents[playerGUID]
			end
			if player then
				self:SpawnCircleOfPowers(self.powers_data[playerID], playerID, i, #player_IDs, start_pos, player)
			end
		end
	end

	self.inst:StartUpdatingComponent(self)
end

local TEMP_SPAWNER_PER_PLAYER =
{
	-- 1 player
	{
		{ x = 0, z = 0 },
	},

	-- 2 player
	{
		{ x = -6, z = 0 },
		{ x = 6, z = 0 },
	},

	-- 3 player
	{
		{ x = -8, z = 7 },
		{ x =  8, z = 7 },
		{ x = 0, z = -8 },
	},

	-- 4 player
	{
		{ x = -8, z = 7 },
		{ x =  8, z = 7 },
		{ x = -8, z = -8 },
		{ x =  8, z = -8 },
	},
}

local startangle_by_dropcount =
-- For each amount of powers, how should we rotate the drops?
{
	0,  -- 1 Power
	0,  -- 2 Powers: line
	90, -- 3 Powers: inverted triangle
	180,  -- 4 Powers:
	270, -- 5 Powers: star
}

local radius_by_dropcount_solo =
-- NON-SHARED DROP
-- For each amount of powers, how far apart should we spawn the drops?
{
	2.25, -- Too close and it gets tricky to pick the right power
	2.25,
	3.5,
	3.5,
	3.5,
}
local radius_by_dropcount_shared =
-- SHARED DROP
-- For each amount of powers, how far apart should we spawn the drops?
{
	2.25,
	2.25,
	5.5, -- Spread out so there's more space
	5.5,
	6.5,
}

local USE_LOOTDROP_LOCATION = true

function PowerDropManager:SpawnCircleOfPowers(powers, player_id, player_index, player_count, start_pos, assigned_player)
	-- Store a table of power items associated with this player idx.
	if not self.spawned_poweritems[player_id] then
		self.spawned_poweritems[player_id] = {}
	end

	local radius_data = assigned_player ~= nil and radius_by_dropcount_solo or radius_by_dropcount_shared
	local startangle_data = startangle_by_dropcount
	local angle_per_spawn = 360 / #powers

	local dungeonentrance = TheDungeon:GetDungeonMap():IsCurrentRoomDungeonEntrance()

	for i, drop in ipairs(powers) do
		local spawn_i = i - 1
		local circle_radius = radius_data[#powers] or 8 -- Powers up to 5 are designed above -- so if we're using the default, we have a LOT of powers, so use a big radius.
		local start_angle = (startangle_data[#powers] or 0) / #powers -- For lower power counts, we want to design the angle to create better shapes. Otherwise, we don't care.

		local poweritem = SpawnPrefab("power_pickup_single", self.inst)
		poweritem:PushEvent("initialized_ware", {
			ware_name = drop.name, -- TODO: make pretty name
			power = drop.name,
			power_type = drop.power_type,
		})

		if assigned_player then
			poweritem.components.singlepickup:AssignToPlayer(assigned_player)
		end

		poweritem.AnimState:SetScale(1.25, 1.25)

		local angle = math.rad((i * angle_per_spawn) + start_angle)
		local xOffset = math.cos(angle) * circle_radius
		local zOffset = math.sin(angle) * circle_radius

		local target_data = TEMP_SPAWNER_PER_PLAYER[player_count][player_index]

		-- target_data: contains offsets based on a given anchor position. Once upon a time this anchor position was 0,0.
		local x_diff = target_data.x
		local z_diff = target_data.z

		-- anchor_pos: based on the start_pos (the power crystal spawn location), apply the template of positions from target_data to find the new actual target position based on player count
		local anchor_pos = {}
		anchor_pos.x = start_pos.x + x_diff
		anchor_pos.z = start_pos.z + z_diff

		-- Now that we have the anchor position, based on how many powers we're spawning around this anchor, find the x and z offsets for this specific power.
		local target_x = anchor_pos.x + xOffset
		local target_z = anchor_pos.z + zOffset
		local target_pos = Vector3(target_x, 0, target_z)

		poweritem.Transform:SetPosition(start_pos.x, start_pos.y, start_pos.z)
		SGCommon.Fns.MoveToPoint(poweritem, target_pos, 20 * ANIM_FRAMES / SECONDS, easing.outQuad)

		-- Spawn directly at their destination:
		-- poweritem.Transform:SetPosition(target_pos.x + x_offset, 0, target_pos.z)
		table.insert(self.spawned_poweritems[player_id], poweritem)
	end
	self.num_powers_to_start[player_id] = #self.spawned_poweritems[player_id]
end

function PowerDropManager:OnUpdate(dt)
	if TheNet:IsHost() then
		local keep_updating = false

		if self.shared_drop then
			-- In this mode, all the powers are in index i=1. Not indexed by players!

			local player_IDs = TheNet:GetPlayerIDsOnRoomChange()

			local all_powers = {}
			for _, playerID in ipairs(player_IDs) do
				local playerGUID = TheNet:FindGUIDForPlayerID(playerID)
				local player
				if playerGUID then 
					player = Ents[playerGUID]
				end

				if player and player.components.powermanager then
					if player.components.powermanager:CanPickUpPowerDrop() then
						keep_updating = true
					end
				end
			end

			if not keep_updating then
				for i,poweritem in ipairs(self.spawned_poweritems[1]) do
					if poweritem ~= nil and poweritem:IsValid() then
						-- Set them to be uninteractable to prevent last-minute interactions,
						-- Then queue a removal. Don't remove them right away, because the one you chose should disappear first, then the others should follow.
						poweritem.components.interactable:SetInteractCondition_Never()
						poweritem:DoTaskInAnimFrames(12, function()
							if poweritem ~= nil and poweritem:IsValid() and not poweritem.sg:HasStateTag("despawning") then
								poweritem:PushEvent("despawn")
							end
						end)
					end
				end
			end
		else
			-- Players are picking individually.

			for playerid, player_items in pairs(self.spawned_poweritems) do

				-- Loop through all the power items spawned for this player, and see if they still exist.
				-- If not, it means they've been picked up: stop tracking them.

				local remaining_poweritems = {}
				for _, poweritem in ipairs(player_items) do
					if poweritem ~= nil and poweritem:IsValid() and not poweritem.sg:HasStateTag("despawning") then
						-- If we've picked one up, then it will be despawning -- at this point we should already consider it 'taken'
						table.insert(remaining_poweritems, poweritem)
					end
				end

				-- Then, see how many powers have been taken away.
				local choices_made = self.num_powers_to_start[playerid] - #remaining_poweritems
				local choices_allowed = self.choices_allowed[playerid]

				-- Check to see if this player is still around. If not, then we'll clear out any remaining poweritems.
				local playerGUID = TheNet:FindGUIDForPlayerID(playerid)
				local player = Ents[playerGUID]
				local player_exists = player ~= nil and player:IsValid()

				-- If they've made enough choices already, then clear out all the remaining poweritems.
				if choices_made >= choices_allowed or (not player_exists) then
					for i, poweritem in ipairs(remaining_poweritems) do
						if poweritem ~= nil and poweritem:IsValid() then
							-- Set them to be uninteractable to prevent last-minute interactions,
							-- Then queue a removal. Don't remove them right away, because the one you chose should disappear first, then the others should follow.
							poweritem.components.interactable:SetInteractCondition_Never()
							poweritem:DoTaskInAnimFrames(12, function()
								if poweritem ~= nil and poweritem:IsValid() and not poweritem.sg:HasStateTag("despawning") then
									poweritem:PushEvent("despawn")
								end
							end)
						end
					end
				else
					self.spawned_poweritems[playerid] = remaining_poweritems
					keep_updating = true
				end
			end
		end

		if not keep_updating then
			self.inst:StopUpdatingComponent(self)
		end
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
	local players = TheNet:GetNrPlayersOnRoomChange() -- QUESTION: should this use TheNet:GetNrPlayersOnRoomChange() instead? Using AllPlayers means spectators about to join are counted, which may be good.
	return lume.filter(powers, function(def)
		return players >= def.minimum_player_count and players <= def.maximum_player_count
	end)
end

function PowerDropManager:FilterBySeen(powers, player)
	return lume.filter(powers, function(def) return not TheDungeon.progression.components.powerroller:HasSeenPower(player, def) end)
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

local function FilterByNameList(powers, power_names)
	return lume.filter(powers, function(def)
		return lume.find(power_names, def.name)
	end)
end

---------------

function PowerDropManager:PickTypesOfWeaponDrops()

end

function PowerDropManager:RollRarity(player, type)
	-- printf("PowerDropManager:RollRarity(%s, %s)", roller.prefab, type)
	local pr = TheDungeon.progression.components.powerroller
	if pr then
		local rarity_ids = table.reverse(Power.RarityIdx)
		return pr:DoPowerRoll(player, type, TUNING.POWERS.DROP_CHANCE, rarity_ids, rarity_ids[#rarity_ids])
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
	end

	if #rarity_powers == 0 then
		return
	end

	-- Sort for determinism.
	table.sort(rarity_powers, function(a,b) return a.name < b.name end)

	local idx, pick = self.rng:PickKeyValue(rarity_powers)

	powers = lume.remove(powers, pick)
	-- printf("GetRandomPowerOfRarity: %s, %s", rarity, pick.name)
	return pick, rarity
end

function PowerDropManager:CollectFabledRelicDrops(player, family)

	-- TODO: Look at World Unlocks to determine what power families can drop in the current biome
	local TEMP_FAMILY_TO_CATEGORY =
	{
		["ELECTRIC"] = Power.Categories.DAMAGE,
		["SHIELD"] = Power.Categories.SUSTAIN,
		["SUMMON"] = Power.Categories.SUPPORT,
	}

	-- TODO: Are these per-player now? then it should be filtered based on that specific player's powers
	kassert.assert_fmt(family, "Failed to handle power category '%s'.", family)
	local powers = Power.GetAllPowersOfFamily(family)
	powers = self:FilterByType(powers, Power.Types.FABLED_RELIC)
	powers = self:FilterByDroppable(powers)
	powers = self:FilterByHas(powers, player)

	local cheat_powers = TheSaveSystem.cheats:GetValue("force_drop_powers")
	if cheat_powers then
		-- Cheat after FilterByHas so we'll be able to go through the whole list.
		return FilterByNameList(powers, cheat_powers)
	end

	powers = self:FilterByCategory(powers, TEMP_FAMILY_TO_CATEGORY[family])
	powers = self:FilterByEligible(powers, player)
	powers = self:FilterByPlayerCount(powers)
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

	local cheat_powers = TheSaveSystem.cheats:GetValue("force_drop_powers")
	if cheat_powers then
		-- Cheat after FilterByHas so we'll be able to go through the whole list.
		return FilterByNameList(powers, cheat_powers)
	end

	powers = self:FilterBySeen(powers, player)
	-- powers = self:FilterByAnyEligible(powers)
	powers = self:FilterByEligible(powers, player)
	powers = self:FilterByPlayerCount(powers)
	TheLog.ch.PowerDropManager:printf("eligible powers before unlocked: %d", #powers)
	powers = self:FilterByUnlocked(powers, player)

	return powers
end

function PowerDropManager:GetNumRelics(player, num, forced_rarity)
	-- TheLog.ch.PowerDropManager:printf("PowerDropManager:GetNumRelics(%s, %s, %s)", player, num, forced_rarity)
	local options = self:CollectRelicDrops(player)
	num = math.min(#options, num)
	TheLog.ch.PowerDropManager:printf("GetNumRelics num=%d options#=%d", num, #options)
	local picks = {}
	for i = 1, num do
		local rarity, lucky
		if forced_rarity then
			rarity = forced_rarity
		else
			rarity, lucky = self:RollRarity(player, "player_power")
		end
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
function PowerDropManager:GetPowerForMarket(type, ideal_rarity, include_lower_rarities, rng)	
	TheLog.ch.PowerManager:printf("GetPowerForMarket(type = %s, rarity = %s)", type, ideal_rarity)
	TheLog.ch.PowerManager:indent()
	rng = rng or self.rng
	local skipped_higher_rarities = false
	for rarity_index, rarity in pairs(lume(Power.Rarities:Ordered()):reverse():result()) do
		if rarity == ideal_rarity then
			skipped_higher_rarities = true
		end
		if skipped_higher_rarities then
			local rarity_market = self.market[type][rarity]
			if not rarity_market then
				TheLog.ch.PowerManager:printf("Market[%s][%s] is nil", type, rarity)
			else
				if #rarity_market == 0 then
					TheLog.ch.PowerManager:printf("Market[%s][%s] is empty", type, rarity)
				else
					local power_index, power = rng:PickKeyValue(rarity_market)
					table.remove(rarity_market, power_index)
					TheLog.ch.PowerManager:printf("Selected power (%s) from market[%s][%s]", power, type, rarity)
					TheLog.ch.PowerManager:unindent()
					return power
				end
			end
		end
	end
	TheLog.ch.PowerManager:printf("No power found. Returning nil!")
	TheLog.ch.PowerManager:unindent()
end

function PowerDropManager:GenerateMarketPowers()
	self.market = self:_BuildMarketPowerTable()
end

function PowerDropManager:_BuildMarketPowerTable()
	-- List of power defs indexed by [power_type][rarity].
	local market = {}
	for _, slot in pairs(Power.Items) do
		for name, def in pairs(slot) do
			local power_type = def.power_type;
			if power_type then
				local rarity = Power.GetBaseRarity(def);
				if rarity then
					market[power_type] = market[power_type] or {}
					market[power_type][rarity] = market[power_type][rarity] or {}			
					table.insert(market[power_type][rarity], def)
				else
					TheLog.ch.PowerManager:printf("Warning: Power (%s) has no rarity", name)
				end
			else
				TheLog.ch.PowerManager:printf("Warning: Power (%s) has no power_type", name)
			end
		end
	end
	
	-- List of power names indexed by [power_type][rarity].
	local out_market = {}
	for power_type, type_market in pairs(market) do
		out_market[power_type] = {}
		for rarity, rarity_market in pairs(type_market) do			
			-- Filter.
			rarity_market = self:FilterByAllHas(rarity_market)
			rarity_market = self:FilterByDroppable(rarity_market)
			rarity_market = self:FilterByAnyEligible(rarity_market)
			rarity_market = self:FilterByPlayerCount(rarity_market)
			rarity_market = self:FilterByAnyUnlocked(rarity_market)

			-- Map to names.
			out_market[power_type][rarity] = lume(rarity_market)
				:map(function(power) return power.name end)
				:result()

			-- Sort for determinism.
			table.sort(out_market[power_type][rarity])
		end
	end
	return out_market
end

function PowerDropManager:Debug_FlattenMarketPowers(market_table)
	local names = {}
	for key,family in pairs(market_table) do
		for rarity,powers in pairs(family) do
			for i,power_name in ipairs(powers) do
				table.insert(names, power_name)
			end
		end
	end
	return names
end

function PowerDropManager:OnSave()
	local data = {}
	return next(data) and data or nil
end

function PowerDropManager:OnLoad(data)

end

return PowerDropManager
