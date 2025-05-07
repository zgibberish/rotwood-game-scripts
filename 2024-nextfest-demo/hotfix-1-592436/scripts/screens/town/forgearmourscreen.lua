local ItemCodex = require("widgets/ftf/itemcodex")
local UpgradeableItemDetails = require("widgets/ftf/upgradeableitemdetails")
local Image = require("widgets/image")
local Panel = require("widgets/panel")

local Screen = require("widgets/screen")
local easing = require "util.easing"


-------------------------------------------------------------------------------------------------

local ForgeArmourScreen = Class(Screen, function(self, player)
	Screen._ctor(self, "ForgeArmourScreen")

	-- Background
	self.darken = self:AddChild(Image("images/square.tex"))
		:SetSize(RES_X, RES_Y)
		:SetMultColor(0x020201ff)
		:SetMultColorAlpha(0.5)

	self.itemCodex = self:AddChild(ItemCodex(1600, RES_Y))
		:LayoutBounds("left", "top", self.darken)
		:Offset(RES_X * 0.05, 0)
		:SetOnItemClick(function(...) self:OnItemClicked(...) end)
		:SetOnItemFocused(function(...) self:OnItemFocused(...) end)
		:SetOnBiomeChangedFn(function() self:OnBiomeChanged() end)

	self.upgradeableItemDetails = self:AddChild(UpgradeableItemDetails(1500, RES_Y))
		:SetOnUnlockFn(function() self:OnUnlockButton() end)
		:SetOnCloseFn(function() self:OnCloseButton() end)
		:LayoutBounds("after", "top", self.itemCodex)
		:Offset(-10, 0)

	-- Focus lock
	self.focused_on_creatures = true -- true if focusing on creatures, false if focusing on items
	self.itemCodex:SetFocusLock(self.focused_on_creatures)
	self.upgradeableItemDetails:SetFocusLock(not self.focused_on_creatures)

	----------------------------------------------------------------------------------
	dbassert(player)
	self:SetOwningPlayer(player)

	self.selected_widget = nil
end)

function ForgeArmourScreen:SetOwningPlayer(owningplayer)
	self.player = owningplayer -- need this for existing logic
	ForgeArmourScreen._base.SetOwningPlayer(self, owningplayer)
	self:Refresh()
end

function ForgeArmourScreen:OnBiomeChanged()
	-- The player moved to a different biome
	-- Re-apply focus to a creature
	self.focused_on_creatures = true
	self.itemCodex:SetFocusLock(self.focused_on_creatures)
	self.upgradeableItemDetails:SetFocusLock(not self.focused_on_creatures)
	if TheFrontEnd:IsRelativeNavigation() and self.itemCodex:HasCreatures() then
		self.itemCodex:FocusOnIndex(1)
		local focus = self:GetDeepestFocus()
		self:_UpdateSelectionBrackets(focus, true)
		-- local focus = self:GetDeepestFocus()
		-- self:_UpdateFocusBrackets(focus)
	end
end

function ForgeArmourScreen:OnUnlockButton()
	-- The player unlocked a creature's armor set
	-- Re-apply focus
	local focus = self.upgradeableItemDetails:GetFocusableItem()
	if TheFrontEnd:IsRelativeNavigation() and focus then
		focus:SetFocus()
		-- focus = self:GetDeepestFocus()
		-- self:_UpdateFocusBrackets(focus)
	end
end

function ForgeArmourScreen:OnItemFocused(widget, player, id, armour)
	self.selected_widget = widget
	self.upgradeableItemDetails:SetArmorData(id, armour)
		:AnimateContentsIn()
end

function ForgeArmourScreen:OnItemClicked(widget, player, id, armour)
	self.selected_widget = widget

	if self.upgradeableItemDetails:GetCurrentMonsterId() ~= id then
		self.upgradeableItemDetails:SetArmorData(id, armour)
			:AnimateContentsIn(function()
				-- Focus on button
				-- self.upgradeableItemDetails:GetFocusableItem():SetFocus()
			end)
	end

	-- Set focus on armor now
	self.focused_on_creatures = false
	self.itemCodex:SetFocusLock(self.focused_on_creatures)
	self.upgradeableItemDetails:SetFocusLock(not self.focused_on_creatures)
	local focus = self.upgradeableItemDetails:GetFocusableItem()
	if TheFrontEnd:IsRelativeNavigation() and focus then
		focus:SetFocus()
		-- focus = self:GetDeepestFocus()
		-- if focus then
		-- 	self:_UpdateFocusBrackets(focus)
		-- end
	end
end

ForgeArmourScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.CANCEL,
		fn = function(self)
			if self.focused_on_creatures then
				-- We're on the creatures side, leave the screen
				self:OnCloseButton()
			else
				-- We're on the armour side, go back to creatures
				self.focused_on_creatures = true
				self.itemCodex:SetFocusLock(self.focused_on_creatures)
				self.upgradeableItemDetails:SetFocusLock(not self.focused_on_creatures)
				if TheFrontEnd:IsRelativeNavigation() and self.itemCodex:HasCreatures() then
					self.itemCodex:FocusOnIndex(self.last_focused_creature_idx or 1)
					-- local focus = self:GetDeepestFocus()
					-- self:_UpdateFocusBrackets(focus)
				end
			end
			return true
		end,
	},
	{
		control = Controls.Digital.OPEN_INVENTORY,
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
			self:NextTab(-1)
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_TAB_NEXT,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.NEXT_TAB", Controls.Digital.MENU_TAB_NEXT))
		end,
		fn = function(self)
			self:NextTab(1)
			return true
		end,
	},

	-- Craft or upgrade items
   --  {
   --      control = Controls.Digital.Y,
   --      fn = function(self)
			-- self.upgradeableItemDetails:TriggerCraftItem("HEAD")
   --      end,
   --  },
   --  {
   --      control = Controls.Digital.X,
   --      fn = function(self)
			-- self.upgradeableItemDetails:TriggerCraftItem("BODY")
   --      end,
   --  },
   --  {
   --      control = Controls.Digital.MENU_SCREEN_ADVANCE,
   --      fn = function(self)
			-- self.upgradeableItemDetails:TriggerUnlockItemSet()
   --      end,
   --  }

}

function ForgeArmourScreen:NextTab(delta)
	-- page between biomes
	self.itemCodex:NextTab(delta)
	return self
end

function ForgeArmourScreen:Refresh()
	self.upgradeableItemDetails:Refresh(self.player)
	self.itemCodex:Refresh(self.player)
	return self
end

function ForgeArmourScreen:SetDefaultFocus()
	if not self.focused_on_creatures then
		local focus = self.upgradeableItemDetails:GetFocusableItem()
		if focus then
			focus:SetFocus()
			return true
		end
		-- else: Select from item codex below.
	end

	local focus = self.itemCodex:GetDefaultFocus()
	focus:SetFocus()
	return true
end

function ForgeArmourScreen:OnOpen()
	ForgeArmourScreen._base.OnOpen(self)

	----------------------------------------------------------------------
	-- Focus selection brackets
	self:EnableFocusBracketsForGamepad("images/ui_ftf_gems/selection_brackets.tex", 78, 94, 80, 96)
	-- self:EnableFocusBracketsForGamepadAndMouse()
	----------------------------------------------------------------------
end

function ForgeArmourScreen:OnBecomeActive()
	ForgeArmourScreen._base.OnBecomeActive(self)
	TheDungeon.HUD:Hide()

	if not self.animatedIn then
		-- Animate in the first time the screen shows up
		self:AnimateIn()
		self.animatedIn = true
	end
end

function ForgeArmourScreen:OnBecomeInactive()
	ForgeArmourScreen._base.OnBecomeInactive(self)
end

function ForgeArmourScreen:AnimateIn()
	-- Hide elements
	self.itemCodex:SetMultColorAlpha(0)

	-- Get default positions
	local rX, rY = self.itemCodex:GetPosition()

	-- Start animating
	self:RunUpdater(Updater.Series({
		-- Animate in the character panel
		Updater.Parallel({
			Updater.Ease(function(v) self.itemCodex:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
			Updater.Ease(function(v) self.itemCodex:SetPosition(v, rY) end, rX - 30, rX, 0.2, easing.inOutQuad),
		}),
	}))

	return self
end

function ForgeArmourScreen:_ShowPlayerHUD()
	assert(TheDungeon.HUD, "No HUD for closing ForgeArmourScreen.")
	TheDungeon.HUD:Show()
end

function ForgeArmourScreen:OnCloseButton()
	TheFrontEnd:PopScreen(self)
	self:_ShowPlayerHUD()
end

return ForgeArmourScreen
