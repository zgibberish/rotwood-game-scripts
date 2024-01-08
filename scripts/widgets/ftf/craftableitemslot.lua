local ImageButton = require("widgets/imagebutton")
local InventorySlot = require("widgets/ftf/inventoryslot")

local Consumable = require"defs.consumable"
-------------------------------------------------------------------------------------------------
--- A craftable item slot
local CraftableItemSlot = Class(InventorySlot, function(self, size)
	InventorySlot._ctor(self, size)
	self:SetName("CraftableItemSlot")

	-- Add favourite button
	self.favouriteButton = self:AddChild(ImageButton("images/ui_ftf_shop/item_favourite_button.tex"))
		:SetImageNormalColour(UICOLORS.ITEM_DARK)
		:SetImageFocusColour(UICOLORS.LIGHT_TEXT_DARK)
		:SetSize(30 * HACK_FOR_4K, 30)
		:LayoutBounds("right", "top", self.background)
		:SetOnClick(function() if self.onClickFavourite then self.onClickFavourite() end end)

end)

function CraftableItemSlot:SetFavourite(favourite)
	self.favourite = favourite
	self.favouriteButton:SetImageNormalColour(self.favourite and UICOLORS.FOCUS or UICOLORS.ITEM_DARK)
	return self
end

function CraftableItemSlot:SetOnClickFavourite(fn)
	self.onClickFavourite = fn
	return self
end

function CraftableItemSlot:SetItem(item, player)
	CraftableItemSlot._base.SetItem(self, item, player)

	if self.item then
		local def = Consumable.FindItem(self.itemDef.name)
		local count = player.components.inventoryhoard:GetStackableCount(def)

		if count and count > 0 then
			self.quantity:SetText(count)
		else
			self.quantity:SetText("")
		end
	end

	return self
end

return CraftableItemSlot
