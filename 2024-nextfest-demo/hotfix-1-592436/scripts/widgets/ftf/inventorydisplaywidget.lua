local Widget = require("widgets/widget")
local Panel = require("widgets/panel")
local Image = require("widgets/image")
local Text = require("widgets/text")

local Consumable = require "defs.consumable"

------------------------------------------------------------------------------------
-- Panel displaying available unlocks and upgrades from a given creature

local InventoryDisplayWidget = Class(Widget, function(self, w, h)
	Widget._ctor(self, "InventoryDisplayWidget")

	self.width = w
	self.height = h
	self.icon_size = 140
	self.name_size = FONTSIZE.SCREEN_TEXT
	self.count_size = self.name_size * 1.2
	self.name_color = UICOLORS.LIGHT_TEXT
	self.count_color = UICOLORS.LIGHT_TEXT

	self.bg = self:AddChild(Panel("images/ui_ftf_research/inventory_bg.tex"))
		:SetName("Background")
		:SetNineSliceCoords(24, 30, 44, 55)
		:SetSize(self.width, self.height)

	self.items_root = self:AddChild(Widget())
		:SetName("Items root")

	self.inventory_icon = self:AddChild(Image("images/ui_ftf_research/inventory_icon.tex"))
		:SetName("Inventory icon")
		:SetHiddenBoundingBox(true)

	self:Layout()
end)

function InventoryDisplayWidget:SetIconSize(icon_size)
	self.icon_size = icon_size or 125
	return self
end

function InventoryDisplayWidget:SetFontSize(name_size, count_size)
	self.name_size = name_size or FONTSIZE.SCREEN_TEXT
	self.count_size = count_size or (self.name_size  * 1.2)
	return self
end

function InventoryDisplayWidget:Refresh(player, items)
	self.player = player
	self.items = items

	-- Remove old items
	self.items_root:RemoveAllChildren()

	-- Add new ones
	for k, id in ipairs(items) do
		local mat_def = Consumable.Items.MATERIALS[id]
		local count = self.player.components.inventoryhoard:GetStackableCount(mat_def)

		-- Create widget
		local widget = self.items_root:AddChild(Widget())
			:SetName("Inventory item")
			:SetToolTip(mat_def.pretty.name)

		-- Add an icon
		local icon = widget:AddChild(Image(mat_def.icon))
			:SetName("Icon")
			:SetSize(self.icon_size, self.icon_size)

		-- Add text
		local text_container = widget:AddChild(Widget())
			:SetName("Text container")
		local name_label = text_container:AddChild(Text(FONTFACE.DEFAULT, self.name_size, mat_def.pretty.name, self.name_color))
		local count_label = text_container:AddChild(Text(FONTFACE.DEFAULT, self.count_size, count, self.count_color))
			:LayoutBounds("left", "below", name_label)
			:Offset(0, 3)

		text_container:LayoutBounds("after", "center", icon)
			:Offset(5, 0)
	end

	self:Layout()
	return self
end

function InventoryDisplayWidget:Layout()

	self.inventory_icon:LayoutBounds("left", "top", self.bg)
		:Offset(-50, 30)
	self.items_root:LayoutChildrenInColumn(100, "center")
		:LayoutBounds("center", "center", self.bg)

	return self
end

return InventoryDisplayWidget