local CameraLimits = Class(function(self, inst)
	self.inst = inst
	self.default =
	{
		xmin = -math.huge,
		xmax = math.huge,
		xpadding = 0,
		zmin = -math.huge,
		zmax = math.huge,
		zpadding = 0,
	}
	self:SetToDefaultLimits()
	self.enabled = true
end)

function CameraLimits:SetToDefaultLimits()
	for k, v in pairs(self.default) do
		self[k] = v
	end
end

function CameraLimits:IsEnabled()
	return self.enabled
end

function CameraLimits:SetEnabled(enable)
	self.enabled = enable
end

function CameraLimits:SetDefaultXRange(min, max, padding)
	self.default.xmin = min or -math.huge
	self.default.xmax = max or math.huge
	self.default.xpadding = padding or 0
end

function CameraLimits:SetDefaultZRange(min, max, padding)
	self.default.zmin = min or -math.huge
	self.default.zmax = max or math.huge
	self.default.zpadding = padding or 0
end

function CameraLimits:SetXRange(min, max, padding)
	self.xmin = min or -math.huge
	self.xmax = max or math.huge
	self.xpadding = padding or 0
end

function CameraLimits:SetZRange(min, max, padding)
	self.zmin = min or -math.huge
	self.zmax = max or math.huge
	self.zpadding = padding or 0
end

function CameraLimits:ApplyLimits(x, z)
	if self.enabled then
		x = self:ApplyLimitsInternal(x, self.xmin, self.xmax, self.xpadding)
		z = self:ApplyLimitsInternal(z, self.zmin, self.zmax, self.zpadding)
	end
	return x, z
end

function CameraLimits:ApplyLimitsInternal(val, min, max, padding)
	padding = math.min(padding, (max - min) * .5)
	local dval = val - min
	if dval <= padding then
		dval = dval + padding
		if dval > 0 then
			return min + dval * dval / (4 * padding)
		else
			return min
		end
	end
	dval = max - val
	if dval <= padding then
		dval = dval + padding
		if dval > 0 then
			return max - dval * dval / (4 * padding)
		else
			return max
		end
	end
	return val
end

return CameraLimits
