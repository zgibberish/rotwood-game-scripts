local Power = require "defs.powers"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local Panel = require "widgets.panel"
local PowerWidget = require "widgets/ftf/powerwidget"
local SkillWidget = require "widgets/ftf/skillwidget"
local FoodWidget = require "widgets/ftf/foodwidget"
local easing = require "util.easing"
local Image = require "widgets/image"

-- Displays a power widget (frame, icon, and stacks) and its description
-- Meant to be shown in the inventory

--           ┌──────────────────────────────────┐
--           │         instructions_label       │
-- ┌─────────┴───┬─┬────────────────────────────┴─────────┐
-- │             │ │                                      │ ◄ text_container
-- │             │ │                                      │
-- │    icon     │ │               title                  │
-- │             │ │             description              │
-- │             │ │                                      │
-- │             │ │                                      │
-- └─────────────┘ └──────────────────────────────────────┘
--                  ▲ details_bg


local PowerDisplayWidget = Class(Widget, function(self, width, owner, power, other_type, hide_icon, icon_override, hide_tail)
	Widget._ctor(self, "PowerDisplayWidget")

	self.width = width or 107 * HACK_FOR_4K
	self.icon_width = 100 * HACK_FOR_4K
	self.details_w = self.width - self.icon_width*0.6
	self.details_h_min = self.icon_width*0.9
	self.text_w = self.details_w - 50 * HACK_FOR_4K

	self.owner = owner
	self.power = power
	self.power_def = self.power and self.power:GetDef()

	if icon_override then
		self.icon = self:AddChild(Image(icon_override))
			:SetScale(0.75, 0.75)
	elseif other_type == "skill" then
		self.icon = self:AddChild(SkillWidget(self.icon_width, self.owner, self.power))
	elseif other_type == "food" then
		self.icon = self:AddChild(FoodWidget(self.icon_width, self.owner, self.power))
	else
		self.icon = self:AddChild(PowerWidget(self.icon_width, self.owner, self.power))
	end

	if hide_icon then
		self.icon:Hide()
	end

	self.details_bg = self:AddChild(Panel("images/ui_ftf_powers/PowerDetailsBg.tex"))
		:SetNineSliceCoords(84, 8, 502, 150)
		:SetMultColor(0x261E1Dff)
		:SetSize(self.details_w, self.details_h_min)
	self.instructions_label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT * 0.8))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
	self.text_container = self:AddChild(Widget("text container"))
	self.title = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_SUBTITLE * 0.8))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetAutoSize(self.text_w)
		:SetText(self.power_def.pretty.name)
	self.description = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT * 0.7))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetAutoSize(self.text_w)
		:SetText(Power.GetDescForPower(self.power))

	self:Layout()
end)

function PowerDisplayWidget:SetInstructions(instructions)
	self.instructions_label:SetText(instructions)
		:SetShown(instructions)
	self:Layout()
	return self
end

function PowerDisplayWidget:Layout()

	self.description:LayoutBounds("center", "below", self.title)
		:Offset(0, 1)
	-- Calculate text height and resize bg
	local t_w, t_h = self.text_container:GetSize()
	local details_h = math.max(self.details_h_min, t_h + 20 * HACK_FOR_4K)
	self.details_bg:SetSize(self.details_w, details_h)
		:LayoutBounds("left", "bottom", self.icon)
		:Offset(self.icon_width*0.6, 0)
	self.text_container:LayoutBounds("center", "center", self.details_bg)
		:Offset(20 * HACK_FOR_4K, 0)
	self.instructions_label:LayoutBounds("center", nil, self)
		:LayoutBounds(nil, "above", self.details_bg)
		:Offset(0, 2 * HACK_FOR_4K)

	return self
end

return PowerDisplayWidget
