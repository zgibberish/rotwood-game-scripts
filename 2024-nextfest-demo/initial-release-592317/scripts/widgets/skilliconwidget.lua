local Power = require "defs.powers"
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local lume = require("util/lume")

local RARITY_TO_ICON_COLOUR =
{
	[Power.Rarity.COMMON] =  RGB(251, 164, 131),
	[Power.Rarity.EPIC] =  RGB(193, 219, 255),
	[Power.Rarity.LEGENDARY] = RGB(251, 220, 131),
}

local SkillIconWidget = Class(Widget, function(self)
	Widget._ctor(self, "SkillIconWidget")

	self.icon_container = self:AddChild(Widget("Icon Root"))

	self.border = self.icon_container:AddChild(Image("images/ui_ftf_powers/common_damage.tex"))

	-- With the size of the bg, we can compute any desired pixel width.
	self.base_width = self.border:GetSize()

	-- Icon depicting what the power does.
	self.icon = self.icon_container:AddChild(Image("images/global/square.tex"))
		:SetHiddenBoundingBox(true)
		:SetSize(self.base_width, self.base_width)
end)

SkillIconWidget.RARITY_TO_ICON_COLOUR = RARITY_TO_ICON_COLOUR

function SkillIconWidget:SetScaleToMatchWidth(width)
	local scale = width / self.base_width
	return self:SetScale(scale)
end

function SkillIconWidget.TextureFromRarity(rarity)
	return string.lower(string.format("images/ui_ftf_powers/%s_skill.tex", rarity))
end

function SkillIconWidget:BuildTextureName()
	return self.TextureFromRarity(self.skill:GetRarity())
end

-- Accepts power ItemInstance instead of pow since may present unselected powers.
function SkillIconWidget:SetSkill(skill)
	self.skill = skill
	self.def = skill:GetDef()

	local current_rarity_idx = lume.find(Power.RarityIdx, self.skill:GetRarity())
	self.border:SetTexture( self:BuildTextureName() )
	self.icon:SetTexture(self.def.icon)
	self.icon:SetMultColor(RARITY_TO_ICON_COLOUR[self.skill:GetRarity()])
	return self
end

function SkillIconWidget:UpdateSkill()
	local current_rarity_idx = lume.find(Power.RarityIdx, self.skill:GetRarity())
	self.border:SetTexture( self:BuildTextureName() )
end

return SkillIconWidget
