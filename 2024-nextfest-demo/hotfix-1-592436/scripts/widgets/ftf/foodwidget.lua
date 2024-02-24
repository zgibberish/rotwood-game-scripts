local Power = require "defs.powers"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local FoodIconWidget = require "widgets.foodiconwidget"
local easing = require "util.easing"

local FoodWidget = Class(Widget, function(self, width, owner, food)
	Widget._ctor(self, "FoodWidget")

	self.width = width or 107

	self.owner = owner
	self.food = food
	self.food_def = food:GetDef()

	self.food_widget_root = self:AddChild(Widget())

	self.food_widget = self.food_widget_root:AddChild(FoodIconWidget())
		:SetScaleToMatchWidth(self.width)
		:SetFood(food)

	self:UpdateUI()
end)

function FoodWidget:UpdateUI()
	self:SetToolTip((STRINGS.UI.UNITFRAME.FOOD_TOOLTIP):format(self.food_def.pretty.name, Power.GetDescForPower(self.food)))
	self.food_widget:UpdateFood()
end

function FoodWidget:AnimateFocusGrab(duration)
	if self.is_animating then
		return
	end
	self.is_animating = true

	self:ScaleTo(1, 1.75, duration * 0.6, easing.inOutQuad, function()
		self:ScaleTo(1.75, 1, duration * 0.4, easing.outElastic)
	end)
end

return FoodWidget