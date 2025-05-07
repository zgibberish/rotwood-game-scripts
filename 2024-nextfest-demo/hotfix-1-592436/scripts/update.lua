UpdatingEnts = {}
NewUpdatingEnts = {}
StopUpdatingComponents = {}
WallUpdatingEnts = {}
NewWallUpdatingEnts = {}
StopWallUpdatingComponents = {}

NetworkUpdatingEnts = {}

function HandleGarbageCollection()
	if LUA_VERSION == 504 then
		local incremental = false

		-- Yes, I set the gc mode every frame. If it doesn't change overhead is minimal and makes it easier to change on the fly
		if incremental then
			local pause = 200			-- default: 200, max: 1000
			local step_multiplier = 100             -- default: 100, max: 1000
			local step_size = 13			-- default: 13, 60 is considered large
			collectgarbage("incremental", pause, step_multiplier, step_size)
		else
			local minor_multiplier = 20			-- default: 20, max:200
			local major_multiplier = 100			-- default: 100, max 1000
			collectgarbage("generational", minor_multiplier, major_multiplier)
		end
		-- currently doing nothing if we're in 5.3, but could call a gc		
		local kb_allocated = 8
		--collectgarbage("step", kb_allocated)
	else
		-- currently doing nothing if we're in 5.3, but could call a gc		
		local kb_allocated = 8
		--collectgarbage("step", kb_allocated)
	end
end

--this is an update that always runs on wall time (not sim time)
function WallUpdate(dt)
	HandleGarbageCollection()

	--TheSim:ProfilerPush("LuaWallUpdate")

	HandleUserCmdQueue()

	local error = TheSim:GetLuaError()
	-- somehow this does not work from RenderOneFrame
	if error and dt > 0 then
		DisplayError(error)
	end

	TheFrontEnd:CheckCachedError()
	if not TheFrontEnd.error_widget then
		TheSim:ProfilerPush("wall updating components")
		for cmp, ent in pairs(StopWallUpdatingComponents) do
			ent:StopWallUpdatingComponent_Deferred(cmp)
		end
		for ent in pairs(NewWallUpdatingEnts) do
			ent:StartWallUpdatingComponents_Deferred()
		end
		for ent in pairs(WallUpdatingEnts) do
			for cmp in pairs(ent.wallupdatecomponents) do
				if StopWallUpdatingComponents[cmp] == nil then
					cmp:OnWallUpdate(dt)
				end
			end
		end
		TheSim:ProfilerPop()
	end

	TheSim:ProfilerPush("mixer")
	TheMixer:Update(dt)
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("input")
	if not SimTearingDown then
		TheInput:OnUpdate(dt)
	end
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("fe")
	if TheFrontEnd.error_widget then
		TheFrontEnd:OnRender()
		TheFrontEnd:OnRenderImGui(dt)
		TheFrontEnd:UpdateControls(dt)
		TheFrontEnd.error_widget:OnUpdate(dt)
	else
		TheFrontEnd:Update(dt)
	end
	TheSim:ProfilerPop()
	--TheSim:ProfilerPop()
end


function NetworkSerialize()
	TheSim:ProfilerPush("networkserialize")
	for ent in pairs(NetworkUpdatingEnts) do
		ent:NetSerialize()	-- this will only do something if this entity is local and needs serializing
	end
	TheSim:ProfilerPop()
end

function NetworkDeserialize()
	TheSim:ProfilerPush("networkdeserialize")
	for ent in pairs(NetworkUpdatingEnts) do
		ent:NetDeserialize()	-- this will only do something if this entity is remote and needs deserializing
	end
	TheSim:ProfilerPop()
end


--this runs on wall time
function PostPhysicsWallUpdate(dt)
	if TheWorld ~= nil then
		local walkable_platform_manager = TheWorld.components.walkableplatformmanager
		if walkable_platform_manager ~= nil then
			walkable_platform_manager:PostUpdate(dt)
		end
	end
end

local _lastsimtick = 0
local _net_restart = false
--this runs on fixed sim ticks
function Update(dt)

-- NW: This is now handled in the NetworkManager, which will get a NetError and will dispatch a NetworkDisconnectEvent system event
--	if InGamePlay() and not TheNet:IsInGame() then
--		if not _net_restart then
--			_net_restart = true
--			TheLog.ch.Networking:printf("******** Lost game session: Returning to main menu... ********")
--			RestartToMainMenu()
--		end
--	end

	HandleClassInstanceTracking()
	TheSim:ProfilerPush("LuaUpdate")

	local tick = GetTick()
	dbassert(tick == _lastsimtick + 1)
	_lastsimtick = tick

	TheSim:ProfilerPush("player controls")
	for i = 1, #AllPlayers do
		local player = AllPlayers[i]
		player.components.playercontroller:ProcessDeferredControls()
	end
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("scheduler")
	Scheduler:Update(tick)
	TheSim:ProfilerPop()

	if SimShuttingDown then
		--TheSim:ProfilerPop()
		return
	end

	TheSim:ProfilerPush("updating components")
--	if not TheFrontEnd.error_widget then
		for cmp, ent in pairs(StopUpdatingComponents) do
			ent:StopUpdatingComponent_Deferred(cmp)
		end
		for ent in pairs(NewUpdatingEnts) do
			ent:StartUpdatingComponents_Deferred()
		end
		for ent in pairs(UpdatingEnts) do
			for cmp in pairs(ent.updatecomponents) do
				if StopUpdatingComponents[cmp] == nil then
					cmp:OnUpdate(dt)
				end
			end
		end
--	end
	TheSim:ProfilerPop()

	-- Spawn all new networked events BEFORE the SGManager updates the tick. (Otherwise OnPostEnterNewState gets called for each spawned event, which we don't want)
	TheNetEvent:SpawnRemoteNetworkEvents()

	TheSim:ProfilerPush("LuaSG")
	SGManager:Update(tick)
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("LuaBrain")
	BrainManager:Update(tick)
	TheSim:ProfilerPop()

	TheSim:ProfilerPop()
end

--This runs after each sim update or wall update
function PostUpdate()
	TheSim:ProfilerPush("LuaPostUpdate")

	HitBoxManager:PostUpdate()
	HitStopManager:PostUpdate()
	SGManager:PostUpdate()

	if TheFocalPoint ~= nil then
		TheSim:SetActiveAreaCenterpoint(TheFocalPoint.Transform:GetWorldPosition())
	else
		TheSim:SetActiveAreaCenterpoint(0, 0, 0)
	end

	TheSim:ProfilerPop()
end

--Camera is always last and always updated
--dt is synced with physics steps, and it can be 0
function CameraUpdate(dt)
	TheSim:ProfilerPush("camera")
	TheCamera:Update(dt)
	TheSim:ProfilerPop()
end

Updaters = require "updaters"

