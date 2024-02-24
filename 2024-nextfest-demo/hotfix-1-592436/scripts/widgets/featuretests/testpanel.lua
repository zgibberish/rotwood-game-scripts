local Panel = require "widgets/panel"

-- Merely here to test Focus gain/loss on panel
local TestPanel = Class(Panel, function(self, tex, dw, dh, innerpw, innerph)
	Panel._ctor(self, tex, dw, dh, innerpw, innerph)
	self:SetHoverCheck(true)
	self:SetMultColor(1, 1, 1, 0.5)
end)

function TestPanel:OnGainHover()
	TestPanel._base.OnGainHover(self)
    	self:SetMultColor(1, 1, 1, 1)
end

function TestPanel:OnLoseHover()
	TestPanel._base.OnLoseHover(self)
	self:SetMultColor(1, 1, 1, 0.5)
end

function TestPanel:OnGainFocus()
	TestPanel._base.OnGainFocus(self)
end

function TestPanel:OnLoseFocus()
	TestPanel._base.OnLoseFocus(self)
end

function TestPanel:OnControl(controls, down)
end

return TestPanel
