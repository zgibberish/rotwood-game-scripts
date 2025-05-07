local CurrencyRings = require "widgets.ftf.currencyrings"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local Image = require("widgets/image")
local Consumable = require "defs.consumable"


local RoomBonusKonjurRings = Class(Widget, function(self, current_konjur)
	Widget._ctor(self, "RoomBonusKonjurRings")

	local scale = 1
	self.rings = self:AddChild(CurrencyRings(scale))

	self.icon = self:AddChild(Image("images/ui_ftf_icons/konjur.tex"))
		:SetScale(scale * .625)
		:LayoutBounds("center", "center", self.rings:GetCenterWidget())
		:Offset(1 * HACK_FOR_4K, 20 * HACK_FOR_4K)

	self.currentKonjur = self:AddChild(Text(FONTFACE.DEFAULT, 34 * HACK_FOR_4K))
		:SetText(string.format(STRINGS.UI.ROOMBONUSSCREEN.CURRENT_KONJUR, current_konjur))
		:SetGlyphColor(HexToRGB(0x8758C9FF))
		:LayoutBounds("center", "center", self.icon)
		:Offset(-3 * HACK_FOR_4K, -55 * HACK_FOR_4K)

	self.currentKonjurLabel = self:AddChild(Text(FONTFACE.DEFAULT, 24 * HACK_FOR_4K))
		:SetText(string.upper(STRINGS.ITEMS.KONJUR.name))
		:SetGlyphColor(HexToRGB(0x8758C9FF))
		:LayoutBounds("center", "center", self.currentKonjur)
		:Offset(0 * HACK_FOR_4K, -25 * HACK_FOR_4K)
end)

-- Meant to be shown as a currency indicator in various player screens
-- Will update itself to show the player's glitz
function RoomBonusKonjurRings:SetGlitzMode(player)

	self.player = player
	self:RefreshGlitz()

	self.inst:ListenForEvent("inventory_stackable_changed", function(inst, itemdef)
		if itemdef == Consumable.Items.MATERIALS.glitz then
			self:RefreshGlitz()
		end
	end, player)

	return self
end

function RoomBonusKonjurRings:RefreshGlitz()
	local amount = 0

	if self.player then
		-- Update konjur count
		local mat_def = Consumable.Items.MATERIALS['glitz']
		amount = self.player.components.inventoryhoard:GetStackableCount(mat_def) or 0
	end

	self.icon:SetTexture("images/ui_ftf_icons/glitz.tex")
	self.currentKonjur:SetText(amount)
		:LayoutBounds("center", "center", self.icon)
		:Offset(-3, -55)
	self.currentKonjurLabel:Hide()
	return self
end

return RoomBonusKonjurRings
