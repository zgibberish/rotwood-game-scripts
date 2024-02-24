--static
local ents = { {}, {}, {} }

local CabbageRollsTracker = Class(function(self, inst)
	self.inst = inst
	self.num = nil
	self.cancombine = false
end)

function CabbageRollsTracker:OnNetSerialize()
	local e = self.inst.entity
	e:SerializeBoolean(self.cancombine)
end

function CabbageRollsTracker:OnNetDeserialize()
	local e = self.inst.entity
	self.cancombine = e:DeserializeBoolean()
end

function CabbageRollsTracker:OnRemoveEntity()
	self:Unregister()
end

function CabbageRollsTracker:OnRemoveFromEntity()
	self:Unregister()
end

function CabbageRollsTracker:Register(num)
	self.num = num
	ents[num][self.inst] = true
end

function CabbageRollsTracker:Unregister()
	if self.num ~= nil then
		ents[self.num][self.inst] = nil
		self.num = nil
	end
end

function CabbageRollsTracker:GetNum()
	return self.num
end

function CabbageRollsTracker:SetCanCombine(enable)
	self.cancombine = enable
end

function CabbageRollsTracker:CanCombine()
	return self.cancombine and self.num < 3 and not self.inst:HasTag("playerminion")
end

function CabbageRollsTracker:FindNearest(num, range)
	local x, z = self.inst.Transform:GetWorldXZ()
	local mindsq = range ~= nil and range * range or math.huge
	local nearest = nil
	for k in pairs(ents[num]) do
		if k ~= self.inst and k.prefab == self.inst.prefab then
			local dsq = k:GetDistanceSqToXZ(x, z)
			if dsq < mindsq then
				mindsq = dsq
				nearest = k
			end
		end
	end
	return nearest
end

return CabbageRollsTracker
