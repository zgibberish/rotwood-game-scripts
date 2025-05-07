local Widget = require("widgets/widget")
local Image = require('widgets/image')
local ItemTooltip = require "widgets/itemtooltip"
local Text = require('widgets/text')

local LockedMetaRewardWidget = Class(Widget, function(self, size, owner, item, count)
	Widget._ctor(self, "LockedMetaRewardWidget")
	self.owner = owner
	self.item = item
	self.def = item:GetDef()

	size = size or 70

	local icon = self:AddChild(Image(self.def.icon))
		:SetSize(size, size)

	if count then
		icon:AddChild(Text(FONTFACE.DEFAULT, 60, count, UICOLORS.LIGHT_TEXT_DARK))
			:LayoutBounds("right", "top", icon)
			:Offset(-25, -20)
	end


	self:SetToolTipClass(ItemTooltip)
	self:SetToolTip({ item = item, player = owner })
end)

return LockedMetaRewardWidget