local Widget = require "widgets.widget"
local Text = require "widgets.text"
local easing = require "util.easing"

local CookingButton = Class(Widget, function(self, target, button)
	Widget._ctor(self, "CookingButton")

	self.text_root = self:AddChild(Widget())

	self.number = self.text_root:AddChild(Text(FONTFACE.BUTTON, 75, "", UICOLORS.RED))
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()


	self.start_x, self.start_y = nil, nil

	self.time_updating = 0

	self.y_offset_base = 0

	self.y_offset_target = 50
	self.y_offset_target_time = 0.5

	self.x_offset_target = 25
	self.x_offset_target_time = 0.5

	self.x_offset_mod = 1

	self.fade_time = 0.66

	self.s_x = nil
	self.s_y = nil
	self.s_z = nil

	self:SetClickable(false)

	-- self:Init(target, button)
end)

function CookingButton:Init(data)
	local button_text = string.format("%s", data.button)
	self.y_offset_base = data.y_offset and data.y_offset or 0

	if data.fade_time and data.fade_time > 0 then
		self.fade_time = data.fade_time
	end
	if data.x_offset_mod then
		self.x_offset_mod = data.x_offset_mod
	end
	if data.text_color then
		self.number:SetGlyphColor(data.text_color)
	end
	if data.text_outline_color then
		self.number:SetOutlineColor(data.text_outline_color)
	end

	self.s_x, self.s_y, self.s_z = data.target.AnimState:GetSymbolPosition("head", 0, 0, 0)
	local x,y = self:CalcLocalPositionFromWorldPoint(self.s_x, self.s_y, self.s_z)
	y = y + self.y_offset_base
	self:SetPosition(x, y)

	self:AlphaTo(0, self.fade_time, easing.inExpo, function() self:Remove() end)

	self.number:SetText(button_text)

	self:StartUpdating()
end

function CookingButton:OnUpdate(dt)
	self.time_updating = self.time_updating + dt
	local y_offset = easing.outElastic(self.time_updating, 0, self.y_offset_target, self.y_offset_target_time, 50, 0.1)

	local x_offset = easing.outExpo(self.time_updating, 0, self.x_offset_target * self.x_offset_mod, self.x_offset_target_time)

	local x,y = self:CalcLocalPositionFromWorldPoint(self.s_x, self.s_y, self.s_z)
	y = y + self.y_offset_base
	self:SetPosition(x + x_offset, y + y_offset)
end

return CookingButton
