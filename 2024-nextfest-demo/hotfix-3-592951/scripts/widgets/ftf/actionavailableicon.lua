local Widget = require("widgets/widget")
local Image = require("widgets/image")

local easing = require("util/easing")

--------------------------------------------------------------
-- Just an animated icon to attract the player's attention to something
-- they can do

local ActionAvailableIcon = Class(Widget, function(self)
	Widget._ctor(self, "ActionAvailableIcon")
	self.icon = self:AddChild(Image("images/ui_ftf_research/icon_upgrade_available.tex"))

	-- Animate it
	local speed = 0.24
	local amplitude = 4
	self.icon:RunUpdater(
		Updater.Loop({
			Updater.Ease(function(v) self.icon:SetPos(0, v) end, 0, amplitude, speed, easing.inOutQuad),
			Updater.Ease(function(v) self.icon:SetPos(0, v) end, amplitude, 0, speed, easing.inOutQuad),
			Updater.Ease(function(v) self.icon:SetPos(0, v) end, 0, amplitude, speed, easing.inOutQuad),
			Updater.Ease(function(v) self.icon:SetPos(0, v) end, amplitude, 0, speed, easing.inOutQuad),
			Updater.Wait(speed*5)
		}))
end)

return ActionAvailableIcon
