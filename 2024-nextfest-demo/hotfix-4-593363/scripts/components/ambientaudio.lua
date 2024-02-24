local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
--local mapgen = require "defs.mapgen"
require "class"

local AmbientAudio = Class(function(self, inst)
	self.inst = inst
	self.ambient_bed_id = audioid.persistent.world_ambient
	self.ambient_birds_id = audioid.persistent.world_birds
	self.threat_level = 0 -- network expecting just 0 or 1; change native serialization if precision increases

	local worldmap = TheDungeon:GetDungeonMap()
	local biomes_location = worldmap:GetBiomeLocation()

	-- ********************************
	-- * PARAMETER CLEANUP PROCEDURES *
	-- ********************************

	-- This section is dedicated to resetting parameters and snapshots to their default values.
	-- Use it to clean up and initialize variables before or after certain actions
	-- to ensure the system starts from a known state.

	local audioParametersToResetOnRoomLoad = {
		"g_fadeOutMusicAndSendToReverb",
		"isLocalPlayerInTotem",
		"thump_pitch",
		"critHitCounter",
		"hitHammerCounter",
		"hitSpearCounter",
		"hitShotputCounter",
		"lootCounter_konjur",
		"lootCounter_common",
		"lootCounter_uncommon",
		"lootCounter_rare",
		"lootCounter_epic",
		"lootCounter_legendary",
		"counter_corestonesSpawned",
		"counter_corestonesAccepted",
	}

	for _, paramName in ipairs(audioParametersToResetOnRoomLoad) do
		TheAudio:SetGlobalParameter(fmodtable.GlobalParameter[paramName], 0)
	end

	local audioSnapshotsToStopOnRoomLoad = {
		"Boss_Intro",
		"Interacting",
		"DuckMusicBass",
		"FadeOutMusicBeforeBossRoom",
		"HitstopCutToBlack",
		"Mute_Music_NonMenuMusic",
		"Mute_Ambience_Bed",
		"Mute_Ambience_Birds",
		"Mute_Music_Dungeon",
		"DeathScreen"
	}

	-- Stopping all snapshots to ensure they don't get stuck
	for _, snapshotName in ipairs(audioSnapshotsToStopOnRoomLoad) do
		TheAudio:StopFMODSnapshot(fmodtable.Snapshot[snapshotName])
	end

	TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.thump_quiet_pitch, 7) -- weird outlier

	-- ********************************
	-- ********************************

	-- ==============================
	-- = MUSIC MANAGEMENT FUNCTIONS =
	-- ==============================

	-- Failsafe to ensure ui music doesn't persistent into the world
	TheAudio:StopPersistentSound(audioid.persistent.ui_music)

	-- stop dungeon music going into certain rooms
	local roomTypesToStopMusic = {
		["boss"] = true,
		["hype"] = true,
		["miniboss"] = true,
		["wanderer"] = true,
	}

	local currentRoomType = worldmap:GetCurrentRoomType()

	if roomTypesToStopMusic[currentRoomType] then
		self:StopAllMusic()
	else
		self:StopBossMusic()
		self:StartMusic()
	end

	self:StartAmbient()

	self:SetDungeonProgressParameter({self.ambient_bed_id, self.ambient_birds_id, audioid.persistent.world_music, audioid.persistent.room_music})
	self:SetIsInBossFlowParameter(worldmap:IsInBossArea())

	-- Default to no threat since we don't save enemies within rooms.
	self:SetThreatLevel(0)
	self:SetEveryoneDead(false)
	self:SetTravelling(false)

	self._onroomcomplete = function(world, data)
		self:SetThreatLevel(0)

		-- handle miniboss victory sequence
		if worldmap:GetCurrentRoomType() == "miniboss" and TheWorld.components.roomclear:IsRoomComplete() then	
			TheFrontEnd:GetSound():PlaySound(biomes_location.miniboss_music_victory)
			self:StopBossMusic()
			self:StartMusic()
		end

	end
	inst:ListenForEvent("room_complete", self._onroomcomplete, TheWorld)

	self._onspawnenemy = function(source, ent)
		self:SetThreatLevel(1)
	end
	inst:ListenForEvent("spawnenemy", self._onspawnenemy, TheWorld)

	self._on_exit_room = function(world, data)
		TheAudio:StopFMODSnapshot(fmodtable.Snapshot.Mute_Music_Dungeon)
	end

	self._on_start_new_run = function(world, data)
	end

	self._on_end_current_run = function(world, data)
	end

	inst:ListenForEvent("exit_room", self._on_exit_room, TheDungeon)
	inst:ListenForEvent("start_new_run", self._on_start_new_run, TheDungeon)
	inst:ListenForEvent("end_current_run", self._on_end_current_run, TheDungeon)

end)

--~ function AmbientAudio:OnSave()
--~ 	local data = {}
--~ 	return next(data) ~= nil and data or nil
--~ end

--~ function AmbientAudio:OnLoad(data)
--~ end

-- == ==

function AmbientAudio:StartMusic()
	local worldmap = TheDungeon:GetDungeonMap()
    local room_music = worldmap:GetCurrentRoomAudio()  
    if room_music then
        self:StartRoomMusic(room_music)
	else
		self:StopRoomMusic()
	end

	self.world_music = self:_GetWorldMusic()
	if self.world_music then
		self:StartWorldMusic(self.world_music)
	else
		self:StopWorldMusic()
	end
end

function AmbientAudio:StartRoomMusic(room_music)
	TheAudio:PlayPersistentSound(audioid.persistent.room_music, room_music)
end

function AmbientAudio:StopRoomMusic()
	TheAudio:StopPersistentSound(audioid.persistent.room_music)
end

function AmbientAudio:StartWorldMusic(world_music)
	TheAudio:PlayPersistentSound(audioid.persistent.world_music, world_music)
end

function AmbientAudio:StopWorldMusic()
	TheAudio:StopPersistentSound(audioid.persistent.world_music)
end

function AmbientAudio:StopBossMusic()
	TheAudio:StopPersistentSound(audioid.persistent.boss_music)
end

function AmbientAudio:StopAllMusic()
	self:StopWorldMusic()
	self:StopRoomMusic()
	self:StopBossMusic()
end

function AmbientAudio:StartAmbient()
	self.ambient_bed_sound, self.ambient_birds_sound = self:_GetAmbientSound()
	TheAudio:PlayPersistentSound(self.ambient_bed_id, self.ambient_bed_sound)
	if self.ambient_birds_sound then
		TheAudio:PlayPersistentSound(self.ambient_birds_id, self.ambient_birds_sound)
	end
end

function AmbientAudio:GetDungeonProgress()
	local worldmap = TheDungeon:GetDungeonMap()
	local dungeon_progress = worldmap.nav:GetProgressThroughDungeon()
	return dungeon_progress
end

function AmbientAudio:SetDungeonProgressParameter(id)
	local dungeon_progress = self:GetDungeonProgress()
	for k, v in pairs(id) do
		TheAudio:SetPersistentSoundParameter(v, "Music_Dungeon_Progress", dungeon_progress)
	end
end

function AmbientAudio:SetIsInBossFlowParameter(is_boss) -- reset to 0 after the boss death animation plays as well
	TheAudio:SetPersistentSoundParameter(self.ambient_bed_id, "isInBossFlow", is_boss and 1 or 0)
	TheAudio:SetPersistentSoundParameter(self.ambient_birds_id, "isInBossFlow", is_boss and 1 or 0)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.world_music, "isInBossFlow", is_boss and 1 or 0)
end

function AmbientAudio:StartMuteSnapshot()
	TheAudio:PlayPersistentSound(audioid.persistent.mute_world_music_snapshot, fmodtable.Event.Snapshot_MuteWorldMusic_LP)
end

function AmbientAudio:StopWandererSnapshot()
	TheAudio:StopPersistentSound(audioid.persistent.mute_world_music_snapshot)
end

function AmbientAudio:StartWandererSnapshot()
	TheAudio:PlayPersistentSound(audioid.persistent.wanderer_snapshot, fmodtable.Event.Snapshot_Wanderer_LP)
end

function AmbientAudio:StopWandererSnapshot()
	TheAudio:StopPersistentSound(audioid.persistent.wanderer_snapshot)
end

function AmbientAudio:StopAmbient()
	TheAudio:StopPersistentSound(self.ambient_bed_id)
	TheAudio:StopPersistentSound(self.ambient_birds_id)
end

function AmbientAudio:StopEverything()
	AmbientAudio:StopAmbient()
	AmbientAudio:StopAllMusic()
end

function AmbientAudio:_GetAmbientSound()
	local biomes_location = TheDungeon:GetDungeonMap():GetBiomeLocation()
	if biomes_location.ambient_birds_sound then
		return biomes_location.ambient_bed_sound or nil, biomes_location.ambient_birds_sound or nil
	else
		return biomes_location.ambient_bed_sound or nil, nil
	end
end

function AmbientAudio:_GetWorldMusic()
	local worldmap = TheDungeon:GetDungeonMap()
	local biomes_location = worldmap:GetBiomeLocation()
	return biomes_location.ambient_music
end

function AmbientAudio:PlayMusicStinger(stinger)
	TheAudio:PlayPersistentSound(audioid.oneshot.stinger, stinger)
end

function AmbientAudio:GetThreatLevel()
	return self.threat_level
end

function AmbientAudio:SetThreatLevel(level)
	self.threat_level = level
	--~ TheLog.ch.Audio:print("SetThreatLevel", level)

	if TheNet:IsHost() then
		TheNet:HostSetThreatLevel(level)
	end

	TheAudio:SetPersistentSoundParameter(audioid.persistent.world_music, "Music_InCombat", level) -- this value gets lerped in FMOD Studio, but we also need to know the immediate value
	TheAudio:SetPersistentSoundParameter(audioid.persistent.world_music, "Music_InCombat_Destination", level) -- so we send a second parameter that represents the destination of the parameter
	TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.inCombat, level)

end

function AmbientAudio:SetEveryoneDead(is_everyonedead)
	assert(is_everyonedead ~= nil)
	local level = is_everyonedead and 1 or 0
	--~ TheLog.ch.Audio:print("SetEveryoneDead", level)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.world_music, "Music_InDeath", level)
	if is_everyonedead then
		TheAudio:PlayPersistentSound(audioid.persistent.world_music, fmodtable.Event.mus_Death_LP)
		TheAudio:StartFMODSnapshot(fmodtable.Snapshot.DeathScreen)
		self:StartAmbient()
	else
		--TheAudio:StopFMODSnapshot(fmodtable.Snapshot.DeathScreen)
	end
end

function AmbientAudio:SetTravelling(is_travelling)
	if is_travelling then
		TheAudio:StartFMODSnapshot(fmodtable.Snapshot.TravelScreen)
	else
		TheAudio:StopFMODSnapshot(fmodtable.Snapshot.TravelScreen)
	end
end
--~ function AmbientAudio:GetDebugString()
--~ 	return table.inspect{
--~ 		sound = self.sound_event,
--~ 		music = self.music_event,
--~ 		current_music = TheAudio:GetPersistentSound(audioid.persistent.world_music),
--~ 		current_sound = TheAudio:GetPersistentSound(self.amb_bed),
--~ 	}
--~ end

function AmbientAudio:SetLocalParameterForAllPersistentMusicTracks(parameter, value)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.world_music, parameter, value)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.room_music, parameter, value)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, parameter, value)
end

-- function AmbientAudio:GetRandomMusicOffset(floor)
-- 	-- Set a random seed based on the current time
-- 	math.randomseed(os.time())
-- 	local offset = math.random() + floor

-- 	-- Adjust the offset based on the floor value
-- 	if offset >= 1 then
-- 		offset = math.abs(1 - offset)
-- 	end

-- 	return offset
-- end

-- -- set a random start time for the level music to create illusion of continued play
-- local music_play_offset = self:GetRandomMusicOffset(self:GetDungeonProgress())
-- TheAudio:SetPersistentSoundParameter(audioid.persistent.world_music, "Music_PlayOffset", music_play_offset)
-- TheLog.ch.Audio:print("***///***ambientaudio.lua: Setting a random music offset:", music_play_offset)

return AmbientAudio
