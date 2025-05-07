--
-- strict.lua
--


-- Stripped in prod builds. Replaced with assert in dev. See luatools.cpp.
-- This line exists to silence lua-lsp warnings and ensure dbassert works in lua.exe
dbassert = assert


local strict = {}

local weak_keys_mt = {
	__mode = "k",
}

local function what()
	local d = debug.getinfo(3, "S")
	return d and d.what or "C"
end

-- Checks uses of undeclared variables
--
-- All global variables must be 'declared' by calling global() before being
-- used anywhere or assigned to inside a function.
--
-- Use on the global table: strict.forbid_undeclared(_G)
function strict.forbid_undeclared(target)
	local mt = getmetatable(target)
	if mt == nil then
		mt = {}
		setmetatable(target, mt)
	end

	function target.global(...)
		for _, v in ipairs{...} do mt.__declared[v] = true end
	end

	target.__STRICT = true
	mt.__declared = {}

	-- TODO(dbriscoe): I'm not sure this works. I can't intentionally make it
	-- fail. Maybe because everywhere I try shows up as main?
	mt.__newindex = function (t, n, v)
		if target.__STRICT and not mt.__declared[n] then
			local w = what()
			if w ~= "main" and w ~= "C" then
				error("assign to undeclared variable '"..n.."'", 2)
			end
			mt.__declared[n] = true
		end
		rawset(t, n, v)
	end

	mt.__index = function (t, n)
		if not mt.__declared[n] and what() ~= "C" then
			error("variable '"..n.."' is not declared", 2)
		end
		return rawget(t, n)
	end
end


local strict_labels = setmetatable({}, weak_keys_mt)
local STRICT_MT =
{
	__newindex = function(t, n, v)
		local w = what()
		if w ~= "main" and w ~= "C" then
			local table_name = strict_labels[t] or "t"
			assert(nil, ("Cannot assign new field '%s' in strict table '%s'. New entries are not allowed."):format(n, table_name))
		end
		rawset(t, n, v)
	end,

	__index = function(t, n)
		if what() ~= "C" then
			local table_name = strict_labels[t] or "t"
			assert(nil, ("'%s' does not exist in strict table '%s' (something like %s.%s is nil)."):format(n, table_name, table_name, n))
		end
		return rawget(t, n)
	end
}


-- Prevent adding new keys or accessing nonexistent ones.
--
-- Unlike forbid_undeclared, provides no way to add new keys.
-- Unlike readonly, allows modifying keys.
-- Usually create and populate a table and then apply strict to prevent typos.
function strict.strictify( t, table_name, recurse )
	dbassert(table_name == nil or type(table_name) == "string", "Second argument is the table name.")
	if getmetatable(t) == nil then
		strict_labels[t] = table_name
		setmetatable(t, STRICT_MT )
		if recurse then
			for k, v in pairs(t) do
				if type(v) == "table" then
					strict.strictify( v, table_name, recurse )
				end
			end
		end
	end
	return t
end

function strict.is_strict(t)
	return getmetatable(t) == STRICT_MT
end


local function readonly_err(t, k, v)
	error("Attempt to modify read-only table "..tostring(k).." = "..tostring(v))
end

-- Prevent modification of the table.
--
-- You must clobber your table with the returned value:
--   t = strict.readonly(t)
--
-- Unlike strictify, allows accessing nonexistent keys to check for existence
-- (and get nil).
function strict.readonly(t)
	for k, v in pairs(t) do
		if type(v) == "table" then
			t[k] = strict.readonly(v)
		end
	end

	assert(getmetatable(t) == nil)

	return setmetatable({}, {
		__index = t,
		__len = function(t2) return #t end,
		__pairs = function(t2) return pairs(t) end,
		__ipairs = function(t2) return ipairs(t) end,
		__newindex = readonly_err,
		-- Prevent tampering with metatable (getmetatable returns false).
		__metatable = false,
	})
end

local function test_readonly()
	local t = strict.readonly({ a = "hi", })
	assert(t.a)
	assert(not pcall(function()
		t.b = "there"
	end))
	assert(pcall(function()
		local b = t.a -- luacheck: ignore b
	end))
end


return strict
