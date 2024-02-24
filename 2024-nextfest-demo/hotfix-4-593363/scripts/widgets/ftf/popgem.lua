local Widget = require "widgets.widget"
local PopPrompt = require("widgets/ftf/popprompt")
local GemXpBar = require("widgets/gemxpbar")
local Text = require("widgets/text")
local Image = require "widgets/image"

local PopGem = Class(PopPrompt, function(self, target, button)
	Widget._ctor(self, "PopGem")

	-- self.bg = self:AddChild(Image("images/ui_ftf/small_panel.tex"))
	-- 	:SetMultColor(UICOLORS.LIGHT_TEXT)
	-- 	:SetName("Background")
	-- 	-- :SetScale(2.5)

	self.gem_icon = self:AddChild(Image(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE, ""))
		:SetName("Gem icon")

	self.gem_level = self:AddChild(GemXpBar())
		:SetName("Gem level")
		-- :SetTextColor(HexToRGB(0x967D7155))
		-- :SetMaxWidth(300)

	self.name_label = self:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.WHITE))
		:SetName("Text label")
		:SetGlyphColor(UICOLORS.WHITE)
end)

local function _LayoutName()

end

function PopGem:Init(data)
	local def = data.gem:GetDef()

	local lvl = data.gem.ilvl
	local lbl
	if data.levelup then
		self.gem_level:ShowLevelUp(data.gem)
		lbl = string.format(STRINGS.ITEMS.GEMS.LEVEL_UP_NOTIFICATION, def.pretty.name.." "..STRINGS.ITEMS.GEMS.ILVL_TO_NAME[lvl])
	else
		self.gem_level:SetGem(data.gem)
		lbl = def.pretty.name.." "..STRINGS.ITEMS.GEMS.ILVL_TO_NAME[lvl]
	end

	self.gem_level:LayoutBounds("middle", "center", self)

	self.name_label:SetText(lbl)
		:SetGlyphColor(UICOLORS.WHITE)
		:LayoutBounds("center", "above", self.gem_level)

	self.gem_icon:SetTexture(def.icon)
		:SetScale(0.35)
		:LayoutBounds("before", "center", self)
		:Offset(-10, 5)

	self:SetScale(data.levelup and 1.7 or 1.5)

	self:Start(data)
end

return PopGem
