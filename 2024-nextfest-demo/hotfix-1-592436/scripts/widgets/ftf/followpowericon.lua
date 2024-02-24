local FollowPrompt = require("widgets/ftf/followprompt")
local PowerDescriptionButton = require "widgets.ftf.powerdescriptionbutton"
local Power = require "defs.powers.power"
local PowerIconWidget = require("widgets/powericonwidget")
local SkillIconWidget = require("widgets/skilliconwidget")

local function MakePowerWidget(power)
	local powerwidget
	local def = power:GetDef()
	if def.power_type == Power.Types.SKILL then
		powerwidget = SkillIconWidget()
		powerwidget:SetSkill(power)
	else
		powerwidget = PowerIconWidget()
		powerwidget:SetPower(power)
	end
	return powerwidget
end

local SCALE = 0.7

-- Text that follows a world-space entity around.
local FollowPowerIcon = Class(FollowPrompt, function(self, power)
	FollowPrompt._ctor(self)

	self.scale = SCALE
	self.power = power
	self.offset_x = 0
	self.offset_y = 450
	self.powerwidget = self:AddChild(MakePowerWidget(power))

	self:Offset(self.offset_x, self.offset_y)
	self:SetScale(self.scale)
	self:SetTarget(self.target)
end)

FollowPowerIcon.MakePowerWidget = MakePowerWidget
FollowPowerIcon.SCALE = SCALE

function FollowPowerIcon:Init(data)
	-- data =
	-- 		target: what world object to be placed on
	--		scale: how big should this widget be
	-- 		offset_x: x offset lol
	--		offset_y: y offset lol

	local pow = Power.FindPowerByName(self.power_name)
	local power_instance = ThePlayer.components.powermanager:CreatePower(pow) -- TODO: I wish this damn widget didn't need an instance, and could just take a def. I don't have an access to a powermanager here. yuck.
end

return FollowPowerIcon
