local kassert = require "util.kassert"
local lume = require "util.lume"


-- Iterator alternatives to ipairs and pairs.
local iterator = {}

local function keys_to_list(t, key_compare)
	local list = {}
	local index = 1
	for key in pairs(t) do
		list[index] = key
		index = index + 1
	end
	table.sort(list, key_compare)
	return list
end

-- Like pairs() but iterates in sorted order.
-- Creates a new table and closure every time it is called.
--
-- See http://lua-users.org/wiki/SortedIteration
--
-- table: t Dict-like table to iterate.
-- function: key_compare An optional function to compare the keys.
--
-- returns: iterator
function iterator.sorted_pairs(t, key_compare)
	local list = keys_to_list(t, key_compare)
	return iterator.indexed_pairs(t, list)
end


-- Iterate with a specific list of keys. Useful when you don't want to sort
-- before each iteration like sorted_pairs.
-- Creates a new closure every time it is called. I can't see how to avoid the
-- closure.
--
-- table: t Dict-like table to iterate.
-- table: keys Array of keys from t.
--
-- returns: iterator
function iterator.indexed_pairs(t, keys)
	local i = 0
	return function()
		i = i + 1
		local key = keys[i]
		if key ~= nil then
			return key, t[key]
		else
			return nil, nil
		end
	end
end
local function test_indexed_pairs()
	local wave = { cat = 2, dog = 1, frog = 10, cow = 5, }
	local keys = lume(wave)
		:keys()
		:sort()
		:result()
	local t = {}
	for key,val in iterator.indexed_pairs(wave, keys) do
		table.insert(t, key)
	end
	kassert.deepequal(keys, t)

	t = {}
	for key,val in iterator.indexed_pairs(wave, keys) do
		table.insert(t, key)
	end
	kassert.deepequal(keys, t, "Repeated iteration should work")
end

-- ripairs originally from lume
local ripairs_iter = function(t, i)
  i = i - 1
  local v = t[i]
  if v ~= nil then
    return i, v
  end
end

--- Performs the same function as `ipairs()` but iterates in reverse; this allows
-- the removal of items from the table during iteration without any items being
-- skipped.
-- ```lua
-- -- Prints "3->c", "2->b" and "1->a" on separate lines
-- for i, v in iterator.ripairs({ "a", "b", "c" }) do
--   print(i .. "->" .. v)
-- end
-- ```
function iterator.ripairs(t)
  return ripairs_iter, t, (#t + 1)
end


local function coro_err_filter(success, ...)
	-- Must abort on error or we'll infinite loop.
	assert(success, ...)
	return ...
end

-- Iterate over values yielded from a coroutine.
function iterator.coroutine(fn)
	local co = coroutine.create(fn)
	return function()
		-- Return all the results yielded from the coroutine and skip the
		-- return code. The end of the coroutine should return nil to stop
		-- iteration.
		return coro_err_filter(coroutine.resume(co))
	end
end

local function test_coroutine()
	local function coro()
		coroutine.yield(1, 2, 3)
		coroutine.yield(1, 2, 1)
	end
	local x = 3
	for a,b,c in iterator.coroutine(coro) do
		assert(a == 1)
		assert(c == x)
		x = a
	end
end


return iterator
