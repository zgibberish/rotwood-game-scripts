local Widget = require "widgets.widget"
local Text = require "widgets.text"
local easing = require "util.easing"

local PopPrompt = Class(Widget, function(self, target, button)
	Widget._ctor(self, "PopPrompt")

	self.prompt_root = self:AddChild(Widget())
end)

function PopPrompt:Start(data)
	-- data
	--		x_offset
	-- 		y_offset
	--		x_offset_mod
	-- 		fade_time
	-- 		target

	self.start_x, self.start_y = nil, nil

	self.time_updating = 0

	self.y_offset_target = 50
	self.y_offset_target_time = 0.5

	self.x_offset_target = 25
	self.x_offset_target_time = 0.5

	self.x_offset_mod = 1

	self.fade_time = 0.66

	self.start_x = nil
	self.start_y = nil
	self.start_z = nil

	self:SetClickable(false)

	self.x_offset_base = data.x_offset and data.x_offset or 0
	self.y_offset_base = data.y_offset and data.y_offset or 0

	if data.fade_time and data.fade_time > 0 then
		self.fade_time = data.fade_time
	end
	if data.x_offset_mod then
		self.x_offset_mod = data.x_offset_mod
	end

	self.start_x, self.start_y, self.start_z = 0, 0, 0
	if data.target then
		if data.target.AnimState ~= nil then
			self.start_x, self.start_y, self.start_z = data.target.AnimState:GetSymbolPosition("head", 0, 0, 0)
		elseif data.target.Transform then
			self.start_x, self.start_y, self.start_z = data.target.Transform:GetWorldPosition()
		end
	end
	local x,y = self:CalcLocalPositionFromWorldPoint(self.start_x, self.start_y, self.start_z)
	x = x + self.x_offset_base
	y = y + self.y_offset_base
	self:SetPosition(x, y)

	self:AlphaTo(0, self.fade_time, easing.inExpo, function() self:Remove() end)

	self:RunUpdater(Updater.Parallel{
			Updater.Ease(function(x3) 
				local x2, y2 = self:GetPosition()
				self:SetPosition(x3, y2) 
			end, x, x + (self.x_offset_target * self.x_offset_mod), self.x_offset_target_time, easing.outExpo),
			Updater.Ease(function(y3) 
				local x2, y2 = self:GetPosition()
				self:SetPosition(x2, y3) 
			end, y, y + self.y_offset_target, self.y_offset_target_time, easing.outElastic),
	})
end

function PopPrompt:Extend(data)
	if data.fade_time and data.fade_time > 0 then
		self.fade_time = data.fade_time
	end

	self:SetMultColorAlpha(1)
	self:AlphaTo(0, self.fade_time, easing.inExpo, function() self:Remove() end)

	self:RunUpdater(Updater.Ease(function(v) self:SetScale(v) end, 0.9, 1, 0.33, easing.outElastic))
end

return PopPrompt