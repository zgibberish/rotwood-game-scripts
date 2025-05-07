---------------------------------------------------------------------------------------
--Helper class for target range calculations when choosing attacks
---------------------------------------------------------------------------------------

local TargetRange = Class(function(self, inst, target)
	dbassert(target and target:IsValid(), "Check target validity first!")
	self.inst = inst
	self.target = target
end)

local fns =
{
	x = function(t) t.x, t.z = t.inst.Transform:GetWorldXZ() end,
	z = function(t) t.x, t.z = t.inst.Transform:GetWorldXZ() end,
	x1 = function(t) t.x1, t.z1 = t.target.Transform:GetWorldXZ() end,
	z1 = function(t) t.x1, t.z1 = t.target.Transform:GetWorldXZ() end,
	dx = function(t) t.dx = t.x1 - t.x end,
	dz = function(t) t.dz = t.z1 - t.z end,
	absdx = function(t) t.absdx = math.abs(t.dx) end,
	absdz = function(t) t.absdz = math.abs(t.dz) end,
	dsq = function(t) t.dsq = t.dx * t.dx + t.dz * t.dz end,
	facing = function(t) t.facing = t.inst.Transform:GetFacing() end,
	facingrot = function(t) t.facingrot = t.inst.Transform:GetFacingRotation() end,
	diffrot = function(t) t.diffrot = DiffAngle(math.deg(math.atan(-t.dz, t.dx)), t.facingrot) end,
	size = function(t) t.size = t.inst.HitBox:GetSize() end,
	depth = function(t) t.depth = t.inst.HitBox:GetDepth() end,
	targetsize = function(t) t.targetsize = t.target.HitBox:GetSize() end,
	targetdepth = function(t) t.targetdepth = t.target.HitBox:GetDepth() end,
}

function TargetRange:__index(k)
	local fn = fns[k]
	if fn ~= nil then
		fn(self)
		return rawget(self, k)
	end
	return TargetRange[k]
end

function TargetRange:IsFacingTarget()
	return (self.x1 > self.x) == (self.facing == FACING_RIGHT)
end

function TargetRange:IsOverlapped()
	return self.absdx < self.targetsize + self.size
end

function TargetRange:IsInZRange(range)
	return self.absdz < range
end

function TargetRange:IsOutOfZRange(range)
	return self.absdz > range
end

function TargetRange:IsInRange(range)
	range = range + self.targetdepth
	return self.dsq < range * range
end

function TargetRange:IsOutOfRange(range)
	range = range + self.targetdepth
	return self.dsq >= range * range
end

function TargetRange:IsBetweenRange(min, max)
	return self:IsInRange(max) and self.dsq >= min * min
end

function TargetRange:IsInRotation(rot)
	return self.diffrot < rot
end

function TargetRange:TestBeamDirectional(mindist, maxdist, thickness)
	return self.absdz < thickness + self.targetdepth
		and self.dx < maxdist + self.targetsize
		and self.dx >= mindist
end

function TargetRange:TestBeam(mindist, maxdist, thickness)
	return self.absdz < thickness + self.targetdepth
		and self.absdx < maxdist + self.targetsize
		and self.absdx >= mindist
end

function TargetRange:TestDetachedBeam(mindist, maxdist, thickness)
	return self:TestBeam(mindist + self.targetsize, maxdist, thickness)
end

function TargetRange:TestCone(rot, mindist, maxdist, thickness)
	return (self:IsInRotation(rot) or
			self.absdz < thickness + self.targetdepth + self.depth)
		and self:IsBetweenRange(mindist, maxdist)
end

function TargetRange:TestCone45(mindist, maxdist, thickness)
	return (self.absdx > self.absdz or
			self.absdz < thickness + self.targetdepth + self.depth)
		and self:IsBetweenRange(mindist, maxdist)
end

function TargetRange:TestDetachedCone(rot, mindist, maxdist, thickness)
	return self:TestCone(rot, mindist + self.targetdepth, maxdist, thickness)
end

function TargetRange:TestDetachedCone45(mindist, maxdist, thickness)
	return self:TestCone45(mindist + self.targetdepth, maxdist, thickness)
end

return TargetRange
