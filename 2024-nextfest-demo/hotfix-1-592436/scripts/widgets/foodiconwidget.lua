local Power = require "defs.powers"
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local lume = require("util/lume")

local RARITY_TO_ICON_COLOUR =
{
	[Power.Rarity.COMMON] =  RGB(162, 111, 95),
	[Power.Rarity.EPIC] =  RGB(195, 214, 238),
	[Power.Rarity.LEGENDARY] = RGB(250, 190, 88),
}

local FoodIconWidget = Class(Widget, function(self)
	Widget._ctor(self, "FoodIconWidget")

	self.icon_container = self:AddChild(Widget("Icon Root"))

	self.border = self.icon_container:AddChild(Image("images/ui_ftf_powers/common_food.tex"))

	-- With the size of the bg, we can compute any desired pixel width.
	self.base_width = self.border:GetSize()


	-- Icon depicting what the power does.
	self.icon = self.icon_container:AddChild(Image("images/global/square.tex"))
		:SetHiddenBoundingBox(true)
		:SetSize(self.base_width, self.base_width)

	self.border:MoveToFront()

end)

function FoodIconWidget:SetScaleToMatchWidth(width)
	local scale = width / self.base_width
	return self:SetScale(scale)
end

function FoodIconWidget:BuildTextureName(food)
	local rarity = self.food:GetRarity()
	local category = self.def.power_category
	local name = string.format("images/ui_ftf_powers/%s_food.tex", rarity)
	return string.lower(name)
end

-- Accepts power ItemInstance instead of pow since may present unselected powers.
function FoodIconWidget:SetFood(food)
	self.food = food
	self.def = food:GetDef()

	local current_rarity_idx = lume.find(Power.RarityIdx, self.food:GetRarity())
	self.border:SetTexture( self:BuildTextureName(self.food) )
	self.icon:SetTexture(self.def.icon)
	-- self.icon:SetMultColor(RARITY_TO_ICON_COLOUR[self.food:GetRarity()])
	return self
end

function FoodIconWidget:UpdateFood()
	local current_rarity_idx = lume.find(Power.RarityIdx, self.food:GetRarity())
	self.border:SetTexture( self:BuildTextureName(self.food) )
end

return FoodIconWidget
