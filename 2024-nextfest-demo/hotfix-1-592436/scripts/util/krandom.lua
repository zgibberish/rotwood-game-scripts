local Vector2 = require "math.modules.vec2"
local Vector3 = require "math.modules.vec3"
local kassert = require "util.kassert"
local lume = require "util.lume"
require "class"
require "util"



-- A module wrapper around RandomGenerator.
--
-- For when you want random numbers, but don't need the extra features
-- (save/load) of an rng stream. For API, see RandomGenerator below.
--
-- Also exposes Create/LoadGenerator to get a RandomGenerator object with
-- serializable state.
local krandom = {}



-- A random number generator that relies on a native implementation to support
-- serializable state.
local RandomGenerator = Class(function(self, w_or_state, z, rnd_class)
	assert(
		(w_or_state == nil and z == nil) or
		(type(w_or_state) == "string" and z == nil) or
		(type(w_or_state) == "number" and z == nil) or
		(type(w_or_state) == "number" and type(z) == "number"))

	if rnd_class then
		self.rng = rnd_class(w_or_state, z)

	else
		-- See random_luaproxy.cpp for how args are handled.
		self.rng = Random(w_or_state, z)
	end
end)

function RandomGenerator:GetState()
	return self.rng:GetState()
end

--- Shuffles list t in place.
function RandomGenerator:Shuffle(t)
	for i = 1, #t do
		local r = self:Integer(i, #t)
		t[i], t[r] = t[r], t[i]
	end
	return t
end

--- Shuffles a clone of list t.
function RandomGenerator:ShuffleCopy(t)
	-- shallowcopy is non-deterministic
	-- return self:Shuffle(shallowcopy(t))
	local ct = {}
	for i,v in ipairs(t) do
		ct[i] = v
	end
	return self:Shuffle(ct)
end

local function test_rng_Shuffle()
	local mock = require "util.mock"
	mock.set_globals()

	local rng = RandomGenerator()
	local t = { 1, 2, 3, 4, 5, }
	rng:ShuffleCopy(t)
	assert(t[1] == 1)
	assert(t[5] == 5)
	rng:Shuffle(t)
	assert(#t == 5)
	t = { 1, 2, }
	rng:Shuffle(t)
	assert(#t == 2)
	t = { 1, }
	rng:Shuffle(t)
	assert(#t == 1)
	assert(t[1] == 1)
end

-- Expanded version of sum_weights.
-- It provides the weighted total and prepares a shallow copy of the choices that
-- is deterministic, assuming the choices can be uniquely sorted.
local function MakeSortedChoiceArrayWithTotalWeight(choices)
	local choices_array = {}
	local total = 0
	for choice,weight in pairs(choices) do
		table.insert(choices_array, choice)
		dbassert(weight >= 0, "Weights must be nonnegative.")
		total = total + weight
	end
	dbassert(total >= 0, "Weights should sum to 0.")
	table.sort(choices_array)
	return choices_array, total

end

--- Takes the argument table `choices` where the keys are the possible choices
-- and each value is the choice's weight. A weight should be 0 or above, and
-- the larger the number the higher the probability of that choice being
-- picked. If the table is empty, a weight is below zero or all the weights are
-- 0 then an error is raised.
-- ```lua
-- RandomGenerator:WeightedChoice({ cat = 10, dog = 5, frog = 0 })
-- -- Returns either "cat" or "dog" with "cat" being twice as likely to be chosen.
-- ```
function RandomGenerator:WeightedChoice(choices)
	local choices_array, total = MakeSortedChoiceArrayWithTotalWeight(choices)

	local threshold = self:Float(total)
	-- TheLog.ch.Random:printf("WeightedChoice threshold: %f", threshold)
	local last_choice
	for _, choice in ipairs(choices_array) do
		local weight = choices[choice]
		threshold = threshold - weight
		if threshold <= 0 then
			return choice
		end
		last_choice = choice
	end
	return last_choice
end

--- Takes the argument table `choices` where the keys are the possible choices
-- and the value is the choice's weight, just like WeightedChoice. But instead
-- of choosing a single value, it generates an array that matches this
-- distribution. Similar to shuffle bag, but works for weighted values.
-- ```lua
-- RandomGenerator:WeightedFill({ cat = 5, dog = 2, frog = 3 }, 10)
-- -- Returns a list with 5 "cat", 2 "dog", 3 "frog".
-- ```
function RandomGenerator:WeightedFill(choices, count)
	local t = {}
	local choices_array, total = MakeSortedChoiceArrayWithTotalWeight(choices)

	local picked = 0
	for _, choice in ipairs(choices_array) do
		local weight = choices[choice]
		local n = lume.round((weight / total) * count)
		for i=1,n do
			table.insert(t, choice)
		end
		picked = picked + n
	end
	-- Using round makes us over fill, but that's better than randomly filling
	-- up the array.
	while picked > count do
		table.remove(t, self:Integer(#t))
		picked = picked - 1
	end
	kassert.lesser_or_equal(picked, count)
	-- Rare case where we can't reach perfect distribution, so use weighting to
	-- determine remaining (minimal) fill.
	local n = count - picked
	picked = picked + n
	for i=1,n do
		table.insert(t, self:WeightedChoice(choices))
	end
	kassert.equal(picked, count)
	-- We insert ordered and then more odds and ends, so shuffle to produce a
	-- known state.
	self:Shuffle(t)
	return t
end

local function test_rng_WeightedFill()
	local mock = require "util.mock"
	mock.set_globals()

	local rng = RandomGenerator()
	-- Perfect distribution.
	local t = rng:WeightedFill({ cat = 5, dog = 2, frog = 3 }, 10)
	local freq = lume.frequency(t)
	kassert.equal(freq.cat, 5)
	kassert.equal(freq.dog, 2)
	kassert.equal(freq.frog, 3)

	-- Uneven split.
	t = rng:WeightedFill({ cat = 7, dog = 2, frog = 3 }, 10)
	freq = lume.frequency(t)
	kassert.bounded(5,  freq.cat, 6) -- 7/12 = 5.8
	kassert.bounded(1,  freq.dog, 2) -- 2/12 = 1.7
	kassert.bounded(1, freq.frog, 3) -- 3/12 = 2.5

	-- Heavily biased uneven split.
	t = rng:WeightedFill({ cat = 9, dog = 2, frog = 3 }, 10)
	freq = lume.frequency(t)
	kassert.bounded(5,  freq.cat, 7) -- 9/15 = 6.0
	kassert.bounded(1,  freq.dog, 2) -- 2/15 = 1.3
	kassert.bounded(1, freq.frog, 3) -- 3/15 = 2.0
end

-- Returns a random item from the input list or dict table.
function RandomGenerator:PickValue(choices)
	local k,v = self:PickKeyValue(choices)
	return v
end

-- Like PickValue, but only works on list tables.
function RandomGenerator:PickFromArray(choices)
	return choices[self:Integer(#choices)]
end

-- Returns a random key and its item from the input list or dict table.
function RandomGenerator:PickKeyValue(choices)
	-- Sort for determinism.
	local keys = lume.sort(lume.keys(choices))
	local choice = self.rng:Random(#keys)
	local pick = keys[choice]
	return pick, choices[pick]
end

-- Made to work with (And return) array-style tables
-- This function does not preserve the original table
function RandomGenerator:PickSome(num, choices)
	dbassert(num <= #choices)
	local l_choices = choices
	local ret = {}
	for i=1,num do
		local choice = self.rng:Random(#l_choices)
		table.insert(ret, l_choices[choice])
		table.remove(l_choices, choice)
	end
	return ret
end

function RandomGenerator:PickSomeWithDups(num, choices)
	local l_choices = choices
	local ret = {}
	for i=1,num do
		local choice = self.rng:Random(#l_choices)
		table.insert(ret, l_choices[choice])
	end
	return ret
end

--- Returns a random floating point number between `a` and `b`.
-- With both args, returns a number in [a,b).
-- If only `a` is supplied, a number in [0,a) is returned.
-- If no arguments are supplied, a number in [0,1) is returned.
function RandomGenerator:Float(a, b)
	-- Originally from lume.random.
	if not a then a, b = 0, 1 end
	if not b then a, b = 0, a end
	return a + self.rng:Random() * (b - a)
end

--- Returns a random integer between `a` and `b`.
-- With both args, returns a number in [a,b].
-- If only `a` is supplied, a number in [1,a] is returned.
function RandomGenerator:Integer(a, b)
	dbassert(a, "Must pass a maximum value to define the range.")
	if not b then a, b = 1, a end
	return self.rng:Random(a, b)
end

--- Returns a random boolean.
--
-- Useful for coin flip logic.
-- Pass a float in (0,1) to adjust the odds of the coin flip: higher makes it
-- more likely to return true.
function RandomGenerator:Boolean(probability_of_true)
	probability_of_true = probability_of_true or 0.5
	return self:Float() < probability_of_true
end

local function test_rng_Boolean()
	local mock = require "util.mock"
	mock.set_globals()

	local rng = RandomGenerator()
	assert(not rng:Boolean(0))
	assert(rng:Boolean(1))
end

function RandomGenerator:Sign(probability_of_positive)
	if self:Boolean(probability_of_positive) then
		return 1
	end
	return -1
end

local function test_rng_Sign()
	local mock = require "util.mock"
	mock.set_globals()

	local rng = RandomGenerator()
	assert(math.abs(rng:Sign()) == 1)
end

--- Returns a random unit vector (length = 1) with angle
-- in [min_angle, max_angle] in degrees and the chosen angle (in radians).
-- Angle is from y axis so:
-- * Vec2_Unit(-10, 10) will be clustered around a line going up.
-- * Vec2_Unit(89, 91) will be clustered around a line going to the right.
function RandomGenerator:Vec2_Unit(min_angle, max_angle)
	min_angle = min_angle or 0
	max_angle = max_angle or 360
	local angle = self:Float(min_angle, max_angle)
	angle = math.rad(angle)
	return Vector2.unit_y:rotate(-angle), angle
end

local function test_rng_Vec2Unit()
	local mock = require "util.mock"
	mock.set_globals()

	local rng = RandomGenerator()
	kassert.equal(lume.round(rng:Vec2_Unit():len(), 0.01), 1)
	kassert.equal(lume.round(rng:Vec2_Unit(32.4):len(), 0.01), 1)
	kassert.equal(lume.round(rng:Vec2_Unit(45, 90):len(), 0.01), 1)
end


--- Returns a random unit vector with zero y component. Useful for offsetting
-- in xz.
function RandomGenerator:Vec3_FlatOffset(magnitude)
	assert(magnitude, "Vec3_FlatOffset requires a length for the offset.")
	local v, angle = self:Vec2_Unit()
	return Vector3(v.x * magnitude, 0, v.y * magnitude), angle
end

local function test_rng_Vec3FlatOffset()
	local mock = require "util.mock"
	mock.set_globals()

	local rng = RandomGenerator()
	kassert.equal(lume.round(rng:Vec3_FlatOffset(10):len(), 0.01), 10)
	kassert.equal(lume.round(rng:Vec3_FlatOffset(32.4):len(), 0.01), 32.4)
end


function RandomGenerator:SetDebug(enabled, label)
	self.rng:SetDebug(enabled, label)
end










-- Like Random userdata, but uses global system random generator.
local SystemRng = Class(function(self, seed)
	if seed then
		kassert.typeof("number", seed)
		math.randomseed(seed)
	end
end)
function SystemRng:Random(...)
	return math.random(...)
end
function SystemRng:SetDebug()
	print("WARNING: SetDebug is not supported on krandom.")
end
function SystemRng:GetState()
	error("GetState is not supported on krandom.")
end


-- Copy RandomGenerator API into krandom.
-- Use a RandomGenerator that uses system random that it's callable from tests
-- and responds to changes in math.randomseed.
local rng = RandomGenerator(nil, nil, SystemRng)
for key in pairs(RandomGenerator) do
	krandom[key] = function(...)
		return rng[key](rng, ...)
	end
end

-- You probably shouldn't use this. Exported for mock.
krandom._SystemRng = SystemRng



-- Pass two seed values or pass none for smart auto seeding.
function krandom.CreateGenerator(w, z)
	return RandomGenerator(w, z)
end

-- Load from serializable data retrieved from the generator's GetState().
function krandom.LoadGenerator(state)
	kassert.typeof("string", state)
	return RandomGenerator(state)
end


-- Can't use testy since Random is native.
function krandom.test_generator()
	local rand_gen = krandom.CreateGenerator(238974928374298347, 2374923847293)
	assert(rand_gen:Integer(0, 10) == 10)

	local state = rand_gen:GetState()
	assert(rand_gen:Integer(0, 10) == 0)
	local reloaded = krandom.LoadGenerator(state)
	assert(reloaded:Integer(0, 10)    == 0)

	assert(rand_gen:Integer(0, 10) == 4)
	assert(reloaded:Integer(0, 10)    == 4)
	assert(rand_gen:Integer(0, 10) == 1)
	assert(reloaded:Integer(0, 10)    == 1)
	print("Tests complete")
end




-- krandom tests copied from RandomGenerator.

local function test_glob_Shuffle()
	local t = { 1, 2, 3, 4, 5, }
	krandom.ShuffleCopy(t)
	assert(t[1] == 1)
	assert(t[5] == 5)
	krandom.Shuffle(t)
	assert(#t == 5)
	t = { 1, 2, }
	krandom.Shuffle(t)
	assert(#t == 2)
	t = { 1, }
	krandom.Shuffle(t)
	assert(#t == 1)
	assert(t[1] == 1)
end

local function test_glob_WeightedFill()
	-- Perfect distribution.
	local t = krandom.WeightedFill({ cat = 5, dog = 2, frog = 3 }, 10)
	local freq = lume.frequency(t)
	kassert.equal(freq.cat, 5)
	kassert.equal(freq.dog, 2)
	kassert.equal(freq.frog, 3)

	-- Uneven split.
	t = krandom.WeightedFill({ cat = 7, dog = 2, frog = 3 }, 10)
	freq = lume.frequency(t)
	kassert.bounded(5,  freq.cat, 6) -- 7/12 = 5.8
	kassert.bounded(1,  freq.dog, 2) -- 2/12 = 1.7
	kassert.bounded(1, freq.frog, 3) -- 3/12 = 2.5

	-- Heavily biased uneven split.
	t = krandom.WeightedFill({ cat = 9, dog = 2, frog = 3 }, 10)
	freq = lume.frequency(t)
	kassert.bounded(5,  freq.cat, 7) -- 9/15 = 6.0
	kassert.bounded(1,  freq.dog, 2) -- 2/15 = 1.3
	kassert.bounded(1, freq.frog, 3) -- 3/15 = 2.0
end

local function test_glob_Pick()
	-- A bunch of tests for basic behaviour and to get lua-lsp to see krandom
	-- functions and offer for completion.
	local choices = { "cat", "dog", "frog" }

	kassert.typeof("string", krandom.PickValue(choices))
	kassert.typeof("string", krandom.PickFromArray(choices))

	local k,v = krandom.PickKeyValue(choices)
	kassert.typeof("number", k)
	kassert.typeof("string", v)

	local num = 2
	assert(num == #krandom.PickSome(num, choices))
	num = 10
	assert(num == #krandom.PickSomeWithDups(num, choices))
	kassert.typeof("number", krandom.Float(0, 100))
	kassert.typeof("number", krandom.Integer(-5, 5))

	kassert.typeof("string", krandom.WeightedChoice({ cat = 10, dog = 5, frog = 0 }))
end

return krandom
