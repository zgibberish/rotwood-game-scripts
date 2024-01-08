local RoomLockable = Class(function(self, inst)
	self.inst = inst
	self.locks = {}

	self._onremovesource = function(source) self:RemoveLock(source) end
end)

function RoomLockable:OnRemoveFromEntity()
	for source in pairs(self.locks) do
		if EntityScript.is_instance(source) then
			self.inst:RemoveEventCallback("onremove", self._onremovesource, source)
		end
	end
end

function RoomLockable:IsLocked()
	return TheNet:IsHost()
		and (next(self.locks) ~= nil)
		or self.clientlock
end

function RoomLockable:AddLock(source)
	if not self.locks[source] then
		local waslocked = self:IsLocked()
		self.locks[source] = true
		if EntityScript.is_instance(source) then
			self.inst:ListenForEvent("onremove", self._onremovesource, source)
		end
		if not waslocked then
			if TheNet:IsHost() then
				TheNet:HostSetRoomLockState(true)
				self.inst:PushEvent("room_locked")
			end
		end
	end
end

function RoomLockable:RemoveLock(source)
	if self.locks[source] then
		if EntityScript.is_instance(source) then
			self.inst:RemoveEventCallback("onremove", self._onremovesource, source)
		end
		self.locks[source] = nil
		if not self:IsLocked() then
			if TheNet:IsHost() then
				TheNet:HostSetRoomLockState(false)
				self.inst:PushEvent("room_unlocked")
			end
		end
	end
end

function RoomLockable:SetClientRoomLockState(isLocked)
	if not TheNet:IsHost() then
		if self.clientlock ~= isLocked then
			TheLog.ch.RoomLockable:printf("Client lock state (%s) does not match host (%s) - Updating...",
				self.clientlock, isLocked)
			self.inst:PushEvent(isLocked and "room_locked" or "room_unlocked")
			self.clientlock = isLocked
		end
	end
end

function RoomLockable:RemoveAllLocks()
	for source in pairs(self.locks) do
		self:RemoveLock(source)
	end
end

function RoomLockable:GetAnyLockWithTagFilter(include_tag, exclude_tag)
	for source,_ in pairs(self.locks) do
		if (include_tag and source:HasTag(include_tag)) and (not exclude_tag or not source:HasTag(exclude_tag)) then
			return source
		end
	end
	return nil
end

return RoomLockable
