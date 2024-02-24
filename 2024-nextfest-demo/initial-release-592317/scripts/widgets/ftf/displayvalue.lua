local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")
local EquipmentStatDisplay = require "defs.equipmentstatdisplay"

-------------------------------------------------------------------------------------------------
--- A widget with a large number value, and a label under it

--  ┌─────────┐
--  │         ├───────┐
--  │  value  │ delta │
--  │         ├───────┘
-- ┌┴─────────┴┐
-- │   label   │
-- └───────────┘

local DisplayValue = Class(Widget, function(self)
	Widget._ctor(self, "DisplayValue")

	self.valueContainer = self:AddChild(Widget())
	self.value = self.valueContainer:AddChild(Text(FONTFACE.DEFAULT, 60 * HACK_FOR_4K, "", UICOLORS.LIGHT_TEXT))
	self.delta = self.valueContainer:AddChild(Text(FONTFACE.DEFAULT, 40 * HACK_FOR_4K, "", UICOLORS.LIGHT_TEXT))
		:Hide()
	self.label = self:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
		:LayoutBounds("center", "below", self.valueContainer)
		:Offset(0, 4)

	self.is_smaller_better = false
end)

function DisplayValue:SetValue(value, label, delta, deltaColour, stat)
	local display_info = EquipmentStatDisplay[stat]
	local percent = display_info and display_info.percent
	-- Update values
	if percent then
		value = math.floor(value * 100)
		value = value and value.."%" or ""
	end
	self.value:SetText(value or "")
	self.label:SetText(label..":" or "")

	-- Add an arrow up or down to the delta
	if delta and delta ~= 0 then
		if delta > 0 then
			if percent then
				delta = math.floor(delta * 100)
				delta = delta.."%"
			end

			local arrow = "<p img='images/ui_ftf_shop/displayvalue_up.tex' color='BONUS'>"
			local str = display_info and display_info.hide_delta_value and arrow or delta..arrow
			self.delta:SetText(str)
		elseif delta < 0 then
			delta = math.abs(delta)
			if percent then
				delta = math.floor(delta * 100)
				delta = delta.."%"
			end
			local arrow = "<p img='images/ui_ftf_shop/displayvalue_down.tex' color='PENALTY'>"
			local str = display_info and display_info.hide_delta_value and arrow or delta..arrow
			self.delta:SetText(str)
		end
		self.delta:Show()
	else
		self.delta:Hide()
	end
	if deltaColour then self.delta:SetGlyphColor(deltaColour) end

	-- Layout widgets
	self.delta:LayoutBounds("after", "top", self.value)
		:Offset(6, -4)
	self.valueContainer:LayoutBounds("center", "above", self.label)
		:Offset(0, -8)
    return self
end

function DisplayValue:SetStat(data)
	local is_smaller = data.delta < 0
	local is_better = is_smaller == self.is_smaller_better

	local name = STRINGS.UI.EQUIPMENT_STATS[string.upper(data.stat)].name
	self:SetValue(data.value, name, data.delta, is_better and UICOLORS.BONUS or UICOLORS.PENALTY, stat)

    return self
end

function DisplayValue:SetValueColour(colour)
	self.value:SetGlyphColor(colour)
	return self
end

function DisplayValue:SetLabelColour(colour)
	self.label:SetGlyphColor(colour)
	return self
end

function DisplayValue:SetValueFontSize(size)
	self.value:SetFontSize(size)
	return self
end

function DisplayValue:SetLabelFontSize(size)
	self.label:SetFontSize(size)
	return self
end

return DisplayValue
