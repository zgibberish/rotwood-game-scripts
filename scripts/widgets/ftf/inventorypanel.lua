local InventoryBasePanel = require "widgets.ftf.inventorybasepanel"
local InventoryItemList = require "widgets.ftf.inventoryitemlist"
local ItemDetails = require "widgets.ftf.itemdetails"
local lume = require"util.lume"
local itemcatalog = require "defs.itemcatalog"
local iterator = require "util.iterator"
local itemforge = require "defs.itemforge"
local Consumable = require "defs.consumable"
local Equipment = require "defs.equipment"
local EquipmentGem = require "defs.equipmentgems"

local equipment_sort_data = {
	default = EQUIPMENT_STATS.s.RARITY,
	data = {}
}
for _, rarity in ipairs(EQUIPMENT_STATS:Ordered()) do
	table.insert(equipment_sort_data.data, { name = STRINGS.UI.EQUIPMENT_STATS[rarity].name, data = rarity })
end

local material_sort_data = {
	default = "SOURCE",
	data =
	{
		{ name = STRINGS.UI.EQUIPMENT_STATS.RARITY.name, data = EQUIPMENT_STATS.s.RARITY },
		{ name = STRINGS.UI.EQUIPMENT_STATS.SOURCE.name, data = "SOURCE" },
	}
}

for _, rarity in ipairs(EQUIPMENT_STATS:Ordered()) do
	table.insert(equipment_sort_data, { name = STRINGS.UI.EQUIPMENT_STATS[rarity].name, data = rarity })
end

local default_tabs = {}

local sets_tab =
{
	key = "ARMOUR_SETS",
	slots = {
		Equipment.Slots.HEAD,
		Equipment.Slots.BODY,
		Equipment.Slots.WAIST,
	},
	sort_data = equipment_sort_data,
	icon = "images/icons_ftf/inventory_sets.tex"
}

for i, slot in ipairs(Equipment.GetOrderedSlots()) do
	local slot_def = itemcatalog.All.SlotDescriptor[slot]
	if not slot_def.tags["no_ui"] then
		local tab = {
			key = slot,
			slots = { slot },
			sort_data = equipment_sort_data,
		}
		table.insert(default_tabs, tab)
	end
end
table.insert(default_tabs, sets_tab)

local gems_tab =
{
	key = EquipmentGem.Slots.GEMS,
	slots = { EquipmentGem.Slots.GEMS },
	sort_data = material_sort_data,
	icon = "images/icons_ftf/inventory_currency_drops.tex",
}
table.insert(default_tabs, gems_tab)

local potions_tab =
{
	key = Equipment.Slots.POTIONS,
	slots = {
		Equipment.Slots.POTIONS,
	},
	sort_data = equipment_sort_data,
}
table.insert(default_tabs, potions_tab)

local tonics_tab =
{
	key = Equipment.Slots.TONICS,
	slots = {
		Equipment.Slots.TONICS,
	},
	sort_data = equipment_sort_data,
}
table.insert(default_tabs, tonics_tab)

local food_tab =
{
	key = Equipment.Slots.FOOD,
	slots = {
		Equipment.Slots.FOOD,
	},
	sort_data = equipment_sort_data,
}
table.insert(default_tabs, food_tab)

local materials_tab =
{
	key = Consumable.Slots.MATERIALS,
	slots = { Consumable.Slots.MATERIALS },
	sort_data = material_sort_data,
}
table.insert(default_tabs, materials_tab)

-- local key_items_tab =
-- {
-- 	key = Consumable.Slots.KEY_ITEMS,
-- 	slots = { Consumable.Slots.KEY_ITEMS },
-- 	sort_data = material_sort_data,
-- }
-- table.insert(default_tabs, key_items_tab)



-- Slot Data
--[[
local example_slot_table =
{
	{ 
		key = "BUFF_ITEMS", -- the ID the slot is known by
		icon = "images/icons_ftf/inventory_buff_items.tex", -- if not defined, take the icon of the first slot in the slots table.
		slots = { Equipment.Slots.POTIONS, Equipment.Slots.TONICS, Equipment.Slots.FOOD }, -- which slots are shown in this tab
		or_filters = { "equipment_buff" }, -- Only show items with any of these tags
		and_filters = { "equipment_buff" }, -- Only show items with all of these tags
		sort_data = equipment_sort_data, -- how the items can be sorted
	}
}
--]]

------------------------------------------------------------------------------------------
--- Displays a panel with a player's inventory
----
local InventoryPanel = Class(InventoryBasePanel, function(self, tabs)
	InventoryBasePanel._ctor(self)

	-- Keeps track of what items the player has chosen (since opening the screen) per slot, but hasn't equipped yet
	self.selectedItems = {
		-- SLOT = itemData, ...
	}

	-- Tabs
	tabs = tabs or default_tabs
	self:SetSlotTabs(tabs)
	self.tabsBg:SetTexture("images/ui_ftf_inventory/TabsBarInventory.tex")


	-- Search
	self.filter_str = {}
	self.filter_text:SetTextPrompt(STRINGS.UI.INVENTORYSCREEN.FILTER)
		:SetFn(function( input )
			if input ~= nil then
				self.filter_str = {}
				for word in string.gmatch(input, '([^,]+)') do
					local str = string.lower(word)
					str = str:gsub("%s+", "")
				    table.insert(self.filter_str, str)
				end
				self:RefreshItemList(self.slot)
			end
		end)


	-- Dropdown
	self.allow_manual_sort = false
	self.sort_stat = "ILVL"
	self.sort_list = {}
	for _, rarity in ipairs(EQUIPMENT_STATS:Ordered()) do
		table.insert(self.sort_list, { name = STRINGS.UI.EQUIPMENT_STATS[rarity].name, data = rarity })
	end
	self.sort_dropdown:SetValues(self.sort_list)
		:SetOnValueChangeFn(function(data, valueIndex, value)
			self.sort_stat = data
			self:RefreshItemList(self.slot)
		end)


	--- ITEM LIST
	self.listWidget = self:AddChild(InventoryItemList(self.width, self.centerHeight))
		:SetVirtualTopMargin(0)
		:SetOnItemClickFn(function(itemData, idx) self:OnItemClicked(itemData, idx) end)
		:SetOnItemAltClickFn(function(itemData, idx) self:OnItemAltClicked(itemData, idx) end)
		:SetOnItemGainFocus(function(itemData, idx) self:OnItemGainFocus(itemData, idx) end)
		:SetOnItemLoseFocus(function(itemData, idx) self:OnItemLoseFocus(itemData, idx) end)
		:HideItemTooltips()

	--- ITEM DETAILS
	self.detailsWidget = self:AddChild(ItemDetails(self.width+8, self.footerHeight))

	self:Layout()
end)

function InventoryPanel:SetDefaultFocus()
	return self.listWidget:SetDefaultFocus()
end

function InventoryPanel:SetExternalFilterFn(fn)
	self.external_filter_fn = fn
	return self
end

function InventoryPanel:UpdateEquippedStatus(slot, item)
	self.listWidget:UpdateEquippedBadge(slot, item)
	self:_ShowItemDetails(item)
end

function InventoryPanel:Refresh(player)
	InventoryPanel._base.Refresh(self, player)

	-- Set player on the details panel, so it can find what the equipped items are
	self.detailsWidget:SetPlayer(self.player)

	-- Set player on the list, so it can find what the equipped items are
	self.listWidget:SetPlayer(self.player)

	-- Select default equipment category & preset
	self:OnPresetSelected(self.player.components.inventoryhoard.data.selectedLoadoutIndex)

	if self.allow_manual_sort then
		self.sort_dropdown:OnValueClick(#self.sort_list)
	end

	self.inst:ListenForEvent("inventory_stackable_changed", function() self:RefreshItemList(self.slot) end, player)

	self:Layout()
	return self
end

-- Should be called when a new loadout preset is chosen by the player
function InventoryPanel:OnPresetSelected(index)
	-- Remember current loadout
	self.selectedLoadoutIndex = index

	-- Re-select the first item tab again, refreshing the list
	self:ClickTab(self.player.components.inventoryhoard:GetLastViewedSlot())
end

-- The screen notified this that the category was changed elsewhere
function InventoryPanel:SetCurrentCategory(slot_data)
	self.player.components.inventoryhoard:SetLastViewedSlot(slot_data)
	self:SelectTab(slot_data.key)
	self:RefreshItemList(slot_data)
	return self
end

function InventoryPanel:RefreshSortDropdown(new_slot)
	if not self.slot or self.slot ~= new_slot then
		if not self.slot or new_slot.sort_data ~= self.slot.sort_data then
			local new_data = new_slot.sort_data

			self.slot = new_slot

			if self.allow_manual_sort then
				self.sort_list = new_data.data
				self.sort_stat = new_data.default
				self.sort_dropdown:SetValues(self.sort_list)
				self.sort_dropdown:OnValueClick(#self.sort_list)
			end
		end
	end
end

-- Updates the item list and selects its first item
function InventoryPanel:RefreshItemList(slot)
	self:RefreshSortDropdown(slot)
	self.slot = slot
	local inventory = self.player.components.inventoryhoard.data.inventory

	local rawList = {}

	for i, slot_id in ipairs(slot.slots) do
		rawList = lume.concat(rawList, inventory[slot_id])
	end

	if rawList == nil then
		rawList = {}
	end

	-- Consumables are dictionaries and equipment are lists
	-- Let's organize that into a plain list
	self.itemsList = {}
	local j = 1
	for _, item in iterator.sorted_pairs(rawList) do
		table.insert(self.itemsList, item)
		j = j + 1
	end

	if slot.or_filters then
		self.itemsList = lume.filter(self.itemsList, function(item)
			for _, tag in ipairs(slot.or_filters) do
				if item:HasTag(tag) then
					return true
				end
			end
			return false
		end)
	end

	if slot.and_filters then
		self.itemsList = lume.filter(self.itemsList, function(item)
			for _, tag in ipairs(slot.and_filters) do
				if not item:HasTag(tag) then
					return false
				end
			end
			return true
		end)
	end

	if #self.filter_str > 0 then
		for i = #self.itemsList, 1, -1 do
			local should_keep = true
			for _, word in ipairs(self.filter_str) do
				if not should_keep then break end

				if word == "" or word == nil then break end

				local item = self.itemsList[i]
				local def = item:GetDef()

				local name = item:GetLocalizedName()
				-- local desc = item:GetLocalizedDescription()
				local rarity = STRINGS.ITEMS.RARITY[def.rarity]

				local to_test = { name, rarity }

				if item.stats then
					for stat, val in pairs(item.stats) do
						if STRINGS.UI.EQUIPMENT_STATS[stat] and val ~= 0 then
							table.insert(to_test, STRINGS.UI.EQUIPMENT_STATS[stat].name)
						end
					end
				end

				if def.tags then
					for tag, _ in pairs(def.tags) do
						table.insert(to_test, tag)
					end
				end

				local any_match = false
				for _, str in ipairs(to_test) do
					if string.lower(str):match(word) then
						any_match = true
						break
					end
				end
				should_keep = any_match
			end

			if not should_keep then
				table.remove(self.itemsList, i)
			end
		end
	end

	if self.external_filter_fn then
		self.itemsList = self.external_filter_fn(self.itemsList)
	end

	if lume.find(slot.slots, Consumable.Slots.MATERIALS) or lume.find(slot.slots, Consumable.Slots.KEY_ITEMS) then
		-- self.itemsList = lume.filter(self.itemsList, function(item) return not item:HasTag("currency")  end)
		if self.sort_stat == "SOURCE" then
			table.sort(self.itemsList, function(a, b)
				return itemforge.SortItemsBySource(a, b)
			end)
		elseif self.sort_stat == EQUIPMENT_STATS.s.RARITY then
			table.sort(self.itemsList, function(a, b)
				return Consumable.CompareDef_ByRarityAndName(a:GetDef(), b:GetDef())
			end)
		end
	elseif lume.find(slot.slots, EquipmentGem.Slots.GEMS) then
		-- do nothing
	else
		if self.sort_stat == "ILVL" then
			table.sort(self.itemsList, function(a,b)
				return itemforge.SortItemsByILvl(a, b)
			end)

		elseif self.sort_stat == EQUIPMENT_STATS.s.RARITY then
			table.sort(self.itemsList, function(a, b)
				return Equipment.CompareDef_ByRarityAndName(a:GetDef(), b:GetDef())
			end)
		else
			table.sort(self.itemsList, function(a, b)
				return itemforge.SortItemsByStat(self.sort_stat, a, b)
			end)
		end
	end

	-- Refresh the list
	self.listWidget:SetSlot(slot, self.itemsList)

	-- Auto-select first item
	if #self.itemsList > 0 then
		-- Auto-select an item
		-- Check if the player had selected one already (since opening the screen) while clicking through the list

		local selectedItems = {}
		local equippedItems = {}

		for _, slot_id in ipairs(slot.slots) do
			local selectedItemData, selectedItemIndex = self:_GetSelectedItem(slot_id)
			if selectedItemData then
				selectedItems[selectedItemData] = selectedItemIndex
			end

			local equippedItemData, equippedItemIndex = self:_GetEquippedItem(slot_id)
			if equippedItemData then
				equippedItems[equippedItemData] = equippedItemIndex
			end
		end

		-- And if the player has one equipped already too

		if table.count(selectedItems) > 0 then
			for item, idx in pairs(selectedItems) do
				-- Re-select the item the player had selected previously (since opening the screen)
				self:_SelectItem(item, idx)
			end

		elseif table.count(equippedItems) > 0 then
			for item, idx in pairs(equippedItems) do
				-- Re-select the item equipped to this slot
				self:_SelectItem(item, idx)
			end
		else
			-- Select the first item on the list
			self:_SelectItem(self.itemsList[1], 1)
		end

	else
		self:_SelectItem(nil)
	end

	return self
end

-- If the player had clicked an item while looking through the list, return that
function InventoryPanel:_GetSelectedItem(slot)

	-- Check if there's a selected item saved
	local selectedItemData = nil
	if self.selectedItems[slot] then
		selectedItemData = self.selectedItems[slot]
	end

	-- If so, find its index too
	local selectedItemIndex = 0
	if selectedItemData then
		for idx, item in ipairs(self.itemsList) do
			if item == selectedItemData then
				selectedItemIndex = idx
			end
		end
	end

	if selectedItemIndex ~= 0 then
		return selectedItemData, selectedItemIndex
	else
		return nil
	end
end

-- If the player has an equipped item on this slot, return that
function InventoryPanel:_GetEquippedItem(slot)

	-- Check if there's a selected item saved
	local selectedLoadoutIndex = self.player.components.inventoryhoard.data.selectedLoadoutIndex
	local equippedItemData = self.player.components.inventoryhoard:GetLoadoutItem(selectedLoadoutIndex, slot)

	-- If so, find its index too
	local equippedItemIndex = 0
	for idx, item in ipairs(self.itemsList) do
		if item == equippedItemData then
			equippedItemIndex = idx
		end
	end

	if equippedItemIndex ~= 0 then
		return equippedItemData, equippedItemIndex
	else
		return nil
	end
end

function InventoryPanel:SetOnItemClickFn(fn)
	self.onItemClickFn = fn
	return self
end

function InventoryPanel:SetOnItemGainFocusFn(fn)
	self.onItemGainFocusFn = fn
	return self
end

function InventoryPanel:SetOnItemLoseFocusFn(fn)
	self.onItemLoseFocusFn = fn
	return self
end

function InventoryPanel:SetOnItemAltClickFn(fn)
	self.onItemAltClickFn = fn
	return self
end

-- Internal selection that does not imply user interaction.
function InventoryPanel:_SelectItem(itemData, idx)
	-- itemData and idx may be nil for empty list.
	local slot = nil
	if itemData ~= nil then

		self.itemData = itemData
		self.itemIdx = idx

		-- Set the item as selected on the list too
		slot = itemData.slot
		self.listWidget:SelectIndex(idx)
	end

	-- Update the item details with the selected item
	self:_ShowItemDetails(self.itemData, self.itemIdx)

	-- Save this selection
	if slot then
		self.selectedItems[slot] = itemData
	end
end

function InventoryPanel:OnItemClicked(itemData, idx)
	self:_SelectItem(itemData, idx)
	if self.onItemClickFn then self.onItemClickFn(itemData, idx) end
	return self
end

function InventoryPanel:OnItemAltClicked(itemData, idx)
	if self.onItemAltClickFn then self.onItemAltClickFn(itemData, idx) end
end

function InventoryPanel:OnItemGainFocus(itemData, idx)
	self:_ShowItemDetails(itemData, idx)
	if self.onItemGainFocusFn then self.onItemGainFocusFn(itemData, idx) end
end

function InventoryPanel:OnItemLoseFocus(itemData, idx)
	self:_ShowItemDetails(self.itemData, self.itemIdx)
	if self.onItemLoseFocusFn then self.onItemLoseFocusFn(self.itemData, self.itemIdx) end
end

function InventoryPanel:_ShowItemDetails(itemData, idx)
	-- Update the item details with the selected item
	self.detailsWidget:SetItem(itemData.slot, itemData)
end

function InventoryPanel:Layout()
	InventoryPanel._base.Layout(self)

	if self.listWidget then
		self.listWidget:SetSize(self.width, self.centerHeight)
			:LayoutBounds("right", nil, self.header)
			:LayoutBounds(nil, self.subheader:IsShown() and "below" or "top", self.subheader)
			:Offset(0, -self.subheaderSpacing - 25 * HACK_FOR_4K)
		self.detailsWidget:LayoutBounds("left", "bottom", self.bg)
			:Offset(0, 0)
	end

	return self
end

return InventoryPanel
