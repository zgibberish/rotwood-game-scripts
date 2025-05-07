local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
--local mapgen = require "defs.mapgen"
require "class"

local AmbientAudio = Class(function(self, inst)
	self.inst = inst
	self.ambient_bed_id = audioid.persistent.world_ambient
	self.ambient_birds_id = audioid.persistent.world_birds
	self.music_id = audioid.persistent.world_music
	self.room_music_id = audioid.persistent.room_music
	self.threat_level = 0 -- network expecting just 0 or 1; change native serialization if precision increases

	local worldmap = TheDungeon:GetDungeonMap()
	local biomes_location = worldmap:GetBiomeLocation()

	-- ==============================
	-- = MUSIC MANAGEMENT FUNCTIONS =
	-- ==============================

	-- stop dungeon music going into certain rooms
	local roomTypesToStopMusic = {
		["boss"] = true,
		["hype"] = true,
		["miniboss"] = true,
	}

	local currentRoomType = worldmap:GetCurrentRoomType()

	if roomTypesToStopMusic[currentRoomType] then
		-- I think the cine starts boss music at a point timed to the visuals.
		TheLog.ch.Audio:print("***///***ambientaudio.lua: Stopping room music because of the room type.")
		self:StopRoomMusic()
		TheLog.ch.Audio:print("***///***ambientaudio.lua: Stopping level music because of the room type.")
		self:StopLevelMusic()
	else
		-- this function tries to start all applicable music types
		-- if room music exists, it plays that, and only that, stopping all other music
		-- otherwise it will play the designated level music
		self:StartMusic()
	end

	-- This music track wasn't always getting stopped going into games since the networking prompt re-flow
	-- So this is here as a catch-all
	TheAudio:StopPersistentSound(audioid.persistent.ui_music)

	-- ==============================
	-- ==============================

	--self:StartWandererSnapshot()
	--self:StopWandererSnapshot()

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

	self:StartAmbient()

	self:SetDungeonProgressParameter({self.ambient_bed_id, self.ambient_birds_id, self.music_id, self.room_music_id})
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
			self:StartMusic()
		end

	end
	inst:ListenForEvent("room_complete", self._onroomcomplete, TheWorld)

	self._onspawnenemy = function(source, ent)
		self:SetThreatLevel(1)
	end
	inst:ListenForEvent("spawnenemy", self._onspawnenemy, TheWorld)

	self._on_exit_room = function(world, data)
		-- TheLog.ch.Audio:print("***///***ambientaudio.lua: Stopping room music on exiting room.")
		-- self:StopRoomMusic()
	end

	inst:ListenForEvent("exit_room", self._on_exit_room, TheDungeon)
	inst:ListenForEvent("end_current_run", self._on_exit_room, TheDungeon)

end)

--~ function AmbientAudio:OnSave()
--~ 	local data = {}
--~ 	return next(data) ~= nil and data or nil
--~ end

--~ function AmbientAudio:OnLoad(data)
--~ end

-- Function to generate a random number with an optional floor
-- function _SetRandomPlayOffsetForWhenMusicResumes(floor)
-- 	math.randomseed(os.time())
-- 	local floorValue = floor or 0
-- 	return math.random(floorValue, 100)
-- end

-- == ==

function AmbientAudio:StartMusic()
	-- Ensure no boss music is already playing.
	TheLog.ch.Audio:print("***///***ambientaudio.lua: Stopping boss music.")
	self:StopBossMusic()

	-- Attempt to start room music first
	local worldmap = TheDungeon:GetDungeonMap()
    local room_music = worldmap:GetCurrentRoomAudio()
    
    if room_music then
		TheLog.ch.Audio:print("***///***ambientaudio.lua: Starting current room music: ", room_music)
        TheAudio:PlayPersistentSound(self.room_music_id, room_music)
		TheLog.ch.Audio:print("***///***ambientaudio.lua: Stopping level music.")
		self:StopLevelMusic()
		return
	end

	-- then check for level
	self.music_event = self:_GetAmbientMusic()
	if self.music_event then
		TheLog.ch.Audio:print("***///***ambientaudio.lua: Starting level music: ", self.music_event)
		TheAudio:PlayPersistentSound(self.music_id, self.music_event)
		TheLog.ch.Audio:print("***///***ambientaudio.lua: Stopping room music.")
		self:StopRoomMusic()
		return
	end

	TheLog.ch.Audio:print("***///***ambientaudio.lua: No room nor level music detected.")
	TheLog.ch.Audio:print("***///***ambientaudio.lua: Stopping all music.")
	self:StopAllMusic()
end

function AmbientAudio:StopRoomMusic()
	TheAudio:StopPersistentSound(self.room_music_id)
end

function AmbientAudio:StopLevelMusic()
	TheAudio:StopPersistentSound(self.music_id)
end

function AmbientAudio:StopBossMusic()
	TheAudio:StopPersistentSound(audioid.persistent.boss_music)
end

function AmbientAudio:StopAllMusic()
	self:StopLevelMusic()
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

function AmbientAudio:SetDungeonProgressParameter(id)
	local worldmap = TheDungeon:GetDungeonMap()
	local dungeon_progress = worldmap.nav:GetProgressThroughDungeon()
	for k, v in pairs(id) do
		TheAudio:SetPersistentSoundParameter(v, "Music_Dungeon_Progress", dungeon_progress)
	end
end

function AmbientAudio:SetIsInBossFlowParameter(is_boss) -- reset to 0 after the boss death animation plays as well
	TheAudio:SetPersistentSoundParameter(self.ambient_bed_id, "isInBossFlow", is_boss and 1 or 0)
	TheAudio:SetPersistentSoundParameter(self.ambient_birds_id, "isInBossFlow", is_boss and 1 or 0)
	TheAudio:SetPersistentSoundParameter(self.music_id, "isInBossFlow", is_boss and 1 or 0)
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

function AmbientAudio:_GetAmbientMusic()
	local worldmap = TheDungeon:GetDungeonMap()
	local biomes_location = worldmap:GetBiomeLocation()
	return biomes_location.ambient_music
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

	TheAudio:SetPersistentSoundParameter(self.music_id, "Music_InCombat", level) -- this value gets lerped in FMOD Studio, but we also need to know the immediate value
	TheAudio:SetPersistentSoundParameter(self.music_id, "Music_InCombat_Destination", level) -- so we send a second parameter that represents the destination of the parameter
	TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.inCombat, level)

end

function AmbientAudio:SetEveryoneDead(is_everyonedead)
	assert(is_everyonedead ~= nil)
	local level = is_everyonedead and 1 or 0
	--~ TheLog.ch.Audio:print("SetEveryoneDead", level)
	TheAudio:SetPersistentSoundParameter(self.music_id, "Music_InDeath", level)
	if is_everyonedead then
		TheAudio:PlayPersistentSound(self.music_id, fmodtable.Event.mus_Death_LP)
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
--~ 		current_music = TheAudio:GetPersistentSound(self.music_id),
--~ 		current_sound = TheAudio:GetPersistentSound(self.amb_bed),
--~ 	}
--~ end

function AmbientAudio:SetLocalParameterForAllPersistentMusicTracks(parameter, value)
	TheAudio:SetPersistentSoundParameter(self.music_id, parameter, value)
	TheAudio:SetPersistentSoundParameter(self.room_music_id, parameter, value)
	TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, parameter, value)
end

return AmbientAudio
