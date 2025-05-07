local InventorySlot = require "widgets.ftf.inventoryslot"
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local EquipmentDescriptionWidget = require("widgets/ftf/equipmentdescriptionwidget")
local TotalWeightWidget = require("widgets/ftf/totalweightwidget")

local Equipment = require("defs.equipment")
local ItemCatalog = require("defs.itemcatalog")
local Weight = require "components/weight"

------------------------------------------------------------------------------------------
--- Displays all the player character's equipment slots
----
local EquipmentSlots = Class(Widget, function(self)
	Widget._ctor(self, "EquipmentSlots")

	self.slotSize = 90 * HACK_FOR_4K

	self.equippedItemSlots = {}

	-- Contains the consumable slots on the top left
	self.slotsLeft = self:AddChild(Widget())

	-- Contains the equipment slots on the bottom right
	self.bgRight = self:AddChild(Image("images/ui_ftf_inventory/EquipmentSlotsLong.tex"))
		:SetSize(520, 1200)
		:SetMultColorAlpha(0.9)
	self.slotsRight = self:AddChild(Widget())
end)

function EquipmentSlots:SetPlayer(player)

	self.player = player
	self.selectedLoadoutIndex = self.player.components.inventoryhoard.data.selectedLoadoutIndex

	-- Remove old slots
	self.slotsLeft:RemoveAllChildren()
	self.slotsRight:RemoveAllChildren()

	-- Add new consumable slots

	local outline_size = 2

	local potionSlot = self:CreateEquippedItemSlot(self.slotsLeft, Equipment.Slots.POTIONS, self.slotSize*1.85)
		:SetSelectionSize(1)
		:SetSelectionColor(UICOLORS.BLACK)
		:ShowSelectionOutline()
		:SetIconSize(-32, 0)
		:SetBackground("images/ui_ftf_inventory/PotionSlotSelection.tex", "images/ui_ftf_inventory/PotionSlotOverlay.tex", "images/ui_ftf_inventory/PotionSlotBackground.tex")
		:SetFlatBackground(0xCEB6A5ff)
		:LayoutBounds("left", "top", 0, 0)

	local tonicSlot = self:CreateEquippedItemSlot(self.slotsLeft, Equipment.Slots.TONICS, self.slotSize*1.3)
		:SetSelectionSize(outline_size)
		:SetSelectionColor(UICOLORS.BLACK)
		:ShowSelectionOutline()
		:SetIconSize(-50, -30 * HACK_FOR_4K)
		:SetBackground("images/ui_ftf_inventory/TonicSlotSelection.tex", "images/ui_ftf_inventory/TonicSlotOverlay.tex", "images/ui_ftf_inventory/TonicSlotBackground.tex")
		:SetFlatBackground(0xCEB6A5ff)
		:LayoutBounds("left", "top", potionSlot)
		:Offset(130 * HACK_FOR_4K, -58 * HACK_FOR_4K)

	local foodSlot = self:CreateEquippedItemSlot(self.slotsLeft, Equipment.Slots.FOOD, self.slotSize*1.3)
		:SetSelectionSize(outline_size)
		:SetSelectionColor(UICOLORS.BLACK)
		:ShowSelectionOutline()
		:SetIconSize(-20, -30 * HACK_FOR_4K)
		:SetBackground("images/ui_ftf_inventory/FoodSlotSelection.tex", "images/ui_ftf_inventory/FoodSlotOverlay.tex", "images/ui_ftf_inventory/FoodSlotBackground.tex")
		:SetFlatBackground(0xCEB6A5ff)
		:LayoutBounds("left", "top", potionSlot)
		:Offset(57 * HACK_FOR_4K, -143 * HACK_FOR_4K)

	-- And new equipment slots

	self.bgRight:LayoutBounds("left", "top", potionSlot)
		:Offset(810, -485)

	local function CreateArmorSlot(slot, add_description)
		local equip_slot = self:CreateEquippedItemSlot(self.slotsRight, slot, self.slotSize * 1.15)
			:SetSelectionSize(outline_size)
			:SetSelectionColor(UICOLORS.BLACK)
			:ShowSelectionOutline()
			:SetIconSize(0, -8 * HACK_FOR_4K)

		return equip_slot
	end

	local function AddEquipmentDescription(slot)
		local widget = self.equippedItemSlots[slot]

		widget.desc_widget = self:AddChild(EquipmentDescriptionWidget(800, 42))
			:Hide()

		local equippedItem = self.player.components.inventoryhoard:GetLoadoutItem(self.selectedLoadoutIndex, slot)

		if equippedItem ~= nil then
			self:EquipItem(slot, equippedItem)
		end
	end

	local weaponSlot = self:CreateEquippedItemSlot(self.slotsRight, Equipment.Slots.WEAPON, self.slotSize*1.4)
		:SetSelectionSize(outline_size)
		:SetSelectionColor(UICOLORS.BLACK)
		:ShowSelectionOutline()
		:SetIconSize(-10 * HACK_FOR_4K, -34 * HACK_FOR_4K)
		:SetBackground("images/ui_ftf_inventory/WeaponSlotSelection.tex", "images/ui_ftf_inventory/WeaponSlotOverlay.tex", "images/ui_ftf_inventory/WeaponSlotBackground.tex")
		:LayoutBounds("right", "top", self.bgRight)
		:Offset(-12 * HACK_FOR_4K, 2 * HACK_FOR_4K)

	--TODO: create a skill widget to be near the weaponSlot

	local headSlot = CreateArmorSlot(Equipment.Slots.HEAD)
		:LayoutBounds("center", "below", potionSlot)
		:Offset(50 * HACK_FOR_4K, -535 * HACK_FOR_4K)

		AddEquipmentDescription(Equipment.Slots.HEAD)

	local bodySlot = CreateArmorSlot(Equipment.Slots.BODY)
		:LayoutBounds("left", "below", headSlot)

		AddEquipmentDescription(Equipment.Slots.BODY)

	local lowerSlot = CreateArmorSlot(Equipment.Slots.WAIST)
		:LayoutBounds("left", "below", bodySlot)

		AddEquipmentDescription(Equipment.Slots.WAIST)

	self.weightWidget = self:AddChild(TotalWeightWidget(player, 0.7))
		:LayoutBounds("before", "below", weaponSlot)
		:Offset(-80, -50)

	return self
end

-- Creates a slot that holds the currently equipped item
-- On creation, it retrieves the currently equipped item from the current loadout
-- After that, it holds what item the player has selected at the moment
-- If the two are different when the player leaves the screen, they can choose to save it to the loadout
function EquipmentSlots:CreateEquippedItemSlot(container, slot, size)
	local equippedItem = self.player.components.inventoryhoard:GetLoadoutItem(self.selectedLoadoutIndex, slot)

	-- Create slot widget
	local common = ItemCatalog.All.SlotDescriptor[slot]
	local slotWidget = container:AddChild(InventorySlot(size, common.icon))
		:SetNavFocusable(false)
		:SetItem(equippedItem, self.player)

	-- Add click callback
	slotWidget:SetOnClick(function() self:OnSlotClicked(slotWidget, slot) end)

	-- Add right-click callback
	slotWidget:SetOnClickAlt(function() self:OnSlotRightClicked(slotWidget, slot) end)

	-- Save reference to widget
	self.equippedItemSlots[slot] = slotWidget

	return slotWidget
end

function EquipmentSlots:EquipItem(slot, itemData)
	-- Only equip items if there's a slot for them (so we don't equip materials)
	if slot and self.equippedItemSlots[slot] then
		self.equippedItemSlots[slot]:SetItem(itemData, self.player)
		if self.equippedItemSlots[slot].desc_widget then
			if itemData then
				self.equippedItemSlots[slot].desc_widget:Show()
				self.equippedItemSlots[slot].desc_widget:SetItem(itemData)
				self.equippedItemSlots[slot].desc_widget:LayoutBounds("after", "center", self.equippedItemSlots[slot])
					:Offset(15, 0)
			else
				self.equippedItemSlots[slot].desc_widget:Hide()
			end
		end

	end

	if self.weightWidget then
		local weights = {}
		local relevant_slots = { Equipment.Slots.WEAPON, Equipment.Slots.HEAD, Equipment.Slots.BODY, Equipment.Slots.WAIST }
		for slot,data in pairs(self.equippedItemSlots) do
			if table.contains(relevant_slots, slot) then
				local def = data.item and data.itemDef
				if def then
					weights[slot] = def.weight
				else
					weights[slot] = Weight.EquipmentWeight.s.None
				end
			end
		end
		self.weightWidget:UpdateByListOfWeights(weights)
	end

	return self
end

function EquipmentSlots:GetSelectedItem(slot)
	if self.equippedItemSlots[slot] then
		return self.equippedItemSlots[slot]:GetItemInstance()
	end
	return nil
end

function EquipmentSlots:SetOnCategoryClickFn(fn)
	self.onCategoryClickFn = fn
	return self
end

function EquipmentSlots:SetOnRightClickFn(fn)
	self.onRightClickFn = fn
	return self
end

function EquipmentSlots:OnSlotClicked(slotWidget, slot)
	-- Highlight the correct category
	self:SetCurrentCategory(slot)

	-- Let the listeners know the selected category changed
	if self.onCategoryClickFn then self.onCategoryClickFn(slot) end

	return self
end

function EquipmentSlots:OnSlotRightClicked(slotWidget, slot)

	-- Let the listeners know the selected category changed
	if self.onRightClickFn then self.onRightClickFn(slot) end

	return self
end

function EquipmentSlots:SetCurrentCategory(slot)
	-- Go through slot widgets and highlight the correct one
	for slotId, slotWidget in pairs(self.equippedItemSlots) do
		slotWidget:SetHighlighted(slotId == slot)
	end
	return self
end

function EquipmentSlots:ShowItemPreview(slot, itemData)
	if self.weightWidget then
		local weights = {}
		local relevant_slots = { Equipment.Slots.WEAPON, Equipment.Slots.HEAD, Equipment.Slots.BODY, Equipment.Slots.WAIST }
		if not table.contains(relevant_slots, itemData.slot) then
			return
		end

		-- Get all the currently equipped items, first.
		for slot,data in pairs(self.equippedItemSlots) do
			if table.contains(relevant_slots, slot) then
				local def = data.item and data.itemDef
				if def then
					weights[slot] = def.weight
				else
					weights[slot] = Weight.EquipmentWeight.s.None
				end
			end
		end

		-- Replace the slot we're trying to preview with the new weight.
		local previewed_weight = itemData:GetDef().weight
		weights[slot] = previewed_weight

		self.weightWidget:PreviewByListOfWeights(weights)
	end
	return self
end

function EquipmentSlots:ClearItemPreview(slot)
	if self.weightWidget then
		self.weightWidget:HidePreview()
	end
	return self
end

return EquipmentSlots
