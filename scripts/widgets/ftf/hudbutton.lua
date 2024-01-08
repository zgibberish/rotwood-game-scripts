local Image = require "widgets.image"
local ImageButton = require "widgets.imagebutton"
local easing = require "util.easing"


------------------------------------------------------------------------------------------
--- A generic hud button for the town
local HudButton = Class(ImageButton, function(self, size, icon, colour, fn)
	ImageButton._ctor(self, "images/global/transparent.tex")

	self.size = size or 150
	self:SetSize(self.size, self.size)
		:SetOnClickFn(fn)

	-- Calculate colours for input interactions
	colour = colour or UICOLORS.WHITE
	self.tint_r, self.tint_g, self.tint_b, self.tint_a = colour[1], colour[2], colour[3], colour[4]
	self.colourNormal = {self.tint_r, self.tint_g, self.tint_b, self.tint_a}
	self.colourFocus = {self.tint_r * 1.2, self.tint_g * 1.2, self.tint_b * 1.2, self.tint_a}
	self.colourDown = {self.tint_r * 0.8, self.tint_g * 0.8, self.tint_b * 0.8, self.tint_a}
	self.colourDisabled = UICOLORS.ITEM_DARK

	self.buttonBg = self:AddChild(Image("images/ui_ftf_shop/hud_button_bg.tex"))
		:SetHiddenBoundingBox(true)
		:SetSize(self.size, self.size)
		:SetMultColor(self.colourNormal)

	self.buttonMask = self:AddChild(Image("images/ui_ftf_shop/hud_button_mask.tex"))
		:SetHiddenBoundingBox(true)
		:SetSize(self.size, self.size)
		:SetMask()

	self.buttonIcon = self:AddChild(Image(icon))
		:SetHiddenBoundingBox(true)
		:SetSize(self.size, self.size)
		:SetMasked()

	-- Set callbacks
	self:SetOnDown(function() self:OnDown() end)
	self:SetOnUp(function() self:OnUp() end)

end)

function HudButton:OnDown()
	if not self.buttonBg then return self end

	self.buttonBg:ScaleTo(nil, 1.05, 0.1, easing.inOutQuad)
		:SetMultColor(self.colourDown)
	self.buttonMask:ScaleTo(nil, 1.05, 0.1, easing.inOutQuad)
end

function HudButton:OnUp()
	if not self.buttonBg then return self end

	self.buttonBg:ScaleTo(nil, 1, 0.1, easing.inOutQuad)
		:SetMultColor(self.colourNormal)
	self.buttonMask:ScaleTo(nil, 1, 0.1, easing.inOutQuad)
end

function HudButton:OnGainFocus()
	if not self.buttonBg then return self end

	self.buttonBg:ScaleTo(nil, 1.05, 0.1, easing.inQuad)
		:SetMultColor(self.colourFocus)
	self.buttonMask:ScaleTo(nil, 1.05, 0.1, easing.inQuad)
	self.buttonIcon:MoveTo(0, 6, 0.1, easing.inQuad)
		:ScaleTo(nil, 1.15, 0.1, easing.inQuad)
end

function HudButton:OnLoseFocus()
	if not self.buttonBg then return self end

	self.buttonBg:ScaleTo(nil, 1, 0.1, easing.outQuad)
		:SetMultColor(self.colourNormal)
	self.buttonMask:ScaleTo(nil, 1, 0.1, easing.outQuad)
	self.buttonIcon:MoveTo(0, 0, 0.2, easing.outQuad)
		:ScaleTo(nil, 1, 0.1, easing.outQuad)
end

return HudButton
