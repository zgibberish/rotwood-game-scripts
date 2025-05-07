local Button = require "widgets.button"
local Image = require "widgets.image"
local Panel = require "widgets.panel"
local easing = require "util.easing"
local kassert = require "util.kassert"
local fmodtable = require "defs.sound.fmodtable"

local CheckBox = Class(Button, function(self, color_palette)
    Button._ctor(self, "CheckBox")

	self.palette = color_palette or {
		primary_active = UICOLORS.BACKGROUND_DARK,
		primary_inactive = UICOLORS.LIGHT_TEXT_DARKER,
	}

	if not self.palette.bg_focus then
		-- Palette was only partially defined. Fill the rest out.
		self.palette.bg_focus = self.palette.primary_active
		self.palette.bg_unselected = deepcopy(self.palette.primary_inactive)
		self.palette.bg_unselected.a = 0.25
		self.palette.handle_enabled = self.palette.primary_inactive
		self.palette.handle_disabled = deepcopy(self.palette.primary_inactive)
		self.palette.handle_disabled.a = 0.30
	end
	-- We modify this color, so ensure we don't touch the original.
	self.palette.handle_disabled = deepcopy(self.palette.handle_disabled)

	-- Text is next to (not on top of) bg, so use match colours.
	self.textcolour = self.palette.primary_inactive
	self.textfocuscolour = self.palette.bg_focus
	self.textdisabledcolour = self.palette.bg_unselected
	self.textselectedcolour = self.palette.bg_focus

	self.toggle_bg = self:AddChild(Panel("images/ui_ftf_options/toggle_bg.tex"))
		:SetNineSliceCoords(5, 8, 95, 92)
		:SetNineSliceBorderScale(0.5)
	self.toggle_handle = self:AddChild(Image("images/ui_ftf_options/toggle_button.tex"))

	-- Align text from Button.
	self.text:SetWordWrap(true)
		:SetAutoSize(200 * HACK_FOR_4K)
		:LeftAlign()

	self:SetOnClick(function()
		self:Toggle()
		if self.state then
			TheFrontEnd:GetSound():PlaySound(self.toggleon_sound)
		else
			TheFrontEnd:GetSound():PlaySound(self.toggleoff_sound)
		end
	end)

	-- Default values
	self.state = false
	self:SetSize(90 * HACK_FOR_4K, 50 * HACK_FOR_4K)
	self:SetIsSlider(false)
	self:OnFocusChange(false) -- set initial appearance
	self:Layout()

	self:SetControlDownSound(nil)
	self:SetControlUpSound(nil)

	self.toggleon_sound =  fmodtable.Event.ui_toggle_on
	self.toggleoff_sound = fmodtable.Event.ui_toggle_off
end)

-- Slider moves a handle instead of filling in the square.
-- SetIsSlider(true) for a slider switch.
-- SetIsSlider(false) for a checkbox.
function CheckBox:SetIsSlider(should_slide)
	kassert.typeof("boolean", should_slide)
	self.is_slider = should_slide
	if self.is_slider then
		if self.w <= self.h then
			self.w = self.h * 2
		end
		self.palette.handle_disabled.a = 0.30
	else
		self.w = self.h
		self.palette.handle_disabled.a = 0.1
	end
	self:SetSize(self.w, self.h)
	return self
end


function CheckBox:SetSize(w, h)
	self.w, self.h = w, h
	self.toggle_bg:SetSize(w, h)
	if self.is_slider then
		self.toggle_handle:SetSize(h, h)
	else
		self.toggle_handle:SetSize(w, h)
	end
	return self
end


function CheckBox:SetTextWidth(w)
	self.text:SetAutoSize(w)
	return self
end

function CheckBox:SetOnChangedFn(fn)
	self.onchangedfn = fn
	return self
end

-- Formerly GetValue
function CheckBox:IsChecked()
	return self.state
end

function CheckBox:SetValue(state, silent)
	self.state = state
	self:OnFocusChange(self.focus)
	self:Layout()

	if not silent and self.onchangedfn then
		self.onchangedfn(state)
	end

	return self
end

function CheckBox:SetText(text, dropShadow, dropShadowOffset)
	CheckBox._base.SetText(self, text, dropShadow, dropShadowOffset)
	self.text
		:LayoutBounds("after", "center", self.toggle_bg)
		:Offset(10 * HACK_FOR_4K, 0)
	return self
end

function CheckBox:OnGainHover()
    CheckBox._base.OnGainHover(self)
	self:OnFocusChange(self.focus)
end

function CheckBox:OnLoseHover()
    CheckBox._base.OnLoseHover(self)
	self:OnFocusChange(self.focus)
end

function CheckBox:OnGainFocus()
    CheckBox._base.OnGainFocus(self)
	self:OnFocusChange(self.focus)
end

function CheckBox:OnLoseFocus()
    CheckBox._base.OnLoseFocus(self)
	self:OnFocusChange(self.focus)
end

function CheckBox:Enable()
    CheckBox._base.Enable(self)
    self:OnFocusChange(self.focus)
    return self
end

function CheckBox:Disable()
    CheckBox._base.Disable(self)
    self:OnFocusChange(self.focus)
    return self
end


function CheckBox:Layout()
	local side = "center"
	if self.is_slider then
		side = self.state and "right" or "left"
	end
	self.toggle_handle:LayoutBounds(side, "center", self.toggle_bg)
	return self
end

function CheckBox:_GetHandleColor()
	if self.state then
		return self.palette.handle_enabled
	end
	return self.palette.handle_disabled
end

function CheckBox:OnFocusChange(hasFocus)
	local handle_color = self:_GetHandleColor()
	if hasFocus then
		self.toggle_bg:TintTo(nil, self.palette.bg_focus, 0.2, easing.inOutQuad)
		self.toggle_handle:TintTo(nil, handle_color, 0.2, easing.inOutQuad)
	else
		self.toggle_bg:TintTo(nil, self.palette.bg_unselected, 0.4, easing.inOutQuad)
		self.toggle_handle:TintTo(nil, handle_color, 0.4, easing.inOutQuad)
	end
	return self
end

function CheckBox:Toggle()
	return self:SetValue(not self.state)
end

return CheckBox
