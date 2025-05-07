local Widget = require "widgets.widget"
local Image = require "widgets.image"

local CenteredWidget = Class(Widget, function(self, width)
	Widget._ctor(self, "CenteredWidget")

	self.hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetMultColor(HexToRGB(0x00ff0040))
		:SetSize(width, 20 * HACK_FOR_4K)
		:SetMultColorAlpha(0)
end)

return CenteredWidget
