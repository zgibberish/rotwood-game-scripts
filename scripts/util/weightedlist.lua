local WeightedList = Class(function(self, other)
	self.totalweight = 0
	if other ~= nil then
		self:Concat(other)
	end
end)

function WeightedList:Clone()
	return WeightedList(self)
end

function WeightedList:Concat(other)
	assert(WeightedList.is_instance(other))
	for i = 1, #other do
		self[#self + 1] = other[i]
	end
	self.totalweight = self.totalweight + other.totalweight
end

function WeightedList:AddItem(item, weight)
	assert(weight > 0)
	self[#self + 1] = weight
	self[#self + 1] = item
	self.totalweight = self.totalweight + weight
end

function WeightedList:PickItem()
	local len = #self
	if len <= 0 then
		return
	end
	local rnd = math.random() * self.totalweight
	for i = 3, #self, 2 do
		if rnd < self[i] then
			return self[i + 1]
		end
		rnd = rnd - self[i]
	end
	return self[2]
end

function WeightedList:PickAndRemoveItem()
	local len = #self
	if len <= 0 then
		return
	end
	local rnd = math.random() * self.totalweight
	for i = 3, len, 2 do
		if rnd < self[i] then
			return self:RemoveItem(i)
		end
		rnd = rnd - self[i]
	end
	return self:RemoveItem(1)
end

function WeightedList:RemoveItem(idx)
	local len = #self
	local item = self[idx + 1]
	self.totalweight = len > 2 and self.totalweight - self[idx] or 0 --avoid floating point error
	self[idx] = self[len - 1]
	self[idx + 1] = self[len]
	self[len - 1] = nil
	self[len] = nil
	return item
end

return WeightedList
