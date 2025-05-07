local Power = require "defs.powers"
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local PowerPipsWidget = require("widgets/powerpipswidget")

local lume = require("util/lume")
local epic_borders = require "gen.atlas.ui_ftf_powers_epic"

local CATEGORY_TO_BG_COLOUR =
{
	[Power.Categories.SUPPORT] = RGB(29, 52, 52),
	[Power.Categories.SUSTAIN] = RGB(13, 18, 51),
	[Power.Categories.DAMAGE] = RGB(37, 16, 26),
}

local PowerIconWidget = Class(Widget, function(self)
	Widget._ctor(self, "PowerIconWidget")

	self.hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetName("Hitbox")
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0)

	self.icon_container = self:AddChild(Widget("Icon Root"))
		:SetHiddenBoundingBox(true)


	self.icon_bg_fill = self.icon_container:AddChild(Image("images/ui_ftf_powers/UI_HUD_Powers_Mask.tex"))

	-- With the size of the bg, we can compute any desired pixel width.
	self.base_width = self.icon_bg_fill:GetSize()
	-- Set hitbox size
	self.hitbox:SetSize(self.base_width * 0.8, self.base_width * 0.8)

	-- Icon depicting what the power does.
	self.icon = self.icon_container:AddChild(Image("images/global/square.tex"))
		:SetSize(self.base_width, self.base_width)

	self.border = self.icon_container:AddChild(Image("images/ui_ftf_powers/common_damage.tex"))

	self.power_pips_widget = self:AddChild(PowerPipsWidget())
		:SetHiddenBoundingBox(true)
		:SetScale(0.9)
		:LayoutBounds("center", "bottom", self.icon_bg_mask)
		:Offset(0, 20)
end)

function PowerIconWidget:SetScaleToMatchWidth(width)
	local scale = width / self.base_width
	return self:SetScale(scale)
end

function PowerIconWidget:BuildTextureName(power)
	local rarity = self.power:GetRarity()
	local category = self.def.power_category
	local name = string.format("images/ui_ftf_powers/%s_%s.tex", rarity, category)
	return string.lower(name)
end

-- Accepts power ItemInstance instead of pow since may present unselected powers.
function PowerIconWidget:SetPower(power)
	self.power = power
	self.def = power:GetDef()
	self.power_pips_widget:SetPower(power)

	local current_rarity_idx = lume.find(Power.RarityIdx, self.power:GetRarity())
	self.border:SetTexture( self:BuildTextureName(self.power) )
	self.icon_bg_fill:SetMultColor(CATEGORY_TO_BG_COLOUR[self.def.power_category])
	self.icon:SetTexture(self.def.icon)
	return self
end

function PowerIconWidget:UpdatePower()
	self.power_pips_widget:UpdatePips()
	local current_rarity_idx = lume.find(Power.RarityIdx, self.power:GetRarity())
	self.border:SetTexture( self:BuildTextureName(self.power) )
end

return PowerIconWidget
