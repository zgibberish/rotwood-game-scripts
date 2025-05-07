local Screen = require("widgets/screen")
local CraftingPanel = require("widgets/ftf/craftingpanel")
local RecipeDetailsPanel = require("widgets/ftf/recipedetailspanel")
local EquipmentPanel = require("widgets/ftf/equipmentpanel")

local camerautil = require "util.camerautil"
local easing = require "util.easing"
local fmodtable = require "defs.sound.fmodtable"

local itemforge = require "defs.itemforge"
require "class"

------------------------------------------------------------------------------------------
--- This is a base screen for making screens that apply recipes.
local RecipeScreen = Class(Screen, function(self, screen_name, player, equipment_slots)
	Screen._ctor(self, screen_name)

	-- TODO(audio): We should set these sounds on these screens instead of
	-- using the names. One typo and it doesn't work as expected.
	if screen_name == "CreateElixirScreen" then
		self.show_sound = fmodtable.Event.apothecaryScreen_show
		self.hide_sound =  fmodtable.Event.apothecaryScreen_hide
	elseif screen_name == "FoodScreen" then
		self.show_sound = fmodtable.Event.foodScreen_show
		self.hide_sound =  fmodtable.Event.foodScreen_hide
	elseif screen_name == "ForgeArmourScreen" then
		self.show_sound = fmodtable.Event.forgeArmorScreen_show
		self.hide_sound =  fmodtable.Event.forgeArmorScreen_hide
	elseif screen_name == "ForgeWeaponScreen" then
		self.show_sound = fmodtable.Event.forgeWeaponScreen_show
		self.hide_sound =  fmodtable.Event.forgeWeaponScreen_hide
	else
		self.show_sound = fmodtable.Event.recipeScreen_show
		self.hide_sound = fmodtable.Event.recipeScreen_hide
	end


	self.player = player

	assert(equipment_slots)

	self.equipmentPanel = self:AddChild(EquipmentPanel())
		:Refresh(self.player)
		-- :SetOnCategoryClickFn(function(slot_key) self:OnEquipmentSlotClicked(slot_key) end)
		:LayoutBounds("before", nil, -400, 0)

	self.recipeDetailsPanel = self:AddChild(RecipeDetailsPanel())
		:LayoutBounds("after", nil, self.equipmentPanel)
		:SetOnCraftedFn(function() self.equipmentPanel:Refresh(self.player) end)
		:SetPlayer(player)

	self.craftingPanel = self:AddChild(CraftingPanel(player, equipment_slots))
		:SetOnCloseFn(function() self:OnCloseButton() end)
		:SetOnCategoryClickFn(function(slot_data) self:OnCategoryClicked(slot_data) end)
		:LayoutBounds("after", nil, self.recipeDetailsPanel)
		:SetOnRecipeSelectedFn(function(recipeData)
			self.recipeDetailsPanel:SetRecipe(recipeData)
			-- Update the character panel
			-- local dummy_item = itemforge.CreateEquipment(recipeData.slot, recipeData.def)
			-- self.equipmentPanel:EquipItem(recipeData.slot, dummy_item)
		end)
end)

function RecipeScreen:SetDefaultFocus()
	return self.craftingPanel:SetDefaultFocus()
end

RecipeScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.MENU_SCREEN_ADVANCE,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.ACCEPT", Controls.Digital.MENU_SCREEN_ADVANCE))
		end,
		fn = function(self)
			if self.recipeDetailsPanel:CanCraft() then
				local skip_equip = self.recipeDetailsPanel.recipeDetails.equipCheckbox:IsChecked() == false
				self.recipeDetailsPanel:OnClickCraftButton(skip_equip)
				return true
			end
		end,
	},
	{
		control = Controls.Digital.CANCEL,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.CANCEL", Controls.Digital.CANCEL))
		end,
		fn = function(self)
			self:OnCloseButton()
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_TAB_PREV,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.PREV_TAB", Controls.Digital.MENU_TAB_PREV))
		end,
		fn = function(self)
			-- TODO(dbriscoe): POSTVS I think we should disable TabGroup and
			-- all the tabs when animating.
			if not self.recipeDetailsPanel:_IsAnimating() then
				self.craftingPanel:NextTab(-1)
			end
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_TAB_NEXT,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.NEXT_TAB", Controls.Digital.MENU_TAB_NEXT))
		end,
		fn = function(self)
			if not self.recipeDetailsPanel:_IsAnimating() then
				self.craftingPanel:NextTab(1)
			end
			return true
		end,
	},
}

function RecipeScreen:SetTitle(title)
	self.craftingPanel:SetTitle(title)
	return self
end

function RecipeScreen:OnEquipmentSlotClicked(slot_key)
	self.craftingPanel:SetTitle(string.format(STRINGS.UI.FORGEWEAPONSCREEN.PANEL_TITLE, STRINGS.ITEM_CATEGORIES[slot_key]))
	self.craftingPanel:SetCurrentCategory(slot_key)
	return self
end

function RecipeScreen:OnCategoryClicked(slot_data)
	self.craftingPanel:SetTitle(string.format(STRINGS.UI.FORGEWEAPONSCREEN.PANEL_TITLE, STRINGS.ITEM_CATEGORIES[slot_data.key]))
	self.craftingPanel:SetCurrentCategory(slot_data.key)
	return self
end

function RecipeScreen:OnCloseButton()
	self:AnimateOut()
end

function RecipeScreen:OnBecomeActive()
	RecipeScreen._base.OnBecomeActive(self)

	--sound snapshot
	TheAudio:StartFMODSnapshot(fmodtable.Snapshot.MenuOverlay)

	TheDungeon.HUD:Hide()
	self.craftingPanel:ClickFirstSlot()

	self:AnimateIn()
end

function RecipeScreen:_ShowPlayerHUD()
	assert(TheDungeon.HUD, "No HUD for closing screen.")
	TheDungeon.HUD:Show()
end

function RecipeScreen:OnBecomeInactive()
	--sound snapshot
	TheAudio:StopFMODSnapshot(fmodtable.Snapshot.MenuOverlay)

	RecipeScreen._base.OnBecomeInactive(self)
	camerautil.ReleaseCamera(self.player)
end

function RecipeScreen:AnimateIn()

	--sound
	TheFrontEnd:GetSound():PlaySound(self.show_sound)

	-- Hide elements
	self.equipmentPanel:SetMultColorAlpha(0)
	self.recipeDetailsPanel:SetMultColorAlpha(0)
	self.craftingPanel:SetMultColorAlpha(0)

	-- Get default positions
	local csX, csY = self.equipmentPanel:GetPosition()
	local rdpX, rdpY = self.recipeDetailsPanel:GetPosition()
	local cpX, cpY = self.craftingPanel:GetPosition()

	-- Start animating
	self:RunUpdater(Updater.Series({

		-- -- Select the first item on the list
		Updater.Do(function()
			self.craftingPanel:OnFinishAnimate()
		end),

		Updater.Parallel({
			Updater.Ease(function(v) self.equipmentPanel:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
			Updater.Ease(function(v) self.equipmentPanel:SetPosition(v, csY) end, csX - 30, csX, 0.2, easing.inOutQuad),
		}),

		-- Animate in the character panel
		Updater.Parallel({
			Updater.Ease(function(v) self.recipeDetailsPanel:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
			Updater.Ease(function(v) self.recipeDetailsPanel:SetPosition(v, rdpY) end, rdpX - 30, rdpX, 0.2, easing.inOutQuad),
		}),

		-- Animate in the inventory panel
		Updater.Parallel({
			Updater.Ease(function(v) self.craftingPanel:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
			Updater.Ease(function(v) self.craftingPanel:SetPosition(v, cpY) end, cpX + 30, cpX, 0.2, easing.inOutQuad),
		}),

	}))
end

function RecipeScreen:AnimateOut()
	-- Get default positions
	local rootX, rootY = self.craftingPanel:GetPosition()

	-- sound
	TheFrontEnd:GetSound():PlaySound(self.hide_sound)

	-- Start animating
	self:RunUpdater(Updater.Series({

		-- Animate the root
		Updater.Parallel({
			Updater.Ease(function(v) self.craftingPanel:SetMultColorAlpha(v) end, 1, 0, 0.1, easing.inOutQuad),
			Updater.Ease(function(v) self.craftingPanel:SetPosition(v, rootY) end, rootX, rootX - 40, 0.2, easing.inOutQuad),
		}),

		Updater.Do(function()
			TheFrontEnd:PopScreen(self)
			self:_ShowPlayerHUD()
		end)

	}))

	
end

return RecipeScreen
