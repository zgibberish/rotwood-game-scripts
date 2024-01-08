local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Panel = require("widgets/panel")
local InventorySlot = require("widgets/ftf/inventoryslot")
local MonsterResearchStackWidget = require("widgets/ftf/monsterresearchstackwidget")
local templates = require "widgets.ftf.templates"

local MetaProgress = require "defs.metaprogression"
local Consumable = require "defs.consumable"
local itemforge = require "defs.itemforge"
local lume = require("util/lume")

local NUM_ITEMS = 5
local NUM_COLUMNS = 5

local RefineryPanel = Class(Widget, function(self)
	Widget._ctor(self, "RefineryPanel")

	self.width = 500
	self.contentWidth = self.width - 50
	self.height = RES_Y

	self.inst:SetStateGraph("widgets/sg_refinerypanel")

	-- SIDEBAR BACKGROUND

	self.bg = self:AddChild(Panel("images/ui_ftf_forging/forge_sidebar.tex"))
		:SetNineSliceCoords(50, 450, 60, 620)
		:SetNineSliceBorderScale(0.5)
		:SetSize(self.width, self.height + 20)
		:LayoutBounds("left", "center", -RES_X / 2, 0)
		:Offset(40, 0)

	--- PANEL CONTENTS

	self.refinery_ui_root = self:AddChild(Widget("Refinery Root"))

	self.button_root = self.refinery_ui_root:AddChild(Widget("Refine Button"))
	local scale = 0.5
	local rotationSpeed = 0.2

	self.ring_center = self.button_root:AddChild(Image("images/ui_ftf_relic_selection/konjurdrawing.tex"))
		:SetScale(scale)
		:Offset(-10,7)

	self.ring_one = self.button_root:AddChild(Image("images/ui_ftf_relic_selection/konjurdrawing.tex"))
		:SetScale(scale * 0.65)
		:LayoutBounds("center", "center", self.ring_center)
		:Offset(-33, 86)
		:AlphaTo(0.4, 0)
		:RotateIndefinitely(-rotationSpeed - (math.random() * 0.01))

	self.ring_two = self.button_root:AddChild(Image("images/ui_ftf_relic_selection/konjurdrawing.tex"))
		:SetScale(scale * 0.65)
		:LayoutBounds("center", "center", self.ring_center)
		:Offset(-74, -90)
		:AlphaTo(0.4, 0)
		:RotateIndefinitely(-rotationSpeed - (math.random() * 0.02))

	self.ring_three = self.button_root:AddChild(Image("images/ui_ftf_relic_selection/konjurdrawing.tex"))
		:SetScale(scale * 0.65)
		:LayoutBounds("center", "center", self.ring_center)
		:Offset(109, -25)
		:AlphaTo(0.45, 0)
		:RotateIndefinitely(rotationSpeed + (math.random() * 0.01))

	self.refine_button = self.button_root:AddChild(templates.Button("Analyze"))
        :SetSize(120 * HACK_FOR_4K, 100)
        :SetOnClickFn(function() self:DoRefinePresentation() end)
        :LayoutBounds("center", "center", self.ring_center)

	self.pending_root = self.refinery_ui_root:AddChild(Widget("Pending Items"))
	self.pending_slots = {} -- a list of widgets in this grid
	self.pending_items = {} -- the list of actual items
	self:BuildItemGrid(self.pending_root, self.pending_slots)
	for i, w in ipairs(self.pending_slots) do
		w:SetOnClick(function(slot, item) self:OnPendingSlotClicked(w:GetItemInstance(), i) end)
		w:SetOnClickAlt(function(slot, item) self:OnPendingSlotAltClicked(w:GetItemInstance(), i) end)
	end

	self.resulting_root = self.refinery_ui_root:AddChild(Widget("Resulting Items"))
	self.resulting_slots = {} -- a list of widgets in this grid
	self.resulting_items = {} -- the list of actual items
	self:BuildItemGrid(self.resulting_root, self.resulting_slots)

    self.confirm_button = self.refinery_ui_root:AddChild(templates.Button("Collect"))
		:SetOnClickFn(function() self:EndRefinePresentation() end)
		:Hide()


	-- self.monster_research = self:AddChild(MonsterResearchStackWidget())

	self.research_results = {}
	self.can_add = true

	self:RefreshRefineButton()

	self:ApplyBaseLayout()

	self:ApplySkin()
		:LayoutSkin()
end)

function RefineryPanel:Refresh(player)
	self.player = player
	-- self.monster_research:SetOwner(player)
	return self
end

function RefineryPanel:BuildItemGrid(root, slots_table, onclick, onaltclick)
	local item_size = 70
	local spacing = 5

	for i = 1, NUM_ITEMS do
		local w = InventorySlot(item_size, "images/ui_ftf_shop/inventory_slot_bg.tex")
			:SetItem(nil)

		slots_table[w] = w
		table.insert(slots_table, w)
		root:AddChild(w)
	end

	root:LayoutChildrenInGrid(NUM_COLUMNS, spacing)
end

function RefineryPanel:ApplyBaseLayout()
	self.button_root:LayoutBounds("center", "center", self.bg)
		-- :Offset(50, 0)

	self.pending_root:LayoutBounds("center", "above", self.button_root)
		:Offset(0, 50)

	self.resulting_root:LayoutBounds("center", "below", self.button_root)
		:Offset(0, -50)

	self.confirm_button:LayoutBounds("center", "below", self.resulting_root)
		:Offset(0, -20)

	self.refinery_ui_root:LayoutBounds("left", "center", self.bg)
		:Offset(50, 0)

	-- self.monster_research:LayoutBounds("right", "center", self.bg)
end

function RefineryPanel:GiveRemainingItems()
	for _, item in pairs(self.pending_items) do
		self.player.components.inventoryhoard:AddStackable(item:GetDef(), item.count)
	end
	self.pending_items = {}

	for _, item in pairs(self.resulting_items) do
		self.player.components.inventoryhoard:AddStackable(item:GetDef(), item.count)
	end
	self.resulting_items = {}
end

function RefineryPanel:GetTotalNumberOfPending()
	local count = 0
	for _, item in pairs(self.pending_items) do
		count = count + item.count
	end
	return count
end

function RefineryPanel:GetPendingItems()
	return self.pending_items
end

function RefineryPanel:AddItemToPending(new_item)
	local def = new_item:GetDef()
	local count = new_item.count

	local did_add = false

	for i, item in ipairs(self.pending_items) do
		if item:GetDef() == def then
			item.count = item.count + count
			did_add = true
			break
		end
	end

	if not did_add and table.count(self.pending_items) < NUM_ITEMS then
		local pending_item = itemforge.CreateStack(def.slot, def)
		pending_item.count = count

		local next_idx = nil
		for i = 1, NUM_ITEMS do
			if not self.pending_items[i] then
				next_idx = i
				break
			end
		end

		self.pending_items[next_idx] = pending_item
		did_add = true
	end

	if did_add then
		self.player.components.inventoryhoard:RemoveStackable(def, count)
		self:RefreshPendingGrid()
		-- self:RefreshMonsterResearch()
	end
end

function RefineryPanel:RemoveItemFromPending(item, idx, num)
	if not item then return end

	local split_stack = itemforge.CreateStack(item:GetDef().slot, item:GetDef())
	split_stack.count = math.min(num, item.count)
	item.count = item.count - split_stack.count

	if item.count <= 0 then
		self.pending_items[idx] = nil
	end

	self:RefreshPendingGrid()
	-- self:RefreshMonsterResearch()
	return split_stack
end

function RefineryPanel:OnPendingSlotClicked(item, idx)
	local split_stack = self:RemoveItemFromPending(item, idx, 1)
	if split_stack then
		self.player.components.inventoryhoard:AddStackable(split_stack:GetDef(), split_stack.count)
	end
end

function RefineryPanel:OnPendingSlotAltClicked(item, idx)
	local split_stack = self:RemoveItemFromPending(item, idx, 5)
	if split_stack then
		self.player.components.inventoryhoard:AddStackable(split_stack:GetDef(), split_stack.count)
	end
end

function RefineryPanel:RefreshPendingGrid()
	for i, w in ipairs(self.pending_slots) do
		w:SetItem(nil)
	end

	for idx, item in pairs(self.pending_items) do
		self.pending_slots[idx]:SetItem(item, self.player)
	end
	self:RefreshRefineButton()
end

function RefineryPanel:RefreshRefineButton()
	local can_refine, reason = self:CanRefinePendingItems()
	if not can_refine then
		self.refine_button:Disable()
		self.refine_button:SetToolTip(reason)
	else
		self.refine_button:Enable()
		self.refine_button:SetToolTip(nil)
	end
end

function RefineryPanel:ClearResulting()
	for i, w in ipairs(self.resulting_slots) do
		w:SetItem(nil)
	end
end

function RefineryPanel:CanAddItems()
	return self.can_add and table.count(self.pending_items) < #self.pending_slots
end

local RARITY_TO_EXP =
{
	[ITEM_RARITY.s.UNCOMMON] = 1,
	[ITEM_RARITY.s.EPIC] = 3,
	[ITEM_RARITY.s.LEGENDARY] = 10,
}

local RARITY_TO_NUM =
{
	[ITEM_RARITY.s.UNCOMMON] = 1/5,
	[ITEM_RARITY.s.EPIC] = 1/5,
	[ITEM_RARITY.s.LEGENDARY] = 1/5,
}

local RARITY_TO_ITEM =
{
	[ITEM_RARITY.s.UNCOMMON] = "konjur_soul_lesser",
	[ITEM_RARITY.s.EPIC] = "konjur_soul_greater",
	[ITEM_RARITY.s.LEGENDARY] = "konjur_heart",
}

function RefineryPanel:CanRefinePendingItems()
	if self:GetTotalNumberOfPending() < 5 then
		return false, "Need to add at least 5 items"
	else
		return true
	end
end

function RefineryPanel:CanBeRefined(item)
	local rarity = item:GetDef().rarity
	local count = math.floor(RARITY_TO_NUM[rarity] * item.count)
	return count > 0
end

function RefineryPanel:GetRefineryExperience(item)
	-- if experience needed is exact, the bar does not show the next level
	return RARITY_TO_EXP[item:GetRarity()] * item.count
end

function RefineryPanel:GetRefineryResult(rarity, num)
	local id = RARITY_TO_ITEM[rarity]
	local count = math.floor(RARITY_TO_NUM[rarity] * num)
	return id, count
end

function RefineryPanel:RefineItems(items)
	local rarity = nil
	local count = 0
	for _, item in ipairs(items) do
		if rarity == nil then rarity = item.rarity end
		assert(rarity == item.rarity, "Invalid Item List!")
		count = count + item.count
	end

	local result_id, result_count = self:GetRefineryResult(rarity, count)

	local def = Consumable.FindItem(result_id)
	local result_item = itemforge.CreateStack(def.slot, def)
	result_item.count = result_count
	table.insert(self.resulting_items, result_item)
	return result_item, #self.resulting_items
end

function RefineryPanel:RefineItemInSlot(idx)
	local item_to_refine = self.pending_items[idx]
	local result_id, result_count, remaining = self:GetRefineryResult(item_to_refine)

	if result_count == 0 then
		return nil
	end

	item_to_refine.count = remaining

	if item_to_refine.count == 0 then
		self.pending_items[idx] = nil
	end

	self.pending_slots[idx]:SetItem(self.pending_items[idx], self.player)

	local def = Consumable.FindItem(result_id)

	for i, result_item in ipairs(self.resulting_items) do
		if result_item:GetDef() == def then
			result_item.count = result_item.count + result_count
			return result_item, i
		end
	end

	local result_item = itemforge.CreateStack(def.slot, def)
	result_item.count = result_count
	table.insert(self.resulting_items, result_item)

	return result_item, #self.resulting_items
end

---------------------------------------

function RefineryPanel:DoRefinePresentation()
	-- done in sg_refinerypanel
	self.can_add = false
	self.inst:PushEvent("start_refine")
end

function RefineryPanel:EndRefinePresentation()
	-- done in sg_refinerypanel
	self.can_add = true
	self.inst:PushEvent("end_refine")

	local to_give = {}
	for i, item in ipairs(self.resulting_items) do
		local def = item:GetDef()
		if not to_give[def] then
			to_give[def] = 0
		end

		to_give[def] = to_give[def] + item.count
	end

	for def, count in pairs(to_give) do
		self.player.components.inventoryhoard:AddStackable(def, count)
	end

	self.resulting_items = {}
	self:ClearResulting()
	-- self:RefreshMonsterResearch()
end

---------------------------------------

-- Instantiates all the skin texture elements to this screen.
-- Call this at the start
function RefineryPanel:ApplySkin()

	self.skinDirectory = "images/ui_ftf_skin/" -- Defines what skin to use

	-- Add chain edges to the bg panel
	self.skinEdgeLeft = self:AddChild(Image(self.skinDirectory .. "panel_left.tex"))
		:SetHiddenBoundingBox(true)
	self.skinEdgeRight = self:AddChild(Image(self.skinDirectory .. "panel_right.tex"))
		:SetHiddenBoundingBox(true)

	-- Add glow at the bottom
	self.skinPanelGlow = self:AddChild(Image(self.skinDirectory .. "panel_glow.tex"))
		:SetHiddenBoundingBox(true)
		:PulseAlpha(0.6, 1, 0.003)

	return self
end

---
-- Lays out all the skin texture elements to this screen
-- Call this when the size/layout changes
--
function RefineryPanel:LayoutSkin()

	-- Edge textures
	local textureW, textureH = 100, 1280
	local targetH = RES_Y
	local targetW = targetH / textureH * textureW
	self.skinEdgeLeft:SetSize(targetW, RES_Y)
		:LayoutBounds("before", "center", self.bg)
		:Offset(targetW * 0.5, 0)
	self.skinEdgeRight:SetSize(targetW, RES_Y)
		:LayoutBounds("after", "center", self.bg)
		:Offset(-targetW * 0.5, 0)

	-- Bottom glow
	self.skinPanelGlow:SetSize(self.width * 1.2, self.width * 1.2)
		:LayoutBounds("center", "bottom", self.bg)

	return self
end

return RefineryPanel
