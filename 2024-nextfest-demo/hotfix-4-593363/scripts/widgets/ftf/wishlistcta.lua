local ActionButton = require "widgets.actionbutton"
local Widget = require "widgets.widget"
local easing = require "util.easing"


-- Call to action to wishlist the game
local WishlistCTA = Class(Widget, function(self)
	Widget._ctor(self, "Image")

	self.button = self:AddChild(ActionButton())
		:SetName("Wishlist CTA Button")
		:SetKonjur()
		:SetSize(650, 200)
		:SetTextFocusColour(WEBCOLORS.WHITE) -- looks really nice with darkened purple selection
		:SetText(STRINGS.UI.MAINSCREEN.WISHLIST_CTA)
		:SetOnClick(function() VisitURL("https://store.steampowered.com/app/2015270/Rotwood/?utm_source=demo") end)
end)

function WishlistCTA:AnimateIn()
	if self:IsShown() then return end

	self:Show()
	self:SetMultColorAlpha(0)

	local x, y = self:GetPos()

	self:RunUpdater(Updater.Parallel{
		Updater.Ease(function(a) self:SetMultColorAlpha(a) end, 0, 1, 0.25, easing.outQuad),
		Updater.Ease(function(dy) self:SetPos(x, y + dy) end, -40, 0, 0.75, easing.outElasticUI),
	})
	return self
end

function WishlistCTA:AnimateOut()
	self:Hide()
end

return WishlistCTA
