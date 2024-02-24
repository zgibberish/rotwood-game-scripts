local Button = require "widgets.button"
local Image = require "widgets.image"
local fmodtable = require "defs.sound.fmodtable"

local ImageCheckBox = Class(Button, function(self, max_width, text)
    Button._ctor(self, "ImageCheckBox")

	self.max_width = 300
	self.image_size = 34
	self.spacing = 6

	self.texture_normal = "images/ui_ftf/CheckBox.tex"
	self.texture_checked = "images/ui_ftf/CheckBoxChecked.tex"

	self.toggle_image = self:AddChild(Image(self.texture_normal))
		:SetSize(self.image_size, self.image_size)

	-- Align text from Button.
	self.text:SetWordWrap(true)
		:SetAutoSize(self.max_width - self.image_size - self.spacing)
		:LeftAlign()
	self:SetTextColour(HexToRGB(0xFFCB27ff))
	self:SetTextFocusColour(UICOLORS.LIGHT_TEXT_SELECTED)

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
	self:Layout()

	self:SetControlDownSound(nil)
	self:SetControlUpSound(nil)

	self.toggleon_sound =  fmodtable.Event.ui_toggle_on
	self.toggleoff_sound = fmodtable.Event.ui_toggle_off
end)

function ImageCheckBox:SetImage(normal, checked)
	self.texture_normal = normal
	self.texture_checked = checked
	return self
end

function ImageCheckBox:SetImageSize(size)
	self.image_size = size or 40
	self.toggle_image:SetSize(self.image_size, self.image_size)
	self.text:SetAutoSize(self.max_width - self.image_size - self.spacing)
	self:Layout()
	return self
end

function ImageCheckBox:SetMaxWidth(max_width)
	self.max_width = max_width or 300
	self.text:SetAutoSize(self.max_width - self.image_size - self.spacing)
	self:Layout()
	return self
end

function ImageCheckBox:SetOnChangedFn(fn)
	self.onchangedfn = fn
	return self
end

function ImageCheckBox:SetTextSize(...)
	ImageCheckBox._base.SetTextSize(self, ...)
	self:Layout()
	return self
end

function ImageCheckBox:_UpdateTextColour(r,g,b,a)
	ImageCheckBox._base._UpdateTextColour(self,r,g,b,a)
	if self.toggle_image then
		self.toggle_image:SetMultColor(r,g,b,a)
	end
	return self
end

-- Formerly GetValue
function ImageCheckBox:IsChecked()
	return self.state
end

function ImageCheckBox:SetValue(state, silent)
	self.state = state
	self.toggle_image:SetTexture(self.state and self.texture_checked or self.texture_normal)
	self:Layout()

	if not silent and self.onchangedfn then
		self.onchangedfn(state)
	end

	return self
end

function ImageCheckBox:SetText(text, dropShadow, dropShadowOffset)
	ImageCheckBox._base.SetText(self, text, dropShadow, dropShadowOffset)
	self:Layout()
	return self
end

function ImageCheckBox:Layout()
	self.text:LayoutBounds("after", "center", self.toggle_image)
		:Offset(self.spacing, 0)
	return self
end

function ImageCheckBox:Toggle()
	return self:SetValue(not self.state)
end

return ImageCheckBox
