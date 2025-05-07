local function OnInterrupted(inst)
	inst:RemoveComponent("spawnfader")
end

local SpawnFader = Class(function(self, inst)
	self.inst = inst
end)

function SpawnFader:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("attacked", OnInterrupted)
	self.inst:RemoveEventCallback("knockback", OnInterrupted)
	self.inst:RemoveEventCallback("knockdown", OnInterrupted)
	self.inst:RemoveEventCallback("death", OnInterrupted)

	if self.inst.components.colormultiplier ~= nil then
		self.inst.components.colormultiplier:PopColor("spawnfader")
	else
		self.inst.AnimState:SetMultColor(1, 1, 1, 1)
	end
end

function SpawnFader:StartSpawn(duration, delay)
	self.t = 0
	self:SetDuration(duration or 1)
	self:SetDelay(delay or 1)

	if self.inst.components.colormultiplier ~= nil then
		self.inst.components.colormultiplier:PushColor("spawnfader", 0, 0, 0, 1)
	else
		self.inst.AnimState:SetMultColor(0, 0, 0, 1)
	end

	self.inst:StartUpdatingComponent(self)
	self.inst:ListenForEvent("attacked", OnInterrupted)
	self.inst:ListenForEvent("knockback", OnInterrupted)
	self.inst:ListenForEvent("knockdown", OnInterrupted)
	self.inst:ListenForEvent("death", OnInterrupted)
end

function SpawnFader:SetDelay(t)
	self:SetDelayTicks(math.ceil(t * SECONDS))
end

function SpawnFader:SetDelayTicks(ticks)
	self.delay = ticks
end

function SpawnFader:SetDuration(t)
	self:SetDurationTicks(math.ceil(t * SECONDS))
end

function SpawnFader:SetDurationTicks(ticks)
	self.duration = ticks
end

function SpawnFader:OnUpdate()
	if self.delay > 0 then
		self.delay = self.delay - 1
	else
		self.t = self.t + 1
		if self.t < self.duration then
			local c = self.t / self.duration
			if self.inst.components.colormultiplier ~= nil then
				self.inst.components.colormultiplier:PushColor("spawnfader", c, c, c, 1)
			else
				self.inst.AnimState:SetMultColor(c, c, c, 1)
			end
		else
			self.inst:RemoveComponent("spawnfader")
		end
	end
end

return SpawnFader
