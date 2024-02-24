local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local itemforge = require "defs.itemforge"
local ActionButton = require "widgets/actionbutton"
local ItemDetails = require "widgets.ftf.itemdetails"
local TotalWeightWidget = require "widgets/ftf/totalweightwidget"
local Equipment = require "defs.equipment"
local recipes = require "defs.recipes"
local UpgradeableItemWidget = require"widgets/ftf/upgradeableitemwidget"
local Weight = require "components/weight"
local Text = require "widgets/text"
local DisplayStat = require "widgets/ftf/displaystat"
local Panel = require "widgets/panel"
local ActionButton = require "widgets/actionbutton"
local easing = require("util.easing")
local ConfirmDialog = require "screens.dialogs.confirmdialog"
local Consumable = require "defs.consumable"
local EffectEvents = require "effectevents"
local SGPlayerCommon = require "stategraphs.sg_player_common"

local EquipmentPreview = Class(Widget, function(self, player, itemDef, owned)
	Widget._ctor(self, "EquipmentPreview")

	self.width = 800 * HACK_FOR_4K
	self.height = 280 * HACK_FOR_4K

	self.player = player
	self.itemDef = itemDef
	self.item = itemforge.CreateEquipment(self.itemDef.slot, self.itemDef)

	local recipe = recipes.FindRecipeForItemDef(self.itemDef)
	self.details = self:AddChild(UpgradeableItemWidget(self.width, self.player, self.item, recipe, owned, false, true))
end)

--------------------------------------------------------------
-- Displays a comparison between two pieces of equipment, and any changes to the player's build if they take the new piece.

local function PurchaseEquipmentItem(player, item_def, item, equip)
	local slot = item_def.slot

	player.components.unlocktracker:UnlockRecipe(item_def.name)
	player:UnlockFlag("pf_has_bought_armour")

	local hoard = player.components.inventoryhoard
	hoard:AddToInventory(slot, item)
	if equip then
		hoard:SetLoadoutItem(hoard.data.selectedLoadoutIndex, slot, item)
		hoard:EquipSavedEquipment()
	end
end

local WEIGHT_CHANGED_TO <const> = {
	[Weight.Status.s.Light] = STRINGS.UI.WARE_PURCHASE_POPUP.WEIGHT_CHANGED_TO.LIGHT,
	[Weight.Status.s.Normal] = STRINGS.UI.WARE_PURCHASE_POPUP.WEIGHT_CHANGED_TO.MEDIUM,
	[Weight.Status.s.Heavy] = STRINGS.UI.WARE_PURCHASE_POPUP.WEIGHT_CHANGED_TO.HEAVY,
}

local EquipmentComparisonScreen = Class(Screen, function(self, player, new_item_def, currency_type, cost)
	Screen._ctor(self, "EquipmentComparisonScreen")

	self.player = player
	self.itemDef = new_item_def
	self.currency_type = currency_type
	self.cost = cost
	self.item = itemforge.CreateEquipment(self.itemDef.slot, self.itemDef)

	local equippedItem = self.player.components.inventoryhoard:GetEquippedItem(self.itemDef.slot)
	if equippedItem then
		self.equippedItemDef = equippedItem:GetDef()
	end


	self.bg = self:AddChild(Image("images/global/square.tex"))
		:SetScale(100)
		:SetMultColor(0, 0, 0, 0.5)

	self.title = self:AddChild(Text(FONTFACE.DEFAULT, 100, "", UICOLORS.LIGHT_TEXT))
		:SetText(STRINGS.UI.WARE_PURCHASE_POPUP.DECISION_TITLE)

	self.text = self:AddChild(Text(FONTFACE.DEFAULT, 70, "", UICOLORS.LIGHT_TEXT))
		:SetText(STRINGS.UI.WARE_PURCHASE_POPUP.DECISION_TEXT)

	-- Containers
	self.itemsContainer = self:AddChild(Widget("Preview Container"))
	if self.equippedItemDef then
		self.equippedItemDetails = self.itemsContainer:AddChild(EquipmentPreview(self.player, self.equippedItemDef, true))

		self.arrows_container = self:AddChild(Widget())
			:SetName("Arrows container")
			:SetMultColorAlpha(0)
		self.arrow_widget_left = self.arrows_container:AddChild(Image("images/ui_ftf_powers/upgrade_arrow_left.tex"))
			:SetName("Arrow left")
			:Offset(-60, 0)
		self.arrow_widget_right = self.arrows_container:AddChild(Image("images/ui_ftf_powers/upgrade_arrow_right.tex"))
			:SetName("Arrow right")
			:Offset(60, 0)

		-- Animate arrows
		local arrow_left_x = self.arrow_widget_left:GetPos()
		local arrow_right_x = self.arrow_widget_right:GetPos()
		local duration = 2
		local distance = 125
		local y_pos = 150
		self.arrows_container:Offset(-distance/2 + 10, y_pos)
		self.arrows_container:RunUpdater(
			Updater.Loop({
				Updater.Parallel{
					Updater.Ease(function(v) self.arrows_container:SetMultColorAlpha(v) end, 0, 1, duration*0.25, easing.inOutQuad),
					Updater.Ease(function(v) self.arrow_widget_left:SetPos(v, y_pos) end, arrow_left_x, arrow_left_x+distance, duration*0.9, easing.inOutQuad),
					Updater.Ease(function(v) self.arrow_widget_right:SetPos(v, y_pos) end, arrow_right_x, arrow_right_x+distance, duration, easing.inOutQuad),
					Updater.Series{
						Updater.Wait(duration*0.75),
						Updater.Ease(function(v) self.arrows_container:SetMultColorAlpha(v) end, 1, 0, duration*0.25, easing.inOutQuad),
					},
				},
			})
		)
	end

	self.newItemDetails = self.itemsContainer:AddChild(EquipmentPreview(self.player, self.itemDef, false))

	-- Changes to our Build
	self.buildPreview = self:AddChild(Panel("images/ui_ftf_research/research_item_bg.tex"))
		:SetName("Background")
		:SetNineSliceCoords(43, 36, 162, 271)
		:SetSize(650, 600)
	self.buildDetails = self.buildPreview:AddChild(Widget("Build Details"))

	self.weightWidget = self.buildDetails:AddChild(TotalWeightWidget(self.player, 0.7))
	self:PreviewWeight()
	self.buildStats = self.buildDetails:AddChild(Widget("Stat Container"))
	self:RefreshStats(self.itemDef.slot, self.item)

	self.buttons = self:AddChild(Widget("Buttons"))

	self.purchaseButton = self.buttons:AddChild(ActionButton())
		:SetName("Purchase Button")
		:SetSize(BUTTON_W, BUTTON_H)
		:SetPrimary()
		:SetText(string.format(STRINGS.UI.WARE_PURCHASE_POPUP.PURCHASE_OPTION, self.cost))
		:SetOnClick(function()
			self.title:SetText(STRINGS.UI.WARE_PURCHASE_POPUP.DECISION_TITLE_PENDING)
			self.text:Hide()

			-- Pop Up "Equip or Ship" screen
			local title = self.itemDef.pretty.name
			local subtitle = nil
			local message = STRINGS.UI.WARE_PURCHASE_POPUP.TEXT

			local preview_weight = Weight.SumWeights(self:GetPreviewWeights())
			local preview_weight_status = Weight.ComputeStatus(preview_weight)
			if preview_weight_status ~= self.player.components.weight:GetStatus() then
				message = message.."\n"..WEIGHT_CHANGED_TO[preview_weight_status]
			end

			local screen = ConfirmDialog(nil, nil, false,
				title, -- Optional
				subtitle, -- Optional
				message -- Optional
			)

			local y_offset = self.equippedItemDef ~= nil and -555 or -530 -- Equipped Item panel is slightly taller

			screen:SetYesButton(STRINGS.UI.WARE_PURCHASE_POPUP.EQUIP_OPTION, function()
					-- "Yes", I will equip it now.

					-- HACK: We want to allow the player to check the comparison before deciding to purchase.
					--		 Because the vendingmachine takes the currency on interact, for this ware we are immediately giving them the currency back.
					--		 At this point, when they say "yes I'll purchase that", we are actually taking the currency away.
					--		 Make sure they still have enough, in case something weird happened.

					local currency = self.currency_type
					local cost = self.cost
					local available = self.player.components.inventoryhoard:GetStackableCount(currency)

					if available >= cost then
						player.components.inventoryhoard:RemoveStackable(currency, cost)
						PurchaseEquipmentItem(self.player, self.itemDef, self.item, true)
						SGPlayerCommon.Fns.CelebrateEquipment(player)
					end
					
					screen:Close()
					self:Close()
				end)
				:SetNoButton(STRINGS.UI.WARE_PURCHASE_POPUP.SHIP_OPTION, function()
					-- "No", I won't equip it -- send it back home.

					-- HACK: We want to allow the player to check the comparison before deciding to purchase.
					--		 Because the vendingmachine takes the currency on interact, for this ware we are immediately giving them the currency back.
					--		 At this point, when they say "yes I'll purchase that", we are actually taking the currency away.
					--		 Make sure they still have enough, in case something weird happened.

					local currency = self.currency_type
					local cost = self.cost
					local available = self.player.components.inventoryhoard:GetStackableCount(currency)

					if available >= cost then
						player.components.inventoryhoard:RemoveStackable(currency, cost)
						PurchaseEquipmentItem(self.player, self.itemDef, self.item, false)
					end
					screen:Close()
					self:Close()

					local title = STRINGS.UI.WARE_PURCHASE_POPUP.SHIPPED_TITLE
					-- local subtitle = "Decorative Pink Hedge"
					local message = STRINGS.UI.WARE_PURCHASE_POPUP.SHIPPED_TEXT

					local shipped_screen = ConfirmDialog(nil, nil, false,
						title, -- Optional
						nil, -- Optional
						message -- Optional
					)
					shipped_screen:SetYesButton(STRINGS.UI.WARE_PURCHASE_POPUP.SHIPPED_OK, function() shipped_screen:Close() end)
						:HideNoButton() -- Optional
						:HideArrow() -- An arrow can show under the dialog pointing at the clicked element
						:SetMinWidth(600)
						:CenterText() -- Aligns left otherwise
						:CenterButtons() -- They align left otherwise
					TheFrontEnd:PushScreen(shipped_screen)
					shipped_screen:AnimateIn()

				end)
				:SetCloseButton(function()
					self.title:SetText(STRINGS.UI.WARE_PURCHASE_POPUP.DECISION_TITLE)
					-- self.text:Show()
					screen:Close()
				end)
				:HideArrow() -- An arrow can show under the dialog pointing at the clicked element
				:SetMinWidth(600)
				:CenterText() -- Aligns left otherwise
				:CenterButtons() -- They align left otherwise
				:Offset(0, y_offset)
			TheFrontEnd:PushScreen(screen)
			screen:AnimateIn()
			
		end)

	self.cancelButton = self.buttons:AddChild(ActionButton())
		:SetName("Cancel Button")
		:SetSize(BUTTON_W * .75, BUTTON_H)
		:SetSecondary()
		:SetText(STRINGS.UI.WARE_PURCHASE_POPUP.CANCEL_OPTION)
		:SetOnClick(function()
			self:Close()
		end)

	self.buildDetails:LayoutChildrenInRow(50)
		:LayoutBounds("center", "center", self.buildPreview)
		:Offset(20, 0)

	self.itemsContainer:LayoutChildrenInRow(300)
		:LayoutBounds("center", "center", self)
		:Offset(0, 300)


	self.title:LayoutBounds("center", "above", self.itemsContainer)
		:Offset(0, 40)
	self.text:LayoutBounds("center", "below", self.title)
		:Offset(0, -20)

	self.itemsContainer:LayoutBounds("center", "below", self.text)
		:Offset(0, -40)

	self.buttons:LayoutChildrenInColumn(20)
	self.buttons:LayoutBounds("center", "below", self.itemsContainer)
		:Offset(0, -70)

	self.buildPreview:LayoutBounds("before", "top", self.purchaseButton)
		:Offset(-300, 0)
		-- :Hide()

	self:Offset(0, -200)
	self.default_focus = self.purchaseButton

	if self.equippedItemDetails ~= nil then
		self.equippedItemDetails.details:Refresh()
	end

	self.newItemDetails.details:Refresh()
end)

function EquipmentComparisonScreen:GetPreviewWeights()
	local weights = self.player.components.weight:GetWeights()
	
	-- Replace the slot we're trying to preview with the new weight.
	weights[self.itemDef.slot] = self.itemDef.weight

	return weights
end

function EquipmentComparisonScreen:PreviewWeight()
	self.weightWidget:PreviewByListOfWeights(self:GetPreviewWeights())
end

function EquipmentComparisonScreen:SetDefaultFocus()
	self.purchaseButton:SetFocus()
end


function EquipmentComparisonScreen:RefreshStats(previewed_slot, previewed_item)
	-- note: jambell, taken from inventory screen -- once desire is known, align these two.

	self.buildStats:RemoveAllChildren()

	local statsData = {
		{
			icon = "images/icons_ftf/stat_weapon.tex",
			stat = EQUIPMENT_STATS.s.DMG,
			value = 0,
			delta = 0
		},
		{
			icon = "images/icons_ftf/stat_armour.tex",
			stat = EQUIPMENT_STATS.s.ARMOUR,
			value = 0,
			delta = 0
		},
	}
	local max_width = 315
	local icon_size = 55 * HACK_FOR_4K
	local text_size = 50 * HACK_FOR_4K
	local delta_size = 50 * HACK_FOR_4K

	for _,slot in pairs(Equipment.GetOrderedSlots()) do
		local equipped_item = self.player.components.inventoryhoard:GetEquippedItem(slot)

		if slot == previewed_slot then
			-- See what the differences for this previewed item are.
			local stats_delta, stats = self.player.components.inventoryhoard:DiffStatsAgainstEquipped(previewed_item, slot)

			local equipped_stats = equipped_item and equipped_item:GetStats()

			for idx, data in pairs(statsData) do
				local stat = data.stat
				if stats_delta and stats_delta[stat] then
					data.delta = (data.delta or 0) + (stats_delta[stat] or 0)
				end
				if equipped_stats and equipped_stats[stat] then
					data.value = (data.value or 0) + (equipped_stats[stat] or 0)
				end
			end
		else
			-- Get currently selected item
			local item = equipped_item -- In this case, this is already the equipped item.

			-- Calculate the stat differences to the loadout's saved item
			local stats_delta, stats = self.player.components.inventoryhoard:DiffStatsAgainstEquipped(item, slot)
			for idx, data in pairs(statsData) do
				local stat = data.stat
				if stats and (stats[stat] or stats_delta[stat]) then
					data.value = (data.value or 0) + (stats[stat] or 0)
					data.delta = (data.delta or 0) + (stats_delta[stat] or 0)
				end
			end
		end
	end

	for id, data in pairs(statsData) do
		-- Display stat widget
		self.buildStats:AddChild(DisplayStat(max_width, icon_size, text_size, delta_size))
			:SetStyle_EquipmentPanel()
			:ShouldShowToolTip(true)
			:ShowName(self.show_stat_names)
			:ShowUnderline(false)
			:SetStat(data)
	end

	self.buildStats:LayoutChildrenInGrid(1, {h = 30 * HACK_FOR_4K, v = 25 * HACK_FOR_4K})
		:LayoutBounds("center", "center", self.bg)
		:Offset(300, -25)
		:SendToFront()

	return self
end

function EquipmentComparisonScreen:Close()
	TheFrontEnd:PopScreen(self)
	return self
end

EquipmentComparisonScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.CANCEL,
		fn = function(self)
			self:Close()
		end,
	}
}

return EquipmentComparisonScreen
