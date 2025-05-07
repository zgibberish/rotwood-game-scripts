local Panel = require("widgets/panel")
local Text = require("widgets/text")
local Widget = require("widgets/widget")

------------------------------------------------------------------------------------------
--- A title widget for the map, with the name of the current region
----
local MapTitleWidget = Class(Widget, function(self)
	Widget._ctor(self, "MapTitleWidget")

	self.frameContainer = self:AddChild(Widget())
	self.frameLeft = self.frameContainer:AddChild(Panel("images/map_ftf/map_title_frame_left.tex"))
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetNineSliceCoords(100, 42, 150, 58)
		:SetNineSliceBorderScale(0.5)
		:SetSize(300 * HACK_FOR_4K, 200 * HACK_FOR_4K)
	self.frameRight = self.frameContainer:AddChild(Panel("images/map_ftf/map_title_frame_right.tex"))
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetNineSliceCoords(100, 42, 150, 58)
		:SetNineSliceBorderScale(0.5)
		:SetSize(300 * HACK_FOR_4K, 200 * HACK_FOR_4K)

	self.textContent = self:AddChild(Widget())
	self.title = self.textContent:AddChild(Text(FONTFACE.DEFAULT, 60, "", UICOLORS.LIGHT_TEXT_DARK))
end)

function MapTitleWidget:SetTitle(title)
	self.title:SetText(title)

	local w, h = self.title:GetSize()
	w = math.max(w, 200) + 130
	h = h + 60

	self.frameLeft:SetSize( w / 2, h)
	self.frameRight:SetSize( w / 2, h)
		:LayoutBounds("after", nil, self.frameLeft)

	self.textContent:LayoutBounds("center", "top", self.frameContainer)
		:Offset(0, -15)

	return self
end

return MapTitleWidget
