local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Panel = require("widgets/panel")
local Text = require("widgets/text")
local PlayerPuppet = require("widgets/playerpuppet")
local EquipmentSlots = require("widgets.ftf.equipmentslots")
local CharacterStats = require("widgets.ftf.characterstats")
local KonjurSoulsWidget = require("widgets/ftf/konjursoulswidget")
local fmodtable = require "defs.sound.fmodtable"
local itemutil = require"util.itemutil"
local Equipment = require("defs.equipment")
local SGPlayerCommon = require "stategraphs.sg_player_common"
local DisplayStat = require "widgets/ftf/displaystat"

------------------------------------------------------------------------------------------
--- Displays a panel with a player's character info
----
local EquipmentPanel = Class(Widget, function(self)
	Widget._ctor(self, "EquipmentPanel")

	self.width = 540 * HACK_FOR_4K
	self.height = RES_Y

	-- Background
	self.bg = self:AddChild(Image("images/ui_ftf_inventory/CharacterPreviewPanel.tex"))

	-- Username
	self.username_bg = self:AddChild(Panel("images/ui_ftf_inventory/PanelTitle.tex"))
		:SetNineSliceCoords(90, 37, 520, 80)
	self.username = self:AddChild(Text(FONTFACE.DEFAULT, 26 * HACK_FOR_4K, "Lorem", UICOLORS.DARK_TEXT))

	-- Konjur
	self.konjurRings = self:AddChild(KonjurSoulsWidget(0))
		:SetHiddenBoundingBox(true)
	-- Clip to avoid overlap on right panel.
	local k_w, k_h = self.konjurRings:GetSize()
	local right_inset = 60 * HACK_FOR_4K
	self.konjurRings:SetScissor(-k_w/2, -k_h/2, k_w-right_inset, k_h)

	-- Animated character
	self.puppetContainer = self.bg:AddChild(Widget("Puppet Container"))
	self.puppet_shadow = self.puppetContainer:AddChild(Image("images/ui_ftf_inventory/CharacterShadow.tex"))
		:SetScale(0.4 * HACK_FOR_4K)
	self.puppet = self.puppetContainer:AddChild(PlayerPuppet())
		:SetScale(0.95 * HACK_FOR_4K)
		:SetFacing(FACING_RIGHT)

	self.statContainer = self:AddChild(Widget("Stats Container"))

	-- Equipment slots
	self.equipmentSlots = self:AddChild(EquipmentSlots())
end)

function EquipmentPanel:SetMannequinPanel(panel)
	self.mannequinPanel = panel
	return self
end

function EquipmentPanel:Refresh(player)
	self.player = player
	self:RefreshPuppet()
	self.equipmentSlots:SetPlayer(self.player)
	self.konjurRings:SetSoulsMode(self.player)
		:LayoutBounds("right", "top", self.bg)
		:Offset(0, 37 * HACK_FOR_4K)

	-- Update username
	self.username:SetText(player:GetCustomUserName())
	local text_w, text_h = self.username:GetSize()
	self.username_bg:SetSize(text_w + 150 * HACK_FOR_4K, 44 * HACK_FOR_4K)
		:LayoutBounds("center", "top", self.bg)
	self.username:LayoutBounds("center", "center", self.username_bg)

	self:RefreshSlots()

	-- Layout slots, stats and username
	self.equipmentSlots:LayoutBounds("left", "top", self.bg)
		:SetOnCategoryClickFn(function(slot_data) self:OnCategoryClicked(slot_data) end)
		:SetOnRightClickFn(function(slot_data) self:OnSlotRightClicked(slot_data) end)
		:Offset(36 * HACK_FOR_4K, -30 * HACK_FOR_4K)

	self:RefreshStats()

	return self
end

function EquipmentPanel:RefreshPuppet()
	local data = self.player.components.charactercreator:OnSave()
	self.puppet:CloneCharacterWithEquipment(self.player)

	-- Position puppet
	self.puppet_shadow:LayoutBounds("center", "bottom", self.puppet)
		:Offset(0, -30 * HACK_FOR_4K)
	self.puppetContainer:SetScale(0.85)
		:LayoutBounds("center", "center", self.bg)
		:Offset(-70 * HACK_FOR_4K, -140 * HACK_FOR_4K)

	self:DoWeaponStance()
	return self
end

-- Show the puppet holding the current weapon
function EquipmentPanel:DoWeaponStance(weapon_override)
	if self.player then

		-- If a weapon hasn't been selected, use the one the player has equipped
		self.equipped_weapon = weapon_override or self.player.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)

		-- Animate the puppet according to the active weapon
		self.weapon_idle_animation = SGPlayerCommon.Fns.GetWeaponPrefix(self.equipped_weapon, "idle_ui")
		self.puppet:PlayAnim(self.weapon_idle_animation, true) -- Loop = true
	end
	return self
end

function EquipmentPanel:DoCheer()
	self.puppet:PlayAnimSequence({"emote_pump", "idle"})
end

function EquipmentPanel:RefreshStats(previewed_slot, previewed_item)
	self.statContainer:RemoveAllChildren()

	local statsData = {
		{
			icon = "images/icons_ftf/stat_weapon.tex",
			stat = EQUIPMENT_STATS.s.DMG,
			value = 0,
			delta = 0
		},
		{
			icon = "images/icons_ftf/stat_armour.tex",
			stat = EQUIPMENT_STATS.s.ARMOUR,
			value = 0,
			delta = 0
		},
	}
	local max_width = 315
	local icon_size = 100 * HACK_FOR_4K
	local text_size = 60 * HACK_FOR_4K
	local delta_size = 20 * HACK_FOR_4K

	for _,slot in pairs(Equipment.GetOrderedSlots()) do

		if slot == previewed_slot then
			-- See what the differences for this previewed item are.
			local stats_delta, stats = self.player.components.inventoryhoard:DiffStatsAgainstEquipped(previewed_item, slot)

			local equipped_item = self.player.components.inventoryhoard:GetEquippedItem(slot)
			local equipped_stats = equipped_item and equipped_item:GetStats()

			for idx, data in pairs(statsData) do
				local stat = data.stat
				if stats_delta and stats_delta[stat] then
					data.delta = (data.delta or 0) + (stats_delta[stat] or 0)
				end
				if equipped_stats and equipped_stats[stat] then
					data.value = (data.value or 0) + (equipped_stats[stat] or 0)
				end
			end
		else
			-- Get currently selected item
			local item = self.equipmentSlots:GetSelectedItem(slot) -- In this case, this is already the equipped item.

			-- Calculate the stat differences to the loadout's saved item
			local stats_delta, stats = self.player.components.inventoryhoard:DiffStatsAgainstEquipped(item, slot)
			for idx, data in pairs(statsData) do
				local stat = data.stat
				if stats and (stats[stat] or stats_delta[stat]) then
					data.value = (data.value or 0) + (stats[stat] or 0)
					data.delta = (data.delta or 0) + (stats_delta[stat] or 0)
				end
			end
		end
	end

	local is_last_row = false
	for id, data in pairs(statsData) do
		-- Display stat widget
		self.statContainer:AddChild(DisplayStat(max_width, icon_size, text_size, delta_size))
			:ShouldShowToolTip(true)
			:ShowName(self.show_stat_names)
			:ShowUnderline(false)
			:SetStat(data)
			:SetStyle_EquipmentPanel()
	end

	self.statContainer:LayoutChildrenInGrid(1, {h = 30 * HACK_FOR_4K, v = 25 * HACK_FOR_4K})
		:LayoutBounds("center", "center", self.bg)
		:Offset(self.width * 0.475, -25)
		:SendToFront()

	return self
end

function EquipmentPanel:RefreshSlots()
	return self
end

function EquipmentPanel:SetOnCategoryClickFn(fn)
	self.onCategoryClickFn = fn
	return self
end

function EquipmentPanel:SetOnRightClickFn(fn)
	self.onSlotRightClickFn = fn
	return self
end

function EquipmentPanel:OnCategoryClicked(slot_data)

	-- One of the slots was clicked. Notify the parent
	if self.onCategoryClickFn then self.onCategoryClickFn(slot_data) end

	return self
end

function EquipmentPanel:OnSlotRightClicked(slot_data)

	-- One of the slots was clicked. Notify the parent
	if self.onSlotRightClickFn then self.onSlotRightClickFn(slot_data) end

	return self
end

-- The screen notified this that the category was changed elsewhere
function EquipmentPanel:SetCurrentCategory(slot)
	-- Tell the slots to highlight the correct slot
	self.equipmentSlots:SetCurrentCategory(slot)
	return self
end

function EquipmentPanel:EquipItem(slot, itemData)
	-- Update puppet
	local item_def = itemData and itemData:GetDef()
	self.puppet.components.inventory:Equip(slot, item_def and item_def.name)

	if slot == Equipment.Slots.WEAPON then
		self:DoWeaponStance(itemData)
	end

	-- Update slots
	self.equipmentSlots:EquipItem(slot, itemData)

	if item_def and item_def.sound_events and item_def.sound_events.equip then
		TheFrontEnd:GetSound():PlaySound(fmodtable.Event[item_def.sound_events.equip])
	end
	return self
end

function EquipmentPanel:GetSelectedItem(slot)
	return self.equipmentSlots:GetSelectedItem(slot)
end


function EquipmentPanel:ShowItemPreview(slot, itemData)
	self.equipmentSlots:ShowItemPreview(slot, itemData)
	self:RefreshStats(slot, itemData)
	return self
end

function EquipmentPanel:ClearItemPreview(slot)
	self.equipmentSlots:ClearItemPreview(slot)
	self:RefreshStats()
	return self
end

return EquipmentPanel
