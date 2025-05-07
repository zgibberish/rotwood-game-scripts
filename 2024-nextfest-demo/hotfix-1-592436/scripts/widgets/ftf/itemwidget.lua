local Image = require("widgets/image")
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local itemcatalog = require "defs.itemcatalog"
local fmodtable = require "defs.sound.fmodtable"


local ItemWidget = Class(Widget, function(self, item_def, count, size)
	Widget._ctor(self, "ItemWidget")
	
	-- sound
	self:SetControlDownSound(nil)
	self:SetControlUpSound(nil)
	self:SetHoverSound(fmodtable.Event.hover)
	self:SetGainFocusSound(fmodtable.Event.hover)

	self.size = size or 130 * HACK_FOR_4K

	self.mask = self:AddChild(Image("images/ui_ftf_shop/inventory_slot_bg.tex"))
		:SetSize(self.size, self.size)
		:SetMask()

	self.background = self:AddChild(Image("images/ui_ftf_shop/inventory_slot_bg.tex"))
		:SetSize(self.size, self.size)
		:SetMasked()

	self.icon = self:AddChild(Image("images/ui_ftf_shop/inventory_slot_bg.tex"))
		:SetSize(self.size, self.size)
		:SetMasked()

	-- Add quantity
	self.quantity = self:AddChild(Text(FONTFACE.DEFAULT, 30 * HACK_FOR_4K, "", UICOLORS.LIGHT_TEXT_TITLE))
		:SetOutlineColor(UICOLORS.BACKGROUND_LIGHT)
		:EnableOutline(0.00001)
		:LayoutBounds("right", "bottom", self.background)
		:Offset(-12 * HACK_FOR_4K, 15 * HACK_FOR_4K)

	self.bonus_icon = self:AddChild(Image("images/ui_ftf_dialog/convo_quest.tex"))
		:SetSize(self.size * 0.33, self.size * 0.33)
		:SetMultColor(RGB(254, 200, 11))
		:SetToolTip("Bonus Loot!")
		:SetHiddenBoundingBox(true)
		:Hide()

	self:SetItem(item_def, count)
end)

function ItemWidget:SetItem(itemdef, count)
	if itemdef then
		-- Set rarity-specific background
		self:_SetRarity(itemdef.rarity or ITEM_RARITY.s.COMMON)

		self.icon:SetTexture(itemdef.icon)
			:SetMultColor(UICOLORS.WHITE)
			:SetMultColorAlpha(1)

		self:SetToolTip( string.format("%s (x%s)", itemdef.pretty.name, count))

		-- Show quantity if available
		self.quantity:SetText(count)
	end

    return self
end

function ItemWidget:SetBonus()
	self.bonus_icon:Show()

	self.bonus_icon:LayoutBounds("right", "top", self.background)
		-- :Offset(-12 * HACK_FOR_4K, -15 * HACK_FOR_4K)

	return self
end

function ItemWidget:_SetRarity(rarity)
	local tex = itemcatalog.GetRarityIcon(rarity)
	self.background:SetTexture(tex)
	return self
end


return ItemWidget
