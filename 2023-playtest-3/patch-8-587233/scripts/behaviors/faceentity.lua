local FaceEntity = Class(BehaviorNode, function(self, inst, target)
	BehaviorNode._ctor(self, "FaceEntity")
	self.inst = inst
	self.target = target
end)

function FaceEntity:Visit()
	TheSim:ProfilerPush(self.name)
	local target

	if self.status == BNState.READY then
		self.status = BNState.RUNNING
	end

	if self.status == BNState.RUNNING then
		local target = self:GetTarget()
		if target ~= nil and target:IsValid() then
			if not self.inst.sg:HasStateTag("busy") then
				local dir = self.inst:GetAngleTo(target)
				if self.inst.components.locomotor ~= nil then
					self.inst.components.locomotor:TurnToDirection(dir)
				else
					self.inst.Transform:SetRotation(dir)
				end
			end

			self:Sleep(self.inst.sg:HasStateTag("moving") and .1 or .5)
		else
			self.status = BNState.FAILED
		end
	end
	TheSim:ProfilerPop()
end

function FaceEntity:GetTarget()
	if type(self.target) == "function" then
		return self.target(self.inst)
	end
	return self.target
end

return FaceEntity
