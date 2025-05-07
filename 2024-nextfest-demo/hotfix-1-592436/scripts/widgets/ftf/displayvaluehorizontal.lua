local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")
local EquipmentStatDisplay = require "defs.equipmentstatdisplay"

local lume = require"util.lume"
-------------------------------------------------------------------------------------------------
--- A widget with a number value, and a label beside it
local DisplayValueHorizontal = Class(Widget, function(self)
	Widget._ctor(self, "DisplayValueHorizontal")

	local text_size = 40
	local delta_size = 30

	self.valueContainer = self:AddChild(Widget())
	self.value = self.valueContainer:AddChild(Text(FONTFACE.DEFAULT, text_size, "", UICOLORS.LIGHT_TEXT))
	self.delta = self.valueContainer:AddChild(Text(FONTFACE.DEFAULT, delta_size, "", UICOLORS.LIGHT_TEXT))
		:Hide()
	self.label = self:AddChild(Text(FONTFACE.DEFAULT, text_size, "", UICOLORS.LIGHT_TEXT))
		:LeftAlign()
		--:LayoutBounds("left_center", "center", self.valueContainer)
		--:Offset(0, 0)

	self.is_smaller_better = false
	self.show_tooltip = false
end)

function DisplayValueHorizontal:SetValue(value, label, delta, deltaColour, percent)
	-- Add an arrow up or down to the delta
	if delta and delta ~= 0 then
		local delta_arrow
		if delta > 0 then
			delta_arrow = "<p img='images/ui_ftf_shop/displayvalue_up.tex' color='BONUS'>"
		elseif delta < 0 then
			value = value
			delta = math.abs(delta)
			delta_arrow = "<p img='images/ui_ftf_shop/displayvalue_down.tex' color='PENALTY'>"
		end

		if percent then
			delta = delta * 100
			delta = lume.round(delta, 0.1)

			if lume.round(delta) == delta then
				delta = lume.round(delta)
			end

			delta = delta.."%"
		end

		self.delta:SetText(delta .. delta_arrow)
		self.delta:Show()
	else
		self.delta:Hide()
	end
	if deltaColour then self.delta:SetGlyphColor(deltaColour) end

	-- Update values
	if percent then
		value = value * 100
		value = lume.round(value, 0.1)

		if lume.round(value) == value then
			value = lume.round(value)
		end

		value = value and value.."%" or ""
	end

	self.value:SetText(value or "")
	self.label:SetText(label..":" or "")


	-- Layout widgets
	self.delta:LayoutBounds("after", "center", self.value)
		:Offset(4, 0)
	self.valueContainer:LayoutBounds("after", "bottom", self.label)
		:Offset(8, 0)
    return self
end

function DisplayValueHorizontal:ShouldShowToolTip(bool)
	self.show_tooltip = bool
	return self
end

function DisplayValueHorizontal:SetStat(data)

	local is_smaller = data.delta < 0
	local is_better = is_smaller == self.is_smaller_better

	local name = STRINGS.UI.EQUIPMENT_STATS[string.upper(data.stat)].name
	self:SetValue(data.value, name, data.delta, is_better and UICOLORS.BONUS or UICOLORS.PENALTY, EquipmentStatDisplay[data.stat].percent)

	local tt
	if EquipmentStatDisplay[data.stat].tt_fn then
		tt = EquipmentStatDisplay[data.stat].tt_fn(data.stat, data.value)
	else
		tt = STRINGS.UI.EQUIPMENT_STATS[string.upper(data.stat)].desc
	end

	if self.show_tooltip then
		self:SetToolTip(tt)
	end

    return self
end

function DisplayValueHorizontal:SetValueColour(colour)
	self.value:SetGlyphColor(colour)
	return self
end

function DisplayValueHorizontal:SetLabelColour(colour)
	self.label:SetGlyphColor(colour)
	return self
end

function DisplayValueHorizontal:SetValueFontSize(size)
	self.value:SetFontSize(size)
	return self
end

function DisplayValueHorizontal:SetLabelFontSize(size)
	self.label:SetFontSize(size)
	return self
end

return DisplayValueHorizontal
