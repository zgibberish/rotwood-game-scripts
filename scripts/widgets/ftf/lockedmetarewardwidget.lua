local Widget = require("widgets/widget")
local Image = require('widgets/image')
local ItemTooltip = require "widgets/itemtooltip"

local LockedMetaRewardWidget = Class(Widget, function(self, size, owner, item)
	Widget._ctor(self, "LockedMetaRewardWidget")
	self.owner = owner
	self.item = item
	self.def = item:GetDef()

	size = size or 70

	self:AddChild(Image(self.def.icon))
		:SetSize(size, size)

	self:SetToolTipClass(ItemTooltip)
	self:SetToolTip({ item = item, player = owner })
end)

return LockedMetaRewardWidget