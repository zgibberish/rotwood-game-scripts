local krandom = require "util.krandom"

local sqrt = math.sqrt

function VecUtil_Add(p1_x, p1_z, p2_x, p2_z)
    return p1_x + p2_x, p1_z + p2_z
end

function VecUtil_Sub(p1_x, p1_z, p2_x, p2_z)
    return p1_x - p2_x, p1_z - p2_z
end

function VecUtil_Scale(p1_x, p1_z, scale)
    return p1_x * scale, p1_z * scale
end

function VecUtil_LengthSq(p1_x, p1_z)
    return p1_x * p1_x + p1_z * p1_z
end

function VecUtil_Length(p1_x, p1_z)
    return sqrt(p1_x * p1_x + p1_z * p1_z)
end

function VecUtil_Dot(p1_x, p1_z, p2_x, p2_z)
	return p1_x * p2_x + p1_z * p2_z
end

function VecUtil_Lerp(p1_x, p1_z, p2_x, p2_z, percent)	
	return (p2_x - p1_x) * percent + p1_x,  (p2_z - p1_z) * percent + p1_z
end

function VecUtil_Normalize(p1_x, p1_z)
    local x_sq = p1_x * p1_x
    local z_sq = p1_z * p1_z
    local length = sqrt(x_sq + z_sq)
    return p1_x / length, p1_z / length
end

function VecUtil_NormalAndLength(p1_x, p1_z)
    local x_sq = p1_x * p1_x
    local z_sq = p1_z * p1_z
    local length = sqrt(x_sq + z_sq)
    return p1_x / length, p1_z / length, length
end

function VecUtil_GetAngleInDegrees(p1_x, p1_z)
	local angle = math.deg(math.atan(p1_z, p1_x))
	if angle < 0 then
		angle = 360 + angle
	end
	return angle
end

function VecUtil_GetAngleInRads(p1_x, p1_z)
    local angle = math.atan(p1_z, p1_x)
    if angle < 0 then
    	angle = math.pi + math.pi + angle
    end
    return angle;
end

local function RandomFloat_IgnoringSelf(self, ...)
	return krandom.Float(...)
end

-- Returns a random offset from origin within a circle of input radius.
function VecUtil_GetRandomPointInCircle(max_radius, krng)
	-- https://mathworld.wolfram.com/DiskPointPicking.html
	local RandomFloat = krng and krng.Float or RandomFloat_IgnoringSelf
	local r = max_radius * sqrt(RandomFloat(krng))
	local angle = RandomFloat(krng, 2 * math.pi)
	return r * math.cos(angle), r * math.sin(angle)
end

-- Returns a random offset from origin within a rect centred on the origin.
function VecUtil_GetRandomPointInRect(w, h, krng)
	local RandomFloat = krng and krng.Float or RandomFloat_IgnoringSelf
	local w_half, h_half = w / 2, h / 2
	return RandomFloat(krng, -w_half, w_half), RandomFloat(krng, -h_half, h_half)
end

function VecUtil_Slerp(p1_x, p1_z, p2_x, p2_z, percent)
	local p1_angle = VecUtil_GetAngleInRads(p1_x, p1_z)
	local p2_angle = VecUtil_GetAngleInRads(p2_x, p2_z)

	if math.abs(p2_angle - p1_angle) > math.pi then
		if p2_angle > p1_angle then
			p2_angle = p2_angle - math.pi - math.pi
		else
			p1_angle = p1_angle - math.pi - math.pi
		end
	end

	local lerped_angle = Lerp(p1_angle, p2_angle, percent)	

	local cos_lerped_angle = math.cos(lerped_angle)
	local sin_lerped_angle = math.sin(lerped_angle)

	return cos_lerped_angle, sin_lerped_angle
end

function VecUtil_RotateAroundPoint(a_x, a_z, b_x, b_z, theta) -- in radians
	local dir_x, dir_z = b_x - a_x, b_z - a_z
	local ct, st = math.cos(theta), math.sin(theta)
	return a_x + dir_x * ct - dir_z * st, a_z + dir_x * st + dir_z * ct
end

function VecUtil_RotateDir(dir_x, dir_z, theta) -- in radians
	local ct, st = math.cos(theta), math.sin(theta)
	return dir_x * ct - dir_z * st, dir_x * st + dir_z * ct
end

function VecUtil_DistancePointToLineSeg(P, P0, P1)
	local v = P1 - P0
	local w = P - P0
	local c1 = w:Dot(v)
	if c1 < 0 then
		return P:Dist(P0)
	end
	local c2 = v:Dot(v)
	if c2 <= c1 then
            return P:Dist(P1)
	end
	local b = c1 / c2
	local Pb = P0 + v * b
        return P:Dist(Pb)
end

--[[
distance( Point P, Segment P0:P1 )
{
      v = P1 - P0
      w = P - P0
      if ( (c1 = w·v) <= 0 )
            return d(P, P0)
      if ( (c2 = v·v) <= c1 )
            return d(P, P1)
      b = c1 / c2
      Pb = P0 + bv
      return d(P, Pb)
}
}   ]]
