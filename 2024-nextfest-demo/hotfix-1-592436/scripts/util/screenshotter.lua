require "class"


local is_first_instance = true

-- A wrapper around TheSim's screenshot callback to add some extra validation
-- and functionality.
local Screenshotter = Class(function(self)
	assert(is_first_instance, "Only one Screenshotter can register for the screenshot callback.")
	is_first_instance = false

	self.cb = nil
	self._screenshotcb = function(...)
		self:_ScreenshotReady(...)
	end
	TheSim:SetScreenshotReadyFn(self._screenshotcb)
end)

function Screenshotter:RequestScreenshot(cb)
	assert(cb, "Must pass a callback.")
	assert(not self.cb, "Screenshot already in progress.")
	self.cb = cb
	TheSim:RequestScreenshot()
end

function Screenshotter:RequestScreenshotAsFile(filename, complete_cb)
	assert(filename)
	local function capture_cb()
		TheSim:SaveLastScreenshotAsFile(filename)
		if complete_cb then
			complete_cb(filename)
		end
	end
	self:RequestScreenshot(capture_cb)
end

function Screenshotter:_ScreenshotReady(texture_handle)
	assert(self.cb, "No screenshot in progress?")
	local cb = self.cb
	self.cb = nil
	cb(texture_handle)
end

return Screenshotter
