local Widget = require("widgets/widget")
local Text = require("widgets/text")
local Panel = require("widgets/panel")
local easing = require "util.easing"

local ProgressBar =  Class(Widget, function(self)
	Widget._ctor(self, "ProgressBar")

	self.time_hurt_bar_visible = 1.0
	self._fade_hurt_bar_task = nil

	self.inner_height = 30

	self.current = 0
	self.max_progress = 100

	self.container = self:AddChild(Widget())

	self.bar_root = self.container:AddChild(Widget("Bar Root"))
		:SendToBack()

	self.bg = self.bar_root:AddChild(Panel("images/ui_ftf_segmented_healthbar/bar_fill.tex"))
		:SetNineSliceCoords(10, 2, 81, 28)
		:SetMultColor(0.2, 0.2, 0.2)

	self.mask = self.bar_root:AddChild(Panel("images/ui_ftf_segmented_healthbar/bar_fill.tex"))
		:SetNineSliceCoords(10, 2, 81, 28)
		:SetMask()

	self.progress = self.bar_root:AddChild(Panel("images/ui_ftf_segmented_healthbar/bar_fill.tex"))
		:SetHiddenBoundingBox(true)
		:SetClickable(false)
		:SetNineSliceCoords(10, 2, 81, 28)
		:SetMultColor(HexToRGB(0XC7B213FF))
		:SetMasked()
		:SetBlocksMouse(false)

	self.inner_widgets =
	{
		self.bg,
		self.mask,
		self.progress
	}

	self.border = self.bar_root:AddChild(Panel("images/ui_ftf_segmented_healthbar/9_slice_border.tex"))
		:SetMultColor(0, 0, 0, 1)
		:SetNineSliceCoords(35, 4, 110, 34)
		:SendToBack()

	self.text_root = self.container:AddChild(Widget("Text Root"))
	self.outline = self.text_root:AddChild(Text(FONTFACE.DEFAULT, self.inner_height, nil, UICOLORS.BLACK))
		:EnableShadow()
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:EnableOutline()
		:SetOutlineColor(UICOLORS.BLACK)
	self.text = self.text_root:AddChild(Text(FONTFACE.DEFAULT, self.inner_height, nil, UICOLORS.LIGHT_TEXT_TITLE))

end)

function ProgressBar:SetMaxProgress(num)
	self.max_progress = num
end

function ProgressBar:SetBarSize(width, height)
	for _, widget in ipairs(self.inner_widgets) do
		widget:SetSize(width, height)
	end
	self.border:SetInnerSize(width, height)
	local w, h = self.border:GetSize()
	w = w * 1.2
	h = h * 1.3
	self:SetScissor(-w/2, -h/2, w, h)
end

function ProgressBar:SetProgressPercent(percent)
	self.current = math.floor(self.max_progress * percent)
	local bar_w, bar_h = self.mask:GetSize()
	local x_offset = (1 - percent) * bar_w
	self.progress:LayoutBounds("left", "center", self.bg)
		:Offset(-x_offset, 0)
	self:UpdateText()
end

function ProgressBar:UpdateText()
	self.text:SetText(string.format("%s/%s", self.current, self.max_progress))
	self.outline:SetText(string.format("%s/%s", self.current, self.max_progress))

	self.text_root:LayoutBounds("left", "center", self.bg)
		:Offset(10, 0)
end

function ProgressBar:ProgressTo(from, to, ...)
	self:ProgressToPercent(from/self.max_progress, to/self.max_progress, ...)
end

function ProgressBar:ProgressToPercent(from, to, time, easefn, cbfn)
	self:SetProgressPercent(from)
	self.time_updating = 0
	self.target_time = time

	self.start_percent = from
	self.end_percent = to
	self.easefn = easefn
	self.cbfn = cbfn

	self.inst:StartUpdatingComponent(self)
end

function ProgressBar:OnUpdate(dt)
	self.time_updating = self.time_updating + dt
	local percent = self.easefn(self.time_updating, self.start_percent, self.end_percent - self.start_percent, self.target_time)
	self:SetProgressPercent(percent)

	if self.time_updating > self.target_time then
		self:SetProgressPercent(self.end_percent)
		if self.cbfn then
			self.cbfn()
		end
		self.inst:StopUpdatingComponent(self)
	end
end

return ProgressBar
