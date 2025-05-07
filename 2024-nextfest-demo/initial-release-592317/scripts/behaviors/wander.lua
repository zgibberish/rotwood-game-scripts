local CollisionAvoidance = require "behaviors.collisionavoidance"

local Wander = Class(BehaviorNode, function(self, inst, home, maxdist)
	BehaviorNode._ctor(self, "Wander")
	self.inst = inst
	self.home = home
	self.maxdist = maxdist
	self.shouldmove = false
	self.movetime = { min = 2, max = 4 }
	self.standtime = { min = 1, max = 3 }
	self.delayendtime = 0
	self.minwalktime = 0
end)

Wander.UseCollisionAvoidance = true

function Wander:Visit()
	TheSim:ProfilerPush(self.name)
	local t = GetTime()

	if self.status == BNState.READY then
		self.delayendtime = t + self.standtime.min + math.random() * (self.standtime.max - self.standtime.min)
		self.shouldmove = false
		self.status = BNState.RUNNING
	end

	if self.status == BNState.RUNNING then
		if t >= self.delayendtime then
			self.shouldmove = not self.shouldmove
			if self.shouldmove then
				self.minwalktime = t + 1
				self.delayendtime = t + self.movetime.min + math.random() * (self.movetime.max - self.movetime.min)
			else
				self.delayendtime = t + self.standtime.min + math.random() * (self.standtime.max - self.standtime.min)
			end
		end

		local ismoving = self.inst.sg:HasStateTag("moving")
		if self.shouldmove then
			local walkdir, cancel
			local x, z = self:GetHomeXZ()
			if x ~= nil and self.maxdist ~= nil and not self.inst:IsNearXZ(x, z, self.maxdist) then
				--Reached max range
				if ismoving and t >= self.minwalktime then
					--Walked at least 1 second, so just stop
					cancel = true
				else
					--Try keep walking, but change direction to get back in range
					walkdir = self.inst:GetAngleToXZ(x, z) - 20 + math.random() * 40
					cancel = not self:IsValidWalkDirection(walkdir)
				end
			elseif not ismoving then
				--Try start walking
				walkdir = self:PickRandomDir(x, z)
				cancel = not self:IsValidWalkDirection(walkdir)
			else
				--Try continue walking
				local currentWalkDir = self.inst.Transform:GetRotation()
				cancel = not self:IsValidWalkDirection(currentWalkDir)
				if not cancel and Wander.UseCollisionAvoidance and CollisionAvoidance.Enabled then
					local dt = math.min(.2, self.delayendtime - t)
					local newWalkDir = CollisionAvoidance.ApplyCollisionAvoidance(self.inst, currentWalkDir, dt, 1, CollisionAvoidanceOptions.IgnoreVariableSpeed)
					if newWalkDir ~= currentWalkDir then
						if self:IsValidWalkDirection(newWalkDir) then
							self.inst.components.locomotor:WalkInDirection(newWalkDir)
						else
							cancel = true
						end
					end
				end
			end

			if cancel then
				self.delayendtime = 0
				if walkdir ~= nil then
					self.inst.components.locomotor:TurnToDirection(walkdir)
					ismoving = self.inst.sg:HasStateTag("moving")
				elseif ismoving then
					self.inst.components.locomotor:Stop()
					ismoving = self.inst.sg:HasStateTag("moving")
				end
			elseif walkdir ~= nil then
				if Wander.UseCollisionAvoidance and CollisionAvoidance.Enabled then
					local dt = math.min(.2, self.delayendtime - t)
					walkdir = CollisionAvoidance.ApplyCollisionAvoidance(self.inst, walkdir, dt, 1, CollisionAvoidanceOptions.IgnoreVariableSpeed)
				end
				self.inst.components.locomotor:WalkInDirection(walkdir)
				ismoving = self.inst.sg:HasStateTag("moving")
			end
		else
			if ismoving then
				self.inst.components.locomotor:Stop()
				ismoving = self.inst.sg:HasStateTag("moving")
			end
		end

		if not ismoving and not self.shouldmove then
			self:Sleep(self.delayendtime - t)
		else
			self:Sleep(math.min(.2, self.delayendtime - t))
		end
	end
	TheSim:ProfilerPop()
end

--Override this
function Wander:IsValidWalkDirection(dir)
	return true
end

function Wander:GetHomeXZ()
	local home = self.home
	if type(home) == "function" then
		local x, z = home(self.inst)
		if z ~= nil then
			return x, z
		end
		home = x
	end

	if EntityScript.is_instance(home) then
		return home.Transform:GetWorldXZ()
	elseif Vector3.is_instance(home) then
		return home:GetXZ()
	end
end

function Wander:PickRandomDir(homex, homez)
	local forceleft = nil
	local forcedown = nil
	if homex ~= nil then
		local x, z = self.inst.Transform:GetWorldXZ()
		local speed = self.inst.components.locomotor:GetWalkSpeed() or self.inst.components.locomotor:GetRunSpeed()
		local dist = speed * math.min(1, self.delayendtime - GetTime())
		if z > homez then
			if z + dist > homez + self.maxdist then
				forcedown = true
			end
		elseif z < homez then
			if z - dist < homez - self.maxdist then
				forcedown = false
			end
		end
		if x > homex then
			if x + dist > homex + self.maxdist then
				forceleft = true
			end
		elseif x < homex then
			if x - dist < homex - self.maxdist then
				forceleft = false
			end
		end
	end

	local dir
	if forcedown == nil then
		dir = -45 + math.random() * 90
	elseif forcedown then
		dir = -10 + math.random() * 70
	else
		dir = 10 - math.random() * 70
	end
	if forceleft or (forceleft == nil and math.random() < .5) then
		dir = 180 - dir
	end
	return dir
end

return Wander
