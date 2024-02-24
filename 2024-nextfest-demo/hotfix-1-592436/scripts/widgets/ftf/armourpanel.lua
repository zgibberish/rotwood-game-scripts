local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Panel = require("widgets/panel")
local ImageButton = require("widgets/imagebutton")
local TabGroup = require("widgets/tabgroup")
local Text = require "widgets.text"
local MonsterArmourWidget = require("widgets/ftf/monsterarmourwidget")
local InventorySlot = require("widgets/ftf/inventoryslot")
local ScrollPanel = require "widgets.scrollpanel"

local lume = require("util/lume")
local Consumable = require "defs.consumable"
local Biomes = require "defs.biomes"
local itemforge = require "defs.itemforge"

local Equipment = require("defs.equipment")

local VALID_SLOTS =
{
	[Equipment.Slots.HEAD] = true,
	[Equipment.Slots.BODY] = true,
}

local ArmourPanel = Class(Widget, function(self, w, h)
	Widget._ctor(self, "ArmourPanel")

	self.width = w
	self.height = h

		-- Background
	self.darken = self:AddChild(Image("images/square.tex"))
		:SetSize(RES_X, RES_Y)
		:SetMultColor(0x020201ff)
		:SetMultColorAlpha(0.5)

	self.bg = self:AddChild(Panel("images/bg_background_panel/background_panel.tex"))
		:SetNineSliceBorderScale(0.4)
		:SetNineSliceCoords(170, 230, 1225, 2100)
		:SetSize(self.width, self.height)
		:Offset(0, -42)

	local inner_w, inner_h = self.bg:GetInnerSize()

	self.header = self.bg:AddChild(Widget("Header"))
	self.panel_title = self.header:AddChild(Text(FONTFACE.DEFAULT, 70, "[TEMP] Armour Crafting", UICOLORS.LIGHT_TEXT_DARKER))
		:SetAutoSize(inner_w)
		:LayoutBounds("center", "top", self.bg)
		:Offset(0, -10)

	self.closeButton = self.header:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		:LayoutBounds("right", "top", self.bg)
		:Offset(10, 10)

	self.subheader = self:AddChild(Widget("Subheader"))
	self.tabsBg = self.subheader:AddChild(Image("images/ui_ftf_inventory/TabsBar.tex"))
		:SetSize(inner_w, inner_h / 10)

	self.content = self:AddChild(Widget("Content"))
	self.biome_title = self.content:AddChild(Text(FONTFACE.DEFAULT, 50, "", UICOLORS.LIGHT_TEXT_DARKER))
		:SetAutoSize(inner_w)

	self.recipe_list = self:AddChild(ScrollPanel())
		:SetSize(inner_w, inner_h * 0.75)
		:SetVirtualMargin(15)

	self.recipe_root = self.recipe_list:AddScrollChild(Widget("Recipes"))

	self.TEMP_STRING = self.bg:AddChild(Text(FONTFACE.DEFAULT, 50, "Super temp screen added for basic functionality!", UICOLORS.LIGHT_TEXT_DARKER))
		:LayoutBounds("center", "bottom", self.bg)
		:Offset(0, 15)
end)

function ArmourPanel:Refresh(player)
	self.player = player

	local icon_spacing = 15

	if self.biome_selection then
		self.biome_selection:Remove()
	end

	self.biome_selection = self.subheader:AddChild(TabGroup())

	-- "region" is the same as "biome"
	local TEMP_BIOMES_TO_SHOW = { "forest", "swamp" }
	-- TODO: Sort & only show relevant biomes
	for _, id in ipairs(TEMP_BIOMES_TO_SHOW) do
		if player.components.unlocktracker:IsRegionUnlocked(id) then -- Region unlocked check
			local def = Biomes.regions[id]
			-- TODO: Hide locked biomes
			local tab_btn = self.biome_selection:AddTab(def.icon, def.name)
			tab_btn.region = def
		end
	end

	self.biome_selection:SetTabSize(self.tabSize, self.tabSize)
		:SetTabOnClick(function(tab_btn) self:OnCategoryTabClicked(tab_btn, tab_btn.region) end)
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:LayoutChildrenInGrid(100, icon_spacing)
		:AddCycleIcons()
		:LayoutBounds("center", "center", self.tabsBg)
		:Offset(-1, 5)

	-- TODO: Open Last Selected
	self.biome_selection:OpenTabAtIndex(1)

	self:Layout()
end

function ArmourPanel:Layout()
	self.subheader:LayoutBounds("center", nil, self.bg)
	self.subheader:LayoutBounds(nil, "below", self.header)
	self.content:LayoutBounds("center", "below", self.subheader)

	self.biome_title:LayoutBounds("center", "top", self.content)


	self.recipe_root:LayoutChildrenInAutoSizeGrid(2, 20, 40)

	local width = self.recipe_root:GetSize()
	self.recipe_root:LayoutBounds("left", "top")
		:Offset(-width/2)
	self.recipe_list:RefreshView()
		:LayoutBounds("center", "below", self.biome_title)

	-- self.recipe_root:LayoutBounds("center", "below", self.biome_title)
end

function ArmourPanel:SetCurrentLocation(location)
	local monsterutil = require "util/monsterutil"

	self.current_biome = location
	self.biome_title:SetText(location.name)

	local mobs = monsterutil.GetMonstersInLocation(location)

	-- Hacky way to get the "basic" armour set to be in the forest biome menu
	if self.current_biome.id == "forest" then
		table.insert(mobs, 1, "basic")
	end

	self.recipe_root:RemoveAllChildren()

	-- TODO: Sort monsters by type
	for _, id in ipairs(mobs) do
		self:AddCraftableWidget(id, self.player.components.unlocktracker:IsEnemyUnlocked(id))
	end

	self:Layout()
end

function ArmourPanel:FindArmourForMonster(id)
	local armour_pieces = {}

	for slot, items in pairs(Equipment.Items) do
		if VALID_SLOTS[slot] then
			for name, def in pairs(items) do
				if name == id and not def.tags.hide then
					armour_pieces[slot] = def
				end
			end
		end
	end

	return armour_pieces
end

function ArmourPanel:AddCraftableWidget(id, unlocked)
	local armour = self:FindArmourForMonster(id)

	if next(armour) then
		self.recipe_root:AddChild(MonsterArmourWidget(self.player, id, armour))
			-- :SetHidden(not unlocked)
	end
end

function ArmourPanel:AddMonsterResearchWidget(id, def, unlocked)
	local mpm = TheWorld:GetMetaProgress()

	if not mpm:GetProgress(def) then
		mpm:StartTrackingProgress(mpm:CreateProgress(def))
	end

	local research = mpm:GetProgress(def)

	local root = self.recipe_root:AddChild(Widget("root"))

	local progress_widget = root:AddChild(MetaProgressWidget(self.player))
		:SetBarSize(300, 40)
	progress_widget.rewards_per_row = 5

	local image = root:AddChild(Image(string.format("images/monster_pictures/%s.tex", id)))
		:SetSize(120, 120)

	local monster_items = Consumable.GetItemList(Consumable.Slots.MATERIALS, { "drops_"..def.name })

	monster_items = lume.sort(monster_items, function(a, b)
		local a_rarity = ITEM_RARITY.id[a.rarity]
		local b_rarity = ITEM_RARITY.id[b.rarity]
		if a_rarity == b_rarity then
			return a.pretty.name < b.pretty.name
		end
		return a_rarity < b_rarity
	end)

	local items = root:AddChild(Widget("item root"))

	for _, itemdef in ipairs(monster_items) do
		if self.player.components.unlocktracker:IsConsumableUnlocked(itemdef.name) then
			local invslot = items:AddChild(InventorySlot(55, "images/ui_ftf_shop/inventory_slot_bg.tex"))
			local result_item = itemforge.CreateStack(itemdef.slot, itemdef)

			local count = self.player.components.inventoryhoard:GetStackableCount(itemdef)
			result_item.count = count

			if count == 0 then
				invslot:SetSaturation(0.5)
			end

			invslot:SetItem(result_item, self.player, true)

			invslot:SetOnClick(function()
				local current_count = self.player.components.inventoryhoard:GetStackableCount(itemdef)
				if current_count > 0 then
					self.player.components.inventoryhoard:RemoveStackable(itemdef, 1)
					result_item.count = self.player.components.inventoryhoard:GetStackableCount(itemdef)
					invslot:SetItem(result_item, self.player, true)
					if result_item.count == 0 then
						invslot:SetSaturation(0.5)
					end

					local log = mpm:GrantExperience(def, TUNING.MONSTER_RESEARCH.RARITY_TO_EXP[itemdef.rarity])
					progress_widget:SetMetaProgressData(research, log)
					progress_widget:ShowMetaProgression()
				end
			end)
		end
	end
	image:LayoutBounds("before", "center", progress_widget)
		:Offset(0, -30)
	items:LayoutChildrenInRow(5)
	items:LayoutBounds("center", "above", image)

	local name_str = research:GetLocalizedName()
	if not unlocked then
		name_str = "????? Research"
		progress_widget:NotDiscovered()
		image:SetMultColor(0,0,0)
	end

	local name = progress_widget:AddChild(Text(FONTFACE.DEFAULT, 30, name_str, UICOLORS.LIGHT_TEXT_DARKER))
	progress_widget:SetMetaProgressData(research)
	name:LayoutBounds("left", "above", progress_widget)
end

function ArmourPanel:NextTab(delta)
	self.biome_selection:NextTab(delta)
	return self
end

function ArmourPanel:OnCategoryTabClicked(selected_tab_btn, region)
	self:SetCurrentLocation(region)
end

function ArmourPanel:SetOnCloseFn(fn)
	self.closeButton:SetOnClick(fn)
	return self
end

return ArmourPanel
