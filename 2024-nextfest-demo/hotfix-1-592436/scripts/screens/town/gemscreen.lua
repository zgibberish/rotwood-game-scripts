local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local ImageButton = require("widgets/imagebutton")
local Image = require("widgets/image")
local Panel = require("widgets/panel")
local Clickable = require("widgets/clickable")
local ScrollPanel = require "widgets.scrollpanel"
local Text = require("widgets/text")
local GemXpBar = require("widgets/gemxpbar")
local Equipment = require("defs.equipment")
local EquipmentGem = require "defs.equipmentgems.equipmentgem"
local EquipmentDescriptionWidget = require("widgets/ftf/equipmentdescriptionwidget")
local RecipeIconHeader = require"widgets.ftf.recipeiconheader"

local easing = require "util.easing"
local krandom = require "util.krandom"

local GEM_SLOT_ICONS =
{
	DAMAGE = "images/ui_ftf_gems/slot_gem_damage.tex",
	SUPPORT = "images/ui_ftf_gems/slot_gem_support.tex",
	SUSTAIN = "images/ui_ftf_gems/slot_gem_sustain.tex",
	ANY = "images/ui_ftf_gems/slot_gem_any.tex",
}


------------------------------------------------------------------------------------------------
-- A single clickable gem widget, to be part of a list
--
--   ┌──────────────┐
--   │              │ ◄ icon
--   │              │
--   │              │
--   │              │
--   │              │
-- ┌─┤              ├─┐
-- │ └──────────────┘ │ ◄ shadow
-- └──────────────────┘
--  ┌────────────────┐
--  │ gem_name       │
--  │ gem_level      │
--  └────────────────┘

local GemItemWidget = Class(Clickable, function(self, gem)
	Clickable._ctor(self)

	self.width = 270
	self.icon_width = 256

    self:SetScales(1, 1.05, 1, 0.15)
    self:ShowToolTipOnFocus(true)

	self.shadow = self:AddChild(Image("images/ui_ftf_gems/gem_shadow.tex"))
		:SetName("Shadow")

	self.icon = self:AddChild(Image("images/global/square.tex"))
		:SetName("Icon")
		:SetSize(self.icon_width, self.icon_width)
		:LayoutBounds("center", "bottom", self.shadow)
		:Offset(0, 20)

	self.gem_name = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT*1.1))
		:SetName("Gem name")
		:SetAutoSize(self.width)
		:SetText("")
		:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
		:SetHAlign(ANCHOR_MIDDLE)

	self.gem_level = self:AddChild(GemXpBar(self.gem))
		:SetName("Gem level")
		:SetTextColor(HexToRGB(0x967D7155)) --UICOLORS.LIGHT_TEXT_DARK, but fainter

	self:SetGemItem(gem)
end)

function GemItemWidget:SetGemItem(gem)
	self.gem = gem
	local def = gem:GetDef()
	local name = def.pretty.name
	self.type = def.gem_type

	self.icon:SetTexture(def.icon)
	self.gem_name:SetText(name.." "..STRINGS.ITEMS.GEMS.ILVL_TO_NAME[self.gem.ilvl])
	self.gem_level:SetGem(self.gem)

	if self.gem.equipped_in then
		--added tooltip showing what the gem does so you can check before you slot it--Kris
		self:SetToolTip(def.pretty.slotted_desc .. "\n\n" .. string.format(STRINGS.UI.GEMSCREEN.GEM_EQUIPPED_TT, STRINGS.ITEMS.WEAPON[self.gem.equipped_in].name))
	else
		--same here --Kris
		self:SetToolTip(def.pretty.slotted_desc)
	end

	self:_Layout()
	return self
end

function GemItemWidget:GetGemItem()
	return self.gem
end

function GemItemWidget:SetGemSelected(is_selected)
	self.is_selected = is_selected
	self:_Layout()
	return self
end

-- If this gem is compatible with the current gem slot
function GemItemWidget:SetSelectable(is_selectable)
	self.is_selectable = is_selectable
	self:_Layout()
	return self
end

function GemItemWidget:_Layout()

	-- Update colors based on state
	if self.is_selected then
		-- Currently equipped gem in the selected slot
		self.icon:SetSaturation(1)
			:SetMultColor(UICOLORS.WHITE)
			:SetAddColor(UICOLORS.BLACK)
		self.gem_name:SetMultColorAlpha(1)
	elseif self.is_selectable then
		-- Can be equipped in the selected slot
		self.icon:SetSaturation(1)
			:SetMultColor(UICOLORS.WHITE)
			:SetAddColor(UICOLORS.BLACK)
		self.gem_name:SetMultColorAlpha(1)
	else
		-- Can't be equipped in the selected slot
		self.icon:SetSaturation(0.4)
			:SetMultColor(HexToRGB(0x303030ff))
			:SetAddColor(HexToRGB(0xA79688ff))
		self.gem_name:SetMultColorAlpha(0.3)
	end

	self.gem_name:LayoutBounds("center", "center", self.shadow)
		:Offset(0, -75)
	self.gem_level:LayoutBounds("center", "below", self.shadow)
		:Offset(0, -95)

	return self
end


------------------------------------------------------------------------------------------------
-- A single gem slot for a weapon
--
-- ┌───────────────────────────────────────────────────────────────┐
-- │  ┌────────────┐                                               │
-- │  │ slot_icon  │  ▼ text_container                             │
-- │  │ gem_icon   │  ┌──────────────────────────────────────────┐ │
-- │  │            │  │ title                                    │ │
-- │  │            │  │ desc_empty                               │ │
-- │  │            │  │ desc_widget(EquipmentDescriptionWidget)  │ │
-- │ ┌┴────────────┴┐ │                                          │ │
-- │ │ slot_type    │ └──────────────────────────────────────────┘ │
-- │ │ gem_level    │                                              │
-- │ └──────────────┘                                              │
-- └───────────────────────────────────────────────────────────────┘
--

local GemSlotDetailsWidget = Class(Clickable, function(self, player, slot)
	Clickable._ctor(self)

	self.slot = slot
	self.selected_slot = false
	self.focus_scale = {1.02, 1.02, 1.02}

	self.bg = self:AddChild(Image("images/ui_ftf_gems/gem_slot_bg.tex"))
		:SetName("Bg")

	----------------------------------------------------------------------------------
	-- Left side
	----------------------------------------------------------------------------------

	-- Shows the type of slot, when there isn't a gem equipped
	self.slot_icon = self:AddChild(Image(GEM_SLOT_ICONS[self.slot.slot_type]))
		:SetName("Slot icon")
		:SetHiddenBoundingBox(true)
		:SetSize(250, 250)
		:LayoutBounds("left", "center", self.bg)
		:Offset(20, 25)
		:Show()

	self.slot_type = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_SCREEN_SUBTITLE*.5))
		:SetText(STRINGS.GEMS.SLOT_TYPE[self.slot.slot_type])
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:LayoutBounds("center", "below", self.slot_icon)
		:Offset(0, 30)
		:Show()

	self.slot_max_level = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_SCREEN_SUBTITLE*.5))
		:SetText(STRINGS.UI.GEMSCREEN.MAX_LEVEL_GEM)
		:SetGlyphColor(UICOLORS.GEM)
		:LayoutBounds("center", "below", self.slot_icon)
		:Offset(0, 30)
		:Hide()

	self.gem_icon = self:AddChild(Image("images/global/square.tex"))
		:SetName("Gem icon")
		:SetHiddenBoundingBox(true)
		:SetSize(180, 180)
		:LayoutBounds("center", "center", self.slot_icon)
		:Offset(0, 10)
		:Hide()

	self.gem_level = self:AddChild(GemXpBar())
		:SetName("Gem level")
		:LayoutBounds("center", "below", self.gem_icon)
		:Offset(0, 0)
		:Hide()

	----------------------------------------------------------------------------------
	-- Right side
	----------------------------------------------------------------------------------

	self.content_width = 840

    self.text_container = self:AddChild(Widget("Text Container"))
    self.title = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT * 1.2))
		:SetName("Title")
		:SetGlyphColor(UICOLORS.BACKGROUND_MID)
		:SetAutoSize(self.content_width)
	self.item_level = self.text_container:AddChild(Widget())
		:SetName("Item level")
	self.desc_empty = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT, "", UICOLORS.DARK_TEXT))
		:SetName("Description empty")
		:SetAutoSize(self.content_width)
		:LeftAlign()
	self.desc_widget = self.text_container:AddChild(EquipmentDescriptionWidget(self.content_width, FONTSIZE.SCREEN_TEXT))
		:SetName("Description widget")


	if self.slot.gem then
		self:ShowEquippedGem(self.slot.gem)
	else
		self:RemoveEquippedGem()
	end
end)

function GemSlotDetailsWidget:SetSlotSelected(is_selected)
	self.is_selected = is_selected
	self:_Layout()
	return self
end

function GemSlotDetailsWidget:IsSlotSelected(is_selected)
	return self.is_selected
end

function GemSlotDetailsWidget:GetSlotType()
	return self.slot.slot_type
end

function GemSlotDetailsWidget:GetEquippedGem()
	return self.gem
end

function GemSlotDetailsWidget:ShowEquippedGem(gem)
	self:RemoveEquippedGem()

	self.slot_icon:Hide()
	self.slot_type:Hide()

	-- Refresh contents
	self.gem = gem
	local def = self.gem:GetDef()
	self.gem_icon:SetTexture(def.icon)
		:Show()
	self.gem_level:SetGem(self.gem)
		:Show()
	self.title:SetText(def.pretty.name.." "..STRINGS.ITEMS.GEMS.ILVL_TO_NAME[self.gem.ilvl])
	self.desc_empty:Hide()
	self.slot_max_level:SetShown(gem.ilvl == #def.base_exp)
	self.desc_widget:SetItem(self.gem, true)
		:Show()

	self:_Layout()
	return self
end

function GemSlotDetailsWidget:RemoveEquippedGem()
	self.slot_icon:SetTexture(GEM_SLOT_ICONS[self.slot.slot_type])
		:Show()
	self.slot_type:SetText(STRINGS.GEMS.SLOT_TYPE[self.slot.slot_type]:upper())
		:Show()
	self.gem_icon:Hide()
	self.gem_level:Hide()
	if self.slot.slot_type == "ANY" then
		self.title:SetText(STRINGS.UI.GEMSCREEN.TITLE_EMPTY_ANY)
		self.desc_empty:SetText(STRINGS.UI.GEMSCREEN.DESC_EMPTY_ANY)
			:Show()
	else
		self.title:SetText(string.format(STRINGS.UI.GEMSCREEN.TITLE_EMPTY, STRINGS.GEMS.SLOT_TYPE[self.slot.slot_type]))
		self.desc_empty:SetText(string.format(STRINGS.UI.GEMSCREEN.DESC_EMPTY, STRINGS.GEMS.SLOT_TYPE[self.slot.slot_type]))
			:Show()
	end
	self.desc_widget:Hide()

	self:_Layout()
	return self
end

function GemSlotDetailsWidget:_Layout()

	self.gem_level:LayoutBounds("center", "below", self.gem_icon)
		:Offset(0, 0)
	self.title:SetPos(0, 0)
	self.desc_empty:LayoutBounds("left", "below", self.title)
		:Offset(0, 0)
	self.desc_widget:LayoutBounds("left", "below", self.title)
		:Offset(0, 0)
	self.text_container:LayoutBounds("left", "center", self.bg)
		:Offset(340, 0)

	return self
end

------------------------------------------------------------------------------------------------
-- Lists a weapon's clickable gem slots
--
-- slot_container
-- ┌─────────────────────────────────────────┐
-- │ slot_container                          │
-- │ ┌─────────────────────────────────────┐ │
-- │ │ GemSlotDetailsWidget                │ │
-- │ │                                     │ │
-- │ │                                     │ │
-- │ └─────────────────────────────────────┘ │
-- │ ┌─────────────────────────────────────┐ │
-- │ │                                     │ │
-- │ │                                     │ │
-- │ │                                     │ │
-- │ └─────────────────────────────────────┘ │
-- │ ┌─────────────────────────────────────┐ │
-- │ │                                     │ │
-- │ │                                     │ │
-- │ │                                     │ │
-- │ └─────────────────────────────────────┘ │
-- └─────────────────────────────────────────┘
--
local WeaponGemSlotsContainer = Class(Widget, function(self, weapon, player)
    Image._ctor(self)

    self.player = player

    self.slot_container = self:AddChild(Widget("Slot Container"))

	-- This weapon's configured gemslots
    local slots = weapon.gem_slots

    -- Make a slot widget for each
	for i, slot_data in ipairs(slots) do
		local slot_widget = self.slot_container:AddChild(GemSlotDetailsWidget(player, slot_data))
		slot_widget:SetOnClick(function() self:OnClickSlot(slot_widget, slot_data, i) end)
		slot_widget:SetOnClickAlt(function() self:OnRightClickSlot(slot_widget, slot_data, i) end)
		-- slot_widget:SetOnGainFocus(function() if TheFrontEnd:IsRelativeNavigation() then self:OnClickSlot(slot_widget, slot_data, i) end end)
	end

    self.slot_container:LayoutChildrenInColumn(40)

	-- Info label for when the weapon has no gem slots
	self.empty_label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT*1.3))
		:SetText(STRINGS.UI.GEMSCREEN.SLOTS_EMPTY)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetAutoSize(600)
		:SetShown(not self.slot_container:HasChildren())
		:Offset(0, -350)
end)

function WeaponGemSlotsContainer:HasSlots()
	return self.slot_container:HasChildren()
end

function WeaponGemSlotsContainer:SetOnSlotSelected(fn)
	self.on_slot_selected_fn = fn
	return self
end

function WeaponGemSlotsContainer:SetOnSlotAltClick(fn)
	self.on_slot_alt_click_fn = fn
	return self
end

function WeaponGemSlotsContainer:SelectIndex(index)
	if self.slot_container.children[index] then
		self.slot_container.children[index]:Click()
	end
	return self
end

function WeaponGemSlotsContainer:GetIndexSlot(idx)
	for i, w in ipairs(self.slot_container.children) do
		if i == idx then return w end
	end
	return nil
end

function WeaponGemSlotsContainer:GetFocusedSlot()
	for idx, w in ipairs(self.slot_container.children) do
		if w:HasFocus() then return w, idx end
	end
	return nil
end

function WeaponGemSlotsContainer:GetSelectedSlot()
	for idx, w in ipairs(self.slot_container.children) do
		if w:IsSlotSelected() then return w, idx end
	end
	return nil
end

function WeaponGemSlotsContainer:OnClickSlot(slot_widget, slot_data, slot_number)

	-- Select the correct slot
	for k, widget in ipairs(self.slot_container.children) do
		widget:SetSlotSelected(widget == slot_widget)
	end

	-- Notify listeners
	if self.on_slot_selected_fn then self.on_slot_selected_fn(slot_widget, slot_data, slot_number) end
end

function WeaponGemSlotsContainer:OnRightClickSlot(slot_widget, slot_data, slot_number)

	-- Notify listeners
	if self.on_slot_alt_click_fn then self.on_slot_alt_click_fn(slot_widget, slot_data, slot_number) end
end

------------------------------------------------------------------------------------------------
-- 

local GemsCollectionWidget = Class(Widget, function(self, width, height)
    Widget._ctor(self)

    self.width = width or 400
    self.height = height or 400

	self.item_list = self:AddChild(ScrollPanel())
		:SetSize(self.width, self.height)
		:SetVirtualMargin(150)
		:SetBarInset(80)

	-- Container for item rows within the scroll panel
	self.item_list_content = self.item_list:AddScrollChild(Widget())

	-- Add this to reveal the bounds of the scroll panel, for alignment
	-- self.item_list:AddScrollChild(Image("images/global/square.tex"))
	-- 	:SetMultColor(UICOLORS.DEBUG)
	-- 	:SetSize(3000, 3000)

	-- Info label for when the player has no gems yet
	self.empty_label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT*1.3))
		:SetText(STRINGS.UI.GEMSCREEN.GEMS_EMPTY)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetAutoSize(600)
		:LayoutBounds("center", "center", self.item_list)
		:Offset(-50, 40)
end)

function GemsCollectionWidget:SetOnScroll(fn)
	self.item_list:SetFn(fn)
	return self
end

function GemsCollectionWidget:GetGemWidgets()
	return self.item_list_content.children
end

function GemsCollectionWidget:FocusOnIndex(idx)
	if idx and idx <= #self.item_list_content.children then
		self.item_list_content.children[idx]:SetFocus()
	elseif self.item_list_content:HasChildren() then
		self.item_list_content.children[1]:SetFocus()
	end
	return self
end

function GemsCollectionWidget:HasGems()
	return self.item_list_content:HasChildren()
end

function GemsCollectionWidget:PopulateWithGemsOfType(type, player, current_gem)

	self.selected_gem_widget = nil

	-- If the list is empty, add gem widgets
	if not self.item_list_content:HasChildren() then
		local items = player.components.inventoryhoard:GetAllGems()
		for i, gem_item in ipairs(items) do
			self.item_list_content:AddChild(GemItemWidget(gem_item))
		end

		self.item_list_content:LayoutChildrenInGrid(3, 40)
			:LayoutBounds("center", "top", self.item_list)
			:Offset(-50, -50)

		self.item_list:RefreshView()
	end

	-- Refresh their status
	local items = player.components.inventoryhoard:GetAllGems()
	for i, gem_item in ipairs(items) do
		local def = gem_item:GetDef()
		local gem_widget = self.item_list_content.children[i]
		local is_gem_equipped = gem_item.equipped_in

		gem_widget:SetGemItem(gem_item)

		gem_widget:SetOnClick(function()
			if (def.gem_type == type or type == "ANY") and not is_gem_equipped then
				self:OnGemClicked(gem_widget, gem_item)
			end
		end)
		gem_widget:SetSelectable((def.gem_type == type or type == "ANY") and not is_gem_equipped)

		-- Useful to debug extra exp/levels into gems
		-- gem_widget:SetOnClickAlt(function() 
		-- 	gem_item.ilvl_max = #def.base_exp
		-- 	gem_item.exp_max = def.base_exp[gem_item.ilvl]
		-- 	d_view(gem_item) end)

		-- If a gem is meant to be shown as selected, do so
		if current_gem and gem_item == current_gem then
			self.selected_gem_widget = gem_widget
			gem_widget:SetGemSelected(true)
		else
			gem_widget:SetGemSelected(false)
		end

	end

	self.empty_label:SetShown(not self.item_list_content:HasChildren())
end

function GemsCollectionWidget:GetSelectedGemWiget()
	return self.selected_gem_widget
end

function GemsCollectionWidget:SetOnGemClickedFn(fn)
	self.on_gem_clicked_fn = fn
	return self
end

function GemsCollectionWidget:OnGemClicked(gem_widget, gem_item)
	self.selected_gem_widget = gem_widget
	if self.on_gem_clicked_fn then self.on_gem_clicked_fn(gem_widget, gem_item) end
end

------------------------------------------------------------------------------------------------
-- Allows the player to equip gems in their current weapon
--
--  ▼ root contains both panels
--               ┌───────────────┐
--               │ weapon_icon   │ ◄ RecipeIconHeader
--               │               │
--               │               │         ▼ close_button
--               │               │       ┌───┐
-- ┌─────────────┤               ├───────┤ X ├─┐
-- │             │               │       └───┘ ├────────┬────────────────────┬─────────┐
-- │             │               │             │        │ gems_title         │         │
-- │             └───────────────┘             │        └────────────────────┘         │
-- │                                           │                                       │
-- │  slots_container(WeaponGemSlotsContainer) │  gems_container(GemsCollectionWidget) │
-- │  ┌─────────────────────────────────────┐  │  ┌─────────┐ ┌─────────┐ ┌─────────┐  │
-- │  │ GemSlotDetailsWidget                │  │  │         │ │         │ │         │  │ ◄ GemItemWidget
-- │  │                                     │  │  │         │ │         │ │         │  │
-- │  │                                     │  │  │         │ │         │ │         │  │
-- │  └─────────────────────────────────────┘  │  │         │ │         │ │         │  │
-- │                                           │  │         │ │         │ │         │  │
-- │  ┌─────────────────────────────────────┐  │  └─────────┘ └─────────┘ └─────────┘  │
-- │  │                                     │  │  ┌─────────┐ ┌─────────┐              │
-- │  │                                     │  │  │         │ │         │              │
-- │  │                                     │  │  │         │ │         │              │
-- │  └─────────────────────────────────────┘  │  │         │ │         │              │
-- │                                           │  │         │ │         │              │
-- │  ┌─────────────────────────────────────┐  │  │         │ │         │              │
-- │  │                                     │  │  └─────────┘ └─────────┘              │
-- │  │                                     │  │                                       │
-- │  │                                     │  │                                       │
-- │  └─────────────────────────────────────┘  │                                       │
-- │                                           │                                       │
-- │                                           │                                       │
-- │      ┌─────────────────────────────┐      │                                       │
-- │      │ info_label                  │      ├───────────────────────────────────────┘
-- └──────┴─────────────────────────────┴──────┘
--   ▲ weapon_panel                              ▲ gems_panel
--

local GemScreen = Class(Screen, function(self, player, on_close_cb)
	Screen._ctor(self, "GemScreen")
	self:SetOwningPlayer(player)

	self.on_close_cb = on_close_cb
	local equipped_weapon = player.components.inventoryhoard:GetEquippedItem(Equipment.Slots.WEAPON)

	self.darken = self:AddChild(Image("images/ui_ftf_roombonus/background_gradient.tex"))
		:SetAnchors("fill", "fill")
		:SetMultColorAlpha(0)

	----------------------------------------------------------------------------------
	-- Root (allows us to center the two panels in the screen)
	----------------------------------------------------------------------------------

	self.root = self:AddChild(Widget())
		:SetName("Root")


	----------------------------------------------------------------------------------
	-- Weapon panel
	----------------------------------------------------------------------------------

	self.weapon_panel = self.root:AddChild(Widget())
		:SetName("Weapon panel")
	self.weapon_panel_bg = self.weapon_panel:AddChild(Image("images/ui_ftf_gems/weapons_panel_bg.tex"))
		:SetName("Weapon panel bg")

	-- Weapon icon badge
	self.weapon_icon = self.weapon_panel:AddChild(RecipeIconHeader(400))
		:SetName("Weapon icon")
		:SetHiddenBoundingBox(true)
		:SetItem(equipped_weapon)
		:HideRarity()

	-- Close button
	self.close_button = self.weapon_panel:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		:LayoutBounds("right", "top", self.weapon_panel_bg)
		:Offset(-60, 10)
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:SetOnClick(function()
			self:OnCloseButton()
		end)

	-- Slots container
	self.slots_container = self.weapon_panel:AddChild(WeaponGemSlotsContainer(equipped_weapon, player, self))
		:SetName("Slots container")
		:SetOnSlotSelected(function(slot_widget, slot_data, slot_number) self:OnGemSlotSelected(slot_widget, slot_data, slot_number) end)
		:SetOnSlotAltClick(function(slot_widget, slot_data, slot_number) self:OnGemSlotAltClicked(slot_widget, slot_data, slot_number) end)

	-- Info label
	self.info_label = self.weapon_panel:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT, STRINGS.UI.GEMSCREEN.INFO_LABEL, UICOLORS.LIGHT_TEXT_DARK))
		:SetName("Info label")
		:SetAutoSize(700)
		:SetShown(self.slots_container:HasSlots())


	----------------------------------------------------------------------------------
	-- Gems panel
	----------------------------------------------------------------------------------

	self.gems_panel = self.root:AddChild(Widget())
		:SetName("Gems panel")
		:SendToBack()
	self.gems_panel_bg = self.gems_panel:AddChild(Image("images/ui_ftf_gems/gems_panel_bg.tex"))
		:SetName("Gems panel bg")

	-- Gems container
	self.gems_container = self.gems_panel:AddChild(GemsCollectionWidget(1150, 1400))
		:SetName("Gems container")
		:SetOnScroll(function() self:OnGemContainerScrolled() end)
		:SetOnGemClickedFn(function(gem_widget, gem_item) self:OnGemClicked(gem_widget, gem_item) end)

	-- These go over the scroll panel, so it looks properly scissored
	self.gems_panel_top = self.gems_panel:AddChild(Image("images/ui_ftf_gems/gems_panel_top.tex"))
		:SetName("Gems panel top")
		:LayoutBounds(nil, "top", self.gems_panel_bg)
	self.gems_panel_bottom = self.gems_panel:AddChild(Image("images/ui_ftf_gems/gems_panel_bottom.tex"))
		:SetName("Gems panel bottom")
		:LayoutBounds(nil, "bottom", self.gems_panel_bg)

	-- Gems title
	self.gems_title_bg = self.gems_panel:AddChild(Image("images/ui_ftf_gems/gem_panel_title_bg.tex"))
		:SetName("Gems title bg")
	self.gems_title = self.gems_panel:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE, STRINGS.UI.GEMSCREEN.GEMS_TITLE, UICOLORS.BACKGROUND_DARK))
		:SetName("Gems title")

	----------------------------------------------------------------------------------
	-- Selection brackets
	----------------------------------------------------------------------------------

	-- Focus brackets
	self.focus_brackets = self:AddChild(Panel("images/ui_ftf_gems/selection_brackets.tex"))
		:SetName("Selection brackets")
		:SetNineSliceCoords(78, 94, 80, 96)
		:SetHiddenBoundingBox(true)
		:IgnoreInput(true)
		:Hide()

	-- Animate them too
	local speed = 1.35
	local amplitude = 14
	self.focus_brackets_w = 100
	self.focus_brackets_h = 100
	self.focus_brackets:RunUpdater(
		Updater.Loop({
			Updater.Ease(function(v) self.focus_brackets:SetSize(self.focus_brackets_w + v, self.focus_brackets_h + v) end, amplitude, 0, speed, easing.inOutQuad),
			Updater.Ease(function(v) self.focus_brackets:SetSize(self.focus_brackets_w + v, self.focus_brackets_h + v) end, 0, amplitude, speed, easing.inOutQuad),
		}))


	-- Slot selection arrows
	self.slot_selection_arrow_left = self:AddChild(Image("images/ui_ftf_gems/selection_arrow_left.tex"))
		:SetName("Slot selection arrow left")
		:SetHiddenBoundingBox(true)
		:IgnoreInput(true)
	self.slot_selection_arrow_right = self:AddChild(Image("images/ui_ftf_gems/selection_arrow_right.tex"))
		:SetName("Slot selection arrow right")
		:SetHiddenBoundingBox(true)
		:IgnoreInput(true)

	-- Animate them too
	local speed = 1.35
	local amplitude = 14
	self.slot_selection_arrow_left_x = 100
	self.slot_selection_arrow_right_x = 130
	self.slot_selection_arrows_y = 0
	self.slot_selection_arrow_left:RunUpdater(
		Updater.Loop({
			Updater.Ease(function(v)
				self.slot_selection_arrow_left:SetPos(self.slot_selection_arrow_left_x + v, self.slot_selection_arrows_y)
				self.slot_selection_arrow_right:SetPos(self.slot_selection_arrow_right_x - v, self.slot_selection_arrows_y)
			end, amplitude, 0, speed, easing.inOutQuad),
			Updater.Ease(function(v)
				self.slot_selection_arrow_left:SetPos(self.slot_selection_arrow_left_x + v, self.slot_selection_arrows_y)
				self.slot_selection_arrow_right:SetPos(self.slot_selection_arrow_right_x - v, self.slot_selection_arrows_y)
			end, 0, amplitude, speed, easing.inOutQuad),
		}))


	-- Gem selection arrows
	self.gem_selection_arrow_left = self:AddChild(Image("images/ui_ftf_gems/selection_arrow_left.tex"))
		:SetName("Gem selection arrow left")
		:SetHiddenBoundingBox(true)
		:IgnoreInput(true)
	self.gem_selection_arrow_right = self:AddChild(Image("images/ui_ftf_gems/selection_arrow_right.tex"))
		:SetName("Gem selection arrow right")
		:SetHiddenBoundingBox(true)
		:IgnoreInput(true)

	-- Animate them too
	local speed = 1.35
	local amplitude = 14
	self.gem_selection_arrow_left_x = 100
	self.gem_selection_arrow_right_x = 130
	self.gem_selection_arrows_y = 0
	self.gem_selection_arrow_left:RunUpdater(
		Updater.Loop({
			Updater.Ease(function(v)
				self.gem_selection_arrow_left:SetPos(self.gem_selection_arrow_left_x + v, self.gem_selection_arrows_y)
				self.gem_selection_arrow_right:SetPos(self.gem_selection_arrow_right_x - v, self.gem_selection_arrows_y)
			end, amplitude, 0, speed, easing.inOutQuad),
			Updater.Ease(function(v)
				self.gem_selection_arrow_left:SetPos(self.gem_selection_arrow_left_x + v, self.gem_selection_arrows_y)
				self.gem_selection_arrow_right:SetPos(self.gem_selection_arrow_right_x - v, self.gem_selection_arrows_y)
			end, 0, amplitude, speed, easing.inOutQuad),
		}))


	----------------------------------------------------------------------------------

	-- Focus lock
	self.focused_on_slots = true -- false if focusing on gems
	self.slots_container:SetFocusLock(self.focused_on_slots)
	self.gems_container:SetFocusLock(not self.focused_on_slots)

	----------------------------------------------------------------------------------

	self:Layout()

	-- Auto select first weapon gem slot
    self.default_focus = self.slots_container:GetIndexSlot(1) or self.weapon_icon
    self.slots_container:EaseTo(function() end, 0, 1, 0.2, nil,  function()
	    if self.slots_container:GetIndexSlot(1) then
			self.slots_container:GetIndexSlot(1):Click():SetFocus()
	    end
    end)
end)

function GemScreen:OnInputModeChanged(old_device_type, new_device_type)
	if not TheFrontEnd:IsRelativeNavigation() then
		self.focus_brackets:Hide()
	end
	self.info_label:RefreshText()
end

function GemScreen:OnFocusMove(dir, down)
	GemScreen._base.OnFocusMove(self, dir, down)
	local focus = self:GetDeepestFocus()
	if focus and TheFrontEnd:IsRelativeNavigation() then
		if self.focus_brackets:IsShown() == false then
			-- The player moved the gamepad joystick for the first time. Focus on the button
			self.focus_brackets:Show()
			self.default_focus:SetFocus()
			self:_UpdateFocusBrackets(self.default_focus)
		else
			-- Move brackets to this element
			self:_UpdateFocusBrackets(focus)
		end
	end
end

-- TODO: The gem list scrolled, so make sure the selection brackets and arrows are still on the correct items
function GemScreen:OnGemContainerScrolled()
end

function GemScreen:_UpdateFocusBrackets(target_widget)

	if self.last_target_widget == target_widget then return self end

	-- Get the brackets' starting position
	local start_pos = self.focus_brackets:GetPositionAsVec2()
	-- Get starting size
	local start_w, start_h = self.focus_brackets:GetSize()

	-- Align them with the target
	self.focus_brackets:LayoutBounds("center", "center", target_widget)
		:Offset(0, 0)

	-- Get the new position
	local end_pos = self.focus_brackets:GetPositionAsVec2()
	-- And the new size
	local w, h = target_widget:GetSize()
	local end_w, end_h = w + 120, h + 100

	-- Calculate midpoint
	local mid_pos = start_pos:lerp(end_pos, 0.2)
	-- Calculate a perpendicular vector from the midpoint
	local dir = start_pos - end_pos
	dir = dir:perpendicular()
	dir = dir:normalized()
	dir = mid_pos + dir*250

	-- Move them back and animate them in
	self.focus_brackets:SetPos(start_pos.x, start_pos.y)
		:CurveTo(end_pos.x, end_pos.y, dir.x, dir.y, 0.35, easing.outElasticUI)
		-- :SizeTo(start_w, end_w, start_h, end_h, 0.35, easing.outQuad)
		:Ease2dTo(function(w, h)
			self.focus_brackets_w = w
			self.focus_brackets_h = h
		end, start_w, end_w, start_h, end_h, 0.1, easing.linear)

	self.last_target_widget = target_widget

	-- If this widget is a gem, save the index, so we can focus on the
	-- same index when changing slots
	if self.gems_container:IsAncestorOf(target_widget) then
		self.last_focused_gem_idx = 1
		for k, v in ipairs(self.gems_container:GetGemWidgets()) do
			if v == target_widget then
				self.last_focused_gem_idx = k
			end
		end
	else
		self.last_focused_gem_idx = false -- Not a gem
	end

	return self
end

function GemScreen:_UpdateSlotSelectionArrows(target_row)

	if target_row then
		if self.last_selected_row == target_row then return self end

		-- Get the brackets' starting position
		local start_pos_left = self.slot_selection_arrow_left:GetPositionAsVec2()
		local start_pos_right = self.slot_selection_arrow_right:GetPositionAsVec2()

		-- Align them with the target
		self.slot_selection_arrow_left:LayoutBounds("before", "center", target_row)
			:Offset(-10, 0)
			:Show()
		self.slot_selection_arrow_right:LayoutBounds("after", "center", target_row)
			:Offset(10, 0)
			:Show()

		-- Get the new position
		local end_pos_left = self.slot_selection_arrow_left:GetPositionAsVec2()
		local end_pos_right = self.slot_selection_arrow_right:GetPositionAsVec2()

		-- Move them back and animate them in
		self.slot_selection_arrow_left:SetPos(start_pos_left.x, start_pos_left.y)
			:Ease2dTo(function(x, y)
				self.slot_selection_arrow_left_x = x
				self.slot_selection_arrows_y = y
			end, start_pos_left.x, end_pos_left.x, start_pos_left.y, end_pos_left.y, 0.65, easing.outElasticUI)
		self.slot_selection_arrow_right:SetPos(start_pos_right.x, start_pos_right.y)
			:Ease2dTo(function(x, y)
				self.slot_selection_arrow_right_x = x
				self.slot_selection_arrows_y = y
			end, start_pos_right.x, end_pos_right.x, start_pos_right.y, end_pos_right.y, 0.65, easing.outElasticUI)

	else
		-- No row. Hide arrows
		self.slot_selection_arrow_left:Hide()
		self.slot_selection_arrow_right:Hide()
	end

	self.last_selected_row = target_row
	return self
end

function GemScreen:_UpdateGemSelectionArrows(target_gem)

	if target_gem then

		if self.last_selected_gem == target_gem then return self end

		-- Get the brackets' starting position
		local start_pos_left = self.gem_selection_arrow_left:GetPositionAsVec2()
		local start_pos_right = self.gem_selection_arrow_right:GetPositionAsVec2()

		-- Align them with the target
		self.gem_selection_arrow_left:LayoutBounds("before", "center", target_gem)
			:Offset(10, 0)
			:Show()
		self.gem_selection_arrow_right:LayoutBounds("after", "center", target_gem)
			:Offset(-10, 0)
			:Show()

		-- Get the new position
		local end_pos_left = self.gem_selection_arrow_left:GetPositionAsVec2()
		local end_pos_right = self.gem_selection_arrow_right:GetPositionAsVec2()

		-- Move them back and animate them in
		self.gem_selection_arrow_left:SetPos(start_pos_left.x, start_pos_left.y)
			:Ease2dTo(function(x, y)
				self.gem_selection_arrow_left_x = x
				self.gem_selection_arrows_y = y
			end, start_pos_left.x, end_pos_left.x, start_pos_left.y, end_pos_left.y, 0.65, easing.outElasticUI)
		self.gem_selection_arrow_right:SetPos(start_pos_right.x, start_pos_right.y)
			:Ease2dTo(function(x, y)
				self.gem_selection_arrow_right_x = x
				self.gem_selection_arrows_y = y
			end, start_pos_right.x, end_pos_right.x, start_pos_right.y, end_pos_right.y, 0.65, easing.outElasticUI)
	else
		-- No gem. Hide arrows
		self.gem_selection_arrow_left:Hide()
		self.gem_selection_arrow_right:Hide()
	end

	self.last_selected_gem = target_gem
	return self
end

function GemScreen:EquipGem(gem_item, slot_widget, slot_number)
	local player = self:GetOwningPlayer()

	local existing_gem = player.components.gemmanager:GetGemInSlot(slot_number)

	if existing_gem then
		self:UnequipGem(slot_number)
	end
	player.components.gemmanager:EquipGem(gem_item, slot_number)
	slot_widget:ShowEquippedGem(gem_item)


	-- Get the current gem, if any
	local current_gem = nil
	current_gem = slot_widget:GetEquippedGem()
	self.gems_container:PopulateWithGemsOfType(slot_widget:GetSlotType(), player, current_gem)
end

function GemScreen:UnequipGem(slot_number)
	local player = self:GetOwningPlayer()

	player.components.gemmanager:UnequipGem(slot_number)

	local slot = self.slots_container.slot_container.children[slot_number]
	slot:RemoveEquippedGem()

	-- Show the gems that fit this slot type
	local slot_widget, slot_number = self.slots_container:GetSelectedSlot()
	self.gems_container:PopulateWithGemsOfType(slot_widget and slot_widget:GetSlotType() or "ANY", player)
	self:_UpdateGemSelectionArrows(nil)
end

-- If a gem is focused, and the list changed, set focus on a new gem
-- (in the same position, if possible)
function GemScreen:_RestoreGemFocus()
	if self.last_focused_gem_idx and TheFrontEnd:IsRelativeNavigation() then
		-- Set focus to the new gem in that index
		self.gems_container:FocusOnIndex(self.last_focused_gem_idx)
		-- And move the brackets over
		local target_widget = self:GetDeepestFocus()
		if target_widget then
			self:_UpdateFocusBrackets(target_widget)
		end
	end
end

function GemScreen:_ShowSelectedGem()
	if self.last_focused_gem_idx and TheFrontEnd:IsRelativeNavigation() then
		-- Set focus to the new gem in that index
		self.gems_container:FocusOnIndex(self.last_focused_gem_idx)
		-- And move the brackets over
		local target_widget = self:GetDeepestFocus()
		if target_widget then
			self:_UpdateFocusBrackets(target_widget)
		end
	end
end

function GemScreen:SetDefaultFocus()
	if #self.slots_container.slot_container.children > 0 then
		self.slots_container.slot_container.children[1]:SetFocus()
	else
		self.weapon_icon:SetFocus()
	end
	self.focused_on_slots = true
	self.slots_container:SetFocusLock(self.focused_on_slots)
	self.gems_container:SetFocusLock(not self.focused_on_slots)
	local focus = self:GetDeepestFocus()
	self:_UpdateFocusBrackets(focus)
end

function GemScreen:OnOpen()
	TheDungeon.HUD:Hide()

	-- Fill out the gems listing
	local player = self:GetOwningPlayer()
	self.gems_container:PopulateWithGemsOfType("ANY", player)
	self:_UpdateGemSelectionArrows(nil)
	self:_UpdateSlotSelectionArrows(nil)

	-- Get animation info
	local pacing = 0.2
	local weapon_x, weapon_y = self.weapon_panel:GetPos()
	local gems_x, gems_y = self.gems_panel:GetPos()
	self.weapon_panel:SetMultColorAlpha(0)
	self.gems_panel:SetMultColorAlpha(0)

	-- Animate in!
	self:RunUpdater(Updater.Parallel{
		Updater.Ease(function(a) self.darken:SetMultColorAlpha(a) end, 0, 1, pacing*4, easing.outQuad),

		Updater.Ease(function(a) self.weapon_panel:SetMultColorAlpha(a) end, 0, 1, pacing*0.5, easing.outQuad),
		Updater.Ease(function(y) self.weapon_panel:SetPos(weapon_x, y) end, weapon_y-60, weapon_y, pacing*5, easing.outElasticUI),

		Updater.Series{
			Updater.Wait(pacing*0.5),
			Updater.Parallel{
				Updater.Ease(function(a) self.gems_panel:SetMultColorAlpha(a) end, 0, 1, pacing, easing.outQuad),
				Updater.Ease(function(x) self.gems_panel:SetPos(x, gems_y) end, gems_x-150, gems_x, pacing*5, easing.outElasticUI),
			}
		}
	})
end

function GemScreen:OnCloseButton()
	local player = self:GetOwningPlayer()
	player.components.gemmanager:UpdateWeaponStats()

	TheFrontEnd:PopScreen(self)
	TheDungeon.HUD:Show()
end

function GemScreen:CloseScreen()
	TheDungeon.HUD:Show()
	TheFrontEnd:PopScreen(self)
end

-- When the player selects a gem slot for the current weapon
function GemScreen:OnGemSlotSelected(slot_widget, slot_data, slot_number)

	-- Animate the arrows into position
	self:_UpdateSlotSelectionArrows(slot_widget)

	-- Get the current gem, if any
	local current_gem = nil
	current_gem = slot_widget:GetEquippedGem()

	-- Show the gems that fit this slot type
	local player = self:GetOwningPlayer()
	self.gems_container:PopulateWithGemsOfType(slot_data.slot_type, player, current_gem)

	-- Check if a gem is already selected, and if so, show arrows around it
	local current_gem_widget = self.gems_container:GetSelectedGemWiget()
	if current_gem_widget then
		self:_UpdateGemSelectionArrows(current_gem_widget)
	else
		self:_UpdateGemSelectionArrows(nil)
	end

	-- Set focus on gems now
	self.focused_on_slots = false
	self.slots_container:SetFocusLock(self.focused_on_slots)
	self.gems_container:SetFocusLock(not self.focused_on_slots)
	if TheFrontEnd:IsRelativeNavigation() and self.gems_container:HasGems() then
		self.gems_container:FocusOnIndex(1)
		local focus = self:GetDeepestFocus()
		self:_UpdateFocusBrackets(focus)
	end

end

function GemScreen:OnGemSlotAltClicked(slot_widget, slot_data, slot_number)
	self:UnequipGem(slot_number)

	-- Show the gems that fit this slot type
	local player = self:GetOwningPlayer()
	self.gems_container:PopulateWithGemsOfType(slot_data.slot_type, player)
	self:_UpdateGemSelectionArrows(nil)
end

function GemScreen:OnGemClicked(gem_widget, gem_item)
	local slot_widget, slot_number = self.slots_container:GetSelectedSlot()
	if slot_widget then
		self:EquipGem(gem_item, slot_widget, slot_number)

		-- Refresh the list
		local player = self:GetOwningPlayer()
		self.gems_container:PopulateWithGemsOfType(slot_widget:GetSlotType(), player)

		self.focused_on_slots = true
		self.slots_container:SetFocusLock(self.focused_on_slots)
		self.gems_container:SetFocusLock(not self.focused_on_slots)
		if TheFrontEnd:IsRelativeNavigation() then
			slot_widget:SetFocus()
			local focus = self:GetDeepestFocus()
			self:_UpdateFocusBrackets(focus)
		end
		-- self:_UpdateGemSelectionArrows(gem_widget)
		-- self:_RestoreGemFocus()
	end
end

function GemScreen:Layout()

	self.weapon_icon:LayoutBounds("center", "top", self.weapon_panel)
		:Offset(00, 120)
	self.slots_container:LayoutBounds("center", "below", self.weapon_icon)
		:Offset(0, -80)
	self.info_label:LayoutBounds("center", "bottom", self.weapon_panel_bg)
		:Offset(0, 80)

	self.gems_panel:LayoutBounds("after", "center", self.weapon_panel)
		:Offset(-85, -17)
	local w, h = self.gems_title:GetSize()
	self.gems_title_bg:SetSize(w + 150, 120)
		:LayoutBounds("center", "top", self.gems_panel_bg)
		:Offset(0, -25)
	self.gems_title:LayoutBounds("center", "center", self.gems_title_bg)
		:Offset(0, 0)
	self.gems_container:LayoutBounds("right", "center", self.gems_panel_bg)
		:Offset(-35, 10)

	self.root:LayoutBounds("center", "center", self.darken)

	return self
end

GemScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.MENU_SCREEN_ADVANCE,
		fn = function(self)
			self:OnCloseButton()
			return true
		end,
	},
	{
		control = Controls.Digital.CANCEL,
		fn = function(self)

			if self.focused_on_slots then
				-- We're on the slots side, leave the screen
				self:OnCloseButton()
			else
				-- We're on the gems side, go back to slots
				self.focused_on_slots = true
				self.slots_container:SetFocusLock(self.focused_on_slots)
				self.gems_container:SetFocusLock(not self.focused_on_slots)
				if TheFrontEnd:IsRelativeNavigation() then
					self:SetDefaultFocus()
					local focus = self:GetDeepestFocus()
					self:_UpdateFocusBrackets(focus)
				end
			end

			return true
		end,
	},
	{
		control = Controls.Digital.OPEN_INVENTORY,
		fn = function(self)
			self:OnCloseButton()
			return true
		end,
	},
	{
		control = Controls.Digital.ATTACK_HEAVY,
		fn = function(self)

			if TheFrontEnd:IsRelativeNavigation() then
				local slot_widget, slot_number = self.slots_container:GetFocusedSlot()
				if slot_widget then
					slot_widget:AltClick()
				end
				return true
			end
		end,
	},
}

return GemScreen
