local audioid = require "defs.sound.audioid"
local biomes = require "defs.biomes"


local RoomLoader = {}
local ALLOW_SIMRESET_BETWEEN_ROOMS <const> = true

-- StartRun generates a dungeon map and saves to disk.
-- For hosts, it also triggers LoadDungeonLevel to kick off the next Lua sim instance
-- For clients, wait until the host sends HostLoadRoom
local function StartRunInternal(regionID, locationID, callback, seed, altMapGenID)
	local WorldMap = require "components.worldmap"
	local worldmap = WorldMap.GetDungeonMap_Safe()
	-- TheAudio:StopAllSounds() -- Not normal flow, so clean up sounds.
	worldmap:StartRun(biomes.regions[regionID].locations[locationID], callback, seed, altMapGenID)
end

function RoomLoader.StartRunWithLocationData(locationData, seed, altMapGenID, ascension)
	assert(type(locationData) == "table")
	RoomLoader.StartRun(locationData.region_id, locationData.id, seed, altMapGenID, ascension)
end

function RoomLoader.RequestRunWithLocationData(playerID, locationData, seed, altMapGenID, ascension)
	assert(type(locationData) == "table")
	RoomLoader.RequestRun(playerID, locationData.region_id, locationData.id, seed, altMapGenID, ascension)
end


-- TODO: networking2022, victorc - move this to a more sensible location
function RoomLoader.GetAltMapGenID(regionID, locationID)
	if not InGamePlay() then
		return nil
	end

	local biome_location = biomes.regions[regionID].locations[locationID]

	if biome_location.alternate_mapgens ~= nil then
		local mapgen = require "defs.mapgen"
		-- We have some alternate mapgens. Let's see if we should use any of them, instead.
		-- Only try alternates if we're in-game. Otherwise, we started a debug
		-- run and should just default to normal mapgen (for now - can change
		-- if we want!)
		for mg_idx,mg in ipairs(biome_location.alternate_mapgens) do
			local possible_mapgen = mapgen.biomes[mg]
			local eligible = true

			-- If any of the FORBIDDEN keys are PRESENT, disqualify this biome
			if possible_mapgen.forbidden_keys ~= nil then
				for i,key in pairs(possible_mapgen.forbidden_keys) do
					if TheWorld:IsFlagUnlocked(key) then -- FLAG
						eligible = false
						break
					end
				end
			end

			-- If any of the REQUIRED keys are MISSING, disqualify this biome
			if possible_mapgen.required_keys ~= nil then
				for i,key in ipairs(possible_mapgen.required_keys) do
					if not TheWorld:IsFlagUnlocked(key) then -- FLAG
						eligible = false
						break
					end
				end
			end

			if eligible then
				-- This possible_mapgen has satisfied all critera. We should use it
				-- Currently picks the FIRST mapgen that satisfies all criteria. Could be smarter if we wanted it to be.
				-- alternate_mapgen = possible_mapgen
				-- biome = possible_mapgen
				return mg_idx
			end
		end
	end
	return nil
end

-- It is technically okay to call this without the network available
function RoomLoader.RequestRun(playerID, regionID, locationID, seed, altMapGenID, ascension)
	seed = seed or os.time(os.date("!*t"))
	altMapGenID = altMapGenID or RoomLoader.GetAltMapGenID(regionID, locationID)

	if not TheWorld then
		TheLog.ch.Networking:printf("Warning: Run data ascension level is unsynced. Ascension manager is not available outside of the game.")
		ascension = 0
	else
		if ascension and TheNet:IsHost() then
			-- Host stores new ascension level since we'll load it to apply in future rooms.
			TheDungeon.progression.components.ascensionmanager:StoreSelectedAscension(locationID, ascension)
		else
			ascension = TheDungeon.progression.components.ascensionmanager:GetSelectedAscension(locationID)
		end
	end

	TheNet:RequestRun(playerID, regionID, locationID, seed, altMapGenID, ascension)
end

-- It is technically okay to call this without the network available
function RoomLoader.StartRun(regionID, locationID, seed, altMapGenID, ascension)
	seed = seed or os.time(os.date("!*t"))
	altMapGenID = altMapGenID or RoomLoader.GetAltMapGenID(regionID, locationID)

	if not TheWorld then
		TheLog.ch.Networking:printf("Warning: Run data ascension level is unsynced. Ascension manager is not available outside of the game.")
		ascension = 0
	else
		if ascension and TheNet:IsHost() then
			-- Host stores new ascension level since we'll load it to apply in future rooms.
			TheDungeon.progression.components.ascensionmanager:StoreSelectedAscension(locationID, ascension)
		else
			ascension = TheDungeon.progression.components.ascensionmanager:GetSelectedAscension(locationID)
		end
	end

	if TheNet:IsHost() then
		local callback = function()
			TheNet:HostStartRun(regionID, locationID, seed, altMapGenID, ascension)
		end
		StartRunInternal(regionID, locationID, callback, seed, altMapGenID)
	end
end

function RoomLoader.ClientStartRun(regionID, locationID, seed, altMapGenID)
	if not TheNet:IsHost() then
		-- TODO: add something like TheNet:ClientStartRunComplete as a flow control callback
		StartRunInternal(regionID, locationID, nil, seed, altMapGenID)
	end
end

local function IsCurrentlyInTown()
	return TheDungeon and TheDungeon:IsInTown()
end

local function IsCurrentlyInDungeon()
	-- Not quite the same as not IsCurrentlyInTown() since we want false in
	-- main menu.
	return TheDungeon and not TheDungeon:IsInTown()
end

local function TransitionLevel(params)
	TheLog.ch.Boot:printf("TransitionLevel need_reset=", params.need_reset)
	if ALLOW_SIMRESET_BETWEEN_ROOMS
		or params.need_reset
		or not TheWorld
	then
		return StartNextInstance(params)
	end
	assert(TheWorld)

	HostLoadRoom(params)

	TheSim:LoadPrefabs{ params.world_prefab }

	TheWorld.is_destroying = true
	TheWorld:MakeSurviveRoomTravel() -- destroy world last
	for guid,ent in pairs(Ents) do
		if ent:IsValid() -- may have been destroyed by Removing another ent.
			and ent:IsLocal()
			and not ent:HasTag("survives_room_travel")
		then
			TheLog.ch.Boot:print("Destroying entity", tostring(ent))
			ent:Remove(true)
		end
	end
	TheWorld.is_destroying = nil

	-- If you're looking for a PushEvent for room_travel, see room_created
	-- (world_autogen) instead.

	-- TODO(roomtravel): Move the world prefab to TheWorld.room, retain the
	-- world, and destroy the TheWorld.room? Maybe it's good to destroy
	-- TheWorld so all event listeners on TheWorld get wiped. Everything we
	-- want to keep needs to be on TheDungeon.
	TheWorld:Remove(true)
	TheWorld = nil
	TheDungeon.room = nil
	-- Wait a frame to allow world native entity to get cleaned up, then load.
	TheGlobalInstance:DoTaskInTime(0, function()
		LoadWorld(params)
	end)
end

local function LoadDungeonLevelInternal(worldprefab, scenegenprefab, roomid)
	TransitionLevel({
		reset_action = RESET_ACTION.LOAD_DUNGEON_ROOM,
		world_prefab = worldprefab,
		scenegen_prefab = scenegenprefab,
		room_id = roomid,
		need_reset = not IsCurrentlyInDungeon(),
	})
end

function RoomLoader.LoadDungeonLevel(worldprefab, scenegenprefab, roomid)
	-- Load may stall/hang if game is paused.
	SetGameplayPause(false)

	if TheNet:IsHost() then
		TryStartNetwork(function()
			LoadDungeonLevelInternal(worldprefab, scenegenprefab, roomid)
		end)
	end
end

function RoomLoader.ClientLoadDungeonLevel(worldprefab, scenegenprefab, roomid)
	if not TheNet:IsHost() then
		TryStartNetwork(function()
			LoadDungeonLevelInternal(worldprefab, scenegenprefab, roomid)
		end)
	end
end

local function LoadTownLevelInternal(worldprefab, roomid)
	TransitionLevel({
		reset_action = RESET_ACTION.LOAD_TOWN_ROOM,
		world_prefab = worldprefab,
		room_id = roomid,
		need_reset = not IsCurrentlyInTown(),
	})
end

function RoomLoader.LoadTownLevel(worldprefab, roomid)
	-- Load may stall/hang if game is paused.
	SetGameplayPause(false)

	if TheNet:IsHost() then
		roomid = roomid or 1
		TryStartNetwork(function()
			LoadTownLevelInternal(worldprefab, roomid)
		end)
	end
end

function RoomLoader.ClientLoadTownLevel(worldprefab, roomid)
	roomid = roomid or 1
	-- victorc: hacky fix to stop music when transitioning since the UI is actually controlling presentation
	TheAudio:StopPersistentSound(audioid.persistent.ui_music)
	if not TheNet:IsHost() then
		TryStartNetwork(function()
			LoadTownLevelInternal(worldprefab, roomid)
		end)
	end
end

local function DevLoadLevelInternal(worldprefab, scenegenprefab)
	TransitionLevel({
		reset_action = RESET_ACTION.DEV_LOAD_ROOM,
		world_prefab = worldprefab,
		scenegen_prefab = scenegenprefab or (TheSceneGen and TheSceneGen.prefab),
		need_reset = true,
	})
end

function RoomLoader.DevLoadLevel(worldprefab, scenegenprefab)
	-- Not normal flow, so make sure sounds are cleaned up.
	TheAudio:StopAllSounds()
	if TheNet:IsHost() then
		TryStartNetwork(function()
			DevLoadLevelInternal(worldprefab, scenegenprefab)
		end)
	end
end

function RoomLoader.ClientDevLoadLevel(worldprefab)
	TheAudio:StopAllSounds()
	if not TheNet:IsHost() then
		TryStartNetwork(function()
			DevLoadLevelInternal(worldprefab)
		end)
	end
end

return RoomLoader
