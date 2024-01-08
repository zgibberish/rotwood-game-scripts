local ContentDB = require "questral.contentdb"
local strict = require "util.strict"


--Extends table

--Count the number of keys. Like #t, but for non-arrays.
function table.numkeys(t)
	local n = 0
	for k in pairs(t) do
		n = n + 1
	end
	return n
end

--Return an array of the keys of the input table.
function table.getkeys(t)
	local ret = {}
	for k in pairs(t) do
		ret[#ret + 1] = k
	end
	return ret
end

--Only for arrays
function table.reverse(t)
	local ret = {}
	local n = #t
	for i = 1, n do
		ret[i] = t[n - i + 1]
	end
	return ret
end

function table.invert(t)
	local ret = {}
	for k, v in pairs(t) do
		ret[v] = k
	end
	return ret
end

function table.contains(t, v)
	for _, tv in pairs(t) do
		if tv == v then
			return true
		end
	end
	return false
end

function table.find(t, v)
	for k, tv in pairs(t) do
		if tv == v then
			return k
		end
	end
	return nil
end

function table.arrayfind(t, v)
	for i = 1, #t do
		if t[i] == v then
			return i
		end
	end
	return nil
end

function table.arrayfind_onindex(t, index, v)
	for i = 1, #t do
		if t[i][index] == v then
			return i
		end
	end
	return nil
end

-- Count occurrences of v in t. See lume.count() to count predicate function
-- matches.
function table.count(t, v)
	local count = 0
	for k, tv in pairs(t) do
		if v == nil or tv == v then
			count = count + 1
		end
	end
	return count
end

function table.clear(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

-- Returns the removed value or nil if not found.
function table.removemapvalue(t, v)
	for k, tv in pairs(t) do
		if tv == v then
			t[k] = nil
			return v
		end
	end
end

-- Returns the removed value or nil if not found.
function table.removearrayvalue(t, v)
	for i = 1, #t do
		if t[i] == v then
			return table.remove(t, i)
		end
	end
end

function table.removeallofvalue(t, v)
	for k, tv in pairs(t) do
		if tv == v then
			t[k] = nil
		end
	end
end

function table.removeallofarrayvalue(t, v)
	for i = 1, #t do
		if t[i] == v then
			--Found first instance
			--Shift kept values down to fill removed spaces
			for j = i + 1, #t do
				if t[j] ~= v then
					t[i] = v
					i = i + 1
				end
			end
			--Clear remainder of array
			for j = i, #t do
				t[j] = nil
			end
			return
		end
	end
end

function table.appendarrays(t, ...)
	for i=1, select('#', ...) do
		local arg = select(i, ...)
		for j = 1, #arg do
			t[#t + 1] = arg[j]
		end
	end
	return t
end

local function test_appendarrays()
	local a = { 1, 2, 3, }
	local b = { 4, 5, 6, }
	local t = {}
	t = table.appendarrays(t, a, b)
	for i=1,6 do
		assert(i == t[i], "copies multiple source into dest")
	end
	t = table.appendarrays({}, a)
	local aa = table.appendarrays(a)
	for i=1,3 do
		assert(i == t[i], "copies single source into dest")
		assert(i == aa[i], "leaves single input untouched")
	end
end

--Returns a new array with the difference between the two provided arrays
function ExceptionArrays(tSource, tException)
	local ret = {}
	for i = 1, #tSource do
		local v = tSource[i]
		if not table.contains(tException, v) then
			ret[#ret + 1] = v
		end
	end
	return ret
end

-- Merge array-style tables, only allowing each value once. Returns an array table.
function ArrayUnion(...)
	local args = { ... }
	local ret = {}
	for i = 1, #args do
		local arg = args[i]
		for j = 1, #arg do
			local v = arg[j]
			if not table.contains(ret, v) then
				ret[#ret + 1] = v
			end
		end
	end
	return ret
end

--Return only values found in all arrays
function ArrayIntersection(...)
	local args = { ... }
	local arg1 = args[1]
	local ret = {}
	for i = 1, #arg1 do
		local v = arg1[i]
		for j = 2, #args do
			if not table.contains(args[j], v) then
				v = nil
				break
			end
		end
		if v ~= nil then
			ret[#ret + 1] = v
		end
	end
	return ret
end


-- Merge map-style tables into the first one, overwriting duplicate keys with
-- the latter map's value. Subtables are recursed into. Formerly MergeMapsDeep.
-- For nonrecursive (old MergeMaps behaviour), see lume.overlaymaps.
function table.overlaymaps_deep(dest, ...)
	-- TODO(dbriscoe): Use select like overlaymaps.
	local args = { ... }

	local keys = {}
	for i = 1, #args do
		for k, v in pairs(args[i]) do
			if keys[k] == nil then
				keys[k] = type(v)
			else
				assert(keys[k] == type(v), "Attempting to merge incompatible tables.")
			end
		end
	end

	for k, t in pairs(keys) do
		if t == "table" then
			local subtables = {}
			for i = 1, #args do
				local v = args[i][k]
				if v ~= nil then
					subtables[#subtables + 1] = v
				end
			end
			dest[k] = table.overlaymaps_deep({}, table.unpack(subtables))
		else
			for i = 1, #args do
				local v = args[i][k]
				if v ~= nil then
					dest[k] = v
				end
			end
		end
	end

	return dest
end

-- only use on indexed tables (list tables)!
function GetFlattenedSparse(tab)
	local keys = {}
	for index,value in pairs(tab) do keys[#keys+1]=index end
	table.sort(keys)

	local ret = {}
	for _,oidx in ipairs(keys) do
		ret[#ret+1]=tab[oidx]
	end
	return ret
end

-- Allows you to defer table creation until it will be nonempty to avoid alloc
-- lots of empty tables.
-- DO NOT use to test for empty. Use next(t) instead.
table.empty = strict.readonly({})


-- True if recursively equal.
function deepcompare(a, b)
	if type(a) ~= type(b) then
		return false
	end

	if type(a) == "table" then
		for k, v in pairs(a) do
			if not deepcompare(v, b[k]) then
				return false
			end
		end

		for k, v in pairs(b) do
			if a[k] == nil then
				return false
			end
		end

		return true
	else
		return a == b
	end
end


local function _copy(object, lookup_table)
	if type(object) ~= "table" then
		return object
	elseif lookup_table[object] then
		return lookup_table[object]
	elseif EntityScript.is_instance(object) then
		error("You cannot copy entities. Instead, spawn a new instance of the same prefab.")
	elseif ContentDB.is_instance(object) then
		error("You cannot copy quest/content objects. Instead, call q:OnSave() to get their saveable data.")
	end

	local new_table = {}
	lookup_table[object] = new_table
	for k, v in pairs(object) do
		new_table[_copy(k, lookup_table)] = _copy(v, lookup_table)
	end
	local mt = getmetatable(object)
	assert(mt ~= false, "Can't deepcopy a hidden metatable. Try deepcopyskipmeta instead.")
	return setmetatable(new_table, mt)
end

-- Recursively copy an object and any of the tables, keys, values contained within.
function deepcopy(object)
	return _copy(object, {})
end

local function _copyskipmeta(object, lookup_table)
	if type(object) ~= "table" then
		return object
	elseif lookup_table[object] then
		return lookup_table[object]
	end

	local new_table = {}
	lookup_table[object] = new_table
	for k, v in pairs(object) do
		new_table[_copyskipmeta(k, lookup_table)] = _copyskipmeta(v, lookup_table)
	end
	return new_table
end

-- deepcopy, but don't set any metatables.
function deepcopyskipmeta(object)
	return _copyskipmeta(object, {})
end

local function _copy_stringifymeta(object, lookup_table)
	if type(object) ~= "table" then
		return object
	elseif getmetatable(object) ~= nil then
		return tostring(object)
	elseif lookup_table[object] then
		return lookup_table[object]
	end

	local new_table = {}
	lookup_table[object] = new_table
	for k, v in pairs(object) do
		new_table[_copy_stringifymeta(k, lookup_table)] = _copy_stringifymeta(v, lookup_table)
	end
	return new_table
end

-- deepcopy, except tables *with metatables* are stored as a string instead of
-- a table.
--
-- Useful when you don't really need a copy of the table, but you want to stash
-- an inspectable version of it. Especially useful with types that implement
-- __tostring.
function deepcopy_stringifymeta(object)
	return _copy_stringifymeta(object, {})
end


function shallowcopy(object)
	if type(object) ~= "table" then
		return object
	end

	local ret = {}
	for k, v in pairs(object) do
		ret[k] = v
	end
	return ret
end

-- Get a table index as if the table were circular.
--
-- You probably want circular_index instead.
-- Due to Lua's 1-based arrays, this is more complex than usual.
function circular_index_number(count, index)
	local zb_current = index - 1
	local zb_result = zb_current
	zb_result = zb_result % count
	return zb_result + 1
end

-- Index a table as if it were circular.
-- Use like this:
--      next_item = circular_index(item_list, index + 1)
function circular_index(t, index)
	return t[circular_index_number(#t, index)]
end
