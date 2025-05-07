local TargetLastAttacker = Class(BehaviorNode, function(self, inst)
	BehaviorNode._ctor(self, "TargetLastAttacker")
	self.inst = inst
	dbassert(inst.components.combat ~= nil)
end)

function TargetLastAttacker:Visit()
	TheSim:ProfilerPush(self.name)
	if not self.inst.components.combat then
		self.status = BNState.FAILED
		self:Sleep(10)
		return
	end

	local lastAttacker = self.inst.components.combat:GetLastAttacker()
	if not lastAttacker then
		self.status = BNState.FAILED
		self:Sleep(1)
		TheSim:ProfilerPop()
		return
	end

	if self.status == BNState.READY
		and lastAttacker:IsValid() and lastAttacker:IsAlive() and not lastAttacker:IsInLimbo()
		and self.inst.components.combat:CanTargetEntity(lastAttacker) then
		self.inst.components.combat:SetTarget(lastAttacker)
		self.inst.components.combat:ClearLastAttacker()
		self.status = BNState.SUCCESS
	else
		self.status = BNState.FAILED
	end

	self:Sleep(1)
	TheSim:ProfilerPop()
end

return TargetLastAttacker
