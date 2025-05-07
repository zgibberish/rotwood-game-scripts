local lume = require "util.lume"
local KMath = require "util.kmath"


-- DebugDraw will remain visible and lifetime (seconds) won't count down when
-- stepping with Home. Pass lifetime = TICKS to to ensure it remains visible
-- when you first press Home.
-- Call TheDebugRenderer:ForceTickCurrentFrame() from code that needs to clear
-- lines while paused.
local DebugDraw = {}


-- Allow rot to be a degree value of the rotation or a vector pointing in the
-- desired direction.
local function ConvertRotationIfVec3(rot)
	if Vector3.is_vec3(rot) then
		return math.deg(Vector3.to_xz(rot):angle_to(Vector2.unit_x))
	end
	assert(not Vector2.is_vec2(rot), "World drawing needs worldspace rotations (vec3 or heading).")
	-- Must be angle in degrees.
	return rot
end

local function ConvertPositionIfVec3(x, z)
	if not z then
		assert(Vector3.is_vec3(x))
		local _
		x, _, z = x:unpack()
	end
	return x, z
end


function DebugDraw.GroundRect(x1, z1, x2, z2, color, thickness, lifetime)
	x1, z1 = ConvertPositionIfVec3(x1, z1)
	x2, z2 = ConvertPositionIfVec3(x2, z2)
	local p1 = { x1, 0, z1 }
	local p2 = { x2, 0, z1 }
	local p3 = { x2, 0, z2 }
	local p4 = { x1, 0, z2 }
	TheDebugRenderer:WorldLine(p1, p2, color, thickness, lifetime)
	TheDebugRenderer:WorldLine(p2, p3, color, thickness, lifetime)
	TheDebugRenderer:WorldLine(p3, p4, color, thickness, lifetime)
	TheDebugRenderer:WorldLine(p4, p1, color, thickness, lifetime)
end

-- Axis-aligned square that correctly measures distance.
function DebugDraw.GroundSquare(x, z, width, color, thickness, lifetime)
	x, z = ConvertPositionIfVec3(x, z)
	local half = width / 2
	DebugDraw.GroundRect(x - half,
		z - half,
		x + half,
		z + half,
		color, thickness, lifetime)
end

-- Useful to distinguish different shapes.
-- size is its max bounding box (the width of the largest square that could contain it).
function DebugDraw.GroundIsoShape(x, z, size, color, num_sides, rot, lifetime)
	x, z = ConvertPositionIfVec3(x, z)
	rot = ConvertRotationIfVec3(rot or 0)
	rot = -math.rad(rot) -- negative for left-hand coordinate system
	local tau = math.pi * 2
	local delta = tau / num_sides
	local half = size / 2
	local last
	for i=0,num_sides do
		local angle = delta * i + rot
		local px = math.cos(angle) * half
		local pz = math.sin(angle) * half
		local pt = {px + x, 0, pz + z}
		if last then
			TheDebugRenderer:WorldLine(last, pt, color, 1, lifetime)
		end
		last = pt
	end
end
function DebugDraw.GroundTriangle(x, z, size, color, rot, lifetime)
	DebugDraw.GroundIsoShape(x, z, size, color, 3, rot, lifetime)
end
function DebugDraw.GroundDiamond(x, z, size, color, rot, lifetime)
	DebugDraw.GroundIsoShape(x, z, size, color, 4, rot, lifetime)
end
function DebugDraw.GroundHex(x, z, size, color, rot)
	DebugDraw.GroundIsoShape(x, z, size, color, 6, rot)
end
function DebugDraw.GroundOct(x, z, size, color, rot)
	DebugDraw.GroundIsoShape(x, z, size, color, 8, rot)
end


function DebugDraw.GroundCircle(x, z, radius, color, thickness, lifetime)
	x, z = ConvertPositionIfVec3(x, z)
	DebugDraw.GroundProjectedCircle(x, 0, z, radius, color, thickness, lifetime)
end

-- theta is the rotation, anti-clockwise from the x-axis, that you want the middle of the
-- arc of the semi-circle to point.
function DebugDraw.GroundProjectedSemiCircle(x, z, theta, radius, color, thickness, lifetime)
	assert(z, "Doesn't support optional Vec3.")
	local y = 0

	local function WorldPoint(theta)
		local local_point = KMath.polar_to_cartesian(radius, theta)
		return {
			x + local_point.x,
			y,
			z + local_point.z
		}
	end

	local semi_circ = math.pi * radius
	local steps = lume.clamp(math.ceil(semi_circ / 2), 6, 10)
	local delta = math.pi / steps
	local p1
	theta = theta - math.pi / 2
	local p2 = WorldPoint(theta)
	local first = p2
	local last
	for i = 1, steps do
		theta = theta + delta
		p1 = p2
		p2 = WorldPoint(theta)
		TheDebugRenderer:WorldLine(p1, p2, color, thickness, lifetime)
		last = p2
	end
	TheDebugRenderer:WorldLine(first, last, color, thickness, lifetime)
end

function DebugDraw.GroundProjectedCircle(x, y, z, radius, color, thickness, lifetime)
	assert(z, "Doesn't support optional Vec3.")
	local circ = 2 * math.pi * radius
	local steps = lume.clamp(math.ceil(circ / 2), 12, 20)
	local delta = 2 * math.pi / steps
	local theta = 0
	local p1
	local p2 = { x + radius, y, z }
	for i = 1, steps do
		theta = theta + delta
		p1 = p2
		p2 = { x + math.cos(theta) * radius, y, z - math.sin(theta) * radius }
		TheDebugRenderer:WorldLine(p1, p2, color, thickness, lifetime)
	end
end

function DebugDraw.GroundPoint(x, z, radius, color, thickness, lifetime)
	x, z = ConvertPositionIfVec3(x, z)
	local p1 = { x - radius, 0, z }
	local p2 = { x + radius, 0, z }
	TheDebugRenderer:WorldLine(p1, p2, color, thickness, lifetime)
	p1 = { x, 0, z - radius }
	p2 = { x, 0, z + radius }
	TheDebugRenderer:WorldLine(p1, p2, color, thickness, lifetime)
end

function DebugDraw.GroundLine(x1, z1, x2, z2, color, thickness, lifetime)
	dbassert(type(z2) == "number", "Doesn't support optional Vec3. Use GroundLine_Vec instead.")
	local p1 = { x1, 0, z1 }
	local p2 = { x2, 0, z2 }
	TheDebugRenderer:WorldLine(p1, p2, color, thickness, lifetime)
end

function DebugDraw.GroundLine_Vec(v1, v2, color, thickness, lifetime)
	local p1 = {v1:Get()}
	local p2 = {v2:Get()}
	p1[2] = 0
	p2[2] = 0
	TheDebugRenderer:WorldLine(p1, p2, color, thickness, lifetime)
end

-- Arrow from start to stop. The line goes from start to stop and the arrow tip
-- points at stop.
function DebugDraw.GroundArrow_Vec(start, stop, color, lifetime)
	local ray = stop - start
	local tip_size = 3
	local direction, size = ray:normalized()
	local top_pos = stop - direction * tip_size / 2
	DebugDraw.GroundTriangle(top_pos.x, top_pos.z, tip_size, color, ray, lifetime)
	DebugDraw.GroundLine_Vec(start, stop, color, 1, lifetime)
end

-- Convenience for GroundArrow_Vec, but with an offset.
function DebugDraw.GroundRay_Vec(pos, offset, color, lifetime)
	local stop = pos + offset
	return DebugDraw.GroundArrow_Vec(pos, stop, color, lifetime)
end

-- Chubby arrow at pos pointing in dir. Size of ray_dir determines size of arrow.
function DebugDraw.GroundDirection_Vec(pos, ray_dir, color, lifetime)
	local direction, size = ray_dir:normalized()
	local offset = pos + direction * size
	local rot = ConvertRotationIfVec3(direction)
	DebugDraw.GroundTriangle(offset.x, offset.z, size * 2.6, color, rot, lifetime)
	DebugDraw.GroundDiamond(pos.x, pos.z, size, color, rot + 45, lifetime)
end

-- size shouldn't be smaller than 10 or you can't see it. 20 is small and 40 is big.
function DebugDraw.WorldText(text, position, size, color, lifetime)
	color = color or WEBCOLORS.WHITE
	lifetime = lifetime or 0
	-- TheLog.ch.Debug:printf("text=%s position=%1.3f,%1.3f,%1.3f", text, position[1], position[2], position[3])
	local ent = SpawnPrefab("debug_worldtext", TheDebugSource)
	ent.components.worldtext:Initialize(text, position, size, color, lifetime)
	return ent
end

return DebugDraw
