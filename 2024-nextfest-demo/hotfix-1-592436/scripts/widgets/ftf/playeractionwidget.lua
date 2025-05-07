local Image = require "widgets.image"
local Widget = require("widgets/widget")
local easing = require "util.easing"

--- Displays a single player character's action
-- This could be the default potion, or something else
local PlayerActionWidget = Class(Widget, function(self, size)
	Widget._ctor(self, "PlayerActionWidget")

	self.size = size or 100

	-- Make this a button
	self:SetClickable(true)
	self.mouseWasDown = false

	-- Is this loading or ready?
	self.progress = 0

	-- Set colours
	self.colourBgLoading = 		HexToRGB(0x494040FF)
	self.colourBgLoadingHover = HexToRGB(0x494040FF)
	self.colourBgActive = 		UICOLORS.LIGHT_TEXT_DARK
	self.colourBgActiveHover = 	UICOLORS.FOCUS

	self.actionBg = self:AddChild(Image("images/ui_ftf_ingame/action_bg.tex"))
		:SetSize(self.size, self.size)
	self.bg_mask = self:AddChild(Image("images/ui_ftf_ingame/action_fill.tex"))
		:SetHiddenBoundingBox(true)
		:SetSize(self.size, self.size)
		:SetMask()
	self.actionFill = self:AddChild(Image("images/ui_ftf_ingame/action_fill.tex"))
		:SetHiddenBoundingBox(true)
		:SetSize(self.size, self.size)
		:SetMultColor(self.colourBgLoading)
		-- :SetMask()
	self.actionProgress = self:AddChild(Image("images/ui_ftf_ingame/action_fill.tex"))
		:SetHiddenBoundingBox(true)
		:SetSize(self.size, self.size)
		:SetMultColor(HexToRGB(0x806550FF))
	self.actionHighlights = self:AddChild(Image("images/ui_ftf_ingame/action_highlights.tex"))
		:SetHiddenBoundingBox(true)
		:SetSize(self.size, self.size)
	self.actionIcon = self:AddChild(Image())
		:SetHiddenBoundingBox(true)
		:SetSize(self.size, self.size)
		:SetMasked()

	self:SetToolTip("PlayerActionWidget")
end)

function PlayerActionWidget:AnimateIn()
	-- Animate into position
	local x,y = self:GetPosition()
	self:SetPosition(x,y-30)
	self:MoveTo(x,y,0.7,easing.outElastic)
	return self
end

function PlayerActionWidget:AnimateFocusGrab(duration)
	if self.is_animating then
		return
	end
	self.is_animating = true

	self:ScaleTo(1, 1.4, duration * 0.05, easing.inOutQuad, function()
		self:ScaleTo(1.4, 1, duration * 0.2, easing.inBack)
	end)

	local x, y = self:GetPos()
	self:MoveTo(x, y + 55, duration * 0.2, easing.inOutQuad, function()
		self:MoveTo(x, y, duration * 0.8, easing.outElastic, function()
			self.is_animating = nil
		end)
	end)
end

function PlayerActionWidget:AnimateUse()
	if self.is_animating then
		return
	end
	self.is_animating = true

	local duration = 0.9
	local x, y = self:GetPos()
	self:MoveTo(x, y - 25, duration * 0, easing.inOutQuad, function()
		self:MoveTo(x, y, duration * 0.9, easing.outElastic, function()
			self.is_animating = nil
		end)
	end)
end

-- If 1, then the action is available to use
function PlayerActionWidget:SetProgress(progress)
	if progress < 1 then
		local showing_unfilled_bg = 0.835
		progress = Remap(progress, 0, 1, 0, showing_unfilled_bg)
	end
	-- Scissor progress correctly
	local texture_fudge_h = 0.78
	local bar_w, bar_h = self.actionBg:GetSize()
	local amount_h = bar_h * texture_fudge_h
	self.actionProgress
		:SetScissor(-0.5 * bar_w, -0.5 * amount_h, bar_w, progress * amount_h)

	-- Update image color
	self.progress = progress
	self:_RefreshImageState()

	return self
end

function PlayerActionWidget:_RefreshImageState()
	if self.focus or self.hover then
		self.actionFill:SetMultColor(self.progress < 1 and self.colourBgLoadingHover or self.colourBgActiveHover)
	else
		self.actionFill:SetMultColor(self.progress < 1 and self.colourBgLoading or self.colourBgActive)
	end
	self.actionProgress:SetShown(self.progress < 1)
	return self
end

function PlayerActionWidget:OnGainHover()
	self:_RefreshImageState()
end

function PlayerActionWidget:OnLoseHover()
	self:_RefreshImageState()
	self.mouseWasDown = false
end

function PlayerActionWidget:OnGainFocus()
	self:_RefreshImageState()
end

function PlayerActionWidget:OnLoseFocus()
	self:_RefreshImageState()
	self.mouseWasDown = false
end

function PlayerActionWidget:OnControl(controls, down)
	PlayerActionWidget._base.OnControl(self, controls, down)

	if self.progress < 1 then return self end

	if controls:Has(Controls.Digital.ACCEPT) and down and self.mouseWasDown == false then
		self.mouseWasDown = true
	elseif controls:Has(Controls.Digital.ACCEPT) and not down and self.mouseWasDown == true then
		self.mouseWasDown = false
		self:OnClick()
		self:OnRelease()
	end
end

function PlayerActionWidget:OnClick()
	print("Action Click!")
end

function PlayerActionWidget:OnRelease()
	print("Action Release!")
end

function PlayerActionWidget:Test_ShowFill()
	local progress = 0.7
	self.test_fill_task = self.inst:DoPeriodicTask(0.1, function(inst_)
		progress = progress + 0.01
		print("Test_ShowFill", progress)
		self:SetProgress(progress)
		if progress >= 1 then
			print("Full!", self.inst)
			self:SetProgress(1)
			self.test_fill_task:Cancel()
			self.test_fill_task = nil
		end
	end)
end


return PlayerActionWidget
