local Enum = require "util.enum"
local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local lume = require "util.lume"
local Platform = require 'util.platform'

local function OnRawKey(key, down, settings)
	if not down then
		return
	end
	if key == InputConstants.Keys.ENTER
		and TheInput:IsKeyDown(InputConstants.Keys.ALT)
	then
		if not Platform.IsBigPictureMode() then
			local f = settings:Get("graphics.fullscreen")
			settings:Set("graphics.fullscreen", not f)
			settings:Save()
		end
	end
end

local function RegisterGameSettings(settings)
	-- Incrementing version will reset all settings to defaults. Only increment
	-- when previous data will be *invalid* and not for new settings!
	settings:SetVersion(5)

	-- Gameplay
	settings:RegisterSetting("gameplay.dialog_speed")
		:SetDefault(1)
	settings:RegisterSetting("gameplay.animation_speed")
		:SetDefault(1)
	settings:RegisterSetting("gameplay.vibration")
		:SetDefault(true)
		:SetApplyFunction(function(value)
			TheInputProxy:EnableVibration(value)
		end)
	settings:RegisterSetting("gameplay.mouseaiming")
		:SetDefault(true)
		:SetApplyFunction(function(value)
			TheInputProxy:EnableMouseAiming(value)
		end)

	-- Graphics
	settings:RegisterSetting("graphics.fullscreen")
		:SetDefault(false)
		:SetLocalToCurrentMachine()
		:SetApplyFunction(function(value)
			settings:GetGraphicsOptions()
				:SetFullScreen(value)
		end)
	settings:RegisterSetting("graphics.resolution")
		:SetDefault({ w = 3840, h = 2160, })
		:SetLocalToCurrentMachine()
	settings:RegisterSetting("graphics.cursor")
		:SetDefault(0)
	settings:RegisterSetting("graphics.bloom")
		:SetDefault(true)
		:SetApplyFunction(function(value)
			settings:GetGraphicsOptions():SetBloomEnabled(value)
		end)
	settings:RegisterSetting("graphics.rimlighting")
		:SetDefault(true)
		:SetApplyFunction(function(value)
			settings:GetGraphicsOptions():SetRimLightingEnabled(value)
		end)
	settings:RegisterSetting("graphics.shadows")
		:SetDefault(true)
		:SetApplyFunction(function(value)
			settings:GetGraphicsOptions():SetShadowsEnabled(value)
		end)
	settings:RegisterSetting("graphics.lod")
		:SetDefault(1)
	settings:RegisterSetting("graphics.screen_shake")
		:SetDefault(true)
		:SetQueriedInsteadOfApplied()
	settings:RegisterSetting("graphics.screen_flash")
		:SetDefault(true)
		:SetQueriedInsteadOfApplied()

	-- Audio
	local default_device = "<SYSTEM_DEFAULT>"
	local function GetAudioDevices()
		return TheAudio:GetOutputDevices() or {}
	end
	local function AudioDeviceNameToId(name)
		local devices = GetAudioDevices()
		if not devices[1] then
			return -1
		end
		local dev = lume.match(devices, function(v)
			return v.name == name
		end)
		-- Okay if can't find the device, might be disconnected. -1 for default.
		return dev and dev.id or -1
	end
	local function AudioDeviceIdToName(id)
		local devices = GetAudioDevices()
		if not devices[1] then
			return default_device
		end
		local dev = lume.match(devices, function(v)
			return v.id == id
		end)
		return dev and dev.name or default_device
	end
	settings:RegisterSetting("audio.devicename")
		-- Store device name as a string since index may change between launches.
		:SetDefault(default_device)
		:SetLocalToCurrentMachine()
		:SetProcessFunctions(AudioDeviceNameToId, AudioDeviceIdToName)
		:SetApplyFunction(function(name)
			local id = AudioDeviceNameToId(name)
			if id == -1 then
				-- Wasn't found. Keep -1 to indicate "system default".
				if name ~= default_device then
					TheLog.ch.Audio:printf("Failed to find output device '%s' (was it disconnected?). Defaulting to first device.", name)
					name = AudioDeviceIdToName(0) -- 0 is current default device
				end
			end
			TheLog.ch.Audio:printf("Setting output device to '%s' (id=%s)", name, id)
			TheAudio:SelectOutputDeviceById(id)
		end)

	local ListenEnv = Enum{
		"speakers", "headphones", "steamdeck",
	}
	settings:RegisterSetting("audio.listening_environment")
		:SetEnum(ListenEnv)
		:SetDefault(ListenEnv.s.headphones)
		:SetApplyFunction(function(value)
			if not ListenEnv:Contains(value) then
				TheLog.ch.Audio:printf("Error: Unknown ListenEnv value '%s'. Failing to set global param.", value)
				return
			end
			local id = ListenEnv.id[value]
			if id <= 1 then
				TheAudio:PlayPersistentSound("listeningEnvironment",fmodtable.Event.ListeningEnvironment_Speakers_LP)
			elseif id == 2 then
				TheAudio:PlayPersistentSound("listeningEnvironment",fmodtable.Event.ListeningEnvironment_Headphones_LP)
			elseif id == 3 then
				TheAudio:PlayPersistentSound("listeningEnvironment",fmodtable.Event.ListeningEnvironment_SteamDeck_LP)
			end
		end)

	settings:RegisterSetting("audio.force_mono")
		:SetDefault(false)
		:SetApplyFunction(function(value)
			local id = value and 1 or 0
			TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.userVolume_Mix_Mono_g, id)
		end)
	settings:RegisterSetting("audio.mute_on_lost_focus")
		:SetDefault(true)
		:SetQueriedInsteadOfApplied()
	settings:RegisterSetting("audio.master_volume")
		:SetDefault(80)
		:SetApplyFunction(function(value)
			local vol = value/100
			TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.userVolume_Master_g, vol)
		end)
	settings:RegisterSetting("audio.music_volume")
		:SetDefault(100)
		:SetApplyFunction(function(value)
			local vol = value/100
			TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.userVolume_Music_g, vol)
		end)
	settings:RegisterSetting("audio.ambience_volume")
		:SetDefault(80)
		:SetApplyFunction(function(value)
			local vol = value/100
			TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.userVolume_Ambience_g, vol)
		end)
	settings:RegisterSetting("audio.voice_volume")
		:SetDefault(100)
		:SetApplyFunction(function(value)
			local vol = value/100
			TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.userVolume_Voice_g, vol)
		end)
	settings:RegisterSetting("audio.sfx_volume")
		:SetDefault(100)
		:SetApplyFunction(function(value)
			local vol = value/100
			TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.userVolume_SFX_g, vol)
		end)

	-- Controls
	settings.InputDevice = Enum{
		-- Keys match ones in "input.bindings"
		"keyboard",
		"gamepad",
	}

	local function BuildSettingsBinding(default_group, control)
		assert(default_group, "wrong key?")
		local binding = lume.match(default_group, function(v)
			return v.control == control
		end)
		assert(binding)
		-- Make a copy to ensure we don't try to serialize runtime data.
		local settings_binding = deepcopy(binding)
		settings_binding.control = nil
		return settings_binding
	end

	local bindings = {}
	local function ConfigureKeybind(setting_name, control)
		local default_binds = require "input.bindings"
		local setting = settings:RegisterSetting(setting_name)
		table.insert(bindings, setting)

		local bind_set = {}
		for _,device in ipairs(settings.InputDevice:Ordered()) do
			bind_set[device] = BuildSettingsBinding(default_binds[device], control)
		end
		setting
			:SetDefault(bind_set)
			:SetApplyFunction(function(settings_bindset)
				-- settings_bindset is savedata and can't contain control
				-- (which might have unserializable runtime data). Make a copy.
				local binding = deepcopy(settings_bindset)
				for _,device in ipairs(settings.InputDevice:Ordered()) do
					assert(settings_bindset[device].control == nil, "If control snuck into serialization, what else is in here that might sometimes not serialize?!")
					binding[device].control = control
				end
				-- Input takes ownership of binding
				TheInput:RebindKey(binding.keyboard)
				TheInput:RebindGamepadButton(binding.gamepad)
			end)
	end

	-- These settings contain bindings for both keyboard and gamepad.
	ConfigureKeybind("bindings.crafting",     Controls.Digital.OPEN_CRAFTING)
	ConfigureKeybind("bindings.inventory",    Controls.Digital.OPEN_INVENTORY)
	ConfigureKeybind("bindings.interact",     Controls.Digital.ACTION)
	ConfigureKeybind("bindings.emote",        Controls.Digital.SHOW_EMOTE_RING)
	ConfigureKeybind("bindings.light_attack", Controls.Digital.ATTACK_LIGHT)
	ConfigureKeybind("bindings.heavy_attack", Controls.Digital.ATTACK_HEAVY)
	ConfigureKeybind("bindings.dodge",        Controls.Digital.DODGE)
	ConfigureKeybind("bindings.potion",       Controls.Digital.USE_POTION)
	ConfigureKeybind("bindings.skill",        Controls.Digital.SKILL)

	function settings:ResetBindingsToDefaults()
		for _,setting in ipairs(bindings) do
			setting:Set(setting:GetDefault())
		end
	end

	function settings:ClearMatchingInputBinding(bind_set)
		bind_set = deepcopy(bind_set) -- ensure it doesn't change while iterating.
		for _,setting in ipairs(bindings) do
			local s = setting:Get()
			if s.gamepad.button == bind_set.gamepad.button then
				s.gamepad.button = nil
			end
			if s.keyboard.key == bind_set.keyboard.key then
				s.keyboard.key = nil
			end
			setting:Set(s)
		end
	end

	-- Do we want to also discover conflicts?
	--~ local function inc(t, k)
	--~ 	if k then
	--~ 		t[k] = (t[k] or 0) + 1
	--~ 	end
	--~ end
	--~ function settings:FindConflictingBindings()
	--~ 	local b = {
	--~ 		gamepad = {},
	--~ 		keyboard = {},
	--~ 	}
	--~ 	for _,setting in ipairs(bindings) do
	--~ 		local s = setting:Get()
	--~ 		inc(b.gamepad, s.gamepad.button)
	--~ 		inc(b.keyboard, s.keyboard.key)
	--~ 	end
	--~ 	for device,device_binds in pairs(b) do
	--~ 		for k,v in pairs(device_binds) do
	--~ 			if v <= 1 then
	--~ 				device_binds[k] = nil
	--~ 			end
	--~ 		end
	--~ 	end
	--~ 	return b
	--~ end

	local LANGUAGE = require "languages.langs"
	settings:RegisterSetting("language.selected")
		:SetDefault(LANGUAGE.ENGLISH)
		:SetApplyFunction(function(lang_id)
			LOC.SwapLanguage(lang_id)
		end)
	settings:RegisterSetting("language.last_detected")
		:SetDefault("NONE")

	-- Other
	settings:RegisterSetting("other.metrics")
		:SetDefault(true)


	TheInput:AddKeyHandler(function(key, down) OnRawKey(key, down, settings) end)
end

return RegisterGameSettings
