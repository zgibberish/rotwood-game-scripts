-- Emulates busted's test API with regular asserts.
local kassert = require "util.kassert"

local fakebusted = {
	assert = {
		is = {
			equal = kassert.equal,
			not_equal = kassert.not_equal,
		},
		is_not = {
			equal = kassert.not_equal,
			not_equal = kassert.equal,
		},
		is_equal = kassert.equal,
		is_not_true = kassert.not_true,
		is_not_truthy = kassert.not_truthy,
	},
}

local assert_fn = testy_assert or assert

setmetatable(fakebusted.assert, {
		__call = function(self, cond, msg)
			return assert_fn(cond, msg)
		end
	})

function fakebusted.assert.is_true(a)
	kassert.equal(a, true)
end

function fakebusted.assert.is_truthy(a)
	kassert.equal(not not a, true)
end

function fakebusted.assert.is_not_true(a)
	kassert.not_equal(a, true)
end

function fakebusted.assert.is_not_truthy(a)
	kassert.not_equal(not not a, true)
end

function fakebusted.pending(...)
	print("Skipping", ...)
end

function fakebusted.describe(title, fn)
	print()
	print(title)
	fn()
end

function fakebusted.it(action, fn)
	fn()
	print("", action)
end

function fakebusted.dump_globals()
	assert = fakebusted.assert
	describe = fakebusted.describe
	it = fakebusted.it
	pending = fakebusted.pending
end

return fakebusted
