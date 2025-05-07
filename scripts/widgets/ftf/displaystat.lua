local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")

local lume = require"util.lume"
local EquipmentStatDisplay = require "defs.equipmentstatdisplay"

-------------------------------------------------------------------------------------------------
--- A widget with an icon and label on the left, and then a value aligned to the right

-- ┌──────┬─────────────────────────────────┐
-- │      │                         ┌───────┤
-- │ icon │ label             value │ delta │
-- │      │                         └───────┤
-- └──────┴─────────────────────────────────┘
--                                          ▲ max_width

local DisplayStat = Class(Widget, function(self, max_width, icon_size, text_size, delta_size)
	Widget._ctor(self, "DisplayStat")

	self.max_width = max_width or (200 * HACK_FOR_4K)
	icon_size = icon_size or (20 * HACK_FOR_4K)
	text_size = text_size or (22 * HACK_FOR_4K)
	delta_size = delta_size or (22 * HACK_FOR_4K)
	self.show_name = true

	self.up_color = UICOLORS.BONUS
	self.down_color = UICOLORS.PENALTY

	self.icon = self:AddChild(Image())
		:SetSize(icon_size, icon_size)
		:SetMultColor(UICOLORS.DARK_TEXT)
		:Hide()

	self.label = self:AddChild(Text(FONTFACE.DEFAULT, text_size, "", UICOLORS.DARK_TEXT))
		:LeftAlign()

	self.valueContainer = self:AddChild(Widget())
	self.value = self.valueContainer:AddChild(Text(FONTFACE.DEFAULT, text_size, "", UICOLORS.DARK_TEXT))
	self.delta = self.valueContainer:AddChild(Text(FONTFACE.DEFAULT, delta_size, "", UICOLORS.DARK_TEXT))
		:Hide()

	self.is_smaller_better = false
	self.show_tooltip = false
end)

-- If this is being displayed in a light background, this switches to colors that read better
function DisplayStat:SetLightBackgroundColors()
	self.up_color = UICOLORS.BONUS_LIGHT_BG
	self.down_color = UICOLORS.PENALTY_LIGHT_BG
	return self
end

function DisplayStat:SetStyle_EquipmentPanel()
	self.value:SetGlyphColor(UICOLORS.DARK_TEXT)
	self.icon:SetMultColor(UICOLORS.DARK_TEXT)
	self.up_color = UICOLORS.BONUS_LIGHT_BG
	self.down_color = UICOLORS.PENALTY_LIGHT_BG
	return self
end

function DisplayStat:SetValue(value, label, delta, deltaColour, stat)
	local display_info = EquipmentStatDisplay[stat]
	-- Add an arrow up or down to the delta
	local delta_arrow
	if delta and delta ~= 0 then
		if delta > 0 then
			delta_arrow = "<p img='images/ui_ftf_shop/displayvalue_up.tex' color=" .. HexToStr(RGBToHex(self.up_color)) .. ">"
		elseif delta < 0 then
			value = value
			delta = math.abs(delta)
			delta_arrow = "<p img='images/ui_ftf_shop/displayvalue_down.tex' color=" .. HexToStr(RGBToHex(self.down_color)) .. ">"
		end

		if display_info and display_info.percent then
			delta = delta * 100
			delta = lume.round(delta, 0.1)

			if lume.round(delta) == delta then
				delta = lume.round(delta)
			end

			delta = delta.."%"
		end

		self.delta:Show()
	else
		self.delta:Hide()
	end
	if deltaColour then self.delta:SetGlyphColor(deltaColour) end

	-- Update values
	if display_info and display_info.percent then
		value = value * 100
		value = lume.round(value, 0.1)

		if lume.round(value) == value then
			value = lume.round(value)
		end

		value = value and value.."%" or ""
	end

	if display_info and display_info.round then
		value = lume.round(value, display_info and display_info.round)
		delta = lume.round(delta, display_info and display_info.round)
	end

	if display_info and display_info.displayvalue_fn then
		value = display_info and display_info.displayvalue_fn(stat, value)
		delta = display_info and display_info.displayvalue_fn(stat, delta)
	end

	self.value:SetText(value or "")
	self.label:SetText(label or "")
		:SetShown(self.show_name)
	if delta_arrow then
		local delta_str = display_info and display_info.hide_delta_value and delta_arrow or delta..delta_arrow
		self.delta:SetText(delta_str)
	end

	-- Layout widgets
	self.label:LayoutBounds(self.icon:IsShown() and "after" or "left", "center", self.icon)
		:Offset(6, 0)
	self.delta:LayoutBounds("after", "center", self.value)
		:Offset(4, 0)
	self.valueContainer:LayoutBounds("after", "center", self.icon:IsShown() and self.icon or self.label)
	if self.underline then
		self.underline:LayoutBounds("left", "below", self.icon:IsShown() and self.icon or self.label):Offset(5, -4)
	end
    return self
end

function DisplayStat:ShowName(bool)
	self.show_name = bool
	return self
end

function DisplayStat:ShouldShowToolTip(bool)
	self.show_tooltip = bool
	return self
end

function DisplayStat:ShowUnderline(bool, divisions, color)
	if bool then
		color = color or UICOLORS.LIGHT_TEXT_DARKER
		local image = "images/ui_ftf_inventory/StatsUnderline4.tex"
		if divisions and divisions == 3 then
			image = "images/ui_ftf_inventory/StatsUnderline3.tex"
		elseif divisions and divisions == 2 then
			image = "images/ui_ftf_inventory/StatsUnderline2.tex"
		end
		self.underline = self:AddChild(Image(image))
			:SetSize(self.max_width - 8 * HACK_FOR_4K, 2.5)
			:SetHiddenBoundingBox(true)
			:SetMultColor(color)
	end
	return self
end

function DisplayStat:SetStat(data)
	local is_smaller = data.delta < 0
	local is_better = is_smaller == self.is_smaller_better

	self.icon:SetTexture(data.icon)
		:Show()

	local name = STRINGS.UI.EQUIPMENT_STATS[string.upper(data.stat)].name

	self:SetValue(data.value, name, data.delta, is_better and self.up_color or self.down_color, data.stat)

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

return DisplayStat
