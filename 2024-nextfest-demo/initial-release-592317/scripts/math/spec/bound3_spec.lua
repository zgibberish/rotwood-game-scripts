local bound3      = require "modules.bound3"
local vec3      = require "modules.vec3"
local DBL_EPSILON = require("modules.constants").DBL_EPSILON

describe("bound3:", function()
	it("creates an empty bound3", function()
		local a = bound3()
		assert.is.equal(0, a.min.x)
		assert.is.equal(0, a.min.y)
		assert.is.equal(0, a.min.z)
		assert.is.equal(0, a.max.x)
		assert.is.equal(0, a.max.y)
		assert.is.equal(0, a.max.z)
	end)

	it("creates a bound3 from vec3s", function()
		local a = bound3(vec3(1,2,3), vec3(4,5,6))
		assert.is.equal(1, a.min.x)
		assert.is.equal(2, a.min.y)
		assert.is.equal(3, a.min.z)
		assert.is.equal(4, a.max.x)
		assert.is.equal(5, a.max.y)
		assert.is.equal(6, a.max.z)
	end)

	it("creates a bound3 using new()", function()
		local a = bound3.new(vec3(1,2,3), vec3(4,5,6))
		assert.is.equal(1, a.min.x)
		assert.is.equal(2, a.min.y)
		assert.is.equal(3, a.min.z)
		assert.is.equal(4, a.max.x)
		assert.is.equal(5, a.max.y)
		assert.is.equal(6, a.max.z)
	end)

	it("creates a bound3 using at()", function()
		local a = bound3.at(vec3(4,5,6), vec3(1,2,3))
		assert.is.equal(1, a.min.x)
		assert.is.equal(2, a.min.y)
		assert.is.equal(3, a.min.z)
		assert.is.equal(4, a.max.x)
		assert.is.equal(5, a.max.y)
		assert.is.equal(6, a.max.z)
	end)

	it("clones a bound3", function()
		local a = bound3(vec3(1,2,3), vec3(4,5,6))
		local b = a:clone()
		a.max = vec3.new(9,9,9)
		assert.is.equal(a.min, b.min)
		assert.is.not_equal(a.max, b.max)
	end)

	it("uses bound3 check()", function()
		local a = bound3(vec3(4,2,6), vec3(1,5,3)):check()
		assert.is.equal(1, a.min.x)
		assert.is.equal(2, a.min.y)
		assert.is.equal(3, a.min.z)
		assert.is.equal(4, a.max.x)
		assert.is.equal(5, a.max.y)
		assert.is.equal(6, a.max.z)
	end)

	it("queries a bound3 size", function()
		local a = bound3(vec3(1,2,3), vec3(4,6,8))
		local v = a:size()
		local r = a:radius()
		assert.is.equal(3, v.x)
		assert.is.equal(4, v.y)
		assert.is.equal(5, v.z)

		assert.is.equal(1.5, r.x)
		assert.is.equal(2, r.y)
		assert.is.equal(2.5, r.z)
	end)

	it("sets a bound3 size", function()
		local a = bound3(vec3(1,2,3), vec3(4,5,6))
		local b = a:with_size(vec3(1,1,1))

		assert.is.equal(1, a.min.x)
		assert.is.equal(2, a.min.y)
		assert.is.equal(3, a.min.z)
		assert.is.equal(4, a.max.x)
		assert.is.equal(5, a.max.y)
		assert.is.equal(6, a.max.z)

		assert.is.equal(1, b.min.x)
		assert.is.equal(2, b.min.y)
		assert.is.equal(3, b.min.z)
		assert.is.equal(2, b.max.x)
		assert.is.equal(3, b.max.y)
		assert.is.equal(4, b.max.z)
	end)

	it("queries a bound3 center", function()
		local a = bound3(vec3(1,2,3), vec3(3,4,5))
		local v = a:center()
		assert.is.equal(2, v.x)
		assert.is.equal(3, v.y)
		assert.is.equal(4, v.z)
	end)

	it("sets a bound3 center", function()
		local a = bound3(vec3(1,2,3), vec3(3,4,5))
		local b = a:with_center(vec3(1,1,1))

		assert.is.equal(1, a.min.x)
		assert.is.equal(2, a.min.y)
		assert.is.equal(3, a.min.z)
		assert.is.equal(3, a.max.x)
		assert.is.equal(4, a.max.y)
		assert.is.equal(5, a.max.z)

		assert.is.equal(0, b.min.x)
		assert.is.equal(0, b.min.y)
		assert.is.equal(0, b.min.z)
		assert.is.equal(2, b.max.x)
		assert.is.equal(2, b.max.y)
		assert.is.equal(2, b.max.z)
	end)

	it("sets a bound3 size centered", function()
		local a = bound3(vec3(1,2,3), vec3(3,4,5))
		local b = a:with_size_centered(vec3(4,4,4))

		assert.is.equal(1, a.min.x)
		assert.is.equal(2, a.min.y)
		assert.is.equal(3, a.min.z)
		assert.is.equal(3, a.max.x)
		assert.is.equal(4, a.max.y)
		assert.is.equal(5, a.max.z)

		assert.is.equal(0, b.min.x)
		assert.is.equal(1, b.min.y)
		assert.is.equal(2, b.min.z)
		assert.is.equal(4, b.max.x)
		assert.is.equal(5, b.max.y)
		assert.is.equal(6, b.max.z)
	end)

	it("insets a bound3", function()
		local a = bound3(vec3(1,2,3), vec3(5,10,11))
		local b = a:inset(vec3(1,2,3))

		assert.is.equal(1, a.min.x)
		assert.is.equal(2, a.min.y)
		assert.is.equal(3, a.min.z)
		assert.is.equal(5, a.max.x)
		assert.is.equal(10, a.max.y)
		assert.is.equal(11, a.max.z)

		assert.is.equal(2, b.min.x)
		assert.is.equal(4, b.min.y)
		assert.is.equal(6, b.min.z)
		assert.is.equal(4, b.max.x)
		assert.is.equal(8, b.max.y)
		assert.is.equal(8, b.max.z)
	end)

	it("outsets a bound3", function()
		local a = bound3(vec3(1,2,3), vec3(5,6,7))
		local b = a:outset(vec3(1,2,3))

		assert.is.equal(1, a.min.x)
		assert.is.equal(2, a.min.y)
		assert.is.equal(3, a.min.z)
		assert.is.equal(5, a.max.x)
		assert.is.equal(6, a.max.y)
		assert.is.equal(7, a.max.z)

		assert.is.equal(0, b.min.x)
		assert.is.equal(0, b.min.y)
		assert.is.equal(0, b.min.z)
		assert.is.equal(6, b.max.x)
		assert.is.equal(8, b.max.y)
		assert.is.equal(10, b.max.z)
	end)

	it("offsets a bound3", function()
		local a = bound3(vec3(1,2,3), vec3(5,6,7))
		local b = a:offset(vec3(1,2,3))

		assert.is.equal(1, a.min.x)
		assert.is.equal(2, a.min.y)
		assert.is.equal(3, a.min.z)
		assert.is.equal(5, a.max.x)
		assert.is.equal(6, a.max.y)
		assert.is.equal(7, a.max.z)

		assert.is.equal(2, b.min.x)
		assert.is.equal(4, b.min.y)
		assert.is.equal(6, b.min.z)
		assert.is.equal(6, b.max.x)
		assert.is.equal(8, b.max.y)
		assert.is.equal(10, b.max.z)
	end)

	it("tests for points inside bound3", function()
		local a = bound3(vec3(1,2,3), vec3(4,5,6))

		assert.is_true(a:contains(vec3(1,2,3)))
		assert.is_true(a:contains(vec3(4,5,6)))
		assert.is_true(a:contains(vec3(2,3,4)))
		assert.is_not_true(a:contains(vec3(0,3,4)))
		assert.is_not_true(a:contains(vec3(5,3,4)))
		assert.is_not_true(a:contains(vec3(2,1,4)))
		assert.is_not_true(a:contains(vec3(2,6,4)))
		assert.is_not_true(a:contains(vec3(2,3,2)))
		assert.is_not_true(a:contains(vec3(2,3,7)))
	end)

	it("rounds a bound3", function()
		local a = bound3(vec3(1.1,1.9,3), vec3(3.9,5.1,6)):round()

		assert.is.equal(1, a.min.x)
		assert.is.equal(2, a.min.y)
		assert.is.equal(3, a.min.z)
		assert.is.equal(4, a.max.x)
		assert.is.equal(5, a.max.y)
		assert.is.equal(6, a.max.z)
	end)

	it("extends a bound3 with a point", function()
		local min = vec3(1,2,6)
		local max = vec3(4,5,9)
		local downright = vec3(8,8,10)
		local downleft = vec3(-4,8,10)
		local top = vec3(2, 0, 7)

		local a = bound3(min, max)
		local temp

		temp = a:extend(downright)
		assert.is_true(a.min == min and a.max == max)
		assert.is_true(temp.min == min and temp.max == downright)
		temp = a:extend(downleft)
		assert.is_true(temp.min == vec3(-4,2,6) and temp.max == vec3(4,8,10))
		temp = a:extend(top)
		assert.is_true(temp.min == vec3(1,0,6) and temp.max == max)
	end)

	it("extends a bound with another bound", function()
		local min = vec3(1,2,3)
		local max = vec3(4,5,6)
		local leftexpand = bound3.new(vec3(0,0,4), vec3(1.5,6,5))
		local rightexpand = bound3.new(vec3(1.5,0,1), vec3(5,6,7))

		local a = bound3(min, max)
		local temp

		temp = a:extend_bound(leftexpand)
		assert.is_equal(temp.min, vec3(0,0,3))
		assert.is_equal(temp.max, vec3(4,6,6))
		temp = temp:extend_bound(rightexpand)
		assert.is_equal(temp.min, vec3(0,0,1))
		assert.is_equal(temp.max, vec3(5,6,7))
	end)

	it("checks for bound3.zero", function()
		assert.is.equal(0, bound3.zero.min.x)
		assert.is.equal(0, bound3.zero.min.y)
		assert.is.equal(0, bound3.zero.min.z)
		assert.is.equal(0, bound3.zero.max.x)
		assert.is.equal(0, bound3.zero.max.y)
		assert.is.equal(0, bound3.zero.max.z)
	end)
end)
