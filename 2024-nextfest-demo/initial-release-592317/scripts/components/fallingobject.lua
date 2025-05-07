local FallingObject = Class(function(self, inst)
	self.inst = inst

	self.velocity = Vector3(0,0,0)
	self.gravity = -9.81

	self.horizontalSpeed = 0

	self.onlaunchfn = nil
	self.onlandfn = nil
	self.onmissfn = nil
	self.y_offset = 0
	self.usehigharc = true
end)

function FallingObject:GetDebugString()
	return tostring(self.velocity)
end

function FallingObject:SetHorizontalSpeed(speed)
    self.horizontalSpeed = speed
end

function FallingObject:SetLaunchHeight(height)
	local x, y, z = self.inst.Transform:GetWorldPosition()
	self.inst.Transform:SetPosition(x, y + height, z)
end

function FallingObject:SetLaunchOffset(offset)
    self.launchoffset = offset -- x is facing, y is height, z is ignored
end

function FallingObject:SetOnLaunch(fn)
	self.onlaunchfn = fn
end

function FallingObject:SetOnLand(fn)
	self.onlandfn = fn
end

function FallingObject:SetGravity(gravity)
	self.gravity = gravity
end

function FallingObject:GetHorizontalVelocity(distance)
	return ((self.gravity * distance)/2)/self.horizontalSpeed
end

function FallingObject:Launch(attacker)
	local pos = self.inst:GetPosition()
	self.attacker = attacker

	local offset = self.launchoffset or Vector3.zero
	if attacker ~= nil and offset ~= nil then
		local facing_angle = math.rad(attacker.Transform:GetRotation())

		pos.x = pos.x + offset.x * math.cos(facing_angle)
		pos.y = pos.y + offset.y
		pos.z = pos.z - offset.x * math.sin(facing_angle)
	end

	self.inst.Transform:SetPosition(pos:Get())

	if self.onlaunchfn then
		self.onlaunchfn(self.inst)
	end

	self.inst:StartUpdatingComponent(self)
end

function FallingObject:Land()
	self.inst:StopUpdatingComponent(self)
	self.velocity = Vector3.zero:clone()
	if self.onlandfn then
		self.onlandfn(self.inst, self.attacker)
	end

	self.inst:PushEvent("landed")
end

function FallingObject:OnUpdate(dt)
	local pos = Vector3(self.inst.Transform:GetWorldPosition())

	local new_pos = pos + (self.velocity * dt)

	new_pos.y = math.max(new_pos.y, 0)

	self.inst.Transform:SetPosition(new_pos.x, new_pos.y, new_pos.z)

	if new_pos.y <= 0 and self.velocity.y <= 0 then
		self:Land()
	else
		self.velocity.x = self.velocity.x + (self.horizontalSpeed * dt)
		self.velocity.y = self.velocity.y + (self.gravity * dt)
	end
end

return FallingObject