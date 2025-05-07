require "class"
require "mathutil"


local function noop() end

-- Move from left to right (or vice versa) with a random speed.
local AutoMover = Class(function(self, inst)
	self.inst = inst
	self.min = -300
	self.max = 300
	self.speed = 0
	self.minspeed = -3
	self.maxspeed = 3

	self.inst:StartUpdatingComponent(self)
end)

function AutoMover:Refresh()
	self.speed = self.minspeed + math.random() * ( self.maxspeed - self.minspeed )
end

function AutoMover:OnUpdate(dt)
	local pos = self.inst:GetPosition()
	pos.x = pos.x + self.speed * dt
	if self.speed < 0 then
		if pos.x < self.min then
			pos.x = self.max
			self:Refresh()
		end
	else
		if pos.x > self.max then
			pos.x = self.min
			self:Refresh()
		end
	end
	self.inst.Transform:SetPosition(pos:unpack())
end

return AutoMover
