local CollisionAvoidance = require "behaviors.collisionavoidance"

local MaxVisits = 100

local Leash = Class(BehaviorNode, function(self, inst, target, maxdist, mindist, shouldrun)
	BehaviorNode._ctor(self, "Leash")
	self.inst = inst
	self.target = target
	self.maxdist = maxdist
	self.mindist = mindist
	self.shouldrun = shouldrun
	-- auto-fail if target XZ can't be reached in x number of updates
	-- with a sleep time of 0.1s, this gives it ~10 seconds to reach its destination
	self.visitsleft = MaxVisits
end)

function Leash:Visit()
	TheSim:ProfilerPush(self.name)
	local x, z

	if self.status == BNState.READY then
		x, z = self:GetTargetXZ()

		-- First, see if we should be leashing because we are too far away from the leash position.
		local shouldleash
		if x ~= nil then
			local maxdist = self:GetMaxDist()
			if maxdist ~= nil then
				-- If we are not within maxdist, we should be leashing.
				-- If we are within maxdist, don't leash: we've successfully reached our leash position.
				shouldleash = not self.inst:IsNearXZ(x, z, maxdist)
			end
		end

		if shouldleash then
			self.status = BNState.RUNNING
		elseif shouldleash == false then
			self.status = BNState.SUCCESS
			if self.inst.sg:HasStateTag("moving") then
				self.inst.components.locomotor:Stop()
			end
		else
			self.status = BNState.FAILED
		end
	end

	-- We haven't succeeded in reaching our leash position.
	if self.status == BNState.RUNNING then
		if x == nil then
			x, z = self:GetTargetXZ()
		end

		local shouldleash
		if x ~= nil then
			local mindist = self:GetMinDist()
			if mindist ~= nil then
				shouldleash = not self.inst:IsNearXZ(x, z, mindist)
			end
		end

		if shouldleash then
			local dir = self.inst:GetAngleToXZ(x, z)
			if CollisionAvoidance.Enabled then
				local speedmultbonus = 0
				local options = not self:ShouldRun() and CollisionAvoidanceOptions.ForceUseWalkSpeed or 0
				self.inst.components.locomotor:AddSpeedMult("collisionavoidance", 0)
				dir, speedmultbonus = CollisionAvoidance.ApplyCollisionAvoidance(self.inst, dir, 0.1, nil, options)
				self.inst.components.locomotor:AddSpeedMult("collisionavoidance", speedmultbonus)
			end
			if self:ShouldRun() then
				self.inst.components.locomotor:RunInDirection(dir)
			else
				self.inst.components.locomotor:WalkInDirection(dir)
			end

			self:Sleep(.1)

			self.visitsleft = self.visitsleft - 1
			if self.visitsleft <= 0 then
				self.visitsleft = MaxVisits
				self.status = BNState.FAILED
			end
		elseif shouldleash == false then
			self.visitsleft = MaxVisits
			self.status = BNState.SUCCESS
			if self.inst.sg:HasStateTag("moving") then
				self.inst.components.locomotor:Stop()
			end
		else
			self.visitsleft = MaxVisits
			self.status = BNState.FAILED
		end
	end
	TheSim:ProfilerPop()
end

function Leash:GetTargetXZ()
	local x, z = self.target, nil
	if type(x) == "function" then
		x, z = x(self.inst)
	end
	if x ~= nil then
		if z ~= nil then
			return x, z
		elseif EntityScript.is_instance(x) then
			CollisionAvoidance.SetIgnoreList(self.inst, { self.target })
			return x.Transform:GetWorldXZ()
		elseif Vector3.is_instance(x) then
			return x:GetXZ()
		end
	end
end

function Leash:GetMaxDist()
	if type(self.maxdist) == "function" then
		return self.maxdist(self.inst)
	end
	return self.maxdist
end	

function Leash:GetMinDist()
	if type(self.mindist) == "function" then
		return self.mindist(self.inst)
	end
	return self.mindist
end

function Leash:ShouldRun()
	if type(self.shouldrun) == "function" then
		return self.shouldrun(self.inst)
	end
	return self.shouldrun
end

return Leash
