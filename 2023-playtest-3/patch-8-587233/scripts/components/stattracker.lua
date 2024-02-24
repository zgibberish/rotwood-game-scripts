local StatTracker = Class(function(self, inst)
	self.inst = inst
	self.default_data = {}
	self.data = {}
end)

function StatTracker:OnSave()
	local data = deepcopy(self.data)
	return data
end

function StatTracker:OnLoad(data)
	if data ~= nil and next(data) then
		self.data = deepcopy(data)
	end
end

function StatTracker:SetDefaultData(default_data)
	self.default_data = default_data
	self:Reset()
end

function StatTracker:Reset()
	self.data = deepcopy(self.default_data)
end

function StatTracker:GetValue(name)
	return self.data[name]
end

function StatTracker:SetValue(name, value)
	self.data[name] = value
end

function StatTracker:IncrementValue(name)
	self:DeltaValue(name, 1)
end

function StatTracker:DeltaValue(name, delta)
	local v = (self:GetValue(name) or 0) + delta
	self:SetValue(name, v)
end

return StatTracker