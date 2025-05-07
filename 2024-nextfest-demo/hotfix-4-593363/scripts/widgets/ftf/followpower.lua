local FollowPrompt = require("widgets/ftf/followprompt")
local PowerDescriptionButton = require "widgets.ftf.powerdescriptionbutton"
local Power = require "defs.powers.power"
local ItemForge = require "defs.itemforge"

local SCALE = 0.8

-- Text that follows a world-space entity around.
local FollowPower = Class(FollowPrompt, function(self, power)
	FollowPrompt._ctor(self)

	self.scale = SCALE
	self.offset_x = 0
	self.offset_y = 500

	self.powerwidget = self:AddChild(PowerDescriptionButton())

	self:SetScale(self.scale)

	-- self.textLabel = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE, ""))
	-- 	:SetName("Text label")
	-- 	:SetGlyphColor(UICOLORS.WHITE)

	-- local icon_size = 120
	-- self.icon = self:AddChild(Image("images/ui_ftf_hud/revive_icon.tex"))
	-- 	:SetName("Icon")
	-- 	:SetSize(icon_size, icon_size)
	-- self.radial = self:AddChild(RadialProgress("images/ui_ftf_hud/revive_icon_radial.tex"))
	-- 	:SetName("Radial")
	-- 	:SetSize(icon_size, icon_size)
end)

FollowPower.SCALE = SCALE

function FollowPower:GetText()
	return self.textLabel:GetText()
end

function FollowPower:SetText(text)
	self.textLabel:SetText(text)
	self.icon:LayoutBounds("center", "above", self.textLabel)
		:Offset(0, 10)
	self.radial:LayoutBounds("center", "center", self.icon)
	return self
end

function FollowPower:SetProgress(zeroToOne)
	self.radial:SetProgress(zeroToOne)
	return self
end

function FollowPower:GetLabelWidget()
	return self.textLabel
end

function FollowPower:Init(data)
	-- data =
	-- 		target: what world object to be placed on
	--		scale: how big should this widget be
	-- 		offset_x: x offset lol
	--		offset_y: y offset lol

	if data.offset_x then self.offset_x = data.offset_x end
	if data.offset_y then self.offset_y = data.offset_y end
	if data.scale then self.scale = data.scale end

	self.power_name = data.power_name
	self.target = data.target

	local pow = Power.FindPowerByName(self.power_name)
	local power_instance = ItemForge.CreatePower(pow) 

	self.powerwidget:SetPower(power_instance, false, true)
	-- self.powerwidget:SetPowerToolTip(1, num_buttons)
	self.powerwidget:SetUnclickable()

	self:Offset(self.offset_x, self.offset_y)
	self:SetScale(self.scale)
	self:SetTarget(self.target)

end

return FollowPower
