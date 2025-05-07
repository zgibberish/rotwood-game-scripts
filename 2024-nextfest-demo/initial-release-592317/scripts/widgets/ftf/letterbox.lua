local Image = require "widgets.image"
local Widget = require "widgets.widget"
local easing = require "util.easing"
require "class"
require "strings.strings"


-- Apply additional letterboxing to screen (to adjust visible area to a wider
-- aspect than 16:9).
local Letterbox = Class(Widget, function(self)
	Widget._ctor(self, "Letterbox")

	self.visible_area = 0.88 -- percent
	self.duration = 0.5 -- seconds

	self.top = self:AddChild(Image("images/global/square.tex"))
		:SetMultColor(WEBCOLORS.BLACK)
	self.bottom = self:AddChild(Image("images/global/square.tex"))
		:SetMultColor(WEBCOLORS.BLACK)

	self.setstate_fn = function(t)
		self:SetDisplayAmount(t)
	end
	self:SetDisplayAmount(0)
end)

function Letterbox:IsDisplaying()
	return self.current_amount > 0
end

function Letterbox:SetDisplayAmount(t)
	self.current_amount = t
	local height = (1 - self.visible_area) * t
	self.top:StretchY(1, 1 - height)
	self.bottom:StretchY(0, height)
	return self
end

function Letterbox:AnimateIn()
	if self.updater then
		self.updater:Stop()
	end

	self.updater = self:RunUpdater(Updater.Series({
				Updater.Ease(self.setstate_fn, self.current_amount, 1, self.duration, easing.outQuad),
		}))

	return self
end

function Letterbox:AnimateOut()
	if self.updater then
		self.updater:Stop()
	end

	self.updater = self:RunUpdater(Updater.Series({
				Updater.Ease(self.setstate_fn, self.current_amount, 0, self.duration, easing.inQuad),
		}))

	return self
end

-- To tune: TheFrontEnd:GetLetterbox():DebugEdit()
function Letterbox:DebugDraw_AddSection(ui, panel)
	Letterbox._base.DebugDraw_AddSection(self, ui, panel)
	ui:Text("Letterbox")
	local changed
	changed, self.visible_area = ui:SliderFloat("Visible size", self.visible_area, 0, 1)
	if changed then
		self:SetDisplayAmount(1)
	end

	if ui:Button("AnimateIn") then
		self:AnimateIn()
	end
	if ui:Button("AnimateOut") then
		self:AnimateOut()
	end
end


return Letterbox
