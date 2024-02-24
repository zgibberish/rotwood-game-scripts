local kassert = require "util.kassert"

function isnan(x) return x ~= x end
math.inf = 1/0
function isinf(x) return x == math.inf or x == -math.inf end
function isbadnumber(x) return isinf(x) or isnan(x) end

math.round = function(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(math.floor(num * mult + 0.5) / mult)
end

--Returns a sine wave based on game time. Mod will modify the period of the wave and abs is wether or not you want
-- the abs value of the wave
function GetSineVal(mod, abs, inst)
    local time = (inst and inst:GetTimeAlive() or GetTime()) * (mod or 1)
    local val = math.sin(math.pi * time)
    if abs then
        return math.abs(val)
    else
        return val
    end
end

function GetSineValForState(mod, abs, sg)
    local time = sg:GetTimeInState() * mod
    local val = math.sin(math.pi * time)
    if abs then
        return math.abs(val)
    else
        return val
    end
end

-- Evaluate curves authored with imgui::CurveEditor.
-- EvaluateCurve({float,...}, float) -> float
function EvaluateCurve(curve, t)
    return TheSim:EvaluateCurve(t, table.unpack(curve))
end

function CreateCurve(first, last)
	-- -1 indicates the first unused entry. The number of values
	-- determines the maximum number of points in the curve editor.
	-- The curve editor currently only supports 8 values.
	if last then
		assert(first)
		-- Create a linear curve from [first,last].
		return {0,first, 1,last, -1,0, 0,0, 0,0, 0,0, 0,0, 0,0,}
	else
		-- Create an uninitialized curve that will act as linear from [0,1].
		return { -1,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, }
	end
end

--Lerp a number from a to b over t
function Lerp(a,b,t)
    return a + (b - a) * t
end

-- Remap a value from one range [in_low, in_high] to another [out_low, out_high]
function Remap(val, in_low, in_high, out_low, out_high)
    local t = (val - in_low) / (in_high - in_low)
    t = math.clamp(t, 0, 1)
    return out_low + t*(out_high - out_low)
end

--- Find the progress of a value (t) from one range [a, b] to [0, 1].
-- You might also think of it as the ratio of the value from a to b.
-- Note the order of args is different from Remap so it matches Lerp!
-- It is the inverse of Lerp:
--   assert(i == Lerp(a, b, InverseLerp(a, b, i)))
function InverseLerp(a, b, t)
    return Remap(t, a, b, 0, 1)
end

local function test_Remap()
    local i, a, b = 5, 0, 10
    kassert.equal(-50, Remap(5, 0, 10, -100, 0))
    kassert.equal(-80, Remap(2, 0, 10, -100, 0))
    kassert.equal(50, Remap(5, 0, 10, 100, 0))
    kassert.equal(80, Remap(2, 0, 10, 100, 0))
    kassert.equal(75, Remap(5, 0, 10, 50, 100))
    kassert.equal(60, Remap(2, 0, 10, 50, 100))
    kassert.equal(75, Remap(5, 0, 10, 100, 50))
    kassert.equal(90, Remap(2, 0, 10, 100, 50))
    kassert.equal(0.5, InverseLerp(0, 10, 5))
    kassert.equal(0, InverseLerp(5, 10, 5))
    assert(i == Lerp(a, b, InverseLerp(a, b, i)))
end

function IsWholeNumber(num)
	local _int, frac = math.modf(num)
	return frac == 0
end

--Round a number to idp decimal points. 0.5-values are always rounded up.
function RoundBiasedUp(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

--Round a number to idp decimal points. 0.5-values are always rounded down.
function RoundBiasedDown(num, idp)
    local mult = 10^(idp or 0)
    return math.ceil(num * mult - 0.5) / mult
end

--Rounds numToRound to the nearest multiple of "mutliple"
function RoundToNearest(numToRound, multiple)
    local half = multiple/2
    return numToRound+half - (numToRound+half) % multiple
end

-- Converts an angle to an angle in the range [0,360)
function SimplifyAngle(rot)
	return ((rot % 360) + 360) % 360
end

function ReduceAngle(rot)
	while rot < -180 do
		rot = rot + 360
	end
	while rot > 180 do
		rot = rot - 360
	end
	return rot
end

function DiffAngle(rot1, rot2)
	return math.abs(ReduceAngle(rot2 - rot1))
end

function ReduceAngleRad(rot)
	while rot < -math.pi do
		rot = rot + 2 * math.pi
	end
	while rot > math.pi do
		rot = rot - 2 * math.pi
	end
	return rot
end

function DiffAngleRad(rot1, rot2)
	return math.abs(ReduceAngleRad(rot2 - rot1))
end

--Clamps a number between two values
function math.clamp(num, min, max)
    return num <= min and min or (num >= max and max or num)
end

function IsNumberEven(num)
    return (num % 2) == 0
end

function DistSq2D(x1, y1, x2, y2)
	x1 = x1 - x2
	y1 = y1 - y2
	return x1 * x1 + y1 * y1
end

function Dist2D(x1, y1, x2, y2)
	return math.sqrt(DistSq2D(x1, y1, x2, y2))
end

function DistSqPointToSegment(p, v1, v2)
	local dx = v2.x - v1.x
	local dz = v2.z - v1.z
	local dx1 = p.x - v1.x
	local dz1 = p.z - v1.z
	if dx == 0 and dz == 0 then
		return dx1 * dx1 + dz1 * dz1
	end
	local t = (dx1 * dx + dz1 * dz) / (dx * dx + dz * dz)
	return (t < 0 and dx1 * dx1 + dz1 * dz1)
	or (t > 1 and DistSq2D(p.x, p.z, v2.x, v2.z))
	or DistSq2D(p.x, p.z, v1.x + t * dx, v1.z + t * dz)
end


-- Calculate the shortest distance between two axis-aligned rectangles.
function CalculateRectDistance(
		from_x1, from_y1, from_x2, from_y2,
		to_x1, to_y1, to_x2, to_y2)

	local right = to_x1 > from_x2
	local left = to_x2 < from_x1
	local top = to_y1 > from_y2
	local bottom = to_y2 < from_y1
	local dist

	if top and right then
		dist = Dist2D( from_x2, from_y2, to_x1, to_y1 )
	elseif bottom and right then
		dist = Dist2D( from_x2, from_y1, to_x1, to_y2 )
	elseif bottom and left then
		dist = Dist2D( from_x1, from_y1, to_x2, to_y2 )
	elseif top and left then
		dist = Dist2D( from_x1, from_y2, to_x2, to_x1 )
	elseif right then
		dist = to_x1 - from_x2
	elseif left then
		dist = from_x1 - to_x2
	elseif top then
		dist = to_y1 - from_y2
	elseif bottom then
		dist = from_y1 - to_y2
	else
		-- overlapping.
		dist = 0
	end

	return dist
end

-- Calculate AABB intersection, assuming these rectangles intersect.
function IntersectRect( x1min, y1min, x1max, y1max, x2min, y2min, x2max, y2max )
	local xmin = math.max( x1min, x2min )
	local xmax = math.min( x1max, x2max )
	local ymin = math.max( y1min, y2min )
	local ymax = math.min( y1max, y2max )
	return xmin, ymin, xmax, ymax
end

function CalcDiminishingReturns(current, basedelta)
	local dampen = 3 * basedelta / (current + 3 * basedelta)
	local dcharge = dampen * basedelta * .5 * (1 + math.random() * dampen)
	return current + dcharge
end

-- Returns a discretely stepped random value out of a total of 'numsteps' in [0, range]
function SteppedRandomRange(numsteps, range)
	return (math.random(numsteps + 1) - 1) / numsteps * range
end

-- Returns a discretely stepped random value out of a total of 'numsteps' in [-range/2,range/2]
function SteppedRandomRangeCentered(numsteps, range)
	return SteppedRandomRange(numsteps, range) - range * 0.5
end

local function GetSide(a, b)
    local cosine_sign = a.x*b.y-a.y*b.x
    if cosine_sign < 0 then
        return true -- LEFT
	elseif cosine_sign > 0 then
        return false --  RIGHT
	end
end

-- Assuming convex_polygon is an array-like table of {x, y} tables that form a convex polygon, return true if the
-- point is inside and false otherwise
function IsPointInsideConvexPolygon(point, convex_polygon)
	local previous_side
	for i = 1, #convex_polygon do
		local next_i
		if i == #convex_polygon then
			next_i = 1
		else
			next_i = i + 1
		end
		local a, b = convex_polygon[i], convex_polygon[next_i]
        local affine_segment = {x = b.x - a.x, y = b.y - a.y}
        local affine_point = {x = point.x - a.x, y = point.y - a.y}
        local current_side = GetSide(affine_segment, affine_point)
        if current_side == nil then
            return false -- outside or over an edge; i.e. on edge is excluded
		elseif previous_side == nil then -- first segment
            previous_side = current_side
        elseif previous_side ~= current_side then
            return false
		end
	end
    return true
end
