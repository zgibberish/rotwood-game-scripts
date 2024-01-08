local RoomLock = Class(function(self, inst)
	self.inst = inst

	TheWorld.components.roomlockable:AddLock(inst)
end)

function RoomLock:OnRemoveFromEntity()
	TheWorld.components.roomlockable:RemoveLock(self.inst)
end

function RoomLock:OnRemoveEntity()
	self:OnRemoveFromEntity()
end

return RoomLock
