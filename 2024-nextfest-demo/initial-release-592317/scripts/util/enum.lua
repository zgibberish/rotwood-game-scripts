local kassert = require "util.kassert"
local lume = require "util.lume"
local strict = require "util.strict"


-- Enum supporting string or int values and ordered iteration.
--
-- Enum values are simple types (string or int) so they're trivially
-- serializable, usable as dict keys, and generally interop with code unaware
-- of Enum.
--
-- x = Enum{ "duck", "frog", }
-- x.s.duck == "duck"
-- x.id.duck == 1
-- x:Contains("duck") == true
-- cur = ui:_Enum("Animals", cur, x, true)
-- cur = ui:_Combo("Animals", cur, x:Ordered())
--
-- See test_enum for more usage.
local Enum = {}

Enum.__index = function(t, k)
	-- Prevent using enum instance directly for enum values.
	local v = rawget(Enum, k)
	if v then
		return v
	elseif k == "_base" then
		-- Special case to allow class.is_instance/is_a checks to work without asserts.
		return nil
	end
	if type(k) == "string" then
		error(([[Bad enum access: Use SomeEnum.s.%s to get "%s".]]):format(k, k))
	elseif type(k) == "number" then
		error(("Bad enum access: Use SomeEnum:FromId(%d) to get string for %d."):format(k, k))
	end
	error("BAD ENUM ACCESS: "..tostring(k))
end
-- Don't use class.lua so we can use the above custom __index error checking.
Enum.__call = function(cls, ...)
	local obj = setmetatable({}, Enum)
	obj:ctor(...)
	return obj
end
setmetatable(Enum, Enum)

function Enum:ctor(ordered_keys)
	assert(ordered_keys[1], "Pass an ordered list of keys.")
	self._ordered_keys = ordered_keys
	-- self.id.blah gives index for enum blah
	self.id = lume.invert(ordered_keys)

	-- self.s.blah gives string value for enum blah
	self.s = {}
	for _,v in ipairs(ordered_keys) do
		assert(type(v) == "string", "Enums must be strings.")
		self.s[v] = v
	end
	strict.strictify(self._ordered_keys, "enum._ordered_keys")
	strict.strictify(self.id, "enum.id")
	strict.strictify(self.s, "enum.s")
end

-- Zero id doesn't show up in Ordered or other collections.
function Enum:SetIdZero(name)
	rawset(self._ordered_keys, 0, name)
	rawset(self.id, name, 0)
	rawset(self.s, name, name)
	return self
end

-- Whether the input string is one of the enum values.
function Enum:Contains(key)
	return rawget(self.s, key) ~= nil
end

-- Whether the input id is one of the enum ids.
function Enum:ContainsId(id)
	return rawget(self._ordered_keys, id) ~= nil
end

-- Get a string enum value from an int id.
-- Use fallback to return a value when the id is unknown (instead of asserting).
function Enum:FromId(id, fallback)
	if fallback and not self:ContainsId(id) then
		kassert.typeof("string", fallback)
		return fallback
	end
	return self._ordered_keys[id]
end

-- Return the string enum values in the input order.
function Enum:Ordered()
	return self._ordered_keys
end

function Enum:AlphaSorted()
	if not rawget(self, "_sorted_keys") then
		self._sorted_keys = lume.sort(self._ordered_keys)
		strict.strictify(self._sorted_keys, "enum._sorted_keys")
	end
	return self._sorted_keys
end

function Enum.IsEnumType(t)
	return type(t) == "table" and getmetatable(t) == Enum
end

local function test_enum()
	local Quacks = Enum{ "frog", "duck", }
	assert(Quacks.s.duck == "duck")
	assert(Quacks.id.frog == 1)
	assert(Quacks.id.duck == 2)

	local ordered = Quacks:Ordered()
	assert(ordered[1] == "frog")
	assert(ordered[2] == "duck")

	local sorted = Quacks:AlphaSorted()
	assert(sorted[1] == "duck")
	assert(sorted[2] == "frog")

	local v = Quacks.s.frog
	assert(Quacks:Contains(v))
	assert(Quacks:Contains("duck"))
	assert(not Quacks:Contains("bat"))
	assert(Quacks:ContainsId(1))
	assert(Quacks:ContainsId(3) == false)
	assert(Quacks:ContainsId(nil) == false)

	assert(Quacks:FromId(Quacks.id.frog))
	assert(Quacks.s.frog == Quacks:FromId(Quacks.id.frog))
	assert(Quacks.s.duck == Quacks:FromId(100, Quacks.s.duck))
	assert(Quacks.s.duck == Quacks:FromId(Quacks.id.duck, "<invalid>"))

	assert(not pcall(function()
		print(Quacks.s.yeti)
	end), "Should error on nonexistent enum use.")
	assert(not pcall(function()
		print(Quacks.id.yeti)
	end), "Should error on nonexistent enum use.")
	assert(not pcall(function()
		print(Quacks.frog)
	end), "Should error on incorrect enum access.")
	assert(not pcall(function()
		print(Quacks[1])
	end), "Should error on incorrect enum access.")

	-- We don't prevent reassignment of enums since that seems unlikely and
	-- overcomplicated.
	-- assert(not pcall(function()
	-- 	Quacks.s.frog = "duck"
	-- end))

	assert(Enum.IsEnumType(Quacks))
end

return Enum
