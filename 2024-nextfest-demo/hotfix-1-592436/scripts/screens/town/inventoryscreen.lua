local EquipmentPanel = require("widgets/ftf/equipmentpanel")
local InventoryPanel = require("widgets/ftf/inventorypanel")
local Screen = require("widgets/screen")

local camerautil = require "util.camerautil"
local easing = require "util.easing"
local lume = require"util.lume"
local Consumable = require "defs.consumable"
local Equipment = require("defs.equipment")
local fmodtable = require "defs.sound.fmodtable"

local DEFAULT_SLOT = Equipment.GetOrderedSlots()[1]

-- In general, 'item' refers to an instance of an item: one in the player's
-- inventory. We can get its definition ('def') with item:GetDef(). We can get
-- common data about its category of item with item:GetCommon(). This is the
-- same data that's defined per slot in itemdef.common.

-------------------------------------------------------------------------------------------------
--- A screen showing two panels, the character sheet on the left,
--- and the inventory panel on the right
local InventoryScreen = Class(Screen, function(self, player)
	Screen._ctor(self, "InventoryScreen")

	self.equipmentPanel = self:AddChild(EquipmentPanel())
		:SetOnCategoryClickFn(function(slot_key) self:OnEquipmentSlotClicked(slot_key) end)
		:SetOnRightClickFn(function(slot_key) self:OnEquipmentSlotRightClicked(slot_key) end)
		:LayoutBounds("before", nil, 1, 0)
	
	self.inventoryPanel = self:AddChild(InventoryPanel())
		:SetOnCategoryClickFn(function(slot_data) self:OnCategoryClicked(slot_data) end)
		:SetOnItemClickFn(function(itemData, idx) self:OnItemClicked(itemData, idx) end)
		:SetOnItemAltClickFn(function(itemData, idx) self:OnAltItemClicked(itemData, idx) end)
		:SetOnItemGainFocusFn(function(itemData, idx) self:OnItemGainFocus(itemData, idx) end)
		:SetOnItemLoseFocusFn(function(itemData, idx) self:OnItemLoseFocus(itemData, idx) end)
		:SetOnItemTooltipFn(function(itemData, idx) return self:OnItemTooltip(itemData, idx) end)
		:SetOnCloseFn(function() self:OnCloseButton() end)
		:LayoutBounds("after", nil, -1, 0)

	dbassert(player)
	self:SetOwningPlayer(player)
end)

function InventoryScreen:SetDefaultFocus()
	return self.inventoryPanel:SetDefaultFocus()
end

function InventoryScreen:SetOwningPlayer(owningplayer)
	self.player = owningplayer -- need this for existing logic
	InventoryScreen._base.SetOwningPlayer(self, owningplayer)
	self:Refresh()
end

InventoryScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.MENU_SCREEN_ADVANCE,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.ACCEPT", Controls.Digital.MENU_SCREEN_ADVANCE))
		end,
		fn = function(self)
			self:OnCloseButton()
			return true
		end,
	},
	{
		control = Controls.Digital.CANCEL,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.CANCEL", Controls.Digital.CANCEL))
		end,
		fn = function(self)
			self:OnCloseButton()
			return true
		end,
	},
	{
		control = Controls.Digital.OPEN_INVENTORY,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.CANCEL", Controls.Digital.CANCEL))
		end,
		fn = function(self)
			self:OnCloseButton()
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_TAB_PREV,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.PREV_TAB", Controls.Digital.MENU_TAB_PREV))
		end,
		fn = function(self)
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.hover)
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
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.hover)
			self:NextTab(1)
			return true
		end,
	},
}

function InventoryScreen:OnBecomeActive()
	InventoryScreen._base.OnBecomeActive(self)
	TheDungeon.HUD:Hide()

	--sound snapshot
	TheAudio:StartFMODSnapshot(fmodtable.Snapshot.MenuOverlay)

	-- JAMBELL: capture current stats

	if not self.animatedIn then
		-- Animate in the first time the screen shows up
		self:AnimateIn()
		self.animatedIn = true
	end

	self.inventoryPanel:ClickFirstSlot()
end

function InventoryScreen:OnBecomeInactive()
	InventoryScreen._base.OnBecomeInactive(self)

	--sound
	TheFrontEnd:GetSound():PlaySound(fmodtable.Event.inventory_hide)

	--sound snapshot
	TheAudio:StopFMODSnapshot(fmodtable.Snapshot.MenuOverlay)

	camerautil.ReleaseCamera(self.player)
end

function InventoryScreen:AnimateIn()
	-- Hide elements
	self.equipmentPanel:SetMultColorAlpha(0)
	self.inventoryPanel:SetMultColorAlpha(0)

	-- Get default positions
	local csX, csY = self.equipmentPanel:GetPosition()
	local ipX, ipY = self.inventoryPanel:GetPosition()

	--sound
	TheFrontEnd:GetSound():PlaySound(fmodtable.Event.inventory_show)

	-- Start animating
	self:RunUpdater(Updater.Series({

		-- Animate in the character panel
		Updater.Parallel({
			Updater.Ease(function(v) self.equipmentPanel:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
			Updater.Ease(function(v) self.equipmentPanel:SetPosition(v, csY) end, csX - 30 * HACK_FOR_4K, csX, 0.2, easing.inOutQuad),
		}),

		-- Animate in the inventory panel
		Updater.Parallel({
			Updater.Ease(function(v) self.inventoryPanel:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
			Updater.Ease(function(v) self.inventoryPanel:SetPosition(v, ipY) end, ipX + 30 * HACK_FOR_4K, ipX, 0.2, easing.inOutQuad),
		}),

	}))

	return self
end

function InventoryScreen:Refresh()
	self.equipmentPanel:Refresh(self.player)
	self.inventoryPanel:Refresh(self.player)
	return self
end

-- Checks whether the player has changed any equipment
function InventoryScreen:DidEquipmentChange()
	local changed = false

	-- Get saved loadout
	local selectedLoadoutIndex = self.player.components.inventoryhoard.data.selectedLoadoutIndex
	local equipmentSlots = self.player.components.inventoryhoard:GetLoadout_Readonly(selectedLoadoutIndex)

	for _,slot in pairs(Equipment.GetOrderedSlots()) do
		-- Get saved equipped item
		local item = equipmentSlots[slot]

		-- Get currently selected item
		local equippedItem = self.equipmentPanel:GetSelectedItem(slot)

		-- Check if there is a new item equipped, for comparison
		if item ~= equippedItem then
			changed = true
		end
	end

	return changed
end

function InventoryScreen:NextTab(delta)
	self.inventoryPanel:NextTab(delta)
	return self
end

function InventoryScreen:OnEquipmentSlotClicked(slot_key)
	if self:DidEquipmentChange() then
		self:_SaveInventoryChanges()
		self.equipmentPanel:RefreshStats()
	end

	local best_slot = nil
	for _, slot_data in ipairs(self.inventoryPanel.inventory_slots) do
		if #slot_data.slots == 1 and lume.find(slot_data.slots, slot_key) then
			best_slot = slot_data
			break
		end
	end

	if not best_slot then
		for _, slot_data in ipairs(self.inventoryPanel.inventory_slots) do
			if lume.find(slot_data.slots, slot_key) then
				best_slot = slot_data
				break
			end
		end
	end

	self:OnCategoryClicked(best_slot)

	return self
end

-- If right-clicked, unequip item
function InventoryScreen:OnEquipmentSlotRightClicked(slot_key)
	local is_required = Equipment.SlotDescriptor[slot_key].tags.required
	if not is_required then
		self.equipmentPanel:EquipItem(slot_key, nil)
		self.inventoryPanel:UpdateEquippedStatus(slot_key, nil)-- Update equipped badge
	end

	if self:DidEquipmentChange() then
		self:_SaveInventoryChanges()
		self.equipmentPanel:RefreshStats()
	end

	return self
end

-- An item in the inventory was clicked
function InventoryScreen:OnCategoryClicked(slot_data)
	if self:DidEquipmentChange() then
		self:_SaveInventoryChanges()
		self.equipmentPanel:RefreshStats()
	end

	self.inventoryPanel:SetTitle(STRINGS.ITEM_CATEGORIES[slot_data.key])

	self.equipmentPanel:SetCurrentCategory(slot_data)
	self.inventoryPanel:SetCurrentCategory(slot_data)

	return self
end

local function IsRequiredItem(itemData)
	local def = itemData:GetDef()
	local slot = def.slot
	return Equipment.SlotDescriptor[slot].tags.required
end

function InventoryScreen:OnAltItemClicked(itemData, idx)
	local slot = itemData.slot

	if itemData.slot == Consumable.Slots.MATERIALS then
		return
	end

	local equippedItem = self.inventoryPanel:_GetEquippedItem(slot)
	local is_required = Equipment.SlotDescriptor[slot].tags.required
	if slot ~= Equipment.Slots.WEAPON and Equipment.Slots[slot] and not is_required and itemData == equippedItem then
	 	self.equipmentPanel:EquipItem(slot, nil)
		self:_SaveInventoryChanges()
		self.equipmentPanel:RefreshStats()
		self.inventoryPanel:UpdateEquippedStatus(slot, nil) -- Refresh stats so that the new item details panel is referencing our newly equipped item
	end
end

-- An item in the inventory was clicked
function InventoryScreen:OnItemClicked(itemData, idx)
	local slot = itemData.slot
	local previewItem = self.equipmentPanel:GetSelectedItem(slot)

	local selectedItem = self.inventoryPanel:_GetSelectedItem(slot)
	local equippedItem = self.inventoryPanel:_GetEquippedItem(slot)

	if itemData.slot == Consumable.Slots.MATERIALS then

	elseif itemData.slot == Consumable.Slots.PLACEABLE_PROP then
		local function on_cancel(placer, placed_ent)
			-- open screen again
			TheFrontEnd:PushScreen(InventoryScreen(self.player))
		end

		local function on_success(placer, placed_ent)
			-- open screen again
			-- remove from inventory
			local def = Consumable.FindItem(itemData.id)
			self.player.components.inventoryhoard:RemoveStackable(def, 1)
			TheFrontEnd:PushScreen(InventoryScreen(self.player))
		end

		self:OnCloseButton()
		-- close inventory screen
		self.player.components.playercontroller:StartPlacer(itemData.id.."_placer", nil, on_success, on_cancel)
	else
		-- only try to equip an item if it's equipment.
		if itemData == equippedItem and itemData == previewItem then
			-- If we clicked an equipped item we unequip it
			self:OnAltItemClicked(itemData, idx)
			return
		elseif itemData == selectedItem then
			if itemData == previewItem then
				-- go back to equipped item
				itemData = equippedItem
				local i = lume.find(self.inventoryPanel.listWidget.itemsList, equippedItem)
				self.inventoryPanel:_SelectItem(slot, equippedItem, i)
			else
				-- show as preview (we don't have to do anything to make this happen)
			end
		end


		-- Update the character panel
		self.equipmentPanel:EquipItem(slot, itemData)
		self:_SaveInventoryChanges() -- Equip right away so this becomes our new build. 
									 -- If we don't save here, we are only ever comparing to the item we had equipped upon first entering the screen, which is very confusing.
		self.inventoryPanel:UpdateEquippedStatus(slot, itemData) -- Refresh stats so that the new item details panel is referencing our newly equipped item
		self.equipmentPanel:RefreshStats()

		--sound
		--TheFrontEnd:GetSound():PlaySound(fmodtable.Event.inventory_equip)
	end

end

function InventoryScreen:OnItemGainFocus(itemData, idx)
	-- Update the character panel
	-- self.equipmentPanel:EquipItem(itemData.slot, itemData)

	self.equipmentPanel:ShowItemPreview(itemData.slot, itemData)
end

function InventoryScreen:OnItemLoseFocus(itemData, idx)
	-- Update the character panel
	-- self.equipmentPanel:EquipItem(itemData.slot, itemData)

	self.equipmentPanel:ClearItemPreview(itemData.slot, itemData)
end

function InventoryScreen:OnItemTooltip(itemData, idx)
	local slot = itemData.slot
	local equippedItem = self.inventoryPanel:_GetEquippedItem(slot)
	local previewItem = self.equipmentPanel:GetSelectedItem(slot)
	
	if itemData.slot ~= Consumable.Slots.MATERIALS and itemData.slot ~= Consumable.Slots.PLACEABLE_PROP then
		if itemData == equippedItem and itemData == previewItem then
			if not Equipment.SlotDescriptor[slot].tags.required then -- not a required item
				return STRINGS.UI.INVENTORYSCREEN.UNEQUIP_TT
			end
		else
			return STRINGS.UI.INVENTORYSCREEN.EQUIP_TT
		end
	end

	return nil
end

function InventoryScreen:_ShowPlayerHUD()
	assert(TheDungeon.HUD, "No HUD for closing inventory screen.")
	TheDungeon.HUD:Show()
end

function InventoryScreen:OnCloseButton()
	if self:DidEquipmentChange() then
		self:_SaveInventoryChanges()
		TheFrontEnd:PopScreen(self)
		self:_ShowPlayerHUD()
	else
		-- Just close the screen
		TheFrontEnd:PopScreen(self)
		self:_ShowPlayerHUD()
	end
end

function InventoryScreen:_SaveInventoryChanges()

	-- Get saved loadout
	local hoard = self.player.components.inventoryhoard
	local selectedLoadoutIndex = self.player.components.inventoryhoard.data.selectedLoadoutIndex
	local equipmentSlots = self.player.components.inventoryhoard:GetLoadout_Readonly(selectedLoadoutIndex)

	-- Go through each slot
	for _,slot in pairs(Equipment.GetOrderedSlots()) do
		-- Get saved equipped item
		local item = equipmentSlots[slot]

		-- Get currently selected item
		local equippedItem = self.equipmentPanel:GetSelectedItem(slot)

		-- Check if there is a different item equipped
		if item ~= equippedItem then
			hoard:SetLoadoutItem(selectedLoadoutIndex, slot, equippedItem)
		end
	end
	hoard.data.selectedLoadoutIndex = selectedLoadoutIndex
	hoard:EquipSavedEquipment()

	return self
end

return InventoryScreen
