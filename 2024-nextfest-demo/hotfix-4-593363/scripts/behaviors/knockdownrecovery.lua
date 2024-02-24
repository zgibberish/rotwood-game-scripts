local KnockdownRecovery = Class(BehaviorNode, function(self, inst)
	BehaviorNode._ctor(self, "KnockdownRecovery")
	self.inst = inst
end)

function KnockdownRecovery:Visit()
	TheSim:ProfilerPush(self.name)
	local isknockdown = self.inst.sg:HasStateTag("knockdown")

	if self.status == BNState.READY then
		self.status = isknockdown and BNState.RUNNING or BNState.FAILED
	end

	if self.status == BNState.RUNNING then
		if not isknockdown then
			self.status = BNState.FAILED
			self:Sleep(1)
		else
			local ticks = self.inst.components.timer:GetTicksRemaining("knockdown")
			if ticks ~= nil then
				self:SleepTicks(math.min(ticks, 15 * ANIM_FRAMES))
			else
				self.inst:PushEvent("getup")
				self:Sleep(.5)
			end
		end
	end
	TheSim:ProfilerPop()
end

return KnockdownRecovery
