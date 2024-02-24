local Enum = require "util.enum"
local fmodtable = require "defs.sound.fmodtable"
local kassert = require "util.kassert"
local kstring = require "util.kstring"


local soundutil = {}


-- Order matches the "faction" parameter in fmod.
soundutil.Faction = Enum{ "localplayer", "remoteplayer", "ally", "enemy", "none", }

-- For SoundEmitter:SetPitchMultiplier().
soundutil.PitchMult = Enum{
	"IsElite",
	"SizeMushroom",
	"UniquePlayer",
	-- See SoundEmitterComponent.h for maximum number of ids.
}

-- Returns the faction as an int.
--
-- Returns nil for unknown so you can check faction multiple entities:
--   soundutil.TryGetFactionFor(ent)
--   	or soundutil.TryGetFactionFor(self.inst)
--   	or soundutil.Faction.id.none
function soundutil.TryGetFactionFor(ent)
	if ent:HasTag("player") then
		if ent:IsLocal() then
			return soundutil.Faction.id.localplayer
		end
		return soundutil.Faction.id.remoteplayer
	elseif ent:HasTag("playerminion") then
		return soundutil.Faction.id.ally
	elseif ent:HasTag("mob") then
		return soundutil.Faction.id.enemy
	end
end

-- For debug prints or tools.
function soundutil.GetFactionNameFor(ent)
	local faction = soundutil.TryGetFactionFor(ent) or soundutil.Faction.id.none
	return soundutil.Faction:FromId(faction)
end


function soundutil.IsLoop(soundevent)
	-- fmodtable's generator validates that looping sounds end with _LP.
	return soundevent and kstring.endswith(soundevent, "_LP")
end

-- Convert from data to soundemitter
function soundutil.ConvertVolume(volume)
	return volume and (volume / 100) or nil
end

function soundutil.FindSoundTracker(instigator)
	-- Fallback to the world so less interesting entities have a global
	-- pool that they're tracked against. Useful for a horde of
	-- cabbagerolls hooting.
	instigator = instigator or TheWorld
	return instigator.components.soundtracker or TheWorld.components.soundtracker
end

local function FmodEventFromParams(params)
	-- TODO(dbriscoe): Consider rewriting all the data to change soundevent -> soundkey.
	dbassert(params.fmodevent or params.soundevent, "Must specify a sound to play.")
	dbassert(not params.fmodevent or not params.soundevent, "Cannot specify both fmodevent and soundevent. Use fmodevent from code.")
	return params.fmodevent or fmodtable.Event[params.soundevent] or ""
end

function soundutil.AddSGAutogenStopSound(inst, param)
	inst.sg.mem.autogen_stopsounds = inst.sg.mem.autogen_stopsounds or {}
	-- if no name is supplied we start it as the soundeventname
	local name = param.name or param.soundevent
	inst.sg.mem.autogen_stopsounds[name] = true
	return name
end


-- Human-oriented sound api.
-- Experimental.
--
-- Eventually this should be the primary way to play sounds from code.
--
-- May return nil if network failed to play the sound.
--
-- Example:
--   soundutil.PlayCodeSound(
--       projectile,                                     -- emitter entity
--       fmodtable.Event.Cannon_shoot_projectile_travel, -- value from fmodtable
--       {
--           instigator = player,                        -- required for soundtracker
--           name = "cannon",                            -- generated if nil
--           max_count = 3,                              -- instigator count limiting parameters
--           volume = 0.7,                               -- defaults to 1
--           is_autostop = false,                        -- detects _LP automatically
--           fmodparams = {                              -- passed directly to fmod
--               remainingAmmo = cannon:GetAmmoCount(),
--           },
--       })
--
-- TODO:
-- Luca also asked for support for these:
--         add_groundtile = true or nil,
function soundutil.PlayCodeSound(inst, fmodevent, args)
	args = args or {}
	dbassert(args.sound_max_count == nil, "Correct parameter name: max_count.")
	dbassert(args.autostop == nil, "Correct parameter name: is_autostop.")

	local data = {
		fmodevent = fmodevent or "", -- Silent failure if we removed a sound from fmod.
		sound_max_count = args.max_count,
		volume = args.volume,
		autostop = args.is_autostop,
		event_source = "PlayCodeSound",
	}
	local handle = soundutil.PlaySoundData(inst, data, args.name, args.instigator)
	-- PlaySoundData may silently fail and return nil. It assumes the other
	-- player successfully played the sound and we'll receive it over the
	-- network.
	if handle and args.fmodparams then
		for key,val in pairs(args.fmodparams) do
			soundutil.SetInstanceParameter(inst, handle, key, val)
		end
	end
	return handle
end


-- Runtime version of EventFuncEditor:SoundData.
-- This function is intended for use by generated code. See PlayCodeSound for
-- calling from code.
--
-- Pass params.fmodevent to use values from fmodtable:
-- handle = soundutil.PlaySoundData(emitter_ent, {
--   fmodevent = fmodtable.Event.whoosh,
-- })
-- The soundevent parameter is meant for generated code (embellisher).
--
-- inst: the entity making the sound.
-- instigator: the entity that created inst or caused it to make sound. (If
-- the player spawns fx, the fx makes sound, then player is the instigator and
-- fx is inst.) Sometimes they're the same (player making sounds).
--
-- Returns the handle/name for the played sound so you can set parameters on
-- it. (If you pass nil for name, it generates a unique handle.)
function soundutil.PlaySoundData(inst, params, name, instigator)
	if inst:ShouldSendNetEvents() then
		if not name then
			-- this needs to match what is done by soundutil.PlaySoundData
			local soundtracker = soundutil.FindSoundTracker(instigator)
			name = soundtracker:GenerateSoundHandle()
		end
		return TheNetEvent:PlaySoundData(inst.GUID, params, name, instigator and instigator.GUID or 0)
	else
		return soundutil.HandlePlaySoundData(inst, params, name, instigator)
	end
end

function soundutil.PlayLocalSoundData(inst, params, name, instigator)
	return soundutil.HandlePlaySoundData(inst, params, name, instigator)
end

function soundutil.ScaleItemAmountsToParameter(input)
	if input == 1 then
		return 1   -- 'single'
	elseif input >= 2 and input <= 5 then
		return 2   -- 'a few'
	elseif input >= 6 and input <= 15 then
		return 3   -- 'several'
	elseif input >= 16 and input <= 75 then
		return 4   -- 'a lot'
	elseif input > 75 then
		return 5   -- 'a ton'
	else
		return nil -- Handle invalid or out-of-range input
	end
end

function soundutil.PlayRemoveItemSound(inst, item_remove_sound, quantity)
	local params = {}
	params.fmodevent = item_remove_sound
	local handle = soundutil.PlayLocalSoundData(inst, params)
	local quantity_to_param = soundutil.ScaleItemAmountsToParameter(quantity)
	soundutil.SetInstanceParameter(inst, handle, "item_amount", quantity_to_param)
end

function soundutil.HandlePlaySoundData(inst, params, name, instigator)
	-- @LUCA Turn this on to see debug code
	-- print("PlaySoundData.params =", table.inspect(params, { depth = 5, }))
	assert(inst, "Need a sound emitter.")
	kassert.typeof("table", params)
	instigator = instigator or inst

	local eventname = FmodEventFromParams(params)
	local event_source = params.event_source
	-- Autostop will stop the sound on destruction. (Good for loops.)
	local is_autostop = params.autostop or soundutil.IsLoop(eventname) -- handle legacy loops
	local volume = soundutil.ConvertVolume(params.volume)
	local max_count = params.sound_max_count
	local soundtracker = soundutil.FindSoundTracker(instigator)
	if max_count then
		-- TheLog.ch.AudioSpam:printf("PlayLimitedSound '%s' from fx '%s'. Max %i on '%s'.", eventname, inst.prefab, max_count, soundtracker.inst)
		name = soundtracker:PlayLimitedSound(eventname, volume, inst, max_count, name, is_autostop)
		-- soundtracker applied faction.
	else
		-- TODO(dbriscoe): Figure out consequences of generating handles for
		-- all emb sounds.
		name = name or soundtracker:GenerateSoundHandle()
		inst.SoundEmitter:PlaySound(eventname, name, volume, is_autostop)
		soundtracker:SetFactionOnSound(inst, name)
	end
	if inst:HasTag("elite") then
		soundutil.SetInstanceParameter(inst, name, "monsterPower", 1)
	end
	return name
end

-- Runtime version of EventFuncEditor:SoundWindow
--
-- inst: the entity making the sound.
-- instigator: the entity that created inst or caused it to make sound. See
-- PlaySoundData.
function soundutil.PlayWindowedSound(inst, params, instigator)
	-- @luca turn on to see debug code
	-- print("PlaySoundData.params =", table.inspect(params, { depth = 5, }))
	assert(inst, "Need a sound emitter.")
	kassert.typeof("table", params)
	local eventname = FmodEventFromParams(params)
	local volume = soundutil.ConvertVolume(params.volume) or 1
	local window_frames = params.window_frames or 5
	if inst.Network then
		TheNetEvent:PlayWindowedSound(inst.GUID, eventname, volume, window_frames, instigator and instigator.GUID or 0)
	else
		local soundtracker = soundutil.FindSoundTracker(instigator)
		soundtracker:PlayWindowedSound(eventname, volume, inst, window_frames)
	end
end

function soundutil.PlayCountedSound(inst, param)
	if inst.Network then
		TheNetEvent:PlayCountedSound(inst.GUID, param)
		return param.fallthrough
	else
		return soundutil.HandlePlayCountedSound(inst, param)
	end
end

function soundutil.HandlePlayCountedSound(inst, param)
	local name = param.name
	if param.stopatexitstate then
		inst.sg.mem.autogen_stopsounds = inst.sg.mem.autogen_stopsounds or {}
		-- if no name is supplied we start it as the soundeventname
		name = name or param.soundevent
		inst.sg.mem.autogen_stopsounds[name] = true
	end
	TheLog.ch.AudioSpam:print("Play Counted Sound:", param.soundevent, param.maxcount)
	if inst.sg.mem.counted_sounds == nil then
		inst.sg.mem.counted_sounds = {}
	end

	local soundcount = inst.sg.mem.counted_sounds[param.soundevent]
	if soundcount ~= nil then
		soundcount = soundcount + 1
	else
		soundcount = 0
	end

	soundcount = soundcount % param.maxcount
	inst.sg.mem.counted_sounds[param.soundevent] = soundcount

	-- Stored count is count-1 for nice modulo math, but need actual count for fmod.
	soundcount = soundcount + 1
	local fmodevent = fmodtable.Event[param.soundevent] or ""
	local volume = soundutil.ConvertVolume(param.volume)
	if name then
		inst.SoundEmitter:PlaySound(
			fmodevent,
			name,
			volume)
		inst.SoundEmitter:SetParameter(name, "count", soundcount)
	else
		inst.SoundEmitter:PlaySoundWithParams(
			fmodevent,
			{ count = soundcount },
			volume)
	end
	return param.fallthrough
end

-- volume [0,100]: nil defaults to 100.  Converted to internal floating point when passed to SoundEmitter
-- is_autostop: nil defaults to true.

-- NOTE: do not ConvertVolume() until the Handle function. Always work [0,100] in code.
function soundutil.PlaySoundWithParams(inst, eventname, params, volume, is_autostop)
	if inst:ShouldSendNetEvents() then
		TheNetEvent:PlaySoundWithParams(inst.GUID, eventname, params, volume, is_autostop)
	else
		soundutil.HandlePlaySoundWithParams(inst, eventname, params, volume, is_autostop)
	end
end

function soundutil.HandlePlaySoundWithParams(inst, eventname, params, volume, is_autostop)
	if volume then
		volume = soundutil.ConvertVolume(volume)
	end
	inst.SoundEmitter:PlaySoundWithParams(eventname, params, volume, is_autostop)
end

function soundutil.SetInstanceParameter(inst, handle, param_name, value)
	if inst:ShouldSendNetEvents() then
		TheNetEvent:SetSoundInstanceParam(inst.GUID, handle, param_name, value)
	else
		soundutil.HandleSetInstanceParameter(inst, handle, param_name, value)
	end
end

function soundutil.SetLocalInstanceParameter(inst, handle, param_name, value)
	soundutil.HandleSetInstanceParameter(inst, handle, param_name, value)
end

function soundutil.HandleSetInstanceParameter(inst, handle, param_name, value)
	inst.SoundEmitter:SetParameter(handle, param_name, value)
end

function soundutil.KillSound(inst, name)
	if inst.Network then
		TheNetEvent:KillSound(inst.GUID, name)
	else
		inst.SoundEmitter:KillSound(name)
	end
end

return soundutil
