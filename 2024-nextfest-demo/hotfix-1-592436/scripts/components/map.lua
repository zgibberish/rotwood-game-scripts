---------------------------------------------------------------------------------------
-- Extends C++ Map component

local krandom = require "util.krandom"


Map.rng = krandom.CreateGenerator()

---------------------------------------------------------------------------------------
-- Add functions to accept (Point) instead of (X, Z) and some convenience
-- functions.


-- Ensure an input point is walkable.
--
-- Returns two values.
-- closest (Vector3): The point within walkable area closest to the input point.
-- distsq (float): How far (squared) from the input point to the output point.
function Map:FindClosestWalkablePoint(pt, padding_from_edge)
	if self:IsWalkableAtXZ(pt:GetXZ()) then
		return pt, 0
	end
	return self:FindClosestPointOnWalkableBoundary(pt, padding_from_edge)
end

-- Find a point on the outside boundary of the walkable area.
--
-- Returns two values.
-- closest (Vector3): The point on the walkable boundary closest to the input point.
-- distsq (float): How far (squared) from the input point to the output point.
function Map:FindClosestPointOnWalkableBoundary(pt, padding_from_edge)
	local x, z, distsq = self:FindClosestXZOnWalkableBoundaryToXZ(pt:GetXZ())

	if padding_from_edge then
		local v = Vector3(x, 0, z)
		if distsq < padding_from_edge * padding_from_edge then
			-- Pull back from outside edges.
			local to_point, len = v:normalized()
			-- Double padding to ensure we've backed up enough.
			len = math.abs(len - padding_from_edge * 2)
			v = to_point:scale(len)
			x = v.x
			z = v.z
		end
	end
	return Vector3(x, 0, z), distsq
end

function Map:IsGroundAtPoint(pt)
	return self:IsGroundAtXZ(pt:GetXZ())
end

function Map:IsGroundAtPoint_IncludeOverhang(pt)
	return self:IsGroundAtXZ_IncludeOverhang(pt:GetXZ())
end


function Map:GetTileCoordsAtPoint(pt)
	return self:GetTileCoordsAtXZ(pt:GetXZ())
end

function Map:GetTileCenterPoint(pt)
	local x, z = self:GetTileCenterXZ(pt:GetXZ())
	return Point(x, 0, z)
end

function Map:GetTileXYAtPoint(pt)
	return self:GetTileXYAtXZ(pt:GetXZ())
end

-- GroundTiles but by name. See groundtiles.lua: the first argument to AddTile
-- is the tile name.
function Map:GetNamedTileAtXZ(x, z)
	local idx = self:GetTileAtXZ(x, z)
	return TheWorld.tilegroup.Order[idx]
end


-- Get a random point somehwere within the walkable area.
--
-- rng: either nil or an instance of krng.
function Map:GetRandomPointInWalkable(padding_from_edge, rng)
	padding_from_edge = padding_from_edge or 0
	-- TODO(dbriscoe): Consider generating poisson disk and iterating
	-- through it so we won't get overlapping points.
	local minx,minz,maxx,maxz = self:GetWalkableBounds()
	local w, h = maxx - minx, maxz - minz
	local x, z = VecUtil_GetRandomPointInRect(w, h, rng or Map.rng)
	local distsq = 0
	if self:IsWalkableAtXZ(x, z) then
		local _
		_, _, distsq = self:FindClosestXZOnWalkableBoundaryToXZ(x, z)
	else
		x, z = self:FindClosestXZOnWalkableBoundaryToXZ(x, z)
	end
	local v = Vector3(x, 0, z)
	if distsq < padding_from_edge * padding_from_edge then
		-- Pull back from outside edges.
		local to_point, len = v:normalized()
		-- Double padding to ensure we've backed up enough.
		len = math.abs(len - padding_from_edge * 2)
		v = to_point:scale(len)
	end
	return v
end

