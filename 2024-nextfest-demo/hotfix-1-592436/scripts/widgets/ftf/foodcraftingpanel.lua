local CraftingPanel = require "widgets.ftf.craftingpanel"
local recipes = require "defs.recipes"
local lume = require "util.lume"
local Consumable = require "defs.consumable"

local FoodCraftingPanel = Class(CraftingPanel, function(self, player, equipment_slots, npc)
	CraftingPanel._ctor(self, player, equipment_slots, npc)
end)

function FoodCraftingPanel:RefreshItemList(slot, filters)

	self.slot = slot
	local itemsToShow = {}
	local towncalendar = TheDungeon.progression.components.towncalendar

	local dailyMenu = self.npc.components.dailymenu
	if dailyMenu ~= nil and dailyMenu:GetDay() == towncalendar:GetDay() then
		itemsToShow = dailyMenu:GetMenuItems()
	else
		local itemsList = shallowcopy(recipes.ForSlot[slot])

		local filteredItems = {}

		for id, itemData in pairs(itemsList) do
			if itemData.def.tags["default_unlocked"] or itemData.def.tags["starting_equipment"] then
				filteredItems[id] = itemData
			elseif self.player.components.unlocktracker:IsRecipeUnlocked(itemData.def.name) then
				filteredItems[id] = itemData
			end
		end

		local ids = lume.keys(filteredItems)

		for i=1, 3 do
			local index = math.random(1, #ids)
			local id =  ids[index]
			table.remove(ids, index)
			table.insert(itemsToShow, { id = id, itemData = filteredItems[id] })
		end

		dailyMenu:SetMenu(itemsToShow, towncalendar:GetDay())
	end

	if filters ~= nil and #filters > 0 then
		for i = #itemsToShow, 1, -1 do
			local data = itemsToShow[i]
			for _, tag in ipairs(filters) do
				if not data.itemData.def.tags[tag] then
					table.remove(itemsToShow, i)
					break
				end
			end
		end
	end

	local selectedLoadoutIndex = self.player.components.inventoryhoard.data.selectedLoadoutIndex
	local currentlyEquipped = self.player.components.inventoryhoard:GetLoadoutItem(selectedLoadoutIndex, slot)

	-- Refresh the list
	self.recipeList:SetSlot(slot, itemsToShow, currentlyEquipped)

	self.recipeList:SelectEquippedOrFirst()
	self:Layout()

	return self
end

return FoodCraftingPanel
