local Widget = require "widgets.widget"
local PopPrompt = require("widgets/ftf/popprompt")
local PowerDisplayWidget = require("widgets/ftf/powerdisplaywidget")
local Power = require "defs.powers.power"
local itemforge = require"defs.itemforge"

local PopText = Class(PopPrompt, function(self, target, button)
	Widget._ctor(self, "PopText")
end)

function PopText:Init(data)
	local width = data.width or 10000
	local owner = data.owner or data.target
	local icon_override = data.icon_override or nil
	local stacks = data.stacks or nil
	local scale = data.scale or 1

	local power

	if data.power_instance then
		power = data.power_instance.persistdata
	else
		local def = Power.FindPowerByName(data.power)
		power = itemforge.CreatePower(def, nil, stacks)
	end

	self:AddChild(PowerDisplayWidget(width, owner, power, nil, nil, icon_override))
	self:SetScale(scale)
	self:Start(data)
end

return PopText
