local Button = require "widgets.button"
local ActionButton = require "widgets.actionbutton"
local Image = require "widgets.image"
local Text = require "widgets.text"
local Panel = require "widgets.panel"

local fmodtable = require "defs.sound.fmodtable"

local easing = require "util.easing"

local WIDTH = BUTTON_W * 1.9
local HEIGHT = BUTTON_H
local FONT_SIZE = FONTSIZE.SPEECH_TEXT

local SpeechButton = Class(ActionButton, function(self, text, right_text)
	ActionButton._ctor(self, "ActionButton")

	self.righttextcolour = UICOLORS.LIGHT_TEXT
	self.righttextfocuscolour = UICOLORS.BLACK

	self:SetUncolored()
		:SetTexture("images/ui_ftf_dialog/speech_button.tex")
		:SetNineSliceCoords(40, 30, 250, 50)
		:SetSize(WIDTH, HEIGHT)
		:SetTextSize(FONT_SIZE)
		:SetFocusScale(1)
		:SetText(text)
		:SetRightText(right_text or " ") -- For convo-option type icon
		:SetTextColour(UICOLORS.SPEECH_BUTTON_TEXT)
		-- sound
		:SetControlDownSound(nil)
		:SetControlUpSound(nil)
		:SetHoverSound(nil)
		:SetGainFocusSound(fmodtable.Event.hover_speechBubble)

	return self
end)

function SpeechButton:_UpdateTextColour(r,g,b,a)
	SpeechButton._base._UpdateTextColour(self,r,g,b,a)
	if self.right_text then
		self.right_text:SetGlyphColor(self.focus and self.righttextfocuscolour or self.righttextcolour)
	end
	return self
end

function SpeechButton:_Layout()
	local y_padding = 30
	local texture_y_offset = 6

	self.text:SetHAlign(ANCHOR_LEFT)
		:SetAutoSize(WIDTH - 200)
	if self.right_text then
		self.right_text:SetHAlign(ANCHOR_RIGHT)
			:SetAutoSize(150)
	end

	local text_w, text_h = self.text:GetSize()
	self.background:SetSize(WIDTH, text_h + y_padding*2)

	self.text:LayoutBounds("left", "center", self.background)
		:Offset(self.left_padding, texture_y_offset)
	if self.right_text then
		self.right_text:LayoutBounds("right", "center", self.background)
			:Offset(-self.right_padding, texture_y_offset)
	end
end

SpeechButton.WIDTH = WIDTH
SpeechButton.HEIGHT = HEIGHT
SpeechButton.FONT_SIZE = FONT_SIZE

return SpeechButton
