--------------------------------------------------------------------------
-- Prefab file for loading the persistent dungeon/world entity
--------------------------------------------------------------------------

--------------------------------
-- Progression
--
-- An entity with components that save between rooms.
--
local function WriteProgression(inst)
	local motherseed = TheDungeon:IsInTown() and 0 or TheDungeon:GetDungeonMap():GetMotherSeed()
	TheSaveSystem.progress:SetValue("progressionmotherseed", motherseed)

	TheSaveSystem.progress:SetValue("progression", inst:GetPersistData())
end
local function LoadProgression(inst)
	-- Usually occurs before the world's created.
	inst:SetPersistData(TheSaveSystem.progress:GetValue("progression"))
end

local function OnRegisterRoomCreated_Progression(inst, room)
	assert(room)
	local savedmotherseed = TheSaveSystem.progress:GetValue("progressionmotherseed") or 0

	local worldmap = TheDungeon:GetDungeonMap()
	if not TheDungeon:IsInTown()
		and worldmap
		and worldmap:GetMotherSeed() ~= savedmotherseed
		and worldmap.data
	then
		-- Fix for the world progression messing up the run state of the
		-- runmanager when joining a game in progress.
		print("Starting new run. Motherseed = ".. savedmotherseed)
		TheDungeon:PushEvent("start_new_run", worldmap.data.location_id)
	end
end
local function Progression_DebugDrawEntity(inst, ui, panel, colors)
	panel:AppendTable(ui, TheDungeon, "TheDungeon")
	panel:AppendTable(ui, inst.world, "world")
end

-- Creation order for components on progression:
-- * ctor
-- * OnPostSpawn
-- * OnLoad
-- * OnRegisterRoomCreated (every room)
-- * OnPostLoadWorld (every room)
-- * OnStartRoom (every room)
-- Sometime after OnStartRoom, players are created. Listen for playeractivated.
local function CreateProgression(dungeon, world)
	local inst = CreateEntity("progression")
		:MakeSurviveRoomTravel()

	-- TODO(roomtravel): Eventually, this should either be
	-- TheDungeon (and all events are sent there) or setup when
	-- TheDungeon spawns the world.
	inst.world = world

	inst:AddComponent("meta")
	inst:AddComponent("castmanager")
	inst:AddComponent("meetingmanager")
	inst:AddComponent("towncalendar")
	inst:AddComponent("ascensionmanager")
	inst:AddComponent("worldunlocks")
	inst:AddComponent("metaprogressmanager")
	inst:AddComponent("runmanager")
	inst:AddComponent("powerroller")

	inst.WriteProgression = WriteProgression
	inst.LoadProgression = LoadProgression
	inst.OnRegisterRoomCreated = OnRegisterRoomCreated_Progression
	inst.DebugDrawEntity = Progression_DebugDrawEntity

	-- ProgressSave calls WriteProgression on every save, so we don't need to
	-- explicitly write before load transitions (start_new_run, exit_room,
	-- etc).

	return inst
end
-- /Progression


--------------------------------
-- Hud
--
-- The persistent player UI.
--
local function CreateHud(inst)
	local PlayerHud = require "screens.playerhud"
	inst.HUD = PlayerHud()
	TheFrontEnd:PushScreen(inst.HUD)
	if TheFrontEnd:GetFocusWidget() == nil then
		inst.HUD:SetFocus()
	end
	inst:PushEvent("on_hud_created")
end

local function DeactivateHUD(inst)
	TheFrontEnd:PopScreen(inst.HUD)
	inst.HUD = nil
end

local function SetHudVisibility(inst, should_show)
	if should_show then
		inst.HUD:Show()
	else
		inst.HUD:Hide()
	end
end
-- /Hud

local function SetupCamera(inst)
	--Initialize local focal point
	assert(TheFocalPoint == nil)
	TheFocalPoint = SpawnPrefab("focalpoint", inst)
	TheCamera:SetTarget(TheFocalPoint)
end


local function OnPostSpawn(inst)
	-- Progression doesn't use SpawnPrefab, so call manually. Deferring until
	-- here after dungeon spawns so nearly everything is setup.
	inst.progression:PostSpawn()
end

local function OnLoad(inst)
	inst.progression:LoadProgression()
end

local function OnPostLoadWorld(inst)
	inst.progression:PostLoadWorld(TheSaveSystem.progress:GetValue("progression"))
end

local function StartRoomForEntity(inst)
	for k, v in pairs(inst.components) do
		if v.OnStartRoom then
			v:OnStartRoom()
		end
	end
end

-- Creation order for components on TheDungeon:
-- * ctor
-- * OnPostSpawn
-- * OnLoad   **store data in progression instead**
-- * OnRegisterRoomCreated (every room)
-- * OnPostLoadWorld (every room)
-- * OnStartRoom (every room)
local function StartRoom(inst)
	-- Init progression entity before other things since it's simple and likely
	-- components rely on it.
	StartRoomForEntity(inst.progression)
	StartRoomForEntity(inst)
	StartRoomForEntity(inst.room)

	TheDungeon:CreateHud()

	TheLog.ch.Networking:printf("dungeon: StartRoom SpawnLocalPlayers")
	inst:DoTaskInTicks(0, function()
		TheLog.ch.Networking:printf("SpawnLocalPlayers Deferred Task")
		TheNet:SpawnLocalPlayers()
	end)
end


local function OnRemoveEntity(inst)
	assert(TheWorld == inst)
	TheWorld = nil

	assert(TheFocalPoint ~= nil)
	TheFocalPoint:Remove()
	TheFocalPoint = nil
end

local function Notify_RegisterRoomCreated(inst, room)
	-- `room` is an instance of world_autogen.
	for k, v in pairs(inst.components) do
		if v.OnRegisterRoomCreated then
			v:OnRegisterRoomCreated(room)
		end
	end
	if inst.OnRegisterRoomCreated then
		inst:OnRegisterRoomCreated(room)
	end
end

-- inst: TheDungeon
-- room: instance of world_autogen
local function RegisterRoomCreated(inst, room)
	inst.room = room
	inst.progression.world = room
	Notify_RegisterRoomCreated(inst.progression, room)
	Notify_RegisterRoomCreated(inst, room)

	TheMetrics:RegisterRoom(room)
	TheMetrics:RegisterDungeon(inst)
end

-- Returns the component with a graph of rooms defining the dungeon (world
-- generation data).
local function GetDungeonMap(inst)
	return inst.components.worldmap
end

local function IsInTown(inst)
	if inst.room then
		return inst.room:HasTag("town")
	end
	-- We are created before the room, so it may be nil.
	return InstanceParams.settings.reset_action == RESET_ACTION.LOAD_TOWN_ROOM
end

local function GetCurrentBoss(inst)
	if inst:IsInTown() then
		return nil
	end
	return inst:GetDungeonMap().nav:GetDungeonBoss()
end

local function GetCurrentMiniboss(inst)
	if inst:IsInTown() then
		return nil
	end
	return inst:GetDungeonMap().nav:GetDungeonMiniboss()
end

local function GetDungeonProgress(inst)
	if inst:IsInTown() then
		return 0
	end
	return inst:GetDungeonMap().nav:GetProgressThroughDungeon()
end

local function IsCurrentRoomType(inst, ...)
	if inst:IsInTown() then
		return false
	end
	return inst:GetDungeonMap():IsCurrentRoomType(...)
end

local function GetCurrentRoomType(inst)
	return inst:GetDungeonMap():GetCurrentRoomType()
end

local function IsRegionUnlocked(inst, ...)
	return inst.progression.components.worldunlocks:IsRegionUnlocked(...)
end

local function IsLocationUnlocked(inst, ...)
	return inst.progression.components.worldunlocks:IsLocationUnlocked(...)
end

local function IsFlagUnlocked(inst, ...)
	return inst.progression.components.worldunlocks:IsFlagUnlocked(...)
end

local function UnlockRegion(inst, ...)
	return inst.progression.components.worldunlocks:UnlockRegion(...)
end

local function UnlockLocation(inst, ...)
	return inst.progression.components.worldunlocks:UnlockLocation(...)
end

local function UnlockFlag(inst, ...)
	return inst.progression.components.worldunlocks:UnlockFlag(...)
end

local function LockFlag(inst, ...)
	return inst.progression.components.worldunlocks:LockFlag(...)
end

local function GetAllUnlocked(inst, ...)
	return inst.progression.components.worldunlocks:GetAllUnlocked(...)
end

-- local function UnlockRecipe(inst, ...)
-- 	inst.progression.components.worldunlocks:UnlockRecipe(...)
-- end

-- local function IsRecipeUnlocked(inst, ...)
-- 	return inst.progression.components.worldunlocks:IsRecipeUnlocked(...)
-- end

local function GetMetaProgress(inst)
	return inst.progression.components.metaprogressmanager
end

local function fn(prefabname)
	local inst = CreateEntity("TheDungeon")
		:MakeSurviveRoomTravel()
	assert(TheDungeon == nil)
	TheDungeon = inst

	inst:AddTag("NOCLICK")
	inst:AddTag("CLASSIFIED")

	inst.persists = false

	--Add core components
	inst.entity:AddTransform()


	--Public functions

	inst.OnPostSpawn = OnPostSpawn
	inst.OnLoad = OnLoad
	inst.OnPostLoadWorld = OnPostLoadWorld
	inst.StartRoom = StartRoom
	inst.OnRemoveEntity = OnRemoveEntity
	inst.RegisterRoomCreated = RegisterRoomCreated

	inst.CreateHud = CreateHud
	inst.DeactivateHUD = DeactivateHUD
	inst.SetHudVisibility = SetHudVisibility

	-- Dungeon state (worldmap)
	inst.GetDungeonProgress = GetDungeonProgress
	inst.IsCurrentRoomType = IsCurrentRoomType
	inst.GetCurrentRoomType = GetCurrentRoomType
	inst.GetCurrentBoss = GetCurrentBoss
	inst.GetCurrentMiniboss = GetCurrentMiniboss

	-- World Flags
	-- These are progression state flags, not room flags.
	inst.IsRegionUnlocked = IsRegionUnlocked
	inst.IsLocationUnlocked = IsLocationUnlocked
	inst.IsFlagUnlocked = IsFlagUnlocked
	inst.UnlockRegion = UnlockRegion
	inst.UnlockLocation = UnlockLocation
	inst.UnlockFlag = UnlockFlag
	inst.LockFlag = LockFlag
	inst.GetAllUnlocked = GetAllUnlocked

	inst.GetMetaProgress = GetMetaProgress
	inst.IsInTown = IsInTown

	-- TheDungeon creates the camera even though the world doesn't even
	-- exist yet because we preserve the camera between rooms.
	-- Since TheWorld doesn't exist yet and disappears between rooms so we
	-- need an even higher level soundtracker.
	inst:AddComponent("soundtracker")
	SetupCamera(inst)

	inst:AddComponent("worldmap")
	inst.GetDungeonMap = GetDungeonMap
	inst:AddComponent("playerspawner")
	inst:AddComponent("chathistory")

	inst.progression = CreateProgression(inst)

	inst.DebugDrawEntity = function(self, ui, panel, colors)
		panel:AppendTable(ui, self.progression, "Progression")
		panel:AppendTable(ui, TheFocalPoint, "focalpoint")
	end

	return inst
end

local deps = {
	"focalpoint",
}


return Prefab("dungeon", fn, nil, deps)
