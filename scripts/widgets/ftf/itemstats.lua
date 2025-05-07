local DisplayStat = require("widgets/ftf/displaystat")
local Image = require "widgets.image"
local Text = require "widgets.text"
local Widget = require "widgets.widget"

local EquipmentDescriptionWidget = require("widgets/ftf/equipmentdescriptionwidget")
local PowerDisplayWidget = require("widgets/ftf/powerdisplaywidget") -- for food details

local color = require "math.modules.color"
local itemutil = require "util.itemutil"
local Equipment = require "defs.equipment"
local EquipmentGem = require "defs.equipmentgems"
local Consumable = require "defs.consumable"
local Power = require"defs.powers"
local lume = require "util.lume"

-- ┌──────────────────────────┐
-- │ header_container         │
-- └──────────────────────────┘
--   ┌──────────────────────┐
--   │ stats_container      │
--   │                      │
--   │                      │
--   │                      │
--   │                      │
--   └──────────────────────┘

local ItemStats = Class(Widget, function(self, width)
	Widget._ctor(self, "ItemStats")

	self.width = width or 300 * HACK_FOR_4K
	self.padding = 20 * HACK_FOR_4K
	self.max_stats_columns = 2
	self.stats_columns = 2 -- Calculated later, based on the number of stats

	self.show_stat_names = false

	self.header_container = self:AddChild(Widget("Header container"))
	self.stats_container = self:AddChild(Widget("Stats container"))
end)

function ItemStats:SuppressStatsUnderline()
	self.suppress_underline = true
	self:Refresh()
	return self
end

function ItemStats:SetPlayer(player)
	self.player = player
	self:Refresh()
	return self
end

function ItemStats:SetItem(slot, itemData)
	self.slot = slot
	self.itemData = itemData
	self:Refresh()
	return self
end

function ItemStats:Refresh()
	local slot = self.slot
	local itemData = self.itemData

	-- No item, clear the panel only
	if slot == nil or itemData == nil then
		return self
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

	return self
end

function ItemStats:_ShowCommonDetails(slot, itemData)

	-- Clear contents
	self.header_container:RemoveAllChildren()
		:Hide()
	self.stats_container:RemoveAllChildren()
	self.comparison_title = nil

	return self
end

function ItemStats:_ShowEquipmentDetails(itemData, slot)
	local stats_delta = {}
	local stats
	if self.player then
		-- Calculate the stat differences to the loadout's saved item
		stats_delta, stats = self.player.components.inventoryhoard:DiffStatsAgainstEquipped(itemData, slot)
	else
		stats = itemData:GetStats()
	end
	local statsData = itemutil.BuildStatsTable(stats_delta, stats, slot)
	self:AddStats(statsData)

	self:Layout()
	return self
end

function ItemStats:_ShowWeaponDetails(itemData)
	-- Show header if comparing
	-- self:AddComparisonHeader(itemData, Equipment.Slots.WEAPON)
	
	return self:_ShowEquipmentDetails(itemData, Equipment.Slots.WEAPON)
end

function ItemStats:_ShowArmourDetails(slot, itemData)
	-- self:AddComparisonHeader(itemData, slot)
	return self:_ShowEquipmentDetails(itemData, slot)
end

function ItemStats:_ShowPotionDetails(itemData)
	self:Layout()
	return self
end

function ItemStats:_ShowFoodDetails(itemData)

	self:Layout()
	return self
end

function ItemStats:_ShowMaterialDetails(itemData)
	return self
end

function ItemStats:SetMaxColumns(cols)
	self.max_stats_columns = cols or 2
	return self
end

function ItemStats:ShowStatNames(show)
	self.show_stat_names = show
	return self
end

function ItemStats:AddHeader(text)
	self.header_bg = self.header_container:AddChild(Image("images/ui_ftf_inventory/ItemDetailsComparisonBg.tex"))
	-- TODO(dbriscoe): Use a larger size for potion descriptions (and not equipment changes).
	self.header_label = self.header_bg:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT * 0.7))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetText(text)
	local t_w, t_h = self.header_label:GetSize()
	self.header_bg:SetSize(t_w + 40 * HACK_FOR_4K, t_h + 10 * HACK_FOR_4K)
	self.header_container:Show()
	return self
end

function ItemStats:AddComparisonHeader(current_item, slot)
	local equipped_item = self.player.components.inventoryhoard:GetEquippedItem(slot)
	if equipped_item and equipped_item.id ~= current_item.id then
		-- Shows: Equipped -> Selected. The comparison is how stats will change
		-- if we switch to selected.
		self.comparison_title = self:AddHeader(string.format("<#%s>%s</> <p img='images/ui_ftf/arrow_right.tex' color=0 scale=0.6> <#%s>%s</>", equipped_item:GetDef().rarity, equipped_item:GetLocalizedName(), current_item:GetDef().rarity, current_item:GetLocalizedName()))
		-- comparison:LayoutBounds("center", "below", )
	end
	return self
end

function ItemStats:AddStats(statsData)
	local max_width = self.width * 0.7
	local icon_size = 75 * HACK_FOR_4K
	local text_size = 50 * HACK_FOR_4K
	local delta_size = 20 * HACK_FOR_4K

	local index = 1
	local count = table.numkeys(statsData)
	-- Calculate how many columns to display
	if count <= self.max_stats_columns then
		self.stats_columns = 1
	else
		self.stats_columns = self.max_stats_columns
	end

	-- Calculate widget width
	max_width = self.width * 0.33

	local is_last_row = false
	for id, data in pairs(statsData) do

		-- We want the underline to show on all stats except the ones in the last row
		is_last_row = math.ceil(index/self.stats_columns) == math.ceil(count/self.stats_columns)
		local suppress_underline = self.suppress_underline or is_last_row
		-- Display stat widget
		self.stats_container:AddChild(DisplayStat(max_width, icon_size, text_size, delta_size))
			:ShouldShowToolTip(true)
			:ShowName(self.show_stat_names)
			:ShowUnderline(not suppress_underline, 2, color.alpha(UICOLORS.LIGHT_TEXT_DARKER, 0.5))
			:SetStat(data)

		index = index + 1
	end

	return self
end

function ItemStats:Layout()

	if self.header_container:IsShown() then
		self.stats_container:LayoutChildrenInGrid(self.stats_columns, {h = 30 * HACK_FOR_4K, v = 12 * HACK_FOR_4K})
			:LayoutBounds("center", "below", self.header_container)
	else
		self.stats_container:LayoutChildrenInGrid(self.stats_columns, {h = 30 * HACK_FOR_4K, v = 12 * HACK_FOR_4K})
			:LayoutBounds("center", "center", self)
			:Offset(0, -10 * HACK_FOR_4K)
	end
	return self
end

return ItemStats
