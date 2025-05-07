local DebugNodes = require "dbui.debug_nodes"
require "class"

-- Prefer using followers:
--   p.entity:SetParent(inst.entity)
--   p.entity:AddFollower()
--
-- However, followers don't work when we mix symbol following
-- (Follower:FollowSymbol) with transform following (AddFollower without
-- FollowSymbol). FollowerComponent::UpdateFollowPosition's method of computing
-- the symbol position to give to mTransform->SetPosition doesn't match
-- animnode's method of computing symbol locations.
local Glue = Class(function(self, inst)
	self.inst = inst
	assert(self.inst.entity:GetParent() == nil, "I don't expect this works well with parents.")
end)

function Glue:FollowTarget(target, flat_offset, height_offset)
	self.flat_offset = flat_offset or Vector2.zero
	assert(Vector2.is_vec2(self.flat_offset), "Offset is in xz plane, so it's vec2.")
	self.height_offset = height_offset or 0
	self.target = target
	self:_TryKeepTargetTracking()
	return self
end

function Glue:OnUpdate(dt)
	-- Rotating as a vec2 simplifies the underlying math since our rotation is
	-- only an angle and always around y axis.
	if self.target == nil or not self.target:IsValid() then
		self.inst:StopUpdatingComponent(self)
		return
	end
	local rot = math.rad(self.target.Transform:GetRotation())
	local delta = self.flat_offset:rotate(rot)
	local pos = self.target:GetPosition()
	pos.x = pos.x - delta.x -- subtract to to rotate in correct direction (xz to xyz coordinate differences)
	pos.y = pos.y + self.height_offset
	pos.z = pos.z + delta.y
	self.inst.Transform:SetPosition(pos:unpack())
end

function Glue:_TryKeepTargetTracking()
	local shouldupdate = self.target ~= nil
	if shouldupdate ~= self.is_updating then
		self.is_updating = shouldupdate
		if shouldupdate then
			self.inst:StartUpdatingComponent(self)
		else
			self.inst:StopUpdatingComponent(self)
		end
	end
end

function Glue:DebugDrawEntity(ui, panel, colors)
	ui:Value("target", self.target)
	if ui:Button("Select target") then
		panel:PushNode(DebugNodes.DebugEntity(self.target))
	end
end

return Glue
