local Weather = require("defs.weather")
local krandom = require "util.krandom"

local WeatherManager = Class(function(self, inst, rng)
	self.inst = inst

	self.event_triggers = {}
	self.update_events = {}

	self.selectedweather = nil

	self.initialize_fn = nil
	self.start_fn = nil
	self.scorewrapup_fn = nil
	self.finish_fn = nil

    self._end_run_fn = function() self:ResetWeather() end
    self.inst:ListenForEvent("end_current_run", self._end_run_fn)
end)

WEATHER_ENABLED = false

-- Trigger a specialevent def callback, if defined.
function WeatherManager:Trigger(cb_name, ...)
	local fn = self.selectedweather[cb_name]
	if fn then
		fn(self.inst, ...)
	end
end

-- Clear out the save data for the old weather that was chosen.
function WeatherManager:ResetWeather()
	TheSaveSystem.dungeon:SetValue("selected_weather", nil)
end

-- Pick Random Weather
function WeatherManager:PickRandomWeather()
	-- local rng = TheDungeon:GetDungeonMap():GetRNG()
	local pick = nil
	local possible_weathers = {}

	for id,data in pairs(Weather.Defs) do
		if data.prerequisite_fn == nil or data.prerequisite_fn(self.selectedweather, self.inst, AllPlayers) then
			possible_weathers[id] = data
		end
	end

	-- TODO(jambell): PICK THIS FOR REAL, DETERMINISTICALLY
	for k,v in pairs(possible_weathers) do
		pick = k
		break
	end

	return pick
end

-- Initialize Event: on load of an 'event' roomtype in the dungeon, what should we do? Spawn NPCs, set up NPC conversation, spawn props etc
function WeatherManager:InitializeWeather()
	if self.initialize_fn then
		self.initialize_fn(self.selectedweather, self.inst)
	end
end

-- Start Event:
function WeatherManager:StartWeather()
	if self.start_fn then
		self.start_fn(self.selectedweather, self.inst)
	end
	if self.update_events ~= nil and next(self.update_events) then
		self.inst:StartUpdatingComponent(self)
	end
end

-------------------- INITIALIZATION --------------------
function WeatherManager:OnLoad()
	if not WEATHER_ENABLED then
		return
	end
	TheLog.ch.Weather:printf("Spawning weather")
	local forced_weather = TheSaveSystem.cheats:GetValue("forced_weather")
	local weathername
	if forced_weather then
		TheLog.ch.Weather:printf("Spawning weather for debug: '%s'", forced_weather)
		weathername = forced_weather
	elseif TheSaveSystem.dungeon:GetValue("selected_weather") ~= nil then
		weathername = TheSaveSystem.dungeon:GetValue("selected_weather")
		TheLog.ch.Weather:printf("Loading saved weather: '%s'", weathername)
	end

	if not weathername then
		-- THIS IS NOT DETERMINISTIC, Shjo
		local rng = krandom.CreateGenerator()
		local chance = rng:Float()
		if chance > 0.5 then
			-- 50% chance of no weather, for now. 
			weathername = self:PickRandomWeather()
			TheLog.ch.Weather:printf("No saved weather, chose a new one: '%s'", weathername)
			TheSaveSystem.dungeon:SetValue("selected_weather", weathername)
		end
	end

	local weather = Weather.Defs[weathername]

	if weather ~= nil then
		self:LoadWeather(weather)
		self:InitializeWeather()
		self:StartWeather()
	end
end

function WeatherManager:LoadWeather(weather)
	if weather.on_init_fn then
		self.initialize_fn = weather.on_init_fn
	end

	self:SetUpEventTriggers(weather)
	self.selectedweather = weather

	if weather.on_start_fn then
		self.start_fn = weather.on_start_fn
	end

	if weather.on_update_fn then
		self:AddUpdateEvent(weather)
	end

	if weather.on_finish_fn then
		self.finish_fn = weather.on_finish_fn
	end
end

function WeatherManager:SetUpEventTriggers(weather)
	if next(weather.event_triggers) then
		if self.event_triggers[weather.name] ~= nil then
			assert(nil, "Tried to set up event triggers for a room that already has them!")
		end
		self.event_triggers[weather.name] = {}
		local triggers = self.event_triggers[weather.name]
		for event, fn in pairs(weather.event_triggers) do
			local listener_fn = function(inst, ...) fn(inst, event, ...) end
			triggers[event] = listener_fn
			self.inst:ListenForEvent(event, listener_fn)
		end
	end
end

function WeatherManager:RemoveEventTriggers(weather)
	local weather_def = weather:GetDef()
	if next(weather_def.event_triggers) then
		local triggers = self.event_triggers[weather_def.name]
		if triggers then
			for event, fn in pairs(triggers) do
				self.inst:RemoveEventCallback(event, fn)
			end
		end
		self.event_triggers[weather_def.name] = nil
	end
end

function WeatherManager:AddUpdateEvent(event)
	self.update_events[event] = event.on_update_fn
end

function WeatherManager:OnUpdate(dt)
	local stop_updating = true
	if self.update_events ~= nil then
		for event, fn in pairs(self.update_events) do
			fn(self.selectedweather, self.inst, event, dt)
		end
		stop_updating = false
	end

	if stop_updating then
		self.inst:StopUpdatingComponent(self)
	end
end
return WeatherManager
