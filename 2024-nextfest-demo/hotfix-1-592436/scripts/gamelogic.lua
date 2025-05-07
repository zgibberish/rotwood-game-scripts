local CancelTip = require "widgets.canceltipwidget"
local Enum = require "util.enum"
local Lume = require "util.lume"
local MainScreen = require "screens.mainscreen"
local ProfanityFilter = require "util.profanityfilter"
local SceneGen = require "components.scenegen"
local WaitingForPlayersScreen = require "screens.waitingforplayersscreen"
local kassert = require "util.kassert"
require "builtinusercommands"
require "constants"
require "emotes"
require "knownerrors"
require "perfutil"
require "usercommands"


if Platform.IsRail() then
	TheSim:SetMemInfoTrackingInterval(5*60)
end

function SetGlobalErrorWidget(...)
    if TheFrontEnd.error_widget == nil then -- only first error!
		TheFrontEnd:SetGlobalErrorWidget(...)
    end
end

local cancel_tip = CancelTip()
	:SetAnchors("center","top")

TheLog.ch.SaveLoad:print("[Loading frontend assets]")

local start_game_time = nil

function ForceAuthenticationDialog()
	if not InGamePlay() then
		local active_screen = TheFrontEnd:GetActiveScreen()
		if active_screen ~= nil and active_screen._widgetname == "MainScreen" then
			active_screen:OnLoginButton(false)
		elseif MainScreen then
			local main_screen = MainScreen(Profile)
			TheFrontEnd:ShowScreen( main_screen )
			main_screen:OnLoginButton(false)
		end
	end
end

local function KeepAlive()
	local global_loading_widget = TheFrontEnd.loading_widget
	if global_loading_widget then
		global_loading_widget:ShowNextFrame()
		if cancel_tip then
			cancel_tip:ShowNextFrame()
		end
		-- TODO(roomtravel): Can't RenderOneFrame during room travel because it
		-- triggers native sim update assert.
		if not InGamePlay() then
			TheSim:RenderOneFrame()
		end
		global_loading_widget:ShowNextFrame()
		if cancel_tip then
			cancel_tip:ShowNextFrame()
		end
	end
end

function ShowLoading()
	local global_loading_widget = TheFrontEnd.loading_widget
	if global_loading_widget then
		global_loading_widget:SetEnabled(true)
	end
end

function HideLoading(force)
	local global_loading_widget = TheFrontEnd.loading_widget
	if global_loading_widget then
		global_loading_widget:SetEnabled(false)
		if force then
			global_loading_widget:Hide()
		end
	end
end

function ShowCancelTip()
	if cancel_tip then
		cancel_tip:SetEnabled(true)
	end
end

function HideCancelTip()
	if cancel_tip then
		cancel_tip:SetEnabled(false)
	end
end

local function RegisterAllPrefabs(init_dlc, async_batch_validation)
	RegisterAllDLC()
	for i = 1, #PREFABFILES do -- required from prefablist.lua
		LoadPrefabFile("prefabs/" .. PREFABFILES[i], async_batch_validation or false)
	end
	if init_dlc then
		InitAllDLC()
	end
	ModManager:RegisterPrefabs()
end

local function LoadAssets(asset_set, savedata)
	ShowLoading()

	local settings = InstanceParams.settings

	assert(asset_set)

	local back_end_prefabs = shallowcopy(BACKEND_PREFABS)
	if savedata and savedata.map then
		if savedata.map.prefab then
			table.insert(back_end_prefabs, savedata.map.prefab)
		end
		if savedata.map.scenegenprefab then
			table.insert(back_end_prefabs, savedata.map.scenegenprefab)
		end
	end

	KeepAlive()

	if asset_set == "FRONTEND" then
		if settings.last_asset_set == asset_set then
			print("\tFE assets already loaded")
			for i = 1, #PREFABFILES do -- required from prefablist.lua
				LoadPrefabFile("prefabs/"..PREFABFILES[i])
			end
			ModManager:RegisterPrefabs()
		else
			if settings.last_asset_set == "BACKEND" then
				print("\tUnload BE")
				TheSim:UnloadPrefabs(PLAYER_PREFABS)
				if settings.last_back_end_prefabs ~= nil then
					TheSim:UnloadPrefabs(settings.last_back_end_prefabs)
				end
				KeepAlive()
				print("\tUnload BE done")
			end

			TheSystemService:SetStalling(true)
			TheSim:UnregisterAllPrefabs()
			local async_batch_validation = settings.last_asset_set == nil
			RegisterAllPrefabs(false, async_batch_validation)
			TheSystemService:SetStalling(false)
			KeepAlive()

			print("\tLoad FE")
			TheSystemService:SetStalling(true)
			TheSim:LoadPrefabs(FRONTEND_PREFABS)
			TheSystemService:SetStalling(false)
			if async_batch_validation then
				TheSim:StartFileExistsAsync()
			end
			print("\tLoad FE done")
		end
	else
		kassert.equal(asset_set, "BACKEND")
		if settings.last_asset_set == asset_set then
			print("\tBack end state has changed. Unloading unused prefabs, loading required prefabs.")

			local unloadables = Lume(settings.last_back_end_prefabs)
				:filter(function(prefab)
					return not Lume(back_end_prefabs):find(prefab):result()
				end)
				:result()
			local loadables = Lume(back_end_prefabs)
				:filter(function(prefab)
					return not Lume(settings.last_back_end_prefabs):find(prefab):result()
				end)
				:result()

			if next(unloadables) then
				print("\tUnload BE")
				TheSim:UnloadPrefabs(unloadables)
				KeepAlive()
				print("\tUnload BE done")
			end

			TheSystemService:SetStalling(true)
			RegisterAllPrefabs()
			TheSystemService:SetStalling(false)
			KeepAlive()

			if next(loadables) then
				print("\tLOAD BE")
				TheSystemService:SetStalling(true)
				TheSim:LoadPrefabs(loadables)
				TheSystemService:SetStalling(false)
				KeepAlive()
				print("\tLOAD BE done")
			end
		else
			if settings.last_asset_set == "FRONTEND" then
				print("\tUnload FE")
				TheSim:UnloadPrefabs(FRONTEND_PREFABS)
				KeepAlive()
				print("\tUnload FE done")
			end

			TheSystemService:SetStalling(true)
			TheSim:UnregisterAllPrefabs()
			RegisterAllPrefabs(true)
			TheSystemService:SetStalling(false)
			KeepAlive()

			print("\tLOAD PLAYER_PREFABS")
			TheSystemService:SetStalling(true)
			TheSim:LoadPrefabs(PLAYER_PREFABS)
			TheSystemService:SetStalling(false)
			KeepAlive()
			print("\tLOAD PLAYER_PREFABS done")

			print("\tLOAD BE")
			if back_end_prefabs ~= nil then
				TheSystemService:SetStalling(true)
				TheSim:LoadPrefabs(back_end_prefabs)
				TheSystemService:SetStalling(false)
				KeepAlive()
			end
			print("\tLOAD BE done")
		end
	end

	settings.last_asset_set = asset_set
	settings.last_back_end_prefabs = back_end_prefabs
end

function GetTimePlaying()
	return start_game_time ~= nil and GetTime() - start_game_time or 0
end

--Only valid during PopulateWorld
populating_world_ents = nil

local function PopulateWorld(savedata, profile)
	assert(savedata ~= nil)
	TheSystemService:SetStalling(true)

	dbassert(populating_world_ents == nil)
	populating_world_ents = {}

	TheSceneGen = savedata.map.scenegenprefab and SpawnPrefab(savedata.map.scenegenprefab)

	local world = SpawnPrefab(savedata.map.prefab)
	dbassert(world ~= nil)
	assert(TheWorld == world)

	world:SetPersistData(savedata.map.data)

	local dungeon_progress = world:GetDungeonProgress()
	local suppress_environment = false

	--If propmanager exist, load static layout one time
	--See world_autogen.lua (OnPreLoad)
	if world.components.propmanager ~= nil then
		--Instantiate all the layout entities

		-- Should roll this logic into MapLayout.
		local layout = world.map_layout.layout
		if layout ~= nil then
			-- Skip the ground layer
			for i = 2, #layout.layers do
				local objects = layout.layers[i].objects
				if objects ~= nil then
					for j = 1, #objects do
						local object = objects[j]
						local record = world.map_layout:ConvertLayoutObjectToSaveRecord(object)
						SpawnSaveRecord(object.type, record)
					end
				end
			end
		end

		--Instantiate static, authored props
		world.components.propmanager:SpawnStaticProps(layout)

		if TheSceneGen
			and not Profile:GetValue("suppress_decor_props", false)
			and world:ProcGenEnabled()
		then
			local authored_prop_placements = world.components.propmanager
				and CollectPropPlacements(world.components.propmanager.filenames)
				or {}
			TheSceneGen.components.scenegen:BuildScene(world, dungeon_progress, authored_prop_placements)
			suppress_environment = true
		end
	end

	if not suppress_environment then
		if TheSceneGen then
			SceneGen.ApplyEnvironment(world, TheSceneGen.components.scenegen, dungeon_progress)
		else
			if not world.scene_gen_overrides.lighting then
				ApplyDefaultLighting()
			end
			if not world.scene_gen_overrides.sky then
				ApplyDefaultSky()
			end
			if not world.scene_gen_overrides.water then
				ApplyDefaultWater()
			end
		end
	end

	--Instantiate all saved entities
	if savedata.ents ~= nil then
		for prefab, ents in pairs(savedata.ents) do
			for i = 1, #ents do
				SpawnSaveRecord(prefab, ents[i])
			end
		end
	end

	--Post pass
	for i = 1, #populating_world_ents do
		local newent = populating_world_ents[i]
		if newent.inst ~= world and newent.inst:IsValid() then
			newent.inst:PostLoadWorld(newent.data)
		end
	end
	world:PostLoadWorld(savedata.map.data)
	TheDungeon:PostLoadWorld()

	populating_world_ents = nil

	--Done
	TheSystemService:SetStalling(false)
end

function DeactivateWorld()
	-- TODO: networking2022: this is no longer called in typical flows
	if TheWorld ~= nil and not TheWorld.isdeactivated then
		TheWorld.isdeactivated = true
		TheWorld:PushEvent("deactivateworld")
		TheMixer:PopMix("normal")
		SetPause(true)
	end
end

local function ActivateWorld()
	if TheWorld ~= nil and not TheWorld.isdeactivated then
		SetPause(false)
		TheMixer:SetLevel("master", 1)
		TheMixer:PushMix("normal")
	end
end

local function OnPlayerActivated(world, inst)
	if not world.isdeactivated then
		start_game_time = GetTime()
		TheCamera:Snap()

		-- Don't fade in if the player is playing a cutscene.
		if not (inst.components.cineactor and inst.components.cineactor:IsInCine()) then
			TheFrontEnd:Fade(FADE_IN, 0.5, ActivateWorld)
		end
	end
end

local function OnPlayerDeactivated(world, player)
	-- TODO: networking2022 - doesn't appear to get executed in current workflow
	-- if not world.isdeactivated then
	--     TheFrontEnd:ClearScreens()
	--     TheFrontEnd:SetFadeLevel(1)
	--     TheMixer:PopMix("normal")
	--     SetPause(true)
	-- end
end

local OnAllPlayersReady = function(savedata, profile)
	--OK, we have our savedata and a profile. Instantiate everything and start the game!
	TheLog.ch.Boot:printf("OnAllPlayersReady called. IsHost[%s] GetNrPlayersOnRoomChange[%s]", TheNet:IsHost(), TheNet:GetNrPlayersOnRoomChange())
	TheFrontEnd:ClearScreens()

	TheMixer:SetLevel("master", 0)
	TheFrontEnd:GetSound():KillSound("FEMusic")
	TheFrontEnd:GetSound():KillSound("FEPortalSFX")

	assert(savedata.map ~= nil, "Map missing from savedata on load")
	assert(savedata.map.prefab ~= nil, "Map prefab missing from savedata on load")

	--PopulateWorld(savedata, profile) --> Moved to BeginRoom

	if TheFrontEnd.error_widget == nil then
		-- This will start the encounter coroutine on the net host.
		assert(TheWorld)
		TheDungeon:StartRoom()

		SetPause(true, "InitGame")

		TheWorld:ListenForEvent("playeractivated", OnPlayerActivated)
		TheWorld:ListenForEvent("playerdeactivated", OnPlayerDeactivated)
	else
		TheFrontEnd:SetFadeLevel(1)
	end

	inGamePlay = true

	TheNet:StartingRoom()	-- Signal the networking systems that the room is starting
end

local function BeginRoom(savedata, profile, was_traveling)
	print("BeginRoom called")
	LoadAssets("BACKEND", savedata)

	if not TheDungeon then
		-- Simpler to let dungeon be a prefab which means putting it after LoadAssets.
		TheDungeon = SpawnPrefab("dungeon")
		-- Don't create hud yet because room information doesn't exist to
		-- populate it.

		TheDungeon:SetPersistData({})
	end

	if was_traveling then
		TheDungeon:GetDungeonMap():OnCompletedTravel()
	end

	-- Each room is a world.
	PopulateWorld(savedata, profile)

	print("Confirming that loading is complete...")
	TheNet:ConfirmRoomLoadReady()	-- Tell the host we're ready to go.
	HideLoading()

	-- We are done loading, but the other players in the network game might not be ready to go yet. So we have to wait until the host tells us we can continue.
	if not TheNet:IsReadyToStartRoom() then
		print("Waiting for other players...")
		TheFrontEnd:PushScreen(WaitingForPlayersScreen( OnAllPlayersReady, savedata, profile) )
	else
		print("Skipping waiting for other players, as everybody is ready")
		OnAllPlayersReady(savedata, profile)
	end
end




------------------------THESE FUNCTIONS HANDLE STARTUP FLOW

-- We call this if we don't have savedata for the world we're loading.
local function DoGenerateWorld(worldprefab, scenegenprefab, was_traveling)
	local savedata =
	{
		map =
		{
			prefab = worldprefab,
			scenegenprefab = scenegenprefab,
		},
	}

	BeginRoom(savedata, Profile, was_traveling)
end

local Neighborhoods = Enum{ "town", "dungeon" }
local function LoadRoomFromSave(savetype, worldprefab, scenegenprefab, roomid)
	dbassert(Neighborhoods:Contains(savetype))
	dbassert(worldprefab)
	dbassert(roomid)
	local was_traveling = savetype == Neighborhoods.s.dungeon
	TheSaveSystem[savetype]:LoadRoom(roomid, function(savedata)
		if savedata ~= nil then
			local prefab = savedata.map ~= nil and savedata.map.prefab or nil
			if prefab == worldprefab then
				BeginRoom(savedata, Profile, was_traveling)
				return

			else
				-- SAVE-MIGRATION: If we want to migrate a player town's, here's the place to do it.
				-- However, it doesn't make much sense for a dungeon room to mismatch.
				local msg = ("WARNING: Saved %s room [%d:%s] prefab mismatch: %s. Can't load savedata."):format(savetype, roomid, tostring(prefab), worldprefab)
				TheLog.ch.WorldGen:print(msg)
				dbassert(savetype == Neighborhoods.s.town and worldprefab == TOWN_LEVEL, msg)
			end
		end
		TheLog.ch.WorldGen:printf("Generating new %s room [%d:%s].", savetype, roomid, worldprefab)
		DoGenerateWorld(worldprefab, scenegenprefab, was_traveling)
	end)
end
local function DoLoadTownRoom(worldprefab, roomid)
	return LoadRoomFromSave(Neighborhoods.s.town, worldprefab, nil, roomid)
end
local function DoLoadDungeonRoom(worldprefab, scenegenprefab, roomid)
	return LoadRoomFromSave(Neighborhoods.s.dungeon, worldprefab, scenegenprefab, roomid)
end

----------------LOAD THE PROFILE AND THE SAVE INDEX, AND START THE FRONTEND

function LoadWorld(settings)
	if settings.reset_action == RESET_ACTION.LOAD_TOWN_ROOM then
		DoLoadTownRoom(settings.world_prefab, settings.room_id)
	elseif settings.reset_action == RESET_ACTION.LOAD_DUNGEON_ROOM then
		DoLoadDungeonRoom(settings.world_prefab, settings.scenegen_prefab, settings.room_id)
	elseif settings.reset_action == RESET_ACTION.DEV_LOAD_ROOM then
		DoGenerateWorld(settings.world_prefab, settings.scenegen_prefab, false)
	else
		error("Unknown reset action ".. tostring(settings.reset_action))
	end
end

local function DoResetAction()
	-- Start loading from a fresh lua sim.
	local ssn = TheNet:GetSimSequenceNumber()
	TheLog.ch.Networking:printf("Simulation Sequence Number: " .. ssn)
	TheNet:DoResetAction();

	local settings = InstanceParams.settings
	if settings.reset_action == nil or settings.reset_action == RESET_ACTION.LOAD_FRONTEND
	then
		LoadAssets("FRONTEND")
		if MainScreen then
			TheFrontEnd:ShowScreen(MainScreen(Profile))
		end
		TheNet:EndGame()
	elseif settings.reset_action == RESET_ACTION.JOIN_GAME and not TheNet:IsInGame() then
		print("Reconnecting to the game")
		LoadAssets("FRONTEND")	-- Need to load these assets before reconnecting, otherwise the reconnect will fail.

		if settings.reconnect_settings.joincode then
			TheNet:StartGame(settings.reconnect_settings.playerInputIDs, "invitejoincode", settings.reconnect_settings.joincode)
		elseif settings.reconnect_settings.lobbyID then
			TheNet:StartGame(settings.reconnect_settings.playerInputIDs, "invite", settings.reconnect_settings.lobbyID)
		else
			print("No reconnection data! Moving to main menu instead.")
			if MainScreen then
				TheFrontEnd:ShowScreen(MainScreen(Profile))
			end
		end
	else
		LoadWorld(settings)
	end
end

local function OnUpdatePurchaseStateComplete()
	TheLog.ch.Boot:print("OnUpdatePurchaseStateComplete")

	if TheInput:HasAnyConnectedGamepads() then
		TheFrontEnd:StopTrackingMouse()
	end

	DoResetAction()
end

local function OnFilesLoaded()
	TheLog.ch.Boot:print("OnFilesLoaded()")
	OnUpdatePurchaseStateComplete()
end

-- Needed to defer graphics loading until that system was init.
TheGameContent:LoadLanguageDisplayElements()

-- Not sure where to put these, so I'm dumping them into a new global.
TheNetUtils = {}
TheNetUtils.ProfanityFilter = ProfanityFilter()

TheNetUtils.ProfanityFilter:AddDictionary("default", require("wordfilter"))

TheLog.ch.SaveLoad:print("[Loading profile and save index]")
Profile:Load(OnFilesLoaded) -- this causes a chain of continuations in sequence that eventually result in DoResetAction being called

require "platformpostload" --Note(Peter): The location of this require is currently only dependent on being after the built in usercommands being loaded

--Online servers will call StartDedicatedServer after authentication
-- NW: networking2022: Removed dedicated server stuff
--if TheNet:IsDedicated() and not TheNet:GetIsServer() then
--	StartDedicatedServer()
--end

