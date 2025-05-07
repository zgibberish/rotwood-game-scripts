local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")
local RadialProgress = require("widgets/radialprogress")
local ActionAvailableIcon = require("widgets/ftf/actionavailableicon")
local ArmourResearchRadial = require("widgets/ftf/armourresearchradial")
local monster_pictures = require "gen.atlas.monster_pictures"

local itemforge = require "defs.itemforge"
local recipes = require "defs.recipes"

local easing = require "util.easing"

local color = require "math.modules.color"

--------------------------------------------------------------
-- Displays an icon, title and value with a progress radial around the icon
--
--  ▼ radial_bg
-- ┌──────────┐      ▼ text_container
-- │          │ ┌────────────────────────┐
-- │   icon   │ │ title                  │
-- │          │ │ value                  │
-- │          │ └────────────────────────┘
-- └──────────┘

local RadialStatWidget = Class(Widget, function(self, width, radial_size, icon_size)
	Widget._ctor(self, "RadialStatWidget")

	self.width = width or 500
	self.radial_size = radial_size or 110
	self.radial_spacing = 20
	self.text_width = self.width - self.radial_size - self.radial_spacing
	self.icon_size = icon_size or 110

	self.color_fill = UICOLORS.LIGHT_TEXT_DARKER
	self.color_bg = color.alpha(UICOLORS.LIGHT_TEXT_DARKER, 0.2)

	self.hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetName("Hitbox")
		:SetSize(self.width, self.radial_size)
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0.0)

	self.radial_bg = self:AddChild(Image("images/ui_ftf_research/research_stats_radial.tex"))
		:SetName("Radial background")
		:SetSize(self.radial_size, self.radial_size)
		:SetMultColor(self.color_bg)
		:SetHiddenBoundingBox(true)
	self.radial_fill = self:AddChild(RadialProgress("images/ui_ftf_research/research_stats_radial.tex"))
		:SetName("Radial fill")
		:SetSize(self.radial_size, self.radial_size)
		:SetMultColor(self.color_fill)
		:SetHiddenBoundingBox(true)
		:SetProgress(0)

	self.icon = self:AddChild(Image("images/global/square.tex"))
		:SetName("Icon")
		:SetSize(self.icon_size, self.icon_size)
		:SetHiddenBoundingBox(true)

	self.text_container = self:AddChild(Widget())
		:SetName("Text container")
		:SetHiddenBoundingBox(true)
	self.title = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT, "TITLE", self.color_fill))
		:SetName("Title")
		:SetAutoSize(self.text_width)
		:LeftAlign()
	self.value = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT * 1.3, "10/10", self.color_fill))
		:SetName("Value")
		:SetAutoSize(self.text_width)
		:LeftAlign()

	self:Layout()
end)

function RadialStatWidget:SetIcon(icon, icon_size, icon_color)
	self.icon:SetTexture(icon)
	if icon_size then
		self.icon_size = icon_size
		self.icon:SetSize(self.icon_size, self.icon_size)
		self:Layout()
	end
	if icon_color then
		self.icon:SetMultColor(icon_color)
	end
	return self
end

function RadialStatWidget:Refresh(title_text, value_text, progress_0to1)
	if title_text then self.title:SetText(title_text) end
	if value_text then self.value:SetText(value_text) end
	if progress_0to1 then self.radial_fill:SetProgress(progress_0to1) end
	self:Layout()
	return self
end

function RadialStatWidget:SetValue(value_text)
	self.value:SetText(value_text)
	self:Layout()
	return self
end

function RadialStatWidget:AnimateProgress(progress_0to1)
	self.radial_fill:RunUpdater(Updater.Ease(function(v) self.radial_fill:SetProgress(v) end, self.radial_fill:GetProgress(), progress_0to1, 0.3, easing.outQuad))
	return self
end

function RadialStatWidget:Layout()

	self.radial_bg:LayoutBounds("left", "center", self.hitbox)
	self.radial_fill:LayoutBounds("center", "center", self.radial_bg)

	self.icon:LayoutBounds("center", "center", self.radial_bg)

	self.value:LayoutBounds("left", "below", self.title)
	self.text_container:LayoutBounds("after", "center", self.radial_bg)
		:Offset(self.radial_spacing, 0)

	return self
end

return RadialStatWidget
