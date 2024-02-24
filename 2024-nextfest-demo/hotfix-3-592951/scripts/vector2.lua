Vector2 = require "math.modules.vec2"

-- Patch compatability shims into vec2's definition. Their class def is a bit
-- wonky and has two levels of metatables.
local vec2 = getmetatable(Vector2).__index

-- Formerly provided by class.lua
function vec2.is_instance(v)
	return getmetatable(v) == getmetatable(Vector2)
end

vec2.Clone = vec2.clone
vec2.MultiplyComponents = vec2.mul
vec2.DivideComponents = vec2.div
vec2.Dot = vec2.dot

-- Not the same as vec2.cross, which is true cross product.
-- Not sure how this Cross() is useful, since it doesn't account for self at
-- all.
function vec2:Cross( rhs )
    -- This is not a cross product, it returns rhs rotated by 90 degrees.
    -- closest to to a cross in 3D - 'give me the vector perpendicular to....'
    -- I don't think a true crossproduct for Vector2 makes sense
    return Vector2(rhs.y, -rhs.x);
end


-- Signed angle in (-pi, pi]
vec2.AngleTo_Radians = vec2.angle_to -- (other)
-- Angle from one vector to another. If positioning UI elements, you probably
-- want angle to +x axis:
--   local delta = self - other
--   local ui_angle = delta:AngleTo_Degrees(Vector2(1,0))
function vec2:AngleTo_Degrees(other)
	local angle = self:AngleTo_Radians(other)
	return math.deg(angle)
end

-- Unsigned angle in [0,pi]
vec2.AngleBetween_Radians = vec2.angle_between
function vec2:AngleBetween_Degrees(other)
	local angle = self:AngleBetween_Radians(other)
	return math.deg(angle)
end

vec2.DistSq = vec2.dist2
vec2.Dist = vec2.dist
vec2.LengthSq = vec2.len2
vec2.Length = vec2.len

-- In place normalization. cpml normalized creates a copy.
function vec2:Normalize()
    local len = self:Length()
    if len > 0 then
        self.x = self.x / len
        self.y = self.y / len
    end
    return self
end

vec2.Get = vec2.unpack
vec2.ToTable = vec2.to_table

function vec2:IsVector2()
    return true
end

function ToVector2(obj,y)
    if not obj then
        return
    end
    if obj.IsVector2 then  -- note: specifically not a function call!
        return obj
    end
    if type(obj) == "table" then
        if obj.x then
            assert(obj.y)
            return Vector2(obj.x, obj.y)
        else
            return Vector2(tonumber(obj[1]),tonumber(obj[2]))
        end
    else
        assert(y)
        return Vector2(tonumber(obj),tonumber(y))
    end
end

assert(Vector2.is_instance(Vector2()))
