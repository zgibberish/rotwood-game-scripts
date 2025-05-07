-- Add functions for debug tracking. Only add them if you want them to run and
-- they'll be no ops if missing.
local tracker = {}

local function noop() end
local mt = {
	__index = function(t, k)
		-- Missing tracker do noop so we don't need nil checks everywhere.
		return noop
	end
}

-- Add trackers to the returned table and set to nil to remove them.
function tracker.CreateTrackerSet()
	return setmetatable({}, mt)
end

return tracker
