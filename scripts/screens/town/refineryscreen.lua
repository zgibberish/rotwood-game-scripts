local RefineryPanel = require("widgets/ftf/refinerypanel")
local InventoryPanel = require("widgets/ftf/inventorypanel")
local Screen = require("widgets/screen")

local itemforge = require "defs.itemforge"
local Consumable = require "defs.consumable"
local easing = require "util.easing"
local lume = require"util.lume"
local fmodtable = require "defs.sound.fmodtable"

-------------------------------------------------------------------------------------------------



local material_sort_data = {
	default = "SOURCE",
	data =
	{
		{ name = STRINGS.UI.EQUIPMENT_STATS.RARITY.name, data = EQUIPMENT_STATS.s.RARITY },
		{ name = STRINGS.UI.EQUIPMENT_STATS.SOURCE.name, data = "SOURCE" },
	}
}

local tabs =
{
	-- Monster Materials
	{
		key = "MONSTER_MATERIALS",
		slots = { Consumable.Slots.MATERIALS },
		or_filters = { LOOT_TAGS.NORMAL, LOOT_TAGS.ELITE, },
		sort_data = material_sort_data,
		icon = "images/icons_ftf/inventory_monster_drops.tex",
	},
}

local RefineryScreen = Class(Screen, function(self, player)
	Screen._ctor(self, "RefineryScreen")



	self.inventoryPanel = self:AddChild(InventoryPanel(tabs))
		:SetOnCategoryClickFn(function(slot) self:OnCategoryClicked(slot) end)
		:SetOnItemClickFn(function(itemData, idx) self:OnInventoryItemClicked(itemData, idx) end)
		:SetOnItemAltClickFn(function(itemData, idx) self:OnInventoryItemAltClicked(itemData, idx) end)
		:SetOnCloseFn(function() self:OnCloseButton() end)
		-- :SetSlotTabs( { Consumable.Slots.MATERIALS, Consumable.Slots.KEY_ITEMS })
		:Offset(550, 0)
		:SetExternalFilterFn(function(items) return self:FilterItemsFn(items) end)

	self.refineryPanel = self:AddChild(RefineryPanel())
		:LayoutBounds("before", "center", self.inventoryPanel)

	dbassert(player)
	self:SetOwningPlayer(player)

	self.default_focus = self.inventoryPanel.closeButton
end)

function RefineryScreen:SetOwningPlayer(owningplayer)
	self.player = owningplayer -- need this for existing logic
	RefineryScreen._base.SetOwningPlayer(self, owningplayer)
	self:Refresh()
end

RefineryScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.MENU_SCREEN_ADVANCE,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.ACCEPT", Controls.Digital.MENU_SCREEN_ADVANCE))
		end,
		fn = function(self)
			self:OnCloseButton()
			return true
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
}

function RefineryScreen:OnBecomeActive()
	RefineryScreen._base.OnBecomeActive(self)
	TheDungeon.HUD:Hide()

	--sound snapshot
	TheAudio:StartFMODSnapshot(fmodtable.Snapshot.MenuOverlay)


	if not self.animatedIn then
		-- Animate in the first time the screen shows up
		self:AnimateIn()
		self.animatedIn = true
	end
end

function RefineryScreen:OnBecomeInactive()
	--sound snapshot
	TheAudio:StopFMODSnapshot(fmodtable.Snapshot.MenuOverlay)

	RefineryScreen._base.OnBecomeInactive(self)
end

function RefineryScreen:AnimateIn()
	--sound
	TheFrontEnd:GetSound():PlaySound(fmodtable.Event.refineryScreen_show)

	-- Hide elements
	self.refineryPanel:SetMultColorAlpha(0)
	self.inventoryPanel:SetMultColorAlpha(0)

	-- Get default positions
	local csX, csY = self.refineryPanel:GetPosition()
	local ipX, ipY = self.inventoryPanel:GetPosition()

	-- Start animating
	self:RunUpdater(Updater.Series({
		-- Animate in the character panel
		Updater.Parallel({
			Updater.Ease(function(v) self.refineryPanel:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
			Updater.Ease(function(v) self.refineryPanel:SetPosition(v, csY) end, csX - 30, csX, 0.2, easing.inOutQuad),
		}),

		-- Animate in the inventory panel
		Updater.Parallel({
			Updater.Ease(function(v) self.inventoryPanel:SetMultColorAlpha(v) end, 0, 1, 0.1, easing.inOutQuad),
			Updater.Ease(function(v) self.inventoryPanel:SetPosition(v, ipY) end, ipX + 30, ipX, 0.2, easing.inOutQuad),
		}),
	}))

	return self
end

function RefineryScreen:Refresh()
	self.refineryPanel:Refresh(self.player)
	self.inventoryPanel:Refresh(self.player)
	return self
end

function RefineryScreen:NextTab(delta)
	self.inventoryPanel:NextTab(delta)
	return self
end

-- An item in the inventory was clicked
function RefineryScreen:OnCategoryClicked(slot)
	self.inventoryPanel:SetCurrentCategory(slot)
	return self
end

function RefineryScreen:OnInventoryItemAltClicked(item, idx)
	if self:CanAddItem(item) then
		local five_stack = itemforge.CreateStack(item:GetDef().slot, item:GetDef())
		five_stack.count = math.min(item.count, 5)
		self.refineryPanel:AddItemToPending(five_stack)
	end
end

-- An item in the inventory was clicked
function RefineryScreen:OnInventoryItemClicked(item, idx)
	if self:CanAddItem(item) then
		local single = itemforge.CreateStack(item:GetDef().slot, item:GetDef())
		single.count = 1
		self.refineryPanel:AddItemToPending(single)
	end
end

function RefineryScreen:FilterItemsFn(items)
	local pending = self.refineryPanel:GetPendingItems()
	if table.count(pending) > 0 then
		local rarity = pending[next(pending)].rarity

		if table.count(pending) == #self.refineryPanel.pending_slots then
			items = lume.filter(items, function(item)
				for _, pending_item in pairs(pending) do
					if pending_item:GetDef() == item:GetDef() then
						return true
					end
				end
				return false
			end)
		else
			items = lume.filter(items, function(item) return item.rarity == rarity end)
		end
	end
	return items
end

function RefineryScreen:CanAddItem(item)
	-- can be refined & isn't already in the pending items
	local can_add = item.count ~= nil and self.refineryPanel:CanAddItems()
	if not can_add then
		local pending = self.refineryPanel:GetPendingItems()
		for _, pending_item in pairs(pending) do
			if pending_item:GetDef() == item:GetDef() then
				can_add = true
				break
			end
		end
	end
	return can_add
end

function RefineryScreen:_ShowPlayerHUD()
	assert(TheDungeon.HUD, "No HUD for closing RefineryScreen.")
	TheDungeon.HUD:Show()
end

function RefineryScreen:OnCloseButton()
	-- if you have items in pending_items, give them back.

	-- if you have items in resulting_items, give them to the player.
	self.refineryPanel:GiveRemainingItems()

	-- sound
	TheFrontEnd:GetSound():PlaySound(fmodtable.Event.refineryScreen_hide)

	TheFrontEnd:PopScreen(self)
	self:_ShowPlayerHUD()
end

return RefineryScreen
