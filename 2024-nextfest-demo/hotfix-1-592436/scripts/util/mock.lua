-- This file is very incomplete. Add as necessary.
--
-- Can import lua here, but only stuff that runs on vanilla lua5.3 (not our
-- embedded lua) so it can be run separately from the game for quick testing.

require "class"
local krandom = require "util.krandom"


local mock = {}

function mock.noop() end
function mock.return_true()
	return true
end

function mock.entity(mock_fns)
	mock_fns = mock_fns or {}

	local ent = {}
	local fns = {
		'HasTag',
		'ListenForEvent',
		'PushEvent',
	}
	for _,fn in ipairs(fns) do
		ent[fn] = mock.noop
	end
	for _,fn in ipairs(mock_fns) do
		ent[fn] = mock.noop
	end
	ent.IsValid = mock.return_true
	return ent
end

function mock.dungeon()
	local fns = {
		"GetAllUnlocked",
		"GetCurrentBoss",
		"GetCurrentRoomType",
		"GetDungeonMap",
		"GetDungeonProgress",
		"GetMetaProgress",
		"IsCurrentRoomType",
		"IsFlagUnlocked",
		"IsInTown",
		"IsLocationUnlocked",
		"IsRegionUnlocked",
		"LockFlag",
		"SetHudVisibility",
		"UnlockFlag",
		"UnlockLocation",
		"UnlockRegion",
	}
	local ent = mock.entity(fns)
	return ent
end

function mock.player(id)
	id = id or 1
	local player = {
		GetHunterId = function()
			return id
		end,
	}
	if AllPlayers then
		table.insert(AllPlayers, player)
	end
	return player
end

function mock.set_globals()
	-- Note: nativeshims is automatically imported by testy.
	require "class"
	require "constants"
	require "strings.strings"

	-- I don't want to mock The Player since it's very complex and requires too
	-- much mock work for little benefit. Adding AllPlayers so we skip any code
	-- checking all players.
	AllPlayers = {}
	Random = krandom._SystemRng
	RELEASE_CHANNEL = "mock"
	TheSim = TheSim or {}
	TheSim.EmptyPersistentDirectory = mock.noop
	InGamePlay = mock.return_true
	InstanceParams = {
		settings = {
			reset_action = RESET_ACTION.DEV_LOAD_ROOM,
		},
	}
	TheInput = { -- too spaghetti to actually import
		SetEditMode = mock.noop,
	}
	TheNet = {
		IsHost = mock.return_true,
		HostSetRoomTravelHistory = mock.noop,
	}

	TheLog = require("util.logchan")()
	TUNING = require("tuning")()

	TheSaveSystem = require("savedata.savesystem")()
end

local function test_set_globals()
	mock.set_globals()
	dbassert(true)
end

return mock
