local Button = require "widgets/button"
local Image = require "widgets/image"

-- Clickable text. You should probably use ImageButton or just Button instead.
local TextButton = Class(Button, function(self, name)
	Button._ctor(self, name or "TEXTBUTTON")

    self.image = self:AddChild(Image("images/global/transparent.tex"))
    self:SetFont(FONTFACE.DEFAULT)
    self:SetTextSize(30)

    self:SetTextColour({0.9,0.8,0.6,1})
    self:SetTextFocusColour({1,1,1,1})
end)

function TextButton:GetSize()
    return self.image:GetSize()
end

function TextButton:SetText(msg)
    TextButton._base.SetText(self, msg)

    -- This is the only reason to use TextButton: it automatically sizes a
    -- clickable transparent image to the size of your text.
	self.image:SetSize(self.text:GetRegionSize())
    return self
end

function TextButton:OverrideLineHeight(height)
    TextButton._base.OverrideLineHeight(self, height)
    return self
end

return TextButton
