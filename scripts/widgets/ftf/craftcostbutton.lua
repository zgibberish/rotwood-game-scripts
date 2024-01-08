local Consumable = require "defs.consumable"
local Image = require("widgets/image")
local ImageButton = require "widgets.imagebutton"
local Text = require("widgets/text")
local Widget = require "widgets.widget"
local itemforge = require "defs.itemforge"

local CraftCostButton = Class(Widget, function(self, item_icon, item_name, hoard, ingredients)
    Widget._ctor(self, "CraftCostButton")

	-- TODO(dbriscoe): Why is there so much scaling? Can we do without it?

	local scaleX, scaleY = 0.625, 0.15
	self.btn = self:AddChild(ImageButton("images/ui_ftf/bg_grey.tex", "images/ui_ftf/bg_alpha.tex"))
		:SetScale(scaleX, scaleY)
		:SetTextColour(UICOLORS.GREY)
		:SetTextFocusColour(UICOLORS.GOLD_FOCUS)
		:SetTextSelectedColour(UICOLORS.GOLD_SELECTED)
		:SetFont(FONTFACE.BUTTON)
		:SetMultColor(1, 1, 1)
	self.btn.scale_on_focus = false

	-- Making this a child of the button so that the image doesn't capture
	-- mouse clicks... is there a better way to do this?
	local weaponItemIcon = self.btn:AddChild(Image(item_icon))
		:LayoutBounds("left", "center", self.btn)
		:SetScale(1 / scaleX * 0.5, 1 / scaleY * 0.5)
		:IgnoreParentMultColor()

	-- Need to ask Kaj later about this. Using offset instead of
	-- setPosition causes text to not be aligned (because of the setScale?)
	self.weaponItemName = self.btn:AddChild(Text(FONTFACE.BUTTON, FONTSIZE.BUTTON, item_name, UICOLORS.WHITE))
		:LayoutBounds("after", "top", weaponItemIcon)
		:SetScale(1 / scaleX, 1 / scaleY)
		:SetPosition(120, 260)
		:SetRegionSize(460, 40)
		:SetHAlign(ANCHOR_LEFT)
		:IgnoreParentMultColor()

	-- Required materials
	self.requiredMaterialsPanel = self.btn:AddChild(Widget())
		:LayoutBounds("left", "below", self.weaponItemName)
		:SetScale(1 / scaleX, 1 / scaleY)
		:Offset(40, -260)
		:IgnoreParentMultColor()

	for ing_name,needs in pairs(ingredients) do
		local requirement = self.requiredMaterialsPanel:AddChild(Widget())

		local ing_def = Consumable.Items.MATERIALS[ing_name]
		local ing_item = itemforge.CreateStack(Consumable.Slots.MATERIALS, ing_def)

		local requiredMaterialIcon = requirement:AddChild(Image(ing_def.icon))
			:SetScale(0.5)
		requiredMaterialIcon:SetToolTip(ing_item:GetLocalizedName())

		local count = hoard:GetStackableCount(ing_def)
		local hasRequiredMaterials = count >= needs
		local requiredMaterialTextColor = hasRequiredMaterials and UICOLORS.WHITE or UICOLORS.RED

		requirement.requiredMaterialQuantity = requirement:AddChild(Text(FONTFACE.BUTTON, FONTSIZE.BUTTON, "x " .. needs, requiredMaterialTextColor))
			:LayoutBounds("after", "center", requiredMaterialIcon)
			:Offset(10, 0)
	end

	self.requiredMaterialsPanel:LayoutChildrenInGrid(3, 20)
end)

function CraftCostButton:SetOnClick(...)
	self.btn:SetOnClick(...)
end

function CraftCostButton:Click(...)
	self.btn:Click(...)
end

return CraftCostButton
