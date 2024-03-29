-- For tools that run vanilla lua, require this first to get close to the
-- game's lua environment.
-- TODO: can we move this out of data/scripts/?

assert(TheSim == nil, "Do not import nativeshims from game code!")

print("Requiring files and setting globals to mimic native environment.")

local function safe_require(modulepath)
	local success, module = pcall(require, modulepath)
	if success then
		return module
	end
	print("WARNING: Failed to import module:", modulepath)
	--~ print(module) -- this is very verbose
end

require "util.strict" -- for dbassert

-- Allow imported code to use our logging.
TheLog = require("util.logchan")()

local lfs = safe_require "lfs"

local function matchesWildcard(str, pattern)
	-- Convert DOS wildcard pattern to Lua pattern
	pattern = pattern:gsub(".", {
			["%"] = "%%",
			["."] = "%.",
			["*"] = ".*",
			["?"] = ".",
			["+"] = ".+",
			["-"] = ".-",
			["["] = "%[",
			["]"] = "%]",
			["("] = "%(",
			[")"] = "%)",
		})

	-- Check if the string matches the pattern
	return string.match(str, "^" .. pattern .. "$") ~= nil
end

TheSim = {}
-- Requires lua.exe to be run with the root of the project as a working
-- directory because file paths include data/ directory.
TheSim.ListFiles = function(self, path, searchpattern, filetype)
	if not lfs then
		return {}
	end

	local FILES = 1
	local DIRS = 2
	local BOTH = 3

	local res = {}
	path = "data/"..path.."/."
	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." then
			local attr = lfs.attributes(path.."/"..file)
			assert (type(attr) == "table")
			local valid_type = (filetype == FILES and attr.mode == "file") or (filetype == DIRS and attr.mode == "directory") or (filetype == BOTH)
			--print("","file:",file,"type:",attr.mode,valid_type,matchesWildcard(file, searchpattern))
			if valid_type and matchesWildcard(file, searchpattern) then
				--print(file)
				table.insert(res,file)
			end
		end
	end
	return res
end


Platform = require "util.platform"
require "util.kstring"
require "class"
require "strings.strings"
require "constants"
TUNING = require("tuning")()
require "prefabs"
require "vector2"
require "vector3"
require "entityscript"
require "util.pool"
