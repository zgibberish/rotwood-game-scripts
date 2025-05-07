local Text = require "widgets.text"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local Image = require("widgets/image")

local RoomBonusButtonTitle = Class(Widget, function(self, button, ornament)
	Widget._ctor(self, "RoomBonusButtonTitle")

	self.ornamentscale = 1
	self.button = button

	self.ornamentContainer = self:AddChild(Widget())
    self.ornamentLeft = self.ornamentContainer:AddChild(Image(ornament))
		:SetScale(self.ornamentscale)
    self.ornamentRight = self.ornamentContainer:AddChild(Image(ornament))
		:SetScale(-self.ornamentscale, self.ornamentscale)

	-- local o_w, o_h = self.ornamentContainer:GetSize()
	-- print(o_w, o_h)

    self.title = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TITLE))
		:SetGlyphColor(HexToRGB(0x755751FF))
		:OverrideLineHeight(FONTSIZE.ROOMBONUS_TITLE * 0.9)
end)

function RoomBonusButtonTitle:ApplyWorldPowerDescriptionStyle()
	self.title:SetGlyphColor(UICOLORS.LIGHT_TEXT_TITLE)
		:SetShadowColor(UICOLORS.BLACK)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()
		:SetShadowOffset(1, -1)

	self.ornamentContainer:Hide()
	return self
end

function RoomBonusButtonTitle:SetTitle(text)
	self.title:SetText(text)

	local font_size_override
	local autosize_override
	local x_offset_mod = 0
	local y_offset_mod = 0

	local w,h = self.title:GetSize()
	-- print("title sizes:", w, h)
	if w > 300 * HACK_FOR_4K then
		-- print("why would anyone write a relic name this long", text)
		font_size_override = 27 * HACK_FOR_4K
		autosize_override = 220 * HACK_FOR_4K
		x_offset_mod = 2 * HACK_FOR_4K
		y_offset_mod = -8 * HACK_FOR_4K
	elseif w > 200 * HACK_FOR_4K then
		-- print("really long relic name", text)
		autosize_override = 180 * HACK_FOR_4K
		x_offset_mod = 2 * HACK_FOR_4K
		y_offset_mod = -8 * HACK_FOR_4K
	elseif w > 150 * HACK_FOR_4K then
		-- print("longish relic name", text)
	elseif w > 100 * HACK_FOR_4K then
		-- print("relic name")
		y_offset_mod = -2 * HACK_FOR_4K
	end
	-- print(w,h)

	self.title
		:LayoutBounds("center", "center", self.button)
		:SetHAlign(ANCHOR_MIDDLE)

	if font_size_override then
		self.title:SetFontSize(font_size_override)
	end
	if autosize_override then
		self.title:SetAutoSize(autosize_override)
	end

	-- Now that we know how long the title will be, we can adjust the positioning of the ornaments INWARD if the title was shorter than our max length.
    self.ornamentLeft
		:LayoutBounds("before", "center", self.title)
		:Offset(-8 + -x_offset_mod, 0 + y_offset_mod) -- To make the ornament icons line up right with the text

    self.ornamentRight
		:LayoutBounds("right", "center", self.title)
		:Offset(8 + x_offset_mod, 0 + y_offset_mod) -- To make the ornament icons line up right with the text
end

return RoomBonusButtonTitle
