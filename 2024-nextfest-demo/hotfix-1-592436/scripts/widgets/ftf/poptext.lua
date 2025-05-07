local Widget = require "widgets.widget"
local Text = require "widgets.text"
local easing = require "util.easing"
local PopPrompt = require("widgets/ftf/popprompt")

local PopText = Class(PopPrompt, function(self, target, button)
	Widget._ctor(self, "PopText")

	self.text_root = self:AddChild(Widget())

	self.number = self.text_root:AddChild(Text(FONTFACE.BUTTON, 75, "", UICOLORS.RED))
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()
end)

function PopText:Init(data)
	local label = string.format("%s", data.button)

	if data.color then
		self.number:SetGlyphColor(data.color)
	end
	if data.outline_color then
		self.number:SetOutlineColor(data.outline_color)
	end
	if data.size then
		self.number:SetFontSize(data.size)
	end

	self.number:SetText(label)
	self:Start(data)
end

return PopText
