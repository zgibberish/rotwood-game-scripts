require "class"


Pool = Class(function(self, createfn, getfn, recyclefn)
	self.pool = {}
	self.createfn = createfn
	self.getfn = getfn
	self.recyclefn = recyclefn
end)

--------------------------------------------------------------------------

local _recycled_mt =
{
	__index = function(t, k) assert(false, "Reading from recycled object.") end,
	__newindex = function(t, k, v) assert(false, "Writing to recycled object.") end,
}

local function _make_invalid(self, obj)
	local mt = getmetatable(obj)
	if self._mt == nil then
		self._mt = mt
	elseif self._mt ~= mt then
		return false
	end
	setmetatable(obj, _recycled_mt)
	return true
end

local function _make_valid(self, obj)
	if getmetatable(obj) ~= _recycled_mt then
		return false
	end
	setmetatable(obj, self._mt)
	return true
end

local function _check_valid(self, obj)
	return getmetatable(obj) == self._mt
end

--------------------------------------------------------------------------

function Pool:Get()
	local n = #self.pool
	if n > 0 then
		local obj = self.pool[n]
		self.pool[n] = nil
		dbassert(_make_valid(self, obj))
		if self.getfn ~= nil then
			self.getfn(obj)
		end
		dbassert(_check_valid(self, obj))
		return obj
	end
	return self.createfn()
end

function Pool:Recycle(obj)
	self.pool[#self.pool + 1] = obj
	if self.recyclefn ~= nil then
		self.recyclefn(obj)
	end
	dbassert(_make_invalid(self, obj))
end

--------------------------------------------------------------------------

local function CreateTable()
	return {}
end

local ValidateEmptyTable
if DEV_MODE then
	ValidateEmptyTable = function(tbl)
		assert(next(tbl) == nil, "Recycled table is not empty.")
	end
end

SimpleTablePool = Class(Pool, function(self)
	Pool._ctor(self, CreateTable, ValidateEmptyTable, ValidateEmptyTable)
end)

return Pool
