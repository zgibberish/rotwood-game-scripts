local Constructable = require "defs.constructable"
local Image = require "widgets.image"
local Panel = require("widgets/panel")
local TabGroup = require "widgets.tabgroup"
local TextEdit = require("widgets/textedit")
local Widget = require("widgets/widget")
local itemcatalog = require "defs.itemcatalog"
local lume = require "util.lume"

local INDEX_OF_FAV_BTN = 1

------------------------------------------------------------------------------------------
--- The bar that pops in when clicking the craft button
-- It shows the craftable categories as a filter
-- And a search bar if the platform supports typing
local CraftFilterBar = Class(Widget, function(self, fn)
	Widget._ctor(self, "CraftFilterBar")

	self.iconSize = 42

	self.background = self:AddChild(Panel("images/ui_ftf_crafting/craft_bar_bg.tex"))
		:SetNineSliceCoords(14, 0, 682, 100)
		:SetNineSliceBorderScale(0.5)

	-- Contains buttons and text field
	self.contents = self:AddChild(Widget())
	-- Contains only buttons
	self.buttonsContainer = self.contents:AddChild(TabGroup())

	local ordered_slots = shallowcopy(Constructable.GetOrderedSlots())
	-- Buildings are only built by hiring npcs.
	lume.remove(ordered_slots, Constructable.Slots.BUILDINGS)
	-- For derived materials.
	-- table.insert(ordered_slots, itemcatalog.Consumable.Slots.MATERIALS)
	-- Add category icons
	for i,slot in pairs(ordered_slots) do
		local category = itemcatalog.All.SlotDescriptor[slot]
		-- Add a button per category
		local categoryButton = self.buttonsContainer:AddTab(category.icon, category.name)
			-- :SetScaleOnFocus(false)
			:SetToolTip(category.pretty.name)
			:SetToolTipLayoutFn(function(w, tooltip_widget)
				-- Position tooltip in relation to the button
				tooltip_widget:LayoutBounds("center", "center", w)
					:Offset(0, -65)
			end)

		-- Save category info
		categoryButton.descriptor = category
		categoryButton.tab_index = i

		-- A "new" badge for when stuff is unlocked
		categoryButton.unseenBadge = categoryButton:AddChild(Image("images/ui_ftf_shop/item_unseen.tex"))
			:SetHiddenBoundingBox(true)
			:IgnoreInput()
			:SetSize(self.iconSize * 0.55, self.iconSize * 0.55)
			--:LayoutBounds("right", "bottom", self.categoryButton)
			:Offset(self.iconSize * 0.3, -self.iconSize * 0.3)
			:Hide()
	end
	self.buttonsContainer
		:SetTabSize(self.iconSize, self.iconSize)
		:SetTabOnClick(function(tab_btn) self:OnCategoryClicked(tab_btn.descriptor, tab_btn.tab_index) end)
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		--~ :AddCycleIcons() -- TODO(dbriscoe): figure out when we are back to crafting.
		:LayoutChildrenInGrid(#ordered_slots, 6)
	-- Add text field
	self.textEdit = self.contents:AddChild(TextEdit())
		:SetSize(250)
		:SetTextPrompt(STRINGS.CRAFT_WIDGET.SEARCH_PLACEHOLDER)
		:SetHAlign(ANCHOR_LEFT)

	-- Layout contents
	self.textEdit:LayoutBounds("after", "center", self.buttonsContainer)
		:Offset(8, 0)
	local contentW, contentH = self.contents:GetSize()
	contentW = contentW + 40
	contentH = contentH + 20
	self.background:SetSize(contentW, contentH)
	self.contents:LayoutBounds("left", "center", self.background)
		:Offset(10, 0)

end)

function CraftFilterBar:SetPlayer(player)
	self.player = player

	-- Listen for changes to the amount of unseen (new) items
	self.inst:ListenForEvent("OnPlayerCrafterUnseenItem", function() self:OnPlayerCrafterUnseenItem() end, self.player)

	-- Also check right now, so the badge displays accordingly
	self:OnPlayerCrafterUnseenItem()

	return self
end

function CraftFilterBar:NextTab(delta)
	self.buttonsContainer:NextTab(delta)
	return self
end

function CraftFilterBar:OnCategoryClicked(categoryData, buttonIndex)

	self.selected_btn_index = buttonIndex

	-- Trigger callback too
	if self.onCategorySelectedFn then self.onCategorySelectedFn(categoryData) end

	return self
end

function CraftFilterBar:SelectMostRecentCategory()
	local favouriteIds = self.player.components.playercrafter:GetFavourites()
	if self.selected_btn_index == INDEX_OF_FAV_BTN and table.numkeys(favouriteIds) == 0 then
		-- Don't show favourites when we don't have any.
		self.selected_btn_index = nil
	end

	local btn = self.buttonsContainer.children[self.selected_btn_index]
	if btn then
		btn:Click()
		return self
	end
	return self:SelectFirstCategory()
end

function CraftFilterBar:SelectFirstCategory()
	local favouriteIds = self.player.components.playercrafter:GetFavourites()

	local btn_index = INDEX_OF_FAV_BTN
	if table.numkeys(favouriteIds) == 0 then
		-- Show first nonfav instead of empty favourites list.
		btn_index = 2
	end
	if #self.buttonsContainer.children > 0 then
		self.buttonsContainer.children[btn_index]:Click()
	end
	return self
end

function CraftFilterBar:UnselectAll()
	for k, button in ipairs(self.buttonsContainer.children) do
		button:Unselect()
	end
	return self
end

function CraftFilterBar:SetOnCategorySelectedFn(fn)
	self.onCategorySelectedFn = fn
	return self
end

function CraftFilterBar:OnPlayerCrafterUnseenItem()
	-- Go through the category buttons
	for k, button in ipairs(self.buttonsContainer.children) do

		-- Get construction slot/category
		local slot = button.descriptor.slot

		local unseenItemIds
		if button.descriptor.is_favourites then
			-- Favourites can't have new items, since they all must be hand-picked by the player.
			unseenItemIds = {}
		else
			-- Check how many new items there are for this category
			unseenItemIds = self.player.components.playercrafter:GetUnseenUnlockedCategoryItems(slot)
		end

		-- Show or hide the unseen badge accordingly
		button.unseenBadge:SetShown(table.numkeys(unseenItemIds) > 0)
	end
end

return CraftFilterBar
