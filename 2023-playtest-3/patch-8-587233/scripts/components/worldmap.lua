local Bound2 = require "math.modules.bound2"
local Grid = require "util.grid"
local MapLayout = require "util.maplayout"
local MysteryManager = require "components.mysterymanager"
local ShopManager = require "components.shopmanager"
local WeatherManager = require "components.weathermanager"
local RoomLoader = require "roomloader"
local WorldAutogenData = require "prefabs.world_autogen_data"
local biomes = require "defs.biomes"
local iterator = require "util.iterator"
local kassert = require "util.kassert"
local krandom = require "util.krandom"
local kstring = require "util.kstring"
local lume = require "util.lume"
local mapgen = require "defs.mapgen"
local scenegenutil = require "prefabs.scenegenutil"
local SpecialEventRoom = require("defs.specialeventrooms.specialeventroom")
local EncounterDeck = require "encounter.encounter_deck"
require "class"
require "util"
require "vector2"
require "vecutil"


local DEFAULT_MOTHER_SEED = 9999

local WorldMap = Class(function(self, inst)
	self.inst = inst
	self.rng = nil
	self.mysterymanager = MysteryManager(inst)
	self.shopmanager = ShopManager(inst)
	self.weathermanager = WeatherManager(inst)

	local reset_action = InstanceParams.settings.reset_action
	if reset_action == RESET_ACTION.DEV_LOAD_ROOM then
		self:GenerateDebugMap()
		TheInput:SetEditMode("worldmap", true)
	elseif TheDungeon:IsInTown() then
		kassert.equal(reset_action, RESET_ACTION.LOAD_TOWN_ROOM)
		local data = TheSaveSystem.town:GetValue("worldmap")
		if data ~= nil then
			self:LoadMapData(data)
		else
			TheLog.ch.WorldMap:print("Generating new town map.")
			self:GenerateTownMap()
		end
	else
		kassert.equal(reset_action, RESET_ACTION.LOAD_DUNGEON_ROOM)
		local data = TheSaveSystem.dungeon:GetValue("worldmap")
		if data ~= nil then
			self:LoadMapData(data)
		else
			error("[WorldMap] Must generate dungeon map before entering dungeon. Generate in town.")
		end
	end

	--~ self.inst:StartWallUpdatingComponent(self)
end)

local debug_world_fake_name = 'debug'


-- Mostly for debug when we might not have a world. Prefer getting the map
-- from TheDungeon:GetDungeonMap().
function WorldMap.GetDungeonMap_Safe()
	if not TheDungeon then
		-- Dungeon not created (in main menu?), but we don't really need it.
		-- Pretend we dev loaded into a room and create it on an empty object.
		InstanceParams.settings.reset_action = RESET_ACTION.DEV_LOAD_ROOM
		TheSim:LoadPrefabs({"dungeon"})
		TheDungeon = SpawnPrefab("dungeon")
		TheDungeon.progression:LoadProgression()
		-- Loading a real dungeon is a bit more work, but I think it's better
		-- since it ensures we have progression data in mapgen. See this fake
		-- dungeon mess:
		--~ TheDungeon = CreateEntity("fakedungeon")
		--~ TheDungeon:AddComponent("worldmap")
		--~ TheDungeon.GetDungeonMap = function(inst)
		--~ 	return inst.components.worldmap
		--~ end
		--~ TheDungeon.IsInTown = function(inst)
		--~ 	return false
		--~ end
	end
	return TheDungeon:GetDungeonMap()
end


function WorldMap:OnWallUpdate()
	self:Debug_RenderMiniMap()
end

function WorldMap:Debug_RenderMiniMap()
	local expanded,open = imgui:Begin("WorldMap", nil, imgui.WindowFlags.AlwaysAutoResize)
	if expanded and open then
		if self.data then
			imgui:InputTextMultiline("##WorldMap", self:GetDebugString(), nil, 450)
			imgui:Value("room id", self.data.current)
			for enemy,_ in pairs(mapgen.roomtypes.Enemy.id) do
				imgui:Text(("%s: %s"):format(enemy, self:HasEnemyForCurrentRoom(enemy)))
			end
			imgui:Value("has resources", self:DoesCurrentRoomHaveResources())
		else
			open = false
		end
	elseif not open then
		self.inst:StopWallUpdatingComponent(self)
	end
	imgui:End()
end

WorldMap.RoomNavigator = Class(function(self, data)
	self.data = data
end)

-- Make an exit in a cardinal direction that enters from the west.
local function connect_cardinal(cardinal, room_to_id, room_id_1, room_id_2)
	dbassert(cardinal ~= "west")
	local room_1 = room_to_id[room_id_1]
	local room_2 = room_to_id[room_id_2]
	room_1.connect[cardinal] = room_id_2
	room_2.connect.west = room_id_1
	room_2.backlinks[room_id_1] = "west"
end

local function connect_right(room_to_id, room_id_l, room_id_r)
	local room_l = room_to_id[room_id_l]
	local room_r = room_to_id[room_id_r]
	room_l.connect.east = room_id_r
	room_r.connect.west = room_id_l
	room_r.backlinks[room_id_l] = "west"
end

local function connect_up(room_to_id, room_id_bot, room_id_top)
	local room_bot = room_to_id[room_id_bot]
	local room_top = room_to_id[room_id_top]
	room_bot.connect.north = room_id_top
	room_top.connect.south = room_id_bot
	room_top.backlinks[room_id_bot] = "south"
end

local function disconnect_single_room(room, to_remove)
	for cardinal,rid in iterator.sorted_pairs(room.connect) do
		if rid == to_remove.index then
			room.connect[cardinal] = nil
		end
	end
	to_remove.backlinks[room.index] = nil
end

local function disconnect_cardinal(cardinal, room_to_id, room_id_1)
	local room_1 = room_to_id[room_id_1]
	local room_id_2 = room_1.connect[cardinal]
	assert(room_id_2, "Input room doesn't have that cardinal exit.")
	local room_2 = room_to_id[room_id_2]
	disconnect_single_room(room_1, room_2)
	disconnect_single_room(room_2, room_1)
end

-- Returns an iterator that traverses the rooms we've visited. If
-- include_final_cardinal is a cardinal direction (string), returns that exit
-- from the final room in the visited path.
-- Includes hype room in output, but not boss room.
--
-- Iterate the visited path:
--   for rid,room in self.nav:IterateVisitedRooms() do
-- Iterate the visited path plus east from the current room:
--   for rid,room in self.nav:IterateVisitedRooms("east") do
function WorldMap.RoomNavigator:IterateVisitedRooms(include_final_cardinal)
	local room = self:get_entrance_room()
	return function()
		local current = room
		if current then
			local rid = lume.match(room.connect, function(exit_id)
				local exit = self.data.rooms[exit_id]
				return (exit.has_visited
					and self:is_forward_path(current.index, exit.index))
			end)
			if not rid then
				rid = room.connect[include_final_cardinal]
				include_final_cardinal = nil
			end
			room = self.data.rooms[rid]
			if room and room.is_terminal then
				-- Hype and boss are displayed as one room, so omit boss.
				room = nil
			end
			return current.index, current
		else
			return nil, nil
		end
	end
end

function WorldMap.RoomNavigator:get_entrance_room()
	return self.data.rooms[self.data.entrance_id]
end

function WorldMap.RoomNavigator:get_final_room()
	return self.data.rooms[self.data.final_id]
end

function WorldMap.RoomNavigator:get_hype_room_id()
	local final = self:get_final_room()
	-- Final room only connects to one other room: hype.
	local hype_dir = next(final.connect)
	local hype_id = final.connect[hype_dir]
	assert(hype_id, "Final room must connect to one another room.")
	-- Only check roomtype if it's been assigned.
	dbassert(self.data.rooms[hype_id].roomtype == nil or self.data.rooms[hype_id].roomtype == "hype")
	return hype_id
end

function WorldMap.RoomNavigator:has_resources(room)
	return room.roomtype == 'resource'
end

function WorldMap.RoomNavigator:get_roomtype(room)
	if not self:is_room_reachable(room) then
		return "unconnected"
	end
	local roomtype = room.roomtype or "unexplored"
	if room.is_entrance then
		roomtype = 'entrance'
	end
	assert(roomtype)
	return roomtype
end

function WorldMap.RoomNavigator:room_has_connection(room)
	return next(room.connect)
end

function WorldMap.RoomNavigator:is_room_reachable(room)
	assert(self:get_entrance_room().depth, "Cannot call is_room_reachable until after depth is assigned.")
	return room.depth ~= nil
end

function WorldMap.RoomNavigator:is_forward_path(src_rid, dest_rid)
	local dest = self.data.rooms[dest_rid]
	return not not dest.backlinks[src_rid]
end

function WorldMap.RoomNavigator:is_backtracking(src_rid, dest_rid)
	return not self:is_forward_path(src_rid, dest_rid)
end

function WorldMap.RoomNavigator:get_first_forward_roomid(room)
	for cardinal,rid in iterator.sorted_pairs(room.connect) do
		if self:is_forward_path(room.index, rid) then
			return rid
		end
	end
end

function WorldMap.RoomNavigator:get_first_backtrack_roomid(room)
	return lume.first(lume.sort(lume.keys(room.backlinks)))
end

function WorldMap.RoomNavigator:get_room_dimensions(room)
	if not room.world or room.world == debug_world_fake_name then
		return Vector2()
	end
	if not room.size then
		local file = WorldAutogenData[room.world]
		local layout = MapLayout(require("map/layouts/"..file.layout))
		local bounds = layout:GetGroundBounds()
		local size = bounds:size()
		room.size = { size.x, size.y }
	end
	return ToVector2(room.size)
end

local function get_room_id_safe(data, x, y)
	return data.grid:GetSafe(x, y)
end

local function select_entrance_room(data)
	local room = data.rooms[1]
	room.pos = Vector2(1,1)
	return room
end

function WorldMap.RoomNavigator:get_room_id_safe(x, y)
	return get_room_id_safe(self.data, x, y)
end

function WorldMap.RoomNavigator:get_pos_for_room_id(room_id_query)
	kassert.typeof('number', room_id_query)
	for x=1,#self.data.grid do
		for y,room_id in ipairs(self.data.grid[x]) do
			if room_id == room_id_query then
				return Vector2(x,y)
			end
		end
	end
end

function WorldMap.RoomNavigator:is_current_room(room_id)
	kassert.typeof('number', room_id)
	return room_id == self.data.current
end

function WorldMap.RoomNavigator:get_current_room_depth()
	local room = self.data.rooms[self.data.current]
	return room.depth
end

function WorldMap.RoomNavigator:find_room(cond_fn)
	for _rid,room in ipairs(self.data.rooms) do
		if cond_fn(room) then
			return room
		end
	end
end

local function create_room(rooms)
	local room = {
		-- Exits take us forward to these room ids. Direction : room id.
		connect = {},
		-- Exits take us backward to these room ids. Room id : direction.
		backlinks = {},
	}
	table.insert(rooms, room)
	room.index = #rooms
	room.reward = mapgen.Reward.s.none
	return room
end

-- Progress in [0,1].
-- Entrance is 0. Hype room is 1.
function WorldMap.RoomNavigator:GetProgressThroughDungeon()
	local room = self.data.rooms[self.data.current]
	return lume.clamp(room.depth / self.data.max_depth, 0, 1)
end

-- Get the count of number of rooms seen and total number of rooms you can
-- visit in one run. Useful for displaying in UI.
--
-- Don't do math on these: use GetProgressThroughDungeon instead.
function WorldMap.RoomNavigator:GetRoomCount_SeenAndMaximum()
	-- Depth starts at 0, but first room counts as seen. max_depth doesn't include
	-- boss so we need to add one for entrance.
	local room_total = self.data.max_depth + 1
	-- The boss room is actually 1 deeper than max depth because it's part of hype.
	local room_visited = lume.clamp(self:get_current_room_depth() + 1, 1, room_total)
	return room_visited, room_total
end

local function build_world_suffix(room)
	local suffix = "_"
	suffix = suffix .. (room.connect.north and "n" or "")
	suffix = suffix .. (room.connect.east and "e" or "")
	suffix = suffix .. (room.connect.south and "s" or "")
	suffix = suffix .. (room.connect.west and "w" or "")
	return suffix
end

local function deconstruct_world_suffix(world)
	local connect = {}
	local suffix = world:gsub("^.*_", "")
	for i,dir in ipairs({'north', 'east', 'south', 'west', }) do
		if suffix:find(dir:sub(1,1), nil, true) then
			connect[dir] = dir
		end
	end
	return connect
end
local function test_deconstruct_world_suffix()
	local connect = deconstruct_world_suffix('startingforest_arena_esw')
	assert(connect.north == nil)
	assert(connect.east)
	assert(connect.south)
	assert(connect.west)
end

-- return: list of cardinal directions.
function WorldMap:GetCurrentWorldEntrances()
	local connect = deconstruct_world_suffix(self.inst.prefab)
	connect = lume.keys(connect)
	table.sort(connect)
	return connect
end

local function SelectWorldWithFallback(world, kind, suffix, roomtype)
	local room_world = world .. kind .. suffix
	if not WorldAutogenData[room_world] then
		TheLog.ch.WorldMap:printf("WARNING: Failed to find world prefab '%s' for roomtype '%s'. Falling back to nesw.", room_world, roomtype)
		room_world = world .. kind .. '_nesw'
	end
	return room_world
end

local function set_world_for_room(nav, rng, room, biome_location)
	assert(nav:room_has_connection(room), "Don't assign worlds to an unconnected rooms.")
	local roomtype_suffixes = {
		miniboss = '_miniboss',
		entrance = '_start',
		food = '_small',
		potion = '_small',
		powerupgrade = '_small',
		market = '_market',
		mystery = '_large', -- This should never actually be used, because 'mystery' should be replaced with any other type of room.
		wanderer = '_small',
		ranger = '_large',
		quest = '_quest',
		resource = '_mat',
		boss = '_%s_boss',
		hype = '_%s_hype', -- requires boss name
	}
	local exits_suffix = build_world_suffix(room)
	assert(exits_suffix:len() > 1)
	local roomtype = nav:get_roomtype(room)
	local roomtype_suffix = roomtype_suffixes[roomtype] or '_arena'
	roomtype_suffix = roomtype_suffix:format(nav:GetDungeonBoss())

	-- Choose a layout from the relevant SceneGen.
	local layout
	local scene_gen = biome_location:GetSceneGen(scenegenutil.ASSERT_ON_FAIL)

	-- Obtain layout from SceneGen.
	local layouts = scenegenutil.FindLayoutsForRoomSuffix(scene_gen, roomtype_suffix..exits_suffix)
	if layouts then
		layout = next(layouts) and rng:PickFromArray(layouts)
	end

	-- If the SceneGen did not provide a layout, try for a fallback layout in any of the mapgen's worlds.
	local function IsValidLayout(layout)
		return layout and WorldAutogenData[layout]
	end
	if not IsValidLayout(layout) then
		TheLog.ch.WorldMap:printf("WARNING: Failed to find room matching '%s'. Falling back to prior algorithm...", roomtype_suffix..exits_suffix)

		local worlds = deepcopy(biome_location.worlds)
		krandom.Shuffle(worlds)

		local function SelectFallbackLayout(roomtype_suffix)
			for _, world in ipairs(worlds) do
				local layout = SelectWorldWithFallback(world, roomtype_suffix, exits_suffix, roomtype)
				if IsValidLayout(layout) then
					return layout
				end
			end
		end

		-- First try for a matching roomtype in the mapgen's list of worlds.
		layout = SelectFallbackLayout(roomtype_suffix)

		-- Failing that, look for "arena"s.
		if not layout then
			layout = SelectFallbackLayout('_arena')
		end
	end

	kassert.assert_fmt(
		layout,
		"Failed to find suitable World for room '%s' set in biome '%s'",
		room.world,
		biome_location.id
	)
	room.world = layout
end

-- Collect values from connecting rooms' tables. Order is random.
local function collect_adjacent_room_keys(data, room_id, key, default)
	local t = {}
	local room = data.rooms[room_id]
	for cardinal,rid in pairs(room.connect) do
		local r = data.rooms[rid]
		local v = r[key] or default
		if v then
			table.insert(t, v)
		end
	end
	return t
end

local function reduce_probability(dist, key, hist, limits, count_as_seen, reduce_scale)
	if not dist[key] then
		-- We pass these two interchangeably, so the key must be in one of them.
		kassert.assert_fmt(mapgen.roomtypes.RoomType:Contains(key) or mapgen.Reward:Contains(key), "Unknown key '%s' in dist. Missing something in room_distribution?", key)
		return
	end
	reduce_scale = reduce_scale or 0.1
	dist[key] = dist[key] * reduce_scale

	local times_seen = hist.seen[key] or 0
	if count_as_seen then
		times_seen = times_seen + 1
		hist.snooze_seen[key] = limits.snooze_seen[key]
		local sn = limits.snooze_depth[key]
		if sn then
			hist.snooze_depth[key] = sn + hist.branch_depth
		end
		if limits.snooze_seen[key] or sn then
			dist[key] = 0 -- do not allow duplicate snoozed exits
		end
	end

	hist.seen[key] = times_seen
	local max_room = limits.max_seen[key]
	if max_room and max_room == times_seen then
		dist[key] = 0
	end
end

local cardinal_to_delta = {
	south = Vector2(0, 1),
	north = Vector2(0, -1),
	west = Vector2(-1, 0),
	east = Vector2(1, 0),
}

local function find_next_room(nav, start_pos, cardinal, min_depth, should_merge)
	local x = min_depth + 1 -- depth is 0 indexed

	local function is_unreachable(room_id)
		local room = nav.data.rooms[room_id]
		return not nav:is_room_reachable(room)
	end

	if should_merge then
		local _,first_unreachable_idx = lume.match(nav.data.grid[x], is_unreachable)
		first_unreachable_idx = first_unreachable_idx or (nav.data.size.y + 1)
		local last_reachable_idx = first_unreachable_idx - 1
		local room_id = nav.data.grid[x][last_reachable_idx]
		local room = nav.data.rooms[room_id]
		assert(room, room_id)
		assert(room.pos, room_id)
		return room, room.pos

	else
		local room_id,y = lume.match(nav.data.grid[x], is_unreachable)
		local room = nav.data.rooms[room_id]
		if room then
			assert(y)
			-- Found an unused room.
			return room, Vector2(x,y)
		end
	end

	-- Only a boss room should have no adjacent rooms to the right and it
	-- shouldn't try to add exits.
	TheLog.ch.WorldMap:print(start_pos, cardinal, min_depth, should_merge, x)
	error("[WorldMap] Failed to find a next room.")
end

local exit_ordered = { 'north', 'east', 'south', }
local exit_ordered_lookup = lume.invert(exit_ordered)
local function cardinal_cmp(a, b)
	return exit_ordered_lookup[a] < exit_ordered_lookup[b]
end

local exclude_from_count = {
	-- Nonzero weight doesn't mean a quest can be selected. Quest system is
	-- also queried, so don't include it in roomtype count.
	quest = true,
}
local function count_non_zero_in_dist(dist)
	local count = 0
	for key,val in pairs(dist) do
		if val > 0 and not exclude_from_count[key] then
			count = count + 1
		end
	end
	return count
end

local function create_branches(s, room)
	local n_branches = s.branch_count:At(room.pos)
	kassert.assert_fmt(n_branches, "No branch count for %d at (%d, %d)", room.index, room.pos:unpack())
	local should_merge = n_branches == 0
	if should_merge then
		n_branches = 1
	end

	local branch_depth = room.depth + 1
	local dist = s.biome.roomdist[branch_depth]

	local exit_directions = lume.clone(exit_ordered)
	lume.remove(exit_directions, room.source)

	-- Force the start room to only exit East, North or North+East, but never south.
	if room.depth == 0 then
		lume.remove(exit_directions, "south")
	end

	exit_directions = s.rng:Shuffle(exit_directions)
	-- Only return to previous if doing three branches.
	table.insert(exit_directions, room.source)
	-- Only select as many as needed and sort so we always go in the same
	-- order. This ensures map drawing can assume the first exit is on the top.
	exit_directions = lume.first(exit_directions, n_branches)
	exit_directions = lume.sort(exit_directions, cardinal_cmp)

	local had_destination = false
	for i=1,n_branches do
		local boss_chance = dist.roomtype.boss or 0
		if boss_chance > 0 then
			kassert.equal(i, 1, "Why was does room_distribution have more options than just boss?")
			-- Force this room to be penultimate so it connects to boss.
			return false
		end

		local cardinal = exit_directions[i]
		local exit, pos = find_next_room(s.nav, room.pos, cardinal, room.depth + 1, should_merge)
		assert(exit)
		had_destination = true
		connect_cardinal(cardinal, s.nav.data.rooms, room.index, exit.index)
		if not exit.depth then
			-- new room
			exit.depth = branch_depth
			exit.prev = room.index
			exit.pos = pos
			exit.source = cardinal
			exit.roomseed = s.rng:Integer(1, 2^32-1)

			assert(exit.roomtype == nil, "Roomtypes assigned in a later step when layout is complete.")

			table.insert(s.waiting, exit.index)
		end
	end
	return had_destination
end

local function FindMinimumDifficultyForReward(dist, reward)
	local reward_id = mapgen.Reward.id[reward]
	for difficulty_id,difficulty_name in ipairs(mapgen.Difficulty:Ordered()) do
		local limit = mapgen.max_reward_per_difficulty[difficulty_id] or mapgen.max_reward
		if limit >= reward_id then
			return difficulty_id
		end
	end
	dbassert(false, "Failed to find acceptable difficulty. Be more careful with force_all_rewards. Can we catch this in mapgen validation?")
	return mapgen.Difficulty.id.hard
end
local function test_FindMinimumDifficultyForReward()
	local dist = {
		reward = {
			small_token = 1,
			plain = 1,
			fabled = 1,
		},
		difficulty_distribution = {
			easy = 2,
			medium = 10,
			hard = 5,
		},
	}
	kassert.equal(FindMinimumDifficultyForReward(dist, "plain"), mapgen.Difficulty.id.easy)
	kassert.equal(FindMinimumDifficultyForReward(dist, "small_token"), mapgen.Difficulty.id.medium)
	kassert.equal(FindMinimumDifficultyForReward(dist, "fabled"), mapgen.Difficulty.id.hard)
	kassert.equal(FindMinimumDifficultyForReward(dist, "big_token"), mapgen.Difficulty.id.hard)
end

local function FilterRewardForDifficulty(dist, reward, difficulty_id)
	local limit = mapgen.max_reward_per_difficulty[difficulty_id]
	if limit then
		local idx = mapgen.Reward.id[reward]
		repeat
			if idx <= 0 then
				return nil
			end
			idx = lume.clamp(idx, 0, limit)
			reward = mapgen.Reward:FromId(idx)
			idx = idx - 1
			-- require the rounded reward to actually be in the list of rewards.
		until (dist.reward[reward] or 0) > 0
	end
	assert(reward, "Failed to find acceptable reward downgrade. Should have been caught in mapgen validation.")
	return reward
end

local function test_FilterRewardForDifficulty()
	local dist = {
		-- Give a small token.
		roomtype = {
			monster = 1,
			powerupgrade = 10
		},
		reward = {
			small_token = 1, -- higher chance of soul after miniboss
			plain = 0.001, -- in case we get easy
		},
		difficulty_distribution = {
			easy = 2,
			medium = 10,
			hard = 5,
		},
	}
	kassert.equal(FilterRewardForDifficulty(dist, "small_token", mapgen.Difficulty.id.easy), "plain")
	kassert.equal(FilterRewardForDifficulty(dist, "small_token", mapgen.Difficulty.id.medium), "small_token")
	kassert.equal(FilterRewardForDifficulty(dist, "small_token", mapgen.Difficulty.id.hard), "small_token")
	kassert.equal(FilterRewardForDifficulty(dist, "big_token", mapgen.Difficulty.id.medium), "small_token")
	kassert.equal(FilterRewardForDifficulty(dist, "big_token", mapgen.Difficulty.id.medium), "small_token")
end

-- For roomtypes or rewards.
local function CalcForcedRoomChoices(force_all, dist)
	if not force_all then
		return nil
	end
	local t = {}
	for key,p in pairs(dist) do
		if p > 0 then
			table.insert(t, key)
		end
	end
	table.sort(t)
	return t
end

local function assign_roomtype_to_exits(s, room_id, room)
	local exits = deepcopy(room.connect)
	for rid,cardinal in pairs(room.backlinks) do
		exits[cardinal] = nil
	end
	exits.west = nil -- never allow west exit.
	local exit_directions = lume.sort(lume.keys(exits), cardinal_cmp)

	if #exit_directions == 0 then
		return
	end

	local hist = s.nav.data.gen_state.history

	hist.visited[room.roomtype] = (hist.visited[room.roomtype] or 0) + 1
	hist.visited[room.reward] = (hist.visited[room.reward] or 0) + 1
	if room.is_mystery then
		-- Mystery rooms change their roomtype before we visit.
		hist.visited.mystery = (hist.visited.mystery or 0) + 1
	end
	hist.branch_depth = room.depth + 1

	local dist = deepcopy(s.biome.roomdist[hist.branch_depth])
	kassert.assert_fmt(dist, "Missing roomdist for depth %d", hist.branch_depth)
	if s.nav.data.is_cheat then
		-- Fully populate to avoid invalid asserts.
		-- TODO(dbriscoe): Should I revive this? The old code was incorrect and thus didn't prevent errors.
		--~ for key in pairs(mapgen.roomtypes.RoomType:Ordered()) do
		--~ 	dist.roomtype[key] = dist.roomtype[key] or 0
		--~ end
		for _,key in pairs(mapgen.Difficulty.id) do
			dist.difficulty[key] = dist.difficulty[key] or 0
		end
	end
	dist.difficulty[-1] = 0 -- invalid difficulty

	-- Grab forced values before changing probabilities.
	local forced_roomtypes = CalcForcedRoomChoices(dist.force_all_roomtypes, dist.roomtype)
	local forced_rewards = CalcForcedRoomChoices(dist.force_all_rewards, dist.reward)

	reduce_probability(dist.roomtype, room.roomtype, hist, s.limits)
	reduce_probability(dist.difficulty, room.difficulty, hist, s.limits)
	reduce_probability(dist.reward, room.reward, hist, s.limits)

	for key,count in iterator.sorted_pairs(hist.snooze_seen) do
		reduce_probability(dist.roomtype, key, hist, s.limits, false, 0.00001)
		reduce_probability(dist.reward, key, hist, s.limits, false, 0.00001)
	end

	for key,depth in iterator.sorted_pairs(hist.snooze_depth) do
		-- We store the allowed depth, so check if we're past that.
		if hist.branch_depth < depth then
			reduce_probability(dist.roomtype, key, hist, s.limits, false, 0.00001)
			reduce_probability(dist.reward, key, hist, s.limits, false, 0.00001)
		else
			-- We won't generate an earlier depths, so we can clear.
			hist.snooze_depth[key] = nil
		end
	end

	for key,count in iterator.sorted_pairs(s.limits.max_seen) do
		local seen = hist.seen[key] or 0
		if seen >= count then
			dist.roomtype[key] = 0
			dist.reward[key] = 0
		end
	end

	for key,count in iterator.sorted_pairs(s.limits.max_visited) do
		local visited = hist.visited[key] or 0
		if visited >= count then
			dist.roomtype[key] = 0
			dist.reward[key] = 0
		end
	end

	-- Could pick an exit index here, but keep it simple to increase
	-- likelihood of placing it.
	local use_quest_room = dist.roomtype.quest > 0 and s.nav.data.wants_quest_room
	dist.roomtype.quest = 0 -- forced, never randomly selected

	if use_quest_room and not dist.allow_optional_quest then
		-- Disconnect unused rooms or it looks like we failed to assign a roomtype.
		local unused_exits = lume.slice(exit_directions, 2, -1)
		TheLog.ch.WorldMap:printf("Generating Quest room at depth %i. Detaching %i unused exits. Disabling force_all, was: roomtypes[%s] rewards[%s]", hist.branch_depth, #unused_exits, dist.force_all_roomtypes, dist.force_all_rewards)
		for _,cardinal in ipairs(unused_exits) do
			disconnect_cardinal(cardinal, s.nav.data.rooms, room.index)
		end
		exit_directions = lume.first(exit_directions, 1)
		assert(#exit_directions == 1)
		-- Ignore force when there's a quest since it's otherwise invalid.
		dist.force_all_roomtypes = false
		dist.force_all_rewards = false
	end

	local assigned_roomtypes = {}

	assert(not dist.force_all_roomtypes or next(forced_roomtypes),
		"If we are forcing room types, we need some to choose from.")
	assert(not dist.force_all_rewards or next(forced_rewards),
		"If we are forcing rewards, we need some to choose from.")
	for i,cardinal in ipairs(exit_directions) do
		local roomtype
		if dist.force_all_roomtypes then
			roomtype = forced_roomtypes[i]
			if not roomtype then
				assert(s.nav.data.is_cheat, "How are there not enough roomtypes? We force the right amount.")
				roomtype = circular_index(forced_roomtypes, i)
			end
		else
			if use_quest_room then
				-- If we hit a merge point below we won't assign this roomtype,
				-- so allow it for any following exit. This does not 100%
				-- guarantee a quest room: may have assigned all exits.
				roomtype = mapgen.roomtypes.RoomType.s.quest
			else
				roomtype = s.rng:WeightedChoice(dist.roomtype)
				--~ print(string.format("room_id=%d i=%d cardinal=%s roomtype=%s dist.roomtype =", room_id, i, cardinal, roomtype), table.inspect(dist.roomtype))
				assert(dist.roomtype[roomtype] > 0, "Were all roomtypes zero probability?")
			end
		end

		local reward
		if dist.force_all_rewards then
			reward = forced_rewards[i]
			if not reward then
				assert(s.nav.data.is_cheat, "How are there not enough rewards? We force the right amount.")
				reward = circular_index(forced_rewards, i)
			end
		else
			reward = s.rng:WeightedChoice(dist.reward)
			assert(dist.reward[reward] > 0, "Were all rewards zero probability?")
		end

		local exit = s.nav.data.rooms[room.connect[cardinal]]
		assert(exit)

		-- We may have already assigned a type if we hit a tree merge point.
		if not exit.roomtype then
			kassert.assert_fmt(
				s.nav.data.final_id ~= exit.index or roomtype == "boss",
				"Failed to set boss roomtype. source_rid=%d, source_depth=%d, roomtype=%s, rid=%d, depth=%d",
				room.index, room.depth, roomtype, exit.index, exit.depth)

			exit.roomtype = roomtype
			if mapgen.roomtypes.Trivial:Contains(exit.roomtype) then
				-- Ensure hardest_seen only counts values in combat rooms. We don't
				-- use difficulty for trivial rooms.
				exit.difficulty = -1
			else
				exit.difficulty = s.rng:WeightedChoice(dist.difficulty)
				if s.biome.enforce_difficulty_ramp then
					local harder = math.min(room.hardest_seen + 1, mapgen.max_difficulty)
					exit.difficulty = math.min(exit.difficulty, harder)
				end
				exit.reward = FilterRewardForDifficulty(dist, reward, exit.difficulty)
				if dist.force_all_rewards and exit.reward ~= reward then
					-- Don't let our filter downgrade force_all_rewards because
					-- it will introduce duplicates, but we still want random
					-- difficulty so we don't force it above.
					exit.reward = reward
					exit.difficulty = FindMinimumDifficultyForReward(dist, reward)
				end
			end
			exit.hardest_seen = math.max(room.hardest_seen, exit.difficulty)

			exit.forced_encounter = dist.forced_encounter
			if use_quest_room then
				assert(roomtype == mapgen.roomtypes.RoomType.s.quest)
				-- Don't want another now that request is filled.
				use_quest_room = nil
			end

			if s.dbg_tracker then
				-- Debug: Track the probabilities at each choice so we can look them up
				-- later and explain what went wrong.
				s.dbg_tracker[exit.index] = {
					_room_id = exit.index, -- underscore sorts to top
					_roomtype = exit.roomtype,
					_reward = exit.reward,
					_difficulty = exit.difficulty,
					--~ from = room_id,
					dist = deepcopy(dist),
					hist = deepcopy(hist),
				}
			end

			reduce_probability(dist.roomtype, exit.roomtype, hist, s.limits, true, 0.001)
			reduce_probability(dist.difficulty, exit.difficulty, hist, s.limits, true, 0.001)
			reduce_probability(dist.reward, exit.reward, hist, s.limits, true, 0.001)
			assigned_roomtypes[exit.roomtype] = true

			if exit.roomtype == "mystery" then
				local mysterymanager = s.mysterymanager
				exit.roomtype = mysterymanager:DoMysteryRoll("mystery", TUNING.MYSTERIES.ROOMS.CHANCES, "wanderer", s.rng)

				if exit.roomtype == "monster" then
					local difficulty = mysterymanager:GetMonsterDifficulty(s.rng)
					local mystery_reward = mysterymanager:GetMonsterReward(difficulty, s.rng)
					exit.difficulty = mapgen.Difficulty.id[difficulty]
					exit.reward = mapgen.Reward.s[mystery_reward]
					assert(exit.difficulty)
					assert(exit.reward)
				end
				exit.is_mystery = true -- Remember original roomtype for limits and UI.
			end
			set_world_for_room(s.nav, s.rng, exit, s.biome_location)
		end
	end

	-- Tick down the generated rooms in snooze. Do this at the end to tick down
	-- the newly revealed rooms all at once. It would be more accurate to tick
	-- down after assigning each exit, but that's more complex and biases
	-- unsnoozing at south.
	local exit_count = #exit_directions
	for key,count in iterator.sorted_pairs(hist.snooze_seen) do
		local sn = count - exit_count
		if assigned_roomtypes[key] then
			-- Don't decrement roomtypes we just picked to give their full
			-- snooze.
			sn = count
		elseif sn <= 0 then
			sn = nil
		end
		hist.snooze_seen[key] = sn
	end
end

local function force_single_exit(branches, x)
	for y=1,branches.size.y do
		branches[x][y] = 0
	end
	branches[x][1] = 1
end

local function create_exit_counts(nav, rng, biome)
	local branch_choices = rng:WeightedFill(biome.branchdist, nav.data.size.y)

	local branches = Grid(nav.data.size, function(x,y) return nil end)
	local intro_rooms = biome.intro_rooms or 0 -- initial rooms that always have 1 exit (incl. entrance)
	for x=1,intro_rooms do
		branches[x][1] = 1
	end

	local outro_rooms = 2 -- final rooms that always have 1 exit (hype, boss)
	for x=0,outro_rooms-1 do
		force_single_exit(branches, branches.size.x - x)
	end

	local branch_idx = 1
	local exits = 1
	for x=intro_rooms+1, branches.size.x - outro_rooms do
		--Uncomment these prints to get a printout of what choices are made at every x while generating
		--print("x:", x)
		local dist = biome.roomdist[x]
		local max_branches = 3
		local possible_roomtypes = count_non_zero_in_dist(dist.roomtype)
		--print("		possible_roomtypes:", possible_roomtypes)
		if possible_roomtypes == 1 then
			-- Avoid branching out a lot with same-y looking rooms early.
			local is_first_half = x < (branches.size.x/2)
			if is_first_half or count_non_zero_in_dist(dist.difficulty) == 1 then
				if count_non_zero_in_dist(dist.reward) == 1 then
					max_branches = 1
					--print("		early and there's only one reward -- max branches to 1")
				else
					--print("		early but there's more than one reward -- max branches to 2")
					max_branches = 2
				end
			end
		elseif possible_roomtypes <= 3 then
			max_branches = 2
			--print("		less than or equal to 3 roomtypes -- max branches to 2")
		end
		--print("		max_branches:", max_branches)
		local count = 0
		if dist.join_all_branches then
			--print("		join all branches")
			force_single_exit(branches, x)
			count = 1
		elseif dist.force_all_roomtypes then
			--print("		force all roomtypes")
			force_single_exit(branches, x)
			count = dist.roomtype_count
			branches[x][1] = count
		elseif dist.force_all_rewards then
			--print("		force all rewards")
			force_single_exit(branches, x)
			count = dist.reward_count
			branches[x][1] = count
		else
			for y=1,exits do
				local n_branches = branch_choices[branch_idx]
				local remaining = nav.data.size.y - count
				local desired = n_branches
				if n_branches > remaining then
					n_branches = 1
				end
				n_branches = lume.clamp(n_branches, 1, max_branches)

				-- TODO(dbriscoe): Not sure if I want to do this still. Rework to use backlinks if reviving.
				--~ if n_branches > 1 then
				--~ 	local parent_room = s.nav.data.rooms[room.connect.west]
				--~ 	local exits = lume.count(parent_room.connect) - 1
				--~ 	assert(exits >= 1, exits)
				--~ 	if exits >= 3 then
				--~ 		-- Limit each exit from a 3-way branch to a single exit to avoid
				--~ 		-- explosion.
				--~ 		n_branches = 1
				--~ 	end
				--~ end

				if desired == n_branches then
					-- Only advance if we actually accepted the value.
					branch_idx = circular_index_number(#branch_choices, branch_idx + 1)
				end
				branches[x][y] = n_branches
				count = count + n_branches
			end
		end
		local excess = count - nav.data.size.y
		if excess > 0 then
			-- Reduce all except the first so we'll squeeze down and have more
			-- space for rooms with lots of exits.
			for y,n_branches in ipairs(branches[x]) do
				if y > 1 and n_branches > 0 then
					branches[x][y] = n_branches - 1
					excess = excess - 1
					count = count - 1
				end
			end
		end
		assert(excess <= 0)
		exits = count
		rng:Shuffle(branches[x])
		-- Ensure first row never merges so there's always something to merge into.
		local _,first_non_merge = lume.match(branches[x], function(v)
			return v > 0
		end)
		if first_non_merge > 1 then
			branches[x][1], branches[x][first_non_merge] = branches[x][first_non_merge], branches[x][1]
		end
	end
	-- Uncomment to see the rough shape of the map.
	--print(branches:tostring())
	return branches
end

local function generate_connections(nav, rng, start_room, biome)
	local state = {
		nav = nav,
		rng = rng,
		biome = biome,
		waiting = { nav.data.entrance_id },
		branch_count = create_exit_counts(nav, rng, biome),
	}

	kassert.equal(start_room.depth, 0)

	local penultimate = {}
	while #state.waiting > 0 do
		local room_id = table.remove(state.waiting, 1)
		local room = nav.data.rooms[room_id]

		-- Last two rooms are hype and boss. Handled outside of here.
		local is_penultimate = room.depth >= nav.data.size.x - 2
		if not is_penultimate then
			is_penultimate = not create_branches(state, room)
		end
		if is_penultimate then
			table.insert(penultimate, room.index)
		end
	end

	return penultimate
end

-- Rooms with roomtypes are also revealed. We assign types immediately before
-- revealing.
function WorldMap:AssignRoomtypesToExits(start_room, additional_depth)
	assert(start_room.roomtype, "AssignRoomtypesToExits doesn't assign a type to start_room.")
	assert(additional_depth > 0)
	local biome_location = self.nav:GetBiomeLocation()
	local biome = mapgen.biomes[biome_location.id]

	local biome_id = self.data.gen_state.alternate_mapgen_name or biome_location.id
	biome = mapgen.biomes[biome_id]
	assert(biome, biome_id)

	local transient_state = {
		nav = self.nav,
		rng = self.rng,
		biome = biome,
		biome_location = biome_location,
		limits = biome.roomlimit,
		waiting = { start_room.index },
		dbg_tracker = self.nav.data.gen_state.dbg_tracker,
		mysterymanager = self.mysterymanager,
	}

	local max_depth = start_room.depth + additional_depth - 1

	while #transient_state.waiting > 0 do
		-- For some reason, generation is not determinstic without this sort.
		table.sort(transient_state.waiting)
		local room_id = table.remove(transient_state.waiting, 1)
		local room = self.nav.data.rooms[room_id]
		assert(room.roomtype, "Failed to assign roomtype?")

		if room.depth <= max_depth then
			assign_roomtype_to_exits(transient_state, room_id, room)

			-- Reveal and queue the exits.
			for cardinal,rid in iterator.sorted_pairs(room.connect) do
				if self.nav:is_forward_path(room_id, rid) then
					local dest = self.nav.data.rooms[rid]
					dbassert(dest.roomtype, "Failed to assign roomtype to exit.")
					dest.is_revealed = true
					if dest.connect.west then
						-- Since rooms can merge, we might not be the back link for
						-- this room. Force it to us to help in UI.
						dest.connect.west = room_id
					end
					table.insert(transient_state.waiting, rid)
				end
			end
		end
	end
end

local function clean_positions(nav)
	for _,room in ipairs(nav.data.rooms) do
		room.pos = nil
	end
end

local function create_empty_map(size, biome_location, rng)
	local data = {
		pos = 1,
		entrance_id = nil,
		last_entrance = "west",
		grid = nil,
		size = { x = size.x, y = size.y, },
		max_depth = 1, -- likely overridden
		rooms = {},
		is_fresh_map = true,
		region_id = biome_location.region_id,
		location_id = biome_location.id,
		boss_prefab = nil,
		layout = {
			random_points = {},
			ui_seed = rng:Integer(2^32),
		},
	}
	for i=1,20 do
		table.insert(data.layout.random_points, Vector2(VecUtil_GetRandomPointInRect(1, 1, rng)))
	end

	if biome_location.monsters
		and biome_location.monsters.bosses
		and #biome_location.monsters.bosses > 0
	then
		data.boss_prefab = rng:PickValue(biome_location.monsters.bosses)
	end

	-- State for world gen that persists between rooms so future room choices
	-- can be dictated by past choices.
	data.gen_state = {
		history = {
			seen = {},
			visited = {},
			snooze_seen = {},
			snooze_depth = {},
		},
		dbg_tracker = {}, -- comment out to disable tracking
	}

	data.grid = Grid(size, function(x,y)
		local room = create_room(data.rooms)
		return room.index
	end)

	local start_room = select_entrance_room(data)
	assert(start_room.index)
	dbassert(start_room.index == get_room_id_safe(data, start_room.pos:unpack()))
	start_room.is_entrance = true
	start_room.is_terminal = true
	start_room.depth = 0
	start_room.difficulty = -1
	start_room.hardest_seen = 0
	start_room.roomtype = 'empty'
	start_room.reward = mapgen.Reward.s.plain -- *usually* get a power in entrance
	start_room.roomseed = rng:Integer(1, 2^32-1)
	data.entrance_id = start_room.index
	data.current = start_room.index
	data.current_room_seed = start_room.roomseed

	return data
end

function WorldMap:GenerateTownMap()
	-- We don't generate a real map for town -- just a starter room. We'll grow
	-- the town some way other than dungeon map generation.
	self.rng = krandom.CreateGenerator() -- TODO(determinism):, use a seed here if towns are meant to be deterministic
	self.data = create_empty_map(Vector2(1, 1), biomes.regions.town.locations.brundle, self.rng)
	self.nav = WorldMap.RoomNavigator(self.data)

	for rid,room in ipairs(self.data.rooms) do
		room.world = 'home_town'
	end
	local room = self.nav:get_entrance_room()
	room.roomtype = 'empty'
	room.reward = mapgen.Reward.s.none
	assert(not self.nav:has_resources(room))
end

function WorldMap:GenerateDebugMap()
	TheLog.ch.WorldMap:print("creating debug map")

	local biome_location = biomes.regions.forest.locations.treemon_forest
	if self.inst:HasTag("town") then
		biome_location = biomes.regions.town.locations.brundle
	end

	self.rng = krandom.CreateGenerator()
	self.data = create_empty_map(Vector2(1, 1), biome_location, self.rng)
	self.nav = WorldMap.RoomNavigator(self.data)

	for rid,room in ipairs(self.data.rooms) do
		room.world = debug_world_fake_name
	end
	local room = self.nav:get_entrance_room()

	room.roomtype = 'empty'
	room.difficulty = mapgen.Difficulty.id.easy

	self.data.is_debug = true
	-- No entrance so you start in the centre of the room.
	self.data.last_entrance = nil
end

function WorldMap:IsDebugMap()
	return self.data.is_debug == true
end


local build_horizontal = {
	name = 'horizontal main path',
}

-- Input dimensions includes start, but not end (which never contains other
-- rooms).
function build_horizontal.compute_size(dimensions)
	return Vector2(dimensions.long, dimensions.short)
end

function build_horizontal.find_short_midpoint(size, rng)
	local quarter = size.y / 4
	local midway = rng:Integer(math.floor(quarter), math.floor(3 * quarter))
	midway = lume.clamp(midway, 2, size.y - 1)
	return Vector2(1, midway)
end

function build_horizontal.find_long_midpoint(size, rng)
	local quarter = size.x / 4
	local midway = rng:Integer(math.floor(quarter), math.floor(3 * quarter))
	midway = lume.clamp(midway, 2, size.x - 1)
	return Vector2(midway, 1)
end

function build_horizontal.create_final_room(nav, is_terminal)
	-- Create a final room that always has something good in it.
	local column = {}
	local room
	-- Fill in empty rooms to ensure alignment
	local y = math.floor(nav.data.size.y/2 + 0.5)
	for i=1,y do
		room = create_room(nav.data.rooms, column)
		table.insert(column, room.index)
	end
	table.insert(nav.data.grid, column)
	nav.data.grid.size.x = nav.data.grid.size.x + 1
	room.pos = Vector2(#nav.data.grid, y)
	room.is_terminal = is_terminal
	nav.data.final_id = room.index
	return room
end


function WorldMap:GenerateDungeonMap(biome_location, seed, alt_mapgen_id, quest_data)
	-- TODO(mapgen): Pull dungeon generation out into a separate module to make
	-- test iteration faster. This component encompasses too much functionality now.
	kassert.typeof('table', biome_location)
	seed = seed or os.time(os.date("!*t"))
	self.rng = krandom.CreateGenerator(seed)
	-- self.rng:SetDebug(true, "WorldMapRNG")

	local pathing = build_horizontal
	TheLog.ch.WorldMap:printf("Generating map using %s in location '%s'. Mother Seed %d", pathing.name, biome_location.id, seed)

	local biome = mapgen.biomes[biome_location.id]

	local alternate_mapgen_name = nil
	if alt_mapgen_id
		and biome_location.alternate_mapgens ~= nil
		and biome_location.alternate_mapgens[alt_mapgen_id]
	then
		alternate_mapgen_name = biome_location.alternate_mapgens[alt_mapgen_id]
		biome = mapgen.biomes[alternate_mapgen_name]
		TheLog.ch.WorldMap:printf("Generating using alternate mapgen id=%d name=%s", alt_mapgen_id, alternate_mapgen_name)
	else
		TheLog.ch.WorldMap:printf("Generating using default '%s' mapgen.", biome_location.id)
	end

	kassert.assert_fmt(biome, "Biome location didn't exist in mapgen: %s", biome_location.id)
	local map_size = pathing.compute_size(biome.dimensions)
	self.data = create_empty_map(map_size, biome_location, self.rng)
	self.nav = WorldMap.RoomNavigator(self.data)
	self.encounter_deck = EncounterDeck(self.rng, biome_location.id)
	self.data.encounter_deck = {
		room_type_encounter_sets = self.encounter_deck.room_type_encounter_sets
	}
	-- We determine this *before* the run so dungeon gen is predictable. We
	-- need to sync any changes if players join/leave.
	self.data.wants_quest_room = quest_data and quest_data.wants_quest_room or false

	if alternate_mapgen_name then
		-- Don't write biome/alternate_mapgen table to data. It bloats savedata
		-- and makes iterating on mapgen harder (because we're storing the
		-- whole mapgen table in save data). Instead, just write the key.
		self.data.gen_state.alternate_mapgen_name = alternate_mapgen_name
	end

	local start_room = self.nav:get_entrance_room()
	assert(start_room.index)
	self.data.last_entrance = nil

	-- TODO(dbriscoe): Future design for mapgen:
	-- * distribute multiple events across map
	--   * guarantee player will see choice of certain event types

	local penultimate_room_ids = generate_connections(self.nav, self.rng, start_room, biome)
	assert(self.nav:room_has_connection(start_room), "First walk must connect to entrance.")

	local hype_room = pathing.create_final_room(self.nav)
	local depths = {}
	local top_left = Vector2(1, 1)
	local bounds = Bound2.at(top_left)
	for _,room_id in ipairs(penultimate_room_ids) do
		connect_up(self.data.rooms, room_id, hype_room.index)
		local room = self.data.rooms[room_id]
		table.insert(depths, room.depth)
		room.is_penultimate = true
		bounds = bounds:extend(room.pos)
		--~ TheLog.ch.WorldMapSpam:print("Penultimate room:", room_id)
	end
	local final_room = pathing.create_final_room(self.nav, true)
	connect_up(self.data.rooms, hype_room.index, final_room.index)

	-- World structure is complete

	hype_room.pos = bounds.max + Vector2.unit_x
	hype_room.depth = math.min(table.unpack(depths)) + 1
	final_room.pos = hype_room.pos + Vector2.unit_x
	final_room.depth = hype_room.depth + 1
	-- Hype and boss are presented as a single room.
	self.data.max_depth = math.max(table.unpack(depths)) + 1
	--~ TheLog.ch.WorldMap:print("max_depth", self.data.max_depth, "room count", #self.data.rooms)

	set_world_for_room(self.nav, self.rng, start_room, biome_location)


	bounds = Bound2.at(top_left)
	for _,room in ipairs(self.data.rooms) do
		if room.depth and room.pos then
			bounds = bounds:extend(room.pos)
			if room.pos.y <= 0 then
				TheLog.ch.WorldMap:print("room =", table.inspect(room, { depth = 5, process = table.inspect.processes.skip_mt, }))
				error("Invalid room position.")
			end
		end
	end
	kassert.greater(bounds.min.x, 0)
	kassert.greater(bounds.min.y, 0)
	self.data.bounds = bounds:size():to_table()

	clean_positions(self.nav)

	kassert.equal(lume.count(final_room.connect), 1) -- all enter through single hype room

	self:_MarkRoomIdVisited(self.data.current)
	assert(start_room.world, "Failed to set world for entrance.")

	self.data.mother_seed = seed -- save this for reference
end

--Don't use OnSave/OnLoad
--This is not part of an individual world's save data

function WorldMap:GetMapData()
	local data = deepcopy(self.data)
	lume.clear(data.layout.random_points)
	for i,v in ipairs(self.data.layout.random_points) do
		table.insert(data.layout.random_points, {v.x, v.y})
	end
	data.grid = self.data.grid:GetSaveData()
	data.mystery_data = self.mysterymanager:SaveData()
	data.shopmanager_data = self.shopmanager:SaveData()
	return data
end

function WorldMap:LoadMapData(data)
	if not data then
		TheLog.ch.WorldMap:print("WARNING: Loaded WorldMap but had no data.")
		return
	end
	-- Ensure we don't change savedata after loading (it's kept in a SaveData).
	self.data = deepcopy(data)

	self.data.layout.random_points = lume.map(self.data.layout.random_points, ToVector2)
	self.data.grid = Grid(data.size):LoadSaveData(data.grid)
	self.mysterymanager:LoadData(self.data.mystery_data)
	self.shopmanager:LoadData(self.data.shopmanager_data)

	TheLog.ch.WorldMap:printf("LoadMapData: Creating RNG with room seed %s", self.data.current_room_seed)
	self.rng = krandom.CreateGenerator(self.data.current_room_seed)
	self.nav = WorldMap.RoomNavigator(self.data)
	self.weathermanager:OnLoad()
	self.encounter_deck = EncounterDeck(
		self.rng,
		self.data.location_id,
		self.data.encounter_deck.room_type_encounter_sets)
end

function WorldMap:RevealPath(path)
	local prev_rid
	for i,room_id in ipairs(path) do
		local room = self.data.rooms[room_id]
		if prev_rid
			and not room.is_revealed
			and room.connect.west
		then
			room.connect.west = prev_rid
		end
		room.is_revealed = true
		self:Debug_LogProcGenInputsForRoom(room)
		prev_rid = room_id
	end
end

function WorldMap:Debug_LogProcGenInputsForRoom(room)
	if self.data.gen_state.dbg_tracker then
		if type(room) == "number" then
			room = self.data.rooms[room]
		end
		if not room then
			room = self:Debug_GetCurrentRoom()
		end
		local hist = {}
		for cardinal,rid in pairs(room.connect) do
			hist[cardinal] = self.data.gen_state.dbg_tracker[rid]
		end
		hist.west = nil
		--~ hist.room = room -- uncomment for more verbose
		local mapgen_name = "using default mapgen"
		if self.data.gen_state.alternate_mapgen_name then
			mapgen_name = ("using %s"):format(self.data.gen_state.alternate_mapgen_name)
		end
		TheLog.ch.WorldMap:print("worldgen state when picking exits of", room.index, mapgen_name, table.inspect(hist, { depth = 5, process = table.inspect.processes.skip_mt, }))
	end
end

function WorldMap:RevealAll()
	for room_id,room in pairs(self.data.rooms) do
		room.is_revealed = true
	end
end

function WorldMap:_MarkRoomIdVisited(room_id)
	local room = self.data.rooms[room_id]
	if room.has_visited then
		-- Does this happen often?
		print("Already visited ".. room_id)
		return
	end
	room.has_visited = true
	room.is_revealed = true
	self:AssignRoomtypesToExits(room, self:_GetScoutLevel())
end

function WorldMap:_GetScoutLevel()
	-- Always grab it from save data to ensure we're always using the latest
	-- scout level (WorldMap may be created before player does scout upgrades,
	-- but then we StartRun after).
	--~ return TheSaveSystem.friends:GetValue("scout") or 1
	-- TODO(dbriscoe): For VS1, we're cutting out the scout upgrading and
	-- forcing scout level 2 for everyone.
	return 1
end

-- victorc: This can't be called from a Lua thread until after all TheSaveSystem calls are done
function WorldMap:StartRun(biome_location, cb, seed, alt_mapgen_id)
	kassert.typeof('table', biome_location)
	kassert.typeof('string', biome_location.id, biome_location.region_id)

	-- Broadcast *first* so other systems can write before we save!
	for _,p in ipairs(AllPlayers or {}) do
		p:PushEvent("start_new_run", biome_location)
	end
	self.inst:PushEvent("start_new_run", biome_location)

	local next_level_name, next_room_id, next_room_seed
	local _cb = MultiCallback()

	-- Only need to save current room if we're in town.
	if self.inst:HasTag("town") then
		local current_room_id = self.data.current
		TheSaveSystem.town:SaveCurrentRoom(current_room_id, _cb:AddInstance())
	end

	-- TEMP JBELL KONJUR DEBUG SAVE SYSTEM
	TheSaveSystem.progress:SetValue("konjur_debug", {})

	TheLog.ch.Metrics:print("Begin metrics session")
	TheSim:BeginMetricsSession()

	TheSaveSystem.dungeon:ClearAllRooms(_cb:AddInstance())

	self:GenerateDungeonMap(biome_location, seed, alt_mapgen_id, self:BuildQuestParams())
	local entrance = self.nav:get_entrance_room()
	assert(entrance.is_entrance, "Failed to tag first room as entrance or need to update StartRun for how entrance is determined.")
	assert(entrance.world, "Failed to set world for entrance.")
	next_level_name = entrance.world
	next_room_id = entrance.index
	next_room_seed = entrance.roomseed

	self.data.current = next_room_id
	self.data.current_room_seed = next_room_seed
	self.data.is_fresh_map = false
	self.data.travel_history = {}
	if TheNet:IsHost() then
		TheNet:HostSetRoomTravelHistory({})
	end

	self.mysterymanager:ResetAllMysteryChances()
	self.shopmanager:ResetAllWareChances()

	local data = self:GetMapData()
	TheSaveSystem.dungeon:SetValue("worldmap", data)
	TheSaveSystem:SaveAllExcludingRoom(_cb:AddInstance())

	local scene_gen = biome_location:GetSceneGen(scenegenutil.ASSERT_ON_FAIL)
	_cb:WhenAllComplete(function(success)
		if not success then
			TheLog.ch.WorldMap:print("WARNING: Failed to save/clear data before loading new dungeon.")
			dbassert(false)
		end
		if cb ~= nil then
			cb()
		end
		if TheNet:IsHost() then
			TheLog.ch.WorldMap:printf("StartRun Host loading room: %s room_id=%d room_seed=%d", next_level_name, next_room_id, next_room_seed)
			RoomLoader.LoadDungeonLevel(next_level_name, scene_gen, next_room_id)
		else
			TheLog.ch.WorldMap:printf("StartRun Client waiting for host loading room: %s room_id=%d room_seed=%d", next_level_name, next_room_id, next_room_seed)
		end
	end)
end

function WorldMap:BuildQuestParams()
	local quest = {
		wants_quest_room = false,
	}
	if TheDungeon then
		-- TODO(questroom): MeetingManager should re-evaluate when players drop mid-run.
		quest.wants_quest_room = not not TheDungeon.progression.components.meetingmanager:WantsQuestRoom()
	else
		TheLog.ch.WorldMap:print("No TheDungeon when starting run. Using no progression data.")
	end
	return quest
end

function WorldMap:EndRun(run_state, cb)
	dbassert(not self.endrun)
	self.endrun = true

	local is_victory = run_state ~= nil and run_state == RunStates.s.VICTORY

	TheLog.ch.WorldMap:printf("EndRun (victory = %s) called", is_victory and "true" or "false")

	-- Broadcast *first* so other systems can write before we save!
	local data = {
		is_victory = is_victory,
		run_state = run_state,
		progress = self.nav:GetProgressThroughDungeon(),
		dungeon_id = self.data.location_id,
	}
	for _,p in ipairs(AllPlayers or {}) do
		if p:IsLocal() and not p:IsSpectating() then
			p:PushEvent("end_current_run", data)
		end
	end
	self.inst:PushEvent("end_current_run", data)

	if self.nav:GetProgressThroughDungeon() > 0 then
		-- if you at least left the first room
		TheSaveSystem.progress:IncrementValue("num_runs")
		TheSaveSystem.permanent:IncrementValue("num_runs")
	end

	TheLog.ch.Metrics:print("Ending metrics session")
	TheSim:EndMetricsSession()

	TheSaveSystem:SaveAllExcludingRoom(function(success)
		if not success then
			TheLog.ch.WorldMap:print("WARNING: Failed to save data before returning to town.")
			dbassert(false)
		end
		if cb then
			cb()
		end
	end)
end

function WorldMap:ReturnToTown()
	local load_fn = function()
		if TheNet:IsHost() then
			TheNet:HostSetRoomTravelHistory({})
			TheLog.ch.WorldMap:printf("Host returning to town...")
			RoomLoader.LoadTownLevel(TOWN_LEVEL)
		else
			TheLog.ch.WorldMap:printf("Client waiting for host to return to town...")
		end
	end

	if not self.endrun then
		TheLog.ch.WorldMap:printf("Warning: Attempting to return to town before ending run")
		self:EndRun(nil, load_fn)
	else
		load_fn()
	end
end

function WorldMap:RecordActionInCurrentRoom(label)
	assert(label)
	local room = self.data.rooms[self.data.current]
	-- We store the label purely to see it when debugging.
	room.used_room_action = label
end

local function find_biome_using_world(world_name)
	local arena_name = world_name:gsub("^(.-)(_%w+_%w+)$", "%1") -- strip _arena_nesw suffix
	local boss_name = arena_name:gsub("^(.-)(_%w+)$", "%1") -- strip _megatreemon boss suffix
	local function matches_world(w)
		return w == arena_name or w == boss_name
	end
	return lume.match(biomes.locations, function(loc)
		return lume.match(loc.worlds, matches_world)
	end)
end

function WorldMap:Debug_StartArena(level, room_overrides)
	kassert.assert_fmt(WorldAutogenData[level], "Unknown world '%s'.", level)
	TheLog.ch.WorldMap:printf("Debug_StartArena: level=%s room_overrides=%s", level, table.inspect(room_overrides))
	local _cb = MultiCallback()

	local biome_location = biomes.locations[room_overrides.location]
	if not biome_location then
		biome_location = find_biome_using_world(level)
	end
	if not biome_location
		and (WorldAutogenData[level].is_debug
			or kstring.startswith(level, "test_"))
	then
		TheLog.ch.WorldMap:print("WARNING: Failed to determine biome for world...defaulting to treemon_forest.")
		biome_location = biomes.locations.treemon_forest
	end
	kassert.assert_fmt(biome_location, "Unknown biome for %s. Probably too many underscores in world name. Change Dungeon to Debug for test levels.", level)

	-- Broadcast *first* so other systems can write before we save!
	for _,p in ipairs(AllPlayers or {}) do
		p:PushEvent("start_new_run", biome_location)
	end
	self.inst:PushEvent("start_new_run", biome_location)

	TheSaveSystem.dungeon:ClearAllRooms(_cb:AddInstance())
	local mother_seed = DEFAULT_MOTHER_SEED
	self:GenerateDungeonMap(biome_location, mother_seed)

	if room_overrides.depth_fn then
		room_overrides.depth = room_overrides.depth_fn(self.data.max_depth)
		room_overrides.depth_fn = nil
	end

	self.data.is_cheat = true

	local connect = deconstruct_world_suffix(level)
	local sorted_connect = lume.keys(connect)
	table.sort(sorted_connect)

	local room = nil
	-- Don't have roomtypes assigned far ahead, so we can't search for
	-- roomtype. Find specific ones.
	if room_overrides.roomtype == "hype" then
		local hype_id = self.nav:get_hype_room_id()
		room = self.data.rooms[hype_id]
	elseif room_overrides.roomtype == "boss" then
		room = self.nav:get_final_room()
	end

	if not room then
		room = self.nav:find_room(function(r)
			for _i,cardinal in ipairs(sorted_connect) do
				if not r.connect[cardinal] then
					return false
				end
			end
			return true
		end)
	end

	if room then
		TheLog.ch.WorldMap:printf("Debug_StartArena: Using room id=%d", room.index)
		-- Pick a valid entrance with preference for most likey correct setups.
		self.data.last_entrance = (connect.west
			or connect.south
			or next(connect))
	else
		TheLog.ch.WorldMap:printf("Couldn't find a room matching exits for world='%s'. Using fallback. Exits might not connect.", level)
		for i,candidate in ipairs(self.data.rooms) do
			if not candidate.is_entrance
				and self.nav:is_room_reachable(candidate)
			then
				room = candidate
				break
			end
		end
		assert(room, "Failed to find a reachable nonentrance room?!")
		self.data.last_entrance = next(connect)
	end
	if room.difficulty == -1 then
		-- Clear invalid difficulty (which can break combat systems) and set it
		-- below with override or default.
		room.difficulty = nil
	end

	if room_overrides.roomtype == "boss" then
		-- Clear connections so we don't try to generate rooms for them.
		room.connect = {}
		room.backlinks = {}
		-- Force boss-level depth.
		room.depth = self.data.max_depth
	end

	if room_overrides.last_entrance then
		self.data.last_entrance = room_overrides.last_entrance
		room_overrides.last_entrance = nil -- not actually a room value
	end

	local rid = room.index
	local roomseed = room.roomseed or 0
	self.data.current = rid
	self.data.current_room_seed = roomseed
	self.data.travel_history = {}

	for key,val in pairs(room_overrides) do
		room[key] = val
	end
	room.difficulty = room.difficulty or mapgen.Difficulty.id.hard
	room.hardest_seen = room.hardest_seen or mapgen.Difficulty.id.hard
	assert(room.difficulty)
	assert(room.roomtype)

	local data = self:GetMapData()
	data.room_overrides = room_overrides
	TheSaveSystem.dungeon:SetValue("worldmap", data)
	TheSaveSystem:SaveAllExcludingRoom(_cb:AddInstance())

	local scene_gen = biome_location:GetSceneGen(scenegenutil.ASSERT_ON_FAIL)
	_cb:WhenAllComplete(function(success)
		dbassert(success, "WARNING: Failed to save/clear data before loading new dungeon.")
		-- Even though this is debug, we load the real level because want to
		-- see it load normally.
		if TheNet:IsHost() then
			TheNet:HostStartArena(level, room_overrides.roomtype, room_overrides.location or biome_location.id, mother_seed)
			-- wait for remote generation confirmation, but that confirmation does not exist
			RoomLoader.LoadDungeonLevel(level, scene_gen, rid)
		else
			TheLog.ch.WorldMap:printf("Waiting for host to start arena via room load...")
		end
	end)
end

function WorldMap:Debug_ReloadDungeonFromDisk()
	TheLog.ch.WorldMap:printf("Debug_ReloadDungeonFromDisk")
	local _cb = MultiCallback()
	TheSaveSystem:LoadAll(_cb:AddInstance())

	_cb:WhenAllComplete(function(success)
		if not success then
			-- Failing to load town is probably okay so long as we have the
			-- dungeon BECAUSE this is debug.
			TheLog.ch.WorldMap:print("WARNING: ReloadDungeonFromDisk failed to load some data from disk.")
		end

		local data = TheSaveSystem.dungeon:GetValue("worldmap")
		assert(data, "No dungeon data to load.")
		self:LoadMapData(data)
		self.data.is_cheat = true
		local biome_location = self:GetBiomeLocation()
		local scene_gen = biome_location:GetSceneGen(scenegenutil.ASSERT_ON_FAIL)

		local room = self:Debug_GetCurrentRoom()
		TheLog.ch.WorldMap:printf("Debug_ReloadDungeonFromDisk: world %s, room %i roomseed %d", room.world or "unknown", room.index or 0, room.roomseed or 0)
		-- Even though this is debug, we load the real level because want to
		-- see it load normally.
		RoomLoader.LoadDungeonLevel(room.world, scene_gen, room.index)
	end)
end

-- A gate doesn't necessarily go anywhere.
function WorldMap:HasGateInCardinalDirection(cardinal)
	local room = self.data.rooms[self.data.current]
	-- While we have grid positions, we prefer to travel through connections.
	local next_room_id = room.connect[cardinal]
	if next_room_id then
		return true
	end
	return (self:IsDebugMap()
		and lume.find(self:GetCurrentWorldEntrances(), cardinal))
end

-- Returning nil means destination is invalid.
function WorldMap:GetDestinationForCardinalDirection(cardinal)
	local room = self.data.rooms[self.data.current]
	-- While we have grid positions, we prefer to travel through connections.
	local next_room_id = room.connect[cardinal]
	if self.data.last_entrance == cardinal then
		-- No backtracking -- previous room is blocked.
		return nil

	elseif next_room_id then
		room = self.data.rooms[next_room_id]
		assert(room, "How did we have a connection to an invalid room?")
		return room
	end
end

-- Gets north/east/south/west if the room is adjacent to our current room,
-- Otherwise returns nil
function WorldMap:GetCardinalDirectionForAdjacentRoomId(room_id)
	local room = self.data.rooms[self.data.current]
	for cardinal,next_room_id in pairs(room.connect) do
		if next_room_id == room_id then
			return cardinal
		end
	end
	return nil
end

function WorldMap:GetCardinalDirectionForEntrance()
	return self.data.last_entrance
end

local function DifficultyToArt(difficulty)
	local count = difficulty or 0
	kassert.lesser_or_equal(count, 4, "Why is room.difficulty so big?")
	-- We only have two difficulty levels. Only show hard for the hardest
	-- levels because easy ones are just for intro.
	if count >= mapgen.Difficulty.id.hard then
		return 2
	end
	return 1
end

local roomtype_to_key = {
	monster = "", -- uses reward_to_key instead
	miniboss = "miniboss",
	food = "food",
	resource = "resource",
	chest = "chest",
	potion = "potion",
	market = "market",
	powerupgrade = "powerupgrade",
	mystery = "specialevent", --TODO(jambell): replace with mystery-named icon
	wanderer = "specialevent", -- This only shows up when one of these rooms is explicitly placed in the mapgen. Otherwise, hidden behind 'mystery'
	ranger = "specialevent", -- This only shows up when one of these rooms is explicitly placed in the mapgen. Otherwise, hidden behind 'mystery'
	quest = "quest",
	insert = "specialevent", -- Quest specific room that is inserted at a point that the quest defines. Does not appear on the map.
	hype = "boss_%s", -- requires boss prefab name
	boss = "", -- shown on hype room instead
	entrance = "entrance",
	unexplored = "unexplored",
	empty = "unexplored", -- for debug playing
}

-- Returns the identifier we use for various bits of art that represent a room
-- (gate indicator anim name, map icon tex name).
function WorldMap.RoomNavigator:GetArtNameForRoom(room)
	local roomtype = self:get_roomtype(room)

	local roomtypevisual = roomtype
	-- If it's a mystery room, force to mystery icon. Otherwise, do the normal thing
	if room.is_mystery then
		roomtypevisual = "mystery"
	end
	local key = roomtype_to_key[roomtypevisual]
	kassert.assert_fmt(key, "Unhandled roomtype '%s'.", roomtype)

	if roomtype == 'monster' and not room.is_mystery then -- Don't override the visual if it's a mystery room
		-- Only monster rooms drop rewards, so show that instead.
		key = self:_GetArtNameForReward(room)
		kassert.assert_fmt(key, "Monster rooms should always have rewards. cheat=%s", self.data.is_cheat)

	elseif roomtype == 'boss' or roomtype == 'hype' then
		local bossprefab = self:GetDungeonBoss()
		key = key:format(bossprefab)
	end
	dbassert(not key:find("%", nil, true), key) -- missed a case for format()
	if key == "" then
		return nil
	end
	return key
end

local reward_to_key = {
	-- All require difficulty.
	coin = "coin%d",
	plain = "plain%d",
	fabled = "fabled%d",
	skill = "skill%d",
	small_token = "smalltoken%d",
	big_token = "bigtoken%d",
}

-- Returns the identifier we use for various bits of art that represent a room
-- (gate indicator anim name, map icon tex name).
function WorldMap.RoomNavigator:_GetArtNameForReward(room)
	local reward = room.reward
	if reward == mapgen.Reward.s.none then
		return nil
	end
	local key = reward_to_key[reward]
	kassert.assert_fmt(key, "Unhandled reward '%s'.", reward)
	local count = DifficultyToArt(room.difficulty)
	key = key:format(count)
	-- print("reward:", reward, "key:", key, "count:", count)
	dbassert(not key:find("%", nil, true), key) -- missed a case for format()
	return key
end

-- Returns the identifier we use for various bits of art that represent a room
-- (gate indicator anim name, map icon tex name).
function WorldMap.RoomNavigator:GetArtDescriptions()
	local rewards = lume.map(reward_to_key, function(v)
		return v:format(1)
	end)
	local type_to_key = lume.merge(roomtype_to_key, rewards)
	type_to_key.monster = type_to_key.monster:format(1)
	type_to_key.hype = type_to_key.hype:format(self:GetDungeonBoss())
	type_to_key.boss = nil -- no art for boss room

	dbassert(lume.all(type_to_key, function(key)
		return not key:find("%", nil, true)
	end), "missed a case for format()")
	return type_to_key
end

function WorldMap:_AddToRoomTravelHistory(room_id, cardinal_exit)
	if not self.data.travel_history then
		self.data.travel_history = {}
	end
	table.insert(self.data.travel_history,
		{
			index = room_id,
			cardinal = mapgen.Cardinal.id[cardinal_exit],
		})

	if TheNet:IsHost() then
		TheNet:HostSetRoomTravelHistory(self.data.travel_history)
	end
end

function WorldMap:_ModifyRoomTravelHistory(room_id, extra_data)
	assert(self.data.travel_history, "Can't modify non-existent travel history: Use _AddToRoomTravelHistory first")

	for _i,data in ipairs(self.data.travel_history) do
		if data.index == room_id then
			for k,v in pairs(extra_data) do
				assert(k ~= "index" and k ~= "cardinal")
				TheLog.ch.WorldMap:printf("Modify Travel History: room_id %d adding %s = %s", room_id, tostring(k), tostring(v))
				data[k] = v
			end

			if TheNet:IsHost() then
				dumptable(self.data.travel_history)
				TheNet:HostSetRoomTravelHistory(self.data.travel_history)
				return
			end
		end
	end

	TheLog.ch.WorldMap:printf("Warning: Tried to modify travel history for non-existent room id %d", room_id)
end

function WorldMap:_GetRoomTravelHistory(room_id)
	local travel_history = TheNet:GetRoomTravelHistory()
	for _i,data in ipairs(travel_history) do
		if data.index == room_id then
			return data
		end
	end

	TheLog.ch.WorldMap:printf("Warning: Tried to get travel history for non-existent room id %d", room_id)
end

function WorldMap:_SetMysteryEvent(next_room, current_room, replaymode, _cb)
	local specialeventroom_type, save_keyname

	if next_room.roomtype == "wanderer" then
		specialeventroom_type = SpecialEventRoom.Types.CONVERSATION
		save_keyname = "selected_wanderer"
	elseif next_room.roomtype == "ranger" then
		specialeventroom_type = SpecialEventRoom.Types.MINIGAME
		save_keyname = "selected_ranger"
	else
		-- TheLog.ch.WorldMap:printf("Next room type is %s: No mystery event required", next_room.roomtype)
		TheSaveSystem.dungeon:SetValue("selected_ranger", nil)
		TheSaveSystem.dungeon:SetValue("selected_wanderer", nil)
		return
	end

	local mystery_rng = krandom.CreateGenerator(next_room.roomseed)

	local event_name
	if TheNet:IsHost() or not replaymode then
		event_name = self.mysterymanager:GetRandomEventByType(mystery_rng, specialeventroom_type).name
	else
		-- clients will always override their next selected_ mystery with the host value's current room
		assert(not TheNet:IsHost())

		local room_history = self:_GetRoomTravelHistory(current_room.index)
		assert(room_history and room_history[save_keyname])
		event_name = room_history[save_keyname]
		TheLog.ch.WorldMap:printf("Travel History setting mystery room event: %s", event_name)
	end

	TheSaveSystem.dungeon:SetValue(save_keyname, event_name)
	if (TheNet:IsHost() or not replaymode) and event_name then
		self:_ModifyRoomTravelHistory(current_room.index, { [save_keyname] = event_name })
	end
end

-- TODO: networking2022, victorc - cleanup this messy replay mode
-- Possibly integrate this with debug dungeon stepping
function WorldMap:TravelCardinalDirection(cardinal, cb, replaymode)
	if not replaymode then
		if self.traveling_cardinal then
			if self.traveling_cardinal == cardinal then
				TheLog.ch.WorldMap:printf("TravelCardinalDirection: Already traveling %s from room id %d. Ignoring extra request.",
					cardinal, self.data.current)
				return
			else
				local error_msg = string.format("TravelCardinalDirection: Double traveling in different directions (existing: %s, new: %s)",
					self.traveling_cardinal, cardinal)
				assert(false, error_msg)
			end
		end
		self.traveling_cardinal = cardinal
	end

	self:_AddToRoomTravelHistory(self.data.current, cardinal)

	if not replaymode then
		-- Broadcast *first* so other systems can write before we save!
		for i,player in ipairs(AllPlayers) do
			player:PushEvent("exit_room")
		end
		self.inst:PushEvent("exit_room")
	end

	local isintown = TheWorld and TheWorld:HasTag("town")
	local next_level_name, next_room_id, next_room_seed
	local _cb = MultiCallback()

	if not replaymode then
		TheSaveSystem:SaveCurrentRoom(_cb:AddInstance())
	end

	local current_room = self.data.rooms[self.data.current]
	local next_room = self:GetDestinationForCardinalDirection(cardinal)
	if not next_room then
		-- HACK(dbriscoe): Debug info for failing assert.
		TheLog.ch.WorldMap:print("Trying to go", cardinal, "current_room:", table.inspect(current_room), "\nrooms:", table.inspect(self.data.rooms, { depth = 2, }))
	end
	assert(next_room, "Trying to travel to invalid room")
	assert(next_room.world, "Trying to travel to room without a world.")
	next_level_name = next_room.world
	next_room_id = next_room.index
	next_room_seed = next_room.roomseed
	-- Completely ignores exit direction from current room because lore
	-- connects room with winding roads!
	self.data.last_entrance = next_room.backlinks[current_room.index]
	assert(self.data.last_entrance)

	self.data.current = next_room_id
	self.data.current_room_seed = next_room_seed or 0
	self.data.is_fresh_map = false

	self:_SetMysteryEvent(next_room, current_room, replaymode, _cb)

	if next_room.roomtype == mapgen.roomtypes.RoomType.s.market and not replaymode then
		self.shopmanager:FillMarkets()
	end

	local data = self:GetMapData()

	if not replaymode then
		if isintown then
			dbassert(false, "Not supported YET")
			TheSaveSystem.town:SetValue("worldmap", data)
		else
			TheSaveSystem.dungeon:SetValue("worldmap", data)
		end
		TheSaveSystem:SaveAllExcludingRoom(_cb:AddInstance())
	end

	if not replaymode then
		local scenegen_prefab = TheSceneGen.prefab
		_cb:WhenAllComplete(function(success)
			if not success then
				TheLog.ch.WorldMap:print("WARNING: Failed to save data before loading next room.")
				dbassert(false)
			end
			if isintown then
				dbassert(false, "Not supported YET")
				RoomLoader.LoadTownLevel(next_level_name, next_room_id)
			elseif TheNet:IsHost() then
				TheLog.ch.WorldMap:printf("Host loading room: %s room_id=%d room_seed=%s", next_level_name, next_room_id, tostring(next_room_seed))
				RoomLoader.LoadDungeonLevel(next_level_name, scenegen_prefab, next_room_id)
			else
				TheLog.ch.WorldMap:printf("Client waiting for host loading room: %s room_id=%d room_seed=%s", next_level_name, next_room_id, tostring(next_room_seed))
			end
			if cb ~= nil then
				cb()
			end
		end)
	end
end

function WorldMap:OnCompletedTravel()
	self.traveling_cardinal = nil
	self:_MarkRoomIdVisited(self.data.current)
	self:ClientReplayTravelHistory()
end

-- Step the dungeon internal state for debug stepping and client replay travel history use
function WorldMap:_StepDungeon(cardinal)
	-- this is the stuff that should be identical for real travel vs replay
	-- this happens at the end of the room lifecycle
	self:TravelCardinalDirection(cardinal, nil, true)
	-- this happens at the start of the room lifecycle (see LoadMapData)
	self.rng = krandom.CreateGenerator(self.data.current_room_seed)
	self:_MarkRoomIdVisited(self.data.current)
	-- self.nav = WorldMap.RoomNavigator(self.data.current) -- TODO: networking2022, doesn't seem needed and actually breaks things?
	self.encounter_deck = EncounterDeck(
		self.rng,
		self.data.location_id,
		self.data.encounter_deck.room_type_encounter_sets)
end

function WorldMap:ClientReplayTravelHistory()
	if TheNet:IsHost() then
		return
	end

	-- compare the host travel history to our history
	-- try to replay the cardinal travel to match-up
	TheLog.ch.Networking:printf("Client replay travel history started.")
	local host_travel_history = TheNet:GetRoomTravelHistory()
	if not host_travel_history then
		TheLog.ch.Networking:printf("Client replay travel history finished (no data).")
		return
	end

	for i,entry in ipairs(host_travel_history) do
		-- ignore until a difference appears
		if not self.data.travel_history[i] or
			self.data.travel_history[i].index ~= entry.index or
			self.data.travel_history[i].cardinal ~= entry.cardinal then
			-- align travel history size
			while #self.data.travel_history > #host_travel_history do
				table.remove(self.data.travel_history)
			end
			-- actual replay of worldmap travel
			local cardinal = mapgen.Cardinal:FromId(entry.cardinal)
			TheLog.ch.Networking:printf("Client replay traveling %s from room id %d type %s", cardinal, entry.index, self.data.rooms[entry.index].roomtype)
			self:_StepDungeon(cardinal)
		end
	end
	TheLog.ch.Networking:printf("Client replay travel history finished (%d entries).", #host_travel_history)
end

function WorldMap.RoomNavigator:GetDungeonBoss()
	return self.data.boss_prefab
end

function WorldMap:GetMotherSeed()
	return self.data.mother_seed
end

-- Should we spawn enemy type in current room.
function WorldMap:HasEnemyForCurrentRoom(enemy_type)
	assert(mapgen.roomtypes.Enemy:Contains(enemy_type), "Invalid enemy type: ".. enemy_type)
	local room = self.data.rooms[self.data.current]
	return room.roomtype == enemy_type
end

-- Should we spawn a specific encounter for this room.
function WorldMap:GetForcedEncounterForCurrentRoom()
	local room = self.data.rooms[self.data.current]
	return room.forced_encounter
end


-- If boss room, this is difficulty of the boss. If monster room, difficulty of
-- mobs. If empty, ignore this value.
function WorldMap:GetDifficultyForCurrentRoom()
	local room = self.data.rooms[self.data.current]
	return room.difficulty
end

-- Returns one of the string values in mapgen.Reward. Returns nil for no
-- reward.
function WorldMap:GetRewardForCurrentRoom()
	local room = self.data.rooms[self.data.current]
	if room.reward == mapgen.Reward.s.none then
		return nil
	end
	return room.reward
end

function WorldMap:IsCurrentRoomDungeonEntrance()
	return self.data.current == self.data.entrance_id
end

function WorldMap:GetRoomData(room_id)
	room_id = room_id or self.data.current
	return self.data.rooms[room_id]
end

function WorldMap:GetCurrentRoomType()
	local room = self.data.rooms[self.data.current]
	return self.nav:get_roomtype(room)
end

function WorldMap:IsCurrentRoomType(roomtype)
	assert(mapgen.roomtypes.RoomType:Contains(roomtype), "Invalid roomtype: ".. roomtype)
	local room = self.data.rooms[self.data.current]
	return self.nav:get_roomtype(room) == roomtype
end

function WorldMap:ShouldSkipMapTransitionFromCurrentRoom()
	return self:IsInBossArea()
end

function WorldMap:DoesCurrentRoomHaveResources()
	local room = self.data.rooms[self.data.current]
	return self.nav:has_resources(room)
end

-- Avoid random code checking for roomtypes and instead expose ways to get
-- roomtype-specific info or use roomtype aware spawners. That reduces how many
-- things know about specific roomtypes, we're more free to rename roomtypes,
-- and it's easier to add new content for new roomtypes.
--
--~ function WorldMap:DoesCurrentRoomHaveChef()
--~ 	local room = self.data.rooms[self.data.current]
--~ 	return self.nav:get_roomtype(room) == 'food'
--~ end

--~ function WorldMap:DoesCurrentRoomHaveShop()
--~ 	local room = self.data.rooms[self.data.current]
--~ 	return self.nav:get_roomtype(room) == 'powerupgrade'
--~ end

--~ function WorldMap:DoesCurrentRoomHaveSpecialEvent()
--~ 	local room = self.data.rooms[self.data.current]
--~ 	return self.nav:get_roomtype(room) == 'specialevent'
--~ end

function WorldMap:GetCurrentRoomAudio()
	local room = self.data.rooms[self.data.current]
	local roomtype = self.nav:get_roomtype(room)
	local biome_location = self:GetBiomeLocation()
	return biome_location.room_audio[roomtype]
end

-- Includes both the hype and boss rooms.
function WorldMap:IsInBossArea()
	local room = self.data.rooms[self.data.current]
	local roomtype = self.nav:get_roomtype(room)
	return roomtype == 'hype' or roomtype == 'boss'
end

function WorldMap:DoesCurrentRoomHaveCombat()
	local room = self.data.rooms[self.data.current]
	return self.nav:get_roomtype(room) == 'boss' or self.nav:get_roomtype(room) == 'miniboss' or self.nav:get_roomtype(room) == 'monster'
end

function WorldMap:GetCurrentRoomId()
	return self.data.current
end

function WorldMap:GetCurrentRoomSeed()
	return self.data.current_room_seed
end

function WorldMap.RoomNavigator:GetBiomeLocation()
	return biomes.locations[self.data.location_id]
end

function WorldMap:GetBiomeLocation()
	return self.nav:GetBiomeLocation()
end

-- Outer bounds. Not all rooms inside these bounds are valid. Use
-- RoomNavigator:get_room_id_safe.
-- For room bounds, see RoomNavigator:get_room_dimensions.
function WorldMap:GetBounds()
	return self.data.grid.size
end

function WorldMap:GetLastPlayerCount()
	return TheNet:GetNrPlayersOnRoomChange()
end

function WorldMap:GetRNG()
	return self.rng
end

function WorldMap:BuildAsciiMap()
	local v_hall_fmt   = "%s%s"
	local v_hall_empty = '          '
	local v_hall_conn  = '    |     '
	local h_hall_empty = '  '
	local h_hall_conn  = '--'
	local str = ""
	str = str .. "↑ N\n"
	-- Map is drawn top to bottom, but the layers are indexed left to right, so
	-- iterate over bounds instead of arrays.
	local bounds = self:GetBounds()
	for y=1,bounds.y do
		for x=1,bounds.x do
			local room_id = self.nav:get_room_id_safe(x,y)
			local room = self.data.rooms[room_id]
			local sep = v_hall_empty
			if room and room.connect.north then
				sep = v_hall_conn
			end
			str = string.format(v_hall_fmt, str, sep)
		end
		str = str .. "\n"
		for x=1,bounds.x do
			local room_id = self.nav:get_room_id_safe(x,y)
			local room = self.data.rooms[room_id]
			local label = '      '
			local left_sep = h_hall_empty
			local right_sep = h_hall_empty
			if room then
				local roomtype = self.nav:get_roomtype(room)
				-- Exits usually connect to west and nothing exits through west, so ignore.
				--~ if room.connect.west then
				--~ 	left_sep = h_hall_conn
				--~ end
				if room.connect.east then
					right_sep = h_hall_conn
				end
				--~ label = ('%-3d '):format(room_id)
				--~ label = room.depth and ('%-3d '):format(room.depth) or ""
				--~ label = (room.depth or -1) > math.ceil(self.data.max_depth / 2) and "deep" or "shal"
				--~ label = ('%-3d '):format(room.difficulty or -1)
				--~ label = ('%d,%d'):format(x, y)
				--~ label = build_world_suffix(room)
				label = ('%02d%2s'):format(room_id % 100, roomtype:sub(1,2)) -- % because only space for two digits
				--~ label = ('%4s'):format(roomtype:sub(1,4))
				--~ label = ('%4s'):format(room.reward:sub(1,4))
				assert(label:len() <= 4, "Larger strings break formatting")
				if self.nav:is_current_room(room_id) then
					label = ('[%4s]'):format(label)
				elseif room.is_terminal then
					label = ('!%4s!'):format(label)
				elseif room.is_penultimate then
					label = ('_%4s_'):format(label)
				else
					label = (' %4s '):format(label)
				end
			end
			str = string.format("%s%s%s%s", str, left_sep, label, right_sep)
		end
		str = str .. "\n"
		for x=1,bounds.x do
			local room_id = self.nav:get_room_id_safe(x,y)
			local room = self.data.rooms[room_id]
			local sep = v_hall_empty
			if room and room.connect.south then
				sep = v_hall_conn
			end
			str = string.format(v_hall_fmt, str, sep)
		end
		str = str .. "\n"
	end
	return str
end

function WorldMap:GetDebugString(draw_map)
	local str = "\n"
	if self:IsDebugMap() then
		str = "DEBUG MAP\n"
	end
	if draw_map then
		str = str .. self:BuildAsciiMap()
	end
	str = ("%s\tmax path depth: %s"):format(str, self.data.max_depth)
	str = ("%s\n\tcurrent room id: %s"):format(str, self.data.current)
	for enemy,_ in iterator.sorted_pairs(mapgen.roomtypes.Enemy.id) do
		str = (("%s\n\t%s: %s"):format(str, enemy, self:HasEnemyForCurrentRoom(enemy)))
	end
	str = ("%s\n\treward: %s"):format(str, self:GetRewardForCurrentRoom())
	str = ("%s\n\thas resources: %s"):format(str, self:DoesCurrentRoomHaveResources())
	str = ("%s\n\tdifficulty: %s"):format(str, mapgen.Difficulty:FromId(self:GetDifficultyForCurrentRoom(), "<none>"))
	str = ("%s\n\tfinal boss: %s"):format(str, self.nav:GetDungeonBoss())

	--~ local inspect = require "inspect"
	--~ str = str .. "\ncurrent room: " .. inspect(self.data.rooms[self.nav:get_room_id_safe(1,3)], { depth = 5, })
	return str
end

-- Probably better functions above to get what you want. This is useful for debug.
function WorldMap:Debug_GetCurrentRoom()
	local room = self.data.rooms[self.data.current]
	return room
end

-- Returns true if debug step was successful
function WorldMap:Debug_StepDungeon(steps, randomize)
	if not TheNet:IsHost() then
		TheLog.ch.WorldMap:printf("Warning: Cannot advance dungeon unless host")
		return false
	elseif randomize and not TheNet:IsGameTypeLocal() then
		TheLog.ch.WorldMap:printf("Warning: Cannot advance dungeon with randomization for network games")
		return false
	end

	local is_modified = false
	steps = steps or self.data.size.x
	local exits = lume.clone(exit_ordered)
	for i=1,steps do
		if randomize then
			-- Don't use rng, this simulates a user choice not worldgen.
			exits = krandom.Shuffle(exits)
		end
		local current = self:Debug_GetCurrentRoom()
		if current.index == self.data.final_id then
			return is_modified
		end
		for _,cardinal in ipairs(exits) do
			local exit_rid = current.connect[cardinal]
			if exit_rid then
				TheLog.ch.WorldMap:printf("Debug Step traveling %s from room id %d type %s", cardinal, exit_rid, self.data.rooms[exit_rid].roomtype)
				self:_StepDungeon(cardinal)
				is_modified = true
				break
			end
		end
	end
	
	return is_modified
end

function WorldMap:Debug_DumpDungeonMonsterInfo()
	local SpawnBalancer = require("spawnbalancer")
	local sb = SpawnBalancer()
	sb.biome_location = biomes.locations[self:GetBiomeLocation().id]

	local enemies = {}

	local steps = self.data.size.x
	local exits = lume.clone(exit_ordered)
	for i=1,steps do
		exits = krandom.Shuffle(exits)
		local current = self:Debug_GetCurrentRoom()

		if self:IsCurrentRoomType("monster") or self:IsCurrentRoomType("miniboss") then
			local encounter_data = TheWorld.components.spawncoordinator:Debug_GetEncounterListForCurrentRoom(self)
			local debug_info
			if type(encounter_data) ~= "function" then
				local difficulty = self:GetDifficultyForCurrentRoom()
				local difficulty_name = mapgen.Difficulty:FromId(difficulty)
				local _, encounter = TheWorld.components.spawncoordinator.rng:PickKeyValue(encounter_data[difficulty_name])
				debug_info = sb:EvaluateEncounter(nil, encounter, 1)
			else
				debug_info = sb:EvaluateEncounter(nil, encounter_data, 1)
			end

			for enemy, count in pairs(debug_info.enemy_counts) do
				if not enemies[enemy] then
					enemies[enemy] = 0
				end
				enemies[enemy] = enemies[enemy] + count
			end
		end

		if current.index == self.data.final_id then
			return
		end
		for _,cardinal in ipairs(exits) do
			local exit_rid = current.connect[cardinal]
			if exit_rid then
				self.data.current = exit_rid
				self:_MarkRoomIdVisited(exit_rid)
				break
			end
		end
	end

	d_view(enemies)
end

local debug_rid
function WorldMap:DebugDrawEntity(ui, panel, colors)
	if ui:CollapsingHeader("Room Explorer", ui.TreeNodeFlags.DefaultOpen) then
		ui:Indent()
		if ui:Button("Jump to Current") then
			debug_rid = nil
		end
		debug_rid = debug_rid or self.data.current
		local room = self.data.rooms[debug_rid]
		debug_rid = math.tointeger(ui:_SliderInt("Inspect Room Id", debug_rid, 1, #self.data.rooms))
		for cardinal,rid in iterator.sorted_pairs(room.connect) do
			if ui:Button(("Connection: %s (%i)"):format(cardinal, rid)) then
				debug_rid = rid
			end
		end
		for rid,cardinal in iterator.sorted_pairs(room.backlinks) do
			if ui:Button(("Backlink: %s (%i)"):format(cardinal, rid)) then
				debug_rid = rid
			end
		end
		ui:Spacing()
		panel:AppendTable(ui, room, "Inspect Room ".. debug_rid)
		panel:AppendTableInline(ui, room, "Room Contents")
		if ui:Button("LogProcGenInputsForRoom") then
			self:Debug_LogProcGenInputsForRoom(room)
		end
		ui:Unindent()
	end

	if ui:Button("DumpDungeonMonsterInfo") then
		self:Debug_DumpDungeonMonsterInfo()
	end

	panel:GetNode():AddFilteredAll(ui, panel, self)
end

local function mock_CreateMap()
	local mock = require("util.mock")
	mock.set_globals()

	local map = WorldMap(mock.entity())
	--SHOULD BE ASYNC DON'T COPY THIS CODE
	TheSaveSystem.dungeon:ClearAllRooms()
	return map
end

local function test_TownMap()
	local map = mock_CreateMap()
	map:GenerateTownMap()
	local room = map.nav:get_entrance_room()
	assert(room)
	assert(not map.nav:room_has_connection(room))
	assert(not map.nav:get_room_id_safe(2,1))
	assert(not map.nav:get_room_id_safe(1,2))
	map:Debug_StepDungeon()
end

local function test_DungeonMap()
	local map = mock_CreateMap()
	map:GenerateDungeonMap(biomes.regions.forest.locations.treemon_forest)
	local room = map.nav:get_entrance_room()
	assert(room)
	assert(map.nav:room_has_connection(room))
	map:Debug_StepDungeon()
end

local function test_backtrack()
	local map = mock_CreateMap()
	map:GenerateDungeonMap(biomes.regions.forest.locations.treemon_forest, 100)

	local src_rid = 8
	local dest_rid = 15
	connect_cardinal('east', map.data.rooms, src_rid, dest_rid)
	assert(not map.nav:is_backtracking(src_rid, dest_rid))
	assert(map.nav:is_backtracking(dest_rid, src_rid))
	kassert.equal(map.nav:get_first_forward_roomid(map.data.rooms[src_rid]), dest_rid)
	kassert.equal(map.nav:get_first_backtrack_roomid(map.data.rooms[dest_rid]), src_rid)
end

local function test_WorldMap()
	TheSaveSystem = require("savedata.savesystem")()
	-- Ensure variablility in tests.
	local seed = os.time(os.date("!*t"))
	--~ seed = 1654325890
	TheLog.ch.WorldMap:printf('Start seed %d', seed)

	local biome_location = biomes.regions.forest.locations.treemon_forest
	local map = mock_CreateMap(biome_location, seed)

	local stress_count = 10
	--~ stress_count = 1
	for i=1,stress_count do
		-- Force specific seeds to make results reproducible.
		seed = seed + 1
		map:GenerateDungeonMap(biome_location, seed)

		map:Debug_StepDungeon()
		TheLog.ch.WorldMap:print(map:GetDebugString(true))
	end
end

return WorldMap
