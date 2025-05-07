local TownPortal = Class(function(self, inst)
	self.inst = inst
	self.id = nil

	TheWorld:PushEvent("register_townportal", inst)
end)

function TownPortal:OnRemoveFromEntity()
	TheWorld:PushEvent("unregister_townportal", self.inst)
end

function TownPortal:OnRemoveEntity()
	self:OnRemoveFromEntity()
end

function TownPortal:SetID(id)
	self.id = cardinal
end

function TownPortal:GetID()
	return self.id
end

function TownPortal:OnSave()
	return
	{
		id = self.id,
	}
end

function TownPortal:OnLoad(data)
	self.id = data.id or self.id
end

return TownPortal
