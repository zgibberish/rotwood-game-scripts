-- class.lua
-- Compatible with Lua 5.1 (not 5.0).

local kassert = require "util.kassert"
require "util.kstring"


local TrackClassInstances = false

ClassRegistry = {}

if TrackClassInstances == true then
	global("ClassTrackingTable")
	global("ClassTrackingInterval")

	ClassTrackingInterval = 100
end


Class = {}

function Class._CopyInheritedFunctions(base, c, c_inherited)
	-- Most inherited functions are looked up with __index, but metamethods are
	-- looked up with rawget and require manual copying.
	--
	-- Store inherited members in c_inherited so we can get rid of them while
	-- monkey patching for hot reload.
	for k,v in pairs(base) do
		if k:startswith("__") and type(v) == "function" then
			local fn = base[k]
			c[k] = fn
			c_inherited[k] = fn
		end
	end
end

local function _is_a(self, klass)
	local m = getmetatable(self)
	while m do
		if m == klass then return true end
		m = m._base
	end
	return false
end

local function is_class(self)
	return rawget(self, "is_instance") ~= nil
end

local function CreateClass(_, base, _ctor)
	local c = {}    -- a new class instance
	local c_inherited = {}
	if not _ctor and type(base) == 'function' then
		_ctor = base
		base = nil
	elseif type(base) == 'table' then
		Class._CopyInheritedFunctions(base, c, c_inherited)
		c._base = base
	end

	-- the class will be the metatable for all its objects,
	-- and they will look up their methods in it.
	c.__index = c

	-- expose a constructor which can be called by <classname>(<args>)
	local mt = {}

	if TrackClassInstances == true and CWD ~= nil then
		if ClassTrackingTable == nil then
			ClassTrackingTable = {}
		end
		ClassTrackingTable[mt] = {}
		local dataroot = "@"..CWD.."\\"
		local tablemt = {}
		setmetatable(ClassTrackingTable[mt], tablemt)
		tablemt.__mode = "k"         -- now the instancetracker has weak keys

		local source = "**unknown**"
		if _ctor then
			-- what is the file this ctor was created in?

			local info = debug.getinfo(_ctor, "S")
			-- strip the drive letter
			-- convert / to \\
			source = info.source
			source = string.gsub(source, "/", "\\")
			source = string.gsub(source, dataroot, "")
			local path = source

			local file = io.open(path, "r")
			if file ~= nil then
				local count = 1
				for i in file:lines() do
					if count == info.linedefined then
						source = i
						-- okay, this line is a class definition
						-- so it's [local] name = Class etc
						-- take everything before the =
						local equalsPos = string.find(source,"=")
						if equalsPos then
							source = string.sub(source,1,equalsPos-1)
						end
						-- remove trailing and leading whitespace
						source = source:gsub("^%s*(.-)%s*$", "%1")
						-- do we start with local? if so, strip it
						if string.find(source,"local ") ~= nil then
							source = string.sub(source,7)
						end
						-- trim again, because there may be multiple spaces
						source = source:gsub("^%s*(.-)%s*$", "%1")
						break
					end
					count = count + 1
				end
				file:close()
			end
		end

		mt.__call = function(class_tbl, ...)
			local obj = {}
			setmetatable(obj, c)
			ClassTrackingTable[mt][obj] = source
			if c._ctor then
				c._ctor(obj, ...)
			end
			return obj
		end
	else
		mt.__call = function(class_tbl, ...)
			local obj = {}
			setmetatable(obj, c)
			if c._ctor then
				c._ctor(obj, ...)
			end
			return obj
		end
	end

	-- Lookup inherited functions in base class.
	mt.__index = base

	c._ctor = _ctor
	c.is_a = _is_a					-- is_a: is descendent of this class
	c.is_class = is_class			-- is_class: is self a class instead of an instance
	c.is_instance = function(obj)	-- is_instance: is obj an instance of this class
		return type(obj) == "table" and _is_a(obj, c)
	end
	c.add_mixin = function(self, mixin)
		-- Mixins allow us to add a common set of operations to a class without
		-- multiple inheritance or deferring to a subobject. Useful for adding
		-- a common API that lazily creates its state.
		kassert.typeof("table", mixin) -- mixin can only be a table of functions.
		assert(self == c, "Only support mixins at the class level, not the instance level.")

		if rawget(c, "_mixins") == nil then
			-- Track mixins separately from parent class. Tracking is just for
			-- validation and has_mixin.
			c._mixins = {}
		end
		assert(not c._mixins[mixin], "Mixin already exists")

		for k, v in pairs(mixin) do
			kassert.typeof("string", k) -- keys must be names
			kassert.typeof("function", v) -- forbid state in mixins
			kassert.assert_fmt(c[k] == nil, "Function exists in class and mixin: %s", k)
			c[k] = v
		end

		c._mixins[mixin] = true
	end
	c.has_mixin = function(self, mixin)
		return (self._mixins and self._mixins[mixin])
			or (self._base and self._base.has_mixin(self._base, mixin))
	end

	setmetatable(c, mt)
	ClassRegistry[c] = c_inherited
	-- local count = 0
	-- for i,v in pairs(ClassRegistry) do
	-- 	count = count + 1
	-- end
	-- if string.split then
	-- 	print("ClassRegistry size : "..tostring(count))
	-- end
	return c
end

setmetatable(Class, {
	__call = CreateClass,
})



-- Checks if the input table is a class. Use MyClass.is_instance or
-- ClassA:is_a(ClassB) to check for relationships.
function Class.IsClassOrInstance(t)
	return type(t) == "table"
		and t.is_class
end
function Class.IsClass(t)
	return Class.IsClassOrInstance(t)
		and t:is_class()
end

function ReloadedClass(mt)
	ClassRegistry[mt] = nil
end

local lastClassTrackingDumpTick = 0

function HandleClassInstanceTracking()
	if TrackClassInstances and CWD ~= nil then
		lastClassTrackingDumpTick = lastClassTrackingDumpTick + 1

		if lastClassTrackingDumpTick >= ClassTrackingInterval then
			collectgarbage()
			print("------------------------------------------------------------------------------------------------------------")
			lastClassTrackingDumpTick = 0
			if ClassTrackingTable then
				local sorted = {}
				local index = 1
				for i,v in pairs(ClassTrackingTable) do
					local count = 0
					local first = nil
					for j,k in pairs(v) do
						if count == 1 then
							first = k
						end
						count = count + 1
					end
					if count>1 then
						sorted[#sorted+1] = {first, count-1}
					end
					index = index + 1
				end
				-- get the top 10
				table.sort(sorted, function(a,b) return a[2] > b[2] end)
				for i=1,10 do
					local entry = sorted[i]
					if entry then
						print(tostring(i).." : "..tostring(sorted[i][1]).." - "..tostring(sorted[i][2]))
					end
				end
				print("------------------------------------------------------------------------------------------------------------")
			end
		end
	end
end
