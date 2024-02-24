local Widget = require("widgets/widget")
local Panel = require("widgets/panel")
local ActionButton = require("widgets/actionbutton")
local ArmourResearchRadial = require("widgets/ftf/armourresearchradial")
local CraftingMaterialsList = require("widgets/ftf/craftingmaterialslist")
local EquipmentDescriptionWidget = require("widgets/ftf/equipmentdescriptionwidget")
local ItemStats = require("widgets/ftf/itemstats")
local Text = require("widgets/text")

local Power = require "defs.powers"
local recipes = require "defs.recipes"
local fmodtable = require "defs.sound.fmodtable"

------------------------------------------------------------------------------------
-- A single craftable/upgradeable item from a given creature
-- Has a set width, but dynamic height

local UpgradeableItemWidget = Class(Widget, function(
	self, 
	width, 
	player, 
	item, 
	recipe, 
	owned, 
	locked, 
	previewing_shop_item
)
	Widget._ctor(self, "UpgradeableItemWidget")
	self:SetGainFocusSound(fmodtable.Event.hover)

	self.player = player
	self.recipe = recipe
	self.item = item
	self.owned = owned
	self.previewing_shop_item = previewing_shop_item
	self.locked = locked
	self.def = item:GetDef()

	self.width = width or 800
	self.header_width = self.width - 150
	self.desc_width = self.header_width - 500
	self.desc_contents_width = self.desc_width - 250

	self.bg = self:AddChild(Panel("images/ui_ftf_research/research_item_bg.tex"))
		:SetName("Background")
		:SetNineSliceCoords(43, 36, 162, 271)
		:SetSize(self.width, 256)

	self.header_bg = self:AddChild(Panel("images/ui_ftf_research/research_item_inner_bg.tex"))
		:SetName("Header background")
		:SetNineSliceCoords(100, 130, 130, 170)
		:SetSize(self.header_width, 260)

	self.header_widget = self:AddChild(Widget())
		:SetName("Header widget")
	self.recipe_icon = self.header_widget:AddChild(ArmourResearchRadial(350))
		:SetName("Armour radial")
		:SetItem(self.item)
		:SetMax(10)
		:LayoutBounds("left", "center", self.bg)
		:Offset(-50, 0)

	-- Description widget. Contains a background and several info labels
	self.desc_widget = self.header_widget:AddChild(Widget())
		:SetName("Description widget")
	self.desc_bg = self.desc_widget:AddChild(Panel("images/ui_ftf_research/research_description_bg.tex"))
		:SetName("Description background")
		:SetNineSliceCoords(84, 0, 804, 262)
		:SetSize(self.desc_width, 262)
	self.desc_text_container = self.desc_widget:AddChild(Widget())
		:SetName("Description widget")
	self.title = self.desc_text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT * 1.2, self.def.pretty.name, UICOLORS.BACKGROUND_DARK))
		:LeftAlign()
		:LayoutBounds("after", "top", self.recipe_icon)
		:Offset(20, -50)
	self.power_desc = self.desc_text_container:AddChild(EquipmentDescriptionWidget(self.desc_contents_width * 0.9, FONTSIZE.SCREEN_TEXT))
		:LayoutBounds("left", "below", self.title)
	self.stats_container = self.desc_widget:AddChild(Widget())
		:LayoutBounds("right", "center", self.desc_bg)
		:Offset(-30, 0)
	self.item_level = self.stats_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT * 1.1, "", UICOLORS.DARK_TEXT))
		:RightAlign()
	self.stats_desc = self.stats_container:AddChild(ItemStats())
		:SuppressStatsUnderline()
		:SuppressDelta()
		:SetPlayer(self.player)
		:SetItem(self.item.slot, self.item)
		:SetScale(0.6)

	-- Footer row
	self.footer_widget = self:AddChild(Widget())
		:SetName("Footer")
	self.footer_text = self.footer_widget:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT, "", UICOLORS.LIGHT_TEXT_DARK))
		:SetAutoSize(self.width * 0.5)
	self.materials_list = self.footer_widget:AddChild(CraftingMaterialsList(125, FONTSIZE.SCREEN_TEXT * 1.4))
		:SetName("Materials list")
		:SetPlayer(player)
		:SetTextColor(UICOLORS.BACKGROUND_DARK, UICOLORS.PENALTY)
		:ShowOnlyCost(true)
	self.button = self.footer_widget:AddChild(ActionButton())
		:SetName("Button")
		:SetScaleOnFocus(false)
		:SetScale(0.7)
		:SetNormalScale(0.7)
		:SetFocusScale(0.7)
		:SetOnClick(function() self:OnButtonClicked() end)
	self.equip_button = self.footer_widget:AddChild(ActionButton())
		:SetName("Equip button")
		:SetTextAndResizeToFit(STRINGS.UI.RESEARCHSCREEN.BTN_EQUIP)
		:SetScaleOnFocus(false)
		:SetScale(0.7)
		:SetScale(0.7)
		:SetNormalScale(0.7)
		:SetFocusScale(0.7)
		:SetOnClick(function() self:OnEquipClicked() end)
		:Hide()
	self.equip_button:DisableMips()

	self.equipped_label = self.footer_widget:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.BUTTON, "", UICOLORS.BLACK))
		:SetName("Equipped label")
		:SetText(STRINGS.UI.RESEARCHSCREEN.LABEL_EQUIPPED)
		:SetScale(0.7)
		:Hide()

	self.on_inventory_stackable_changed = function(_, def) self:Refresh() end
	self.on_loadout_changed = function() self:Refresh() end

	self.inst:ListenForEvent("inventory_stackable_changed", self.on_inventory_stackable_changed, self.player)
	self.inst:ListenForEvent("loadout_changed", self.on_loadout_changed, self.player)

	self:Refresh()
end)

function UpgradeableItemWidget:SetPlayer(player)
	self.stats_desc:SetPlayer(player)
	self.materials_list:SetPlayer(player)

	self.inst:RemoveEventCallback("inventory_stackable_changed", self.on_inventory_stackable_changed, self.player)
	self.inst:RemoveEventCallback("loadout_changed", self.on_loadout_changed, self.player)

	self.player = player
	self.inst:ListenForEvent("inventory_stackable_changed", self.on_inventory_stackable_changed, self.player)
	self.inst:ListenForEvent("loadout_changed", self.on_loadout_changed, self.player)

	self:Refresh()
end

function UpgradeableItemWidget:GetDefaultFocus()
	if self.button:IsShown() then
		return self.button
	elseif self.equip_button:IsShown() then
		return self.equip_button
	else
		return self
	end
end

function UpgradeableItemWidget:OnInputModeChanged(old_device_type, new_device_type)
	self.equip_button:RefreshText()
		:ResizeToFit()

	self:Layout()
end

function UpgradeableItemWidget:GetRecipe()
	return self.recipe
end

function UpgradeableItemWidget:SetOnCraftFn(fn)
	self.on_craft_fn = fn
	return self
end

function UpgradeableItemWidget:CanUpgradeItem()
	local def = self.item:GetDef()
	if def.usage_data and def.usage_data.power_on_equip then
		local power_def = Power.FindPowerByName(def.usage_data.power_on_equip)
		if power_def.stacks_per_usage_level then
			-- if the item's level is still lower than the number of upgrade tiers the item's power has,
			-- it can still be upgraded.
			return self.item:GetUsageLevel() < #power_def.stacks_per_usage_level
		end
	end
	return false
end

function UpgradeableItemWidget:Refresh()

	-- Get this item out of the player's inventory
	local held_item = self.player 
		and self.player.components.inventoryhoard:GetInventoryItem(self.item:GetDef())
	if not self.previewing_shop_item then
		self.owned = held_item ~= nil
	else
		self.owned = true
	end

	-- Check what item the player has equipped in this slot
	local currently_equipped
	if self.player then
		local slot = self.item.slot
		local selectedLoadoutIndex = self.player.components.inventoryhoard.data.selectedLoadoutIndex
		currently_equipped = self.player.components.inventoryhoard:GetLoadoutItem(selectedLoadoutIndex, slot)
	end

	self.recipe_icon:SetMax(self.item:GetMaxUsageLevel())
		:SetProgress(0)
	self.footer_text:Hide()
	self.materials_list:Hide()
	self.button:Hide()
	self.equip_button:Hide()
	self.equipped_label:Hide()
	local showing_upgrade_details = false
	self:UpdateTitle(showing_upgrade_details)
	self:UpdatePowerDescription(showing_upgrade_details)

	self:_ShowSaturatedState()

	-- The player has to unlock this creature before crafting any equipment
	if not self.locked then

		-- This creature has been unlocked
		if self.previewing_shop_item or self.owned then
			if held_item then
				-- The player already has this!
				self.item = held_item
			end

			-- Update progress
			self.recipe_icon:SetMax(self.item:GetMaxUsageLevel())
				:SetProgress(self.item:GetUsageLevel()/self.item:GetMaxUsageLevel())

			-- Can they get an upgrade?
			local recipe = recipes.FindUpgradeRecipeForItem(self.item)
			self.recipe = recipe

			if self.recipe and self.item:GetUsageLevel() + 1 <= self.item:GetMaxUsageLevel() then
				-- There is an upgrade available!
				showing_upgrade_details = true
				if not self.previewing_shop_item then
					self.recipe_icon:SetUpgradeProgress((self.item:GetUsageLevel()+1)/self.item:GetMaxUsageLevel(), UICOLORS.UPGRADE)
					self:UpdateTitle(showing_upgrade_details)
					self:UpdatePowerDescription(showing_upgrade_details)
					self.materials_list:SetIngredients(self.recipe.ingredients)
						:LayoutChildrenInRow(20)
						:Show()
					self.button:SetText(string.format(STRINGS.UI.RESEARCHSCREEN.BTN_UPGRADE, self.item:GetUsageLevel() + 1))
						:SetEnabled(self.recipe:CanPlayerCraft(self.player))
						:SetSecondary()
						:Show()
				end
			else
				-- The item is maxxed out!
				self.recipe_icon:SetProgress(1, UICOLORS.FOCUS_BOLD)
			end

			-- The player owns this. Is it equipped?
			if currently_equipped and currently_equipped == self.item then
				-- The player has this item equipped already
				if not self.previewing_shop_item then
					self.equip_button:Hide()
				end
				self.equipped_label:Show()
			else
				-- The player has something else equipped, or nothing
				if not self.previewing_shop_item then
					self.equip_button:Show()
				end
				self.equipped_label:Hide()
			end

			local footer_text
			if held_item then
				if not self.equipped_label:IsShown() then
					footer_text = STRINGS.UI.RESEARCHSCREEN.ALREADY_OWNED
				end
			else
				local item_def = self.item:GetDef()
				if item_def.weapon_type
					and self.player
					and not self.player.components.unlocktracker:IsWeaponTypeUnlocked(item_def.weapon_type) 
				then
					footer_text = STRINGS.UI.RESEARCHSCREEN.WEAPON_LOCKED
				end
			end
			if footer_text then
				self.footer_text
					:SetText(footer_text)
					:Show()
			else
				self.footer_text:Hide()
			end

		else

			-- The player doesn't own this yet
			self:_ShowDesaturatedState()

			self.recipe_icon:SetUpgradeProgress(0)
			self.materials_list:SetIngredients(self.recipe.ingredients)
				:LayoutChildrenInRow(20)
				:Hide()
			self.button:SetText(string.format(STRINGS.UI.RESEARCHSCREEN.BTN_CRAFT))
				-- :SetEnabled(self.recipe:CanPlayerCraft(self.player))
				-- :SetPrimary()
				:Hide()
			self.equip_button:Hide()
			self.equipped_label:Hide()

		end
	else
		-- This item is locked
		self:_ShowDesaturatedState()
	end

	self:Layout()
end

function UpgradeableItemWidget:_ShowDesaturatedState()
	self:Hide()

	-- self.materials_list:SetTextColor(UICOLORS.LIGHT_TEXT, UICOLORS.PENALTY)
	-- self.title:SetGlyphColor(UICOLORS.LIGHT_TEXT)
	-- self.bg:SetSaturation(0)
	-- self.header_bg:SetSaturation(0)
	-- self.desc_bg:SetSaturation(0)
	-- self.bg:SetMultColor(HexToRGB(0x584741FF))
	-- self.header_bg:SetMultColor(HexToRGB(0x584741FF))
	-- self.desc_bg:SetMultColor(HexToRGB(0x584741FF))
	-- self.recipe_icon:SetShadowColor(HexToRGB(0x413430FF))
	-- 	:SetImageSaturation(0)
	-- 	:SetImageColor(HexToRGB(0x352C4Fff))
	-- 	:SetImageAddColor(HexToRGB(0x352C4Fff))
	return self
end

function UpgradeableItemWidget:_ShowSaturatedState()
	self.materials_list:SetTextColor(UICOLORS.BACKGROUND_DARK, UICOLORS.PENALTY)
	self.title:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
	self.bg:SetSaturation(1)
	self.header_bg:SetSaturation(1)
	self.desc_bg:SetSaturation(1)
	self.bg:SetMultColor(UICOLORS.WHITE)
	self.header_bg:SetMultColor(UICOLORS.WHITE)
	self.desc_bg:SetMultColor(UICOLORS.WHITE)
	self.recipe_icon:SetShadowColor(UICOLORS.LIGHT_BACKGROUNDS_MID)
		:SetImageSaturation(1)
		:SetImageColor(UICOLORS.WHITE)
		:SetImageAddColor(UICOLORS.BLACK)
	return self
end

function UpgradeableItemWidget:Layout()

	-- Layout header
	self.power_desc:LayoutBounds("left", "below", self.title)
		:Offset(0, -5)
	self.desc_text_container:LayoutBounds("left", "center", self.desc_bg)
		:Offset(120, 0)
	self.desc_widget:LayoutBounds("after", "center", self.recipe_icon)
		:Offset(-55, 10)
	self.stats_desc:LayoutBounds("right", "below", self.item_level)
	self.stats_container
		:LayoutBounds("right", "center", self.desc_bg)
		:Offset(-50, 0)

	-- Layout footer
	self.footer_widget:LayoutChildrenInRow(40)
	self.button:Offset(20, 0)

	-- Resize whole panel
	local _, header_h = self.header_widget:GetSize()
	local _, footer_h = self.footer_widget:GetSize()
	header_h = header_h + 0 -- Padding for the header bg
	footer_h = footer_h + 10
	local bg_padding = 40 -- All around the inside
	local header_footer_spacing = 0 -- Between the header and the footer, if any footer
	if footer_h == 0 then
		header_footer_spacing = 0
	end
	self.bg:SetSize(self.width, header_h + header_footer_spacing + footer_h + bg_padding*2)
	self.header_bg:SetSize(self.header_width, header_h)
		:LayoutBounds("center", "top", self.bg)
		:Offset(-10, -bg_padding)
	self.header_widget:LayoutBounds("center", "center", self.header_bg)
		:Offset(0, -10)
	self.footer_widget:LayoutBounds("center", "below", self.header_bg)
		:Offset(0, -header_footer_spacing)

	return self
end

function UpgradeableItemWidget:CheckCanCraft()
	if not self.recipe then
		-- must be at max upgrade
	elseif self.recipe:CanPlayerCraft(self.player) then
		self.button:SetImageNormalColour(HexToRGB(0x59494966)) -- 40%
			:SetImageSelectedColour(HexToRGB(0x594949ff))
		-- can either be crafted or upgraded
	else
		self.button:SetImageNormalColour(HexToRGB(0xFF575366)) -- 40%
			:SetImageSelectedColour(HexToRGB(0xFF5753ff))
		-- can't craft
	end
end

function UpgradeableItemWidget:UpdateTitle(showing_upgrade_details)
	local level_str = ""
	if showing_upgrade_details and self.owned and self.item:GetUsageLevel() < self.item:GetMaxUsageLevel() then
		level_str = string.format(STRINGS.UI.RESEARCHSCREEN.TITLE_LEVEL_UPGRADE, self.item:GetUsageLevel(), self.item:GetUsageLevel() + 1)
	else
		level_str = string.format("%d", self.item:GetUsageLevel())
	end

	self.item_level:SetText(level_str)
end

function UpgradeableItemWidget:UpdatePowerDescription(showing_upgrade_details)
	if not self.owned then
		showing_upgrade_details = false
	end

	self.power_desc:SetItem(self.item, showing_upgrade_details)
end

function UpgradeableItemWidget:OnButtonClicked()
	if not self.recipe or not self.recipe:CanPlayerCraft(self.player) then
		TheFrontEnd:GetSound():PlaySound(fmodtable.Event.input_down)
		return
	end

	local skip_equip = true -- Don't equip until player confirms
	self.recipe:CraftItemForPlayer(self.player, skip_equip)

	if self.owned then
		-- upgrade item
		self.item:UpgradeUsageLevel()
		self.player:PushEvent("inventory_changed", { item = self.item })
		self.player:PushEvent("equipment_upgrade", { item = self.item })
		TheFrontEnd:GetSound():PlaySound(fmodtable.Event.inventory_upgrade)
		TheFrontEnd:GetSound():PlaySound(fmodtable.Event.upgrade_armour)
	else
		TheFrontEnd:GetSound():PlaySound(fmodtable.Event.craft_new_armour)
	end

	self:Refresh()

	if self.on_craft_fn then self.on_craft_fn() end

	return self
end

function UpgradeableItemWidget:OnEquipClicked()
	if self.owned and self.player and self.player.components.inventoryhoard then
		TheFrontEnd:GetSound():PlaySound(fmodtable.Event.equip_new_armour)
		local hoard = self.player.components.inventoryhoard
		hoard:SetLoadoutItem(hoard.data.selectedLoadoutIndex, self.item.slot, self.item)
		hoard:EquipSavedEquipment()
	end
end

UpgradeableItemWidget.CONTROL_MAP =
{
	{
		control = Controls.Digital.ACCEPT,
		fn = function(self)
			if self.button:IsShown() and self.button:IsEnabled() then
				self.button:Click()
				return true
			else
				self:OnFocusNudge("down")
				return false
			end
		end,
	},
}

return UpgradeableItemWidget
