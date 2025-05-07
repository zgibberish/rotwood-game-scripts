local Equipment = require "defs.equipment"
local Stats = require "stats"
local kassert = require "util.kassert"
local lume = require "util.lume"
require "class"
require "constants"



local Metrics = Class(function(self)
	RegisterOnAccountEventListener(self)
	self.inst = CreateEntity("Metrics")
end)

function Metrics:Send(label, data)
	kassert.typeof("string", label)
	local json_data = data and json.encode_compliant(data) or nil
	TheSim:SendMetricsData(label, json_data)
end

local function GetEquipmentName(inst, slot)
	local item = inst.components.inventoryhoard:GetEquippedItem(slot)
	return item and item.id or "<none>"
end
local function GetWeaponName(inst)
	return GetEquipmentName(inst, Equipment.Slots.WEAPON)
end

local function GetWeaponType(inst)
	-- This is actually get weapon tag since the intended value is lowercased...
	-- I think we don't need to send the weapon type if we're sending the
	-- actual equipment name since we can look up that data offline.
	local weapon_tag = inst.components.inventory:GetEquippedWeaponTag()
	return weapon_tag or "<none>"
end
local function GetPlayerHealthPercent(p)
	return p.components.health:GetPercent()
end
local function GetPlayerHealthMax(p)
	return p.components.health:GetMax()
end

local function BuildRunStats(worldmap)
	local alive_count = lume.count(AllPlayers, EntityScript.IsAlive)
	local total_count = #AllPlayers
	local room = worldmap:Debug_GetCurrentRoom()
	local biome_location = worldmap.nav:GetBiomeLocation()
	return {
		players_alive = alive_count,
		players_total = total_count,
		num_runs = TheSaveSystem.progress:GetValue("num_runs"),
		dungeon_progress = worldmap.nav:GetProgressThroughDungeon(),
		roomtype = room and room.roomtype,
		biome_location = biome_location and biome_location.id,
		dungeon_boss = worldmap.nav:GetDungeonBoss(),
		ascension = TheDungeon.progression.components.ascensionmanager:GetCurrentLevel(),
		team_equipment = {
			weapons = lume.map(AllPlayers, GetWeaponName),
			-- TODO(dbriscoe): potions
		}
	}
end

local function BuildRoomStats(worldmap)
	local total_count = #AllPlayers
	local room = worldmap:Debug_GetCurrentRoom()
	local health_pct = lume.map(AllPlayers, GetPlayerHealthPercent)
	local health_max = lume.map(AllPlayers, GetPlayerHealthMax)
	return {
		players_total = total_count,
		dungeon_progress = worldmap.nav:GetProgressThroughDungeon(),
		health = {
			-- List of values for each player (index 1 is first player).
			percent = health_pct,
			max = health_max,
		},
		roomtype = room and room.roomtype,
	}
end

-- Register events on the world to avoid cluttering up other parts of the code
-- with metrics.
function Metrics:RegisterRoom(world)
	self._onplayerentered = function(source, player)
		self:_RegisterPlayer(player)
	end
	self.inst:ListenForEvent("playerentered", self._onplayerentered, world)

	self._onspecialeventroom_activate = function(source, mystery_name)
		local room = BuildRoomStats(TheDungeon:GetDungeonMap())
		room.mystery = mystery_name
		self:Send("dungeon.mystery.partake", room)
	end
	self.inst:ListenForEvent("specialeventroom_activate", self._onspecialeventroom_activate, world)
end


function Metrics:RegisterDungeon(dungeon)
	self._onstart_new_run = function(source)
		local run = BuildRunStats(dungeon:GetDungeonMap())
		self:Send("dungeon.run.start", run)
	end
	self.inst:ListenForEvent("start_new_run", self._onstart_new_run, dungeon)

	self._onend_current_run = function(source, data)
		local run = BuildRunStats(dungeon:GetDungeonMap())
		run.is_victory = data.is_victory
		self:Send("dungeon.run.end", run)
	end
	self.inst:ListenForEvent("end_current_run", self._onend_current_run, dungeon)
end

-- Register on players to avoid cluttering up other parts of the code
-- with metrics.
function Metrics:_RegisterPlayer(player)
	local worldmap = TheDungeon:GetDungeonMap()

	self._ondrink_potion = function(source, potion_item)
		local health = player.components.health
		self:Send("dungeon.potion.drink", {
				name = potion_item.id,
				after_health = {
					current = health:GetCurrent(),
					max = health:GetMax(),
				},
				dungeon_progress = worldmap.nav:GetProgressThroughDungeon(),
			})
	end
	self.inst:ListenForEvent("drink_potion", self._ondrink_potion, player)

	self._onpotion_refilled = function(source, potion_item)
		self:Send("dungeon.potion.refill", {
				name = potion_item.id,
				dungeon_progress = worldmap.nav:GetProgressThroughDungeon(),
			})
	end
	self.inst:ListenForEvent("potion_refilled", self._onpotion_refilled, player)

	self._onadd_power = function(source, pow)
		self:Send("dungeon.power.add", {
				name = pow.def.name,
				dungeon_progress = worldmap.nav:GetProgressThroughDungeon(),
			})
	end
	self.inst:ListenForEvent("add_power", self._onadd_power, player)

	self._onpower_upgraded = function(source, pow)
		self:Send("dungeon.power.upgrade", {
				name = pow.def.name,
				new_rarity = pow.persistdata:GetRarity(),
				dungeon_progress = worldmap.nav:GetProgressThroughDungeon(),
			})
	end
	self.inst:ListenForEvent("power_upgraded", self._onpower_upgraded, player)

	self._onremove_power = function(source, pow)
		local dungeon_progress = worldmap.nav:GetProgressThroughDungeon()
		if dungeon_progress == 0 then
			-- HACK(dbriscoe): Until we put player save data into dungeon save,
			-- we do a bunch of removes on run start.
			-- https://quire.io/w/Sprint_Tracker/969/Split_player_save_data_into_dungeon_and_town
			return
		end
		self:Send("dungeon.power.remove", {
				name = pow.def.name,
				dungeon_progress = dungeon_progress,
			})
	end
	self.inst:ListenForEvent("remove_power", self._onremove_power, player)

	self._ondeath = function(source, attack)
		local run = BuildRunStats(TheDungeon:GetDungeonMap())
		run.fatal_attack = attack and attack.attack and attack.attack:GetMetrics_PlayerVictim() or nil
		self:Send("dungeon.death", run)
	end
	self.inst:ListenForEvent("dying", self._ondeath, player)
end

function Metrics:Send_StartGame()
	local t = nil
	--~ local t = {}
	--~ if Platform.IsRail() then
	--~ 	t.appdata_writable = TheSim:IsAppDataWritable()
	--~ 	t.documents_writable = TheSim:IsDocumentsWritable()
	--~ end
	self:Send("boot.game_started", t) -- is_only_local_users_data
end


-- includes a bit more metadata about the user, should probably only be on startup
local function BuildStartupContextTable()
    local t = Stats.BuildContextTable(TheNet:GetUserID())

    t.platform = PLATFORM
	-- We send svn branch with our kleionline connection.
    t.releasechannel = RELEASE_CHANNEL
	t.betabranch = TheSim:GetCurrentBetaName()
	t.owns_rotwood = TheSim:GetUserHasLicenseForApp(APPID.ROTWOOD)

    --~ local modnames = KnownModIndex:GetModNames()
    --~ for i, name in ipairs(modnames) do
    --~     if KnownModIndex:IsModEnabled(name) then
    --~         t.branch = t.branch .. "_modded"
    --~         break
    --~     end
    --~ end

    return t
end

local sent_launchcomplete = false
function Metrics:OnAccountEvent(success, event_code, custom_message)
	-- FTF: Not sure that accounts are hooked up on native side.
	TheLog.ch.Metrics:print("OnAccountEvent")
	if not sent_launchcomplete
		and success
		and (event_code == 3
			or event_code == 6)
	then
		sent_launchcomplete = true
		local t = BuildStartupContextTable()
		self:Send("boot.launchcomplete", t)
	end
end

if not METRICS_ENABLED then
	-- Strip all functionality.
	local function noop() end
	local DummyClass = Class(noop)
	for key,val in pairs(Metrics) do
		if type(val) == "function" then
			DummyClass[key] = DummyClass[key] or noop
		end
	end
	Metrics = DummyClass
end

return Metrics
