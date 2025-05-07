local kassert = require "util.kassert"
local lume = require "util.lume"


-- See also ../math/modules/ for math types.
local kmath = {}

local function sum(a, b)
	return a + b
end

--- Adds the values in a list.
-- t (table) a list of numbers or tables
-- key (string, optional) if t is a list of tables, the key containing the value to sum
function kmath.sum(t, key)
	if key then
		return lume.reduce(t, function(a, b)
			return a + b[key]
		end, 0)
	else
		return lume.reduce(t, sum)
	end
end

local function test_sum()
	kassert.equal(kmath.sum({1, 2, 3}), 6)
	kassert.equal(kmath.sum({{a=1, b=2, c=3}, {c=8, d=9}}, 'c'), 11)
end

function kmath.use_nil_as_true(x)
	return x == nil or x
end

local function test_use_nil_as_true()
	assert(kmath.use_nil_as_true(true) == true)
	assert(kmath.use_nil_as_true(false) == false)
	assert(kmath.use_nil_as_true(nil) == true)
	assert(kmath.use_nil_as_true({}))
end

function kmath.polar_to_cartesian(r, theta)
	return {
		x = r * math.cos(theta),
		z = r * math.sin(theta)
	}
end

return kmath
