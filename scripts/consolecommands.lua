local DebugNodes = require "dbui.debug_nodes"
local iterator = require "util.iterator"
local kstring = require "util.kstring"
local lume = require "util.lume"
local playerutil = require "util.playerutil"
local Consumable = require "defs.consumable"
require "util.tableutil"


-- not local - debugkeys use it too
function ConsoleCommandPlayer()
    return (c_sel() ~= nil and c_sel():HasTag("player") and c_sel()) or GetDebugPlayer() or AllPlayers[1]
end

function ConsoleWorldPosition()
    return TheInput:GetWorldPosition()
end

function ConsoleWorldEntityUnderMouse()
    return TheInput:GetWorldEntityUnderMouse()
end

local function ListingOrConsolePlayer(input)
    if type(input) == "string" or type(input) == "number" then
        return UserToPlayer(input)
    end
    return input or ConsoleCommandPlayer()
end

---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------
-- Console Functions -- These are simple helpers made to be typed at the console.
---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------

local function _stopsounds()
	-- When debug resetting, clear sounds to prevent bleed over (especially
	-- for errors that force us to main menu).
	TheAudio:StopAllSounds()
	if TheInput:IsEditMode() then
		local panel = TheFrontEnd:FindOpenDebugPanel(DebugNodes.EditableEditor)
		if panel then
			local node = panel:GetNode()
			node:OnDebugResetGame()
		end
	end
end

-- Restart the server to the last save file
function c_reset()
	if TheNet:IsInGame() then
		if TheNet:IsHost() then
			TheNet:DoWorldReset()
			_stopsounds()
		else
			-- Do nothing! Can't press Ctrl-R as a client
			print("Can't CTRL-R as a client!")
		end
	else
		-- If there was a lua crash on a client, it will populate the reconnect settings with the information needed to
		-- re-join the game that they were just in.
		local reconnectsettings = TheNet:GetLuaCrashReconnectSettings()
		if reconnectsettings then
			print("Reconnecting using these settings: ")
			dumptable(reconnectsettings)

			_stopsounds()

			StartNextInstance({
					reset_action = RESET_ACTION.JOIN_GAME,
					reconnect_settings = reconnectsettings,
				})	-- This ends up in gamelogic.lua. Search for RESET_ACTION.JOIN_GAME
		else
			StartNextInstance()
		end
	end
end

function c_erasesavedata(cb)
	local _cb = MultiCallback()
	-- Erase progression
	TheSaveSystem:EraseAll(_cb:AddInstance())
	-- And reset saves.
	TheGameSettings:ResetToDefaults()
	TheGameSettings:Save(_cb:AddInstance())
	_cb:WhenAllComplete(cb)
end

function c_save(cb)
	if TheWorld ~= nil then
		local worldmap = TheDungeon:GetDungeonMap()
		if worldmap ~= nil then
			if not worldmap:IsDebugMap() then
				TheSaveSystem:SaveAll(cb)
				return
			elseif TheWorld.components.propmanager ~= nil then
				TheWorld.components.propmanager:SaveAllProps()
				if cb ~= nil then
					cb(true)
				end
				return
			end
		end
	end
	if cb ~= nil then
		cb(false)
	end
end

-- Shutdown the application, optionally close with out saving (saves by default)
function c_shutdown(save)
    print("c_shutdown", save)
    --[[if save == false or TheWorld == nil then
        Shutdown()
    else
        for i, v in ipairs(AllPlayers) do
            v:OnDespawn()
        end
        TheSystemService:EnableStorage(true)
        SaveGameIndex:SaveCurrent(Shutdown, true)
    end]]
    Shutdown()
end

-- Remotely execute a lua string
function c_remote(fnstr)
	local x, z = TheSim:ScreenToWorldXZ(TheInput:GetMousePos())
	TheNet:SendRemoteExecute(fnstr, x, z)
end

-- Spawn At Cursor and select the new ent.
function c_spawn(prefab, count, dontselect)
    assert(prefab)
    count = count or 1
    local inst = nil

    prefab = string.lower(prefab)

	if not DebugNodes.EditableEditor.QuerySpawnable(prefab) then
		return
	end

    for i = 1, count do
        inst = DebugSpawn(prefab)
        assert(inst, "Failed to spawn prefab.")
        if inst.components.skinner ~= nil and IsRestrictedCharacter(prefab) then
            inst.components.skinner:SetSkinMode("normal_skin")
        end
    end
    if not dontselect then
        SetDebugEntity(inst)
    end
    if inst.OnEditorSpawn then
        -- Doing this here instead of inside DebugSpawn so Editors can call
        -- with themselves as argument and you can do debug spawns without
        -- OnEditorSpawn.
        inst:OnEditorSpawn(c_spawn)
    end
    SuUsed("c_spawn_"..prefab, true)
    return inst
end

-- Spawn at cursor, select, and disable brain.
function c_spawndumb(prefab, dontselect)
	local inst = c_spawn(prefab, 1, dontselect)
	inst:Stupify("c_spawndumb")
	return inst
end

function c_spawnstage(monster, num)
	assert(monster)
	if not DebugNodes.EditableEditor.QuerySpawnable(monster) then
		return
	end
	TheSim:LoadPrefabs({ monster })

	num = num or 1
	local waves = require "encounter.waves"
	local sc = TheWorld.components.spawncoordinator
	local testencounter = function(spawner)
		spawner:StartSpawningFromHidingPlaces()
		spawner:SpawnWave(waves.Raw{ [monster] = num })
	end
	sc:StartCustomEncounter(testencounter)
end

-- victorc: hack - local multiplayer, number of local players added this Lua session
function mp_getlocalplayercount()
	local localPlayerCount = 0
	for _,v in ipairs(AllPlayers) do
		if v:IsLocal() then
			localPlayerCount = localPlayerCount + 1
		end
	end
	return localPlayerCount
end

local function CanAddLocalPlayer(input_id)
	if TheNet:IsInGame() then
		if input_id == nil then
			printf("No free input devices.")
			return false
		elseif input_id ~= 0 and not TheInput:IsDeviceFree("gamepad", input_id) then
			printf("Input device %s is not free.", tostring(input_id))
			return false
		end
	end

	return true
end

-- not really mp_-specific but convenient for autocomplete
function mp_listgamepads()
	TheInput:DebugListDevices("gamepad")
end

-- We don't have per-player customization screens yet.
function mp_customizecharacter(player_id)
	local CharacterScreen = require("screens.character.characterscreen")
	local player = AllPlayers[player_id]
	if player then
		TheFrontEnd:PushScreen(CharacterScreen(player))
	end
end


function mp_identifyinputs()
	for i,player in ipairs(AllPlayers) do
		player:DoTaskInTicks((i - 1) * 15, function()
			player:PeekFollowStatus({showPlayerId = true, doInputIdentifier = true})
		end)
	end
end

-- klei_net test API

-- type = local, friends, public, invite
-- "invite" type needs a lobby identifier (online screen join handles this)
function net_startgame(type, param)
	type = type or "local"

	local inputID = 0	-- TODO: requires an inputID for the player that started the game

	if type == "invite" then
		TheNet:StartGame(inputID, type, param)
	else
		TheNet:StartGame(inputID, type)
	end
end

function net_endgame()
	TheNet:EndGame()
end

function net_canaddplayer()
	local input_id = TheInput:FindFreeDeviceID("gamepad")
	if input_id == nil then
		return false, "ERROR_NO_FREE_INPUT_DEVICE"
	end
	if CanAddLocalPlayer(input_id) then
		return true -- Can add player
	else
		return false, "ERROR_NO_AVAILABLE_SLOTS"
	end
end

function net_addplayer(input_id)
	if not CanAddLocalPlayer(input_id) then
		return
	end

	-- response in OnNetworkRequestAddPlayerComplete
	print(debugstack())
	if TheNet:RequestAddPlayer(input_id) then
		TheLog.ch.Networking:print("Request to add player sent to host...")
	else
		TheLog.ch.Networking:print("Request to add player denied.")
	end
end

function net_modifyplayer(player_id, new_input_id)
	TheNet:RequestChangePlayerInputID(player_id, new_input_id)
end

-- player_ids are 0-based and displayed in the bottom right Debug Render.
function net_removeplayer(player_id)
	if player_id then
		local requestSent, id = TheNet:RequestRemovePlayer(player_id)
		if requestSent then
			TheLog.ch.Networking:printf("Request to remove player %s sent to host...", tostring(id))
		elseif id then
			TheLog.ch.Networking:printf("Request to remove player %s denied.", tostring(id))
		else
			TheLog.ch.Networking:printf("Cannot remove unspecified player.")
		end
	else
		TheLog.ch.Networking:printf("Cannot remove unspecified player. Pass the playerID of the player you want to remove.")
	end
end

function c_inputdump()
	TheInput:DebugListDevices("gamepad", true)
end

function c_getnumplayers()
    print(#AllPlayers)
end

function c_getmaxplayers()
    print(TheNet:GetDefaultMaxPlayers())
end

-- Return a listing of currently active players
function c_listnetplayers()
	local players = {}
	for i,p in ipairs(AllPlayers) do
		players[p.Network:GetPlayerID()] = p
	end

	local clients = TheNet:GetClientList() or {}
	for i, v in ipairs(clients) do
		local p = players[v.id]
		v.name = p.name
		v.userid = p.userid
	end
	print(table.inspect(clients, { depth = 5, process = table.inspect.processes.slim, }))
end

-- Return a listing of AllPlayers table
function c_listallplayers()
    for i, v in ipairs(AllPlayers) do
        print(string.format("[%d] (%s) %s <%s>", v:GetHunterId(), v.userid, v.name, v.prefab))
    end
end

-- Get the currently selected entity, so it can be modified etc.
-- Has a gimpy short name so it's easier to type from the console
function c_sel()
    return GetDebugEntity()
end

function c_select(inst)
    if not inst then
        inst = ConsoleWorldEntityUnderMouse()
    end
    if inst and not EntityScript.is_instance(inst) then
        print("Not an entity: "..tostring(inst) )
        return
    end
    print("Selected "..tostring(inst or "<nil>") )
    SetDebugEntity(inst)
    return inst
end

-- See also c_find.
function c_selectprefab(prefabname)
	local current_selection = c_sel()

	local last_guid = 0
	if current_selection ~= nil and current_selection.prefab == prefabname then
		last_guid = current_selection.GUID
	end

	for i = 1, #Ents do
		local guid = i + last_guid
		local ent = circular_index(Ents, guid)
		if ent and ent:IsValid() and ent.prefab == prefabname then
			c_select(ent)
			return ent
		end
	end
	print("Prefab not found:", prefabname)
	c_select(nil)
end

function c_selectany()
	local x, y = TheInput:GetMousePos()
	local ents = TheSim:GetEntitiesAtScreenPoint(x, y, false, false)
	local altents = TheSim:GetEntitiesAtScreenPoint(x, y, false, true)
	-- find the nearest to screen by entity (small z is near cam)
	local smallestZ = math.huge
	local inst
	for i,v in pairs(ents) do
		local x,y,z = v.Transform:GetWorldPosition()
		if z < smallestZ then
			smallestZ = z
			inst = v
		end
	end
	for i,v in pairs(altents) do
		local x,y,z = v.Transform:GetWorldPosition()
		if z < smallestZ then
			smallestZ = z
			inst = v
		end
	end

	print("Selected "..tostring(inst or "<nil>") )
	SetDebugEntity(inst)
	return inst
end

function c_selectany_cycle()
	local x, y = TheInput:GetMousePos()
	local ents = TheSim:GetEntitiesAtScreenPoint(x, y, false, false)
	local altents = TheSim:GetEntitiesAtScreenPoint(x, y, false, true)

	local ent_list = table.appendarrays({}, ents, altents)

	--sort by things that have a brain, player, then by distance from camera
	table.sort(ent_list, function(a, b)
		if not a.brain ~= not b.brain then
			return a.brain
		elseif a:HasTag("player") ~= b:HasTag("player") then
			return a:HasTag("player")
		end

		local _,_,az = a.Transform:GetWorldPosition()
		local _,_,bz = b.Transform:GetWorldPosition()
		return az < bz;
	end)

	local index = 1
	local debug_entity = GetDebugEntity()
	if debug_entity ~= nil then
		-- Find last index to skip dupes (particlesystem_prop).
		for i,v in iterator.ripairs(ent_list) do
			if v == debug_entity then
				-- Found it. Pick one after to cycle. We'll select nil when we
				-- hit the end.
				index = i + 1
				break
			end
		end
	end

	local inst = ent_list[index]

	print("Selected "..tostring(inst or "<nil>") )
	SetDebugEntity(inst)
	return inst
end

local function camera(fov, dist, pitch)
	TheCamera:SetFOV(fov)
	TheCamera:SetDistance(dist)
	TheCamera:SetPitch(pitch)
	TheCamera:Snap()
end

-- Show the world from above so you can see what all the entities are doing.
function c_overheadcam(dist)
	dist = dist or 50
	if TheCamera.__before_mapcam then
		camera(TheCamera.__before_mapcam.fov, TheCamera.__before_mapcam.dist, TheCamera.__before_mapcam.pitch)
		TheFocalPoint:EnableEntityEdgeDetection(TheCamera.__before_mapcam.useplayeredgedetect)
		TheCamera.__before_mapcam = nil
	else
		TheCamera.__before_mapcam =
		{
			fov = TheCamera:GetFOV(),
			dist = TheCamera:GetDistance(),
			pitch = TheCamera:GetPitch(),
			useplayeredgedetect = TheFocalPoint:IsEntityEdgeDetectionEnabled()
		}
		TheFocalPoint:EnableEntityEdgeDetection(false)
		-- Distance 50 keeps all of startingforest_arena in view.
		-- Pitch must be less than 90 or facing won't correctly apply.
		camera(50, dist, 85)
	end
end

function c_showmap()
	TheWorld:StartWallUpdatingComponent(TheDungeon:GetDungeonMap())
	print(TheDungeon:GetDungeonMap():GetDebugString(true))
end

-- Print the (visual) tile under the cursor
function c_tile()
	local s = ""

	local map = TheWorld.Map
	local mx, mz = ConsoleWorldPosition():GetXZ()
	local tx, ty = map:GetTileCoordsAtXZ(mx, mz)
	s = s..string.format("world[%f,%f] tile[%d,%d] ", mx,mz, tx,ty)

	local tile_name = map:GetNamedTileAtXZ(mx, mz)
	if tile_name then
		s = s..string.format("ground[%s] ", tile_name)
	end

	print(s)
end
-- Simpler version of c_tile
function c_groundtype()
	local player = GetDebugPlayer()
	if player then
	    local tile = TheWorld.Map:GetNamedTileAtXZ(player.Transform:GetWorldXZ())
		print("Ground type is:", tile)
	end
end


-- Apply a scenario script to the selection and run it.
--[[function c_doscenario(scenario)
    local inst = GetDebugEntity()
    if not inst then
        print("Need to select an entity to apply the scenario to.")
        return
    end
    if inst.components.scenariorunner then
        inst.components.scenariorunner:ClearScenario()
    end

    -- force reload the script -- this is for testing after all!
    package.loaded["scenarios/"..scenario] = nil

    inst:AddComponent("scenariorunner")
    inst.components.scenariorunner:SetScript(scenario)
    inst.components.scenariorunner:Run()
    SuUsed("c_doscenario_"..scenario, true)
end]]


-- Some helper shortcut functions
function c_sel_health()
    if c_sel() then
        local health = c_sel().components.health
        if health then
            return health
        else
            print("Gah! Selection doesn't have a health component!")
            return
        end
    else
        print("Gah! Need to select something to access it's components!")
    end
end

function c_sethealth(n)
    local player = ConsoleCommandPlayer()
    if player ~= nil and player.components.health ~= nil then
        SuUsed("c_sethealth", true)
        player.components.health:SetPercent(math.clamp(n, 0, 1))
    end
end

function c_setminhealth(n)
    local player = ConsoleCommandPlayer()
    if player ~= nil and player.components.health ~= nil and not player:HasTag("playerghost") then
        SuUsed("c_minhealth", true)
        player.components.health:SetMinHealth(n)
    end
end

-- networking2022 -- review this API; use klei_net net_joingame in the meantime
-- Work in progress direct connect code.
-- Currently, to join an online server you must authenticate first.
-- In the future this authentication will be taken care of for you.
function c_connect(ip, port, password)
	return false
    -- if not InGamePlay() and TheNet:StartClient(ip, port, 0, password) then
    --     --DisableAllDLC()
    --     return true
    -- end
    -- return false
end


local function add_currency(itemdef, amount)
    local player = ConsoleCommandPlayer()
	if not player then
		return
	end

	amount = amount or 1
	if amount > 0 then
		player.components.inventoryhoard:AddStackable(itemdef, amount)
	else
		player.components.inventoryhoard:RemoveStackable(itemdef, -amount)
	end
	SuUsed("c_currency_".. itemdef.name)
end

-- Put most relevant currency into player's inventory.
function c_currency(amount)
	if TheWorld:HasTag("town") then
		-- c_currencytown(amount)
		c_lessersoul(amount)
	else
		c_currencydungeon(amount)
	end
end

--- Gimme some quick cash!
function c_rich()
	c_lessersoul(100)
	c_currencydungeon(10000)
	add_currency(Consumable.Items.MATERIALS.glitz, 10000)
end

--- Remove all known currencies from the player.
function c_bankrupt()
    local player = ConsoleCommandPlayer()
	if not player then
		return
	end
	local hoard = player.components.inventoryhoard
	local currencies = {
		Consumable.Items.MATERIALS.konjur_soul_lesser,
		Consumable.Items.MATERIALS.konjur_soul_greater,
		Consumable.Items.MATERIALS.konjur_heart,
		Consumable.Items.MATERIALS.konjur,
		Consumable.Items.MATERIALS.glitz
	}
	for _, currency in ipairs(currencies) do
		hoard:RemoveStackable(currency, hoard:GetStackableCount(currency))
	end
end

function c_lessersoul(amount)
	local Consumable = require "defs.consumable"
	add_currency(Consumable.Items.MATERIALS.konjur_soul_lesser, amount)
end

function c_greatersoul(amount)
	local Consumable = require "defs.consumable"
	add_currency(Consumable.Items.MATERIALS.konjur_soul_greater, amount)
end

function c_konjurheart(boss, amount)
	local Consumable = require "defs.consumable"
	boss = boss or "megatreemon"
	local heart_name = ("konjur_heart_%s"):format(boss)
	add_currency(Consumable.Items.MATERIALS[heart_name], amount)
end

function c_currencytown(amount)
	local Consumable = require "defs.consumable"
	add_currency(Consumable.Items.MATERIALS.glitz, amount)
end

function c_currencydungeon(amount)
	local Consumable = require "defs.consumable"
	add_currency(Consumable.Items.MATERIALS.konjur, amount)
end


-- Put an item(s) in the player's inventory. count is ignored for equipment and
-- skip_equip is ignored for materials.
function c_give(slot, name, count, skip_equip)
	if kstring.startswith(slot, "pwr_") then
		return c_power(slot)
	end

	playerutil.DoForAllLocalPlayers(function(player)
		slot = slot:upper()
		name = name:lower()
		count = count or 1

		local success = player.components.inventoryhoard:Debug_GiveItem(slot, name, count, not skip_equip)
		if success then
			SuUsed(("c_give_%s_%s"):format(slot,name))
		end
	end)
end

function c_give_armorset(name)
	c_give('ARMS', name)
	c_give('BODY', name)
	c_give('HEAD', name)
	c_give('WAIST', name)
	c_give('LEGS', name)
	c_give('SHOULDERS', name)
end

-- Receives equipment info and gives the player all ingredients to craft that
-- equipment. Nothing happens if there's no recipe.
function c_giveingredients(slot, name)
	local Consumable = require "defs.consumable"
	local recipes = require "defs.recipes"

	slot = slot:upper()
	name = name:lower()
    local recipe = recipes.ForSlot[slot][name]
    if not recipe then
		print(("Invalid item to build: %s.%s"):format(slot, name))
        return
    end

    for ing_name, needs in pairs(recipe.ingredients) do
        c_give(Consumable.Slots.MATERIALS, ing_name, needs)
    end
end

-- Make it rain loot drops.
function c_loot_shower(count)
	count = count or 1000
	local Consumable = require "defs.consumable"
	local DropsAutogenData = require "prefabs.drops_autogen_data"
	for prefab,params in pairs(DropsAutogenData) do
		local def = Consumable.FindItem(params.loot_id)
		if def then
			c_spawn(prefab)
			count = count - 1
			if count <= 0 then
				return
			end
		end
	end
end

function c_power(power_id, rarity, stacks, target)
	stacks = math.floor(stacks or 1)
	-- local itemforge = require "defs.itemforge"
	local Power = require "defs.powers"
	target = target or ConsoleCommandPlayer()

	if not target then
		return
	end

	local pm = target.components.powermanager
	local def = Power.FindPowerByQualifiedName(power_id)
	local power = pm:CreatePower(def, rarity)
	local can_add = pm:Debug_CanAddPower(power)
	if can_add then
		pm:AddPower(power, stacks)
		print("Debug gave power", def.name)
	else
		print("Already had power", def.name)
	end
	return can_add
end

function c_upgradepower(power_id, player)
	local Power = require "defs.powers"
	player = player or ConsoleCommandPlayer()

	if not player then
		return
	end

	local pm = player.components.powermanager
	if power_id then
		local def = Power.FindPowerByQualifiedName(power_id)
		pm:UpgradePower(def)
	else
		TheLog.ch.Cheat:print("c_upgradepower: upgrading all powers")
		local powers = player.components.powermanager:GetUpgradeablePowers()
		for _,pow in ipairs(powers) do
			player.components.powermanager:UpgradePower(pow.def)
		end
	end
end

function c_removepower(power_id)
	-- local itemforge = require "defs.itemforge"
	local Power = require "defs.powers"
	local player = ConsoleCommandPlayer()

	if not player then
		return
	end

	local pm = player.components.powermanager
	local def = Power.FindPowerByQualifiedName(power_id)
	pm:RemovePower(def, true)
end

function c_random_powers(num, target)
    local krandom = require "util.krandom"
    local Power = require "defs.powers"
    local all_powers = Power.GetQualifiedNames()

    local valid_powers = {}
    for _, pwr_name in ipairs(all_powers) do
		local def = Power.FindPowerByQualifiedName(pwr_name)
		if def.power_type == "RELIC"
			and def.show_in_ui -- shown in ui means might be given normally
		then
			table.insert(valid_powers, pwr_name)
		end
    end

    num = num or 5
    num = math.min(#valid_powers, num)

    local powers = krandom.PickSome(num, valid_powers)
    for _,p in ipairs(powers) do
        c_power(p, nil, nil, target)
    end
end

-- Craft a recipe with the player's current inventory.
function c_craft(slot, name, skip_equip)
	local recipes = require "defs.recipes"

	slot = slot:upper()
	name = name:lower()
    local recipe = recipes.ForSlot[slot][name]
    if not recipe then
		print(("Invalid item to build: %s.%s"):format(slot, name))
        return
    end

    local player = ConsoleCommandPlayer()
	if not player then
		return
	end

	if recipe:CanPlayerCraft(player, skip_equip) then
		print("crafting", slot, name)
		recipe:CraftItemForPlayer(player, skip_equip)
	else
		print("insufficient materials for", slot, name)
	end
end

function c_pos(inst)
    return inst ~= nil and inst:GetPosition() or nil
end

function c_printpos(inst)
    print(c_pos(inst))
end

function c_teleport(x, y, z, inst)
    inst = ListingOrConsolePlayer(inst)
    if inst ~= nil then
		if x == nil then
			x, y, z = ConsoleWorldPosition():Get()
		end
        inst.Transform:SetPosition(x, y, z)
        SuUsed("c_teleport", true)
    end
end

function c_move(inst)
    inst = inst or c_sel()
    if inst ~= nil then
        inst.Transform:SetPosition(ConsoleWorldPosition():Get())
        SuUsed("c_move", true)
    end
end

function c_goto(dest, inst)
    if type(dest) == "string" or type(dest) == "number" then
        dest = UserToPlayer(dest)
    end
    if dest ~= nil then
        inst = ListingOrConsolePlayer(inst)
        if inst ~= nil then
            if inst.Physics ~= nil then
                inst.Physics:Teleport(dest.Transform:GetWorldPosition())
            else
                inst.Transform:SetPosition(dest.Transform:GetWorldPosition())
            end
            SuUsed("c_goto", true)
            return dest
        end
    end
end

function c_inst(guid)
    return Ents[guid]
end

function c_list(prefab)
    local x,y,z = ConsoleCommandPlayer().Transform:GetWorldPosition()
    local ents = TheSim:FindEntitiesXZ(x,z, 9001)
    for k,v in pairs(ents) do
        if v.prefab == prefab then
            print(string.format("%s {%2.2f, %2.2f, %2.2f}", tostring(v), v.Transform:GetWorldPosition()))
        end
    end
end

function c_listtag(tag)
    local tags = {tag}
    local x,y,z = ConsoleCommandPlayer().Transform:GetWorldPosition()
    local ents = TheSim:FindEntitiesXZ(x,z, 9001, tags)
    for k,v in pairs(ents) do
        print(string.format("%s {%2.2f, %2.2f, %2.2f}", tostring(v), v.Transform:GetWorldPosition()))
    end
end

local lastfound = -1
local lastprefab = nil
function c_findnext(prefab, radius, inst)
    if type(inst) == "string" or type(inst) == "number" then
        inst = UserToPlayer(inst)
        if inst == nil then
            return
        end
    end
    inst = inst or ConsoleCommandPlayer() or TheWorld
    if inst == nil then
        return
    end
    prefab = prefab or lastprefab
    lastprefab = prefab

    local trans = inst.Transform
    local found = nil
    local foundlowestid = nil
    local reallowest = nil
    local reallowestid = nil
    local reallowestidx = -1

    print("Finding a ",prefab)

    local x,y,z = trans:GetWorldPosition()
    local ents = {}
    if radius == nil then
        ents = Ents
    else
        -- note: this excludes CLASSIFIED
        ents = TheSim:FindEntitiesXZ(x,z, radius)
    end
    local total = 0
    local idx = -1
    for k,v in pairs(ents) do
        if v ~= inst and v.prefab == prefab then
            total = total+1
            if v.GUID > lastfound and (foundlowestid == nil or v.GUID < foundlowestid) then
                idx = total
                found = v
                foundlowestid = v.GUID
            end
            if not reallowestid or v.GUID < reallowestid then
                reallowest = v
                reallowestid = v.GUID
                reallowestidx = total
            end
        end
    end
    if not found then
        found = reallowest
        idx = reallowestidx
    end
    if not found then
        print("Could not find any objects matching '"..prefab.."'.")
        lastfound = -1
    else
        print(string.format("Found %s (%d/%d)", found.GUID, idx, total ))
        lastfound = found.GUID
    end
    return found
end

local godmode_image = nil

function c_godmode(player, force_enable, damage_mult)
    player = ListingOrConsolePlayer(player)
    if player ~= nil then
        SuUsed("c_godmode", true)
		player.components.combat.godmode = force_enable or not player.components.combat.godmode
		if player.components.combat.godmode then
			damage_mult = damage_mult or 5
			player.components.combat:SetDamageDealtMult("cheat", damage_mult)
			player.components.combat:SetDamageReceivedMult("cheat", 0)

			-- Show icon on screen to indicate god mode is on.
			local Image = require "widgets/image"
			local icon_image = (damage_mult > 100 and "images/icons_boss/megatreemon.tex") or
								(damage_mult > 5 and "images/icons_boss/bullder.tex") or
								(damage_mult == 1 and "images/icons_boss/owlitzer.tex") or
								(damage_mult == 0 and "images/icons_boss/thatcher.tex") or
								"images/icons_boss/bandicoot.tex"

			if godmode_image then
				godmode_image:SetTexture(icon_image)
			else
				godmode_image = Image(icon_image)
					:SetAnchors("left", "bottom")
					:SetScale(0.5)
					:SetPosition(50, 50)
			end

			if godmode_image then
				godmode_image:Show()

				local fmodtable = require "defs.sound.fmodtable"
				TheFrontEnd:GetSound():PlaySound(fmodtable.Event.Skill_Megatreek_Queue)
			end
		else
			player.components.combat:RemoveAllDamageMult("cheat")

			if godmode_image then
				godmode_image:Hide()
			end
		end
		print("God mode: "..tostring(player.components.combat.godmode), player)
    end
end

function c_babymode(player, force_enable)
    player = ListingOrConsolePlayer(player)
    if player ~= nil then
        SuUsed("c_babymode", true)
		player.components.combat.babymode = force_enable or not player.components.combat.babymode
		if player.components.combat.babymode then
			player.components.combat:SetDamageDealtMult("babymode", 0.0)
			player.components.combat:SetDamageReceivedMult("babymode", 0)
		else
			player.components.combat:RemoveAllDamageMult("babymode")
		end
		print("Baby mode: "..tostring(player.components.combat.babymode), player)
    end
end

function c_godmodeall(damage_mult, force_enable)
	for _,player in ipairs(AllPlayers) do
		c_godmode(player, force_enable, damage_mult)
	end
end

function c_armor(player)
    player = ListingOrConsolePlayer(player)
    if player ~= nil then
        SuUsed("c_armor", true)
        if player.components.combat then
			player.components.combat:SetDamageReceivedMult("cheat", 0)
			print(tostring(player) .." now ignores all damage")
		end
	end
end
c_armour = c_armor

-- Find closest prefab instance with matching name near player. See also
-- c_selectprefab to ignore distance and c_searchprefabs to find prefab defs.
function c_find(prefab, radius, inst)
    inst = ListingOrConsolePlayer(inst)
    if inst == nil then
        return
    end

    local trans = inst.Transform
    local found = nil
    local founddistsq = math.huge

    local x, z = trans:GetWorldXZ()
    local ents = Ents
    if radius then
        -- excludes CLASSIFIED
        ents = TheSim:FindEntitiesXZ(x,z, radius)
    end
    for k, v in pairs(ents) do
        if v ~= inst and v.prefab == prefab then
            local distsq = inst:GetDistanceSqTo(v)
            if distsq < founddistsq then
                found = v
                founddistsq = distsq
            end
        end
    end
    return found
end

function c_gonext(name)
    if name ~= nil then
        local next = c_findnext(string.lower(name))
        if next ~= nil and next.Transform ~= nil then
            return c_goto(next)
        end
    end
    return nil
end

function c_simphase(phase)
    TheWorld:PushEvent("phasechange", {newphase = phase})
end

local last_count
-- Prints counts for all known prefabs. If called again, prints the delta from
-- the last call to easily tell what's increasing.
local function countallprefabs(noprint)
    local total = 0
    local unk = 0
    local counted = {}
    for k,v in pairs(Ents) do
        if v.prefab ~= nil then
            if counted[v.prefab] == nil then
                counted[v.prefab] = 1
            else
                counted[v.prefab] = counted[v.prefab] + 1
            end
            total = total + 1
        else
            unk = unk + 1
        end
    end

	if not noprint then
		print(table.inspect(counted))

		if last_count then
		    print("Deltas from last count:")
		    for prefab,count in iterator.sorted_pairs(counted) do
		        local before = last_count[prefab] or 0
		        if before ~= count then
		            print(("%s: %d -> %d"):format(prefab, before, count))
		        end
		    end
		end
		print(string.format("There are %d different prefabs in the world, %d total (and %d unknown)", table.numkeys(counted), total, unk))
	end
    last_count = counted
	return total
end

function c_countprefabs(prefab, noprint)
	if not prefab then
		return countallprefabs(noprint)
	end

    local count = 0
    for k,v in pairs(Ents) do
        if v.prefab == prefab then
            count = count + 1
        end
    end
    if not noprint then
        print("There are ", count, prefab.."s in the world.")
    end
    return count
end

function c_counttagged(tag, noprint)
    local count = 0
    for k,v in pairs(Ents) do
        if v:HasTag(tag) then
            count = count + 1
        end
    end
    if not noprint then
        print("There are ", count, tag.."-tagged ents in the world.")
    end
    return count
end

function c_speedmult(multiplier)
    local inst = ConsoleCommandPlayer()
    if inst ~= nil then
        inst.components.locomotor:SetExternalSpeedMultiplier(inst, "c_speedmult", multiplier)
    end
end

function c_dump()
    local ent = GetDebugEntity()
    if not ent then
        ent = ConsoleWorldEntityUnderMouse()
    end
    DumpEntity(ent)
end

--[[function c_dumpseasons()
    local str = TheWorld.net.components.seasons:GetDebugString()
    print(str)
end]]

function c_selectnext(name)
    return c_select(c_findnext(name))
end

function c_selectnear(prefab, rad)
    local player = ConsoleCommandPlayer()
    local x,y,z = player.Transform:GetWorldPosition()
    local ents = TheSim:FindEntitiesXZ(x,z, rad or 30)
    local closest = nil
    local closeness = nil
    for k,v in pairs(ents) do
			print("found", v.prefab)
        if v.prefab == prefab then
			print("found", v.prefab)
            if closest == nil or player:GetDistanceSqTo(v) < closeness then
                closest = v
                closeness = player:GetDistanceSqTo(v)
            end
        end
    end
    if closest then
        c_select(closest)
    end
end

function c_gatherplayers()
    local x,y,z = ConsoleWorldPosition():Get()
    for k,v in pairs(AllPlayers) do
        v.Transform:SetPosition(x,y,z)
    end
end

function c_speedup()
    TheSim:SetTimeScale(TheSim:GetTimeScale() *10)
    print("Speed is now ", TheSim:GetTimeScale())
end

-- Finds a prefab def fuzzy matching the input name. To find in world, see c_find.
function c_searchprefabs(str)
    local regex = ""
    for i=1,str:len() do
        if i > 1 then
            regex = regex .. ".*"
        end
        regex = regex .. str:sub(i,i)
    end
    local res = {}
    for prefab,v in pairs(Prefabs) do
        local s,f = string.lower(prefab):find(regex)
        if s ~= nil then
            -- Tightest match first, with a bias towards the match near the beginning, and shorter prefab names
            local weight = (f-s) - (100-s)/100 - (100-prefab:len())/100
            table.insert(res, {name=prefab,weight=weight})
        end
    end

    table.sort(res, function(a,b) return a.weight < b.weight end)

    if #res == 0 then
        print("Found no prefabs matching "..str)
    elseif #res == 1 then
        print("Found a prefab called "..res[1].name)
        return res[1].name
    else
        print("Found "..tostring(#res).." matches:")
        for i,v in ipairs(res) do
            print("\t"..v.name)
        end
        return res[1].name
    end
end

function c_maintainhealth(player, percent)
    player = ListingOrConsolePlayer(player)
    if player ~= nil and player.components.health ~= nil then
        if player.debug_maintainhealthtask ~= nil then
            player.debug_maintainhealthtask:Cancel()
        end
        player.debug_maintainhealthtask = player:DoPeriodicTask(3, function(inst) inst.components.health:SetPercent(percent or 1) end)
    end
end

-- Use this instead of godmode if you still want to see deltas and things
function c_maintainall(player)
    player = ListingOrConsolePlayer(player)
    if player ~= nil then
        c_maintainhealth(player)
    end
end

function c_cancelmaintaintasks(player)
    player = ListingOrConsolePlayer(player)
    if player ~= nil then
        if player.debug_maintainhealthtask ~= nil then
            player.debug_maintainhealthtask:Cancel()
            player.debug_maintainhealthtask = nil
        end
    end
end

function c_removeallwithtags(...)
    local count = 0
    for k,ent in pairs(Ents) do
        for i=1,select('#', ...) do
            local tag = select(i, ...)
            if ent:HasTag(tag) then
                ent:Remove()
                count = count + 1
                break
            end
        end
    end
    print("removed",count)
end

function c_removeall(name)
    local count = 0
    for k,ent in pairs(Ents) do
        if ent.prefab == name then
            ent:Remove()
            count = count + 1
        end
    end
    print("removed",count)
end
function c_sounddebug()
    if not package.loaded["debugsounds"] then
        require "debugsounds"
    end
    SOUNDDEBUG_ENABLED = true
    SOUNDDEBUGUI_ENABLED = false
    TheSim:SetDebugRenderEnabled(true)
end

function c_sounddebugui()
    if not package.loaded["debugsounds"] then
        require "debugsounds"
    end
    SOUNDDEBUG_ENABLED = true
    SOUNDDEBUGUI_ENABLED = true
    TheSim:SetDebugRenderEnabled(true)
end

function c_migrateto(worldId, portalId)
    local player = ConsoleCommandPlayer()
    if player ~= nil then
        portalId = portalId or 1
        TheWorld:PushEvent(
            "ms_playerdespawnandmigrate",
            { player = player, portalid = portalId, worldid = worldId }
        )
    end
end

function c_repeatlastcommand()
    local history = GetConsoleHistory()
    if #history > 0 then
        if history[#history] == "c_repeatlastcommand()" then
            -- top command is this one, so we want the second last command
            history[#history] = nil
        end
        local success = ExecuteConsoleCommand(history[#history])
        if not success then
            TheFrontEnd:ShowConsoleLog()
        end
    end
end

function c_startvote(commandname, playeroruserid)
    local userid = playeroruserid
    if type(userid) == "table" then
        userid = userid.userid
    elseif type(userid) == "string" or type(userid) == "number" then
        userid = UserToClientID(userid)
        if userid == nil then
            return
        end
    end
    TheNet:StartVote(smallhash(commandname), userid)
end

function c_stopvote()
    TheNet:StopVote()
end

function c_autoteleportplayers()
    TheWorld.auto_teleport_players = not TheWorld.auto_teleport_players
    print("auto_teleport_players:", TheWorld.auto_teleport_players)
end

function c_dumpentities()

    local ent_counts = {}

	local total = 0
    for k,v in pairs(Ents) do
        local name = v.prefab or (v.widget and v.widget.name) or v.name

        if(type(name) == "table") then
            name = tostring(name)
        end


		if name == nil then
			name = "NONAME"
		end
        local count = ent_counts[name]
        if count == nil then
            count = 1
        else
            count = count + 1
        end
        ent_counts[name] = count
		total = total + 1
    end

    local sorted_ent_counts = {}

    for ent, count in pairs(ent_counts) do
        table.insert(sorted_ent_counts, {ent, count})
    end

    table.sort(sorted_ent_counts, function(a,b) return a[2] > b[2] end )


    print("Entity, Count")
    for k,v in ipairs(sorted_ent_counts) do
        print(v[1] .. ",", v[2])
    end
	print("Total: ", total)
end

function c_mute()
	local volume = TheGameSettings:Get("audio.master_volume")
	if volume > 50 then
		volume = 0
	else
		volume = 99
	end
	TheGameSettings:Set("audio.master_volume", volume)
	TheGameSettings:Save()
end

-- Nuke any controller mappings, for when people get in a hairy situation with a controller mapping that is totally busted.
function ResetControllersAndQuitGame()
    print("ResetControllersAndQuitGame requested")
    if not InGamePlay() then
	-- Nuke any controller configurations from our profile
	-- and clear the setting in the ini file
	TheSim:SetSetting("misc", "controller_popup", tostring(nil))
	Profile:SetValue("controller_popup",nil)
	Profile:SetValue("controls",{})
	Profile:Save()
	-- And quit the game, we want a restart
	RequestShutdown()
    else
	print("ResetControllersAndQuitGame can only be called from the frontend")
    end
end

---------------------------------------------------------------------
-- ADD GAME-SPECIFIC CONSOLE COMMANDS BELOW
---------------------------------------------------------------------

function c_place(prefab)
	GetDebugPlayer().components.playercontroller:StartPlacer(prefab.."_placer")
end

function c_startsnapshot(snapshot)
   TheAudio:StartFMODSnapshot(snapshot)
end

function c_stopsnapshot(snapshot)
   TheAudio:StopFMODSnapshot(snapshot)
end

function c_animdata(prefab)
    if prefab then
        c_spawn(prefab)
    end

    local anims = c_sel().AnimState:GetAnimNamesFromAnimFile()
    for i, anim in ipairs(anims) do
        printf("%s : %f", anim, c_sel().AnimState:GetAnimationNumFrames(anim))
    end
end

function c_hud_hide()
	TheDungeon.HUD:Hide()
end

function c_hud_show()
	TheDungeon.HUD:Show()
end

function c_reset_player()
	local player = GetDebugPlayer()
	if player and player:IsLocal() then
		-- full health
		player.components.health:HealAndClearAllModifiers()
		-- remove powers
		player.components.powermanager:ResetData()
		-- refill potion
		player.components.potiondrinker:InitializePotions()
	end
end

function c_refillpotion()
	local player = GetDebugPlayer()
	if player and player:IsLocal() then
		player.components.potiondrinker:InitializePotions()
	end
end

function c_potion(potion)
    local player = ConsoleCommandPlayer()
	if not player or not player:IsLocal() then
		return
	end

    local success = player.components.inventoryhoard:Debug_GiveItem("POTIONS", potion, 1, true)
    if not success then
        print ("Could not give potion ", potion)
        return
    end

    player.components.potiondrinker:CheckPotions(true)
    player.components.potiondrinker:InitializePotions()
end


function c_tonic(tonic)
    local player = ConsoleCommandPlayer()
	if not player or not player:IsLocal() then
		return
	end

    local success = player.components.inventoryhoard:Debug_GiveItem("TONICS", tonic, 1, true)
    if not success then
        print ("Could not give tonic ", tonic)
        return
    end

    player.components.potiondrinker:CheckPotions(true)
    player.components.potiondrinker:InitializePotions()
end

function c_potions(potion, tonic)
    c_potion(potion)
    c_tonic(tonic)
end

function c_dpstracker()
	local player = GetDebugPlayer()
	if player then
		player:AddComponent("dpstracker")
	end
end

function c_visualize_iframes()
	local player = GetDebugPlayer()
	if player then
		player:AddComponent("dpstracker")
		player.components.dpstracker:VisualizeIframes(true)
	end
end

function c_visualize_hitstun()
	HITSTUN_VISUALIZER_ENABLED = true
	local x,y,z = ConsoleCommandPlayer().Transform:GetWorldPosition()
	local ents = TheSim:FindEntitiesXZ(x,z, 9001)
	for i,v in ipairs(ents) do
		if v:HasTag("mob") or v:HasTag("player") then
			v:AddComponent("hitstunvisualizer")
		end
	end
end

function c_charmedyammo()
	local x,y = TheSim:ScreenToWorldXZ(TheInput:GetMousePos())
	local yammo = c_spawn("yammo")
	yammo.Transform:SetPosition(x,y,0)
	yammo:RemoveTag("mob")
	yammo:AddTag("playerminion")
	yammo.components.combat:ClearTargetTags()
	yammo.components.combat:AddTargetTags(TargetTagGroups.Enemies)
	-- yammo.components.combat:SetDamageDealtMult("charmed", 10)
	-- yammo.components.combat:SetDamageReceivedMult("charmed", 10)
	yammo.components.hitbox:SetHitGroup(HitGroup.PLAYER)
	yammo.components.hitbox:SetHitFlags(HitGroup.CREATURES)
	-- TODO: ADJUST TARGETING BEHAVIOUR... RETARGET MORE OFTEN? OVERRIDE TO TARGET NEAREST
	yammo.components.attacktracker:SetMinimumCooldown(0)
	yammo.components.attacktracker:ModifyAttackCooldowns(.5)
	yammo.components.attacktracker:ModifyAllAttackTimers(0)

	yammo.components.coloradder:PushColor("charmed", 28/255, 0/255, 58/255, 1)
	yammo.components.colormultiplier:PushColor("charmed", 220/255, 169/255, 255/255, 1)
	yammo.components.bloomer:PushBloom("charmed", 64/255, 0/255, 70/255, 0.5)
end



-- Called on sim start from QA builds (but not main menu).
function c_qa_build()
	-- Log extra info for our QA testers to track down current issues. This is
	-- called very early so you can hook into events to log at the appropriate
	-- time.
	--
	-- Errors in this code are not silenced, so make sure it doesn't fail!
	-- Beware of changing behaviour or it may introduce phantom bugs.
	local task
	TheDungeon:ListenForEvent("playeractivated", function(_, player)
		if not task then
			-- Wait a bit for other players to spawn so we don't log too much.
			task = TheDungeon:DoTaskInTime(1, function(inst_)
				task = nil
				print("c_qa_build: after players activated")


				c_printpowers() -- jambell wants to see armor info.
			end)
		end
	end)
end

-- Called when we send feedback.
function c_printplayerdata()
	-- Log info to track down current issues.
	--
	-- Errors in this code *are silenced* when called from feedback. If the log
	-- is cut off, something's probably throwing an error!
	c_controlinfo()
	c_konjurlog()
	c_printpowers()
	c_currententityinfo()
	c_networkinfo()
	c_spawninfo()
	c_questinfo()
end

function c_konjurlog()
	local krm = TheWorld.components.konjurrewardmanager
	if krm ~= nil then
		print("------------ KONJUR LOG BEGINS ------------[[")
		print(table.inspect(krm:GetLog()))
		print("]]------------ KONJUR LOG ENDS ------------")
	end
end

function c_printpowers()
	print("------------ CURRENT POWER LIST BEGINS --------[[")
	for i,player in ipairs(AllPlayers) do
		print("Player", i, player.components.powermanager:Debug_GetPowerListing())
	end
	print("]]---------- CURRENT POWER LIST ENDS ------------")
end

function c_printsettings()
	print("------------ SETTINGS DUMP BEGINS ----------[[")
	local data = TheGameSettings:GetSaveData()
	print("TheGameSettings =", table.inspect(data, { depth = 6, process = table.inspect.processes.skip_mt, }))
	print("]]---------- SETTINGS DUMP ENDS ------------")
end

function c_controlinfo()
	print("------------ CONTROL DUMP BEGINS ----------[[")
	for i,player in ipairs(AllPlayers or {}) do
		print(("P%i last device: %s"):format(i, player.components.playercontroller:GetLastInputDeviceType()))
	end
	print("]]---------- CONTROL DUMP ENDS ------------")
end

function c_currententityinfo()
	local function get_net_id(inst)
		if inst.Network then
			return inst.Network:GetEntityID()
		end
		return "[no Network]"
	end
	local function get_sg_state(inst)
		if inst.sg then
			local laststate = inst.sg.laststate and inst.sg.laststate.name or "[no last state]"
			local curstate = inst.sg:GetCurrentState() or "[no current state]"
			local remotestate
			if SGRegistry:HasData(inst.sg.sg.name) and not inst:IsLocal() then
				remotestate = inst.sg.remote_state
			else
				remotestate = "n/a"
			end
			return ("  Last State: %s\n  Current State: %s\n  Remote State: %s\n"):format(laststate, curstate, remotestate)
		end
		return "[no sg]"
	end
	print("-------- CURRENT ENTITY INFO DUMP BEGINS --------[[")
	print("IsHost:", TheNet:IsHost())
	print("-------- PLAYERS --------")
	for i, player in ipairs(AllPlayers) do
		printf("\n[%d] Player %d:\n  GUID: %d\n  EntityID: %s\n  Hitbox Enabled: %s\n  In Limbo: %s\n%s  DebugString[[\n\n%s\n]]\n",
			i, player:GetHunterId(), player.GUID, get_net_id(player),
			player.HitBox:IsEnabled(), player:IsInLimbo(),
			get_sg_state(player),
			player:GetDebugString())
	end

	print(" -------- MOBS --------")
	local enemies = TheWorld.components.roomclear and TheWorld.components.roomclear:GetEnemies() or {}
	for enemy, _ in pairs(enemies) do
		printf("\nEnemy: %s\n  GUID: %d\n  EntityID: %s\n  Health: %s\n  Hitbox Enabled: %s\n  Is Visible: %s\n  In Limbo: %s\n  Is Local: %s\n  Position: %s\n  Map Walkable: %s\n%s\n\n",
			enemy.prefab, enemy.GUID, get_net_id(enemy),
			enemy.components.health:GetDebugString(),
			enemy.HitBox:IsEnabled(), enemy:IsVisible(), enemy:IsInLimbo(), enemy:IsLocal(),
			enemy:GetPosition() or "", TheWorld.Map:IsWalkableAtXZ(enemy:GetPosition():GetXZ()) or "",
			get_sg_state(enemy))
	end

	print(" -------- INTERACTABLES --------")
	local ents = TheSim:FindEntitiesXZ(0, 0, 1000, { "interactable" })
	for _, interactable in ipairs(ents) do
		printf("\nInteractable: %s\n  GUID: %d\n  EntityID: %s\n  Is Visible: %s\n  In Limbo: %s\n  Position: %s\n  Map Walkable: %s\n%s\n%s\n",
			interactable.prefab, interactable.GUID, get_net_id(interactable),
			interactable:IsVisible(), interactable:IsInLimbo(),
			interactable:GetPosition() or "", TheWorld.Map:IsWalkableAtXZ(interactable:GetPosition():GetXZ()) or "",
			get_sg_state(interactable),
			"  Interactable:\n    ".. interactable.components.interactable:GetDebugString())
	end

	print(" -------- ROOM CLEAR --------")
	if TheWorld.components.roomclear then
		print("IsRoomComplete:", TheWorld.components.roomclear:IsRoomComplete())
		print("IsClearOfEnemies:", TheWorld.components.roomclear:IsClearOfEnemies())
	end
	if TheWorld.components.roomlockable then
		print("Room Locked:", TheWorld.components.roomlockable:IsLocked())
		for lock, _ in pairs(TheWorld.components.roomlockable.locks) do
			-- DebugString includes guid, net_id, but only if valid.
			printf("\nLocking Entity: %s\n  GUID: %d\n  EntityID: %s\nDebugString[[\n\n%s\n]]\n",
				lock.prefab, lock.GUID, get_net_id(lock), lock:GetDebugString())
		end
	end
	print("]]-------- CURRENT ENTITY INFO DUMP ENDS --------")
end

function c_networkinfo()
	print("-------- NETWORK INFO BEGINS --------[[")

	print(TheNet:GetNetworkDebugInfo());

	print("]]-------- NETWORK INFO DUMP ENDS --------")
end

function c_spawninfo()
	print("------------ SPAWN DUMP BEGINS ----------[[")
	if TheWorld
		and TheWorld.components.spawncoordinator
	then
		local spawncoordinator = TheWorld.components.spawncoordinator
		print("SpawnCoordinator Encounter Callstack")
		print(spawncoordinator:Debug_GetEncounterCallstack())
		print("SpawnCoordinator data")
		print(table.inspect(spawncoordinator.data, { depth = 1, }))
	end
	print("]]---------- SPAWN DUMP ENDS ------------")
end

function c_questinfo()
	print("------------ QUEST DUMP BEGINS ----------[[")
	local castmanager = TheDungeon and TheDungeon.progression.components.castmanager
	if castmanager then
		local players = castmanager:GetActivePlayers()
		for player, questcentral in pairs(players) do
			if player:IsLocal() then
				print("----")
				printf("---- Dumping Data For Player: [%s]", player)
				print("----")
				local qman = questcentral:GetQuestManager()
				local quests = qman:GetQuests()
				for _, quest in ipairs(quests) do
					printf("-------- [%s] : %s", quest:GetContentID(), quest:GetStatus())
					for objective, state in pairs(quest.objective_state) do
						printf("---------------- [%s] : %s", objective, state)
					end
				end
			else
				print("----")
				printf("---- SKIPPING PLAYER: [%s] (NOT LOCAL)", player)
				print("----")
			end
		end
	end
	print("]]---------- QUEST DUMP ENDS ------------")
end

local function MakeWeaponAndArmourTuningTable()
	local itemforge = require "defs.itemforge"
	local equipment = itemforge.GetWeaponsAndArmour()

	local tuning_data = {}
	tuning_data.weapons = {}
	tuning_data.armours = {}

	for i, item in ipairs(equipment) do
		if item.slot == "WEAPON" then
			tuning_data.weapons[item.id] = {}
			tuning_data.weapons[item.id][item.slot] = {}
			tuning_data.weapons[item.id][item.slot].stats = item.stats
		else
			-- If we haven't already started a category for this family, start one.
			if not tuning_data.armours[item.id] then
				tuning_data.armours[item.id] = {}
				tuning_data.armours[item.id].pieces = {}
			end
			tuning_data.armours[item.id].pieces[item.slot] = {}
			tuning_data.armours[item.id].pieces[item.slot].stats = item.stats

			-- Add its total stats to the stat table.
			for stat,val in pairs(item.stats) do
				tuning_data.armours[item.id][stat] = tuning_data.armours[item.id][stat] ~= nil and tuning_data.armours[item.id][stat] + val or val
			end
		end
	end

	return tuning_data
end

function c_equipmentstats()
	local tbl = MakeWeaponAndArmourTuningTable()
	print("------------ EQUIPMENT STATS BEGIN ------------")
	dumptable(tbl)
	-- print(table.inspect(tbl))
	print("------------ EQUIPMENT STATS ENDS ------------")
end

function c_armourstats(set)
	if not set then
		print("c_armourstats(set) -- no [set] argument given")
		return
	end

	local tbl = MakeWeaponAndArmourTuningTable()
	if tbl.armours[set] ~= nil then
		dumptable(tbl.armours[set])
	else
		print("Armour set not found:", set)
	end
end

function c_armoursets_by_stat()
	local stats =
	{
	}

	for stat,_ in pairs(EQUIPMENT_STATS.s) do
		table.insert(stats, stat)
	end
	local weapon_and_armors = MakeWeaponAndArmourTuningTable()

	local unsorted_stats = {}
	for _,stat in ipairs(stats) do
		-- Initialize the table indexed by STAT: armour, hp, crit, etc.
		if not unsorted_stats[stat] then
			unsorted_stats[stat] = {}
		end

		-- Loop through all the armours: if a piece of armour has this stat, add it to the table, indexed by the armour's stat value.
		for set,data in pairs(weapon_and_armors.armours) do
			if data[stat] ~= nil then
				table.insert(unsorted_stats[stat], { data[stat], set })
			end
		end
	end

	print("------------ SORTED ARMOUR SETS BEGIN ------------")
	for stat,tbl in pairs(unsorted_stats) do
		local sorted_tbl = lume.sort(tbl, function(a,b) return a[1] > b[1] end)
		print("")
		print("")
		print(stat)
		-- Create a sorted version of tbl

		-- Then print the sorted data
		for i = 1, #sorted_tbl do
			local pair = sorted_tbl[i]
			print(pair[1], pair[2]) -- value, armourset
		end
	end
	print("")
	print("")
	print("------------ SORTED ARMOUR SETS END ------------")
end

function c_weapons_by_stat()
	local stats =
	{
	}

	for stat,_ in pairs(EQUIPMENT_STATS.s) do
		table.insert(stats, stat)
	end
	local weapons_and_armors = MakeWeaponAndArmourTuningTable()

	local unsorted_stats = {}
	for _,stat in ipairs(stats) do
		-- Initialize the table indexed by STAT: armour, hp, crit, etc.
		if not unsorted_stats[stat] then
			unsorted_stats[stat] = {}
		end

		-- Loop through all the armours: if a piece of armour has this stat, add it to the table, indexed by the armour's stat value.
		for set,data in pairs(weapons_and_armors.weapons) do
			if data.WEAPON.stats[stat] ~= nil then
				table.insert(unsorted_stats[stat], { data.WEAPON.stats[stat], set })
			end
		end
	end

	print("------------ SORTED WEAPONS BEGIN ------------")
	for stat,tbl in pairs(unsorted_stats) do
		local sorted_tbl = lume.sort(tbl, function(a,b) return a[1] > b[1] end)
		print("")
		print("")
		print(stat)
		-- Create a sorted version of tbl

		-- Then print the sorted data
		for i = 1, #sorted_tbl do
			local pair = sorted_tbl[i]
			print(pair[1], pair[2]) -- value, armourset
		end
	end
	print("")
	print("")
	print("------------ SORTED WEAPONS END ------------")
end

function c_spawnnpc(npc_prefab)
	if TheWorld.components.plotmanager:IsPlotOccupied(npc_prefab) then
		print ("TRYING TO SPAWN AN ALREADY EXISTING NPC")
		return
	end

	local NPC_TO_QUEST =
	{
		npc_apothecary = "twn_shop_apothecary",
		npc_armorsmith = "twn_armorsmith_arrival",
		npc_blacksmith = "twn_shop_weapon",
		npc_cook = "twn_shop_cook",
		npc_refiner = "twn_shop_research",
	}

	local NPC_TO_FLAG =
	{
		npc_apothecary = "wf_town_has_apothecary",
		npc_armorsmith = "wf_town_has_armorsmith",
		npc_blacksmith = "wf_town_has_blacksmith",
		npc_cook = "wf_town_has_cook",
		npc_dojo_master = "wf_town_has_dojo",
		npc_refiner = "wf_town_has_research",
	}

	TheWorld:UnlockFlag(NPC_TO_FLAG[npc_prefab])

	local plot = TheWorld.components.plotmanager.plots[npc_prefab].inst
	plot.components.plot:OnPostLoadWorld()

	playerutil.DoForAllLocalPlayers(function(player)
		local qm = player.components.questcentral:GetQuestManager()
		qm:SpawnQuest(NPC_TO_QUEST[npc_prefab])
	end)
end

function c_repeatquest()
	playerutil.DoForAllLocalPlayers(function(player)
		player.components.questcentral:SpawnRepeatableQuest()
	end)
end

-- Spawning biome lineups:
local function LineUp(ents)
	dumptable(ents)
	local count = #ents
	print("count:")
	local x = count * -2
	for _,ent in ipairs(ents) do
		ent.Transform:SetPosition(x, 0, 0)
		x = x + 4.5
	end
end

local function GetLineUpByTag(tag)
	local Biomes = require"defs.biomes"

	local biome = TheDungeon:GetDungeonMap():GetBiomeLocation().id
	local def = Biomes.locations[biome]

	local ents = {}
	for thing,_ in pairs(def.monsters.allowed_mobs) do
		local ent = c_spawndumb(thing)
		if ent:HasTag(tag) then
			print("Spawning:", ent)
			table.insert(ents, ent)
		else
			ent:Remove()
		end
	end

	return ents
end

function c_lineup_traps()
	local traps = GetLineUpByTag("trap")
	LineUp(traps)
end

function c_lineup_monsters()
	local mobs = GetLineUpByTag("mob")
	LineUp(mobs)
end

function c_mastery(mastery_id, target)
	local Mastery = require "defs.masteries"
	target = target or ConsoleCommandPlayer()

	if not target then
		return
	end

	local mm = target.components.masterymanager
	local def = Mastery.FindMasteryByQualifiedName(mastery_id)
	local mastery = mm:CreateMastery(def)
	local can_add = mm:DEBUG_CanAddMastery(mastery)
	if can_add then
		mm:AddMastery(mastery)
		print("SUCCESS: Debug gave mastery", def.name)
	else
		print("FAILED: Already had mastery", def.name)
	end
	return can_add
end

function c_mastery_remove(mastery_id, target)
	local Mastery = require "defs.masteries"
	target = target or ConsoleCommandPlayer()

	if not target then
		return
	end

	local mm = target.components.masterymanager
	local def = Mastery.FindMasteryByQualifiedName(mastery_id)
	if def and mm:HasMastery(def) then
		mm:RemoveMastery(def)
		print("SUCCESS: Debug remove mastery", def.name)
		return true
	else
		local name = mastery_id:match("^mst_(%S+)$")
		print("FAILED: Mastery", name, "does not exist on ", target.name)
		return false
	end
end

function c_mastery_addprogress(mastery_id, progressval, target)
	local Mastery = require "defs.masteries"
	target = target or ConsoleCommandPlayer()

	if not target then
		return
	end

	local mm = target.components.masterymanager
	local def = Mastery.FindMasteryByQualifiedName(mastery_id)
	if def and mm:HasMastery(def) then
		local mastery = mm:GetMastery(def)
		mastery:DeltaProgress(progressval)
		print("SUCCESS: Added", progressval, "progress to mastery", def.name)
	else
		local name = mastery_id:match("^mst_(%S+)$")
		print("FAILED: Mastery", name, "does not exist on ", target.name)
		return false
	end
end

function c_itemcatalog()
	local itemcatalog = require "defs.itemcatalog"
	dumptable(itemcatalog.All.Items)
end

function c_equipgem(gem_name)
	local Equipment = require "defs.equipment"
	local EquipmentGem = require "defs.equipmentgems.equipmentgem"
	local itemforge = require "defs.itemforge"

	local gem_def = EquipmentGem.FindGemByName(gem_name)

	local inst = ConsoleCommandPlayer()
	local equipped_weapon = inst.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)

	local equipped = false
	for i,slot in ipairs(equipped_weapon.gem_slots) do
		if slot.slot_type == gem_def.gem_type or slot.slot_type == EquipmentGem.Type.ANY then
			local gem = inst.components.gemmanager:MakeGem(gem_def)
			inst.components.gemmanager:EquipGem(gem, i)
			equipped = true
			-- equipped_weapon.gem_slots[i].gem = gem
			break
		end
	end

	if not equipped then
		print("FAILED: No gem slot found for gem type ", gem_def.gem_type)
	end
end

function c_unequipgems(gem_name)
	local inst = ConsoleCommandPlayer()
	inst.components.gemmanager:ClearAllSlots()
end

function c_removearmor(slot, armor)
	local player = GetDebugPlayer()
	if player then
		player.components.inventoryhoard:Debug_RemoveByName(slot, armor)
	end
end

function c_removeweapon(weapon)
	local player = GetDebugPlayer()
	if player then
		player.components.inventoryhoard:Debug_RemoveByName("WEAPON", weapon)
	end
end

function c_hitme(prefabname, attack_level, damage)
	local player = GetDebugPlayer()
	if player then
		local target = (type(prefabname) == "number" and AllPlayers[prefabname]) or (prefabname and c_find(prefabname)) or player
		if not target or not target.components.combat then return end

		local ent = CreateEntity()--c_spawndumb("cabbageroll")
		ent.prefab = "DEBUG_DAMAGE"
		ent.entity:AddTransform()
		ent.Transform:SetPosition(player:GetPosition():Get())
		ent:AddComponent("combat")
		ent.components.combat:SetBaseDamage(ent, damage or 0)

		local attack = Attack(ent, target)
		attack:SetHitstunAnimFrames(6)

		if attack_level == 1 then
			target.components.combat:SetHasKnockback(true)
			target.components.combat:SetFrontKnockbackOnly(false)
			target.sg:RemoveStateTag("knockdown")

			target.components.combat:DoKnockbackAttack(attack)
		elseif attack_level == 2 then
			attack:SetForceKnockdown(true)
			target.components.combat:DoKnockdownAttack(attack)
		else
			target.components.combat:DoBasicAttack(attack)
		end

		-- For networked games, take control of remote entities.
		if not target:IsLocal() then
			target:TakeControl()
		end

		if ent then ent:Remove() end
	end
end

-- heh
function c_nopants()
	playerutil.DoForAllLocalPlayers(function(player)
		player.components.inventory:Equip("WAIST", nil)
	end)
end
