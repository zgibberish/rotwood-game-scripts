local kassert = {}

local up_one_level = 2

-- Only do string formatting if assert fails.
function kassert.assert_fmt(cond, fmt, ...)
	if not cond then
		error(fmt:format(...), up_one_level)
	end
	return cond
end

function kassert.equal(a,b, msg, level)
	local cond = a == b
	if not cond then
		msg = msg or "Expected equal values"
		error(("%s: %s == %s"):format(msg, tostring(a), tostring(b)), level or up_one_level)
	end
	return cond
end

function kassert.deepequal(a,b, msg, level)
	local inspect = require "inspect"
	require "util.tableutil"

	local cond = deepcompare(a, b)
	if not cond then
		msg = msg or "Expected recursively equal values/tables"
		local cfg = { depth = 5, process = inspect.processes and inspect.processes.slim, }
		local a_dump = inspect(a, cfg)
		local b_dump = inspect(b, cfg)
		error(("%s: %s (a) == %s (b)\na = %s\nb = %s"):format(msg, tostring(a), tostring(b), a_dump, b_dump), level or up_one_level)
	end
	return cond
end

function kassert.not_equal(a,b, msg)
	local cond = a ~= b
	if not cond then
		msg = msg or "Expected unequal values"
		error(("%s: %s != %s"):format(msg, tostring(a), tostring(b)), up_one_level)
	end
	return cond
end

function kassert.lesser(a,b, msg)
	local cond = a < b
	if not cond then
		msg = msg or "Expected first to be lesser"
		error(("%s: %s < %s"):format(msg, tostring(a), tostring(b)), up_one_level)
	end
	return cond
end

function kassert.lesser_or_equal(a,b, msg)
	local cond = a <= b
	if not cond then
		msg = msg or "Expected first to be lesser"
		error(("%s: %s <= %s"):format(msg, tostring(a), tostring(b)), up_one_level)
	end
	return cond
end

function kassert.greater(a,b, msg)
	local cond = a > b
	if not cond then
		msg = msg or "Expected first to be greater"
		error(("%s: %s > %s"):format(msg, tostring(a), tostring(b)), up_one_level)
	end
	return cond
end

function kassert.greater_or_equal(a,b, msg)
	local cond = a >= b
	if not cond then
		msg = msg or "Expected first to be greater"
		error(("%s: %s >= %s"):format(msg, tostring(a), tostring(b)), up_one_level)
	end
	return cond
end

function kassert.bounded(min,a,max, msg)
	local cond = min <= a and a <= max
	if not cond then
		msg = msg or "Expected middle to be within bounds"
		error(("%s: %s <= %s <= %s"):format(msg, tostring(min), tostring(a), tostring(max)), up_one_level)
	end
	return cond
end


--- Assert all inputs are the expected type.
-- Useful for verifying function inputs.
function kassert.typeof(expected, ...)
	local all_cond = true
	for i = 1, select("#", ...) do
		local cond = kassert.equal(type(select(i, ...)), expected, ("Type mismatch at [%i]"):format(i), up_one_level + 1)
		all_cond = all_cond and cond
	end
	return all_cond
end


-- testy_wrap_asserts is called automatically by testy.
local function noop() end
function kassert.testy_wrap_asserts()
	for key,fn in pairs(kassert) do
		if key[1] ~= "_" and fn ~= kassert.testy_wrap_asserts then
			kassert[key] = function(...)
				local cond = fn(...)
				if testy_assert then			-- luacheck: ignore 113
					return testy_assert(cond)	-- luacheck: ignore 113
				end
				return cond
			end
		end
	end
	kassert.testy_wrap_asserts = noop -- prevent multiple nesting.
	return true
end

local function test_should_pass()
	kassert.testy_wrap_asserts()
	kassert.equal(10, 10)
	kassert.not_equal(10, 100)
	kassert.lesser(10, 100)
	kassert.lesser_or_equal(10, 10)
	kassert.greater(20, 10)
	kassert.greater_or_equal(20, 20)
	kassert.typeof('number', 20)
end

--~ local function test_should_fail()
--~ 	kassert.equal(10, 30)
--~ 	kassert.not_equal(100, 100)
--~ 	kassert.lesser(100, 10)
--~ 	kassert.lesser_or_equal(100, 10)
--~ 	kassert.greater(10, 20)
--~ 	kassert.greater_or_equal(200, 20)
--~ 	kassert.typeof('number', "20")
--~ end

return kassert
