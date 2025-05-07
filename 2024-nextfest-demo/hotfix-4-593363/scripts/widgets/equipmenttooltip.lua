local Panel = require "widgets/panel"
local Text = require "widgets/text"
local Widget = require "widgets/widget"
local DisplayValueHorizontal = require "widgets.ftf.displayvaluehorizontal"

local Power = require"defs.powers"
local Equipment = require "defs.equipment"
local itemutil = require "util.itemutil"
local kassert = require "util.kassert"

local ItemStats = require("widgets/ftf/itemstats")
local DisplayStat = require("widgets/ftf/displaystat")
local color = require "math.modules.color"
local Equipment = require("defs.equipment")

--------------------------------------------------------------------
-- A tooltip built specifically for showing equipment data

local EquipmentTooltip = Class(Widget, function(self, width, ischild)
	Widget._ctor(self)

	self:IgnoreInput(not ischild)

	self.padding_h = 25
	self.padding_v = 20

	-- Calculate content width
	width = width or DEFAULT_TT_WIDTH
	width = width - self.padding_h * 2

	self.bg = self:AddChild(Panel("images/ui_ftf_shop/tooltip_bg.tex"))
		:SetNineSliceCoords(124, 71, 130, 78)
		:SetNineSliceBorderScale(0.5)
		:SetMultColor(HexToRGB(0X4f3b33FF))

	self.container = self:AddChild(Widget("Container"))

	self.title_text = self.container:AddChild(Text(FONTFACE.DEFAULT, 22))
		:SetAutoSize(width)
		:SetWordWrap(true)
		:LeftAlign()
		:OverrideLineHeight(20)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		
	self.rarity_text = self.container:AddChild(Text(FONTFACE.DEFAULT, 22))
		:SetAutoSize(width)
		:SetWordWrap(true)
		:LeftAlign()
		:OverrideLineHeight(20)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)

	self.stats_container = self.container:AddChild(Widget("Stats"))
	self.tip_text = self.container:AddChild(Text(FONTFACE.DEFAULT, 18))
		:SetAutoSize(width)
		:SetWordWrap(true)
		:LeftAlign()
		:OverrideLineHeight(20)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)

	self:Hide()
end)

EquipmentTooltip.LAYOUT_SCALE =
{
    [SCREEN_MODE.MONITOR] = 2.5,
    [SCREEN_MODE.TV] = 3,
    [SCREEN_MODE.SMALL] = 3,
}

function EquipmentTooltip:OnExamine(down)
	self:LayoutWithContent( { item = self.item, player = self.player }, down)
end

-- @returns whether the layout was successful (and should be displayed).
function EquipmentTooltip:LayoutWithContent( data )
	self.item = data.item
	self.itemDef = self.item:GetDef()

	self.player = data.player

	self.stats_container:RemoveAllChildren()

	local stats_delta, stats = self.player.components.inventoryhoard:DiffStatsAgainstEquipped(self.item, self.itemDef.slot)
	
	local statsData = itemutil.BuildStatsTable(stats_delta, stats, self.itemDef.slot)
	self:AddStats(statsData)

	local tt = ""

	local rarity = self.itemDef.rarity or "COMMON"
	tt = tt .. string.format("<#%s>%s</>", rarity, self.item:GetLocalizedName())

	-- Update contents
	self.title_text:SetText(tt or "")
	self.title_text:LayoutBounds("left", "top", self.bg)
		:Offset(self.padding_h, -self.padding_v + 2)
	
	self.stats_container:LayoutChildrenInGrid(self.stats_columns, {h = 30 * HACK_FOR_4K, v = 3 * HACK_FOR_4K})
			:LayoutBounds("center", "below", self.title_text)

	local rarity_str = string.format("<#%s>%s</>", rarity, STRINGS.ITEMS.RARITY_CAPS[self.itemDef.rarity or ITEM_RARITY.s.COMMON])
	self.rarity_text:SetText(rarity_str)
		:LayoutBounds("center", "below", self.stats_container)
		:Offset(0, -15)

	self.tip_text:SetText(STRINGS.UI.INVENTORYSCREEN.UNEQUIP_SLOT_TT)
			:LayoutBounds("center", "below", self.rarity_text)
			:Offset(0, -5)
		
	self.tip_text:SetShown(TheWorld:HasTag("town") and not Equipment.SlotDescriptor[self.itemDef.slot].tags.required)

	self.bg:SizeToWidgets(50, self.container)
	self.container:LayoutBounds("center", "center", self.bg)

	return true
end

function EquipmentTooltip:AddStats(statsData)
	local max_width = 300 * 0.7
	local icon_size = 25 * HACK_FOR_4K
	local text_size = 20 * HACK_FOR_4K
	local delta_size = 15 * HACK_FOR_4K

	local count = table.numkeys(statsData)
	-- Calculate how many columns to display
	self.stats_columns = 1

	-- Calculate widget width
	max_width = 300 * 0.33

	for id, data in pairs(statsData) do
		-- Display stat widget
		self.stats_container:AddChild(DisplayStat(max_width, icon_size, text_size, delta_size))
			:ShouldShowToolTip(false)
			:ShowName(false)
			:ShowUnderline(true, 2, color.alpha(UICOLORS.LIGHT_TEXT_DARKER, 0.5))
			:SetStat(data)
	end

	return self
end

return EquipmentTooltip