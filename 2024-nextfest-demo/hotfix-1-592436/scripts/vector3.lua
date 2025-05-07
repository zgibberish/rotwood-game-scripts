Vector3 = require "math.modules.vec3"
Point = Vector3

-- Patch compatability shims into vec3's definition. Their class def is a bit
-- wonky and has two levels of metatables.
local vec3 = getmetatable(Vector3).__index

-- Formerly provided by class.lua
function vec3.is_instance(v)
	return getmetatable(v) == getmetatable(Vector3)
end

vec3.Dot = vec3.dot
vec3.Cross = vec3.cross
vec3.DistSq = vec3.dist2
vec3.Dist = vec3.dist
vec3.LengthSq = vec3.len2
vec3.Length = vec3.len

-- In place normalization. cpml normalized creates a copy.
function vec3:Normalize()
    local len = self:Length()
    if len > 0 then
        self.x = self.x / len
        self.y = self.y / len
        self.z = self.z / len
    end
    return self
end

vec3.Get = vec3.unpack

-- Returns individual xz unlike vec3.to_xz which returns a vec2.
function vec3:GetXZ()
	return self.x, self.z
end

function vec3:IsVector3()
    return true
end

function ToVector3(obj,y,z)
    if not obj then
        return
    end
    if obj.IsVector3 then  -- note: specifically not a function call! 
        return obj
    end
    if type(obj) == "table" then
        return Vector3(tonumber(obj[1]),tonumber(obj[2]),tonumber(obj[3]))
    else
        return Vector3(tonumber(obj),tonumber(y),tonumber(z))
    end
end


assert(Vector3.normalized)
assert(Vector3().Normalize)
assert(Vector3.is_instance(Vector3()))
