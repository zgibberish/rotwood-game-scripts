local DebugDraw = require "util.debugdraw"
local lume = require "util.lume"

local DebugAudio = Class(function(self)
	self.debugentityrequired = false
	self.mindrawtime = 0.5
	self.paths = {}
	self:SetEnabled(false)
end)

DebugAudio.Draw3DFlags =
{
	FullEventPath = 0x00000001, -- i.e. display "player/weapon/hammer/hammer_atk_1" instead of just "hammer_atk_1"
	SoundSize     = 0x00000002, -- draws a circle to indicate the limit when a sound is fully directional (as opposed to "enveloped")
	MinMaxDist    = 0x00000004, -- draws two circles to indicate the minimum and maximum audible distances
}

DebugAudio.Colors =
{
	EventTextLowCount = WEBCOLORS.CYAN,
	EventTextHighCount = WEBCOLORS.WHITE,
	EventMaxDist = WEBCOLORS.ROYALBLUE,
	EventMinDist = WEBCOLORS.MEDIUMTURQUOISE,
	EventSoundSize = WEBCOLORS.VIOLET,
	ListenerShadow = WEBCOLORS.LIGHTGRAY,
	ListenerX = WEBCOLORS.RED,
	ListenerY = WEBCOLORS.GREEN,
	ListenerZ = WEBCOLORS.BLUE,
}

DebugAudio.Draw3DFlagsDefault =
	DebugAudio.Draw3DFlags.MinMaxDist | DebugAudio.Draw3DFlags.SoundSize

function DebugAudio:SetEnabled(enabled)
	self.enabled = enabled
	-- TODO: victorc -- chicken/egg issue with this
	self.draw3dflags = DebugAudio.Draw3DFlagsDefault
	TheAudio:SetDebugVisualize3DSound(enabled)
end

function DebugAudio:IsEnabled()
	return self.enabled
end

function DebugAudio:Toggle()
	self:SetEnabled(not self.enabled)
end

function DebugAudio:IsDebugEntityRequired()
	return self.debugentityrequired
end

-- Set to true to require a debug entity to be selected in order to display 3D audio events.
-- Useful to focus on a single entity.
function DebugAudio:SetDebugEntityRequired(enabled)
	self.debugentityrequired = enabled
end

function DebugAudio:GetDraw3DFlags()
	return self.draw3dflags
end

-- Set the draw flags for 3D audio event visualization
-- See DebugAudio.Draw3DFlags
-- Flags can be bitwise-OR'ed together
function DebugAudio:SetDraw3DFlags(flags)
	self.draw3dflags = flags
end

function DebugAudio:DrawListener(pos, forward, up)
	local right = Vector3.cross(forward, up)

	TheDebugRenderer:WorldLine({pos.x, pos.y, pos.z}, {pos.x + forward.x, pos.y + forward.y, pos.z + forward.z}, DebugAudio.Colors.ListenerX)
	TheDebugRenderer:WorldLine({pos.x, pos.y, pos.z}, {pos.x + up.x, pos.y + up.y, pos.z + up.z}, DebugAudio.Colors.ListenerY)
	TheDebugRenderer:WorldLine({pos.x, pos.y, pos.z}, {pos.x + right.x, pos.y + right.y, pos.z + right.z}, DebugAudio.Colors.ListenerZ)
	-- ground circle is acts like a shadow to help reference a floating position
	DebugDraw.GroundCircle(pos.x, pos.z, 0.25, DebugAudio.Colors.ListenerShadow)
	-- TheLog.ch.Audio:printf("Audio Listener Position: (%1.2f, %1.2f, %1.2f)", pos.x, pos.y, pos.z)
	-- TheLog.ch.Audio:printf("Audio Listener Forward: (%1.2f, %1.2f, %1.2f)", forward.x, forward.y, forward.z)
end

local function SetPathInternal(debugaudio, name, elements)
	local paramtype = type(elements)
	if paramtype == "string" then
		if elements ~= "" then
			elements = {elements}
		else
			elements = {}
		end
	elseif paramtype ~= "table" then
		elements = {}
	end

	debugaudio.paths[name] = {}
	for _i,v in ipairs(elements) do
		debugaudio.paths[name][v:lower()] = true
	end
	TheLog.ch.Audio:printf("%s path elements for debug visualization:", name)
	dumptable(debugaudio.paths[name])
end

-- Set the audio event path elements you want to see
-- All audio events need to have at least one of the required path elements when it is non-empty
-- Utilizes lua string.match() syntax
-- Supports elements as a single string or table of strings
-- Examples:
--   TheDebugAudio:SetRequiredPath("hammer")
--   TheDebugAudio:SetRequiredPath({"hammer", "player"})
function DebugAudio:SetRequiredPath(elements)
	SetPathInternal(self, "required", elements)
end

-- Set the audio event path elements you want to ignore
-- Any audio event that matches one or more ignored path elements is omitted when it is non-empty
-- Utilizes lua string.match() syntax
-- Supports elements as a single string or table of strings like SetRequiredPath
function DebugAudio:SetIgnoredPath(elements)
	SetPathInternal(self, "ignored", elements)
end

function DebugAudio:GetMinDrawTime()
	return self.mindrawtime
end

function DebugAudio:SetMinDrawTime(seconds)
	self.mindrawtime = seconds
end

-- data - table with entityguid,x,y,z,eventname,length(ms),soundsize,mindist,maxdist
-- see native SoundEmitterComponent::DebugVisualize3DSound and FMOD Studio documentation
function OnDebugVisualize3DSound(data)
	local fulleventpath = data.eventname:lower()
	local eventpath = fulleventpath:split("/")

	local debugent = GetDebugEntity()
	if debugent and debugent.GUID ~= data.entityguid then
		return
	end

	local draw3dflags = 0xFFFFFFFF
	if TheDebugAudio then
		if TheDebugAudio:IsDebugEntityRequired() and not debugent then
			return
		end

		-- filter based on required, then ignored keywords in event paths
		if TheDebugAudio.paths["required"] then
			local isMatchedPattern = false
			for reqPattern, _v in pairs(TheDebugAudio.paths["required"]) do
				for _i, pathElement in ipairs(eventpath) do
					if string.match(pathElement, reqPattern) ~= nil then
						isMatchedPattern = true
						break
					end
				end
				if isMatchedPattern then
					break;
				end
			end

			if not isMatchedPattern then
				return
			end
		end

		if TheDebugAudio.paths["ignored"] then
			for _i, pathElement in ipairs(eventpath) do
				for ignoredPattern, _v in pairs(TheDebugAudio.paths["ignored"]) do
					if string.match(pathElement, ignoredPattern) then
						return
					end
				end
			end
		end

		draw3dflags = TheDebugAudio:GetDraw3DFlags()
	end

	local otherdebugaudio = TheSim:FindEntitiesXZ(data.x, data.z, 2, {"DEBUGAUDIO", "CLASSIFIED"})
	local text = (draw3dflags & DebugAudio.Draw3DFlags.FullEventPath) ~= 0
		and fulleventpath
		or eventpath[#eventpath]
	local lifetime = data.length / 1000 >= TheDebugAudio:GetMinDrawTime()
		and data.length / 1000
		or TheDebugAudio:GetMinDrawTime()
	local textsize = 24

	local LerpRGB = function(ca, cb, t)
		local result = {}
		for i=1,3 do
			result[i] = lume.lerp(ca[i], cb[i], t)
		end
		result[4] = 1 --ignore alpha blending with this implementation
		return result
	end

	-- add y-offset to new world text if nearby ones exist
	-- to avoid overwriting into the same visual space
	local overlapworldoffset = 0.4
	local maxnearbyaudio = 4
	local nearbydebugaudio = otherdebugaudio and #otherdebugaudio or 0
	-- lerp the colours so it's easier to read multiple events at once
	local textcolor = LerpRGB(
		DebugAudio.Colors.EventTextLowCount,
		DebugAudio.Colors.EventTextHighCount,
		lume.clamp(nearbydebugaudio / maxnearbyaudio, 0, 1))
	local textent = DebugDraw.WorldText(
		text,
		Vector3(data.x, data.y + #otherdebugaudio * overlapworldoffset, data.z),
		textsize,
		textcolor,
		lifetime)
	textent:AddTag("DEBUGAUDIO")

	if (draw3dflags & DebugAudio.Draw3DFlags.SoundSize) ~= 0 then
		DebugDraw.GroundProjectedCircle(
			data.x, data.y, data.z,
			data.soundsize, DebugAudio.Colors.EventSoundSize, 1, lifetime)
	end

	if (draw3dflags & DebugAudio.Draw3DFlags.MinMaxDist) ~= 0 then
		DebugDraw.GroundProjectedCircle(data.x, data.y, data.z,
			data.mindist, DebugAudio.Colors.EventMinDist, 1, lifetime)
		DebugDraw.GroundProjectedCircle(data.x, data.y, data.z,
			data.maxdist, DebugAudio.Colors.EventMaxDist, 1, lifetime)
	end
end

return DebugAudio
