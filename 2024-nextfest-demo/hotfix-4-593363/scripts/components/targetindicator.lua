local TargetIndicator = Class(function(self, inst)
	self.inst = inst
	self.radius = 0
	self.pointer = nil
	self.target = nil

	self._onremovepointer = function() self:SetPointer(nil) end
	self._onremovetarget = function() self:SetTarget(nil) end
end)

function TargetIndicator:OnRemoveFromEntity()
	if self.pointer ~= nil then
		self.inst:RemoveEventCallback("onremove", self._onremovepointer, self.pointer)
	end
	if self.target ~= nil then
		self.inst:RemoveEventCallback("onremove", self._onremovetarget, self.target)
	end
end

function TargetIndicator:SetRadius(radius)
	if self.radius ~= radius then
		self.radius = radius
		self:ApplyRadiusInternal()
	end
end

function TargetIndicator:ApplyRadiusInternal()
	if self.pointer ~= nil then
		self.pointer.Transform:SetPosition(self.radius, 0, 0)
	end
end

function TargetIndicator:SetPointer(pointer)
	if self.pointer ~= pointer then
		if self.pointer ~= nil then
			self.inst:RemoveEventCallback("onremove", self._onremovepointer, self.pointer)
		end
		self.pointer = pointer
		if pointer ~= nil then
			self.inst:ListenForEvent("onremove", self._onremovepointer, pointer)
			self:ApplyRadiusInternal()
		end
	end
end

function TargetIndicator:SetTarget(target)
	if self.target ~= target then
		if self.target ~= nil then
			self.inst:RemoveEventCallback("onremove", self._onremovetarget, self.target)
			self.inst:StopWallUpdatingComponent(self)
			self.target = nil
		end
		if target ~= nil then
			self.target = target
			self.inst:ListenForEvent("onremove", self._onremovetarget, target)
			self.inst:StartWallUpdatingComponent(self)
			self:OnWallUpdate(0)
		end
	end
end

function TargetIndicator:OnWallUpdate(dt)
	self.inst:Face(self.target)
end

return TargetIndicator
