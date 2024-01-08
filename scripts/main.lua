--Override the package.path in luaconf.h because it is impossible to find
package.path = "scripts\\?.lua"

--Override package.loaded metatable so we don't double load packages
--when using different syntax for the path.
setmetatable(package.loaded,
{
	__index = function(t, k)
		k = string.gsub(k, "[\\/]+", ".")
		return rawget(t, k)
	end,
	__newindex = function(t, k, v)
		k = string.gsub(k, "[\\/]+", ".")
		rawset(t, k, v)
	end,
})

-- Improve seeding on platforms where similar seeds produce similar sequences
-- (OSX) by throwing away the high part of time and then reversing the digits
-- so the least significant part makes the biggest change. See
-- http://lua-users.org/wiki/MathLibraryTutorial
math.randomseed(tonumber(tostring(os.time()):reverse():sub(1,6)))
math.random()

Platform = require "util.platform"

--defines
MAIN = 1
IS_QA_BUILD = TheSim:GetCurrentBetaName() == "huwiz"
DEV_MODE = RELEASE_CHANNEL == "dev" or IS_QA_BUILD -- For now, QA gets debug tools everywhere.
ENCODE_SAVES = RELEASE_CHANNEL ~= "dev"
CHEATS_ENABLED = DEV_MODE or (Platform.IsConsole() and CONFIGURATION ~= "PRODUCTION")
PLAYTEST_MODE = RELEASE_CHANNEL == "demo"
SOUNDDEBUG_ENABLED = false
SOUNDDEBUGUI_ENABLED = false
HITSTUN_VISUALIZER_ENABLED = false
--DEBUG_MENU_ENABLED = true
DEBUG_MENU_ENABLED = DEV_MODE or (Platform.IsConsole() and CONFIGURATION ~= "PRODUCTION")
METRICS_ENABLED = true
TESTING_NETWORK = 1
AUTOSPAWN_MASTER_SECONDARY = false
DEBUGRENDER_ENABLED = true
SHOWLOG_ENABLED = true
POT_GENERATION = false

-- Networking related configuration
DEFAULT_JOIN_IP				= "127.0.0.1"
DISABLE_MOD_WARNING			= false
DEFAULT_SERVER_SAVE_FILE    = "/server_save"

RELOADING = false
SHOW_OBSOLETE = false

--debug.setmetatable(nil, {__index = function() return nil end})  -- Makes  foo.bar.blat.um  return nil if table item not present   See Dave F or Brook for details

ExecutingLongUpdate = false

local DEBUGGER_ENABLED = TheSim:ShouldInitDebugger() and Platform.IsNotConsole() and CONFIGURATION ~= "PRODUCTION"
if DEBUGGER_ENABLED then
	Debuggee = require 'debuggee'
end


TheAudio:SetReverbPreset("default")

RequiredFilesForReload = {}

--install our crazy loader!
local loadfn = function(modulename)
	--print (modulename, package.path)
    local errmsg = ""
    local modulepath = string.gsub(modulename, "%.", "/")
    for path in string.gmatch(package.path, "([^;]+)") do
        local filename = string.gsub(path, "%?", modulepath)
        filename = string.gsub(filename, "\\", "/")
        local result = kleiloadlua(filename)
        if result then
			local filetime = TheSim:GetFileModificationTime(filename)
			RequiredFilesForReload[filename] = filetime
            return result
        end
        errmsg = errmsg.."\n\tno file '"..filename.."' (checked with custom loader)"
    end
  return errmsg
end
table.insert(package.searchers, 2, loadfn)

-- Use our loader for loadfile too.
if TheSim then
    function loadfile(filename)
        filename = string.gsub(filename, ".lua", "")
        filename = string.gsub(filename, "scripts/", "")
        return loadfn(filename)
    end
	-- else, how can TheSim be nil??
end

--if not TheNet:GetIsClient() then
--	require("mobdebug").start()
--end

local strict = require "util.strict"
strict.forbid_undeclared(_G)

require("debugprint")
-- add our print loggers
AddPrintLogger(function(...) TheSim:LuaPrint(...) end)
TheLog = require("util.logchan")()


require("class")
require("util.pool")
require("util.multicallback")
require("util.helpers")

TheConfig = require("config").CreateDefaultConfig()

require("vector3")
require("vector2")
require("mainfunctions")

require("mods")
require("json")
TUNING = require("tuning")()
require "entityscript"
local kstring = require "util.kstring"

--monkey-patch in utf8-aware version of the string library.
local utf8_ex = require "lua-utf8"
for k,v in pairs(string) do
    if utf8_ex[k] then
        string[k] = utf8_ex[k]
    end
end

function utf8.sub(s,i,j)
    return utf8_ex.sub(s,i,j)
end

local Settings = require("settings.settings")
TheGameSettings = Settings("gamesettings")
local function LoadGameSettings()
	local RegisterGameSettings = require "settings.gamesettings"
	RegisterGameSettings(TheGameSettings)
	TheGameSettings:Load(function(success) print("Load gamesettings, result = "..tostring(success)) end)

	if Platform.IsBigPictureMode() then
		TheGameSettings:Set("graphics.fullscreen", true)
	end

	LOC.DetectLanguage()

	TheGameSettings:Save()
end

Profile = require("playerprofile")() --profile needs to be loaded before language
Profile:Load( nil, true ) --true to indicate minimal load required for language.lua to read the profile.

LOC = require "languages.loc"
require "languages.language"
require "strings.strings"
local GameContent = require "gamecontent"
global "TheGameContent"
TheGameContent = GameContent():Load()

-- Apply a baseline set of translations so that lua in the boot flow can access
-- the correct strings, after the mods are loaded, main.lua will run this again.
--
-- Ideally we wouldn't need to do this, but stuff like maps/levels/forest loads
-- in the boot flow and it caches strings before they've been translated.
--
-- Doing an early translate here is less risky than changing all the cases of
-- early string access. Downside is that it doesn't address the issue for mod
-- transations.
-- TODO(l10n): We defer TheGameContent:SetLanguage() until ModSafeStartup so we
-- have settings loaded. Does that still work?
--~ TranslateStringTable( STRINGS )

require "constants"

-- For dev, configure your channels from customcommands.lua.
if CONFIGURATION == "PRODUCTION" then
	-- TODO: Should we disable anything in prod? Maybe default is fine.
	--~ TheLog:disable_all()
	--~ TheLog:enable_channel("WorldMap")
	--~ TheLog:disable_channel("FrontEnd")
end



require "debugtools"
require "simutil"
require "util.colorutil"
require "util"
require "util.kstring" -- defines some methods in string
require "scheduler"
Attack = require "attack"
require "stategraph"
require "behaviortree"
require "prefabs"
require "bosscoroutine"
require("profiler")
require "brain"
require "components.hitbox"
require "components.soundemitter"
require "hitstopmanager"
require "input.inputconstants"
require "input.input"
require("stats")
require("commonassets")

--Now let's setup debugging!!!
global "Debuggee"
if Debuggee then
    local startResult, breakerType = Debuggee.start()
    print('Debuggee start ->', startResult, breakerType )
end

serpent = require "util/serpent"
require("frontend")
require("networking")

require("gen.prefablist")
require("netcomponents")	-- Creates dictionaries of hash values to prefabs and components
FindNetComponents()

require("networkstrings")	-- Collects and adds all static strings that need to be sent over the network to a string table and submits it to C++

require("update")
require("fonts")
require("physics")
require("modindex")
require("mathutil")
require("reload")
require("worldtiledefs")
--require("skinsutils")

if TheConfig:IsEnabled("force_netbookmode") then
	TheSim:SetNetbookMode(true)
end


print ("running main.lua\n")
print("Lua version: "..LUA_VERSION)

TheSystemService:SetStalling(true)

--instantiate the mixer
local Mixer = require("mixer")
TheMixer = Mixer.Mixer()
require("mixes")
TheMixer:PushMix("start")


Prefabs = {}
Ents = {}

local tracker = require "util.tracker"
TheTrackers = tracker.CreateTrackerSet()

TheGlobalInstance = nil
TheDebugSource = CreateEntity("TheDebugSource")
	:MakeSurviveRoomTravel()
TheDebugSource.entity:AddTransform()

global("TheCamera")
TheCamera = nil
global("PostProcessor")
PostProcessor = nil

global("MapLayerManager")
MapLayerManager = nil
global("TheDungeon")
global("TheFrontEnd")
TheFrontEnd = nil
global("TheWorld")
TheWorld = nil
global("TheFocalPoint")
TheFocalPoint = nil
global("ThePlayer")
ThePlayer = nil
global("AllPlayers")
AllPlayers = {}
global("TheDebugAudio")
TheDebugAudio = nil
global("TheMetrics")
TheMetrics = require("util.metrics")()
global("SERVER_TERMINATION_TIMER")
SERVER_TERMINATION_TIMER = -1
global("TheSceneGen")
TheSceneGen = nil

inGamePlay = false

function GetDebugPlayer()
	local playerID = TheNet:GetLocalDebugPlayer()
	if playerID then
		return GetPlayerEntityFromPlayerID(playerID)
	end
	return nil
end

local function ModSafeStartup()

	-- If we failed to boot last time, disable all mods
	-- Otherwise, set a flag file to test for boot success.

	--Ensure we have a fresh filesystem
	--TheSim:ClearFileSystemAliases()

	---PREFABS AND ENTITY INSTANTIATION

	--#V2C no mods for now... deal with this later T_T
	--ModManager:LoadMods()

	-- Apply translations
	TheGameContent:SetLanguage()

	-- Register every standard prefab with the engine

    -- This one needs to be active from the get-go.
    -- event_deps is also needed for event specific globals.
    local async_batch_validation = RUN_GLOBAL_INIT
    LoadPrefabFile("prefabs/global", async_batch_validation)

    local FollowCamera = require("cameras/followcamera")
    TheCamera = FollowCamera()

	--- GLOBAL ENTITY ---
    --[[Non-networked entity]]
    TheGlobalInstance = CreateEntity("TheGlobalInstance")
		:MakeSurviveRoomTravel()
    TheGlobalInstance.entity:AddTransform()
    TheGlobalInstance.persists = false
    TheGlobalInstance:AddTag("CLASSIFIED")

	if RUN_GLOBAL_INIT then
		GlobalInit()
	end

	PostProcessor = TheGlobalInstance.entity:AddPostProcessor()
	local IDENTITY_COLORCUBE = "images/color_cubes/identity_cc.tex"
	PostProcessor:SetColorCubeData( 0, IDENTITY_COLORCUBE, IDENTITY_COLORCUBE )
	PostProcessor:SetColorCubeData( 1, IDENTITY_COLORCUBE, IDENTITY_COLORCUBE )
	PostProcessor:SetColorCubeData( 2, IDENTITY_COLORCUBE, IDENTITY_COLORCUBE )

	MapLayerManager = TheGlobalInstance.entity:AddMapLayerManager()

    -- I think we've got everything we need by now...
   	if Platform.IsNotConsole() then
		if TheSim:GetNumLaunches() == 1 then
			TheMetrics:Send_StartGame()
		end
	end

end

-- json_instance_params is a global set from cSimulation
SetInstanceParameters(json_instance_params)

require "stacktrace"
require "debughelpers"

require "consolecommands"

require "debugsettings"

--debug key init
if CHEATS_ENABLED then
    require "debugcommands"
    require "debugkeys"
end

local function screen_resize(w,h)
	TheFrontEnd:OnScreenResize(w,h)
	TheInput:OnScreenResize(w, h)
end

function Render()
	TheFrontEnd:OnRender()
end

local function key_down_callback(keyid, modifiers)
	TheInput:OnKeyDown(keyid, modifiers);
end

local function key_repeat_callback(keyid, modifiers)
	TheInput:OnKeyRepeat(keyid);
end

local function key_up_callback(keyid, modifiers)
	TheInput:OnKeyUp(keyid, modifiers);
end

local function text_input_callback(text)
	TheInput:OnTextInput(text)
end

--local function text_edit_callback(text)
--    TheGame:GetInput():OnTextEdit(text);
--end

-- Mouse:
local function mouse_move_callback(x, y)
	if not Platform.IsBigPictureMode() then
		TheInput:OnMouseMove(x,y)
	end
end

local function mouse_wheel_callback(wheeldelta)
	TheInput:OnMouseWheel(wheeldelta)
end

local function mouse_button_down_callback(x, y, button)
	if not Platform.IsBigPictureMode() then
		TheInput:OnMouseButtonDown(x,y,button)
	end
end

local function mouse_button_up_callback(x, y, button)
	if not Platform.IsBigPictureMode() then
		TheInput:OnMouseButtonUp(x,y,button)
	end
end

local function touch_began_callback(x, y)
	TheInput:OnMouseButtonDown(x,y,0)
end

local function touch_move_callback(x, y)
	TheInput:OnMouseMove(x,y)
end

local function touch_ended_callback(x, y)
	TheInput:OnMouseButtonUp(x,y,0)
end

-- Gamepad:
local function gamepad_connected_callback(gamepad_id, gamepad_name)
	TheInput:OnGamepadConnected(gamepad_id, gamepad_name);
end

local function gamepad_disconnected_callback(gamepad_id)
	TheInput:OnGamepadDisconnected(gamepad_id);
end

local function gamepad_button_down_callback(gamepad_id, button)
	TheInput:OnGamePadButtonDown(gamepad_id, button);
end

local function gamepad_button_repeat_callback(gamepad_id, button)
	TheInput:OnGamePadButtonRepeat(gamepad_id, button);
end

local function gamepad_button_up_callback(gamepad_id, button)
	TheInput:OnGamePadButtonUp(gamepad_id, button);
end

local function gamepad_analog_input_callback(gamepad_id, ls_x, ls_y, rs_x, rs_y, lt, rt)
	TheInput:OnGamepadAnalogInput(gamepad_id, ls_x, ls_y, rs_x, rs_y, lt, rt);
end

local function filedrop(txt)
	if not DEV_MODE then
		print("You must be in dev mode to drop files onto the game. Received:", txt)
		return
	end

	if kstring.endswith(txt, "savedata.zip")
		or (txt:find("\\savedata",1,true) and kstring.endswith(txt, ".zip")) -- "savedata (1).zip"
	then
		print("dropped a save zip")
		TheSim:MountSave(txt)
		d_loadsaveddungeon()
	elseif txt:find("\\replay",1,true) then
		print("dropped a replay")
		--local f = io.open( txt, "r" )
		--local savestr = f:read( "*all" )
		local savestr = TheSim:DevLoadDataFile(txt)
		if savestr then
			local savepath = "SAVEGAME:replay_dev"
			if TheSim:DevSaveDataFile(savepath, savestr) then
				local metadata
				local loadsuccess
				TheSim:GetPersistentString("replay_dev", function(success, data)
					if success and string.len(data) > 0 then
						success, data = RunInSandbox(data)
						if success and data ~= nil then
							loadsuccess = true
							metadata = data.metadata
							TheLog.ch.SaveLoad:print("Successfully loaded: /"..savepath)
							return
						end
					end
					TheLog.ch.SaveLoad:print("Failed to load: /"..savepath)
				end)

				if loadsuccess then
					local RoomLoader = require "roomloader"
					InstanceParams.dbg = InstanceParams.dbg or {}
					-- InstanceParams.dbg.open_nodes = {'DebugHistory'} -- This doesn't work unfortunately, the history debugger has some assumptions
					InstanceParams.dbg.load_replay = true
					if metadata then
						if metadata.world_is_town then
							RoomLoader.LoadTownLevel(metadata.world_prefab or TOWN_LEVEL)
						else
							RoomLoader.LoadDungeonLevel(metadata.world_prefab, metadata.scenegen_prefab, metadata.room_id)
						end
					else
						RoomLoader.LoadTownLevel(TOWN_LEVEL)
					end
				end
			else
				print("Failed to save replay to "..savepath)
			end
		else
			print("Failed to load "..txt)
		end
	else
		print ("DROP FILE ", txt)
	end
end

TheFeedbackScreen = nil

function SubmitFeedbackResult(response_code, response)
	print("Feedback result:",response_code)
	print("response:",response)
	if TheFeedbackScreen then
		TheFeedbackScreen:SubmitFeedbackResult(response_code, response)
	end
end

TheScreenshotter = require("util.screenshotter")()

TheSim:SetScreenSizeChangeFn(screen_resize)

--  Keyboard
TheSim:SetKeyDownFn(key_down_callback);
TheSim:SetKeyRepeatFn(key_repeat_callback);
TheSim:SetKeyUpFn(key_up_callback);
TheSim:SetTextInputFn(text_input_callback);
--TheSim:SetTextEditFn(text_edit_callback);


-- Mouse:
TheSim:SetMouseMoveFn(mouse_move_callback);
TheSim:SetMouseWheelFn(mouse_wheel_callback);
TheSim:SetMouseButtonDownFn(mouse_button_down_callback);
TheSim:SetMouseButtonUpFn(mouse_button_up_callback);

-- Touch:
TheSim:SetTouchBeganFn(touch_began_callback);
TheSim:SetTouchMoveFn(touch_move_callback);
TheSim:SetTouchEndedFn(touch_ended_callback);

-- Gamepad:
TheSim:SetGamepadConnectedFn(gamepad_connected_callback);
TheSim:SetGamepadDisconnectedFn(gamepad_disconnected_callback);
TheSim:SetGamepadButtonDownFn(gamepad_button_down_callback);
TheSim:SetGamepadButtonRepeatFn(gamepad_button_repeat_callback);
TheSim:SetGamepadButtonUpFn(gamepad_button_up_callback);
TheSim:SetGamepadAnalogInputFn(gamepad_analog_input_callback);

TheSim:SetDropFileFn(filedrop);


TheSaveSystem = require("savedata.savesystem")()
LoadGameSettings()

require "prefabs.stategraph_autogen" -- to get around a circular dependency

if not MODS_ENABLED then
	TheSaveSystem:LoadAll(function(success)
		ModSafeStartup()
	end)
else
	--#V2C no mods for now... deal with this later T_T
	assert(false)
	KnownModIndex:Load(function()
		KnownModIndex:BeginStartupSequence(function()
			TheSaveSystem:LoadAll(function(success)
				ModSafeStartup()
			end)
		end)
	end)
end

TheSystemService:SetStalling(false)
