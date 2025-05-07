local Screen = require("widgets/screen")

local PowerDetailsButton = require('widgets/ftf/powerdetailsbutton')
local ItemDetailsButton = require('widgets/ftf/itemdetailsbutton')
local templates = require "widgets.ftf.templates"

------------------------------------------------------------------------------------------
local UnlockableRewardDetailsScreen = Class(Screen, function(self, owner, cb_fn)
	Screen._ctor(self, "UnlockableRewardDetailsScreen")

	self.owner = owner
	self.cb_fn = cb_fn

    self.black = self:AddChild(templates.BackgroundTint())
		:SetMultColor(0,0,0,0.5)
end)

function UnlockableRewardDetailsScreen:ShowPowerDetails(power)
	local button
	button = self:AddChild(PowerDetailsButton(self.owner, power))
		:SetOnClick(function()
			button:AnimateOut(self.cb_fn)
		end)
		:LayoutBounds("center", "center", self.black)

	button:AnimateIn()
	button:SetFocus()
	self.default_focus = button
end

function UnlockableRewardDetailsScreen:ShowItemDetails(item)
	local button
	button = self:AddChild(ItemDetailsButton(self.owner, item))
		:SetOnClick(function()
			button:AnimateOut(self.cb_fn)
		end)
		:LayoutBounds("center", "center", self.black)

	button:AnimateIn()
	button:SetFocus()
	self.default_focus = button
end

return UnlockableRewardDetailsScreen
