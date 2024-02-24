local Image = require "widgets.image"
local Panel = require("widgets/panel")
local ScrollPanel = require("widgets/scrollpanel")
local Widget = require("widgets/widget")
local easing = require "util.easing"
local itemcatalog = require "defs.itemcatalog"
local itemforge = require "defs.itemforge"
local lume = require "util.lume"
local recipes = require "defs.recipes"

local CraftableItemSlot = require"widgets.ftf.craftableitemslot"

local Consumable = require "defs.consumable"

------------------------------------------------------------------------------------------
--- A list of items that shows above the craft bar when a category is selected
local CraftableItemsList = Class(Widget, function(self)
	Widget._ctor(self, "CraftableItemsList")

	self.width = 500
	self.height = 240
	self.scrollPaddingX = 20 -- left spacing, so items can scale up without being clipped by the scroll panel

	self.background = self:AddChild(Panel("images/ui_ftf_crafting/craft_list_bg.tex"))
		:SetNineSliceCoords(290, 150, 300, 160)
		:SetNineSliceBorderScale(0.5)
		:SetSize(self.width, self.height)

	self.scroll = self:AddChild(ScrollPanel())
		:SetSize(self.width - 24 * HACK_FOR_4K, self.height - 8 * HACK_FOR_4K)
        :SetVirtualMargin(20)
        :SetScrollBarMargin(0)
        :SetScrollBarVerticalOffset(8)
		:LayoutBounds("left", "top", self.background)
		:Offset(3, -3)
	self.contents = self.scroll:AddScrollChild(Widget())

	self.inst:ListenForEvent("OnPlayerCrafterItemUnlocked", function() self:OnPlayerCrafterItemUnlocked() end, ThePlayer)
	self.inst:ListenForEvent("OnPlayerCrafterItemFavourited", function() self:OnPlayerCrafterItemFavourited() end, ThePlayer)

	self:ApplySkin()
		:LayoutSkin()

end)

-- So we can animate and return to the correct spot later
function CraftableItemsList:MemorizePosition()
	self.originalPositionX, self.originalPositionY = self:GetPosition()
	return self
end

function CraftableItemsList:SetCategory(categoryData)
	self.categoryData = categoryData
	self:_RefreshCurrentCategory()
	return self
end

function CraftableItemsList:_RefreshCurrentCategory()
	-- Remove old items
	self.contents:RemoveAllChildren()

	-- Get what items are unlocked
	local unlockedIds = ThePlayer.components.playercrafter:GetUnlockedItems()

	-- Get what items are favourites
	local favouriteIds = ThePlayer.components.playercrafter:GetFavourites()

	-- Get what items are unseen
	local unseenIds = ThePlayer.components.playercrafter:GetUnseenItems()

	-- Get item data for this category
	local itemDataList = itemcatalog.All.Items[self.categoryData.slot]


	-- If the category is favourites, get that list instead
	if self.categoryData.is_favourites then
		-- Get all craftable items
		local craftables = itemforge.GetAllCraftableItems()
		-- Reset list
		itemDataList = {}
		-- And keep only the favourites
		for itemId, itemData in pairs(craftables) do
			if favouriteIds[itemId] then
				itemDataList[itemId] = itemData
			end
		end
	end

	-- Keep only the unlocked ones
	local unlockedItems = {}
	for itemId, itemData in pairs(itemDataList) do
		if unlockedIds[itemId] then unlockedItems[itemId] = itemData end
	end
	itemDataList = unlockedItems

	local sorted_defs = lume.values(itemDataList)
	table.sort(sorted_defs, function(a,b)
		if a.category ~= b.category then
			return a.category < b.category
		end
		return a.pretty.name < b.pretty.name
	end)

	-- Add items to list
	for _, item_def in ipairs(sorted_defs) do
		local recipe = recipes.ForSlot[item_def.slot][item_def.name]
		if recipe then
			local itemData = itemforge.CreateCraftable(item_def)
			-- Create item slot

			local is_available = recipe:CanPlayerCraft(ThePlayer) or ThePlayer.components.inventoryhoard:GetStackableCount(Consumable.FindItem(item_def.name)) > 0

			local itemSlot = self.contents:AddChild(CraftableItemSlot(90))
				:SetItem(itemData, ThePlayer)
				:SetFavourite(favouriteIds[item_def.name])
				:SetUnseen(unseenIds[item_def.name])
				:SetAvailable(is_available)
			-- Add event listeners
			itemSlot:SetOnClick(function()
					self:OnItemSelectedButton(item_def.name, itemSlot, itemData)
				end)
				:SetOnClickAlt(function()
					self:OnItemSelectedAltButton(item_def.name, itemSlot, itemData)
				end)
				:SetOnClickFavourite(function()
					self:OnItemFavouriteButton(item_def.name, itemSlot, itemData)
				end)
				:SetOnGainFocus(function()
					if self.onItemFocusedFn then self.onItemFocusedFn(item_def.name, itemSlot, itemData) end
				end)
				:SetOnLoseFocus(function()
					if self.onItemFocusedFn then self.onItemUnfocusedFn() end
				end)
		end
	end

	-- Save list
	self.itemDataList = itemDataList

	-- Layout list
	local w, h = self.scroll:GetSize()
	self.contents:LayoutChildrenInGrid(4, 20)
		:LayoutBounds("left", "top", 0, 0)
		:Offset(-w / 2 + self.scrollPaddingX, 0)
	self.scroll:RefreshView()

	return self
end

function CraftableItemsList:OpenList()
	if not self.isListOpen then
		self.isListOpen = true
		self:Show()
			:SetMultColorAlpha(0)
			:SetPosition(self.originalPositionX, self.originalPositionY - 30)
			:AlphaTo(1, 0.1, easing.inOutQuad)
			:MoveTo(self.originalPositionX, self.originalPositionY, 0.1, easing.inQuad)
		if self.GetSkinOpenUpdater then self:RunUpdater(self:GetSkinOpenUpdater()) end
	end
end

function CraftableItemsList:CloseList(onDoneFn)
	if self.isListOpen then
		self.isListOpen = false
		self:AlphaTo(0, 0.1, easing.inOutQuad, function() self:Hide() end)
			:MoveTo(self.originalPositionX, self.originalPositionY - 30, 0.1, easing.inQuad, function() if onDoneFn then onDoneFn() end end)
		self:_MarkAllAsSeen()
	end
end

function CraftableItemsList:IsListOpen()
	return self.isListOpen
end

--- Marks every item as seen
function CraftableItemsList:_MarkAllAsSeen()
	for itemId, itemData in pairs(self.itemDataList) do
		ThePlayer.components.playercrafter:SetSeen(itemId)
	end
	return self
end

function CraftableItemsList:SetOnItemFocusedFn(fn)
	self.onItemFocusedFn = fn
	return self
end

function CraftableItemsList:SetOnItemUnfocusedFn(fn)
	self.onItemUnfocusedFn = fn
	return self
end

function CraftableItemsList:SetOnItemSelectedFn(fn)
	self.onItemSelectedFn = fn
	return self
end

function CraftableItemsList:SetOnItemSelectedAltFn(fn)
	self.onItemSelectedAltFn = fn
	return self
end

function CraftableItemsList:OnItemSelectedButton(itemId, itemSlot, itemData)
	if self.onItemSelectedFn then self.onItemSelectedFn(itemId, itemSlot, itemData) end
end

function CraftableItemsList:OnItemSelectedAltButton(itemId, itemSlot, itemData)
	if self.onItemSelectedAltFn then self.onItemSelectedAltFn(itemId, itemSlot, itemData) end
end

function CraftableItemsList:OnItemFavouriteButton(itemId, itemSlot, itemData)
	ThePlayer.components.playercrafter:ToggleFavourite(itemId)
end

--- Event functions

function CraftableItemsList:OnPlayerCrafterItemUnlocked()
	if self:IsListOpen() then
		-- Refresh contents
		self:_RefreshCurrentCategory()
	end
end

function CraftableItemsList:OnPlayerCrafterItemFavourited()
	if self:IsListOpen() then
		-- Refresh contents
		self:_RefreshCurrentCategory()
	end
end


---
-- Instantiates all the skin texture elements to this screen.
-- Call this at the start
--
function CraftableItemsList:ApplySkin()

	self.skinDirectory = "images/ui_ftf_skin/" -- Defines what skin to use

	-- Add chain edges to the bg panel
	self.skinEdge = self:AddChild(Image(self.skinDirectory .. "buildpanel_frame.tex"))
		:SetHiddenBoundingBox(true)

	-- Add top left corner decorations
	self.skinLeavesTop = self:AddChild(Image(self.skinDirectory .. "buildpanel_leaves_top.tex"))
		:SetHiddenBoundingBox(true)
	self.skinLeavesLeft = self:AddChild(Image(self.skinDirectory .. "buildpanel_leaves_left.tex"))
		:SetHiddenBoundingBox(true)
	self.skinBadge = self:AddChild(Image(self.skinDirectory .. "buildpanel_badge.tex"))
		:SetHiddenBoundingBox(true)

	return self
end

function CraftableItemsList:GetSkinOpenUpdater()
	return Updater.Series({
		Updater.Wait(0.1),
		Updater.Parallel({
			Updater.Ease(function(v) self.skinLeavesTop:SetRotation(v) end, 0, -4, 0.1, easing.outQuad),
			Updater.Ease(function(v) self.skinLeavesLeft:SetRotation(v) end, 0, 4, 0.1, easing.outQuad),
			Updater.Ease(function(v) self.skinBadge:SetScale(v,v) end, 1, 1.1, 0.1, easing.inOutQuad),

			Updater.Series({
				Updater.Wait(0.1),
				Updater.Parallel({
					Updater.Ease(function(v) self.skinLeavesTop:SetRotation(v) end, -4, 0, 0.2, easing.outQuad),
					Updater.Ease(function(v) self.skinLeavesLeft:SetRotation(v) end, 4, 0, 0.2, easing.outQuad),
					Updater.Ease(function(v) self.skinBadge:SetScale(v,v) end, 1.1, 1, 0.2, easing.inOutQuad),
				}),
			}),
		}),
	})
end

---
-- Lays out all the skin texture elements to this screen
-- Call this when the size/layout changes
--
function CraftableItemsList:LayoutSkin()

	self.skinEdge:SetSize(self.width * 1.28, self.height * 1.28)
		:LayoutBounds("center", "center", self.background)
		:Offset(-2, 1)
	self.skinLeavesTop:LayoutBounds("left", "above", self.background)
		:Offset(-136, -7)
	self.skinLeavesLeft:LayoutBounds("before", "top", self.background)
		:Offset(20, 134)
	self.skinBadge:LayoutBounds("before", "above", self.background)
		:Offset(30, -30)

	return self
end

return CraftableItemsList
