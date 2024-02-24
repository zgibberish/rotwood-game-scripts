local AimIndicator = Class(function(self, inst)
	self.inst = inst

	self.pointer = nil
	self.follow_target = nil

	self._onremovepointer = function() self:SetPointer(nil) end
	self._onremovetarget = function() self:SetFollowTarget(nil) end
end)

function AimIndicator:OnRemoveFromEntity()
	if self.pointer ~= nil then
		self.inst:RemoveEventCallback("onremove", self._onremovepointer, self.pointer)
	end
	if self.follow_target ~= nil then
		self.inst:RemoveEventCallback("onremove", self._onremovetarget, self.follow_target)
	end
end

function AimIndicator:SetPointer(pointer)
	if self.pointer ~= pointer then
		if self.pointer ~= nil then
			self.inst:RemoveEventCallback("onremove", self._onremovepointer, self.pointer)
		end
		self.pointer = pointer
		if pointer ~= nil then
			self.inst:ListenForEvent("onremove", self._onremovepointer, pointer)
		end
	end
end

function AimIndicator:SetFollowTarget(target)
	if self.follow_target ~= target then
		if self.follow_target ~= nil then
			self.inst:RemoveEventCallback("onremove", self._onremovetarget, self.follow_target)
			self.inst:StopWallUpdatingComponent(self)
			self.follow_target = nil
		end
		if target ~= nil then
			self.follow_target = target
			self.inst:ListenForEvent("onremove", self._onremovetarget, target)
			self.inst:StartWallUpdatingComponent(self)
			self:OnWallUpdate(0)
		end
	end
end

function AimIndicator:OnWallUpdate(dt)
	self.inst.Transform:SetPosition(self.follow_target.Transform:GetWorldPosition())
	local angle
	if TheFrontEnd:IsRelativeNavigation() or self.follow_target ~= AllPlayers[1] then
		angle = self.follow_target.components.playercontroller:GetAnalogDir() or self.follow_target.Transform:GetFacingRotation()
	else
		local x,z = TheInput:GetWorldXZWithHeight(0)
		if x and z then
			angle = self.inst:GetAngleToXZ(x, z)
		else
			angle = 0
		end
	end

	-- Clamp the angle of the aim indicator to the actual effective angles that a player can attack
	local angle_snap = TUNING.player.attack_angle_clamp
	if math.abs(angle) < 90 then
		-- angle = 0
		angle = math.clamp(angle, -angle_snap, angle_snap)
	elseif math.abs(angle) > 90 then
		-- angle = 180
		if angle < 0 then
			angle = math.clamp(angle, -180, -180 + angle_snap)
		else
			angle = math.clamp(angle, 180 - angle_snap, 180)
		end
	end

	self.inst.Transform:SetRotation(angle)
end

return AimIndicator