local Power = require "defs.powers"
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")
local Panel = require("widgets/panel")
local PowerIconWidget = require("widgets/powericonwidget")
local Consumable = require "defs.consumable"

local PriceWidget = Class(Widget, function(self, player, current_price)
	Widget._ctor(self, "PriceWidget")

	self.player = player
	self.current_price = current_price or 0

	self.price = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_SCREEN_SUBTITLE))
		:SetText(string.format(STRINGS.UI.INVENTORYSCREEN.KONJUR, 0))
		:SetFontSize(40)

	self._on_inventory_changed = function()
		self:SetPrice(self.current_price) -- refresh text colour
	end

	local listenPlayer
	self.inst:ListenForEvent("inventory_stackable_changed", self._on_inventory_changed, self.player)

	self:SetPrice(self.current_price)
end)

function PriceWidget:SetTheme_Dark()
	self.price:SetGlyphColor(UICOLORS.DARK_TEXT_DARKER)
	return self
end

function PriceWidget:SetCanAfford(can_afford)
	if not can_afford then
		self.price:SetGlyphColor(UICOLORS.RED)
	end
	return self
end

function PriceWidget:SetLarge()
	self.price:SetFontSize(65)
	return self
end

function PriceWidget:SetPrice(price)
	self.current_price = price
	self.price:SetText(string.format(STRINGS.UI.INVENTORYSCREEN.KONJUR, self.current_price))

	if self:GetCurrentKonjur() < price then
		--self.price:SetGlyphColor(212/255, 11/255, 28/255, 1) -- jambell: disabling this, because sometimes this widget is desaturated and sometimes it's not. the rest of the screen is clear enough, and this Red was inconsistent across screens!
		self:SetToolTip(STRINGS.UI.PRICEWIDGET.NOT_ENOUGH)
	else
		--self.price:SetGlyphColor(1, 1, 1, 1)
		self:SetToolTip(nil)
	end
end

function PriceWidget:GetCurrentKonjur()
	local inventory = self.player.components.inventoryhoard
	return inventory:GetStackableCount(Consumable.Items.MATERIALS.konjur)
end

return PriceWidget
