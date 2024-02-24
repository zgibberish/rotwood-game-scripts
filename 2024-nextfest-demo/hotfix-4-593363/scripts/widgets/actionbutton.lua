local Button = require "widgets.button"
local Image = require "widgets.image"
local Text = require "widgets.text"
local Panel = require "widgets.panel"
local easing = require "util.easing"
local fmodtable = require "defs.sound.fmodtable"

--- A regular button with text
-- Has a nineslice background and customizable colour
-- Call SetPrimary() for the main button on a screen and SetSecondary() for all the other actions
local ActionButton = Class(Button, function(self)
	Button._ctor(self, "ActionButton")

	-- Space between the text and the side edges of the background
	self.left_padding = 40
	self.right_padding = 40

	-- Setup default scale
	self.scaleNormal = 1
	self.scaleFocus = 1.05

	-- Set default flags
	self.scaleOnFocus = true
	self.moveOnClick = true

	self.saturationDisabled = 0.15

	-- Button background 9slice
	self.background = self:AddChild(Panel("images/ui_ftf/ButtonBackground.tex"))
		:SetNineSliceCoords(30, 20, 520, 120)
		:SetNineSliceBorderScale(1)
		:SetClickable(true)
		:MoveToBack()

	-- Set every button to secondary colour by default
	self:SetSecondary()

	-- Set default size
	self:SetSize(BUTTON_W, BUTTON_H)

	-- Set callbacks
	self:SetOnDown(function() self:_RefreshImageState() end)
	self:SetOnUp(function() self:_RefreshImageState() end)

	return self
end)

function ActionButton:DebugDraw_AddSection(ui, panel)
	ActionButton._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("ActionButton")
	ui:Indent() do
		if ui:Button("Set Primary") then
			self:SetPrimary()
		end
		if ui:Button("Set Secondary") then
			self:SetSecondary()
		end
		if ui:Button("Set Debug") then
			self:SetDebug()
		end
	end
	ui:Unindent()
end

--- The main button on a given screen
function ActionButton:SetPrimary()
	self.texturePath = "images/ui_ftf/ButtonBackground.tex"
	self.texturePathFlipped = "images/ui_ftf/ButtonBackgroundFlipped.tex"
	self.textureCoordMinX = 30
	self.textureCoordMinY = 20
	self.textureCoordMaxX = 520
	self.textureCoordMaxY = 120
	self.background:SetTexture(self.texturePath)
		:SetNineSliceCoords(self.textureCoordMinX, self.textureCoordMinY, self.textureCoordMaxX, self.textureCoordMaxY)
	self.colourNormal = HexToRGB(0xFFFFFFff)
	self.colourFocus = HexToRGB(0xFEC33Aff)
	self.colourDown = HexToRGB(0xbbbbbbff)
	self.colourDisabled = HexToRGB(0x7A7A7Aff)
	self.saturationDisabled = 0.15
	self.colourSelected = HexToRGB(0xFEC33Aff)
	self:SetTextColour(UICOLORS.BACKGROUND_DARK)
	self:_RefreshImageState()
	self:_Layout()
	return self
end

--- The other buttons on a given screen
function ActionButton:SetSecondary()
	self.texturePath = "images/ui_ftf/ButtonSecondaryBackground.tex"
	self.texturePathFlipped = "images/ui_ftf/ButtonSecondaryBackgroundFlipped.tex"
	self.textureCoordMinX = 30
	self.textureCoordMinY = 20
	self.textureCoordMaxX = 520
	self.textureCoordMaxY = 120
	self.background:SetTexture(self.texturePath)
		:SetNineSliceCoords(self.textureCoordMinX, self.textureCoordMinY, self.textureCoordMaxX, self.textureCoordMaxY)
	self.colourNormal = HexToRGB(0xFFFFFFff)
	self.colourFocus = HexToRGB(0x47DAFFff)
	self.colourDown = HexToRGB(0xbbbbbbff)
	self.colourDisabled = HexToRGB(0x7A7A7Aff)
	self.saturationDisabled = 0.15
	self.colourSelected = HexToRGB(0x47DAFFff)
	self:SetTextColour(UICOLORS.BACKGROUND_DARK)
	self:_RefreshImageState()
	self:_Layout()
	return self
end

--- Buttons displaying konjur
function ActionButton:SetKonjur()
	self.texturePath = "images/ui_ftf/ButtonKonjurBackground.tex"
	self.texturePathFlipped = "images/ui_ftf/ButtonKonjurBackgroundFlipped.tex"
	self.textureCoordMinX = 30
	self.textureCoordMinY = 20
	self.textureCoordMaxX = 520
	self.textureCoordMaxY = 120
	self.background:SetTexture(self.texturePath)
		:SetNineSliceCoords(self.textureCoordMinX, self.textureCoordMinY, self.textureCoordMaxX, self.textureCoordMaxY)
	self.colourNormal = HexToRGB(0xFFFFFFff)
	self.colourFocus = HexToRGB(0xB892F1ff)
	self.colourDown = HexToRGB(0xbbbbbbff)
	self.colourDisabled = HexToRGB(0x7A7A7Aff)
	self.saturationDisabled = 0.15
	self.colourSelected = HexToRGB(0xB892F1ff)
	self:SetTextColour(UICOLORS.BACKGROUND_DARK)
	self:_RefreshImageState()
	self:_Layout()
	return self
end

--- Debug buttons on a screen
function ActionButton:SetDebug()
	self.texturePath = "images/ui_ftf/ButtonDebugBackground.tex"
	self.texturePathFlipped = "images/ui_ftf/ButtonDebugBackgroundFlipped.tex"
	self.textureCoordMinX = 30
	self.textureCoordMinY = 20
	self.textureCoordMaxX = 520
	self.textureCoordMaxY = 120
	self.background:SetTexture(self.texturePath)
		:SetNineSliceCoords(self.textureCoordMinX, self.textureCoordMinY, self.textureCoordMaxX, self.textureCoordMaxY)
	self.colourNormal = HexToRGB(0xFFFFFFff)
	self.colourFocus = HexToRGB(0xCE97FFff)
	self.colourDown = HexToRGB(0xbbbbbbff)
	self.colourDisabled = HexToRGB(0x7A7A7Aff)
	self.saturationDisabled = 0.15
	self.colourSelected = HexToRGB(0xCE97FFff)
	self:SetTextColour(UICOLORS.BACKGROUND_DARK)
	self:_RefreshImageState()
	self:_Layout()
	if not DEBUG_MENU_ENABLED then
		-- Create debug buttons but hide to simplify code.
		self:Hide()
	end
	return self
end

--- Debug buttons on a screen, for player-facing, build-included
function ActionButton:SetPublicFacingDebug()
	self.texturePath = "images/ui_ftf/ButtonDebugBackground.tex"
	self.texturePathFlipped = "images/ui_ftf/ButtonDebugBackgroundFlipped.tex"
	self.textureCoordMinX = 30
	self.textureCoordMinY = 20
	self.textureCoordMaxX = 520
	self.textureCoordMaxY = 120
	self.background:SetTexture(self.texturePath)
		:SetNineSliceCoords(self.textureCoordMinX, self.textureCoordMinY, self.textureCoordMaxX, self.textureCoordMaxY)
	self.colourNormal = HexToRGB(0xFFFFFFff)
	self.colourFocus = HexToRGB(0xCE97FFff)
	self.colourDown = HexToRGB(0xbbbbbbff)
	self.colourDisabled = HexToRGB(0x7A7A7Aff)
	self.saturationDisabled = 0.15
	self.colourSelected = HexToRGB(0xCE97FFff)
	self:SetTextColour(UICOLORS.BACKGROUND_DARK)
	self:_RefreshImageState()
	self:_Layout()
	return self
end

--- All white. So it doesn't tint colored textures
function ActionButton:SetUncolored()
	self.colourNormal = UICOLORS.WHITE
	self.colourFocus = UICOLORS.WHITE
	self.colourDown = UICOLORS.WHITE
	self.colourDisabled = UICOLORS.WHITE
	self.colourSelected = UICOLORS.WHITE
	self:SetTextColour(UICOLORS.BACKGROUND_DARK)
	self:_RefreshImageState()
	return self
end

-- Alternates the texture, so contiguous buttons don't look repeated
function ActionButton:SetFlipped(is_flipped)
	if is_flipped == nil then is_flipped = true end
	self.is_flipped = is_flipped
	self.background:SetTexture(self.is_flipped and self.texturePathFlipped or self.texturePath)
	return self
end

function ActionButton:SetDisabledColour(colour)
	self.colourDisabled = colour
	self:_RefreshImageState()
	return self
end

function ActionButton:DisableMips()
	self.background:SetEffect(global_shaders.UI_NOMIP)
end

function ActionButton:SetSize(x, y)
	self.background:SetSize(x, y)
	self:_Layout()
	return self
end

function ActionButton:SetTextAndResizeToFit(text, horizontal_padding, vertical_padding)
	self:SetText(text)
	self:ResizeToFit(horizontal_padding, vertical_padding)
	return self
end

function ActionButton:ResizeToFit(horizontal_padding, vertical_padding)
	local w,h = self.text:GetSize()
	w = w + (horizontal_padding or 35)*2
	h = h + (vertical_padding or 20)*2

	if h < BUTTON_H then
		-- Assume standard button height is good for all text. Makes buttons
		-- look more consistent.
		h = BUTTON_H
	end

	self:SetSize(w,h)
	return self
end

function ActionButton:SetTexture(tex)
	self.texturePath = tex
	self.background:SetTexture(self.texturePath)
	return self
end

function ActionButton:SetNineSliceCoords(minx, miny, maxx, maxy)
	self.textureCoordMinX = minx
	self.textureCoordMinY = miny
	self.textureCoordMaxX = maxx
	self.textureCoordMaxY = maxy
	self.background:SetNineSliceCoords(self.textureCoordMinX, self.textureCoordMinY, self.textureCoordMaxX, self.textureCoordMaxY)
	return self
end

function ActionButton:SetNineSliceBorderScale(scale)
	self.background:SetNineSliceBorderScale(scale)
	return self
end

function ActionButton:_RefreshImageState()
	if self:IsSelected() then
		self.background:SetMultColor(self.colourSelected)
		self.background:SetSaturation(1)
	elseif self:IsEnabled() then
		if self.down then
			self.background:SetMultColor(self.colourDown)
		elseif self.focus then
			self.background:SetMultColor(self.colourFocus)
		else
			self.background:SetMultColor(self.colourNormal)
		end
		self.background:SetSaturation(1)
	else
		self:SetScale(self.scaleNormal)
		self.background:SetMultColor(self.colourDisabled)
		self.background:SetSaturation(self.saturationDisabled)
	end

	-- Make the icon tint match the text
	if self.icon then
		self.icon:SetMultColor(self.iconColour or self.text:GetColour())
	end

	return self
end

function ActionButton:SetOnGainFocusFn(fn)
	self.onGainFocus_fn = fn
	return self
end

function ActionButton:SetOnLoseFocusFn(fn)
	self.onLoseFocus_fn = fn
	return self
end

function ActionButton:OnGainFocus()
	ActionButton._base.OnGainFocus(self)

	if self:IsEnabled() then
		self.background:TintTo(nil, self.colourFocus, 0.1, easing.inOutQuad)
	else
		-- Disabled
		self.background:SetMultColor(self.colourDisabled)
	end

	if self.scaleOnFocus then
		self:ScaleTo(nil, self.scaleFocus, 0.1, easing.inOutQuad)
	end

	if self.onGainFocus_fn then
		self.onGainFocus_fn(self)
	end
end

function ActionButton:OnLoseFocus()
	ActionButton._base.OnLoseFocus(self)

	if self:IsEnabled() then
		self.background:TintTo(nil, self.colourNormal, 0.1, easing.inOutQuad)
	else
		-- Disabled
		self:SetScale(self.scaleNormal)
		self.background:SetMultColor(self.colourDisabled)
	end

	if self.scaleOnFocus then
		self:ScaleTo(nil, self.scaleNormal, 0.2, easing.inOutQuad)
	end

	if self.onLoseFocus_fn then
		self.onLoseFocus_fn(self)
	end
end

function ActionButton:SetRightText(text)
	if not self.right_text then
		self.right_text = self:AddChild(Text(self.font, FONTSIZE.BUTTON))
			:SetGlyphColor(self.textcolour)
	end
	self.right_text:SetText(text)
	self:_Layout()
	return self
end

function ActionButton:SetTextSize(sz)
	ActionButton._base.SetTextSize(self, sz)
	if self.right_text then self.right_text:SetFontSize(self.size) end
	return self
end

function ActionButton:_Layout()
	if self.right_text then
		self.text:SetHAlign(ANCHOR_LEFT)
			:LayoutBounds("left", "center", self.background)
			:Offset(self.left_padding, 0)
		self.right_text:SetHAlign(ANCHOR_RIGHT)
			:LayoutBounds("right", "center", self.background)
			:Offset(-self.right_padding, 0)
	else
		self.text:LayoutBounds("center", "center", self.background)
			:Offset(0, 0)
	end
end

function ActionButton:_UpdateTextColour(r,g,b,a)
	ActionButton._base._UpdateTextColour(self,r,g,b,a)
	if self.right_text then
		self.right_text:SetGlyphColor(r,g,b,a)
	end
	return self
end

function ActionButton:RefreshText()
	self.text:RefreshText()
	self:_Layout()
	return self
end

function ActionButton:OnEnable()
	ActionButton._base.OnEnable(self)
	self:_RefreshImageState()
end

function ActionButton:OnDisable()
	ActionButton._base.OnDisable(self)
	self:_RefreshImageState()
end

function ActionButton:SetScaleOnFocus(scale)
	self.scaleOnFocus = scale
	return self
end

function ActionButton:SetFocusScale(scale)
	self.scaleFocus = scale or 1.2

	if self.focus and self.scaleOnFocus and not self.selected then
		self:ScaleTo(nil, self.scaleFocus, 0.1, easing.inOutQuad)
	end
	return self
end

function ActionButton:SetNormalScale(scale)
	self.scaleNormal = scale or 1

	if not self.focus and self.scaleOnFocus then
		self:ScaleTo(nil, self.scaleNormal, 0.2, easing.inOutQuad)
	end
	return self
end

function ActionButton:SetImageNormalColour(r,g,b,a)
	if type(r) == "number" then
		self.colourNormal = {r, g, b, a}
	else
		self.colourNormal = r
	end

	if self:IsEnabled() and not self.focus and not self.selected then
		self.background:SetMultColor(self.colourNormal)
	end
	return self
end

function ActionButton:SetImageFocusColour(r,g,b,a)
	if type(r) == "number" then
		self.colourFocus = {r,g,b,a}
	else
		self.colourFocus = r
	end

	if self.focus and not self.selected then
		self.background:SetMultColor(self.colourFocus)
	end
	return self
end

function ActionButton:SetImageDisabledColour(r,g,b,a)
	if type(r) == "number" then
		self.colourDisabled = {r,g,b,a}
	else
		self.colourDisabled = r
	end

	if not self:IsEnabled() then
		self.background:SetMultColor(self.colourFocus)
	end
	return self
end

function ActionButton:SetImageSelectedColour(r,g,b,a)
	if type(r) == "number" then
		self.colourSelected = {r,g,b,a}
	else
		self.colourSelected = r
	end

	if self.selected then
		self.background:SetMultColor(self.colourFocus)
	end
	return self
end

return ActionButton
