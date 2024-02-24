local Text = require "widgets.text"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local kassert = require "util.kassert"
local templates = require "widgets.ftf.templates"
require "class"
require "strings.strings"


-- Show a lower third title card to introduce a named character.
local TitleCard = Class(Widget, function(self, titlekey)
	Widget._ctor(self, "TitleCard")

	self.titlekey = titlekey
	local t = STRINGS.TITLE_CARDS[titlekey]
	kassert.assert_fmt(t, "Missing STRINGS.TITLE_CARDS.%s for showing titlecard.", titlekey)

	self.root = self:AddChild(Widget("TitleCard root"))
	self.bg = self.root:AddChild(templates.SmallOverlayBackground())
		:SetSize(50, 50)
	self.title = self.root:AddChild(Text(FONTFACE.TITLE, FONTSIZE.OVERLAY_TITLE))
		:SetText(t.TITLE or STRINGS.NAMES[titlekey])
		:SetGlyphColor(UICOLORS.OVERLAY)
		:LayoutBounds("right", "top", self)
	self.lowerthird = self.root:AddChild(Text(FONTFACE.TITLE, FONTSIZE.OVERLAY_SUBTITLE))
		:SetText(t.LOWERTHIRD)
		:SetGlyphColor(UICOLORS.OVERLAY_LIGHT)
		:LayoutBounds("center", "below", self.title)
		:Offset(0, -10)
	self.bg:SizeToWidgets({50, 25}, self)

	self.setpos_fn = function(x)
		self.root:SetPosition(x, 0)
	end

	self.setalpha_fn = function(a)
		self.root:SetMultColor(1, 1, 1, a)
	end

	self.setalpha_fn(0)
end)

function TitleCard:AnimateIn()
	if self.updater then
		return
	end

	local duration = 0.25

	self.updater = self:RunUpdater(Updater.Parallel({
				Updater.Ease(self.setpos_fn,   -200, 0, duration, easing.outCirc),
				Updater.Ease(self.setalpha_fn, 0,    1, duration, easing.inQuart),
		}))

	return self
end

function TitleCard:FadeAndRemove()
	if self.updater then
		self.updater:Stop()
	end

	local offscreen = self:GetSize()
	local duration = 0.5

	self.updater = self:RunUpdater(Updater.Series({
				Updater.Parallel({
						Updater.Ease(self.setpos_fn,   0, offscreen, duration, easing.inCirc),
						Updater.Ease(self.setalpha_fn, 1, 0,         duration, easing.inQuart),
					}),
				Updater.Do(function()
					self:Remove()
				end),
		}))

	return self
end


return TitleCard
