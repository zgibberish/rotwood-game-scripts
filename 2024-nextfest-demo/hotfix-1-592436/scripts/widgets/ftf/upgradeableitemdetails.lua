local Widget = require("widgets/widget")
local Image = require("widgets/image")
local ActionButton = require("widgets/actionbutton")
local ImageButton = require("widgets/imagebutton")
local CraftingMaterialsList = require("widgets/ftf/craftingmaterialslist")
local UpgradeableItemWidget = require("widgets/ftf/upgradeableitemwidget")
local InventoryDisplayWidget = require("widgets/ftf/inventorydisplaywidget")
local ItemUnlockPopup = require "screens.itemunlockpopup"
local Text = require("widgets/text")
local fmodtable = require "defs.sound.fmodtable"

local recipes = require "defs.recipes"
local itemforge = require "defs.itemforge"
local Equipment = require("defs.equipment")

local easing = require "util.easing"
local lume = require"util/lume"
local itemutil = require"util.itemutil"

------------------------------------------------------------------------------------
-- Panel displaying available unlocks and upgrades from a given creature
--
-- ┌──────────────────────────────────────────────────────┐ ◄ bg
-- │    ┌───────────────────────────────────────────┐   ┌─┴─┐
-- │    │ text_root                                 │   │ X │ ◄ close_button
-- │    │  title                                    │   └─┬─┘
-- │    │  desc                                     │     │
-- │    └───────────────────────────────────────────┘     │
-- │ ┌────────────────────────────────────────────────────┴─┐
-- │ │ items_root                                           │
-- │ │ ┌────────────────────────────────────────────────────┤
-- │ │ │ UpgradeableItemWidget                              │
-- │ │ │                                                    │
-- │ │ │                                                    │
-- │ │ └────────────────────────────────────────────────────┤
-- │ │ ┌────────────────────────────────────────────────────┤
-- │ │ │ UpgradeableItemWidget                              │
-- │ │ │                                                    │
-- │ │ │                                                    │
-- │ │ └────────────────────────────────────────────────────┤
-- │ └────────────────────────────────────────────────────┬─┘
-- │          ┌────────────────────────────────┐          │ ◄ only gets shown if
-- │          │ empty_banner                   │          │   this creature hasn't
-- │          │  empty_label                   │          │   been found by the player
-- │          └────────────────────────────────┘          │
-- │   ┌───────────────────┬─────┬────────────────────┐   │ ◄ only gets shown if this
-- │   │ unlock_widget     │     │◄ unlock_icon       │   │   creature has been seen by
-- │   │                   │     │                    │   │   the player, but the recipes
-- │   │                   └─────┘                    │   │   haven't been unlocked
-- │   │                unlock_label                  │   │
-- │   ├──────────────────────────────────────────────┤   │
-- │   │ unlock_footer                                │   │
-- │   │    ┌───┐  ┌───┐  ┌───┐  ┌───────────────┐    │   │
-- │   │    │   │  │   │  │   │  │    Unlock!    │    │   │
-- │   │    └───┘  └───┘  └───┘  └───────────────┘    │   │
-- │   │    ▲ unlock_materials    ▲ unlock_button     │   │
-- │   └──────────────────────────────────────────────┘   │
-- │    ┌────────────────────────────────────────────┐    │ ◄ Displays relevant player
-- │    │ InventoryDisplayWidget                     │    │   inventory items and amounts
-- │    │                                            │    │
-- └────┴────────────────────────────────────────────┴────┘
--

local UpgradeableItemDetails = Class(Widget, function(self, w, h)
	Widget._ctor(self, "UpgradeableItemDetails")

	self.width = w
	self.height = h

	self.bg = self:AddChild(Image("images/bg_research_screen_right/research_screen_right.tex"))
		:SetName("Background")
		:SetSize(self.width, self.height)

	self.close_button = self:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetName("Close button")
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		:LayoutBounds("right", "top", self.bg)
		:Offset(20, -50)

	self.text_root = self:AddChild(Widget())
	self.title = self.text_root:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TITLE, "", UICOLORS.LIGHT_TEXT))
		:SetName("Title")
		:SetAutoSize(self.width * 0.5)
	self.desc = self.text_root:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT, "", UICOLORS.LIGHT_TEXT_DARKER))
		:SetAutoSize(self.width * 0.5)

	-- Empty banner
	self.empty_banner = self:AddChild(Widget())
		:SetName("Empty banner")
		:Hide()
	self.empty_bg = self.empty_banner:AddChild(Image("images/ui_ftf_research/research_banner.tex"))
		:SetName("Background")
		:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_DARK)
		:SetRotation(1)
	local bg_w, bg_h = self.empty_bg:GetSize()
	local target_w = self.width * 0.5
	local ratio = target_w/bg_w
	self.empty_bg:SetScale(ratio)
	self.empty_label = self.empty_banner:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT, STRINGS.UI.RESEARCHSCREEN.ARMOR_LOCKED_DESCRIPTION, UICOLORS.LIGHT_TEXT_DARKER))
		:SetAutoSize(self.width * 0.5 - 160)
		:LayoutBounds("center", "center", self.empty_bg)

	-- Unlock widget
	-- self.unlock_widget = self:AddChild(Widget())
	-- 	:SetName("Unlock widget")
	-- 	:SetNavFocusable(true)
	-- self.unlock_bg = self.unlock_widget:AddChild(Image("images/ui_ftf_research/research_banner.tex"))
	-- 	:SetName("Background")
	-- 	:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_LIGHT)
	-- 	:SetRotation(1)
	-- 	:SetScale(2.2)
	-- self.unlock_icon = self.unlock_widget:AddChild(Image("images/ui_ftf_research/research_widget_lock.tex"))
	-- 	:SetName("Icon")
	-- 	:SetMultColor(UICOLORS.LIGHT_TEXT_DARKER)
	-- 	:SetSize(90, 90)
	-- self.unlock_label = self.unlock_widget:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT, STRINGS.UI.RESEARCHSCREEN.UNLOCK_LABEL, UICOLORS.LIGHT_TEXT_DARKER))
	-- 	:SetAutoSize(self.width * 0.5)
	-- 	:LayoutBounds("center", "center", self.empty_bg)
	-- self.unlock_footer = self.unlock_widget:AddChild(Widget())
	-- 	:SetName("Unlock footer")
	-- self.unlock_materials = self.unlock_footer:AddChild(CraftingMaterialsList(125, FONTSIZE.SCREEN_TEXT * 1.4))
	-- 	:SetName("Materials list")
	-- 	:SetTextColor(UICOLORS.BACKGROUND_DARK, UICOLORS.PENALTY)
	-- self.unlock_button = self.unlock_footer:AddChild(ActionButton())
	-- 	:SetName("Button")
	-- 	:SetNavFocusable(false) -- rely on CONTROL_MAP
	-- 	:SetText(string.format(STRINGS.UI.RESEARCHSCREEN.BTN_UNLOCK))
	-- 	:SetScaleOnFocus(false)
	-- 	:SetPrimary()
	-- 	:SetScale(0.7)
	-- 	:SetNormalScale(0.7)
	-- 	:SetFocusScale(0.7)
	-- 	:SetControlDownSound(fmodtable.Event.unlock_new_armour)
	-- 	:SetControlUpSound(nil)

	self.items_root = self:AddChild(Widget("Items Root"))
	self.slot_items = {}

	self.inventory_display = self:AddChild(InventoryDisplayWidget(400, self.height * 0.5))
		:SetName("Inventory display")

	self:Layout()
end)

function UpgradeableItemDetails:Refresh(player)
	self.player = player
	-- self.unlock_materials:SetPlayer(self.player)
	-- self.unlock_button:SetEnabled(self.recipe and self.recipe:CanPlayerCraft(self.player))
	self:Layout()
end

function UpgradeableItemDetails:GetFocusableItem()
	-- if self.unlock_widget:IsShown() then
		-- return self.unlock_widget
	if self.items_root:HasChildren() then
		for _, child in pairs(self.items_root.children) do
			if child:IsShown() then
				return child:GetDefaultFocus()
			end
		end
	end
	if self.empty_banner:IsVisible() then
		return self.empty_banner
	end
end

function UpgradeableItemDetails:GetCurrentMonsterId()
	return self.monster_id
end


function UpgradeableItemDetails:SetArmorData(monster_id, armour_items)
	self.monster_id = monster_id
	self.armour_items = armour_items
	self.recipe = recipes.FindRecipeForItem('armour_unlock_'..self.monster_id)

	self.title:SetText(string.format(STRINGS.UI.RESEARCHSCREEN.ARMOR_TITLE, STRINGS.NAMES[monster_id]))
	self.desc:SetText(string.format(STRINGS.UI.RESEARCHSCREEN.ARMOR_DESCRIPTION, STRINGS.NAMES[monster_id]))

	-- Check if this monster is locked or unlocked
	local monster_unlocked = self.player.components.unlocktracker:IsEnemyUnlocked(self.monster_id) or self.monster_id == "basic"
	self.unlocked_recipes = self.player.components.unlocktracker:IsRecipeUnlocked(self.monster_id)

	if not monster_unlocked then

		-- If this monster is locked, and the player doesn't own any of its items, show no info

		self.title:Hide()
		self.desc:Hide()
		self.empty_banner:Show()
		self.items_root:RemoveAllChildren()
		-- self.unlock_widget:Hide()
		self.inventory_display:Hide()

	elseif monster_unlocked and not self.unlocked_recipes then

		-- The player has seen the monster, but not unlocked its armour

		self.title:Show()
		self.desc:Show()
		self.empty_banner:Hide()

		-- Display the armour slots
		self.items_root:RemoveAllChildren()
		for _, slot in ipairs(itemutil.GetOrderedArmourSlots()) do
			if armour_items[slot] then
				self:_AddItem(armour_items[slot])
			end
		end

		--[[
		-- Display unlock widget
		self.unlock_icon:LayoutBounds("center", "top", self.unlock_bg)
			:Offset(0, -50)
		self.unlock_label:LayoutBounds("center", "below", self.unlock_icon)
			:Offset(0, -10)
		self.unlock_materials:SetIngredients(self.recipe.ingredients)
			:LayoutChildrenInRow(20)
		self.unlock_button:LayoutBounds("after", "center", self.unlock_materials)
			:Offset(30, 0)
		self.unlock_footer:LayoutBounds("center", "below", self.unlock_label)
			:Offset(0, -60)
		-- self.unlock_widget:Show()
		-- 	:LayoutBounds("center", "above", self.inventory_display)
		-- 	:Offset(0, 60)

		-- Setup button callback
		self.unlock_button:SetOnClickFn(function()
			if self.recipe:CanPlayerCraft(self.player) then
				self.recipe:TakeIngredientsFromPlayer(self.player)
				self.player.components.unlocktracker:UnlockMonsterArmourSet(self.monster_id)

				-- Assemble popup!
				local screen = ItemUnlockPopup(nil, nil, true)
					:SetArmourSetUnlock(self.monster_id)

				-- Setup callback
				screen:SetOnDoneFn(
					function()
						-- Close popup
						TheFrontEnd:PopScreen(screen)

						-- Refresh panel
						self:SetArmorData(self.monster_id, self.armour_items)

						-- Notify parent
						if self.on_unlock_fn then self.on_unlock_fn() end
					end)

				-- Show popup
				TheFrontEnd:PushScreen(screen)
				screen:AnimateIn()
			end
		end)

		-- Enable button accordingly
		self.unlock_button:SetEnabled(self.recipe:CanPlayerCraft(self.player))
		-- Update the input binding string
		self.unlock_button:SetText("") -- Force an actual text change
		self.unlock_button:SetText(string.format(STRINGS.UI.RESEARCHSCREEN.BTN_UNLOCK))

		self.inventory_display:Show()
		--]]
	elseif monster_unlocked and self.unlocked_recipes then

		-- The player has seen the monster and unlocked the recipes

		self.title:Show()
		self.desc:Show()
		self.empty_banner:Hide()

		-- Display the armour slots
		self.items_root:RemoveAllChildren()
		self.slot_items = {}
		for _, slot in ipairs(itemutil.GetOrderedArmourSlots()) do
			if armour_items[slot] then
				self:_AddItem(armour_items[slot])
			end
		end

		-- self.unlock_widget:Hide()
		self.inventory_display:Show()
	end
	self:_UpdateInventoryDisplay()
	self:Layout()
	return self
end

function UpgradeableItemDetails:_AddItem(itemdef, hotkey)
	local recipe = recipes.FindRecipeForItemDef(itemdef)
	local item = self.player.components.inventoryhoard:GetInventoryItem(itemdef)
	local owned = false

	if item then
		owned = true
	else
		item = itemforge.CreateEquipment( itemdef.slot, itemdef )
	end

	local row = self.items_root:AddChild(UpgradeableItemWidget(self.width + 40, self.player, item, recipe, owned, not self.unlocked_recipes))
		:SetOnCraftFn(function()
			self:_UpdateInventoryDisplay()
			self:Layout()

			-- This widget is removed and replaced after click, so restore focus onto the new one's button
			self.slot_items[itemdef.slot]:GetDefaultFocus():SetFocus()
		end)
		:SetOnGainFocus(function()
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.hover)
		end)
		:SetOnLoseFocus(function()
			--@luca
		end)


	self.slot_items[itemdef.slot] = row
end

-- Used on the ForgeArmourScreen, for controller support
function UpgradeableItemDetails:TriggerCraftItem(slot)
	if self.slot_items[slot] then
		self.slot_items[slot]:OnButtonClicked()
    end
	return self
end

-- Used on the ForgeArmourScreen, for controller support
function UpgradeableItemDetails:TriggerUnlockItemSet()
	-- if self.unlock_button:IsShown() and self.unlock_button:IsEnabled() then
	-- 	self.unlock_button:Click()
    -- end
	return self
end

-- Updates the inventory_display to show the relevant crafting materials from the player's inventory
function UpgradeableItemDetails:_UpdateInventoryDisplay()
	local relevant_items = self:GetRelevantInventoryItems()

	-- Update list, without duplicates
	self.inventory_display:Refresh(self.player, lume.unique(relevant_items))
end

-- Goes through the recipes displayed, and picks the various materials needed
-- Returns a table of those materials, used elsewhere.
function UpgradeableItemDetails:GetRelevantInventoryItems()
	local relevant_items = {}
	-- if self.unlock_widget:IsShown() and self.recipe then
	-- 	-- The player hasn't unlocked the armour recipes
	-- 	-- Gather the ingredients for the unlocking recipe
	-- 	for item_id, amount in pairs(self.recipe.ingredients) do
	-- 		table.insert(relevant_items, item_id)
	-- 	end
	-- else
		-- Go through the armour pieces and gather their ingredients
		for k, upgradeable_item_widget in ipairs(self.items_root.children) do
			local recipe = upgradeable_item_widget:GetRecipe()
			if recipe then
				for item_id, amount in pairs(recipe.ingredients) do
					table.insert(relevant_items, item_id)
				end
			end
		end
	-- end

	return relevant_items
end

function UpgradeableItemDetails:AnimateContentsIn(on_done_fn)
	local updater = Updater.Parallel()

	local total_wait = 0

	-- Add item panels
	for k, widget in ipairs(self.items_root.children) do

		-- Get target position
		local x, y = widget:GetPos()

		-- Move it down a bit
		widget:SetPos(x, y - 50)
		widget:SetMultColorAlpha(0)

		-- Animate!
		updater:Add(Updater.Series{
			Updater.Wait(total_wait),
			Updater.Parallel{
				Updater.Ease(function(v) widget:SetMultColorAlpha(v) end, 0, 1, 0.05, easing.outQuad),
				Updater.Ease(function(v) widget:SetPos(x, v) end, y-50, y, 0.45, easing.outElasticUI)
			}
		})

		total_wait = total_wait + 0.1
	end

	-- -- Add unlock panel
	-- if self.unlock_widget:IsShown() then

	-- 	-- Get target position
	-- 	local x, y = self.unlock_widget:GetPos()

	-- 	-- Move it down a bit
	-- 	self.unlock_widget:SetPos(x, y - 50)
	-- 	self.unlock_widget:SetMultColorAlpha(0)

	-- 	-- Animate!
	-- 	updater:Add(Updater.Series{
	-- 		Updater.Wait(total_wait),
	-- 		Updater.Parallel{
	-- 			Updater.Ease(function(v) self.unlock_widget:SetMultColorAlpha(v) end, 0, 1, 0.05, easing.outQuad),
	-- 			Updater.Ease(function(v) self.unlock_widget:SetPos(x, v) end, y-50, y, 0.45, easing.outElasticUI)
	-- 		}
	-- 	})

	-- 	total_wait = total_wait + 0.1
	-- end

	-- Add unlock panel
	if self.empty_banner:IsShown() then

		-- Get target position
		local x, y = self.empty_banner:GetPos()

		-- Move it down a bit
		self.empty_banner:SetPos(x, y - 50)
		self.empty_banner:SetMultColorAlpha(0)

		-- Animate!
		updater:Add(Updater.Series{
			Updater.Wait(total_wait),
			Updater.Parallel{
				Updater.Ease(function(v) self.empty_banner:SetMultColorAlpha(v) end, 0, 1, 0.05, easing.outQuad),
				Updater.Ease(function(v) self.empty_banner:SetPos(x, v) end, y-50, y, 0.45, easing.outElasticUI)
			}
		})

		total_wait = total_wait + 0.1
	end

	self:RunUpdater(Updater.Series({

		-- Run our sequence of animations
		updater,

		-- And our callback at the end
		Updater.Do(function()
			if on_done_fn then on_done_fn() end
		end)
	}))
	return self
end

function UpgradeableItemDetails:SetOnUnlockFn(fn)
	self.on_unlock_fn = fn
	return self
end

function UpgradeableItemDetails:SetOnCloseFn(fn)
	self.close_button:SetOnClick(fn)
	return self
end

function UpgradeableItemDetails:Layout()

	self.title:LayoutBounds("center", "top", self.bg)
		:Offset(0, -80)
	self.desc:LayoutBounds("center", "below", self.title)
		:Offset(0, -10)
	self.empty_banner:LayoutBounds("center", "center", self.bg)
		:Offset(0, 0)

	self.items_root:LayoutChildrenInColumn(30)
		:LayoutBounds(nil, "below", self.desc)
		:LayoutBounds("left", nil, self.bg)
		:Offset(0, -60)

	self.inventory_display:LayoutBounds("after", "center", self.bg)
		:Offset(100, 0)

	return self
end

UpgradeableItemDetails.CONTROL_MAP =
{
	{
		control = Controls.Digital.ACCEPT,
		fn = function(self)
			-- if self.unlock_widget:IsShown() and self.unlock_widget:HasFocus() then
			-- 	if self.unlock_button:IsEnabled() then
			-- 		self.unlock_button:Click()
			-- 		return true
			-- 	else
			-- 		self.unlock_widget:OnFocusNudge("down")
			-- 	end
			-- end
			if self.empty_banner:IsShown() and self.empty_banner:HasFocus() then
				self.empty_banner:OnFocusNudge("down")
			end
		end,
	},
}

return UpgradeableItemDetails
