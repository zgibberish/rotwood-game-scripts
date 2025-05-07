local Queue = require "util.queue"
local kassert = require "util.kassert"
local lume = require "util.lume"
local soundutil = require "util.soundutil"
require "class"

local function SetNamePrefix(inst)
	if inst:IsNetworked() then
		return ("auto__%i__"):format(inst.Network:GetEntityID())
	else
		return ("auto__%i__"):format(inst.GUID)
	end
end

local SoundTracker = Class(function(self, inst)
	self.inst = inst
	self.tracked_sounds = {}
	self.windowed_sounds = {}
	self.name_idx = 0
	self.prefix = SetNamePrefix(inst)
end)

function SoundTracker:OnEntityBecameRemote()
	self.prefix = SetNamePrefix(self.inst)
end

function SoundTracker:OnEntityBecameLocal()
	self.prefix = SetNamePrefix(self.inst)
end

local function GetOldestRecentTick()
	-- Tune r to be number of ticks to count as recent.
	local r = 5
	return GetTick() - r
end


function SoundTracker:GetFactionFor(ent)
	-- You'd expect to check ent first to get the more specific answer, but if
	-- something is tracked on us then it should be aligned to us. ent is
	-- probably fx which doesn't have a faction, so we go for the most likely
	-- answer first.
	return soundutil.TryGetFactionFor(self.inst)
		or soundutil.TryGetFactionFor(ent)
		or soundutil.Faction.id.none
end

-- Pass the entity playing the sound and the name/handle of the sound. We'll
-- figure out the faction automatically.
function SoundTracker:SetFactionOnSound(emitter_ent, sound_handle)
	local faction = self:GetFactionFor(emitter_ent)
	emitter_ent.SoundEmitter:SetParameter(sound_handle, "faction", faction)
	local faction_player_id
	if self.inst.GetHunterId then
		faction_player_id = self.inst:GetHunterId()
		emitter_ent.SoundEmitter:SetParameter(sound_handle, "faction_player_id", faction_player_id)
	end
end

local player_pitch_mult = {
	-- Numbers between [0,100] that could be multiplied in fmod for each sound.
	-- Anything more than 1+-0.2 might be too big.
	1.01,
	0.95,
	1.04,
	.98,
}

function SoundTracker:ApplyUniquenessState(emitter_ent)
	if self.inst:HasTag("player") then
		local shift = circular_index(player_pitch_mult, self.inst:GetHunterId())
		emitter_ent.SoundEmitter:SetPitchMultiplier(soundutil.PitchMult.id.UniquePlayer, shift)
		local volume = 1
		if not self.inst:IsLocal() then
			-- dim volume on remote player sounds
			volume = 0.75
		end
		emitter_ent.SoundEmitter:OverrideVolumeMultiplier(volume)
		--~ TheLog.ch.Audio:printf("ApplyUniquenessState from [%s] to [%s] shift=%s volume=%s.", self.inst, emitter_ent, shift, volume)
		return
	elseif self.inst:HasTag("elite") and not emitter_ent:HasTag("cinematic") then
		--print("We are pitching this!!", emitter_ent, self.inst)
		emitter_ent.SoundEmitter:SetPitchMultiplier(soundutil.PitchMult.id.IsElite, 0.9) -- pitch shifts elite monsters a tiny bit
	end
end

-- Generate "names" for named sounds.
function SoundTracker:GenerateSoundHandle()
	self.name_idx = self.name_idx + 1
	return self.prefix .. self.name_idx
end

local function IsInvalidSound(v)
	local is_valid = v.ent:IsValid() and v.ent.SoundEmitter:IsPlayingSound(v.name)
	return not is_valid
end

-- Ensures sounds only include ones that are still playing.
function SoundTracker:RefreshSounds()
	for eventname,q in pairs(self.tracked_sounds) do
		lume.removeall(q.list, IsInvalidSound)
	end
end

function SoundTracker:_GetCount(eventname)
	local q = self.tracked_sounds[eventname]
	if q then
		return q:Count()
	end
	return 0
end

function SoundTracker:_PushItem(eventname, emitter_ent, name)
	local q = self.tracked_sounds[eventname] or Queue()
	self.tracked_sounds[eventname] = q

	local item = {
		ent = emitter_ent,
		eventname = eventname,
		name = name or self:GenerateSoundHandle(),
		tick = GetTick(),
	}
	q:Push(item)
	return item
end


-- Play a sound with a maximum count.
--
-- Limiting is per soundtracker which allows us to give each player a budget
-- for this sound so they won't steal from each other. Good for weapon whooshes
-- and hits to ensure everyone gets feedback but we don't overwhelm with sound.
function SoundTracker:PlayLimitedSound(eventname, volume, emitter_ent, max_count, name, is_autostop)
	dbassert(eventname)
	dbassert(emitter_ent)
	dbassert(max_count)

	self:RefreshSounds()
	local count = self:_GetCount(eventname)
	if count >= max_count then
		local q = self.tracked_sounds[eventname]
		local oldest = q:Pop()
		assert(oldest.ent:IsValid())
		oldest.ent.SoundEmitter:KillSound(oldest.name)
		-- TheLog.ch.Audio:printf("PlayLimitedSound killed sound '%s' from '%s' because we hit max %i.", eventname, oldest.ent, max_count)
	else
		count = count + 1
	end
	local newitem = self:_PushItem(eventname, emitter_ent, name)

	emitter_ent.SoundEmitter:PlaySound(newitem.eventname, newitem.name, volume, is_autostop)
	-- This parameter is only set on start.
	emitter_ent.SoundEmitter:SetParameter(newitem.name, "startCount_instigator", count)
	self:SetFactionOnSound(emitter_ent, newitem.name)

	local q = self.tracked_sounds[eventname]

	-- Parameter to tell sound how many of this sound were started "recently".
	-- Doesn't update when other sounds start for simplicity here and in fmod.
	local recent_tick = GetOldestRecentTick()
	local recent_count = lume.count(q.list, function(item)
		return item.tick > recent_tick
	end)
	emitter_ent.SoundEmitter:SetParameter(newitem.name, "recentCount_instigator", recent_count)

	-- Update parameters only when *starting* a sound to keep things simpler.
	-- We don't try to decrement count when old ones stop, but count may go
	-- down if one stopped after another starts.
	for _,item in ipairs(q.list) do
		item.ent.SoundEmitter:SetParameter(item.name, "activeCount_instigator", count)
	end

	return newitem.name
end

function SoundTracker:_OnWindowClose(eventname, volume, emitter_ent, q)
	self.inst:RemoveEventCallback("onremove", q.onclosefn, emitter_ent)
	q.task:Cancel()
	q.onclosefn = nil
	q.task = nil
	if emitter_ent:IsValid() then
		--~ TheLog.ch.Audio:printf("PlayWindowedSound play '%s' on '%s'. Count: %d", eventname, emitter_ent, q.countDuringWindow_instigator)
		q.faction = self:GetFactionFor(emitter_ent)
		emitter_ent.SoundEmitter:PlayOneShot(eventname, volume, q)
	end
	self.windowed_sounds[eventname] = nil
end


-- Open a timing window and play the sound when the window closes with a count
-- of the number of attempts to play the same sound event on this tracker
-- (countDuringWindow_instigator).
--
-- Useful for spreading out or staggering multiple impact sounds that would
-- happen on the same frame. (3 projectiles hit at once, we can play a scatter
-- sound in fmod instead of the same sound stacked on top of itself.) Windowed
-- sounds are never named because they don't exist immediately.
function SoundTracker:PlayWindowedSound(eventname, volume, emitter_ent, window_frames)
	dbassert(eventname)
	dbassert(emitter_ent)
	dbassert(emitter_ent.SoundEmitter)
	dbassert(window_frames)

	local q = self.windowed_sounds[eventname]
	if q then
		kassert.equal(q.window_frames, window_frames, "Expected window frames to always match. Accidental overlap?")
		q.countDuringWindow_instigator = q.countDuringWindow_instigator + 1
	else
		q = {
			countDuringWindow_instigator = 1,
			window_frames = window_frames,
		}
		self.windowed_sounds[eventname] = q
		q.onclosefn = function()
			self:_OnWindowClose(eventname, volume, emitter_ent, q)
		end
		q.task = self.inst:DoTaskInAnimFrames(window_frames, q.onclosefn)
		self.inst:ListenForEvent("onremove", q.onclosefn, emitter_ent)
	end
	--~ TheLog.ch.Audio:printf("PlayWindowedSound request '%s' from '%s'. Count: %d", eventname, emitter_ent, q.countDuringWindow_instigator)
end

function SoundTracker:DebugDrawEntity(ui, panel, colors)
	if ui:CollapsingHeader("Tracked Sounds", ui.TreeNodeFlags.DefaultOpen) then
		for eventname,q in pairs(self.tracked_sounds) do
			ui:TextColored(colors.header, eventname)
			for _,item in ipairs(q.list) do
				ui:Value("Emitter Entity", item.ent)
				ui:Value("IsPlaying", item.ent.SoundEmitter:IsPlayingSound(item.name))
				ui:Value("IsRecent", item.tick > GetOldestRecentTick())
				ui:Value("TimelinePosition", item.ent.SoundEmitter:GetTimelinePosition(item.name))
				--~ ui:Value("Sound Name", item.name)
			end
		end
		if not next(self.tracked_sounds) then
			ui:TextColored(WEBCOLORS.LIGHTGRAY, "None")
		end
	end
	if ui:CollapsingHeader("Windowed Sounds", ui.TreeNodeFlags.DefaultOpen) then
		for eventname,q in pairs(self.windowed_sounds) do
			ui:TextColored(colors.header, eventname)
			ui:Value("Count", q.countDuringWindow_instigator)
			ui:Value("Window Frame Duration", q.window_frames)
		end
	end
end


return SoundTracker
