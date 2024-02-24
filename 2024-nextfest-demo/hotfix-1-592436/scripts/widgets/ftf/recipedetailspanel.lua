local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Panel = require("widgets/panel")
local RecipeDetails = require"widgets.ftf.recipedetails"
local RecipeIconHeader = require"widgets.ftf.recipeiconheader"
local ItemDetails = require "widgets.ftf.itemdetails"
local ItemStats = require("widgets/ftf/itemstats")
local Text = require("widgets/text")

local itemforge = require "defs.itemforge"

------------------------------------------------------------------------------------------
--- Displays a panel with detailed information about a specific recipe

local RecipeDetailsPanel = Class(Widget, function(self)
	Widget._ctor(self, "RecipeDetailsPanel")

	self.width = 800
	self.contentWidth = self.width - 50
	self.height = RES_Y

	-- Background
	self.bg = self:AddChild(Image("images/ui_ftf_crafting/CraftPanelBg.tex"))
		:SetSize(self.width, self.height)

	-- Recipe item icon
	local max_width = self.width*0.85
	self.recipe_icon = self:AddChild(RecipeIconHeader(max_width))

	-- Recipe item stats
	self.item_stats = self:AddChild(ItemStats(self.width - 100))
		:ShowStatNames(true)
		:SetMaxColumns(1)

	-- Crafting details
	self.recipeDetails = self:AddChild(RecipeDetails(self.player, self.width - 100, 330))
		:SetOnCraftFn(function(skip_equip) self:OnClickCraftButton(skip_equip) end)
		:Hide()

	-- self:ApplySkin()
	self:Layout()
end)

function RecipeDetailsPanel:SetPlayer(player)
	self.player = player
	self.recipeDetails:SetPlayer(player)
	self.item_stats:SetPlayer(player)
	return self
end

function RecipeDetailsPanel:SetRecipe(recipe)

	self.recipeData = recipe
	self.recipeDef = recipe.def
	self.dummy_item = itemforge.CreateEquipment(self.recipeData.slot, self.recipeData.def)

	self.recipe_icon:SetRecipe(self.recipeData)
	self.item_stats:SetItem(self.recipeData.slot, self.dummy_item)

	self.recipeDetails:SetSlot( self.recipeData.slot )
	self.recipeDetails:SetRecipe(self.recipeData)
	self.recipeDetails:Show()

	self:Layout()
end

function RecipeDetailsPanel:SetOnCraftedFn(fn)
	self.onCraftedFn = fn
	return self
end

function RecipeDetailsPanel:OnClickCraftButton(skip_equip)
	self.recipeDetails:ShowCraftedAnimation(self.recipeData)
	self.recipeData:CraftItemForPlayer(self.player, skip_equip)
	if self.onCraftedFn then self.onCraftedFn() end
end

function RecipeDetailsPanel:_IsAnimating()
	return self.recipeDetails:IsAnimating()
end

function RecipeDetailsPanel:CanCraft()
	return self.recipeDetails:CanCraft()
end

function RecipeDetailsPanel:ApplySkin()

	self.skinPanelIllustration:SetTexture(self.skinDirectory .. "panel_armour_1.tex")

	-- Add a second illustration
	self.skinPanelIllustration2 = self.root:AddChild(Image(self.skinDirectory .. "panel_armour_2.tex"))
		:SetHiddenBoundingBox(true)

	self.skinPanelIllustration2:RunUpdater(Updater.Loop({
		Updater.Series({
			Updater.Ease(function(v) self.skinPanelIllustration2:SetRotation(v) end, 3, -5, 7, easing.inOutQuad),
			Updater.Wait(0.4),
			Updater.Ease(function(v) self.skinPanelIllustration2:SetRotation(v) end, -5, 3, 7.5, easing.inOutQuad),
		})
	}))

	return self
end

function RecipeDetailsPanel:Layout()
	self.recipe_icon:LayoutBounds("center", "top", self.bg)
		:Offset(0, -100)
	self.item_stats:LayoutBounds("center", "center", 0, 140)
	self.recipeDetails:LayoutBounds("center", "bottom", self.bg)
		:Offset(0, 250)
	return self
end

return RecipeDetailsPanel