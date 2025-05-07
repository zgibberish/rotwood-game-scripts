local Panel = require "widgets/panel"
local Text = require "widgets/text"
local Widget = require "widgets/widget"
local kassert = require "util.kassert"

--------------------------------------------------------------------
-- Basic tooltip, just a text label on a panelled background.

local Tooltip = Class(Widget, function(self, width)
	Widget._ctor(self)

	self.padding_h = 25 * HACK_FOR_4K
	self.padding_v = 20 * HACK_FOR_4K

	-- Calculate content width
	width = width or DEFAULT_TT_WIDTH
	width = width - self.padding_h * 2

	self.bg = self:AddChild(Panel("images/ui_ftf_shop/tooltip_bg.tex"))
		:SetNineSliceCoords(124, 71, 130, 78)
	self.text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.TOOLTIP))
		:SetAutoSize(width)
		:SetWordWrap(true)
		:LeftAlign()
		:OverrideLineHeight(FONTSIZE.TOOLTIP - 2) -- presumably to make them compact?
		:SetGlyphColor(UICOLORS.TOOLTIP_TEXT)
	self:Hide()
end)

Tooltip.LAYOUT_SCALE =
{
    [SCREEN_MODE.MONITOR] = 1,
    [SCREEN_MODE.TV] = 1.5,
    [SCREEN_MODE.SMALL] = 1.5,
}

-- @returns whether the layout was successful (and should be displayed).
function Tooltip:LayoutWithContent(txt)
	kassert.typeof("string", txt)

	-- Update contents
	self.text:SetText(txt or "")

	-- Resize background to contents
	local w, h = self.text:GetSize()
	w = w + self.padding_h * 2
	h = h + self.padding_v * 2
	self.bg:SetSize(w, h)

	-- Layout
	self.text:LayoutBounds("left", "top", self.bg)
		:Offset(self.padding_h, -self.padding_v + 2)

	return true
end

return Tooltip
