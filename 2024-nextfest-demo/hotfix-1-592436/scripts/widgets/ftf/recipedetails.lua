------------------------------------------------------------------------------------------
--- Displays the selected recipe's details and action buttons
local CraftingMaterialsList = require "widgets.ftf.craftingmaterialslist"
local Widget = require "widgets.widget"
local Image = require "widgets.image"
local Panel = require "widgets.panel"
local Text = require "widgets.text"
local ImageCheckBox = require "widgets.imagecheckbox"
local ActionButton = require "widgets.actionbutton"
local fmodtable = require "defs.sound.fmodtable"
local itemcatalog = require "defs.itemcatalog"

local easing = require "util.easing"
----

local RecipeDetails = Class(Widget, function(self, player, width, ingredients_y_offset)
	Widget._ctor(self, "RecipeDetails", nil, false)

	self.width = width or 550
	self.ingredients_y_offset = ingredients_y_offset or 220 -- Vertical center of the ingredients list, starting at the bottom of the widget
	self.player = player

	-- Contains all the dialog's contents
	self.detailsContainer = self:AddChild(Widget())

	-- Header
	self.count_text = self:AddChild(Text(FONTFACE.DEFAULT, 50, "", UICOLORS.LIGHT_TEXT))
		:EnableOutline(true)
		:Hide()

	-- Item ingredients
	self.ingredientsList = self:AddChild(CraftingMaterialsList())
		:SetPlayer(self.player)
		:SetScale(2)

	-- Buttons
	self.craft_button = self:AddChild(ActionButton())
		:SetPrimary()
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:SetText(STRINGS.NPC_DIALOG.NPC_CRAFT_DIALOG_ACCEPT)
		:SetSize(self.width * 0.75, BUTTON_H * 1.1)
		:Disable()
		:SetOnClick(function()
			if self.onCraftFn then
				local skip_equip = self.equipCheckbox:IsChecked() == false
				self.onCraftFn(skip_equip)
			end
		end)
		:SetNavFocusable(false)
	self.equipCheckbox = self:AddChild(ImageCheckBox())
		:SetText(STRINGS.NPC_DIALOG.NPC_CRAFT_DIALOG_EQUIP)
		:SetMaxWidth(self.width)
		:SetImageSize(54)
		:SetTextSize(50)
		:Offset(0, 60)
		:SetNavFocusable(false)

	-- Info label
	self.info_background = self:AddChild(Panel("images/ui_ftf/InfoBackground.tex"))
		:SetNineSliceCoords(200, 86, 230, 110)
		:SetMultColorAlpha(0.3)
		:SetSize(self.width * 0.75, BUTTON_H * 1.1)
		:Hide()
	self.info_text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT, "", UICOLORS.LIGHT_TEXT_DARKER))
		:Hide()

	return self
end)

function RecipeDetails:SetPlayer(player)
	self.player = player

	self.ingredientsList:SetPlayer(player)

	self.inst:ListenForEvent("inventory_stackable_changed", function(owner, itemDef)
		self:OnInventoryChanged()
	end, self.player)

	return self
end

function RecipeDetails:SetSlot(slot)
	if self.slot == slot then return end
	self.slot = slot
	return self
end

function RecipeDetails:IsAnimating()
	-- See ShowCraftedAnimation's use of IgnoreInput.
	return self.craft_button.ignore_input
end

function RecipeDetails:CanCraft()
	return (self.craft_button:IsEnabled()
		and self.craft_button:IsVisible()
		and not self:IsAnimating())
end

function RecipeDetails:SetOnCraftFn(fn)
	self.onCraftFn = fn
	return self
end

function RecipeDetails:SetRecipe(recipeData)
	self.recipeData = recipeData

	if recipeData.count > 1 then
		self.count_text:SetText(string.format(STRINGS.UI.RECIPESCREEN.ITEM_COUNT, recipeData.count))
			-- :Show()
			:LayoutBounds("after", "center", self.icon_root)
			:Offset(30, 0)
	end

	-- Update the materials based on the player's inventory
	self:OnInventoryChanged()

	self:Layout()
	return self
end

--- The player's inventory changed. Update the ingredients accordingly
function RecipeDetails:OnInventoryChanged()
	-- Refresh ingredients
	self.ingredientsList:SetIngredients(self.recipeData.ingredients)

	-- Check if the player can craft this
	local can_craft, display_message = self.recipeData:CanPlayerCraft(self.player)
	if can_craft then
		self.craft_button:Enable()
			:Show()
		self.equipCheckbox:Show()
		self.info_background:Hide()
		self.info_text:Hide()
	else
		self.craft_button:Disable()
			:Hide()
		self.equipCheckbox:Hide()
		self.info_background:Show()
		self.info_text:SetText(display_message)
			:LayoutBounds("center", "center", self.info_background)
			:Show()
	end

	return self
end

function RecipeDetails:Layout()
	self.equipCheckbox:Enable()

	self.equipCheckbox:LayoutBounds("center", "bottom", 0, 0)
	self.craft_button:LayoutBounds("center", "above", self.equipCheckbox)
		:Offset(0, 20)
	self.info_background:LayoutBounds("center", "center", self.craft_button)
	self.info_text:LayoutBounds("center", "center", self.info_background)
	self.ingredientsList:LayoutBounds("center", "center", 0, 0)
		:Offset(0, self.ingredients_y_offset)

	local slot = self.recipeData.def.slot
	local can_equip = itemcatalog.All.SlotDescriptor[slot] and itemcatalog.All.SlotDescriptor[slot].tags.equippable

	if not can_equip then
		self.equipCheckbox:SetValue(false, true)
		self.equipCheckbox:Disable()
	end

	return self
end

function RecipeDetails:ShowCraftedAnimation(recipeData, onDoneFn)

	-- Disable inputs
	self.craft_button:IgnoreInput()
	self.equipCheckbox:IgnoreInput()

	--sound
	if recipeData.def.sound_events and recipeData.def.sound_events.craft then
		TheFrontEnd:GetSound():PlaySound(fmodtable.Event[recipeData.def.sound_events.craft])
	end

	-- Create new container widget for our animation elements
	self.dialogAnimationContainer = self:AddChild(Widget())

	-- Create an icon for the item we're making
	local craftedItemIcon = self.dialogAnimationContainer:AddChild(Image(recipeData.def.icon))
		:SetSize(90 * HACK_FOR_4K, 90 * HACK_FOR_4K)
		:SetMultColorAlpha(0)
		:LayoutBounds("center", "center", self.craft_button)
		:Offset(0, -40)
	local iconX, iconY = craftedItemIcon:GetPosition()

	-- Create an icon name for the animation
	local craftedItemName = self.dialogAnimationContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_TITLE))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetText(recipeData.def.pretty.name)
		:SetMultColorAlpha(0)
		:SetHAlign(ANCHOR_MIDDLE)
		:LayoutBounds("center", "below", craftedItemIcon)
		:Offset(0, 20)
	local titleX, titleY = craftedItemName:GetPosition()

	-- And a subtitle
	local subtitle = self.dialogAnimationContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetText(STRINGS.NPC_DIALOG.NPC_CRAFT_CRAFTED)
		:SetMultColorAlpha(0)
		:SetHAlign(ANCHOR_MIDDLE)
		:LayoutBounds("center", "below", craftedItemName)
		:Offset(0, 0)
	local subtitleX, subtitleY = subtitle:GetPosition()

	local container_x, container_y = self.dialogAnimationContainer:GetPosition()

	-- Hide panel contents
	self:RunUpdater(Updater.Series{

		Updater.Ease(function(v)
			self.craft_button:SetMultColorAlpha(v)
			self.equipCheckbox:SetMultColorAlpha(v)
		end, 1, 0, 0.2, easing.outQuad),

		Updater.Wait(0.2),

		Updater.Parallel({
			-- Fade in
			Updater.Ease(function(v) craftedItemIcon:SetMultColorAlpha(v) end, 0, 1, 0.5, easing.outQuad),
			Updater.Ease(function(v) craftedItemName:SetMultColorAlpha(v) end, 0, 1, 0.5, easing.outQuad),
			-- Move
			Updater.Ease(function(v) craftedItemIcon:SetPosition(iconX, v) end, iconY, iconY + 30, 0.6, easing.outQuad),
			Updater.Ease(function(v) craftedItemName:SetPosition(titleX, v) end, titleY, titleY - 10, 0.6, easing.outQuad),
			-- Scale in
			Updater.Ease(function(v) craftedItemIcon:SetScale(v, v) end, 1, 1.4, 0.8, easing.outQuad),
		}),

		Updater.Wait(0.4),

		Updater.Parallel({
			-- Fade in
			Updater.Ease(function(v) subtitle:SetMultColorAlpha(v) end, 0, 1, 0.5, easing.outQuad),
			-- Move
			Updater.Ease(function(v) subtitle:SetPosition(subtitleX, v) end, subtitleY, subtitleY - 10, 0.6, easing.outQuad),
		}),

		Updater.Wait(1.2),

		Updater.Do(function()
			if onDoneFn then onDoneFn() end

			-- Update the materials based on the player's inventory
			self:OnInventoryChanged()
		end),

		Updater.Parallel({
			-- Fade out
			Updater.Ease(function(v) self.dialogAnimationContainer:SetMultColorAlpha(v) end, 1, 0, 0.2, easing.outQuad),
			-- Move
			Updater.Ease(function(v) self.dialogAnimationContainer:SetPosition(container_x, v) end, container_y, container_y + 10, 0.2, easing.outQuad),
		}),

		-- Start resetting everything back

		Updater.Ease(function(v)
			self.craft_button:SetMultColorAlpha(v)
			self.equipCheckbox:SetMultColorAlpha(v)
		end, 0, 1, 0.1, easing.outQuad),

		Updater.Do(function()
			-- Make stuff work again
			self.craft_button:IgnoreInput(false)
			self.equipCheckbox:IgnoreInput(false)

			-- Remove animation panel
			self.dialogAnimationContainer:Remove()
			self.dialogAnimationContainer = nil
		end)
	})

	return self
end

return RecipeDetails
