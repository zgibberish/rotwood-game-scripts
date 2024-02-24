local RoomLock = Class(function(self, inst)
	self.inst = inst

	TheWorld.components.roomlockable:AddLock(inst)
end)

function RoomLock:OnRemoveFromEntity()
	if TheWorld then -- can be invalid with dev reload and nosimreset
		TheWorld.components.roomlockable:RemoveLock(self.inst)
	end
end

function RoomLock:OnRemoveEntity()
	self:OnRemoveFromEntity()
end

return RoomLock
