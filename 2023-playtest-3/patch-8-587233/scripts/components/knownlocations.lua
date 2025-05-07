local lume = require "util.lume"

local KnownLocations = Class(function(self, inst)
	self.inst = inst
	self.locations = {}
end)

function KnownLocations:AddLocationPoint(name, pt)
	--Note: we want to clone, not ref, the pt
	self:AddLocationInternal(name, pt:Get())
end

function KnownLocations:AddLocationXZ(name, x, z)
	self:AddLocationInternal(name, x, 0, z)
end

function KnownLocations:AddLocationInternal(name, x, y, z)
	local pt = self.locations[name]
	if pt == nil then
		self.locations[name] = Vector3(x, y, z)
	else
		pt.x, pt.y, pt.z = x, y, z
	end
end

function KnownLocations:RemoveLocation(name)
	self.locations[name] = nil
end

function KnownLocations:HasLocation(name)
	return self.locations[name] ~= nil
end

function KnownLocations:GetLocationPoint(name)
	local pt = self.locations[name]
	if pt ~= nil then
		return Vector3(pt:Get())
	end
end

function KnownLocations:GetLocationXZ(name)
	local pt = self.locations[name]
	if pt ~= nil then
		return pt:GetXZ()
	end
end

function KnownLocations:CopyLocationFrom(name, src, srcname)
	if src.components.knownlocations ~= nil then
		local pt = src.components.knownlocations.locations[srcname or name]
		if pt ~= nil then
			self:AddLocationInternal(name, pt:Get())
		end
	end
end

function KnownLocations:OnSave()
	if next(self.locations) ~= nil then
		local data = {}
		for name, pt in pairs(self.locations) do
			local savept =
			{
				x = lume.round(pt.x, 0.01),
				y = lume.round(pt.y, 0.01),
				z = lume.round(pt.z, 0.01),
			}
			if savept.y == 0 then
				savept.y = nil
			end
			data[name] = savept
		end
		return data
	end
end

function KnownLocations:OnLoad(data)
	table.clear(self.locations)
	for name, savept in pairs(data) do
		self.locations[name] = Vector3(savept.x or 0, savept.y or 0, savept.z or 0)
	end
end

function KnownLocations:GetDebugString()
	local str = ""
	for name, pt in pairs(self.locations) do
		str = str..string.format("\n    --%s: %s", name, tostring(pt))
	end
	return str
end

return KnownLocations
