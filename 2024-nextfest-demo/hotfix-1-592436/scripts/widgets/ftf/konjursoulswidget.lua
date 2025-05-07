local CurrencyRings = require "widgets.ftf.currencyrings"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local Image = require("widgets/image")
local Consumable = require "defs.consumable"

local KonjurSoulsWidget = Class(Widget, function(self, konjur_on_skip)
	Widget._ctor(self, "KonjurSoulsWidget")

	self.scale = 1
	self.rings = self:AddChild(CurrencyRings(self.scale))

	-- Main icon
	self.lesser_souls_container = self:AddChild(Widget())
		:SetToolTip(STRINGS.UI.PAUSEMENU.MAP_LEGEND.konjur_soul_lesser)
	self.lesser_souls_icon = self.lesser_souls_container:AddChild(Image('images/hud_images/hud_konjur_soul_lesser_drops_currency.tex'))
		:SetScale(self.scale * .525)
		:LayoutBounds("center", "center", self.rings:GetCenterWidget())
		:Offset(1, 20 * HACK_FOR_4K)
	self.lesser_souls_count = self.lesser_souls_container:AddChild(Text(FONTFACE.DEFAULT, 34 * HACK_FOR_4K))
		:SetText(string.format(STRINGS.UI.ROOMBONUSSCREEN.SKIP_BUTTON_KONJUR, konjur_on_skip))
		:SetGlyphColor(HexToRGB(0x8758C9FF))
		:LayoutBounds("center", "center", self.lesser_souls_icon)
		:Offset(-3, -55 * HACK_FOR_4K)
	self.lesser_souls_label = self.lesser_souls_container:AddChild(Text(FONTFACE.DEFAULT, 24 * HACK_FOR_4K))
		:SetText(string.upper(STRINGS.ITEMS.KONJUR.name))
		:SetGlyphColor(HexToRGB(0x8758C9FF))
		:LayoutBounds("center", "center", self.lesser_souls_count)
		:Offset(0, -25 * HACK_FOR_4K)
end)

-- Meant to be shown as a currency indicator in various player screens
-- Will update itself to show the player's glitz
function KonjurSoulsWidget:SetSoulsMode(player)

	self.player = player
	self:RefreshSouls()

	self.inst:ListenForEvent("inventory_stackable_changed", function(inst, itemdef)
		if itemdef == Consumable.Items.MATERIALS['konjur_soul_lesser']
		or itemdef == Consumable.Items.MATERIALS['konjur_soul_greater'] then
			self:RefreshSouls()
		end
	end, player)

	return self
end

function KonjurSoulsWidget:RefreshSouls()
	local lesser_souls_amount = 0
	local greater_souls_amount = 0

	if self.player then
		-- Update lesser souls count
		local mat_def = Consumable.Items.MATERIALS['konjur_soul_lesser']
		lesser_souls_amount = self.player.components.inventoryhoard:GetStackableCount(mat_def) or 0

		-- Update greater souls count
		mat_def = Consumable.Items.MATERIALS['konjur_soul_greater']
		greater_souls_amount = self.player.components.inventoryhoard:GetStackableCount(mat_def) or 0
	end

	-- Update main icon
	self.lesser_souls_container:SetToolTip(Consumable.Items.MATERIALS['konjur_soul_lesser'].pretty.name)
	self.lesser_souls_icon:SetTexture('images/hud_images/hud_konjur_soul_lesser_drops_currency.tex')
	self.lesser_souls_count:SetText(lesser_souls_amount)
		:LayoutBounds("center", "center", self.lesser_souls_icon)
		:Offset(-3, -42 * HACK_FOR_4K)

	-- Layout main icon
	self.lesser_souls_container:LayoutBounds("center", "center", self.rings:GetCenterWidget())
		:Offset(1, -5)

	-- Check if the player has greater souls too
	if greater_souls_amount > 0 then
		if not self.greater_souls_icon then
			self.greater_souls_container = self:AddChild(Widget())
				:SetToolTip(Consumable.Items.MATERIALS['konjur_soul_greater'].pretty.name)
			self.greater_souls_icon = self.greater_souls_container:AddChild(Image('images/hud_images/hud_konjur_soul_greater_drops_currency.tex'))
				:SetScale(self.scale * .625)
			self.greater_souls_count = self.greater_souls_container:AddChild(Text(FONTFACE.DEFAULT, 34 * HACK_FOR_4K))
				:SetGlyphColor(HexToRGB(0x8758C9FF))
		end
		self.greater_souls_count:SetText(greater_souls_amount)
			:LayoutBounds("center", "center", self.greater_souls_icon)
			:Offset(-3 * HACK_FOR_4K, -50 * HACK_FOR_4K)

		-- Layout both icons
		self.lesser_souls_container:LayoutBounds("center", "center", self.rings:GetCenterWidget())
			:Offset(-30 * HACK_FOR_4K, 10 * HACK_FOR_4K)
		self.greater_souls_container:LayoutBounds("center", "center", self.rings:GetCenterWidget())
			:Offset(35 * HACK_FOR_4K, -20 * HACK_FOR_4K)
	end

	-- Hide label
	self.lesser_souls_label:Hide()
	return self
end

return KonjurSoulsWidget
