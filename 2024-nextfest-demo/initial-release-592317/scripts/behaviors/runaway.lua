local RunAway = Class(BehaviorNode, function(self, inst, seedist, safedist, fn, andtags, nottags, ortags)
	BehaviorNode._ctor(self, "RunAway")
	self.inst = inst
	self.seedist = seedist
	self.safedistsq = safedist * safedist
	self.fn = fn
	self.andtags = andtags
	self.nottags = nottags
	self.ortags = ortags
	self.target = nil
	self.dir = nil
	self.dirtime = nil
end)

function RunAway:Visit()
	TheSim:ProfilerPush(self.name)
	if self.status == BNState.READY then
		self.target = nil
		local x, z = self.inst.Transform:GetWorldXZ()
		for i, v in ipairs(TheSim:FindEntitiesXZ(x, z, self.seedist, self.andtags, self.nottags, self.ortags)) do
			if v ~= self.inst and v:IsVisible() and (self.fn == nil or self.fn(self.inst, v)) then
				self.target = v
				break
			end
		end
		self.dir = nil
		self.status = self.target ~= nil and BNState.RUNNING or BNState.FAILED
	end

	if self.status == BNState.RUNNING then
		if self.target == nil or not self.target:IsValid() then
			self.status = BNState.FAILED
		else
			local x, z = self.inst.Transform:GetWorldXZ()
			local x1, z1 = self.target.Transform:GetWorldXZ()
			local dx = x1 - x
			local dz = z1 - z
			if dx * dx + dz * dz < self.safedistsq then
				local t = GetTime()
				if self.dir == nil or self.dirtime < t then
					if dx ~= 0 or dz ~= 0 then
						self.dir = math.deg(math.atan(dz, -dx))
						self.dirtime = t + 1
					elseif self.dir == nil then
						self.dir = self.inst.Transform:GetRotation()
						self.dirtime = t
					end
				end
				self.inst.components.locomotor:RunInDirection(self.dir)
			else
				self.status = BNState.SUCCESS
				if self.inst.sg:HasStateTag("moving") then
					self.inst.components.locomotor:Stop()
				end
			end

			self:Sleep(.25)
		end
	end
	TheSim:ProfilerPop()
end

return RunAway
