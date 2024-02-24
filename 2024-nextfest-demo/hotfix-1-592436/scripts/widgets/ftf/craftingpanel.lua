local InventoryBasePanel = require "widgets.ftf.inventorybasepanel"
local ItemDetails = require "widgets.ftf.itemdetails"
local RecipeList = require"widgets.ftf.recipelist"

local Equipment = require "defs.equipment"
local Consumable = require "defs.consumable"
local recipes = require "defs.recipes"
local itemforge = require "defs.itemforge"
local lume = require "util.lume"
local easing = require "util.easing"

local CraftingPanel = Class(InventoryBasePanel, function(self, player, equipment_slots, npc)
	InventoryBasePanel._ctor(self, nil, 640)

	self.player = player
	self.equipment_slots = equipment_slots
	self.npc = npc

	-- Add slot tabs
	local tabs = {}
	for _, data in ipairs(self.equipment_slots) do
		table.insert(tabs, {
			key = data.slot,
			slots = { data.slot },
			sort_data = data.filters,
		})
	end
	self:SetSlotTabs(tabs)

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
				self:RefreshItemList(self.slot_key)
			end
		end)

	-- Dropdown
	self.sort_stat = nil
	self.sort_list = {}
	table.insert(self.sort_list, { name = STRINGS.UI.CRAFTING.CAN_CRAFT, data = "can_craft" })
	for _, rarity in ipairs(EQUIPMENT_STATS:Ordered()) do
		table.insert(self.sort_list, { name = STRINGS.UI.EQUIPMENT_STATS[rarity].name, data = rarity })
	end
	self.sort_dropdown:SetValues(self.sort_list)
		:SetOnValueChangeFn(function(data, valueIndex, value)
			self.sort_stat = data
			self:RefreshItemList(self.slot_key)
		end)

	-- Recipe list
	self.recipeList = self:AddChild(RecipeList(self.player, self.width-60, self.centerHeight))
		:SetOnRecipeClickedFn(function(recipeData) self:OnListItemClicked(recipeData) end)
		:SetOnRecipeGainFocusFn(function(recipeData) self:OnListItemGainFocus(recipeData) end)
		:SetOnRecipeLoseFocusFn(function(recipeData) self:OnListItemLoseFocus(recipeData) end)

	-- Listen for inventory changes
	self.inst:ListenForEvent("inventory_stackable_changed", function(owner, itemDef)

		-- Refresh the contents, since the player might not have enough konjur/materials
		self.recipeList:OnInventoryChanged()
		-- self.recipeDetails:OnInventoryChanged()
	end, self.player)

	self.inst:ListenForEvent("loadout_changed", function(owner, itemDef)

		-- Refresh the contents, since the player might not have enough konjur/materials
		self.recipeList:OnInventoryChanged()
		-- self.recipeDetails:OnInventoryChanged()

	end, self.player)

	--- ITEM DETAILS
	self.detailsWidget = self:AddChild(ItemDetails(self.width+8, self.footerHeight))

	self:Layout()

	self.animatedIn = false

	-- Use SetDefaultFocus instead of default_focus.
	self.default_focus = nil
end)

function CraftingPanel:SetDefaultFocus()
	return self.recipeList:SetDefaultFocus()
end

-- The screen notified this that the category was changed elsewhere
function CraftingPanel:SetCurrentCategory(slot_key)
	self:SelectTab(slot_key)
	self:OnChangeEquipmentSlot(slot_key)
	return self
end

function CraftingPanel:SetMannequinPanel(widget)
	self.mannequinPanel = widget
	return self
end

function CraftingPanel:SetOnCloseFn(fn)
	self.closeButton:SetOnClick(fn)
	return self
end

function CraftingPanel:SetDefaultFocus()
	self.recipeList:SetDefaultFocus()
	return true
end

function CraftingPanel:NextTab(direction)
	if self.item_category_root:IsVisible() then
		self.item_category_root:NextTab(direction)
	end
end

function CraftingPanel:RefreshItemList(slot_key)
	self.slot_key = slot_key
	local itemsList = shallowcopy(recipes.ForSlot[self.slot_key])

	local unlocks = self.player.components.unlocktracker

	local itemsToShow = {}
	for id, itemData in pairs(itemsList) do
		if itemData.def.tags["default_unlocked"] or itemData.def.tags["starting_equipment"] then
			table.insert(itemsToShow, { id = id, itemData = itemData })
		elseif unlocks:IsRecipeUnlocked(itemData.def.name) then

			-- only show a recipe if we have discovered the recipe through meta progression
			if self.slot_key == "WEAPON" then
				if unlocks:IsWeaponTypeUnlocked(itemData.def.weapon_type)  then
					table.insert(itemsToShow, { id = id, itemData = itemData })
				end
			else
				table.insert(itemsToShow, { id = id, itemData = itemData })
			end
		end
	end

	-- if filters ~= nil and #filters > 0 then
	-- 	for i = #itemsToShow, 1, -1 do
	-- 		local data = itemsToShow[i]
	-- 		for _, tag in ipairs(filters) do
	-- 			if not data.itemData.def.tags[tag] then
	-- 				table.remove(itemsToShow, i)
	-- 				break
	-- 			end
	-- 		end
	-- 	end
	-- end

	if #self.filter_str > 0 then
		for i = #itemsToShow, 1, -1 do
			local data = itemsToShow[i]
			local def = data.itemData.def

			local should_keep = true
			for _, word in ipairs(self.filter_str) do

				if not should_keep then break end

				if word == "" or word == nil then break end

				local name = def.pretty.name
				local rarity = STRINGS.ITEMS.RARITY[def.rarity]

				local to_test = { name, rarity }

				if def.tags then
					for tag, _ in pairs(def.tags) do
						table.insert(to_test, tag)
					end
				end

				if data.ingredients then
					for ingredient, _ in (data.ingredients) do
						table.insert(to_test, ingredient)
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
				table.remove(itemsToShow, i)
			end
		end
	end

	if self.slot_key == Consumable.Slots.MATERIALS then
		-- TODO @H: review this since craftables no longer use glitz
		itemsToShow = lume.sort(itemsToShow, function( a, b ) return a.itemData.ingredients.glitz < b.itemData.ingredients.glitz end)
	else
		if self.sort_stat == "can_craft" then
			table.sort(itemsToShow, function(a, b)
				local a_craft = a.itemData:CanPlayerCraft(self.player)
				local b_craft = b.itemData:CanPlayerCraft(self.player)

				if a_craft == b_craft then
					return Equipment.CompareDef_ByRarityAndName(a.itemData.def, b.itemData.def)
				end

				return a_craft and not b_craft
			end)
		elseif self.sort_stat == EQUIPMENT_STATS.s.RARITY then
			table.sort(itemsToShow, function(a, b)
				return Equipment.CompareDef_ByRarityAndName(a.itemData.def, b.itemData.def)
			end)
		else
			table.sort(itemsToShow, function(a, b)
				local item_a = itemforge.CreateEquipment(a.itemData.slot, a.itemData.def)
				local item_b = itemforge.CreateEquipment(b.itemData.slot, b.itemData.def)
				return itemforge.SortItemsByStat(self.sort_stat, item_a, item_b)
			end)
		end
	end

	local selectedLoadoutIndex = self.player.components.inventoryhoard.data.selectedLoadoutIndex
	local currentlyEquipped = self.player.components.inventoryhoard:GetLoadoutItem(selectedLoadoutIndex, self.slot_key)

	-- Refresh the list
	self.recipeList:SetSlot(self.slot_key, itemsToShow, currentlyEquipped)

	self.recipeList:SelectEquippedOrFirst()
	self:Layout()

	return self
end

function CraftingPanel:OnFinishAnimate()
	self.animatedIn = true
	self.recipeList:SelectEquippedOrFirst()
end

function CraftingPanel:OnChangeEquipmentSlot(slot_key)
	self.slot_key = slot_key
	if not self.sort_stat then
		self.sort_dropdown:OnValueClick(#self.sort_list)
	else
		self:RefreshItemList(self.slot_key)
	end
end

function CraftingPanel:OnListItemClicked(recipeData)
	self.recipeData = recipeData
	self:_ShowRecipeDetails(self.recipeData)
end

function CraftingPanel:OnListItemGainFocus(recipeData)
	self:_ShowRecipeDetails(recipeData)
end

function CraftingPanel:OnListItemLoseFocus(recipeData)
	self:_ShowRecipeDetails(self.recipeData)
end

function CraftingPanel:_ShowRecipeDetails(recipeData)

	-- Display the recipe's info on the bottom panel
	local dummy_item = itemforge.CreateEquipment(recipeData.slot, recipeData.def)
	-- Check if the player owns this
	local items = self.player.components.inventoryhoard.data.inventory[recipeData.def.slot]
	local owned = false
	for _, item in ipairs(items) do
		if item.id == recipeData.def.name then
			owned = true
			break
		end
	end
	self.detailsWidget:ShowOnlyDescription(dummy_item:GetLocalizedDescription(), owned)

	-- Notify that selected recipe changed
	if self.onRecipeSelectedFn then self.onRecipeSelectedFn(recipeData) end

end

function CraftingPanel:SetOnRecipeSelectedFn(fn)
	self.onRecipeSelectedFn = fn
	return self
end

function CraftingPanel:Layout()
	CraftingPanel._base.Layout(self)

	if self.recipeList then
		self.recipeList:SetSize(self.width - 30 * HACK_FOR_4K, self.centerHeight)
			:LayoutBounds("left", self.subheader:IsShown() and "below" or "top", self.subheader)
			:Offset(15, -self.subheaderSpacing - 25)
		self.detailsWidget:LayoutBounds("left", "bottom", self.bg)
			:Offset(0, 0)
	end

	return self
end

return CraftingPanel
