local LocoMotor = Class(function(self, inst)
	self.inst = inst
	self.base_walkspeed = nil
	self.base_runspeed = nil
	self.speed_mults = {} -- TODO @chrisp #meta - implement in terms of AddSourceModifiers
	self.total_speed_mult = 1

    self._new_run_fn =  function() self:ClearAllModifiers() end
    self.inst:ListenForEvent("start_new_run", self._new_run_fn)
    self.inst:ListenForEvent("end_current_run", self._new_run_fn)
end)

function LocoMotor:SetWalkSpeed(speed)
	self.base_walkspeed = speed
end

function LocoMotor:SetRunSpeed(speed)
	self.base_runspeed = speed
end

function LocoMotor:CanWalk()
	return self.base_walkspeed ~= nil
end

function LocoMotor:GetBaseWalkSpeed()
	return self.base_walkspeed
end

function LocoMotor:GetWalkSpeed()
	return self.base_walkspeed * self.total_speed_mult
end

function LocoMotor:CanRun()
	return self.base_runspeed ~= nil
end

function LocoMotor:GetBaseRunSpeed()
	return self.base_runspeed
end

function LocoMotor:GetRunSpeed()
	return self.base_runspeed * self.total_speed_mult
end

function LocoMotor:GetTotalSpeedMult()
	return self.total_speed_mult
end

function LocoMotor:Stop()
	if self.inst:IsLocal() then
		self.inst:PushEvent("locomote", { move = false })
	end
end

function LocoMotor:WalkInDirection(dir)
	if self.inst:IsLocal() then
		self.inst:PushEvent("locomote", { move = true, run = false, dir = dir })
	end
end

function LocoMotor:RunInDirection(dir)
	if self.inst:IsLocal() then
		self.inst:PushEvent("locomote", { move = true, run = true, dir = dir })
	end
end

function LocoMotor:TurnToDirection(dir)
	if self.inst:IsLocal() then
		self.inst:PushEvent("locomote", { move = false, dir = dir })
	end
end

function LocoMotor:UpdateTotalSpeedMult(force_push_event)
	force_push_event = force_push_event or false
	local total = 1
	for id, bonus in pairs(self.speed_mults) do
		total = total + bonus
	end
	local old_total = self.total_speed_mult
	self.total_speed_mult = math.max(total, 0)

	if force_push_event or old_total ~= self.total_speed_mult then
		self.inst:PushEvent("speed_mult_changed", { new = self.total_speed_mult, old = old_total })
	end
end

function LocoMotor:AddSpeedMult(source_id, bonus)
	self.speed_mults[source_id] = bonus
	self:UpdateTotalSpeedMult()
end

function LocoMotor:RemoveSpeedMult(source_id)
	self.speed_mults[source_id] = nil
	self:UpdateTotalSpeedMult()
end

function LocoMotor:ClearAllModifiers()
	self.speed_mults = {}
	self:UpdateTotalSpeedMult()
end

function LocoMotor:NetSetTotalSpeedMult(value)
	self.total_speed_mult = value
end

function LocoMotor:OnSave()
	local data
	if next(self.speed_mults) then
		data = {}
		data.speed_modifiers = deepcopy(self.speed_mults)
	end
	return data ~= nil and data or nil
end

function LocoMotor:OnLoad(data)
	if data.speed_modifiers then
		self.speed_mults = deepcopy(data.speed_modifiers) or {}
		self:UpdateTotalSpeedMult()
	end
end

return LocoMotor
