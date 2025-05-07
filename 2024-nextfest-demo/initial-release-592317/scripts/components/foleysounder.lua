local GroundTiles = require "defs.groundtiles"
local fmodtable = require "defs.sound.fmodtable"
local iterator = require "util.iterator"
local soundutil = require "util.soundutil"

local FoleySounder = Class(function(self, inst)
	self.inst = inst
	self._size = nil

	--Audio events:
	self._footstep = nil
	self._footstep_stop = nil
	self._hand = nil
	self._jump = nil
	self._land = nil
	self._bodyfall = nil

	self._hit_start = nil
	self._knockback_start = nil
	self._knockdown_start = nil

	self.inst:ListenForEvent("sfx-hit_hitstop_start", function(inst) self:PlayHitStartSound() end )
	self.inst:ListenForEvent("sfx-knockback_hitstop_start", function(inst) self:PlayKnockbackStartSound() end )
	self.inst:ListenForEvent("sfx-knockdown_hitstop_start", function(inst) self:PlayKnockdownStartSound() end )
end)

-- Mix values for surface sounds for various foley events
local FOOTSTEP_SURFACE_LOUDNESS = 1
local STOP_SURFACE_LOUDNESS = 0.75
local JUMP_SURFACE_LOUDNESS = 1
local LAND_SURFACE_LOUDNESS = 2
local BODYFALL_SURFACE_LOUDNESS = 3
local HAND_SURFACE_LOUDNESS = 0.5
local weight = 1

-- Configuration functions
function FoleySounder:SetFootstepSound(event)
	assert(event ~= nil, string.format("[FoleySounder:SetFootstepSound: %s] Event does not exist in fmodtable. Please make sure it exported in a bank correctly.", string.upper(self.inst.prefab)))
	self._footstep = event
end
function FoleySounder:GetFootstepSound()
	assert(self._footstep, "FOLEYSOUNDER: You must configure a [Footstep] sound for ["..string.upper(self.inst.prefab).."]")
	return self._footstep
end

function FoleySounder:SetFootstepStopSound(event)
	assert(event ~= nil, string.format("[FoleySounder:SetFootstepStopSound: %s] Event does not exist in fmodtable. Please make sure it exported in a bank correctly.", string.upper(self.inst.prefab)))
	self._footstep_stop = event
end
function FoleySounder:GetFootstepStopSound()
	assert(self._footstep, "FOLEYSOUNDER: You must configure a [Footstep Stop] sound for ["..string.upper(self.inst.prefab).."]")
	return self._footstep_stop
end

function FoleySounder:SetHandSound(event)
	assert(event ~= nil, string.format("[FoleySounder:SetHandSound: %s] Event does not exist in fmodtable. Please make sure it exported in a bank correctly.", string.upper(self.inst.prefab)))
	self._hand = event
end
function FoleySounder:GetHandSound()
	assert(self._hand, "FOLEYSOUNDER: You must configure a [Hand] sound for ["..string.upper(self.inst.prefab).."]")
	return self._hand
end

function FoleySounder:SetJumpSound(event)
	assert(event ~= nil, string.format("[FoleySounder:SetJumpSound: %s] Event does not exist in fmodtable. Please make sure it exported in a bank correctly.", string.upper(self.inst.prefab)))
	self._jump = event
end
function FoleySounder:GetJumpSound()
	assert(self._jump, "FOLEYSOUNDER: You must configure a [Jump] sound for ["..string.upper(self.inst.prefab).."]")
	return self._jump
end

function FoleySounder:SetLandSound(event)
	assert(event ~= nil, string.format("[FoleySounder:SetLandSound: %s] Event does not exist in fmodtable. Please make sure it exported in a bank correctly.", string.upper(self.inst.prefab)))

	self._land = event
end
function FoleySounder:GetLandSound()
	assert(self._land, "FOLEYSOUNDER: You must configure a [Land] sound for ["..string.upper(self.inst.prefab).."]")
	return self._land
end

function FoleySounder:SetBodyfallSound(event)
	assert(event ~= nil, string.format("[FoleySounder:SetBodyfallSound: %s] Event does not exist in fmodtable. Please make sure it exported in a bank correctly.", string.upper(self.inst.prefab)))
	self._bodyfall = event
end
function FoleySounder:GetBodyfallSound()
	assert(self._bodyfall, "FOLEYSOUNDER: You must configure a [Bodyfall] sound for ["..string.upper(self.inst.prefab).."]")
	return self._bodyfall
end

function FoleySounder:SetSize(size)
	self._size = size
end
function FoleySounder:GetSize()
	assert(self._size, "FOLEYSOUNDER: You must configure a Size for ["..string.upper(self.inst.prefab).."]")
	return self._size
end

function FoleySounder:SetHitStartSound(event)
	assert(event ~= nil, string.format("[FoleySounder:SetHitStartSound: %s] Event does not exist in fmodtable. Please make sure it exported in a bank correctly.", string.upper(self.inst.prefab)))
	self._hit_start = event
end
function FoleySounder:GetHitStartSound()
	-- Allow these hit/knockback/knockdown sounds to return nil, because the use pattern is a bit different than other foley sounder events.
	return self._hit_start
end
function FoleySounder:SetKnockbackStartSound(event)
	assert(event ~= nil, string.format("[FoleySounder:SetKnockbackStartSound: %s] Event does not exist in fmodtable. Please make sure it exported in a bank correctly.", string.upper(self.inst.prefab)))
	self._knockback_start = event
end
function FoleySounder:GetKnockbackStartSound()
	-- Allow these hit/knockback/knockdown sounds to return nil, because the use pattern is a bit different than other foley sounder events.
	return self._knockback_start
end
function FoleySounder:SetKnockdownStartSound(event)
	assert(event ~= nil, string.format("[FoleySounder:SetKnockdownStartSound: %s] Event does not exist in fmodtable. Please make sure it exported in a bank correctly.", string.upper(self.inst.prefab)))
	self._knockdown_start = event
end
function FoleySounder:GetKnockdownStartSound()
	-- Allow these hit/knockback/knockdown sounds to return nil, because the use pattern is a bit different than other foley sounder events.
	return self._knockdown_start
end


-- Footsteps are oneshots that stop on their own.
local isautostop = false

function FoleySounder:_CalcScaleParam()
	return self.inst:HasTag("player") and self.inst.components.scalable:GetTotalScaleModifier() or 1
end

function FoleySounder:UpdateWeight(class)
	if class == "Light" then
		weight = 0
	elseif class == "Normal" then
		weight = 1
	elseif class == "Heavy" then
		weight = 2
	else
		weight = 1
	end
end

function FoleySounder:_BuildParams()
	return {
		scale = self:_CalcScaleParam(),
		weight = weight
	}
end

-- Playback functions
function FoleySounder:PlayFootstep(volume)
	soundutil.PlaySoundWithParams(self.inst, self:GetFootstepSound(), self:_BuildParams(), volume or 100, isautostop)
	self.inst:PushEvent("foley_footstep")

	self:PlayFoleySurfaceSound((volume or 100)*FOOTSTEP_SURFACE_LOUDNESS)
end

function FoleySounder:PlayFootstepStop(volume)
	soundutil.PlaySoundWithParams(self.inst, self:GetFootstepStopSound(), self:_BuildParams(), volume or 100, isautostop)
	self.inst:PushEvent("foley_footstepstop")

	self:PlayFoleySurfaceSound((volume or 100)*STOP_SURFACE_LOUDNESS)
end

function FoleySounder:PlayJump(volume)
	soundutil.PlaySoundWithParams(self.inst, self:GetJumpSound(), self:_BuildParams(), volume or 100, isautostop)
	self.inst:PushEvent("foley_jump")

	self:PlayFoleySurfaceSound((volume or 100)*JUMP_SURFACE_LOUDNESS)
end

function FoleySounder:PlayLand(volume)
	soundutil.PlaySoundWithParams(self.inst, self:GetLandSound(), self:_BuildParams(), volume or 100, isautostop)
	self.inst:PushEvent("foley_land")

	self:PlayFoleySurfaceSound((volume or 100)*LAND_SURFACE_LOUDNESS)
end

function FoleySounder:PlayBodyfall(volume)
	soundutil.PlaySoundWithParams(self.inst, self:GetBodyfallSound(), self:_BuildParams(), volume or 100, isautostop)
	self.inst:PushEvent("foley_bodyfall")

	self:PlayFoleySurfaceSound((volume or 100)*BODYFALL_SURFACE_LOUDNESS)
end

function FoleySounder:PlayHand(volume)
	soundutil.PlaySoundWithParams(self.inst, self:GetHandSound(), self:_BuildParams(), volume or 100, isautostop)
	self.inst:PushEvent("foley_hand")

	self:PlayFoleySurfaceSound((volume or 100)*HAND_SURFACE_LOUDNESS)
end

-- Sound designers want to tag these sounds at the first frame of the hitstop state, but because the entity gets paused, they don't receive the sound until after hitstop has ended.
-- Let's try using foleysounder play these events when we first enter the state, so it doesn't matter if it gets paused.
-- these are played from hit_hold, knockback_hold, and knockdown_hold, only if the sound designer has assigned an event in the prefab constructor.
function FoleySounder:PlayHitStartSound(volume)
	local sound = self:GetHitStartSound()
	if sound then
		soundutil.PlaySoundWithParams(self.inst, sound, self:_BuildParams(), volume or 100, isautostop)
	end
end
function FoleySounder:PlayKnockbackStartSound(volume)
	local sound = self:GetKnockbackStartSound()
	if sound then
		soundutil.PlaySoundWithParams(self.inst, sound, self:_BuildParams(), volume or 100, isautostop)
	end
end
function FoleySounder:PlayKnockdownStartSound(volume)
	local sound = self:GetKnockdownStartSound()
	local alive = self.inst:IsAlive()
	if sound and alive then
		soundutil.PlaySoundWithParams(self.inst, sound, self:_BuildParams(), volume or 100, isautostop)
	end
end


function FoleySounder:_FindCurrentGroundTile()
	local x, z = self.inst.Transform:GetWorldXZ()
	if TheWorld.zone_grid then
		local tile, tile_name = TheWorld.zone_grid:GetTile({x = x, z = z})
		return tile and tile_name
	else
		return TheWorld.Map:GetNamedTileAtXZ(x, z)
	end
end

function FoleySounder:_TileToSurfaceSound(tile_name)
	return string.lower(tile_name).."_" .. self:GetSize()
end

function FoleySounder:PlayFoleySurfaceSound(volume)
	local tile_name = self:_FindCurrentGroundTile()
	if tile_name ~= nil then
		local surfacesound = self:_TileToSurfaceSound(tile_name)
		if fmodtable.Event[surfacesound] ~= nil then
			surfacesound = fmodtable.Event[surfacesound]
			soundutil.PlaySoundData(self.inst, { fmodevent = surfacesound, volume = volume or 100 })
		else
			TheLog.ch.AudioWarnSpam:print("Trying to play a surface sound which does not exist: "..surfacesound)
		end
	end
end

function FoleySounder:GetSurfaceAsParameter()
	local surface_type_param
	local tile_name = self:_FindCurrentGroundTile()
	if GroundTiles.Tiles[tile_name] then
		surface_type_param = GroundTiles.Tiles[tile_name].audio_param
	else
		-- Default to DIRT
		surface_type_param = GroundTiles.Tiles.DIRT.audio_param
	end
	return surface_type_param
end

function FoleySounder:DebugDrawEntity(ui, panel, colors)
	local cur_tile_name = self:_FindCurrentGroundTile()
	local cur_surfacesound = self:_TileToSurfaceSound(cur_tile_name)
	ui:Value("Current Ground Tile", cur_tile_name)
	ui:Value("Current Surface Sound", cur_surfacesound)
	ui:Value("Current Surface Event", fmodtable.Event[cur_surfacesound] or "<missing>")

	ui:Indent()
	if ui:CollapsingHeader("All Ground Tile Events") then
		local status_color = {
			[true] = WEBCOLORS.PALEGREEN,
			[false] = WEBCOLORS.LEMONCHIFFON,
		}
		for tile_name in iterator.sorted_pairs(GroundTiles.Tiles) do
			local surfacesound = self:_TileToSurfaceSound(tile_name)
			local soundevent = fmodtable.Event[surfacesound]
			ui:PushStyleColor(ui.Col.Text, status_color[not not soundevent])
			ui:Value(surfacesound, soundevent or "<missing>")
			ui:PopStyleColor(1)
		end
	end
	ui:Unindent()
end

-- Error checking functions
function FoleySounder:CheckForSoundEmitter()
	assert(self.inst.SoundEmitter, "FOLEYSOUNDER: Must add a SoundEmitter component before tagging foley sounds on .. ["..string.upper(self.inst.prefab).."]")
end
return FoleySounder
