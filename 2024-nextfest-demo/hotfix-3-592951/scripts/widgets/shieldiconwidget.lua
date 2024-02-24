local Power = require "defs.powers"
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local easing = require("util/easing")

local ShieldIconWidget = Class(Widget, function(self, size)
	Widget._ctor(self, "ShieldIconWidget")

	self.icon_size = size or 17

	self.icon_container = self:AddChild(Widget("Icon Root"))

    self.icon = self.icon_container:AddChild(Image("images/ui_ftf_ingame/ui_shield_icon.tex"))
		:SetSize(self.icon_size, self.icon_size)
end)

function ShieldIconWidget:DoShieldAdd()
	self:SetMultColorAlpha(0)
	self:AlphaTo(1, 0.33)
	-- local x,y = self.icon:GetPosition()
	-- self.icon:Offset(0, -10)
	-- self.icon:MoveTo(x, y, 0.33, easing.inElastic)
end

function ShieldIconWidget:DoShieldBreak(cb)
	-- self:AlphaTo(0, 0.33, nil, function() self:Remove() cb() end)
	self:ScaleTo(1, 0, 0.33, easing.inBack, function() self:Remove() cb() end)
end

return ShieldIconWidget