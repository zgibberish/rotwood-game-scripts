local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")

-------------------------------------------------------------------------------------------------
--- Displays a series of dots showing the upgrade status of this item
local ItemUpgradeDisplayWidget = Class(Widget, function(self, height, colour)
	Widget._ctor(self, "ItemUpgradeDisplayWidget")

	self.circleHeight = height or self.HEIGHT
	self.upgradeColour = colour or UICOLORS.ITEM_DARK

	-- Assemble widget
	self.label = self:AddChild(Text(FONTFACE.DEFAULT, 30 * HACK_FOR_4K, "", self.upgradeColour))
	self.container = self:AddChild(Widget())

end)

ItemUpgradeDisplayWidget.HEIGHT = 80 * HACK_FOR_4K

function ItemUpgradeDisplayWidget:SetItem(categoryData, itemData)
	if itemData and itemData.upgradeLevel and itemData.maxUpgradeLevel > 1 then
	    -- Update label
	    self.label:SetText(string.format(STRINGS.UI.INVENTORYSCREEN.UPGRADE_WIDGET, itemData.upgradeLevel, itemData.maxUpgradeLevel))
	    -- Remove old dots
	    self.container:RemoveAllChildren()
	    -- Add new ones
	    for i = 1, itemData.maxUpgradeLevel do
			local dot = self.container:AddChild(Image("images/ui_ftf_shop/"..(itemData.upgradeLevel >= i and "item_upgrade_full.tex" or "item_upgrade_empty.tex")))
				:SetSize(self.circleHeight, self.circleHeight)
				:SetMultColor(self.upgradeColour)
			if i > 1 then
				dot:LayoutBounds("after", nil)
					:Offset(-1, 0)
			end
			-- Add a connector to the previous icon?
			if i < itemData.maxUpgradeLevel then
				local connector = self.container:AddChild(Image("images/ui_ftf_shop/item_upgrade_connector.tex"))
					:SetSize(self.circleHeight * 0.3, self.circleHeight)
					:SetMultColor(self.upgradeColour)
					:LayoutBounds("after", nil)
					:Offset(-1, 0)
			end
	    end
	    -- Layout text
	    self.container:LayoutBounds("after", "center", self.label)
	    	:Offset(self.circleHeight * 0.2, 0)
	else
	    self.label:SetText("")
	    self.container:RemoveAllChildren()
	end
    return self
end


function ItemUpgradeDisplayWidget:ShowLabel(show)
	self.label:SetShown(show)
	return self
end


function ItemUpgradeDisplayWidget:SetColour(colour)
	-- Save colour
	self.upgradeColour = colour or UICOLORS.ITEM_DARK

	-- Update widgets
	self.label:SetGlyphColor(self.upgradeColour)
	for k, v in ipairs(self.container.children) do
		v:SetMultColor(self.upgradeColour)
	end

	return self
end

return ItemUpgradeDisplayWidget
