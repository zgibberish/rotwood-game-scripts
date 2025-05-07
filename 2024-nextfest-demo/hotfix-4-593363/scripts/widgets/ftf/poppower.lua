local Widget = require "widgets.widget"
local PopPrompt = require("widgets/ftf/popprompt")
local PowerDescriptionButton = require "widgets.ftf.powerdescriptionbutton"
local Power = require "defs.powers.power"

local PopText = Class(PopPrompt, function(self, target, button)
	Widget._ctor(self, "PopText")

	self.powerwidget = self:AddChild(PowerDescriptionButton())
end)

function PopText:Init(data)
	local power_instance

	if data.power_instance then
		power_instance = data.power_instance.persistdata
	else
		local pow = Power.FindPowerByName(data.power)
		power_instance = data.target.components.powermanager:CreatePower(pow) --TODO: maybe target doesn't have a powermanager, but we -need- one here to configure PowerDescriptionButton
	end


	self.powerwidget:SetPower(power_instance, false, true)
	self:SetScale(data.scale)

	self:Start(data)
end

return PopText
