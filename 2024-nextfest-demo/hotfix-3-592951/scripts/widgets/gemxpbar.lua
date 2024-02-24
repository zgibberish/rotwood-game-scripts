local Widget = require("widgets/widget")
local Text = require("widgets/text")
local Image = require("widgets/image")

------------------------------------------------------------------------------------------------
-- Allows the player to equip gems in their current weapon

local GemXpBar = Class(Widget, function(self, gem)
	Widget._ctor(self, "GemXpBar")

	self.gem_level = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetName("Gem level")
		:SetText("Lvl")
		:SetGlyphColor(UICOLORS.GEM)
		:SetHAlign(ANCHOR_MIDDLE)

	self.xp_bar_width = 100
	self.xp_bar_height = 7
	self.xp_bar = self:AddChild(Widget())
		:SetName("XP bar")
	self.xp_bar_bg = self.xp_bar:AddChild(Image("images/global/square.tex"))
		:SetName("XP bar bg")
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetMultColorAlpha(0.3)
		:SetSize(self.xp_bar_width, self.xp_bar_height)
	self.xp_bar_fill = self.xp_bar:AddChild(Image("images/global/square.tex"))
		:SetMultColor(UICOLORS.GEM)
		:SetSize(self.xp_bar_width, self.xp_bar_height)

	self:SetGem(gem)
end)

function GemXpBar:SetTextColor(text_color)
	self.gem_level:SetGlyphColor(text_color)
	self.xp_bar_fill:SetMultColor(text_color)
	return self
end

function GemXpBar:SetMaxWidth(width)
	self.xp_bar_width = width or self.xp_bar_width
	self.xp_bar_bg:SetSize(self.xp_bar_width, self.xp_bar_height)
	self.xp_bar_fill:SetSize(self.xp_bar_width, self.xp_bar_height)
	return self
end

function GemXpBar:ShowLevelUp(gem)
	self.gem = gem
	if self.gem then
		local gem_def = self.gem:GetDef()
		local completed_gem_level = self.gem.ilvl - 1
		local gem_type = gem_def.gem_type
		local target_exp = gem_def.base_exp[completed_gem_level]

		self.gem_level:Show()
		self.xp_bar:Show()

		self.gem_level:SetText(string.format("%d/%d", target_exp, target_exp))
		self.xp_bar_fill:SetSize(self.xp_bar_width, self.xp_bar_height)
	end
	return self
end

function GemXpBar:SetGem(gem)

	self.gem = gem
	if self.gem then
		local gem_def = self.gem:GetDef()
		local gem_level = self.gem.ilvl
		local gem_type = gem_def.gem_type
		local current_exp = self.gem.exp
		local target_exp = gem_def.base_exp[gem_level]

		if gem_level < #gem_def.base_exp then
			self.gem_level:Show()
			self.xp_bar:Show()

			self.gem_level:SetText(string.format("%d/%d", math.floor(current_exp), target_exp))

			local percent = current_exp / target_exp
			self.xp_bar_fill:SetSize(percent * self.xp_bar_width, self.xp_bar_height)
		else
			-- Max level
			self.gem_level:Hide()
			self.xp_bar:Hide()
		end
	else
		self.gem_level:Hide()
		self.xp_bar:Hide()
	end

	-- Layout
	self.xp_bar_fill:LayoutBounds("left", "center", self.xp_bar_bg)
	self.xp_bar:LayoutBounds("center", "below", self.gem_level)
		:Offset(0, -5)

	return self
end

return GemXpBar