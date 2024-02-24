require "class"
require "util"


local playsound = SoundEmitter.PlaySound
local playsoundwithparams = SoundEmitter.PlaySoundWithParams
local killsound = SoundEmitter.KillSound
local killallsounds = SoundEmitter.KillAllNamedSounds
local setparameter = SoundEmitter.SetParameter
local setvolume = SoundEmitter.SetVolume
local setlistener = Audio.SetListener

SoundEmitter.SoundDebug = {}

--tweakable parameters
SoundEmitter.SoundDebug.maxRecentSounds = 30 --max number of recent sounds to list in the debug output
SoundEmitter.SoundDebug.maxDistance     = 30 --max distance to show

SoundEmitter.SoundDebug.nearbySounds = {}
SoundEmitter.SoundDebug.loopingSounds = {}
SoundEmitter.SoundDebug.soundCount = 0
SoundEmitter.SoundDebug.listenerPos = Vector3.zero

SoundEmitter.SoundDebug.uiSounds = {}
SoundEmitter.SoundDebug.loopingUISounds = {}
SoundEmitter.SoundDebug.uiSoundCount = 0

TheSim:LoadPrefabs({"sounddebugicon"})

SoundEmitter.PlaySound = function(emitter, event, name, volume, ...)
	SoundEmitter.DebugPlaySoundCall(emitter, event, name, volume)
	playsound(emitter, event, name, volume, ...)
end

SoundEmitter.PlaySoundWithParams = function(emitter, event, params, volume, ...)
	SoundEmitter.DebugPlaySoundCall(emitter, event, nil, volume, params)
	playsoundwithparams(emitter, event, params, volume, ...)
end

SoundEmitter.KillSound = function(emitter, name, ...)
	local ent = emitter:GetEntity()
	local ent_sounds = SoundEmitter.SoundDebug.loopingSounds[ent]
	if ent_sounds then
		if ent_sounds[name] and ent_sounds[name].icon then
			ent_sounds[name].icon:Remove()
		end
		ent_sounds[name] = nil
	end

	if SoundEmitter.SoundDebug.loopingUISounds[name] then
		SoundEmitter.SoundDebug.loopingUISounds[name] = nil
	end

	killsound(emitter, name, ...)
end

SoundEmitter.KillAllNamedSounds = function(emitter, ...)
	local sounds = SoundEmitter.SoundDebug.loopingSounds[emitter:GetEntity()]
	if sounds then
		for k,v in pairs(sounds) do
			if v.icon then
				v.icon:Remove()
			end
			sounds[v] = nil
		end
		sounds = nil
	end

	local ent = emitter:GetEntity()
	if ent == nil or ent.Transform == nil then
		-- Probably clearing all ui sounds because we assume all ui sounds are
		-- played by the same emitter (frontend).
		SoundEmitter.SoundDebug.loopingUISounds = {}
	end

	killallsounds(emitter, ...)
end

SoundEmitter.SetParameter = function(emitter, name, parameter, value, ...)
	local ent = emitter:GetEntity()
	local ent_sounds = SoundEmitter.SoundDebug.loopingSounds[ent]
	if ent_sounds and ent_sounds[name] then
		ent_sounds[name].params[parameter] = value
	end

	local ui_sound = SoundEmitter.SoundDebug.loopingUISounds[name]
	if ui_sound then
		ui_sound.params[parameter] = value
	end

	setparameter(emitter, name, parameter, value, ...)
end

SoundEmitter.SetVolume = function(emitter, name, volume, ...)
	local ent = emitter:GetEntity()
	local ent_sounds = SoundEmitter.SoundDebug.loopingSounds[ent]
	if ent_sounds and ent_sounds[name] then
		ent_sounds[name].volume = volume
	end

	local ui_sound = SoundEmitter.SoundDebug.loopingUISounds[name]
	if ui_sound then
		ui_sound.volume = volume
	end
	setvolume(emitter, name, volume, ...)
end

Audio.SetListener = function(sim, x, y, z, ...)
	SoundEmitter.SoundDebug.listenerPos = Vector3(x, y, z)
	setlistener(sim, x, y, z, ...)
end

local function DoUpdate()
	for ent,sounds in pairs(SoundEmitter.SoundDebug.loopingSounds) do
		if not next(sounds) then
			SoundEmitter.SoundDebug.loopingSounds[ent] = nil
		else
			for name,info in pairs(sounds) do
				if not ent:IsValid() or not ent.SoundEmitter or not ent.SoundEmitter:IsPlayingSound(name) then
					if info.icon then
						info.icon:Remove()
					end
					sounds[name] = nil
				else
					local pos = Vector3(ent.Transform:GetWorldPosition() )
					local dist = pos:Dist(SoundEmitter.SoundDebug.listenerPos)
					info.dist = dist
					info.pos = pos
					if info.icon then
						info.icon.Transform:SetPosition(pos:Get() )
					end
				end
			end
		end
	end
end
Scheduler:ExecutePeriodic(1, DoUpdate)

local function getLocalInStack(localName)
	for level=0, 10 do
		--~ print(level)
		local index = 1
		while true do
			local info = debug.getinfo(level + 1,"l")
			if not info then
				return
			end
			local name, value = debug.getlocal(level + 1, index)
			if not name then
				break
			end
			index = index + 1
			if name == localName then
				return value
			end
		end
	end
end

local function getFirstWidgetInStack()
	local Widget = require "widgets.widget"
	for level=0, 10 do
		local index = 1
		while true do
			local info = debug.getinfo(level + 1, "l")
			if not info then
				return
			end
			local name, value = debug.getlocal(level + 1, index)
			if not name then
				break
			end
			index = index + 1
			if name == "self" and Widget.is_instance(value) then
				return value
			end
		end
	end
end

SoundEmitter.DebugPlaySoundCall = function(emitter, event, name, volume, params)
	if not SOUNDDEBUG_ENABLED then
		return
	end
	local ent = emitter:GetEntity()
	local soundInfo = {
		-- Data common to world and ui sounds.
		event = event,
		owner = ent,
		guid = ent.GUID,
		prefab = ent and ent.prefab or "",
		volume = volume or 1,
		callstack = debugstack(2),
		params = params or {},
	}
	if ent and ent.Transform then
		local pos = Vector3(ent.Transform:GetWorldPosition() )
		local dist = pos:Dist(SoundEmitter.SoundDebug.listenerPos)
		-- If the sound is within our debug range or it's a named sound, place a debug icon
		if dist < SoundEmitter.SoundDebug.maxDistance or name then
			local soundIcon = nil
			-- Figure out what debug icon we should use. If it exists, display it.
			local ent_sounds = SoundEmitter.SoundDebug.loopingSounds[ent]
			if name and ent_sounds and ent_sounds[name] then
				soundIcon = ent_sounds[name].icon
			else
				soundIcon = SpawnPrefab("sounddebugicon", ent)
			end
			if soundIcon then
				soundIcon.Transform:SetPosition(pos:Get() )
				soundIcon.Transform:SetScale(.05, .05, .05)
			end
			soundInfo.position = pos
			soundInfo.dist = dist
			soundInfo.icon = soundIcon
			soundInfo.event_source = getLocalInStack("event_source")
			if name then
				--add to looping sounds list
				if not SoundEmitter.SoundDebug.loopingSounds[ent] then
					SoundEmitter.SoundDebug.loopingSounds[ent] = {}
				end
				SoundEmitter.SoundDebug.loopingSounds[ent][name] = soundInfo
				if soundIcon then
					if soundIcon.autokilltask then
						soundIcon.autokilltask:Cancel()
						soundIcon.autokilltask = nil
					end
					soundIcon.Label:SetText(name)
				end
			else
				--add to oneshot sound list
				SoundEmitter.SoundDebug.soundCount = SoundEmitter.SoundDebug.soundCount + 1
				local index = (SoundEmitter.SoundDebug.soundCount % SoundEmitter.SoundDebug.maxRecentSounds)+1
				soundInfo.count = SoundEmitter.SoundDebug.soundCount
				SoundEmitter.SoundDebug.nearbySounds[index] = soundInfo
				if soundIcon then
					soundIcon.Label:SetText(tostring(SoundEmitter.SoundDebug.soundCount) )
				end
			end
		end
	else
		soundInfo.widget = getFirstWidgetInStack()
		if name then
			--add to looping sounds list
			soundInfo.params = {}
			SoundEmitter.SoundDebug.loopingUISounds[name] = soundInfo
		else
			--add to oneshot sound list
			SoundEmitter.SoundDebug.uiSoundCount = SoundEmitter.SoundDebug.uiSoundCount + 1
			local index = (SoundEmitter.SoundDebug.uiSoundCount % SoundEmitter.SoundDebug.maxRecentSounds)+1
			soundInfo.count = SoundEmitter.SoundDebug.uiSoundCount
			SoundEmitter.SoundDebug.uiSounds[index] = soundInfo
		end
	end
end

function GetSoundDebugString()
	local lines = {}
	table.insert(lines, "-------SOUND DEBUG-------")
	table.insert(lines, "Looping Sounds")
	for ent,sounds in pairs(SoundEmitter.SoundDebug.loopingSounds) do
		for name,info in pairs(sounds) do
			if info.dist < SoundEmitter.SoundDebug.maxDistance then
				local params = ""
				for k,v in pairs(info.params) do
					params = params.." "..k.."="..v
				end
				table.insert(lines,
					string.format("\t[%s] %s owner:%d %s pos:%s dist:%2.2f volume:%s params:{%s}",
					name, info.event, info.guid, info.prefab, tostring(info.pos), info.dist, tostring(info.volume), params) )
			end
		end
	end
	if SOUNDDEBUGUI_ENABLED then
		for name,info in pairs(SoundEmitter.SoundDebug.loopingUISounds) do
			local params = ""
			for k,v in pairs(info.params) do
				params = params.." "..k.."="..v
			end
			table.insert(lines,
				string.format("\t[%s] %s volume:%d params:{%s}",
				name, info.event, info.volume, params) )
		end
	end
	table.insert(lines, "Recent Sounds")
	for i = SoundEmitter.SoundDebug.soundCount-SoundEmitter.SoundDebug.maxRecentSounds+1, SoundEmitter.SoundDebug.soundCount do
		local index = (i % SoundEmitter.SoundDebug.maxRecentSounds)+1
		if SoundEmitter.SoundDebug.nearbySounds[index] then
			local soundInfo = SoundEmitter.SoundDebug.nearbySounds[index]
			table.insert(lines,
				string.format("\t[%d] %s owner:%d %s pos:%s dist:%2.2f volume:%1.3f",
				soundInfo.count, soundInfo.event, soundInfo.guid, soundInfo.prefab, tostring(soundInfo.pos), soundInfo.dist, soundInfo.volume) )
		end
	end
	if SOUNDDEBUGUI_ENABLED then
		for i = SoundEmitter.SoundDebug.uiSoundCount-SoundEmitter.SoundDebug.maxRecentSounds+1, SoundEmitter.SoundDebug.uiSoundCount do
			local index = (i % SoundEmitter.SoundDebug.maxRecentSounds)+1
			if SoundEmitter.SoundDebug.uiSounds[index] then
				local soundInfo = SoundEmitter.SoundDebug.uiSounds[index]
				table.insert(lines,
					string.format("\t[%d] %s volume:%d",
					soundInfo.count, soundInfo.event, soundInfo.volume) )
			end
		end
	end
	return table.concat(lines, "\n")
end
