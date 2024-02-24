local InventorySlot = require "widgets.ftf.inventoryslot"
local ScrollPanel = require "widgets.scrollpanel"
local Widget = require "widgets.widget"
local Image = require "widgets.image"
local Text = require "widgets.text"

------------------------------------------------------------------------------------------
--- A simple holder for something else. It takes up a fixed width and then displays
--- an icon or text inside it centered within it
----

local InventoryItemList = Class(Widget, function(self, width, height)
	Widget._ctor(self, "InventoryItemList")

	self.width = width or (300 * HACK_FOR_4K)
	self.height = height or (300 * HACK_FOR_4K)
	self.leftPadding = 15 * HACK_FOR_4K -- So the items don't touch the left clipping edge
	self.rightPadding = 10 * HACK_FOR_4K
	self.item_grid_columns = 9
	self.listWidth = self.width - self.leftPadding - self.rightPadding
	self.itemSize = 80 * HACK_FOR_4K

	self.hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetMultColor(HexToRGB(0xff000040))
		:SetSize(self.width, self.height)
		:SetMultColorAlpha(0)

	self.scroll = self:AddChild(ScrollPanel())
		:SetSize(self.listWidth, self.height)
        :SetVirtualMargin(20 * HACK_FOR_4K)
        :LayoutBounds("left", "center", self.hitbox)
    self.scrollContents = self.scroll:AddScrollChild(Widget())

    -- Text to display if the list is empty
	self.emptyText = self:AddChild(Text(FONTFACE.DEFAULT, 30 * HACK_FOR_4K, STRINGS.UI.INVENTORYSCREEN.EMPTY_LIST_INFO, UICOLORS.ITEM_DARK))
		:LayoutBounds("center", "top", self.scroll)
		:Offset(0, -15 * HACK_FOR_4K)
		:SetNavFocusable(true)
end)

function InventoryItemList:SetDefaultFocus()
	local list_item = self.scrollContents:GetFirstChild()

	if self.currently_highlighted then
		self.currently_highlighted:SetFocus()
	elseif list_item then
		list_item:SetFocus()
	else
		self.emptyText:SetFocus()
	end
end

function InventoryItemList:SetSize(width, height)
	self.width = width or (300 * HACK_FOR_4K)
	self.height = height or (300 * HACK_FOR_4K)
	self.listWidth = self.width - self.leftPadding - self.rightPadding
	self.hitbox:SetSize(self.width, self.height)
	self.scroll:SetSize(self.listWidth, self.height)
	return self
end

function InventoryItemList:SetOnItemClickFn(fn)
	self.onItemClickFn = fn
	return self
end

function InventoryItemList:SetOnItemAltClickFn(fn)
	self.onItemAltClickFn = fn
	return self
end

function InventoryItemList:SetOnItemGainFocus(fn)
	self.onItemGainFocusFn = fn
	return self
end

function InventoryItemList:SetOnItemLoseFocus(fn)
	self.onItemLoseFocusFn = fn
	return self
end

function InventoryItemList:SetItemTooltipFn(fn)
	self.itemTooltipFn = fn
	return self
end

function InventoryItemList:HideItemTooltips()
	self.hideTooltips = true
	return self
end

function InventoryItemList:SetVirtualTopMargin(margin)
	self.scroll:SetVirtualTopMargin(margin)
	return self
end

function InventoryItemList:SetPlayer(player)
	self.player = player
	return self
end

function InventoryItemList:SetSlot(slot_data, itemsList)

	-- Remove old items
	self.scrollContents:RemoveAllChildren()

	-- Get equipped item, for highlight purposes
	local selectedLoadoutIndex = self.player.components.inventoryhoard.data.selectedLoadoutIndex

	local equippedItems = {}

	for _, slot in ipairs(slot_data.slots) do
		local item = self.player.components.inventoryhoard:GetLoadoutItem(selectedLoadoutIndex, slot)
		if item then
			equippedItems[item] = true
		end
	end


	-- Add new ones
	for idx, itemData in ipairs(itemsList) do
		local slot = self.scrollContents:AddChild(InventorySlot(self.itemSize))
			:SetItem(itemData, self.player)
			:SetEquipped(equippedItems[itemData])
			:SetOnClick(function()
				if self.onItemClickFn then self.onItemClickFn(itemData, idx) end
			end)
			:SetOnClickAlt(function()
				if self.onItemAltClickFn then self.onItemAltClickFn(itemData, idx) end
			end)
			:SetOnControllerClickAlt(function()
				if self.onItemAltClickFn then self.onItemAltClickFn(itemData, idx) end
			end)
			:SetOnGainFocus(function()
				if self.onItemGainFocusFn then self.onItemGainFocusFn(itemData, idx) end
			end)
			:SetOnLoseFocus(function()
				if self.onItemLoseFocusFn then self.onItemLoseFocusFn(itemData, idx) end
			end)
			:SetToolTipFn(function() 
				if self.itemTooltipFn then return self.itemTooltipFn(itemData, idx) end 
			end)
			:SetToolTipClass(nil)
			:AddHitbox(6) -- Add an invisible hitbox, so the buttons don't have gaps between them

		if self.hideTooltips then
			slot:SetToolTip(nil)
		end
	end

	self.scrollContents:LayoutChildrenInGrid(self.item_grid_columns, 0)
		:LayoutBounds("left", "top", 0, 0)
		:Offset(-self.listWidth / 2 + self.leftPadding, 0)
	self:RenavControls()
	self.scroll:RefreshView()

	self.emptyText:SetShown(#itemsList == 0)
	if self.emptyText:IsShown() then self.currently_highlighted = nil end

	self.itemsList = itemsList

	return self
end

function InventoryItemList:UpdateEquippedBadge(slot, item)
	if item == nil then
		for i,v in ipairs(self.scrollContents.children) do
			v:SetEquipped(false)
		end
	else
		for i,v in ipairs(self.scrollContents.children) do
			v:SetEquipped(v.item == item)
		end
	end

end

function InventoryItemList:RenavControls()
	-- Go through list and make items nav correctly to each other
	local widgets = self.scrollContents:GetChildren()
	for i, v in ipairs(widgets) do
		if i > 1 then
			v:SetFocusDir("left", widgets[i-1], true)
		end
		if i > self.item_grid_columns then
			v:SetFocusDir("up", widgets[i-self.item_grid_columns], true)
		end
	end
end

function InventoryItemList:SelectIndex(idx)

	for k, w in ipairs(self.scrollContents.children) do
		self.currently_highlighted = w
		w:SetHighlighted(k == idx)
	end

	local w = self.scrollContents.children[idx]
	if w then
		-- TheFrontEnd:HintFocusWidget(w)
	end

	return self
end

return InventoryItemList
