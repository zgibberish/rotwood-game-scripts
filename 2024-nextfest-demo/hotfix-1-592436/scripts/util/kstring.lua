local kassert = require "util.kassert"


local kstring = {}

-- Get the raw tostring output (table address) even if using __tostring metamethod.
function kstring.raw(t)
	-- From GLN. Formerly rawstring.
	local mt = type(t) == "table" and getmetatable( t )
	if mt then
		-- Seriously, is there any better way to bypass the tostring metamethod?
		setmetatable( t, nil )
		local s = tostring( t )
		setmetatable( t, mt )
		return s
	else
		return tostring(t)
	end
end

function kstring.first_to_upper(str)
	return str:gsub("^%l", string.upper)
end

function kstring.is_lower(str)
    return str:find("%u") == nil
end

-- True if the input string contains whitespace and is only whitespace. Same
-- idea as python's isspace.
function kstring.is_whitespace(str)
	return string.find(str, "^%s-$") ~= nil
end

function kstring.trim(str)
	return string.match(str, "^()%s*$") and "" or string.match(str, "^%s*(.*%S)")
end

function kstring.split(self, sep)
	sep = sep or ":"
	local fields = {}
	local pattern = string.format("([^%s]+)", sep)
	self:gsub(pattern, function(c) fields[#fields+1] = c end)
	return fields
end

-- Like kstring:split, but split on a lua regex pattern instead of a list of characters.
function kstring.split_pattern(str, inSplitPattern, outResults)
	-- from gln
	inSplitPattern = inSplitPattern or " "
	if not outResults then
		outResults = {}
	end
	local start = 1
	local split_start, split_end = string.find( str, inSplitPattern, start )
	while split_start do
		if split_start-1 >= start then
			table.insert( outResults, string.sub( str, start, split_start-1 ) )
		end
		start = split_end + 1
		split_start, split_end = string.find( str, inSplitPattern, start )
	end
	if start <= #str then
		table.insert( outResults, string.sub( str, start ) )
	end
	return outResults
end

local function test_split()
	local s = kstring.split_pattern("hello there heroes")
	assert(#s == 3)
	assert(s[1] == "hello")
	s = kstring.split_pattern("hello there heroes", "he")
	kassert.equal(#s, 3)
	kassert.equal(s[1], "llo t")
	kassert.equal(s[2], "re ")
	s = kstring.split("hello there heroes", "he")
	kassert.equal(#s, 5)
end

-- Check if the beginning of str matches prefix. Analogous to python's
-- startswith().
function kstring.startswith(str, prefix)
	return string.sub(str, 1, string.len(prefix)) == prefix
end

-- Check if the end of str matches suffix. Analogous to python's
-- endswith().
function kstring.endswith(str, suffix)
	return suffix == '' or string.sub(str, -string.len(suffix)) == suffix
end

-- Check if first character of str is capitalized.
function kstring.is_capitalized(str)
	return string.find(str, "^%u")
end

-- usage:
-- subfmt("this is my {adjective} string, read it {number} times!", {adjective="cool", number="five"})
-- => "this is my cool string, read it five times"
function kstring.subfmt(str, tab)
	return (str:gsub('(%b{})', function(w) return tab[w:sub(2, -2)] or w end))
end

function kstring.abbreviate(str, limit)
	assert(limit > 3)
	if str:len() <= limit then
		return str
	end
	return str:sub(1, limit - 3) .. "..."
end

local function test_abbreviate()
	kassert.equal("Hello...", kstring.abbreviate("Hello World", 8))
	kassert.equal("Hello World", kstring.abbreviate("Hello World", 18))
end


-- Like string.find, but returns an array of first,last pairs. Never returns
-- nil. Does not return captures -- if you want text matches, see
-- string.gmatch.
function kstring.findall(s, pattern, init, plain)
	local matches = {}
	local first = init or 1
	local last = first
	while first ~= nil do
		first, last = s:find(pattern, first, plain)
		if first ~= nil then
			table.insert(matches, {first,last})
			first = last + 1
		end
	end
	return matches
end

-- Like string.find, but finds the last match. init is normal index (1 is first
-- character).
function kstring.rfind(s, pattern, init, plain)
	local matches = kstring.findall(s, pattern, init, plain)
	if #matches > 0 then
		return table.unpack(matches[#matches])
	end
	return nil
end

-- Like string.find, but finds the last match and always does plain matches.
-- init is normal index (1 is first character).
function kstring.rfind_plain(s, query, init)
	local s_rev = s:reverse()
	local query_rev = query:reverse()
	local first,last = s_rev:find(query_rev, init, true)
	local len = #s
	if first then
		return len - last + 1, len - first + 1
	end
	return nil
end


-- Pass to table.sort to sort alphabetically but case insensitive.
function kstring.cmp_alpha_case_insensitive(a, b)
	return string.upper(a) < string.upper(b)
end


-- Caching for kstring.random
local Chars = {}
for Loop = 0, 255 do
	Chars[Loop+1] = string.char(Loop)
end
local String = table.concat(Chars)
local Built = {['.'] = Chars}

local AddLookup = function(CharSet)
	local Substitute = string.gsub(String, '[^'..CharSet..']', '')
	local Lookup = {}
	for Loop = 1, string.len(Substitute) do
		Lookup[Loop] = string.sub(Substitute, Loop, Loop)
	end
	Built[CharSet] = Lookup

	return Lookup
end

-- Creates a random string of the given length with the input char set.
-- Length (number)
-- CharSet (string, optional); e.g. %l%d for lower case letters and digits
function kstring.random(Length, CharSet)
	CharSet = CharSet or '.'

	if CharSet == '' then
		return ''
	else
		local Result = {}
		local Lookup = Built[CharSet] or AddLookup(CharSet)
		local Range = #Lookup

		for Loop = 1,Length do
			Result[Loop] = Lookup[math.random(1, Range)]
		end

		return table.concat(Result)
	end
end



local function test_startsendswith()
	assert(kstring.startswith("bludjday", "blud"))
	assert(kstring.startswith("bludjday", ""))

	assert(kstring.endswith("bludjday", "jday"))
	assert(kstring.endswith("bludjday", ""))
end




-- Add some methods directly to string.
-- These can be called on strings:
-- * text:split()
-- * ("ha ha"):split(" ")
string.abbreviate = kstring.abbreviate
string.endswith = kstring.endswith
string.findall = kstring.findall
string.first_to_upper = kstring.first_to_upper
string.is_capitalized = kstring.is_capitalized
string.is_lower = kstring.is_lower
string.is_whitespace = kstring.is_whitespace
string.rfind = kstring.rfind
string.rfind_plain = kstring.rfind_plain
string.split = kstring.split
string.split_pattern = kstring.split_pattern
string.startswith = kstring.startswith
string.subfmt = kstring.subfmt
string.trim = kstring.trim

return kstring
