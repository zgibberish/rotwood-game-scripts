local StandStill = Class(BehaviorNode, function(self, inst)
	BehaviorNode._ctor(self, "StandStill")
	self.inst = inst
end)

function StandStill:Visit()
	TheSim:ProfilerPush(self.name)
	if self.status == BNState.READY then
		self.status = BNState.RUNNING
	end

	if self.status == BNState.RUNNING then
		if self.inst.sg:HasStateTag("moving") then
			self.inst.components.locomotor:Stop()
		end

		self:Sleep(.5)
	end
	TheSim:ProfilerPop()
end

return StandStill
