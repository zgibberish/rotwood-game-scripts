local Vector2 = require "math.modules.vec2"
local kassert = require "util.kassert"
require "class"
require "util.tableutil"
require "vector2"

local function empty_table(x,y)
	return {}
end

--- An array2d for lua.
-- Grid(Vector2, fn(x,y))
--
-- Use it like a table of tables:
--   g = Grid(v)
--   g[1][2] = 10
--
-- @cell_ctor (optional) is a function to call to create each grid element.
local Grid = Class(function(self, size, cell_ctor)
	cell_ctor = cell_ctor or empty_table

	self.size = ToVector2(size)
	for x=1,self.size.x do
		local column = {}
		self[x] = column
		for y=1,self.size.y do
			self[x][y] = cell_ctor(x,y)
		end
	end
end)

function Grid:GetSaveData()
	local data = deepcopy(self)
	data.size = nil
	setmetatable(data, nil)
	return data
end

function Grid:LoadSaveData(data)
	local cols = 0
	for key,val in pairs(data) do
		assert(type(key) == "number", key)
		self[key] = val
		cols = cols + 1
	end
	self.size = Vector2(cols, #self[1])
	return self
end


-- Value at position defined by vector.
function Grid:At(v)
	return self[v.x][v.y]
end

-- Value at position or nil if either is out of bounds.
function Grid:GetSafe(x, y)
	kassert.typeof('number', x,y)
	local column = self[x]
	return column and column[y] or nil
end

function Grid:tostring(cell_tostring)
	cell_tostring = cell_tostring or tostring
	local str = ""
	for y=1,self.size.y do
		for x=1,self.size.x do
			str = str .. cell_tostring(self[x][y]) .. "\t"
		end
		str = str .. "\n"
	end
	return str
end

local function test_grid()
	local g = Grid(Vector2(10, 10), function(x,y)
		return { x = x, y = y }
	end)
	local serpent = require "util.serpent"
	print()
	print(g:tostring(serpent.line))
	print(serpent.block(g[1][4]))
	local gg = Grid(Vector2(1, 1))
	gg:LoadSaveData(g:GetSaveData())
	kassert.equal(g[1][5].x, gg[1][5].x)
	kassert.equal(g[1][5].y, gg[1][5].y)
end

return Grid
