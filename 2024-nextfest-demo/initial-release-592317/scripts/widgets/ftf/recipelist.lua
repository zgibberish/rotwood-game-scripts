local ScrollPanel = require "widgets.scrollpanel"
local Widget = require "widgets.widget"
local RecipeRow = require"widgets.ftf.reciperow"
local Text = require "widgets.text"

------------------------------------------------------------------------------------------
--- Displays an actions widget (right side) that allows the player
--- to forge some items
----
local RecipeList = Class(Widget, function(self, player, width, height)
	Widget._ctor(self, "RecipeList")

	self.player = player
	self.width = width or 400
	self.height = height or 300

	self.paddingRight = 70 -- To add spacing between the scroll bar and the right edge
	self.paddingLeft = 20

	self.headerHeight = 40
	self.equippedHeight = 80

	self.itemRowW = self.width
	self.itemRowH = 160

	self.itemList = self:AddChild(ScrollPanel())
		:SetSize(self.width, self.height)
		:SetVirtualMargin(15)

	-- Container for item rows within the scroll panel
	self.itemListContent = self.itemList:AddScrollChild(Widget())

    -- Text to display if the list is empty
	self.emptyText = self:AddChild(Text(FONTFACE.DEFAULT, 30, STRINGS.UI.INVENTORYSCREEN.EMPTY_LIST_INFO, UICOLORS.ITEM_DARK))
		:LayoutBounds("center", "top", self.itemList)
		:Offset(0, -15)
		:SetNavFocusable(true)

end)

function RecipeList:SetDefaultFocus()
	local list_item = self.itemListContent:GetFirstChild()

	if list_item then
		list_item:SetFocus()
	else
		self.emptyText:SetFocus()
	end
end

function RecipeList:SetSize(width, height)
	self.width = width or 400
	self.height = height or 300
	self.itemList:SetSize(self.width, self.height)
	return self
end

function RecipeList:SetSlot(slot, itemsList, currentlyEquipped)
	self.slot = slot
	self.itemsList = itemsList
	self.currentlyEquipped = currentlyEquipped

	-- Clear the item list
	self.itemListContent:RemoveAllChildren()

	-- And fill it back up with items
	for _, data in ipairs(self.itemsList) do
		local row = self.itemListContent:AddChild(RecipeRow(self.itemRowW - self.paddingRight, self.itemRowH))
			:SetPlayer(self.player)
			:SetRecipeData(data.itemData, self.currentlyEquipped)
		row:SetOnClick(function() self:OnRowClicked(row, data.itemData) end)
		row:SetOnGainFocus(function() self:OnRowGainFocus(row, data.itemData) end)
		row:SetOnLoseFocus(function() self:OnRowLoseFocus(row, data.itemData) end)
	end

	self.itemListContent:LayoutChildrenInGrid(1, 0)
		:LayoutBounds("left", "top")
		:Offset(-self.itemRowW/2 + self.paddingLeft, 0)
	self.itemList:RefreshView()
		:LayoutBounds("center", "below", self.header)
		:Offset(0, 0)

	self.emptyText:SetShown(#self.itemsList == 0)

	return self
end

function RecipeList:OrderItemsByStat(stat)

	-- And fill it back up with items
	for k, itemData in pairs(self.itemsList) do
		local row = self.itemListContent:AddChild(RecipeRow(self.itemRowW, self.itemRowH))
			:SetPlayer(self.player)
			:SetRecipeData(itemData, self.currentlyEquipped)
		row:SetOnClick(function() self:OnRowClicked(row, itemData) end)
	end

	self.itemListContent:LayoutChildrenInGrid(1, 2)
		:LayoutBounds("left", "top")
		:Offset(-self.itemRowW/2 + self.paddingLeft, 0)

	self:SetDefaultFocus()
end

function RecipeList:SetOnRecipeClickedFn(fn)
	self.onRecipeClickedFn = fn
	return self
end

function RecipeList:SetOnRecipeGainFocusFn(fn)
	self.onRecipeGainFocusFn = fn
	return self
end

function RecipeList:SetOnRecipeLoseFocusFn(fn)
	self.onRecipeLoseFocusFn = fn
	return self
end

function RecipeList:SelectEquippedOrFirst()

	if #self.itemListContent.children > 0 then
		local to_select = 1
		local currentlyEquipped = self.player.components.inventoryhoard:GetEquippedItem(self.slot)

		for idx, data in ipairs(self.itemsList) do


			if currentlyEquipped and data.itemData.def == currentlyEquipped:GetDef() then
				to_select = idx
				break
			end
		end

		self.itemListContent.children[to_select]:Click()
	end
	return self
end

function RecipeList:SelectFirst()
	if #self.itemListContent.children > 0 then
		self.itemListContent.children[1]:Click()
	end
	return self
end

function RecipeList:OnRowClicked(row, recipeData)

	-- Unselect other rows
	for k, r in ipairs(self.itemListContent.children) do
		r:SetSelected(r == row)
	end

	if self.onRecipeClickedFn then self.onRecipeClickedFn(recipeData) end

	return self
end

function RecipeList:OnRowGainFocus(row, recipeData)
	if self.onRecipeGainFocusFn then self.onRecipeGainFocusFn(recipeData) end
	return self
end

function RecipeList:OnRowLoseFocus(row, recipeData)
	if self.onRecipeLoseFocusFn then self.onRecipeLoseFocusFn(recipeData) end
	return self
end

--- When the player inventory changes, update the rows
function RecipeList:OnInventoryChanged()
	-- get equipped item
	-- if it isn't the same as self.currentlyEquipped then do a refresh
	local selectedLoadoutIndex = self.player.components.inventoryhoard.data.selectedLoadoutIndex
	local currentlyEquipped = self.player.components.inventoryhoard:GetLoadoutItem(selectedLoadoutIndex, self.slot)

	if currentlyEquipped ~= self.currentlyEquipped then
		self.currentlyEquipped = currentlyEquipped
	end

	for k, r in ipairs(self.itemListContent.children) do
		r:OnInventoryChanged(currentlyEquipped)
	end

	return self
end

return RecipeList