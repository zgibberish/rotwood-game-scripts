local DebugDraw = require "util.debugdraw"

local SteeringLimit = Class(function(self, inst, steeringLimitFn)
	self.inst = inst
	self.steeringLimitFn = steeringLimitFn
	self.requestedDir = nil
	self.requestedPace = nil
	self.limitedDir = nil
end)

function SteeringLimit:RequestLocomote(dir, pace)
	self.requestedDir = dir
	self.requestedPace = pace
	if self.steeringLimitFn == nil then
		self.limitedDir = dir
	else
		self.limitedDir = self.inst.Transform:GetRotation()
	end
	if self.inst.components.locomotor then
		self.inst:StartUpdatingComponent(self)
	end
end

function SteeringLimit:OnUpdate(dt)
	if not self.requestedDir then
		self.inst:StopUpdatingComponent(self)
		return
	end

	if self.steeringLimitFn ~= nil then
		self.limitedDir = self.steeringLimitFn(self, dt)
		if SteeringLimit.DebugDraw then
			local entX, entZ = self.inst.Transform:GetWorldXZ()
			if self.limitedDir then
				local limitedVel = Vector2.rotate(Vector2(5,0), math.rad(-self.limitedDir))
				DebugDraw.GroundLine(entX, entZ, entX + limitedVel.x, entZ + limitedVel.y, WEBCOLORS.LIME, dt * 4)
			end

			local requestedVel = Vector2.rotate(Vector2(5,0), math.rad(-self.requestedDir))
			DebugDraw.GroundLine(entX, entZ, entX + requestedVel.x, entZ + requestedVel.y, WEBCOLORS.WHITESMOKE, dt * 4)
		end
		if SteeringLimit.DebugText then
			TheLog.ch.AI:printf("SteeringLimit: reqDir=%1.2f limitedDir=%1.2f", self.requestedDir, self.limitedDir)
		end
	end

	if self.requestedPace == "walk" then
		self.inst.components.locomotor:WalkInDirection(self.limitedDir)
	else
		self.inst.components.locomotor:RunInDirection(self.limitedDir)
	end

	if self.requestedDir == self.limitedDir then
		self.inst:StopUpdatingComponent(self)
	end
end

function SteeringLimit.ConstantAngularRotationLimiter(cmp, dt, rotationLimit)
	if not cmp.inst.sg:HasStateTag("moving") then
		return cmp.requestedDir
	end

	local angleDiff = cmp.requestedDir - cmp.limitedDir
	while angleDiff <= -180 do
		angleDiff = angleDiff + 360
	end
	while angleDiff >= 180 do
		angleDiff = angleDiff - 360
	end

	local maxRotationThisFrame = rotationLimit * dt
	if math.abs(angleDiff) < maxRotationThisFrame then
		return cmp.requestedDir
	end

	local sign = angleDiff >= 0 and 1 or -1
	local newLimitedDir = math.clamp(
		cmp.limitedDir + sign * maxRotationThisFrame,
		cmp.limitedDir - maxRotationThisFrame,
		cmp.limitedDir + maxRotationThisFrame)
	return newLimitedDir
end

SteeringLimit.DebugDraw = false
SteeringLimit.DebugText = false

return SteeringLimit
