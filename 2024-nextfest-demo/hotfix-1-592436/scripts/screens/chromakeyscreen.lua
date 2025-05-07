local Screen = require "widgets.screen"
local templates = require "widgets.ftf.templates"
require "util.colorutil"


-- A debug screen that makes the bg magenta so you can easily take a screenshot
-- and cut out the background.
local ChromaKeyScreen = Class(Screen, function(self)
	Screen._ctor(self, "ChromaKeyScreen")
	self.bg = self:AddChild(templates.BackgroundTint())
	self:SetMagenta()
end)

function ChromaKeyScreen:SetMagenta()
	self.bg:SetMultColor(HexToRGBFloats(0xff00ffff))
	return self
end

function ChromaKeyScreen:SetBlack()
	self.bg:SetMultColor(HexToRGBFloats(0x000000ff))
	return self
end

function ChromaKeyScreen:ScreenshotWidget(w, cb)
	local old_parent = w.parent
	w:Reparent(self)
	self:Show()
	-- Save two versions so you can get selection from magenta but then copy
	-- from black to retain crisp black outlines. Would be better to save with
	-- transparency.
	self:SetMagenta()
	TheScreenshotter:RequestScreenshotAsFile("widget-bg", function()
		self:SetBlack()
		TheScreenshotter:RequestScreenshotAsFile("widget-fg", function()
			w:Reparent(old_parent)
			self:Hide()
			if cb then
				cb()
			end
		end)
	end)
end

return ChromaKeyScreen
