local HudButton = require "widgets.ftf.hudbutton"
local HotkeyWidget = require("widgets/hotkeywidget")
local Image = require "widgets.image"
local Widget = require("widgets/widget")
local easing = require "util.easing"

local CraftableItemDetailsPanel = require"widgets.ftf.craftableitemdetailspanel"
local CraftFilterBar = require"widgets.ftf.craftfilterbar"
local CraftableItemsList = require"widgets.ftf.craftableitemslist"


local Consumable = require"defs.consumable"

------------------------------------------------------------------------------------------
--- The button that toggles the build menu while in town
-- Displays its hotkey below it
local CraftButton = Class(Widget, function(self, fn)
	Widget._ctor(self, "CraftButton")

	-- Our clickable craft button
	self.button = self:AddChild(HudButton(140, "images/ui_ftf_shop/hud_button_build.tex", UICOLORS.ACTION, fn))

	-- Hotkey hint
	self.hotkeyWidget = self:AddChild(HotkeyWidget(Controls.Digital.OPEN_CRAFTING, STRINGS.CRAFT_WIDGET.HUD_HOTKEY))
		:LayoutBounds("center", "below", self.button)
		:Offset(0, -10)
	self.hotkeyWidget:SetOnLayoutFn(function()
		self.hotkeyWidget:LayoutBounds("center", "below", self.button)
			:Offset(0, -10)
	end)

	-- A "new" badge for when stuff is unlocked
	self.unseenBadge = self:AddChild(Image("images/ui_ftf_shop/item_unseen.tex"))
		:SetHiddenBoundingBox(true)
		:SetToolTip(STRINGS.CRAFT_WIDGET.CRAFT_BUTTON_UNSEEN_BADGE_TT)
		:SetSize(42 * HACK_FOR_4K, 42 * HACK_FOR_4K)
		:LayoutBounds("right", "bottom", self.button)
		:Offset(5, 15)
		:Hide()

	-- The filters bar with the category listing
	-- Opens when the button is clicked
	self.filterBar = self:AddChild(CraftFilterBar())
		:LayoutBounds("before", "center", self.button)
		:Offset(32, -8)
		:SendToBack()
		:SetOnCategorySelectedFn(function(categoryData) self:OnCategorySelected(categoryData) end)
		:Hide()
	self.filterBarX, self.filterBarY = self.filterBar:GetPosition()
	self.isBarOpen = false

	-- The list of items within the selected category
	self.itemsList = self:AddChild(CraftableItemsList())
		:LayoutBounds("right", "above", self.button)
		:Offset(-88, -58)
		:MemorizePosition()
		:SendToBack()
		:SetOnItemFocusedFn(function(...) self:OnItemFocused(...) end)
		:SetOnItemUnfocusedFn(function() self:OnItemUnfocused() end)
		:SetOnItemSelectedFn(function(...) self:OnItemSelected(...) end)
		:SetOnItemSelectedAltFn(function(...) self:OnItemSelectedAlt(...) end)
		:Hide()

	-- The details panel above the list, for hovered items
	self.listItemDetails = self:AddChild(CraftableItemDetailsPanel())
		:LayoutBounds("center", "above", self.itemsList)
		:ShowCraftingInfo()
		:Offset(0, 70)
		:MemorizePosition()
		:SendToBack()
		:Hide()

	-- The details panel floating on the header, for when placing items down
	self.floatingItemDetails = self:AddChild(CraftableItemDetailsPanel())
		:SetHiddenBoundingBox(true)
		:ShowPlacementInfo()
		:LayoutBounds("center", "above", self.button)
		:MemorizePosition()
		:SendToBack()
		:Hide()

end)

function CraftButton:SetPlayer(player)
	self.player = player

	-- Listen for changes to the amount of unseen (new) items
	self.inst:ListenForEvent("OnPlayerCrafterUnseenItem", function() self:OnPlayerCrafterUnseenItem() end, self.player)
	self.inst:ListenForEvent("inventory_changed", function() self:OnInventoryChanged() end, self.player)
	self.inst:ListenForEvent("inventory_stackable_changed", function() self:OnInventoryChanged() end, self.player)

	self.filterBar:SetPlayer(self.player)

	-- Also check right now, so the badge displays accordingly
	self:OnPlayerCrafterUnseenItem()
	return self
end

function CraftButton:GetDetailsPanel()
	return self.floatingItemDetails
end

CraftButton.CONTROL_MAP =
{
	--~ {
	--~ 	control = Controls.Digital.CANCEL,
	--~ 	hint = function(self, left, right)
	--~ 		table.insert(right, loc.format(LOC"UI.CONTROLS.CANCEL", Controls.Digital.CANCEL))
	--~ 	end,
	--~ 	fn = function(self)
	--~ 		self:ToggleBar()
	--~ 		return true
	--~ 	end,
	--~ },
	{
		control = Controls.Digital.MENU_TAB_PREV,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.PREV_TAB", Controls.Digital.MENU_TAB_PREV))
		end,
		fn = function(self)
			self:NextTab(-1)
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_TAB_NEXT,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.NEXT_TAB", Controls.Digital.MENU_TAB_NEXT))
		end,
		fn = function(self)
			self:NextTab(1)
			return true
		end,
	},
}

function CraftButton:OnInventoryChanged()
	if self.itemsList:IsListOpen() then
		self.itemsList:_RefreshCurrentCategory()
	end
end

function CraftButton:NextTab(delta)
	self.filterBar:NextTab(delta)
	return self
end

function CraftButton:OpenBar()
	if not self.isBarOpen then
		self.isBarOpen = true
		self.filterBar:Show()
		self.filterBar:SetMultColorAlpha(0)
			:SetPosition(self.filterBarX + 150, self.filterBarY)
			:Show()
			:AlphaTo(1, 0.1, easing.inOutQuad)
			:ScaleTo(0.7, 1, 0.1, easing.inOutQuad)
			:MoveTo(self.filterBarX, self.filterBarY, 0.1, easing.inQuad)

		-- Select first category when the animation is over
		TheWorld:DoTaskInTime(0.15, function()
			if self.isBarOpen then
				self.filterBar:SelectMostRecentCategory()
			end
			self.player.components.playercontroller:EnterBuildingMode()
		end)
		if self.floatingItemDetails:IsOpen() then
			-- Bar is auto closed when placing, so if details is still open
			-- then we're still placing.
			self:_CancelPlacing(self.player)
		end
	end
end

function CraftButton:CloseBar()
	if self.isBarOpen then
		self.isBarOpen = false
		self.itemsList:CloseList(function()
			self.player.components.playercontroller:ExitBuildingMode()
			self.filterBar:AlphaTo(0, 0.1, easing.inOutQuad, function() self.filterBar:Hide() end)
				:ScaleTo(1, 0.7, 0.1, easing.inOutQuad)
				:MoveTo(self.filterBarX + 150, self.filterBarY, 0.1, easing.inQuad)
				:UnselectAll()
		end)
	end
end

function CraftButton:_CancelPlacing(player)
	self.floatingItemDetails:Close()
	player.components.playercontroller:StopPlacer()
end

function CraftButton:IsBarOpen()
	return self.shown and self.isBarOpen
end

function CraftButton:ToggleBar()
	if self.isBarOpen then
		self:CloseBar()
	else
		self:OpenBar()
	end
end

function CraftButton:OnCategorySelected(categoryData)
	-- If list is open, close it first
	if self.itemsList:IsListOpen() then
		self.itemsList:CloseList(function()
			-- Refresh contents and reopen
			self.itemsList:SetCategory(categoryData)
				:OpenList()
		end)
	else
		-- If the list is closed, just refresh the contents and reopen
		self.itemsList:SetCategory(categoryData)
			:OpenList()
	end
end

function CraftButton:OnItemFocused(itemId, itemSlot, itemData)
	local placeable_def = Consumable.FindItem(itemId)
	local has_existing = self.player.components.inventoryhoard:GetStackableCount(placeable_def) > 0
	self.listItemDetails:SetItem(itemId, itemSlot, itemData, has_existing)
		:Open()
end

function CraftButton:OnItemUnfocused()
	self.listItemDetails
		:Close()
end

function CraftButton:ShakeWidget(widget)
	local rot = 5
	self:RunUpdater(Updater.Series({
				Updater.Ease(function(v) widget:SetRotation(v) end, 0, rot, 0.05, easing.inOutQuad),
				Updater.Ease(function(v) widget:SetRotation(v) end, rot, -rot, 0.05, easing.inOutQuad),
				Updater.Ease(function(v) widget:SetRotation(v) end, -rot, 0, 0.05, easing.inOutQuad),
			})
		)
end

function CraftButton:OnItemSelected(itemId, itemSlot, itemData)
	-- If you have one of these crafted already, try to place it.
	-- If you don't have one of these crafted already, queue a craft and then try to place it.
		-- Do not consume crafting materials until placement is done.

	local placeable_def = Consumable.FindItem(itemId)
	local has_existing = self.player.components.inventoryhoard:GetStackableCount(placeable_def) > 0

	self.floatingItemDetails:SetItem(itemId, itemSlot, itemData, has_existing)

	local recipe = self.floatingItemDetails.recipe

	if self.floatingItemDetails:IsOpen() then
		self:_CancelPlacing(self.player)
	elseif recipe:CanPlayerCraft(self.player) or has_existing then
		local def = itemData:GetDef()
		if def.tags.placeable then
			self.floatingItemDetails:Open()
			self:CloseBar()

			local function validate_fn()
				-- do you still have existing items or still have materials


				local can_place = recipe:CanPlayerCraft(self.player) or self.player.components.inventoryhoard:GetStackableCount(placeable_def) > 0

				if not can_place then
					self:ShakeWidget(self.floatingItemDetails)
					self.floatingItemDetails:SetItem(itemId, itemSlot, itemData, has_existing)
				end

				return can_place
			end

			local function on_cancel(placer, placed_ent)
				self.floatingItemDetails:Close()
				self:OpenBar()
			end

			local function on_success(placer, placed_ent)
				assert(recipe.def.name == placed_ent.prefab)

				if has_existing then
					self.player.components.inventoryhoard:RemoveStackable(placeable_def, 1)
				else
					recipe:TakeIngredientsFromPlayer(self.player)
				end

				has_existing = self.player.components.inventoryhoard:GetStackableCount(placeable_def) > 0
				self.floatingItemDetails:SetItem(itemId, itemSlot, itemData, has_existing)
			end

			local prefab = itemData.id
			self.player.components.playercontroller:StartPlacer(prefab.."_placer", validate_fn, on_success, on_cancel)

		else
			recipe:CraftItemForPlayer(self.player)
			self:ShakeWidget(self.listItemDetails)
		end
	else
		-- TODO(dbriscoe): error sound
	end
end

function CraftButton:OnItemSelectedAlt(itemId, itemSlot, itemData)
	-- Craft one of these and add it to your inventory.

	self.floatingItemDetails:SetItem(itemId, itemSlot, itemData)
	local recipe = self.floatingItemDetails.consumable_recipe

	if recipe:CanPlayerCraft(self.player) then
		recipe:CraftItemForPlayer(self.player, true)
		self:ShakeWidget(self.listItemDetails)
	else
		-- TODO(dbriscoe): error sound
	end
end

function CraftButton:OnPlayerCrafterUnseenItem()
	-- Check how many new items there are
	local unseenItemIds = self.player.components.playercrafter:GetUnseenItems()

	-- Show or hide the unseen badge accordingly
	self.unseenBadge:SetShown(table.numkeys(unseenItemIds) > 0)
end

return CraftButton
