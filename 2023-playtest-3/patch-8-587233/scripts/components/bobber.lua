local ValueStacker = require "components.valuestacker"
local color = require "math.modules.color"
local kassert = require "util.kassert"
require "mathutil"


local Bobber = Class(function(self, inst)
	self.inst = inst
	self.inst:StartUpdatingComponent(self)
	self.inst.AnimState:SetOnWater(true)
end)

function Bobber:OnUpdate()
	local x,y,z = self.inst.Transform:GetWorldPosition()
	local h = TheWorld.components.worldwater:GetHeight()
	self.inst.Transform:SetPosition(x,h,z)
end

return Bobber
