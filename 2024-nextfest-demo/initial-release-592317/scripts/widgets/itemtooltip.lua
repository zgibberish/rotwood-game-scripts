local Panel = require "widgets/panel"
local Text = require "widgets/text"
local Widget = require "widgets/widget"
local DisplayValueHorizontal = require "widgets.ftf.displayvaluehorizontal"

local Power = require"defs.powers"
local Equipment = require "defs.equipment"
local itemutil = require "util.itemutil"
local kassert = require "util.kassert"
--------------------------------------------------------------------
-- A tooltip built specifically for showing item qualities and comparing items to eachother.

local ItemTooltip = Class(Widget, function(self, width, ischild)
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
	self:Hide()

	self.focus_text = self.container:AddChild(Text(FONTFACE.DEFAULT, 18))
		:SetAutoSize(width)
		:SetWordWrap(true)
		:LeftAlign()
		:OverrideLineHeight(20)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)

	self.usage_data_text = self.container:AddChild(Text(FONTFACE.DEFAULT, 18))
		:SetAutoSize(width)
		:SetWordWrap(true)
		:LeftAlign()
		:OverrideLineHeight(20)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)

	self.tip_text = self.container:AddChild(Text(FONTFACE.DEFAULT, 18))
		:SetAutoSize(width)
		:SetWordWrap(true)
		:LeftAlign()
		:OverrideLineHeight(20)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)

	self.ilvl_text = self.container:AddChild(Text(FONTFACE.DEFAULT, 15))
		:SetAutoSize(width)
		:SetWordWrap(true)
		:LeftAlign()
		:OverrideLineHeight(20)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)

	self.stats_container = self.container:AddChild(Widget("Stats"))
		:SetScale(0.5)

	self:Hide()
end)

ItemTooltip.LAYOUT_SCALE =
{
    [SCREEN_MODE.MONITOR] = 2.5,
    [SCREEN_MODE.TV] = 3,
    [SCREEN_MODE.SMALL] = 3,
}

function ItemTooltip:OnExamine(down)
	self:LayoutWithContent( { item = self.item, player = self.player }, down)

	if down then
		local other_item = self.player.components.inventoryhoard:GetEquippedItem(self.itemDef.slot)
		if not self.other_item_tt then

			if not other_item then other_item = self.item end

			self.other_item_tt = self:AddChild(ItemTooltip(nil, true))
				:Show()
			self.other_item_tt:LayoutWithContent({ item = other_item, player = self.player }, false)
			self.other_item_tt:LayoutBounds("left", "below", self.bg)
		end
	else
		if self.other_item_tt then
			self.other_item_tt:Remove()
			self.other_item_tt = nil
		end
	end
end

function ItemTooltip:OnHide()
	if self.other_item_tt then
		self.other_item_tt:Remove()
		self.other_item_tt = nil
	end
end

-- @returns whether the layout was successful (and should be displayed).
function ItemTooltip:LayoutWithContent( data, do_diff )
	self.item = data.item
	self.itemDef = self.item:GetDef()

	self.player = data.player

	self.stats_container:RemoveAllChildren()

	if not (self.itemDef.slot == "FAVOURITES" or self.itemDef.slot == "BUILDINGS" or self.itemDef.slot == "FURNISHINGS" or self.itemDef.slot == "DECOR") then
		local stats_delta, stats = self.player.components.inventoryhoard:DiffStatsAgainstEquipped(self.item, self.itemDef.slot)

		if not do_diff and stats_delta then
			stats_delta = {}
		end

		if stats_delta or stats then
			local statsData = itemutil.BuildStatsTable(stats_delta, stats, self.itemDef.slot)
			self:AddStats(statsData)
		end
	end

	local tt = ""

	local rarity = self.itemDef.rarity or "COMMON"

	tt = tt .. string.format("<#%s>%s</>", rarity, self.item:GetLocalizedName())

	if self.itemDef.weapon_type then
		self.focus_text:SetText(string.format("\n\n%s", STRINGS.WEAPONS.FOCUS_HIT[self.item:GetDef().weapon_type]))
		self.focus_text:Show()
	else
		self.focus_text:SetText("")
		self.focus_text:Hide()
	end

	if self.itemDef.tags["recipe"] then
		self.tip_text:SetText("[TEMP] This unlocks a new recipe in your village!\n(if the correct villager has moved in)")
		self.tip_text:Show()
	else
		self.tip_text:SetText("")
		self.tip_text:Hide()
	end

	if self.itemDef.usage_data ~= nil and next(self.itemDef.usage_data) then
		local usage_string = ""

		if self.itemDef.usage_data.power then
			local power = self.player.components.powermanager:CreatePower(Power.FindPowerByName(self.itemDef.usage_data.power))

			local name = power:GetLocalizedName()
			local desc = Power.GetDescForPower(power)
			usage_string = usage_string .. Power.POWER_AS_TOOLTIP_FMT:subfmt({
					name = name,
					desc = desc,
				})
		end

		if self.itemDef.usage_data.max_uses then
			usage_string = usage_string.."\n"..string.format(STRINGS.UI.ITEMS.TOOLTIP.MAX_USES, self.itemDef.usage_data.max_uses)
		end

		self.usage_data_text:SetText(usage_string)
		self.usage_data_text:Show()
	else
		self.usage_data_text:SetText("")
		self.usage_data_text:Hide()
	end

	if self.item.ilvl then
		self.ilvl_text:SetText(string.format("%s: %s", STRINGS.UI.EQUIPMENT_STATS.ILVL.name, self.item.ilvl))
		self.ilvl_text:Show()
	else
		self.ilvl_text:SetText("")
		self.ilvl_text:Hide()
	end

	-- Update contents
	self.title_text:SetText(tt or "")

	self.title_text:LayoutBounds("left", "top", self.bg)
		:Offset(self.padding_h, -self.padding_v + 2)

	self.focus_text:LayoutBounds("left", "below", self.title_text)
		:Offset(0, -5)

	self.stats_container:LayoutChildrenInGrid(1, 5)

	self.stats_container:LayoutBounds("left", "below", self.focus_text)
		:Offset(0, -5)

	self.tip_text:LayoutBounds("left", "below", self.stats_container)
		:Offset(0, -5)

	self.usage_data_text:LayoutBounds("left", "below", self.tip_text)
		:Offset(0, -5)

	self.ilvl_text:LayoutBounds("left", "below", self.usage_data_text)
		:Offset(0, -15)

	self.bg:SizeToWidgets(40, self.container)

	self.ilvl_text:LayoutBounds("right", "bottom", self.bg)
		:Offset(0, 20)

	self.bg:SizeToWidgets(40, self.container)

	self.container:LayoutBounds("center", "center", self.bg)

	return true
end

function ItemTooltip:AddStats( statsData )
	for id, data in pairs(statsData) do
		self.stats_container:AddChild(DisplayValueHorizontal())
			:SetStat(data)
			:SetValueColour(UICOLORS.LIGHT_TEXT_DARK)
			:SetLabelColour(UICOLORS.LIGHT_TEXT)
	end

	return self
end

return ItemTooltip
