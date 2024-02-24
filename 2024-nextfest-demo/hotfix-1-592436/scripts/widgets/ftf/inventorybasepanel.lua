local Image = require "widgets.image"
local TabGroup = require "widgets.tabgroup"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local DropDown = require "widgets.dropdown"
local TextEdit = require "widgets.textedit"
local ImageButton = require"widgets.imagebutton"
local itemcatalog = require "defs.itemcatalog"

------------------------------------------------------------------------------------------
--- Shouldn't be used on its own. A base panel for the player's inventory, npc shops, etc
----
local InventoryBasePanel = Class(Widget, function(self, tabs, width)
	Widget._ctor(self, "InventoryBasePanel")

	width = width or 840
	self.width = width * HACK_FOR_4K
	self.contentWidth = self.width - 50 * HACK_FOR_4K
	self.height = RES_Y

	self.tabSize = 40 * HACK_FOR_4K
	self.headerHeight = 100 * HACK_FOR_4K
	self.subheaderTopMargin = 15 * HACK_FOR_4K
	self.subheaderHeight = 70 * HACK_FOR_4K
	self.subheaderSpacing = 20 * HACK_FOR_4K -- Between subheader and center
	self.footerHeight = 280 * HACK_FOR_4K
	self.centerSpacing = 2 * HACK_FOR_4K -- Between list and footer
	self.footerSpacing = 20 * HACK_FOR_4K -- Between footer and bottom
	self.sortSpacing = 10 * HACK_FOR_4K

	-- Background
	self.bg = self:AddChild(Image("images/square.tex"))
		:SetSize(self.width, self.height)
		:SetMultColor(0x020201ff)
		:SetMultColorAlpha(0.8)

	-- Header
	self.header = self:AddChild(Widget("Sidebar Header"))
	self.title = self.header:AddChild(Text(FONTFACE.DEFAULT, 50 * HACK_FOR_4K, STRINGS.UI.INVENTORYSCREEN.MENU_TITLE, UICOLORS.LIGHT_TEXT_TITLE))
		:SetAutoSize(self.contentWidth)
		:LeftAlign()
	self.title_decor_left = self.header:AddChild(Image("images/ui_ftf_inventory/InventoryTitleDecorLeft.tex"))
		:SetSize(40 * HACK_FOR_4K, 40 * HACK_FOR_4K)
	self.title_decor_right = self.header:AddChild(Image("images/ui_ftf_inventory/InventoryTitleDecorRight.tex"))
		:SetSize(40 * HACK_FOR_4K, 40 * HACK_FOR_4K)
	self.closeButton = self.header:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)

	-- Tabs
	self.subheader = self:AddChild(Widget("Sidebar Subheader"))
	local tabs_texture_w, tabs_texture_h = 1280, 188
	local tabs_w = self.width + 10 * HACK_FOR_4K
	self.subheaderHeight = tabs_w * tabs_texture_h / tabs_texture_w
	self.tabsBg = self.subheader:AddChild(Image("images/ui_ftf_inventory/TabsBar.tex"))
		:SetScale(1.33, 1)

	-- Layout header
	self.header:LayoutBounds("center", "top", self.bg)
		:Offset(0, -10)
	self.subheader:LayoutBounds("left", "top", self.bg)
		:Offset(0, -self.headerHeight)
	self.centerHeight = self.height - self.headerHeight + self.subheaderTopMargin - self.subheaderSpacing - self.subheaderHeight - self.centerSpacing - self.footerHeight - self.footerSpacing - self.sortSpacing

	-- Search
	self.filter_str = {}
	self.filter_text = self:AddChild(TextEdit(nil, 20 * HACK_FOR_4K, ""))
		:SetInventoryTheme()
		:SetFocusedImage("images/ui_ftf_inventory/InventorySearch.tex", "images/ui_ftf_inventory/InventorySearchFocused.tex", "images/ui_ftf_inventory/InventorySearchFocused.tex")
		:SetNineSliceCoords(116, 0, 248, 88)
		:SetSize(425 * HACK_FOR_4K, 52 * HACK_FOR_4K, 70 * HACK_FOR_4K, 0, 5 * HACK_FOR_4K, 0)
		:SetFontSize(36 * HACK_FOR_4K)
		:SetTextPrompt(STRINGS.UI.INVENTORYSCREEN.FILTER)
		:SetScale(0.7)
		:SetForceEdit(true)
		:SetNavFocusable(false)


	-- Dropdown
	self.sort_dropdown = self:AddChild(DropDown(300 * HACK_FOR_4K))
		:SetBackground("images/ui_ftf_inventory/InventoryDropdown.tex", 10, 0, 216, 88)
		:SetBackgroundColour(0xFFFFFFff)
		:SetButtonColour(UICOLORS.LIGHT_TEXT)
		:SetTextColour(UICOLORS.LIGHT_TEXT)
		:SetButtonMargin(8)
		:SetButtonMarginRight(24 * HACK_FOR_4K)
		:SetListWidthOffset(-23 * HACK_FOR_4K, -7 * HACK_FOR_4K)
		:SetSize(425 * HACK_FOR_4K)
		:SetScale(0.7)
		:SetNavFocusable(false)


	-- Layout everything
	self:Layout()
end)

function InventoryBasePanel:SetSlotTabs( slots )
	local icon_spacing = 25 * HACK_FOR_4K

	self.inventory_slots = deepcopy(slots)

	if self.item_category_root then
		self.item_category_root:Remove()
	end

	self.item_category_root = self.subheader:AddChild(TabGroup())

	for _, slot in ipairs(self.inventory_slots) do

		local icon = slot.icon
		if not icon then
			local slot_def = itemcatalog.All.SlotDescriptor[slot.slots[1]]
			icon = slot_def.icon
		end

		local tab_btn = self.item_category_root:AddTab(icon)
		tab_btn.slot_data = slot
	end

	self.item_category_root:SetTabSize(self.tabSize, self.tabSize)
		:SetTabOnClick(function(tab_btn) self:OnCategoryTabClicked(tab_btn, tab_btn.slot_data) end)
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:LayoutChildrenInGrid(100, icon_spacing)
		:AddCycleIcons()
		:LayoutBounds("center", "center", self.tabsBg)
		:Offset(-1 * HACK_FOR_4K, 5 * HACK_FOR_4K)

	if not self.slot then
		self.slot = slots[1]
	end

	-- If there's only one slot, hide the subheader
	self.subheader:SetShown(self.item_category_root:GetNumTabs() > 1)

	self:Layout()
	return self
end

function InventoryBasePanel:Refresh(player)
	self.player = player
	self:Layout()
	return self
end

function InventoryBasePanel:SetTitle(title)
	self.title:SetText(title)
	self:Layout()
	return self
end

function InventoryBasePanel:Layout()

	self.header:SendToFront()
	self.filter_text:SendToFront()
	self.sort_dropdown:SendToFront()

	-- Update height, in case there isn't a subheader anymore
	self.centerHeight = self.height - self.headerHeight - self.centerSpacing - self.footerHeight - self.footerSpacing - self.sortSpacing
	if self.subheader:IsShown() then
		self.centerHeight = self.centerHeight + self.subheaderTopMargin - self.subheaderSpacing - self.subheaderHeight
	end

	-- Layout titles
	self.title:LayoutBounds("center", "top", self.bg)
		:Offset(0, -25 * HACK_FOR_4K)
	self.title_decor_left:LayoutBounds("before", "center", self.title)
		:Offset(-10 * HACK_FOR_4K, 0)
	self.title_decor_right:LayoutBounds("after", "center", self.title)
		:Offset(10 * HACK_FOR_4K, 0)
	self.closeButton:LayoutBounds("right", "top", self.bg)
		:Offset(15 * HACK_FOR_4K, -22 * HACK_FOR_4K)

	self.sort_dropdown:LayoutBounds("right", nil, self.bg)
		:LayoutBounds(nil, self.subheader:IsShown() and "below" or "top", self.subheader)
		:Offset(-9, 0)
		:Hide() -- Hiding because the things in this sort menu are no longer relevant. Keeping here in case we want to add back in some kind of sort.
	self.filter_text:LayoutBounds("left", nil, self.bg)
		:LayoutBounds(nil, self.subheader:IsShown() and "below" or "top", self.subheader)
		:Offset(9, 0)

	return self
end

function InventoryBasePanel:ClickFirstSlot()
	if #self.item_category_root.tabs > 0 then
		self.item_category_root.tabs[1]:Click()
	end
	return self
end

function InventoryBasePanel:SetOnCategoryClickFn(fn)
	self.onCategoryClickFn = fn
	return self
end

-- Called when a category tab is clicked
function InventoryBasePanel:OnCategoryTabClicked(selected_tab_btn, slot_data)
	-- Notify category changed
	if self.onCategoryClickFn then self.onCategoryClickFn(slot_data) end
end

function InventoryBasePanel:ClickTab(slot_key)
	if not slot_key then return self end
	for i, tab in ipairs(self.item_category_root.tabs) do
		if tab.slot_data.key == slot_key then
			tab:Click()
			return self
		end
	end
	return self
end

-- Sets a tab as selected without triggering its click function
function InventoryBasePanel:SelectTab(slot_key)
	if not slot_key then return self end
	for i, tab in ipairs(self.item_category_root.tabs) do
		if tab.slot_data.key == slot_key then
			self.item_category_root:SelectTab(i, false)
			return self
		end
	end
	return self
end

function InventoryBasePanel:NextTab(delta)
	self.item_category_root:NextTab(delta)
	return self
end

function InventoryBasePanel:SetOnCloseFn(fn)
	self.closeButton:SetOnClick(fn)
	return self
end

return InventoryBasePanel
