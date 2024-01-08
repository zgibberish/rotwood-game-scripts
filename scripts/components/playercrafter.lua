local itemcatalog = require "defs.itemcatalog"
local Consumable = require"defs.consumable"

local function create_default_data()
	local data = {
		unlockedItems = {}, -- Items that you can craft for your village
		-- 	armorer = true,
		-- 	forge = true,
		-- 	scout_tent = true,
		-- },
		unseenItems = {}, -- Items you can craft but have not seen in the crafting menu yet (marked as new!)
		favouriteItems = {}, -- Items that the player as marked as favorite, and will show up in the favorites tab in the crafting menu
	}
	return data
end

-- Keeps track of what craftable items the player can make, which ones are new,
-- and which ones are favourites.
-- ONLY used for village buildings like DECOR and FURNISHINGS, not used for armour & weapons.

local PlayerCrafter = Class(function(self, inst)
	self.data = create_default_data()
	self.inst = inst
	-- Unlock everything for now until we have a reason to lock.
	-- self:UnlockAll()


	self.inst:ListenForEvent("inventory_changed", function(_, data) self:OnInventoryChanged(data) end)
end)

function PlayerCrafter:OnInventoryChanged(data)
	local def = data.item and data.item:GetDef()
	if def then
		self:UnlockRecipesFromDef(def)
	end
end



function PlayerCrafter:UnlockAll()
	local oldunseenItems = table.numkeys(self.data.unseenItems)

	for _, group in pairs(itemcatalog.All.Items) do
		for k, v in pairs(group) do
			if v.tags.playercraftable then
				if self.data.unlockedItems[k] ~= true then
					self.data.unseenItems[k] = true
				end
				self.data.unlockedItems[k] = true
			end
		end
	end

	self.inst:PushEvent("OnPlayerCrafterChanged")
	self.inst:PushEvent("OnPlayerCrafterItemUnlocked")

	if table.numkeys(self.data.unseenItems) ~= oldunseenItems then
		self.inst:PushEvent("OnPlayerCrafterUnseenItem")
	end
end

function PlayerCrafter:UnlockItem(itemId, markAsNew)
	self.data.unlockedItems[itemId] = true

	self.inst.components.unlocktracker:UnlockRecipe(itemId)
	self.inst:PushEvent("OnPlayerCrafterChanged")
	self.inst:PushEvent("OnPlayerCrafterItemUnlocked")

	if markAsNew then
		self.data.unseenItems[itemId] = true
		self.inst:PushEvent("OnPlayerCrafterUnseenItem")
	end
end

function PlayerCrafter:UnlockRecipesFromDef(def)
	if def.recipes then
		for _, recipe in ipairs(def.recipes) do
			self:UnlockItem(recipe.name, true)
		end
	end
end

function PlayerCrafter:IsUnlocked(itemId)
	return self.data.unlockedItems[itemId]
end

--- Format: {
-- chair1 = true,
-- dummy_bandicoot = true,
--}
function PlayerCrafter:GetUnlockedItems()
	return self.data.unlockedItems
end

function PlayerCrafter:GetFavourites()
	return self.data.favouriteItems
end

function PlayerCrafter:SetFavourite(itemId, isFavourite)
	if isFavourite then
		self.data.favouriteItems[itemId] = isFavourite
	else
		self.data.favouriteItems[itemId] = nil
	end
	self.inst:PushEvent("OnPlayerCrafterChanged")
	self.inst:PushEvent("OnPlayerCrafterItemFavourited")
end

function PlayerCrafter:ToggleFavourite(itemId)
	if self.data.favouriteItems[itemId] then
		self.data.favouriteItems[itemId] = nil
	else
		self.data.favouriteItems[itemId] = true
	end
	self.inst:PushEvent("OnPlayerCrafterChanged")
	self.inst:PushEvent("OnPlayerCrafterItemFavourited")
end

function PlayerCrafter:GetUnseenItems()
	return self.data.unseenItems
end

-- Returns item ids for items that are unlocked and are unseen in this category
function PlayerCrafter:GetUnseenUnlockedCategoryItems(slot)
	local finalItemsList = {}

	-- Get item data for this category
	local itemDataList = itemcatalog.All.Items[slot]

	-- Keep only the unlocked && unseen ones
	for itemId, itemData in pairs(itemDataList) do
		if self.data.unlockedItems[itemId] and self.data.unseenItems[itemId] then
			finalItemsList[itemId] = itemData
		end
	end

	return finalItemsList
end

function PlayerCrafter:SetSeen(itemId)
	self.data.unseenItems[itemId] = nil
	self.inst:PushEvent("OnPlayerCrafterUnseenItem")
end

function PlayerCrafter:OnSave()
	return self.data
end

function PlayerCrafter:OnLoad(data)
	if data ~= nil then
		self.data = data
	else
		self.data = create_default_data()
	end
end

function PlayerCrafter:ResetData()
	self.data = create_default_data()
	self.inst:PushEvent("OnPlayerCrafterChanged")
	self.inst:PushEvent("OnPlayerCrafterItemUnlocked")
	self.inst:PushEvent("OnPlayerCrafterUnseenItem")
end

return PlayerCrafter
