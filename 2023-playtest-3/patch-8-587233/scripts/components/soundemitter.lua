local kassert = require "util.kassert"
local soundutil = require "util.soundutil"


---------------------------------------------------------------------------------------
-- Extends C++ SoundEmitter component



-- Has a name so you can modify it later. Only one event using this name on
-- this SoundEmitter can play at a time.
function SoundEmitter:PlayUniqueSound(eventname, name, volume, ispredicted)
	assert(name, "If you don't want a name, then call PlayOneShot.")
	local isautostop = soundutil.IsLoop(eventname)
	return self:PlaySound(eventname, name, volume, isautostop, ispredicted)
end

-- TODO(dbriscoe): Use GetEntity to access inst and generate handles on the soundtracker.
local name_idx = 0
function SoundEmitter:_GenerateSoundHandle()
	name_idx = name_idx + 1
	return "auto_emitter__" .. name_idx
end

-- Returns a unique name so you can control it, but unlimited of them can play at once.
-- Example:
--   local handle = inst.SoundEmitter:PlaySound_Autoname(fmodtable.Event.battoad_upperwings_pre_LP)
--   inst.SoundEmitter:KillSound(handle)
function SoundEmitter:PlaySound_Autoname(eventname, volume, isautostop, ispredicted, params)
	isautostop = isautostop or soundutil.IsLoop(eventname)
	local handle = self:_GenerateSoundHandle()
	self:PlaySound(eventname, handle, volume, isautostop, ispredicted)
	-- params is optional, but lets you pass a table of params just like
	-- PlaySoundWithParams.
	for key,val in pairs(params or table.empty) do
		self:SetParameter(handle, key, val)
	end
	return handle
end

-- One shots play to completion. Even if the emitter is destroyed.
function SoundEmitter:PlayOneShot(eventname, volume, params, ispredicted)
	local isautostop = soundutil.IsLoop(eventname)
	if params then
		kassert.typeof("table", params)
		return self:PlaySoundWithParams(eventname, params, volume, isautostop, ispredicted)
	else
		return self:PlaySound(eventname, nil, volume, isautostop, ispredicted)
	end
end

-- StopOnDestroy sounds are automatically stopped when this entity is destroyed.
function SoundEmitter:PlayStopOnDestroySound(eventname, name, volume, ispredicted)
	local isautostop = true
	return self:PlaySound(eventname, name, volume, isautostop, ispredicted)
end

