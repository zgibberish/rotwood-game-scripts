local CameraShake = require "camerashake"
local DebugAudio = require "util.debugaudio"
local camerautil = require "util.camerautil"
local lume = require "util.lume"

local FollowCamera = Class(function(self, inst)
	self.inst = inst or CreateEntity()
	self.target = nil
	self.baseoffset = Vector3(0, 1.5, 0)
	self.offset = Vector3(0, 0, 0)
	self.currentpos = Vector3(self.offset:Get())
	self.currentdist = 40
	self.targetdist = 40
	self.zoom = 0
	self.fov = 30
	self.pitchrad = camerautil.defaults.pitchrad
	self.pitch = math.deg(self.pitchrad)
	self.pangain = 4
	self.zoomgain = 2
	self.shake = nil
	self.rumbles = {}

	self._onremove_target = function()
		TheLog.ch.Camera:print("Camera target was removed. Clearing...")
		self:SetTarget(nil)
	end

	if TheDebugAudio == nil then
		TheDebugAudio = DebugAudio()
	end
end)

function FollowCamera:Shake(type, duration, speed, scale, inputdevicefeedback)
	-- CameraShake does nothing on creation. Create it always to define rumble.
	local shake = CameraShake(type, duration, speed, scale)
	if TheGameSettings:Get("graphics.screen_shake") then
		self.shake = shake
	end

	-- inputdevicefeedback is a bitfield for whether each device wants rumble
	inputdevicefeedback = inputdevicefeedback or 0
	local i = 0
	while inputdevicefeedback ~= 0 do
		if i > 4 then return end -- emergency sanity exit
		if inputdevicefeedback & 0x1 == 1 then
			local rumble_speed = shake.duration
			local amplitude = math.max(0, math.min(shake.scale * 0.5, 1))
			local r = TheInput:PlayRumble(i, "VIBRATION_CAMERA_SHAKE", rumble_speed, amplitude)
			if r then
				table.appendarrays(self.rumbles, r)
				-- else rumble is disabled
			end
		end
		i = i + 1
		inputdevicefeedback = inputdevicefeedback >> 1
	end
end

function FollowCamera:StopShake()
	self.shake = nil
	TheInput:KillRumble_Predicate(function(v)
		return lume.find(self.rumbles, v.rumble.id)
	end)
	lume.clear(self.rumbles)
end

function FollowCamera:GetTarget()
	return self.target
end

function FollowCamera:SetTarget(target)
	if self.target then
		self.inst:RemoveEventCallback("onremove", self._onremove_target, self.target)
	end

	self.target = target

	if self.target then
		self.inst:ListenForEvent("onremove", self._onremove_target, self.target)
	end
end

function FollowCamera:GetCurrentPosWithoutOffset()
	return self.currentpos - self.baseoffset - self.offset
end

function FollowCamera:GetOffset()
	return self.offset
end

function FollowCamera:SetOffset(x, y, z)
	assert(not isnan(x) and not isnan(y) and not isnan(z), "FollowCamera:SetOffset attempted to set nan value.")
	self.offset.x, self.offset.y, self.offset.z = x, y, z
end

function FollowCamera:GetDistance()
	return self.targetdist
end

function FollowCamera:SetDistance(dist)
	self.targetdist = dist
end

function FollowCamera:GetZoom()
	return self.zoom
end

function FollowCamera:SetZoom(zoom)
	self.zoom = zoom
end

function FollowCamera:GetFOV()
	return self.fov
end

function FollowCamera:SetFOV(fov)
	self.fov = fov
end

function FollowCamera:GetPitch()
	return self.pitch
end

function FollowCamera:SetPitch(pitch)
	self.pitch = ReduceAngle(pitch)
	self.pitchrad = math.rad(self.pitch)
end

function FollowCamera:Apply()
	--dir
	local dx = 0
	local dy, dz
	if self.pitch == 90 then
		--Overhead camera is useful, so make it exact
		dy, dz = -1, 0
	else
		dy = -math.sin(self.pitchrad)
		dz = math.cos(self.pitchrad)
	end
	assert(not isnan(dx) and not isnan(dy) and not isnan(dz), "Camera direction has a nan value.")
	TheSim:SetCameraDir(dx, dy, dz)

	--pos
	assert(not isnan(self.currentpos.x) and not isnan(self.currentpos.y) and not isnan(self.currentpos.z), "Camera position has a nan value.")
	TheSim:SetCameraPos(
		self.currentpos.x - dx * self.currentdist,
		self.currentpos.y - dy * self.currentdist,
		self.currentpos.z - dz * self.currentdist
	)

	--up
	local ux = 0
	local uy = dz
	local uz = -dy

	TheSim:SetCameraUp(ux, uy, uz)
	TheSim:SetCameraFOV(self.fov)

	local listenerpos = self.currentpos

	--listen dist
	local listendist = .010 * self.currentdist
	TheAudio:SetListener(
		dx * listendist + listenerpos.x,
		dy * listendist + listenerpos.y,
		dz * listendist + listenerpos.z,
		dx, dy, dz,
		ux, uy, uz
	)

	if TheDebugAudio and TheDebugAudio:IsEnabled() then
		-- this needs to match what's in the SetListener call
		local pos =	Vector3(dx * listendist + listenerpos.x, dy * listendist + listenerpos.y, dz * listendist + listenerpos.z)
		local forward = Vector3(dx, dy, dz)
		local up = Vector3(ux, uy, uz)
		TheDebugAudio:DrawListener(pos, forward, up)
	end
end

function FollowCamera:Snap()
	--pan
	local x, y, z = 0, 0, 0
	if self.target ~= nil then
		if self.target.components.focalpoint ~= nil then
			self.target.components.focalpoint:OnUpdate(0)
		end
		x, y, z = self.target.Transform:GetWorldPosition()
		-- Not sure why the position is ind.
		dbassert(not isbadnumber(x), "Cannot Snap until after target has a valid position (move around first).")
	end
	self.currentpos.x = x + self.baseoffset.x + self.offset.x
	self.currentpos.y = y + self.baseoffset.y + self.offset.y
	self.currentpos.z = z + self.baseoffset.z + self.offset.z

	--zoom
	self.currentdist = self.targetdist + self.zoom

	self:Apply()
end

local function CameraLerp(lower, upper, t)
	return (t > 1 and upper)
		or (t <= 0 and lower)
		or lower * (1 - t) + upper * t
end

function FollowCamera:Update(dt)
	--pan
	local pangain = dt * self.pangain
	local x, y, z = 0, 0, 0
	local dist
	if self.target ~= nil then
		x, y, z = self.target.Transform:GetWorldPosition()
		dist = self.target.desired_camera_distance
	end
	if dist then
		self:SetDistance(dist)
	end
	self.currentpos.x = CameraLerp(self.currentpos.x, x + self.baseoffset.x + self.offset.x, pangain)
	self.currentpos.y = CameraLerp(self.currentpos.y, y + self.baseoffset.y + self.offset.y, pangain)
	self.currentpos.z = CameraLerp(self.currentpos.z, z + self.baseoffset.z + self.offset.z, pangain)

	--zoom
	self.currentdist = CameraLerp(self.currentdist, self.targetdist + self.zoom, dt * self.zoomgain)

	--camera shake
	if self.shake ~= nil then
		local shakeOffset = self.shake:Update(dt)
		if shakeOffset ~= nil then
			self.currentpos.x = self.currentpos.x + shakeOffset.x
			self.currentpos.y = self.currentpos.y + shakeOffset.y
		else
			self.shake = nil
			lume.clear(self.rumbles)
		end
	end

	self:Apply()
end

return FollowCamera
