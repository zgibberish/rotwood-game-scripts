local ItemStats = require("widgets/ftf/itemstats")
local Panel = require "widgets.panel"
local Text = require "widgets.text"
local Widget = require "widgets.widget"

local Equipment = require "defs.equipment"
local EquipmentGem = require "defs.equipmentgems"
local Consumable = require "defs.consumable"
local Power = require "defs.powers"
local PowerDisplayWidget = require "widgets/ftf/powerdisplaywidget"
local EquipmentDescriptionWidget = require "widgets/ftf/equipmentdescriptionwidget"

--   ▼ panel_left                  ▼ panel_right (ItemStats)
-- ┌─────────────────────────────┬──────────────────────────────┐
-- │ ┌─────────────────────────┐ │                              │
-- │ │ title                   │ │                              │
-- │ ├─────────────────────────┤ │                              │
-- │ │ description             │ │                              │
-- │ │                         │ │                              │
-- │ │                         │ │                              │
-- │ │                         │ │                              │
-- │ └─────────────────────────┘ │                              │
-- │                             │                              │
-- │                             │                              │
-- │                             │                              │
-- │ ┌─────────────────────────┐ │                              │
-- │ │ rarity                  │ │                              │
-- └─┴─────────────────────────┴─┴──────────────────────────────┘

local ItemDetails = Class(Widget, function(self, width, height)
	Widget._ctor(self, "ItemDetails")

	self.width = width or 300 * HACK_FOR_4K
	self.height = height or 200 * HACK_FOR_4K
	self.padding = 20 * HACK_FOR_4K
	self.max_stats_columns = 2
	self.stats_columns = 2 -- Calculated later, based on the number of stats

	self.left_w = 300 * HACK_FOR_4K
	self.item_stats_w = self.width - self.left_w

	self.bg = self:AddChild(Panel("images/ui_ftf_inventory/ItemDetailsPanel.tex"))
		:SetNineSliceCoords(630, 0, 648, 550)
		:SetSize(width, height)

	local padding = 30 * HACK_FOR_4K
	local text_width = self.width * 0.6 - padding
	self.empty_label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetAutoSize(text_width)
		:SetText(STRINGS.UI.INVENTORYSCREEN.NO_ITEM_SELECTED)
		:Hide()

	self.description_label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetAutoSize(text_width)
		:SetHAlign(ANCHOR_MIDDLE)
		:Hide()

	self.panel_left = self:AddChild(Widget("Panel left"))
	self.item_stats = self:AddChild(ItemStats(self.item_stats_w - padding * 2))

	-- Left side
	self.title = self.panel_left:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_SUBTITLE))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetAutoSize(text_width)
	self.description = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT * 0.9))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetAutoSize(text_width)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetVAlign(ANCHOR_TOP)
		:SetRegionSize(text_width, 120)
		:SetAlpha(0.4)
	self.rarity = self.panel_left:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))

	self.power_container = self:AddChild(Widget("Power Container"))

end)

function ItemDetails:SetPlayer(player)
	self.player = player
	self.item_stats:SetPlayer(self.player)
	return self
end

function ItemDetails:SetItem(slot, itemData)
	-- No item, clear the panel only
	if slot == nil or itemData == nil then
		self:_ShowEmpty()
		return self
	else
		self.bg:SetTexture("images/ui_ftf_inventory/ItemDetailsPanel.tex")
		self.panel_left:Show()
		self.item_stats:Show()
		self.empty_label:Hide()
	end

	-- Show the details that are shared across all items
	self:_ShowCommonDetails(slot, itemData)

	-- And also the category-specific details
	if slot == Equipment.Slots.WEAPON then
		self:_ShowWeaponDetails(itemData)
	elseif slot == Equipment.Slots.POTIONS
	or slot == Equipment.Slots.TONICS then
		self:_ShowPotionDetails(itemData)
	elseif slot == Equipment.Slots.FOOD then
		self:_ShowFoodDetails(itemData)
	elseif slot == Consumable.Slots.MATERIALS
		or slot == Consumable.Slots.PLACEABLE_PROP
		or slot == Consumable.Slots.KEY_ITEMS
		or slot == EquipmentGem.Slots.GEMS then
		self:_ShowMaterialDetails(itemData)
	else --  Armour
		self:_ShowArmourDetails(slot, itemData)
	end

	self:Layout()
	return self
end

--- Displayed when there's no item selected
function ItemDetails:ShowOnlyDescription(description_text, show_owned_label)
	self.bg:SetTexture("images/ui_ftf_inventory/ItemDetailsPanelEmpty.tex")
	self.panel_left:Hide()
	self.item_stats:Hide()
	self.empty_label:Hide()
	self.description_label:SetText(string.format("<i>"..STRINGS.UI.CRAFTING.RECIPE_DESCRIPTION.."</i>", description_text))
		:LayoutBounds("center", "center", self.bg)
		:Show()

	-- Show a label displaying whether or not the player owns this item
	if show_owned_label then
		if not self.owned_label_bg then
			self.owned_label_bg = self:AddChild(Panel("images/ui_ftf_crafting/RecipeDescriptionOwned.tex"))
				:SetNineSliceCoords(46, 0, 58, 100)
				:LayoutBounds("left", "center", -RES_X / 2, 0)
				:Offset(40 * HACK_FOR_4K, 0)
			self.owned_label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT, STRINGS.UI.CRAFTING.OWNED, UICOLORS.LIGHT_TEXT_SELECTED))
			local w, h = self.owned_label:GetSize()
			self.owned_label_bg:SetSize(w + 120 * HACK_FOR_4K, h + 8 * HACK_FOR_4K)
		end
		self.owned_label_bg:LayoutBounds("center", "bottom", self.bg)
			:Offset(0, 6)
			:Show()
		self.owned_label:LayoutBounds("center", "center", self.owned_label_bg)
			:Offset(0, -2)
			:Show()
	elseif self.owned_label_bg then
		self.owned_label_bg:Hide()
		self.owned_label:Hide()
	end
	return self
end

--- Displayed when there's no item selected
function ItemDetails:_ShowEmpty(slot, itemData)
	self.bg:SetTexture("images/ui_ftf_inventory/ItemDetailsPanelEmpty.tex")
	self.panel_left:Hide()
	self.item_stats:Hide()
	self.empty_label:Show()
end

function ItemDetails:_ShowCommonDetails(slot, itemData)
	self.power_container:RemoveAllChildren()

	-- Show item name and description
	self.title:SetText( string.format("<#%s>%s</>", itemData:GetDef().rarity, itemData:GetLocalizedName()) )
	self.description:SetText(itemData:GetLocalizedDescription())

	-- Update stats
	self.item_stats:SetItem(slot, itemData)

	-- Show rarity
	local itemDef = itemData:GetDef()
	local rarity_str = STRINGS.ITEMS.RARITY_CAPS[itemDef.rarity or ITEM_RARITY.s.COMMON]
	self.rarity:SetText(string.format("<#%s>%s</>",itemDef.rarity, rarity_str))

	return self
end

function ItemDetails:AddSkill(itemData)

	local def = itemData:GetDef()
	local usage_data = def.usage_data
	local power_name = usage_data.power_on_equip

	if power_name then
		local power_def = Power.FindPowerByName(power_name)
		local pow = self.player.components.powermanager:CreatePower(power_def)
		-- Check if this power should show in the UI
		if power_def.show_in_ui then
			-- Show its widget
			self.power_container:AddChild(PowerDisplayWidget(self.width * 0.6, self.player, pow, "skill"))
		end
	end

	return self
end

function ItemDetails:AddEquipmentPower(itemData)
	self.power_container:AddChild(EquipmentDescriptionWidget(self.width * 0.5, FONTSIZE.ROOMBONUS_TEXT))
		:SetItem(itemData)

	return self
end

function ItemDetails:AddFoodPower(itemData)
	local def = itemData:GetDef()
	local usage_data = def.usage_data

	if usage_data and usage_data.power then
		local power_def = Power.FindPowerByName(usage_data.power)
		if power_def then
			-- Display widget
			local pow = self.player.components.powermanager:CreatePower(power_def)
			local power_widget = self.power_container:AddChild(PowerDisplayWidget(self.width * 0.5, self.player, pow, "food"))
		end
	end
end

function ItemDetails:AddPotionPower(itemData)
	local def = itemData:GetDef()
	local usage_data = def.usage_data
	if usage_data and usage_data.power then
		local power_def = Power.FindPowerByName(usage_data.power)
		if power_def then
			local pow = self.player.components.powermanager:CreatePower(power_def)
			-- Check if this power should show in the UI
				-- Show its widget
			self.power_container:AddChild(PowerDisplayWidget(self.width * 0.5, self.player, pow, nil, false, def.icon)) --width, owner, power, is_skill, hide_icon, icon_override

			-- -- Display the header regardless
			-- if usage_data.power_stacks then
			-- 	local stacks_label = string.format(" x%s", usage_data.power_stacks)
			-- 	self:AddHeader(string.format(STRINGS.UI.INVENTORYSCREEN.TONIC_POWER_EXPLANATION, stacks_label))
			-- else
			-- 	self:AddHeader(string.format(STRINGS.UI.INVENTORYSCREEN.TONIC_POWER_EXPLANATION, ""))
			-- end
		end
	end
end

function ItemDetails:_ShowWeaponDetails(itemData)
	self:AddSkill(itemData)
	return self
end

function ItemDetails:_ShowArmourDetails(slot, itemData)
	self:AddEquipmentPower(itemData)
	return self
end

function ItemDetails:_ShowPotionDetails(itemData)
	self:AddPotionPower(itemData)
	return self
end

function ItemDetails:_ShowFoodDetails(itemData)
	self:AddFoodPower(itemData)
	return self
end

function ItemDetails:_ShowMaterialDetails(itemData)
	local desc_string = itemData:GetLocalizedDescription()
	if itemData.count then
		desc_string = string.format(STRINGS.UI.INVENTORYSCREEN.DESCRIPTION_QUANTITY_SUFFIX, itemData:GetLocalizedDescription(), itemData.count)
	end
	-- Append item quantity below the description
	self.description:SetText(desc_string)
	return self
end

function ItemDetails:Layout()

	-- Layout text
	-- I want the title to be centered on the left panel
	self.title:LayoutBounds("center", "top", self.bg)
		:Offset(-self.width/2 + self.left_w/2, -40 * HACK_FOR_4K)
	self.item_stats:LayoutBounds("center", "below", self.title)

	self.rarity:LayoutBounds("center", nil, self.title)
		:LayoutBounds(nil, "bottom", self.bg)
		:Offset(0, 8 * HACK_FOR_4K)

	self.power_container:LayoutBounds("center", "top", self.bg)
		:Offset(140 * HACK_FOR_4K, -50 * HACK_FOR_4K)

	self.description:LayoutBounds("center", "bottom", self.bg)
		:Offset(140 * HACK_FOR_4K, 20 * HACK_FOR_4K)

	-- Layout empty label
	self.empty_label:LayoutBounds("center", "center", self.bg)
	self.description_label:LayoutBounds("center", "bottom", self.bg)
end

return ItemDetails
