-- Component used if needed to serialize data on a boss entity with its remote counterparts.
local BossData = Class(function(self, inst)
	self.inst = inst
	self.phase_changed = nil
	self._onphasechangedfn = nil
end)

function BossData:OnNetSerialize()
	local e = self.inst.entity

	e:SerializeBoolean(self.phase_changed);

	if self.phase_changed then
		self.inst.components.bossdata:SetBossPhaseChanged(nil)
	end
end

function BossData:OnNetDeserialize()
	local e = self.inst.entity

	local phasechanged = e:DeserializeBoolean();
	if phasechanged and self._onphasechangedfn then
		self._onphasechangedfn(self.inst)
	end
end

function BossData:SetBossPhaseChanged(state)
	self.phase_changed = state
	if self.phase_changed and self.inst:IsLocal() then
		self._onphasechangedfn(self.inst)
	end
end

function BossData:SetBossPhaseChangedFunction(func)
	self._onphasechangedfn = func
end

return BossData
