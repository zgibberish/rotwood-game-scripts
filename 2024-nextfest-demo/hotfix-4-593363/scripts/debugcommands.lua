local DebugDraw = require "util.debugdraw"
local DebugNodes = require "dbui.debug_nodes"
local DebugPanel = require "dbui.debug_panel"
local kassert = require "util.kassert"
local kstring = require "util.kstring"
local krandom = require "util.krandom"
local lume = require "util.lume"
local playerutil = require"util.playerutil"
require "util"


-- Cache things that should only have one instance for d_run_on_demand. Cache
-- entities you spawn so you can d_destroy_cached before respawning without
-- leaving the old behind.
-- Not every spawn debug command should add to this cache! Use for
-- d_run_on_demand-focused cases and directly from your run_on_demand file.
global "DEBUG_CACHE"
DEBUG_CACHE = DEBUG_CACHE or {
    cleanup_fns = {},
    ents = {},
    screens = {},
    tasks = {},
}
function d_destroy_cached()
    for key,fn in pairs(DEBUG_CACHE.cleanup_fns) do
        fn(key)
    end
    for key,screen in pairs(DEBUG_CACHE.screens) do
        TheFrontEnd:PopScreen(screen)
    end
    for key,val in pairs(DEBUG_CACHE.ents) do
        if val:IsValid() then
            -- How can I make this more robust? Tried: Checking guids, removing
            -- in ascending guid order, removing parents first, clearing parent
            -- and follow.
            val:Remove()
        end
    end
    for key,task in pairs(DEBUG_CACHE.tasks) do
        task:Cancel()
    end
    for _,list in pairs(DEBUG_CACHE) do
        lume.clear(list)
    end
end

-- Listen for events and remove listener with d_destroy_cached.
function d_listen_for_event(listener, event, fn, target)
    kassert.typeof("string", event)
    table.insert(DEBUG_CACHE.cleanup_fns, function()
        if listener and listener:IsValid() then
            listener:RemoveEventCallback(event, fn, target)
        end
    end)
    return listener:ListenForEvent(event, fn, target)
end

-- Put in your localexec to fake a prod build.
function d_fakeproductionbuild()
    print("Pretending to be prod build.", CONFIGURATION, "-> PRODUCTION")
    CONFIGURATION = "PRODUCTION"
    DEV_MODE = false
end

-- Use the "Attach [d_attachdebugger]" debug target in VSCode and then run this
-- command to start debugging. Lets you run the game in fast mode until you
-- need to start debugging instead of launching exe with -enable_debug_console
-- and always suffering the lag of the debugger.
function d_attachdebugger()
    TheSim:UseDebuggerNextRestart(true)

    Debuggee = Debuggee or require 'debuggee'
    local start_result, breaker_type = Debuggee.start()
    if start_result then
        TheLog.ch.Debug:printf("Debuggee started. Success=%s Breaker=%s", start_result, breaker_type)
    else
        -- Failure is usually because nothing was listening.
        TheLog.ch.Debug:print([[Debuggee start failed.
Run "Attach [d_attachdebugger]" in vscode *and then* call d_attachdebugger.]])
    end
end

function d_forcecrash(unique)
    local path = "crashing_via_d_forcecrash_"
    if unique then
    path = path .. kstring.random(10, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUV")
    end

    if TheGlobalInstance then
    TheGlobalInstance:DoTaskInTime(0,function() _G[path].b = 0 end)
    else
    error("Don't have a clever way to crash.")
    end
end

function d_forcecrash_native()
    -- Imgui asserts on missing ends in release builds.
    imgui:Begin("crash")
end

function d_knownassert(key)
    key = key or "CONFIG_DIR_WRITE_PERMISSION"

    if TheWorld then
    TheWorld:DoTaskInTime(0,function() known_assert(false, key) end)
    elseif TheFrontEnd then
    TheFrontEnd.screenroot.inst:DoTaskInTime(0,function() known_assert(false, key) end)
    end
end


-- Simple function timing. For profiling see profiler.lua or
-- TheSim:ProfilerPush/Pop and tracy.
-- https://www.notion.so/kleient/Profiling-0b3c1c9890c94c56bf34a6ca489ffbba
function d_timeit(fn)
    TheSim:StartTimer() -- cannot be used nested!
    fn()
    -- returns seconds
    return TheSim:StopTimer()
end


function d_teststate(state)
    c_sel().sg:GoToState(state)
end

function d_anim(animname, loop)
    if GetDebugEntity() then
        GetDebugEntity().AnimState:PlayAnimation(animname, loop or false)
    else
        print("No DebugEntity selected")
    end
end

-- Get the widget selected by the debug widget editor (WidgetDebug).
-- Try d_widget():ScaleTo(3,1,.7)
function d_widget()
    local panel = TheFrontEnd:FindOpenDebugPanel(DebugNodes.DebugWidget)
    if panel then
        return panel:GetNode().focus_widget
    else
        print("DebugWidget panel not open")
    end
end

-- Pass any lua object to inspect it in a DebugNode.
--       d_viewinpanel(TheWorld.components.propmanager)
function d_viewinpanel(obj, reuse_panel)
    local ent = EntityScript.is_instance(obj) and obj or nil
    local panel = reuse_panel and TheFrontEnd:GetTopDebugPanel()
    if not panel then
        panel = DebugNodes.ShowDebugPanel(DebugNodes.DebugEntity, false, ent)
    end
    if ent then
        c_select(obj)
    else
        panel:PushDebugValue(obj)
    end
    return panel
end
d_view = d_viewinpanel -- short alias.

-- A variant that I've found useful. Great in run_on_demand.
function d_viewinpanel_autosize(...)
    local old_node_count = TheFrontEnd:GetNumberOpenDebugPanels(DebugNodes.DebugNode)
    local panel = d_viewinpanel(...)
    local opened_new_panel = TheFrontEnd:GetNumberOpenDebugPanels(DebugNodes.DebugNode) > old_node_count
    if opened_new_panel then
        -- Maximize new panels. Use left/right maximize to snap to the side for
        -- less neck strain. We don't want in d_viewinpanel because it's hard
        -- to open multiple panels.
        panel.did_maximize = TheGameSettings:Get("graphics.fullscreen")
    end
end

-- Call from localexec.lua to setup running the file on Ctrl-d:
-- d_run_on_demand("scripts/localexec_no_package/user_YOURNAMEHERE_run_on_demand.lua")
--
-- Or this to run on Ctrl-Alt-b:
-- d_run_on_demand(
--   "scripts/localexec_no_package/run_on_demand.lua",
--   InputConstants.Keys.B,
--   { InputConstants.Keys.CTRL, InputConstants.Keys.ALT })
function d_run_on_demand(filepath, key, mods)
    key = key or InputConstants.Keys.D
    mods = mods or { InputConstants.Keys.CTRL }
    local IsKeyDown = lume.fn(TheInput.IsKeyDown, TheInput)
    AddGlobalDebugKey(key, function()
        if lume.all(mods, IsKeyDown) then
            -- Don't force PushNode calls to open new windows because ctrl was
            -- held for run_on_demand.
            DebugPanel.can_listen_to_ctrl = false
            local fn, r = loadfile(filepath)
            if type(fn) == "string" then
                print(fn)
            else
                -- pcall so user errors don't propagate to crash reporter.
                local status, msg = xpcall(fn, generic_error)
                if not status then
                    print(("Error in %s:\n%s"):format(filepath, msg))
                    -- Show error to user (no lua crash screen for pcall).
                    TheFrontEnd:ShowConsoleLog()
                end
            end
            DebugPanel.can_listen_to_ctrl = true
        end
        return true
    end)
end

-- Useful before opening editors in d_run_on_demand.
function d_close_and_revert_editors()
    for _, panel in ipairs(TheFrontEnd.debug_panels) do
        local node = panel:GetNode()
        if node and node.Revert then
            -- Prevent savealert when editor is dirty.
            node:Revert()
        end
        panel.show = false
    end
end

function d_widgettest()
    local WidgetTest = require "screens/featuretests/widgettest"
    TheFrontEnd:PushScreen(WidgetTest())
end

function d_screen_getpower(power_def)
    return d_open_screen("screens.dungeon.roombonusscreen", GetDebugPlayer(), power_def)
end

function d_open_screen(screen_module, target_player, ...)
    target_player = target_player or ConsoleCommandPlayer()
    print("d_open_screen: showing screen over top of", TheFrontEnd:GetFocusWidget())

    if DEBUG_CACHE.screens.scr then
        TheFrontEnd:PopScreen(DEBUG_CACHE.screens.scr)
    end

    local screen_ctor = require(screen_module)
    local screen = screen_ctor:DebugConstructScreen(target_player, ...)
    if screen then
        TheFrontEnd:PushScreen(screen)
        DEBUG_CACHE.screens.scr = screen
    else
        print("d_open_screen: failed to create screen", screen_module)
    end
    return screen
end

function d_buildtest()
    local player = GetDebugPlayer()
    if not player then
        return
    end
    if player.sg:HasStateTag("busy") then
        player.sg:GoToState("idle")
        return false
    else
        player.sg:GoToState("buildtest")
        return true
    end
end

-- Spawns input prefab and draws 1 unit squares from their position forward to
-- visualize a distance.
function d_estimate_distance(prefab, distance)
    distance = distance or 5
    prefab = prefab or "floracrane"
    local width = 1
    local ent = c_spawndumb(prefab)
    local seconds = 0.2
    -- Use a task so they follow the entity.
    local taskname = "estimate_distance".. ent.GUID
    DEBUG_CACHE.tasks[taskname] = TheWorld:DoPeriodicTask(seconds, function(inst_)
        if not ent:IsValid() then
            DEBUG_CACHE.tasks[taskname]:Cancel()
            DEBUG_CACHE.tasks[taskname] = nil
            return
        end
        local pos = ent:GetPosition()
        local x = pos.x - width/2
        for i=1,distance do
            DebugDraw.GroundSquare(x + i, pos.z, width, nil, nil, seconds)
        end
    end)
    return ent
end

-- Visualize where is considered walkable. The grid intersection points are the
-- test point. We connect them because it looks cool.
function d_draw_iswalkable()
    -- Too many lines to draw frequently (especially if you shrink pad).
    local seconds = 0.5
    local thick = 1
    DEBUG_CACHE.tasks.walkable = TheWorld:DoPeriodicTask(seconds, function(inst_)
        local pad = 1.5
        for x=-30,30,pad do
            for z=-30,30,pad do
                local c = TheWorld.Map:IsWalkableAtXZ(x,z) and WEBCOLORS.CYAN or WEBCOLORS.RED
                DebugDraw.GroundPoint(x,z, pad/2, c, thick, seconds)
            end
        end

        local player = GetDebugPlayer()
        if player then
            local x,z = player.Transform:GetWorldXZ()
            local c = TheWorld.Map:IsWalkableAtXZ(x,z) and WEBCOLORS.CYAN or WEBCOLORS.RED
            DebugDraw.GroundSquare(x,z, 1, c, thick, seconds)
            c = TheWorld.Map:IsGroundAtXZ(x,z) and WEBCOLORS.BROWN or WEBCOLORS.YELLOW
            DebugDraw.GroundCircle(x,z, 1, c, 1, seconds)
        end
    end)
end

-- Visualize where is considered ground. See d_draw_iswalkable and
-- MapComponentReg::IsGroundAtXZ.
function d_draw_isground()
    -- Too many lines to draw frequently (especially if you shrink pad).
    local seconds = 0.5
    local thick = 1
    DEBUG_CACHE.tasks.ground = TheWorld:DoPeriodicTask(seconds, function(inst_)
        local pad = 1.5
        for x=-28,32,pad do
            for z=-28,32,pad do
                local c = TheWorld.Map:IsGroundAtXZ(x,z) and WEBCOLORS.BROWN or WEBCOLORS.YELLOW
                DebugDraw.GroundPoint(x,z, pad/2, c, thick, seconds)
            end
        end
    end)
end

function d_draw_closestboundary()
    local seconds = 0.1
    local thick = 1
    DEBUG_CACHE.tasks.closest = TheWorld:DoPeriodicTask(seconds, function(inst_)
        local player = GetDebugPlayer()
        if player then
            local pt, dist = TheWorld.Map:FindClosestPointOnWalkableBoundary(player:GetPosition())
            DebugDraw.GroundPoint(pt, nil, 1, WEBCOLORS.ORANGE, thick, seconds)
        end
    end)
end

function d_spawnlayout(name, offset)
    local obj_layout = require("map/object_layout")
    local entities = {}
    local map_width, map_height = TheWorld.Map:GetSize()
    local add_fn = {
        fn=function(prefab, points_x, points_y, current_pos_idx, entitiesOut, width, height, prefab_list, prefab_data, rand_offset)
            print("adding, ", prefab, points_x[current_pos_idx], points_y[current_pos_idx])
            local x = (points_x[current_pos_idx] - width/2.0)*TILE_SCALE
            local y = (points_y[current_pos_idx] - height/2.0)*TILE_SCALE
            x = math.floor(x*100)/100.0
            y = math.floor(y*100)/100.0
            SpawnPrefab(prefab, TheDebugSource).Transform:SetPosition(x, 0, y)
        end,
        args={entitiesOut=entities, width=map_width, height=map_height, rand_offset = false, debug_prefab_list=nil}
    }

    local x, z = ConsoleWorldPosition():GetXZ()
    x, z = TheWorld.Map:GetTileCoordsAtXZ(x, z)
    offset = offset or 3
    obj_layout.Place({math.floor(x) - 3, math.floor(z) - 3}, name, add_fn, nil, TheWorld.Map)
end


-- Makes a player follow a leader.
-- For mp testing, try adding this to your localexec to make everyone follow p1:
--   for i=2,4 do
--      if AllPlayers[i] then
--          d_playerfollow(AllPlayers[i], AllPlayers[1], "attack")
--      end
--   end
function d_playerfollow(follower, leader, behavior)
    TheLog.ch.Cheat:printf("d_playerfollow(follower=<%s>, leader=<%s>, behavior=%s)", follower, leader, behavior)
    if behavior == "wait_for_room_complete"
        and TheWorld
        and not TheWorld.components.spawncoordinator:GetIsRoomComplete()
    then
        local onroomcomplete = function(source) d_playerfollow(follower, leader) end
        TheDebugSource:ListenForEvent("room_complete", onroomcomplete, TheWorld)
        return
    end

    follower = follower or ConsoleCommandPlayer()
    leader = leader or GetDebugPlayer()
    if follower == leader then
        print("Error: d_playerfollow requires two different entities.")
        return
    end
    kassert.typeof("table", follower, leader)
    local max_distance = 7
    follower.components.forcedlocomote:ChaseEntity(leader, max_distance)

    local task_name = "follow_" .. follower.GUID
    if DEBUG_CACHE.tasks[task_name] then
        DEBUG_CACHE.tasks[task_name]:Cancel()
        DEBUG_CACHE.tasks[task_name] = nil
    end

    if behavior == "attack" then
        local heavy = true
        DEBUG_CACHE.tasks[task_name] = follower:DoPeriodicTask(1, function(inst)
            if not leader
                or not leader:IsValid()
                or not leader:IsAlive()
            then
                -- Release control on losing our leader so follower can revive them.
                follower.components.forcedlocomote:AbortMove()
                return
            end

            -- Ensure it doesn't stop following.
            if not follower.components.forcedlocomote:IsForcingMove()
            then
                follower.components.forcedlocomote:ChaseEntity(leader, max_distance)
            end

            if TheWorld.components.spawncoordinator:GetIsRoomComplete() then
                -- Don't attack for cleared rooms. This task is on
                -- the player, so it will cleanup if they destroy.
                return
            end

            -- Don't make this more complex! If we want a smarter player bot,
            -- we should write a Brain for them.
            if heavy then
                inst.components.playercontroller:OnHeavyAttackButton(true)
                inst.components.playercontroller:OnHeavyAttackButton(false)
            else
                inst.components.playercontroller:OnLightAttackButton(true)
                inst.components.playercontroller:OnLightAttackButton(false)
            end
            heavy = not heavy
        end)
    end
end

-- Make local players follow an arbitrary remote player. Add to localexec to
-- make clients follow a remote:
--   if not TheNet:IsHost() then
--      d_playerfollowremote("attack")
--   end
function d_playerfollowremote(behavior)
    if DEBUG_CACHE.ents.playerfollowremote then
        DEBUG_CACHE.ents.playerfollowremote:Remove()
    end
    DEBUG_CACHE.ents.playerfollowremote = CreateEntity("d_playerfollowremote")
        :MakeSurviveRoomTravel()
    local remote = nil
    local function ApplyToPlayer(source, player)
        if remote and remote:IsValid() then
            if player:IsLocal() then
                d_playerfollow(player, remote, behavior)
            end
        else
            if not player:IsLocal() then
                remote = player
                TheLog.ch.Cheat:printf("d_playerfollowremote assigned remote=<%s>", remote)
                for id,ent in playerutil.LocalPlayers() do
                    d_playerfollow(ent, remote, behavior)
                end
            end
        end
    end
    -- Immediately apply in case players are already spawned.
    local first_remote = lume(AllPlayers)
        :reject(EntityScript.IsLocal)
        :first()
        :result()
    if first_remote then
        ApplyToPlayer(TheDungeon, first_remote)
    end
    DEBUG_CACHE.ents.playerfollowremote:ListenForEvent("playerentered", ApplyToPlayer, TheDungeon)
end


function d_movetoexit(ent)
    local gate_tuning = require "defs.gate_tuning"

    ent = ent or c_sel()
    local portal = c_find("room_portal")
    local cardinal = portal.components.roomportal:GetCardinal()
    local data = gate_tuning.GetTuningForCardinal(cardinal)
    local pos = portal:GetPosition()
    if ent.prefab:find("gate") then
        pos = pos + data.world.gate
        print("d_movetoexit: Detected a gate, so using gate offset", ent.prefab)
    end
    ent.Transform:SetPosition(pos:unpack())
end

function d_light()
    -- TODO: This function doesn't seem to work anymore.
    local player = GetDebugPlayer()
    if not player then
        return
    end
    local light_prefab = "lightspot_angular"
    TheSim:SetAmbientColor(0.8, 0.8, 0.8)
    local obj = c_spawn(light_prefab)
    obj.Light:SetColor(1, 1, 1, 1)
    --~ obj.Light:SetCookie("images/light_cookie_angular_01.tex")
    obj.Light:SetScale(10)
    obj.Light:SetRotation(1)
    obj.Light:SetIntensity(1.0)
    local pt = player:GetPosition()
    obj.Transform:SetPosition(pt.x - 30, 0, pt.z)

    local obj = c_spawn(light_prefab)
    obj.Light:SetColor(1, 1, 1, 1)
    --~ obj.Light:SetCookie("images/light_cookie_angular_02.tex")
    obj.Light:SetScale(10)
    obj.Light:SetRotation(1)
    obj.Light:SetIntensity(1.0)
    obj.Transform:SetPosition(pt.x - 10, 0, pt.z)

    local obj = c_spawn(light_prefab)
    obj.Light:SetColor(1, 1, 1, 1)
    --~ obj.Light:SetCookie("images/light_cookie_angular_03.tex")
    obj.Light:SetScale(10)
    obj.Light:SetRotation(1)
    obj.Light:SetIntensity(1.0)
    obj.Transform:SetPosition(pt.x + 10, 0, pt.z)

    local obj = c_spawn(light_prefab)
    obj.Light:SetColor(1, 1, 1, 1)
    --~ obj.Light:SetCookie("images/light_cookie_angular_04.tex")
    obj.Light:SetScale(10)
    obj.Light:SetRotation(1)
    obj.Light:SetIntensity(1.0)
    obj.Transform:SetPosition(pt.x + 30, 0, pt.z)

    -- colored light
    local obj = c_spawn(light_prefab)
    local r,g,b = 1,1,1
    obj:DoPeriodicTask(0.033, function()
        r = r + 0.01
        g = g + 0.015
        b = b + 0.02
        local rs = (math.sin(r) + 1)/2
        local gs = (math.sin(g) + 1)/2
        local bs = (math.sin(b) + 1)/2
        obj.Light:SetColor(rs, gs, bs, 1)
    end)
    obj.Light:SetColor(1, 1, 1, 1)
    --~ obj.Light:SetCookie("images/light_cookie_angular_01.tex")
    obj.Light:SetScale(10)
    obj.Light:SetRotation(1)
    obj.Light:SetIntensity(1.0)
    obj.Transform:SetPosition(pt.x + 50, 0, pt.z)

    -- rotating, scaling, intensity
    local obj = c_spawn(light_prefab)
    local rot = 0
    local sx,sy = 0,0
    local intens = 0
    obj:DoPeriodicTask(0.033, function()
        rot = rot + 0.1
        obj.Light:SetRotation(rot)
        sx = sx + 0.01
        sy = sy + 0.015
        local sxs = (math.sin(sx) + 1)/2
        local sys = (math.sin(sy) + 1)/2
        obj.Light:SetScale(10 + sxs*4, 10+sys*4)
        intens = intens + 0.01
        local sintens = (math.sin(intens) + 1)/2
        obj.Light:SetIntensity(sintens)

    end)
    obj.Light:SetColor(1, 1, 1, 1)
    --~ obj.Light:SetCookie("images/light_cookie_angular_01.tex")
    obj.Light:SetScale(10)
    obj.Light:SetRotation(1)
    obj.Light:SetIntensity(1.0)
    obj.Transform:SetPosition(pt.x - 50, 0, pt.z)

end

function d_fadeplayer()
    local fade = 0
    TheWorld:DoPeriodicTask(0.033, function()
        fade = fade + 0.033
        local fadecol = (math.sin(fade) + 1)/2

        local player = GetDebugPlayer()
        if player then
            player.AnimState:SetMultColor(fadecol, fadecol, fadecol, fadecol)
        end
    end)
end

function d_fire(num)
    local inst
    if num==1 then
        inst = SpawnPrefab("fire_indoor", TheDebugSource)
    elseif num==2 then
        inst = SpawnPrefab("fog_map_fg", TheDebugSource)
    else
        inst = SpawnPrefab("Sloth_test1", TheDebugSource)
    end
    SetDebugEntity(inst)
end

function d_worldfire(num)
    local inst = SpawnPrefab("worldfire", TheDebugSource)
    SetDebugEntity(inst)
end

function d_childfire()
    local player = GetDebugPlayer()
    if player then
        local inst = SpawnPrefab("worldfire", TheDebugSource)
        inst.Transform:SetPosition(0,0,0)
        inst.entity:AddFollower()
        inst.Follower:FollowSymbol(player.GUID, "weapon_back01")
        SetDebugEntity(inst)
    end
end

function d_childtest()
    local player = GetDebugPlayer()
    if player then
        local p = DebugSpawn("player_side")
        p.Transform:SetPosition(3,0,0)
        p.entity:AddFollower()
        p.Follower:FollowSymbol(player.GUID, "weapon_back01")
    end
end

local function get_worldmap_safe()
    local WorldMap = require "components.worldmap"
    return WorldMap.GetDungeonMap_Safe()
end

function d_startdailyrun(location_id)
    location_id = location_id or "kanft_swamp"
    local date = os.date("*t")
    local seed = os.time{year = date.year, month = date.month, day = date.day}
    d_startrun(location_id, seed)
end

-- ensure all parameters can be optional into the call stack for ease-of-use
-- ascension override can only be used when launching from within an active world
function d_startrun(location_id, rng_seed, alt_mapgen_id, ascension, quest_params)
    TheSaveSystem.cheats:SetValue("skip_new_game_flow", true)
    TheLog.ch.Cheat:print("d_startrun", location_id, rng_seed, alt_mapgen_id, ascension, quest_params)
    location_id = location_id or "kanft_swamp"
	-- quest_params are optional: default is handled in RoomLoader.
    local biomes = require "defs.biomes"
    TheAudio:StopAllSounds() -- Not normal flow, so clean up sounds.

    local start_fn = function()
        local RoomLoader = require "roomloader"
        RoomLoader.StartRunWithLocationData(biomes.locations[location_id], rng_seed, alt_mapgen_id, ascension, quest_params)
    end

    if not TheNet:IsInGame() then
        TryStartNetwork()
        TheGlobalInstance:DoTaskInTime(1, function()
            start_fn()
        end)
    else
        start_fn()
    end
end

local function start_specific_room(roomtype, location_id, world)
    TheSaveSystem.cheats:SetValue("skip_new_game_flow", true)
    location_id = location_id or "kanft_swamp"
    local biomes = require "defs.biomes"
    local biome_location = biomes.locations[location_id]
    if not world then
        world = biome_location:Debug_GetRandomRoomWorld(roomtype)
    end
    local worldmap = get_worldmap_safe()
    TheAudio:StopAllSounds() -- Not normal flow, so clean up sounds.
    worldmap:Debug_StartArena(world,
        {
            roomtype = roomtype,
            location = biome_location.id,
            is_terminal = false, -- terminal suppresses resource rooms
        })
end

function d_starthype(location_id)
    return start_specific_room("hype", location_id)
end

function d_startminiboss(location_id)
    return start_specific_room("miniboss", location_id)
end

function d_startboss(location_id)
    return start_specific_room("boss", location_id)
end

function d_startmarket(location_id)
    if TheWorld then
        d_fill_markets()
    end
    return start_specific_room("market", location_id)
end

function d_restartrun()
    if InGamePlay() and TheNet:IsHost() and TheNet:IsInGame() and TheWorld and not TheWorld:HasTag("town") then
        local mode, world, regionID, locationID, seed, altMapGenID, ascension, _seqNr, questParams = TheNet:GetRunData()
        if mode == STARTRUNMODE_DEFAULT then
            d_startrun(locationID, seed, altMapGenID, ascension, questParams)
        elseif mode == STARTRUNMODE_ARENA then
            start_specific_room(regionID, locationID, world) -- regionID is roomtype for arenas
        else
            assert(false, "Unhandled start run mode: %d", mode)
        end
    end
end

function d_loadempty(world)
    if not world then
        world = TheWorld and TheWorld.prefab or "startingforest_arena_nesw"
    end
    d_loadroom(world, "empty")
end

-- Replace your dungeon_temp with one from feedback and call this to load it.
-- May fail if dungeon datastructures changed.
function d_loadsaveddungeon()
    local worldmap = get_worldmap_safe()
    worldmap:Debug_ReloadDungeonFromDisk()
end

function d_dumpworldgen()
    TheLog:enable_channel("WorldMap")
    TheLog.ch.WorldMap:print("--- Dumping WorldMap data ---")
    local worldmap = TheDungeon:GetDungeonMap()
    TheLog.ch.WorldMap:print(worldmap:GetDebugString(true))
    for room_id,room in ipairs(worldmap.data.rooms) do
        if worldmap.nav:is_room_reachable(room) then
            worldmap:Debug_LogProcGenInputsForRoom(room)
        end
    end
    TheLog.ch.WorldMap:print("--- Done ---")
end

function d_loadroom(name, as_roomtype, scene_gen_prefab_name)
    TheSaveSystem.cheats:SetValue("skip_new_game_flow", true)
    TheLog.ch.Cheat:print("d_loadroom", name, as_roomtype)
    TheAudio:StopAllSounds() -- Not normal flow, so clean up sounds.
    if as_roomtype then
        kassert.typeof("string", as_roomtype)
        -- Start playing as if we were in dungeon.
        get_worldmap_safe():Debug_StartArena(name, {
                roomtype = as_roomtype,
                location = scene_gen_prefab_name
            })
    else
        -- Load the room like we're editing.
        local RoomLoader = require "roomloader"
        RoomLoader.DevLoadLevel(name, scene_gen_prefab_name)
    end
end

function d_unlockroom()
    TheWorld.components.roomlockable:RemoveAllLocks()
    print("Force unlocked current room")
end

function d_clearwave()
    TheWorld.components.roomclear:Debug_ForceClear()
end

function d_clearroom()
    TheWorld.components.spawncoordinator:SetEncounterCleared()
end

function d_unlock_all_locations()
    local biomes = require "defs.biomes"

    for region, data in pairs(biomes.regions) do
        GetDebugPlayer().components.unlocktracker:UnlockRegion(region)
    end

    for location, data in pairs(biomes.locations) do
        GetDebugPlayer().components.unlocktracker:UnlockLocation(location)
    end
end

function d_spawnwave_single()
    -- Spawn a single thing for testing room_cleared events. Pairs well with
    -- d_clearwave.
    local sc = TheWorld.components.spawncoordinator
    local testencounter = function(spawner)
        spawner:StartSpawningFromHidingPlaces()
        spawner:SpawnWave({ cabbageroll = 1 })
    end
    sc:StartCustomEncounter(testencounter)
end

function d_spawnjumpwave_single()
    -- Spawn a single thing for testing room_cleared events. Pairs well with
    -- d_clearwave.
    local sc = TheWorld.components.spawncoordinator
    local testencounter = function(spawner)
        spawner:StartSpawningFromHidingPlaces()
        spawner:SpawnWave({ yammo = 1 })
    end
    sc:StartCustomEncounter(testencounter)
end

function d_equip(name, slot)
    local player = GetDebugPlayer()
    if player then
        if slot ~= nil then
            player.components.inventory:Equip(slot, name)
        else
            local Equipment = require("defs.equipment")
            for _, v in pairs(Equipment.Slots) do
                if v ~= Equipment.Slots.WEAPON then
                    player.components.inventory:Equip(v, name)
                end
            end
        end
    end
end

function d_run()
    c_sel():PushEvent("locomote", { move = c_sel().sg:HasStateTag("walking") or not c_sel().sg:HasStateTag("moving"), run = true })
end

function d_walk()
    local player = GetDebugPlayer()
    if player then
        c_sel():PushEvent("locomote", { move = c_sel().sg:HasStateTag("running") or not c_sel().sg:HasStateTag("moving"), run = false, dir = c_sel():GetAngleTo(player) })
    end
end

--Force load ALL prefab files for dev
function d_allprefabs()
    local existing = {}
    for i = 1, #PREFABFILES do
        existing[PREFABFILES[i]] = true
    end

    local filepath = require("util/filepath")
    local files = {}
    local recursive = true
    filepath.list_files("scripts/prefabs/", "*.lua", recursive, files)
    for i = 1, #files do
        local file = string.match(files[i], "^scripts/prefabs/(.+)[.]lua$")
        -- file will be nil when not a valid lua file.
        if file and not existing[file] then
            PREFABFILES[#PREFABFILES + 1] = file
            LoadPrefabFile("prefabs/"..file)
        end
    end
end

function d_draw_health()
    local function DrawDestinations(inst_)
        local x,z = inst_.Transform:GetWorldXZ()
        local t = InverseLerp(
            0,
            inst_.components.health:GetMax(),
            inst_.components.health:GetCurrent())
        DebugDraw.GroundCircle(x, z, t * 10, WEBCOLORS.YELLOW)
    end
    local inst = c_sel()
    inst.debug_draw_task = inst:DoPeriodicTask(0, DrawDestinations, 0)
end

function d_audio_error_on_missing()
    local strict = require "util.strict"
    local fmodtable = require "defs.sound.fmodtable"
    -- Don't strictify by default to allow nicer error messages.
    strict.strictify(fmodtable, "fmodtable", true)
end

function d_disablephysics(inst, disable)
    disable = disable == nil and true or disable
    if not inst.Physics then
        return
    end
    if disable then
        if not inst.Physics.UnwrapNativeComponent then
            inst.Physics:SetMotorVel(0, 0, 0)
            inst.Physics:SetVel(0, 0, 0)
            inst:Debug_WrapNativeComponent("Physics")
            local noop = function() end
            inst.Physics.SetMotorVel = noop
            inst.Physics.Stop = noop
            inst.Physics.Move = noop
            inst.Physics.MoveRelFacing = noop
            inst.Physics.Teleport = noop
        end
    else
        if inst.Physics.UnwrapNativeComponent then
            inst.Physics:UnwrapNativeComponent()
        end
    end
end


function d_deleteprops()
    for i,v in pairs(Ents) do
        print(i,v,v.components.prop)
        if v.components.prop then
            v:Remove()
        end
    end
end

function d_scout(smart)
    c_godmode()
    for x = -5, 5 do
        for y = -5, 5 do
            local inst = smart and c_spawn("npc_scout") or c_spawndumb("npc_scout")
            inst.Transform:SetPosition(x * 3, 0, y * 3)
        end
    end
--[[
    for x = -3, 3 do
        for y = -3, 3 do
            local inst = smart and c_spawn("yammo") or c_spawndumb("yammo")
            inst.Transform:SetPosition(x * 4, 0, y * 4)
        end
    end
]]
end

function d_glow()
    local player = GetDebugPlayer()
    if player then
        player.components.coloradder:PushColor("potion", 0, 1, 0, 0)
        player.components.bloomer:PushBloom("potion", 1)
    end
end

function d_surroundme(count, radius)
    local player = GetDebugPlayer()
    if player then
        count = count and (count > 0 and count or 12) or 12
        radius = radius and (radius > 0 and radius or 8) or 8

        local x, z = player.Transform:GetWorldXZ()
        local angle = 0
        local angleIncrement = 360 / count

        for i=1,count do
            local p = Vector2.rotate(Vector2(radius,0), -math.rad(angle))
            p = p + Vector2(x,z)
            local ent = DebugSpawn("cabbageroll")
            ent.Transform:SetPosition(p.x, 0, p.y)
            angle = angle + angleIncrement
        end
    end
end

function d_powerup(count)
    local powers = {
        "pwr_attack_dice",
        "pwr_grand_entrance",
        "pwr_retribution",
        "pwr_damage_until_hit",
        "pwr_heal_on_focus_kill",
        "pwr_thick_skin",
        "pwr_heal_on_enter",
        "pwr_max_health_and_heal",
        "pwr_running_shoes",
        "pwr_undamaged_target",
        "pwr_mulligan",
        "pwr_iron_brew",
        "pwr_risk_reward",
        "pwr_extended_range",
        "pwr_volatile_weaponry",
        "pwr_pump_and_dump",
        "pwr_momentum",
    }

    count = count or #powers
    count = lume.clamp(count, 0, #powers)

    for i = 1,count do
        c_give(powers[i])
    end
end

function d_spawninring(prefabs_to_spawn)
    local player = GetDebugPlayer()
    if player then
        kassert.typeof("table", prefabs_to_spawn)
        local centre = player:GetPosition()
        local offset = Vector3.unit_x * 10
        print(prefabs_to_spawn)
        local delta = math.pi * 2 / table.count(prefabs_to_spawn)
        local i = 0
        for key,prefab in pairs(prefabs_to_spawn) do
            i = i + 1
            local ent = c_spawn(prefab)
            local pos = centre + offset:rotate(i * delta, Vector3.unit_y)
            ent.Transform:SetPosition(pos:unpack())
            DEBUG_CACHE.ents[key] = ent
        end
    end
end

function d_ringofpower()
    local drops = {
        core   = 'soul_drop_lesser',
        heart  = 'soul_drop_heart',
        meta   = 'soul_drop_greater',
        power  = 'power_drop_player',
        skill  = 'power_drop_skill',
        shield = 'power_drop_shield',
    }
    d_spawninring(drops)
end

function d_shield(pips)
    pips = pips or 1
    local player = ConsoleCommandPlayer()
    if not player:HasTag(POWER_TAGS.PROVIDES_SHIELD) then
        c_power("pwr_shield_focus_kill")
        -- For some reason getting a shield power isn't enough to get shield.
        c_power("pwr_shield")
        pips = pips - 1
    end

    local Power = require "defs.powers.power"
    local shield_def = Power.Items.SHIELD.shield
    player.components.powermanager:DeltaPowerStacks(shield_def, pips)
end

-- Adds tbl to DebugAnything -- if it's open. See d_edit to view immediately.
function d_anything( tbl )
    SetDebugTable(tbl)
end

function d_watch( key, tbl, entity, max_depth, condition_fn )
    --pass in the key, the parent table, and optionally an entity e.g.
    --d_watch("current", inst.components.health, inst, 0 )
    --condition_fn signature is:
    --function( old_val, new_val ) return is_true end
    if not DebugNodes.DebugWatch.IsWatching(key, tbl) then
        DebugNodes.DebugWatch.ToggleWatch(key, tbl, entity, max_depth, condition_fn)
    end
end

function d_addcomponenttohistory( component_name )
    TheFrontEnd.debugMenu.history:GetComponentHistory():AddComponentToTrack(component_name)
end

function d_loadsave(dirname)
    TheSim:SetSaveGameDirectory(dirname)
    d_loadsaveddungeon()
end

function d_metrics()
    local points = 33
    local source = "string_with_value_source"
    local json_t = { PLAYER_DATA = {name = 33, test="kaj"}, METTLE_DELTA = points, METTLE_SOURCE = type(source) == "string" and source or "" }
    local json_data = json.encode( json_t )
    TheSim:SendMetricsData("REMOVED_NEGOTIATION_CARD", json_data)
end

local use_30hz_timing = true
function d_togglerefreshplayerframeevents()
    local player = GetDebugPlayer()
    if player then
        TheLog.ch.StateGraph:printf("Refreshing player frame events (use_30hz_timing=%s)", tostring(use_30hz_timing))
        for _k,state in pairs(player.sg.sg.states) do
            if state:DebugRefreshTimeline(use_30hz_timing) then
                TheLog.ch.StateGraph:printf("  Refreshed frame events in state %s", state.name)
            end
        end
        use_30hz_timing = not use_30hz_timing
        TheLog.ch.StateGraph:printf("Refreshing player frame events complete")
    end
end

function d_chaos()
    c_godmode()
    for x = -5, 5 do
        for y = -5, 5 do
            local inst = c_spawn("trap_bomb_pinecone")
            inst.Transform:SetPosition(x * 3, 0, y * 3)
            local inst = c_spawn("cabbageroll")
            inst.Transform:SetPosition(x * 3, 0, y * 3)
        end
    end
end

function d_slide(on_done)
    local flags = nil
--      TheGame:FE():FadeTransition( function()
    local on_done = function()
                print("done with slideshow!")
            end
    --function FrontEnd:Fade(in_or_out, time_to_take, cb, fade_delay_time, delayovercb, fadeType)

    TheFrontEnd:Fade(FADE_OUT, 0.5, function()
                    local SlideshowScreen = require "screens.slideshowscreen"
                    TheFrontEnd:PushScreen( SlideshowScreen( "rotwood_intro", on_done, flags) )
                    TheFrontEnd:Fade(FADE_IN, 0.5)
                      end)
end

local function load_mystery(mystery_type, mystery_name, world, force_reload)
    local mapgen = require "defs.mapgen"
    assert(mapgen.roomtypes.Trivial:Contains(mystery_type), "Not a valid mystery roomtype.")

    if not mystery_name or mystery_name:len() == 0 then
        TheLog.ch.Mystery:printf("Cleared the saved %s event.", mystery_type)
        TheSaveSystem.cheats:SetValue("forced_mystery", nil)
            :Save()
        return
    end

    local matches_mystery = TheSaveSystem.cheats:GetValue("forced_mystery") == mystery_name
    TheSaveSystem.cheats:SetValue("forced_mystery", mystery_name)
        :Save(function()
            if not force_reload and matches_mystery and TheWorld and TheWorld.prefab == world then
                TheLog.ch.Mystery:printf("We should be playing mystery '%s'", mystery_name)
            else
                TheLog.ch.Mystery:printf("Debug loading into mystery room '%s' for mystery '%s'.", world, mystery_name)
                get_worldmap_safe():Debug_StartArena(world,
                    {
                        difficulty = mapgen.Difficulty.id.easy,
                        roomtype = mystery_type,
                        is_terminal = false, -- terminal suppresses resource rooms
                    })
            end
        end)
end

-- Call d_minigame("dps_check") to test that minigame.
-- Call d_minigame() to stop testing.
function d_minigame(minigame, world, force_reload)
    world = world or "startingforest_large_ew"
    load_mystery("ranger", minigame, world, force_reload)
end

-- Call d_minigamestart() when in a minigameroom to force start the minigame, rather than having to talk to the NPC.
function d_minigamestart()
    for k,v in pairs(Ents) do
        if v.prefab == "npc_specialeventhost" then
            -- jambell: Gross temporary way of doing this for now, until specialeventroommanager is registered on TheWorld
            v.specialeventroommanager.components.specialeventroommanager:StartCountdown(ConsoleCommandPlayer())
            break
        end
    end
end

--[[
TODO(jambell): make one function that loads a minigame and starts into it immediately. notes from dbriscoe:

Use cheats to pass cheat data between instances:

    ----------
    TheSaveSystem.cheats:SetValue("mystery_autostart", true)
        :Save()
    ----------
    local mystery_autostart = TheSaveSystem.cheats:GetValue("mystery_autostart")
    ----------

those cheats are wiped on game startup but preserved between lua sim restarts.

you won't be able to make it generic for Debug_StartArena (no functions in there either), but you can set flags as you please.
]]

-- Call d_wanderer("free_power") to test that wanderer convo.
-- Call d_wanderer() to stop testing.
function d_wanderer(conversation, world, force_reload)
    world = world or "startingforest_small_ew"
    load_mystery("wanderer", conversation, world, force_reload)
end


function d_test_pointinenemy()
    local player = GetDebugPlayer()
    if player then
        local seconds = 3
        local thick = 1
        local dodamage = function(source, attack)
            local victim = attack:GetTarget()
            local pt = player:GetPosition():lerp(victim:GetPosition(), 0.5)
            local c = victim.Physics:IsPointInBody(pt:unpack()) and WEBCOLORS.CYAN or WEBCOLORS.RED
            DebugDraw.GroundPoint(pt, nil, 1, c, thick, seconds)
        end
        d_listen_for_event(player, "do_damage", dodamage)
    end
end

function d_draw_world_space_bounds()
    local seconds = 0.5
    local thick = 4
    DEBUG_CACHE.tasks.world_space_bounds = TheWorld:DoPeriodicTask(seconds, function(_)
        local arena = TheWorld.map_layout:GetWorldspaceBounds()
        DebugDraw.GroundRect(arena.min.x, arena.min.y, arena.max.x, arena.max.y, WEBCOLORS.DEEPPINK, thick, seconds)
    end)
end

function d_updateparticles()
    local DataDumper = require "util.datadumper"
    local filepath = require("util/filepath")
    local files = {}
    filepath.list_files("scripts/map/propdata", "*.lua", false, files)
    for i = 1, #files do
        local fname = files[i]
        local s = TheSim:DevLoadDataFile(fname)
        local fn, err = load(s)
        local data = fn()
        print("Data:",data)
        local replacements
        for i,v in pairs(data) do
            if i == "particlesystem_prop" then
                for i,v in pairs(v) do
                    print("",i,v)
                    -- one particlesystem_prop
                    local x
                    local y
                    local z
                    local param_id
                    local layer
                    local snaptogrid
                    for i,v in pairs(v) do
                        --print("","",i,v)
                        if i == "x" then
                            x = v
                        elseif i == "y" then
                            y = v
                        elseif i == "z" then
                            z = v
                        elseif i == "param_id" then
                            param_id = v
                        elseif i == "layer" then
                            layer = v
                        elseif i == "snaptogrid" then
                            snaptogrid = v
                        else
                            assert(false, "UNKNOWN PARAMETER:"..i)
                        end
                    end
                    if param_id and param_id ~= "" then
                        replacements = replacements or {}
                        replacements[#replacements+1] = { param_id = param_id, x = x, y = y, z = z, layer = layer, snaptogrid = snaptogrid }
                    end
                end
            end
        end
        if replacements then
            print("NEED TO REPLACE!")
            data.particlesystem_prop = nil
            for i,v in pairs(replacements) do
                data[v.param_id] = data[v.param_id] or {}
                table.insert(data[v.param_id], { x = v.x, y = v.y, z = v.z, layer = v.layer, snaptogrid = v.snaptogrid })
            end
        end
        TheSim:DevSaveDataFile(fname, DataDumper(data, nil, false))
    end
end

-- Just here to test parented, follow orientation, follow symbol on spawned effects
function d_orientation_test()
    local events = require "eventfuncs"
    local function SpawnEffect(inst, param)
        inst:DoTaskInTime(0.4, function()
            local testfx = c_spawn(param.fxname)
            local followsymbol = param.followsymbol

            if testfx ~= nil then
                if param.ischild then
                    testfx.entity:SetParent(inst.entity)
                    testfx.entity:AddFollower()

                    if inst.components.hitstopper ~= nil then
                        inst.components.hitstopper:AttachChild(testfx)
                    end

                    if followsymbol then
                        testfx.Follower:FollowSymbol(
                            inst.GUID,
                            followsymbol,
                            param.offx or 0,
                            param.offy or 0,
                            param.offz or 0
                        )
                        if not param.inheritrotation then
                            testfx.AnimState:SetUseOwnRotation()
                        end
                    else
                        testfx.Transform:SetPosition(param.offx or 0, param.offy or 0, param.offz or 0)
                        if param.inheritrotation then
                            local dir = inst.Transform:GetFacingRotation()
                            testfx.Transform:SetRotation(dir)
                        end
                    end

                    if param.detachatexitstate then
                        inst.sg.mem.autogen_detachentities = inst.sg.mem.autogen_detachentities or {}
                        inst.sg.mem.autogen_detachentities[testfx] = true
                        testfx:ListenForEvent("onremove", function()
                            RemoveEntityFromExitStateList(inst, testfx, "autogen_detachentities")
                        end)
                    end
                else
                    local offx = param.offx or 0
                    local offy = param.offy or 0
                    local offz = param.offz or 0

                    if followsymbol then
                        local x, y, z = inst.AnimState:GetSymbolPosition(followsymbol, offx, offy, offz)
                        testfx.Transform:SetPosition(x, y, z)
                        if param.inheritrotation then
                            local dir = inst.Transform:GetFacingRotation()
                            testfx.Transform:SetRotation(dir)
                        else
                            testfx.AnimState:SetUseOwnRotation(true)
                        end
                    else
                        local x, y, z = inst.Transform:GetWorldPosition()
                        local offdir = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
                        testfx.Transform:SetPosition(x + offdir * offx, y + offy, z + offdir * offz)
                        if param.inheritrotation then
                            local dir = inst.Transform:GetFacingRotation()
                            testfx.Transform:SetRotation(dir)
                        end
                    end
                end
                testfx.AnimState:SetScale(param.scalex or 1, param.scalez or 1)

                if param.stopatexitstate then
                    StopFxOnStateExit(inst, testfx)
                end
            end
            return testfx
        end)
    end

    local function SpawnYammos(val)
        local x = val % 2 == 0 and -10 or 5
        local y = 12 - math.floor(val / 2) * 8

        local parented = val & 1 ~= 0
        local symbol = val & 2 ~= 0
        local orientation = val & 4 ~= 0

        print(val,x,y, parented, symbol, orientation)

        local param =
        {
            fxname = "arrow_test_right",
--              followsymbol = symbol and "body",
            followsymbol = symbol and "face",
            ischild = parented,
            inheritrotation = orientation,
            offx = symbol and 100 or 3,
        }

        local ent = c_spawn("yammo")
--          ent:SetBrain()
--          ent:SetStateGraph()
        ent.Transform:SetPosition(x,0,y)
        -- flip this one
        ent:SnapToFacingRotation()
        local rot = ent.Transform:GetRotation()
        ent.Transform:SetRotation(rot + 180)

        SpawnEffect(ent, param)

        local ent = c_spawn("yammo")
--          ent:SetBrain()
--          ent:SetStateGraph()
        ent.Transform:SetPosition(x + 5,0,y)
        -- and nuke the sg
--          ent:DoTaskInTime(0.2, function() ent.sg.GoToState = function() end ent:SetBrain() end)
        SpawnEffect(ent, param)
    end

    SpawnYammos(7)
end

function d_set_equipped_ilvl(num)
    local SLOTS =
    {
        "WEAPON",
        "HEAD",
        "BODY",
        "SHOULDERS",
        "ARMS",
        "WAIST",
        "LEGS",
    }
    for _,p in ipairs(AllPlayers) do
        local inventoryhoard = p.components.inventoryhoard
        for i, slot in ipairs(SLOTS) do
            local item = inventoryhoard:GetEquippedItem(slot)
            if item then
                item:SetItemLevel(num)
            end
        end
    end
end

function d_refreshgear()
    for _,p in ipairs(AllPlayers) do
        p.components.inventoryhoard:RefreshItemStats()
    end
end

function d_draw_snap_grid()
    TheWorld.components.snapgrid:SetDrawGridEnabled(true)
    for _, entity in pairs(Ents) do
        if entity.components.snaptogrid then
            entity.components.snaptogrid:SetDrawGridEnabled(true)
        end
    end
end

function d_runmaterials(runs, regular_drops, epic_drops)
    runs = runs or 1

    for i=1,runs do
        for _, drop in ipairs(regular_drops) do
            c_give("MATERIALS", drop, math.random(1, 4))
        end

        if math.random() > 0.9 then
            local epic_drop = epic_drops[math.random(1, #epic_drops)]
            c_give("MATERIALS", epic_drop)
        end

        c_lessersoul()
    end
end

function d_treeforestmaterials(runs)

    local regular_drops = {
        "cabbageroll_skin",
        "blarmadillo_hide",
        "treemon_arm",
        "yammo_skin",
        "zucco_skin",
        "gourdo_hat"
    }

    local epic_drops = {
        "cabbageroll_baby",
        "blarmadillo_trunk",
        "treemon_cone",
        "yammo_stem",
        "zucco_claw",
        "gourdo_skin",
    }

    d_runmaterials(runs, regular_drops, epic_drops)
end

function d_owlforestmaterials(runs)
    local regular_drops = {
    }

    local epic_drops = {
    }
    -- d_runmaterials(runs, regular_drops, epic_drops)
end

function d_bandiswampmaterials(runs)
    local regular_drops = {}
    local epic_drops = {}
    -- d_runmaterials(runs, regular_drops, epic_drops)
end

function d_advanceruns(runs, region, progress, victory)
    for i=1, runs do
        d_metaprogressrun(region, progress, victory)
    end
end

function d_metaprogressrun(region, progress, victory)
    region = region or "forest"
    progress = progress or 1
    if victory == nil then
        victory = true
    end

    TheDungeon.progression.components.runmanager:Debug_PushProgress(region, progress, victory)
end

function d_quickstart(checkpoint)
    if checkpoint == "create_menu" then
        -- The menu for debugkeys. Here to easily keep the labels in sync.
        return {
            {
                name = "(1) Mother Treek/Killed Miniboss",
                fn = function()
                d_quickstart(1)
                end,
            },

            {
                name = "(2) Mother Treek/Killed Boss",
                fn = function()
                d_quickstart(2)
                end,
            },

            {
                name = "(3) Owlitzer/Killed Miniboss",
                fn = function()
                d_quickstart(3)
                end,
            },

            {
                name = "(4) Owlitzer/Killed Boss",
                fn = function()
                d_quickstart(4)
                end,
            },

            {
                name = "(5) Swamp/Killed Miniboss",
                fn = function()
                d_quickstart(5)
                end,
            },

            {
                name = "(6) Swamp/Killed Boss (cook)",
                fn = function()
                d_quickstart(6)
                end,
            },
        }
    end
    if not TheWorld:HasTag("town") then
        print ("CAN'T USE THAT CHEAT IN DUNGEON")
        return
    end

    kassert.typeof("number", checkpoint)

    local function RefreshNPCs()
        local plots = TheWorld.components.plotmanager.plots
        for npc, plot in pairs(plots) do
            plot.inst.components.plot:OnPostLoadWorld()
        end
    end

    local function TryComplete(quest_id, obj_id)
        playerutil.DoForAllLocalPlayers(function(player)
            local qm = player.components.questcentral:GetQuestManager()
            local quest = qm:FindQuestByID(quest_id)
            if quest and not quest:IsComplete() then
                quest:Complete(obj_id)
            end
        end)
    end

    local function TrySpawnHousedNpc(npc_prefab)
        local npc_found = c_find(npc_prefab)
        local home = npc_found and npc_found.components.npc:GetHome()
        if home and home:HasTag("spawner_npc") then
            -- Remove them if unhoused.
            npc_found:Remove()
        end

        c_spawnnpc(npc_prefab)
    end


    local checkpoints = {

        -- Beat Treemon Forest Miniboss
        -- Get Armorsmith
        function() -- 1
            d_treeforestmaterials()
            d_advanceruns(10)
            TryComplete("main_defeat_megatreemon", "quest_intro")
            TryComplete("main_defeat_megatreemon", "find_target_miniboss")
            TryComplete("main_defeat_megatreemon", "defeat_target_miniboss")
            TryComplete("intro_meeting_armorsmith")
            TryComplete("twn_unlock_polearm")

            TheWorld:UnlockFlag("wf_seen_room_bonus")

            playerutil.DoForAllLocalPlayers(function(player)
            player.components.unlocktracker:UnlockEnemy("cabbageroll")
            player.components.unlocktracker:UnlockRecipe("cabbageroll")

            player.components.unlocktracker:UnlockEnemy("blarmadillo")
            player.components.unlocktracker:UnlockRecipe("blarmadillo")

            player.components.unlocktracker:UnlockEnemy("beets")
            player.components.unlocktracker:UnlockRecipe("beets")

            player.components.unlocktracker:UnlockEnemy("zucco")
            player.components.unlocktracker:UnlockRecipe("zucco")

            player.components.unlocktracker:UnlockEnemy("yammo")
            player.components.unlocktracker:UnlockRecipe("yammo")

            player.components.unlocktracker:UnlockWeaponType(WEAPON_TYPES.POLEARM)
            player.components.unlocktracker:UnlockRecipe("polearm_basic")
            player.components.unlocktracker:UnlockRecipe("polearm_startingforest")
            player.components.inventoryhoard:Debug_GiveItem("WEAPON", "polearm_basic", 1, true)
            end)
        end,

        -- Beat Treemon Forest boss
        -- Unlock Owl Forest
        function() -- 2
            TryComplete("main_defeat_megatreemon")
            TryComplete("main_defeat_owlitzer", "quest_intro")
            d_advanceruns(10)
            c_konjurheart("megatreemon")
            d_treeforestmaterials()

            TheDungeon.progression.components.ascensionmanager:DEBUG_UnlockAscension("treemon_forest", 1)

            playerutil.DoForAllLocalPlayers(function(player)
            player.components.unlocktracker:UnlockEnemy("megatreemon")
            end)
        end,

        -- Beat Owl Forest Miniboss
        -- Get Cook
        function() -- 3
            d_owlforestmaterials()
            d_advanceruns(10)
            TryComplete("main_defeat_owlitzer", "find_target_miniboss")
            TryComplete("main_defeat_owlitzer", "defeat_target_miniboss")
            TryComplete("intro_meeting_cook")

            playerutil.DoForAllLocalPlayers(function(player)
            player.components.unlocktracker:UnlockEnemy("gnarlic")
            player.components.unlocktracker:UnlockRecipe("gnarlic")

            player.components.unlocktracker:UnlockEnemy("windmon")
            player.components.unlocktracker:UnlockRecipe("windmon")

            player.components.unlocktracker:UnlockEnemy("gourdo")
            player.components.unlocktracker:UnlockRecipe("gourdo")

            player.components.unlocktracker:UnlockEnemy("battoad")
            player.components.unlocktracker:UnlockRecipe("battoad")

            end)
        end,

        -- Beat Owl Forest Boss
        -- Invite Hamish to Town
        -- Unlock Bandi Swamp
        function() -- 4
            TryComplete("main_defeat_owlitzer")
            TryComplete("intro_meeting_blacksmith", "meet_in_dungeon")
            d_advanceruns(10)
            c_konjurheart("owlitzer")
            d_owlforestmaterials()

            TheDungeon.progression.components.ascensionmanager:DEBUG_UnlockAscension("owlitzer_forest", 1)

            playerutil.DoForAllLocalPlayers(function(player)
            player.components.unlocktracker:UnlockEnemy("owltizer")
            end)
        end,

        -- Beat Swamp Miniboss
        -- Fully unlock Hamish
        function() -- 5
            d_bandiswampmaterials()
            d_advanceruns(10)
            TryComplete("main_defeat_bandicoot", "quest_intro")
            TryComplete("main_defeat_bandicoot", "find_target_miniboss")
            TryComplete("main_defeat_bandicoot", "defeat_target_miniboss")
            TryComplete("intro_meeting_blacksmith")

            playerutil.DoForAllLocalPlayers(function(player)
            player.components.unlocktracker:UnlockEnemy("mothball")
            player.components.unlocktracker:UnlockRecipe("mothball")

            player.components.unlocktracker:UnlockEnemy("mothball_teen")
            player.components.unlocktracker:UnlockRecipe("mothball_teen")

            player.components.unlocktracker:UnlockEnemy("mothball_spawner")
            player.components.unlocktracker:UnlockRecipe("mothball_spawner")

            player.components.unlocktracker:UnlockEnemy("bulbug")
            player.components.unlocktracker:UnlockRecipe("bulbug")

            player.components.unlocktracker:UnlockEnemy("mossquito")
            player.components.unlocktracker:UnlockRecipe("mossquito")

            player.components.unlocktracker:UnlockEnemy("eyev")
            player.components.unlocktracker:UnlockRecipe("eyev")

            player.components.unlocktracker:UnlockEnemy("sporemon")
            player.components.unlocktracker:UnlockRecipe("sporemon")

            player.components.unlocktracker:UnlockEnemy("groak")
            player.components.unlocktracker:UnlockRecipe("groak")

            end)
        end,

        -- Beat Bandi Swamp Boss
        function() -- 6
            TryComplete("main_defeat_bandicoot")
            d_advanceruns(10)
            c_konjurheart("bandicoot")
            d_bandiswampmaterials()

            TheDungeon.progression.components.ascensionmanager:DEBUG_UnlockAscension("kanft_swamp", 1)

            playerutil.DoForAllLocalPlayers(function(player)
            player.components.unlocktracker:UnlockEnemy("bandicoot")
            end)
        end,

        -- -- Unlock all dungeon 1 armor, unlock 3 ascensions, advance 5 runs in dungeon two, unlock shotput, give some d2 resources
        -- function() -- 7
        --     d_advanceruns(5, "swamp")

        --     c_give("BODY", "zucco",       nil, true)
        --     c_give("BODY", "yammo",       nil, true)
        --     c_give("BODY", "megatreemon", nil, true)

        --     c_give("HEAD", "cabbageroll", nil, true)
        --     c_give("HEAD", "zucco",       nil, true)
        --     c_give("HEAD", "yammo",       nil, true)
        --     c_give("HEAD", "blarmadillo", nil, true)
        --     c_give("HEAD", "megatreemon", nil, true)

        --     c_give("WEAPON", "hammer_startingforest",  nil, true)
        --     c_give("WEAPON", "hammer_startingforest2", nil, true)
        --     c_give("WEAPON", "hammer_megatreemon",     nil, true)

        --     c_give("WEAPON", "polearm_startingforest",  nil, true)
        --     c_give("WEAPON", "polearm_startingforest2", nil, true)
        --     c_give("WEAPON", "polearm_megatreemon",     nil, true)

        --     TheDungeon.progression.components.ascensionmanager:DEBUG_UnlockAscension("treemon_forest", 3)

        --     d_forestmaterials()
        -- end,

    }

    for i=1,checkpoint do
        checkpoints[i]()
        RefreshNPCs()
    end
end

function d_export_all_editors()
    local function export(catdef)
        local catname = catdef[1]
        local editorname = catdef[2]
        local cateditor = DebugNodes[editorname]
        local editor = cateditor:FindOrCreateEditor()
        editor.static.dirty = true
        editor:Save(true)
        -- create our autogen file
        local fname = "scripts/prefabs/"..catname.."_autogen_data.lua"
        local contents = string.format(
        [[
-- Note - this assumes the directory autogen/<category> exists, so if you ever clone this file, make sure to modify category and add its directory
local category = "%s"

local prefabutil = require "prefabs.prefabutil"
return prefabutil.LoadAutogenDefs(category)

]], catname)
        --print("fname:",fname)
        --print("contents:",contents)
        TheSim:DevSaveDataFile(fname, contents)
    end
    local exports = {
                {"animtag","AnimTagger"},
                {"animtest", "AnimTester"},
                {"particles", "ParticleEditor"},
                {"world", "WorldEditor"},
                {"stategraph", "Embellisher"},
                {"scenegen", "SceneGenEditor"},
                {"cine","CineEditor"},
                {"curve","CurveEditor"},
                {"drops","DropEditor"},
                {"fx","FxEditor"},
                {"mappath","MapPathEditor"},
                {"npc","NpcEditor"},
                {"prop","PropEditor"},
            }
    for i,v in pairs(exports) do
        export(v)
    end
    --export(DebugNodes.ParticleEditor)
    --export(DebugNodes.WorldEditor)
    --export(DebugNodes.AnimTagger)
    --export(DebugNodes.Embellisher)
    --export(DebugNodes.SceneGenEditor)
end

function d_settitle(titleid)
    local player = GetDebugPlayer()
    if player then
        local Cosmetics = require "defs.cosmetics.cosmetics"
        if titleid then
            player.components.playertitleholder:SetTitle(Cosmetics.Items["PLAYER_TITLE"][titleid])
        else
            player.components.playertitleholder:ClearTitle()
        end
    end
end

function d_unlock_ascension(location_id, num)
    TheDungeon.progression.components.ascensionmanager:SetHighestCompletedAscension(location_id, num)
end

function d_testhitfx(fx_name, offset_x, offset_y)
    local player = GetDebugPlayer()
    if player then
        SpawnHitFx(fx_name, player, player, offset_x or 0, offset_y or 0, nil, HitStopLevel.MINOR)
    end
end

-- function d_printcosmetics()
--      local Cosmetics = require "defs.cosmetics.cosmetics"
--      for k,v in pairs(Cosmetics.Items["PLAYER_TITLE"]) do
--          print (k,v)
--      end
-- end

function d_test_radius(radius)
    local time = 5
    DebugDraw.GroundCircle(0, 0, radius or 1, nil, 1, time)
    local fx = SpawnPrefab("fx_radius_test")
    fx.AnimState:SetScale(radius or 1, radius or 1)
    TheWorld:DoTaskInTime(time, function()
        if fx ~= nil and fx:IsValid() then
            fx:Remove()
        end
    end)
end

function d_nextbossphase()
    local ents = TheSim:FindEntitiesXZ(0, 0, 1000, { "boss" })
    local boss = ents and ents[1] or nil

    if boss then
        local current_phase = boss.boss_coro:CurrentPhase()
        boss.boss_coro:SetPhase(current_phase + 1)
        print("Boss Phase set to", current_phase + 1)
    end
end


-- Cancels d_papercut() use (see below)
function d_papercut_cancel()
    local player = GetDebugPlayer()
    if player and player.papercut_task then
        player.papercut_task:Cancel()
        player.papercut_task = nil
        player.papercut_count = nil
    end
end

-- Deal player combat damage to a target entity periodically for a set number of times
-- Cancel this with d_papercut_cancel()
--
-- count: times to inflict damage (defaults to a thousand)
-- damage: defaults to 5; is affected by player damage scaling (i.e. baby mode, god mode, etc.)
-- period: repetition period in time, defaults to 10 ticks, or once every ~167ms
-- ent: target to inflict damage (defaults to debug entity)
function d_papercut(count, damage, period, ent)
    count = count or 1000
    damage = damage or 5
    period = period or TICKS * 10
    ent = ent or GetDebugEntity()

    local player = GetDebugPlayer()
    if not player or not ent or count <= 0 or damage < 1 then
        return
    end

    d_papercut_cancel()

    if ent and ent.components.combat and count > 0 then
        player.papercut_count = count
        player.papercut_task = player:DoPeriodicTask(period, function(_player)
            if not ent:IsValid() or ent:IsInLimbo() or ent:IsDead() then
                d_papercut_cancel()
                return
            end

            local attack = Attack(player, ent)
            attack:SetOverrideDamage(damage)
            attack:SetIgnoresArmour(true)
            attack:SetSkipPowerDamageModifiers(true)
            attack:SetDir(player:GetAngleTo(ent))
            attack:SetPushback(0)
            player.components.combat:DoBasicAttack(attack)

            if player.papercut_count then
                player.papercut_count = player.papercut_count - 1
                if player.papercut_count <= 0 then
                    d_papercut_cancel()
                end
            else
                d_papercut_cancel()
            end
        end)
    end
end

function d_unlock_all_cosmetics()
    local Cosmetics = require "defs.cosmetics.cosmetics"
    for group, items in pairs(Cosmetics.Items) do
        for name, item in pairs(items) do
            ThePlayer.components.unlocktracker:UnlockCosmetic(name, group)
        end
    end
end

function d_purchase_all_cosmetics()
    d_unlock_all_cosmetics()

    local Cosmetics = require "defs.cosmetics.cosmetics"
    for group, items in pairs(Cosmetics.Items) do
        for name, item in pairs(items) do
            ThePlayer.components.unlocktracker:PurchaseCosmetic(name, group)
        end
    end
end

-- Slightly misleading name, we're only unpurchasing the ones that are not purchased by default
function d_unpurchase_all_cosmetics()
    local Cosmetics = require "defs.cosmetics.cosmetics"
    for group, items in pairs(Cosmetics.Items) do
        for name, item in pairs(items) do
            if not item.purchased then
                ThePlayer.components.unlocktracker:UnpurchaseCosmetic(name, group)
            end
        end
    end
end

-- Same as the function above, we're only locking the cosmetics not unlocked by default
function d_lock_all_cosmetics()
    d_unpurchase_all_cosmetics()

    local Cosmetics = require "defs.cosmetics.cosmetics"
    for group, items in pairs(Cosmetics.Items) do
        for name, item in pairs(items) do
            if item.locked then
                ThePlayer.components.unlocktracker:LockCosmetic(name, group)
            end
        end
    end
end

function d_market_mannequins()
    TheSim:LoadPrefabs({"meta_item_shop"})

    TheDungeon:GetDungeonMap().shopmanager:PROTO_CreateMannequins("treemon_forest", TheDungeon:GetDungeonMap().rng)
end

function d_test_powerdrops()
    local powerdropmanager = TheWorld.components.powerdropmanager
    local Power = require "defs.powers"

    local function MakePower(x, z)
        local power = powerdropmanager:GetPowerForMarket(Power.Types.RELIC, Power.Rarity.EPIC, true)
		dbassert(power)
        local poweritem = SpawnPrefab("proto_power_item", TheWorld)
        poweritem.components.poweritem:SetPower(power.name)
        poweritem.components.interactable:SetRadius(1)
        poweritem.Transform:SetPosition(0 + x, 0, z)
    end

    local distance_back = 4
    local distance_front = 3

    local x_offset = -5
    for i=1,2 do
        MakePower(-10 + x_offset, 10)
        x_offset = x_offset + distance_back
    end

    local x_offset = -5
    for i=1,2 do
        MakePower(10 + x_offset, 10)
        x_offset = x_offset + distance_back
    end

    local x_offset = -5
    for i=1,2 do
        MakePower(-7 + x_offset, -10)
        x_offset = x_offset + distance_front
    end

    local x_offset = -5
    for i=1,2 do
        MakePower(7 + x_offset, -10)
        x_offset = x_offset + distance_front
    end
end

function d_fill_markets()
    if not TheWorld or TheWorld:HasTag("town") then
        return
    end
    local world_map = TheDungeon:GetDungeonMap()
    world_map.shopmanager:FillMarkets(krandom.CreateGenerator())
    TheSaveSystem.dungeon:SetValue("worldmap", world_map:GetMapData())
    TheSaveSystem:SaveAll()
end

function d_weight_light()
    local Weight = require "components/weight"
    local player = (c_sel() ~= nil and c_sel():HasTag("player") and c_sel()) or GetDebugPlayer() or AllPlayers[1]
    player.components.weight:SetDebugStatus(Weight.Status.s.Light)
end

function d_weight_normal()
    local Weight = require "components/weight"
    local player = (c_sel() ~= nil and c_sel():HasTag("player") and c_sel()) or GetDebugPlayer() or AllPlayers[1]
    player.components.weight:SetDebugStatus(Weight.Status.s.Normal)
end

function d_weight_heavy()
    local Weight = require "components/weight"
    local player = (c_sel() ~= nil and c_sel():HasTag("player") and c_sel()) or GetDebugPlayer() or AllPlayers[1]
    player.components.weight:SetDebugStatus(Weight.Status.s.Heavy)
end

function d_weight_clear()
    local player = (c_sel() ~= nil and c_sel():HasTag("player") and c_sel()) or GetDebugPlayer() or AllPlayers[1]
    player.components.weight:ClearDebugStatus()
end

function d_charscreen(debug_mode)
    local CharacterScreen = require ("screens.character.characterscreen")
    TheFrontEnd:PushScreen(CharacterScreen(ThePlayer, nil, nil, debug_mode))
end

function d_symboltest()
    local inst = c_spawn("run_item_shop")


    local border_build = "images/shop_anim_icon_borders.xml"

    -- border_front, border_back, icon, item
    local border_back_symbol = "border_back"
    local border_front_symbol = "border_front"
    local icon_symbol = "icon"
    local item_symbol = "item"


    local powerups = {
                {"images/ui_ftf_skill_icons1.xml", "icon_skillpowers_hammer_totem.tex"},
                {"images/ui_ftf_food_icons1.xml", "icon_food_powers_thick_skin.tex"},
            }
    local colors = {
        { 1, 0, 0, 1},
        { 1, 1, 0, 1},
        { 1, 0, 1, 1},
        { 0.5, 0.5, 0.8, 1},
        }
    local index = 0

    local function OverrideSymbol(inst, symbol, build, override_symbol)
        inst.AnimState:OverrideSymbol(symbol, build, override_symbol)
        if inst.highlightchildren ~= nil then
            for i = 1, #inst.highlightchildren do
                local child = inst.highlightchildren[i]
                child.AnimState:OverrideSymbol(symbol, build, override_symbol)
            end
        end
    end

    local function OverrideSymbolMultColor(inst, symbol, r, g, b, a)
        inst.AnimState:SetSymbolMultColor(symbol, r, g, b, a)
        if inst.highlightchildren ~= nil then
            for i = 1, #inst.highlightchildren do
                local child = inst.highlightchildren[i]
                child.AnimState:SetSymbolMultColor(symbol, r,g,b,a )
            end
        end
    end

    local function HideSymbol(inst, symbol)
        inst.AnimState:HideSymbol(symbol)
        if inst.highlightchildren ~= nil then
            for i = 1, #inst.highlightchildren do
                local child = inst.highlightchildren[i]
                child.AnimState:HideSymbol(symbol)
            end
        end
    end

    -- frame overtop icon
    --local borderToUse = border_front_symbol
    --local override_symbol = "epic_food.tex"

    -- frame behind icon
    local borderToUse = border_back_symbol
    local override_symbol = "epic_skill.tex"

    OverrideSymbol( inst, borderToUse, border_build, override_symbol)
    HideSymbol(inst, borderToUse == border_back_symbol and border_front_symbol or border_back_symbol)

    TheWorld:DoPeriodicTask(1, function()
        local work = index % #powerups
        local powerup = powerups[work+1]
        local build = powerup[1]


        local override_symbol = powerup[2]
        local color = {math.random(1000)/1000, math.random(1000)/1000, math.random(1)/1000, 1}

        OverrideSymbol(inst, icon_symbol, build, override_symbol)
        OverrideSymbolMultColor(inst, icon_symbol, table.unpack(color))
        HideSymbol(inst, item_symbol)

        index = index + 1
    end)
end

function d_zombietest(stagger_ticks)
    local offsets =
    {
        { -3, 0, 0 },
        { 3, 0, 0 },
        { 0, 0, 2 },
        { 0, 0, -2 },

    }
    local num_monsters = 2

    for _, target in ipairs(AllPlayers) do
        if target:IsLocal() then
            target.components.health:SetCurrent(1)
        end
        local pos = target:GetPosition()
        local delayticks = 0

        for i = 1, num_monsters do
            local inst = DebugSpawn("cabbageroll_elite")
            inst:Stupify("d_zombietest")

            inst.Transform:SetPosition(pos.x + offsets[i][1], pos.y + offsets[i][2], pos.z + offsets[i][3])
            local SGCommon = require "stategraphs.sg_common"
            SGCommon.Fns.FaceTarget(inst, target, true)
            inst:DoTaskInTicks(delayticks, function()
                inst.sg:GoToState("bite_pre")
                inst:DoTaskInTime(3, function() inst:DelayedRemove() end)
            end)
            delayticks = delayticks + (stagger_ticks or 0)
        end
    end
end

function d_unlock_all_dyes(purchase)
    local Cosmetics = require "defs.cosmetics.cosmetics"
    for slot, sets in pairs(Cosmetics.EquipmentDyes) do
        for set, defs in pairs(sets) do
            for name, def in pairs(defs) do
                ThePlayer.components.unlocktracker:UnlockCosmetic(def.armour_slot, def.short_name)
                if purchase then
                    ThePlayer.components.unlocktracker:PurchaseCosmetic(def.armour_slot, def.short_name)
                end
            end
        end
    end 
end
