local Widget = require "widgets.widget"
local Image = require("widgets/image")


-- A background decoration we use when displaying currency (konjur things).
local CurrencyRings = Class(Widget, function(self, scale)
	Widget._ctor(self, "CurrencyRings")
	assert(scale)

	local rotationSpeed = 0.2

	self.ring_center = self:AddChild(Image("images/ui_ftf_relic_selection/konjurdrawing.tex"))
		:SetScale(scale)
		:Offset(-10 * HACK_FOR_4K,7 * HACK_FOR_4K)
		:RotateIndefinitely(-rotationSpeed*0.2 - (math.random() * 0.01))

	self.ring_one = self:AddChild(Image("images/ui_ftf_relic_selection/konjurdrawing.tex"))
		:SetScale(scale * 0.65)
		:LayoutBounds("center", "center", self.ring_center)
		:Offset(-33 * HACK_FOR_4K, 86 * HACK_FOR_4K)
		:AlphaTo(0.4, 0)
		:RotateIndefinitely(-rotationSpeed - (math.random() * 0.01))

	self.ring_two = self:AddChild(Image("images/ui_ftf_relic_selection/konjurdrawing.tex"))
		:SetScale(scale * 0.65)
		:LayoutBounds("center", "center", self.ring_center)
		:Offset(-74 * HACK_FOR_4K, -90 * HACK_FOR_4K)
		:AlphaTo(0.4, 0)
		:RotateIndefinitely(-rotationSpeed - (math.random() * 0.02))

	self.ring_three = self:AddChild(Image("images/ui_ftf_relic_selection/konjurdrawing.tex"))
		:SetScale(scale * 0.65)
		:LayoutBounds("center", "center", self.ring_center)
		:Offset(109 * HACK_FOR_4K, -25 * HACK_FOR_4K)
		:AlphaTo(0.45, 0)
		:RotateIndefinitely(rotationSpeed + (math.random() * 0.015))
end)

-- You probably want to align to this widget.
function CurrencyRings:GetCenterWidget()
	return self.ring_center
end

return CurrencyRings
