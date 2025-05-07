local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Panel = require("widgets/panel")
local ImageButton = require("widgets/imagebutton")
local ExpandingTabGroup = require("widgets/expandingtabgroup")
local MonsterArmourWidget = require("widgets/ftf/monsterarmourwidget")
local RadialStatWidget = require("widgets/ftf/radialstatwidget")

local Biomes = require "defs.biomes"
local itemforge = require "defs.itemforge"
local recipes = require "defs.recipes"

local easing = require "util.easing"
local itemutil = require"util.itemutil"
local monsterutil = require "util/monsterutil"


------------------------------------------------------------------------------------
-- A panel with biome tabs, to list selectable widgets
--
-- ┌───────────────────────────────────┐ ◄ bg
-- │   ┌───────────────────────────┐ ┌─┴─┐
-- │   │ tabs_container            │ │ X │ ◄ close_button
-- │   │  tabs_widget              │ └─┬─┘
-- │   └───────────────────────────┘   │ ◄ tabs_background
-- │ ┌───────────────────────────────┐ │
-- │ │ list_hitbox                   │ │
-- │ │ list_container                │ │ ◄ The widgets inside list_container get
-- │ │                               │ │   laid out in a grid pattern and centered
-- │ │                               │ │   within the list hitbox.
-- │ │                               │ │   If they're too big, they get scaled until
-- │ │                               │ │   they fit.
-- │ │                               │ │
-- │ │                               │ │
-- │ │                               │ │
-- │ │                               │ │
-- │ │                               │ │
-- │ └───────────────────────────────┘ │
-- │  ┌─────────────────────────────┐  │
-- │  │ stats_container             │  │
-- │  │                             │  │
-- │  └─────────────────────────────┘  │
-- └───────────────────────────────────┘
--

local TEMP_BIOMES_TO_SHOW = {
	{ region = "forest", location = "treemon_forest" },
	{ region = "forest", location = "owlitzer_forest" },
	{ region = "swamp", location = "kanft_swamp" },
}

local ItemCodex = Class(Widget, function(self, w, h)
	Widget._ctor(self, "ItemCodex")

	self.width = w
	self.height = h

	-- The background
	self.bg = self:AddChild(Panel("images/bg_research_screen_left/research_screen_left.tex"))
		:SetNineSliceCoords(200, 1080, 1414, 1755)
		:SetSize(self.width, self.height)

	-- The hitbox, used only to align the list contents to
	-- It's sized up to match the light area in the bg's texture
	-- This margin allows us to customize how close to the bg's texture the elements can get
	local hitbox_margin = 50
	self.list_hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetSize(self.width - 84*2 - hitbox_margin*2, self.height - 234*2 - hitbox_margin*2)
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0)

	-- The close button. Only shows if a callback function is set on the panel
	self.close_button = self:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		:LayoutBounds("right", "top", self.bg)
		:Offset(-10, -10)
		:Hide()

	-- Tabs container
	self.tabs_container = self:AddChild(Widget())
		:SetName("Tabs container")
	self.tabs_background = self.tabs_container:AddChild(Panel("images/ui_ftf_research/research_tabs_bg.tex"))
		:SetName("Tabs background")
		:SetNineSliceCoords(26, 0, 195, 150)
		:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_MID)
	self.tabs_spacing = 5
	self.tabs_widget = self.tabs_container:AddChild(ExpandingTabGroup())
		:SetName("Tabs widget")
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:SetTabOnClick(function(tab_btn)
			self:OnCategoryTabClicked(tab_btn, tab_btn.region)
		end)
		:SetOnTabSizeChange(function()
			self.tabs_widget:LayoutChildrenInGrid(100, self.tabs_spacing)
			local tabs_w, tabs_h = self.tabs_widget:GetSize()
			self.tabs_background:SetSize(tabs_w + 100, tabs_h + 60)
			self.tabs_widget:LayoutBounds("center", "center", self.tabs_background)
		end)

	-- List container
	self.list_container = self:AddChild(Widget())
		:SetName("List container")

	-- Stats container
	self.stats_container = self:AddChild(Widget())
		:SetName("Stats container")
		:Hide() -- jambell: hiding, but leaving there in case we want to re-enable these someday.
	self:_SetupArmourStats()

end)

function ItemCodex:GetDefaultFocus()
	if self.list_container:HasChildren() then
		return self.list_container.children[1]
	end
end

function ItemCodex:SetDefaultFocus()
	local focus = self:GetDefaultFocus()
	if focus then
		focus:SetFocus()
		return true
	end
end

function ItemCodex:Refresh(player)
	self.player = player

	-- Remove existing tabs
	self.tabs_widget:RemoveAllTabs()
	self.tabs_list = {}

	-- Get all locations and add tabs for each
	for _, location_data in ipairs(TEMP_BIOMES_TO_SHOW) do
		local region_id = location_data.region
		local location_id = location_data.location


		local def = Biomes.regions[region_id].locations[location_id]
		if player.components.unlocktracker:IsLocationUnlocked(location_id) then -- Location unlock check
			local tab_btn = self.tabs_widget:AddTab(def.icon, def.name)
				:ShowAvailableActionIcon(false) -- TODO ricardo: show the icon if there are actions available
			tab_btn.region = def
			self.tabs_list[location_id] = tab_btn
		else
			local tab_btn = self.tabs_widget:AddTab("images/ui_ftf_research/research_widget_lock.tex", "")
				:SetLocked(true)
				:Hide()
			tab_btn.region = def
			self.tabs_list[location_id] = tab_btn
		end
	end

	-- Layout tabs
	self:Layout()
	self.tabs_widget:LayoutChildrenInGrid(100, self.tabs_spacing)
		:AddCycleIcons()
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:LayoutBounds("center", "center", self.tabs_background)
		:Offset(-1, 5)

	-- TODO: Open Last Selected
	self.tabs_widget:OpenTabAtIndex(1)

	-- Show whether a tab has available actions or not
	self:_UpdateTabAvailableActions()
end

function ItemCodex:Layout()
	self.tabs_container:LayoutBounds("center", "top", self.bg)
		:Offset(0, -70)
	self.list_hitbox:LayoutBounds("center", "center", self.bg)
		:Offset(-3, 5)

	-- Layout the list widgets in a grid
	self:_ListLayoutAndFit(160, 10)

	self.stats_container:LayoutBounds("center", "bottom", self.bg)
		:Offset(0, 70)

	return self
end

-- Goes through the biomes, checks if there are unlockable or craftable things
-- and displays an icon on the corresponding biome
function ItemCodex:_UpdateTabAvailableActions()
	for _, location_data in ipairs(TEMP_BIOMES_TO_SHOW) do
		local region_id = location_data.region
		local location_id = location_data.location

		local show_available_action = false
		local location = Biomes.regions[region_id].locations[location_id]
		local tab_btn = self.tabs_list[location_id]

		-- Check if this biome is unlocked
		if self.player.components.unlocktracker:IsLocationUnlocked(location_id) then

			-- Check if there are new creatures
			local mobs = self:_GetLocationMobs(location)
			for i, monster_id in ipairs(mobs) do

				local monster_unlocked = self.player.components.unlocktracker:IsEnemyUnlocked(monster_id)
				local armour = itemutil.GetArmourForMonster(monster_id)

				if next(armour) then
					local unlocked_recipes = self.player.components.unlocktracker:IsMonsterArmourSetUnlocked(monster_id)
					local monster_armour_recipe = recipes.FindRecipeForItem('armour_unlock_'..monster_id)
					local can_player_unlock = monster_armour_recipe:CanPlayerCraft(self.player)

					-- If the player has seen this monster, but not unlocked its armour (but can), show the icon
					if monster_unlocked and (not unlocked_recipes and can_player_unlock) then
						show_available_action = true
					end

					-- If we haven't already decided to show the icon, check the armour recipes too
					if monster_unlocked and show_available_action == false then

						for slot, itemdef in pairs(armour) do
							local recipe = recipes.FindRecipeForItemDef(itemdef)

							local item = self.player.components.inventoryhoard:GetInventoryItem(itemdef)
							local owned = item ~= nil

							if owned then
								recipe = recipes.FindUpgradeRecipeForItem(item)
							else
								item = itemforge.CreateEquipment( itemdef.slot, itemdef )
							end

							local can_craft = recipe and recipe:CanPlayerCraft(self.player)
							if can_craft then
								show_available_action = true
							end
						end
					end
				end

			end
		end

		-- Show the icon!
		tab_btn:ShowAvailableActionIcon(show_available_action)
	end
end

-- Lays out the list widgets in a funky hex grid
-- and scales them down to fit, if needed
function ItemCodex:_ListLayoutAndFit(spacing_h, spacing_v)

	-- Reset scale before starting
	self.list_container:SetScale(1)

	-- Get widgets to layout
	local to_layout = {}
    for i, v in ipairs( self.list_container.children ) do
        if v:IsShown() then
            table.insert(to_layout, v)
        end
    end
    if #to_layout == 0 then return self end

    -- Calculate sizes and spacing
	spacing_h = spacing_h or 10
	spacing_v = spacing_v or spacing_h
	-- Get the width of the first widget
	local widget_w = to_layout[1]:GetSize()

    -- Check how many columns we need
    local oddrow_columns = 0
    local evenrow_columns = 0
    local evenrow_columns_offset = -(widget_w/2 + spacing_h/2)
    if #to_layout == 2
	or #to_layout == 6
	or #to_layout == 8
    then
		oddrow_columns = 2
		evenrow_columns = 2
    elseif #to_layout == 3
    or #to_layout == 4
    then
		oddrow_columns = 1
		evenrow_columns = 2
    elseif #to_layout == 5
    then
		oddrow_columns = 2
		evenrow_columns = 1
		evenrow_columns_offset = -evenrow_columns_offset
    elseif #to_layout == 7
	or #to_layout == 9
	or #to_layout == 10
	or #to_layout == 11
	or #to_layout == 12
	then
		oddrow_columns = 2
		evenrow_columns = 3
	else
		oddrow_columns = 3
		evenrow_columns = 4
    end

    local current_column = 1
    local current_row = 1
    local newrow = false
	for index, v in ipairs( to_layout ) do

		-- Check if this is an even row
		local even_row = current_row%2 == 0

		-- Position the widget
		if newrow then
			v:LayoutBounds("left", nil, to_layout[1])
				:LayoutBounds(nil, "below", to_layout[index - 1])
				:Offset(even_row and evenrow_columns_offset or 0, -spacing_v)
		else
			v:LayoutBounds("after", "center", to_layout[index - 1])
				:Offset(spacing_h, 0)
		end

		-- If this was a new row, the next one isn't
		if newrow then
			newrow = false
		end

		------------------------------------------------------------------------------------
		------------------------------------------------------------------------------------
		-- Renav and set up the focus directions for all the items

		if current_column > 1 then
			-- Link left to the previous widget
			v:SetFocusDir("left", to_layout[index - 1], true)
		end

		if current_row > 1 then
			-- Link up to the above widget
			-- This is trickier because of the difference in column counts between odd and even rows
			-- If we're on an even row, subtract the number of columns in the row before (odd)
			-- If we're on an odd row, subtract the number of columns in the row before (even)
			if even_row then
				v:SetFocusDir("up", to_layout[index - oddrow_columns], true)
			else
				v:SetFocusDir("up", to_layout[index - evenrow_columns], true)
			end
		end
		------------------------------------------------------------------------------------
		------------------------------------------------------------------------------------

		-- Increase the column for the next widget
		current_column = current_column + 1

		-- Check if the next widget should go to a new row
		if even_row and current_column > evenrow_columns then
			current_column = 1
			newrow = true
			current_row = current_row + 1
		end
		if not even_row and current_column > oddrow_columns then
			current_column = 1
			newrow = true
			current_row = current_row + 1
		end

    end

	-- Move every widget a random amount
	-- local max_h_offset = 30
	-- local max_v_offset = 30
	-- for index, v in ipairs( to_layout ) do
	-- 	v:Offset(math.random(-max_h_offset, max_h_offset), math.random(-max_v_offset, max_v_offset))
	-- end

	-- Check if the list is too large for the available space, and scale it down accordingly
	local list_w, list_h = self.list_container:GetSize()
	local max_w, max_h = self.list_hitbox:GetSize()
	local scale = self.list_container:GetScale()
	if list_w > max_w then
		-- Too wide
		local ratio = max_w / list_w
		self.list_container:SetScale(ratio)
	end
	scale = self.list_container:GetScale()
	list_w, list_h = self.list_container:GetScaledSize()
	if list_h > max_h then
		-- Too tall
		local ratio = max_h / list_h
		self.list_container:SetScale(scale * ratio)
	end

	self.list_container
		:LayoutBounds("center", "center", self.list_hitbox)
end

function ItemCodex:_GetLocationMobs(location)
	local mobs = itemutil.GetLocationArmourSets(location)

	-- Hacky way to get the "basic" armour set to be in the forest biome menu
	if self.current_location.id == "treemon_forest" then
		table.insert(mobs, 1, "basic")
	end

	return mobs
end

function ItemCodex:SetCurrentLocation(location)
	self.last_target_button = nil

	self.current_location = location

	local mobs = itemutil.GetLocationArmourSets(location)

	-- Remove all list widgets
	self.list_container:RemoveAllChildren()

	-- Add new ones
	-- TODO: Sort monsters by type
	for i, id in ipairs(mobs) do
		self:AddCraftableWidget(id, self.player.components.unlocktracker:IsEnemyUnlocked(id))
	end

	self:Layout()

	-- Select the first
	if self.list_container:HasChildren() then
		local first_button = self.list_container:GetChildren()[1]

		-- Trigger the first button
		first_button:Click()
		first_button:SetFocus()

		-- Resize the brackets to fit, and position them
		-- self:_ResizeSelectionBrackets()

		-- self:_UpdateSelectionBrackets(first_button)
	end

	self:_RefreshArmourStats()
end

function ItemCodex:_SetupArmourStats()

	-- Remove existing stats, if any
	self.stats_container:RemoveAllChildren()

	-- Display armour-relevant stats
	self.armour_stats = {
		creatures = {
			title = STRINGS.UI.FORGEARMORSCREEN.STATS_CREATURES_TITLE,
			value = STRINGS.UI.FORGEARMORSCREEN.STATS_CREATURES_VALUE,
			icon = "images/ui_ftf_research/research_stats_creatures.tex"
		},
		head = {
			title = STRINGS.UI.FORGEARMORSCREEN.STATS_HEAD_TITLE,
			value = STRINGS.UI.FORGEARMORSCREEN.STATS_HEAD_VALUE,
			icon = "images/ui_ftf_research/research_stats_helmet.tex"
		},
		body = {
			title = STRINGS.UI.FORGEARMORSCREEN.STATS_BODY_TITLE,
			value = STRINGS.UI.FORGEARMORSCREEN.STATS_BODY_VALUE,
			icon = "images/ui_ftf_research/research_stats_armor.tex"
		}
	}

	local stat_widget_width = self.width*0.75 / 3
	self.armour_stats["creatures"].stat_widget = self.stats_container:AddChild(RadialStatWidget(stat_widget_width))
		:SetName("Creatures stats")
		:Refresh(self.armour_stats["creatures"].title, self.armour_stats["creatures"].value, 0)
		:SetIcon(self.armour_stats["creatures"].icon, nil, UICOLORS.LIGHT_TEXT_DARKER)
	self.armour_stats["head"].stat_widget = self.stats_container:AddChild(RadialStatWidget(stat_widget_width))
		:SetName("Head stats")
		:Refresh(self.armour_stats["head"].title, self.armour_stats["head"].value, 0)
		:SetIcon(self.armour_stats["head"].icon, nil, UICOLORS.LIGHT_TEXT_DARKER)
	self.armour_stats["body"].stat_widget = self.stats_container:AddChild(RadialStatWidget(stat_widget_width))
		:SetName("Body stats")
		:Refresh(self.armour_stats["body"].title, self.armour_stats["body"].value, 0)
		:SetIcon(self.armour_stats["body"].icon, nil, UICOLORS.LIGHT_TEXT_DARKER)

	self.stats_container:LayoutChildrenInRow(50)
	self:Layout()
end

function ItemCodex:_RefreshArmourStats()

	-- Tally up everything!
	self.armour_stats["creatures"].current = 0
	self.armour_stats["creatures"].total = 0
	self.armour_stats["head"].current = 0
	self.armour_stats["head"].total = 0
	self.armour_stats["body"].current = 0
	self.armour_stats["body"].total = 0

	local mobs = itemutil.GetLocationArmourSets(self.current_location)

	-- Save total amount of creatures in this biome
	self.armour_stats["creatures"].total = #mobs

	for k, monster_id in ipairs(mobs) do

		-- Has the player seen this creature?
		if self.player.components.unlocktracker:IsMonsterArmourSetUnlocked(monster_id) then
			self.armour_stats["creatures"].current = self.armour_stats["creatures"].current + 1
		end

		-- Get this creature's armour set
		local armour = itemutil.GetArmourForMonster(monster_id)

		-- Count head armour
		if armour["HEAD"] then

			-- Get item
			local item = self.player.components.inventoryhoard:GetInventoryItem(armour["HEAD"])
			local owned = item ~= nil

			if owned then
				-- What level is the player's item at
				self.armour_stats["head"].current = self.armour_stats["head"].current + item:GetItemLevel()
			else
				-- The player doesn't own this item. Let's create a proxy
				item = itemforge.CreateEquipment( armour["HEAD"].slot, armour["HEAD"] )
			end

			-- How many levels are there?
			self.armour_stats["head"].total = self.armour_stats["head"].total + item:GetMaxItemLevel()
		end

		-- Count body armour
		if armour["BODY"] then

			-- Get item
			local item = self.player.components.inventoryhoard:GetInventoryItem(armour["BODY"])
			local owned = item ~= nil

			if owned then
				-- What level is the player's item at
				self.armour_stats["body"].current = self.armour_stats["body"].current + item:GetItemLevel()
			else
				-- The player doesn't own this item. Let's create a proxy
				item = itemforge.CreateEquipment( armour["BODY"].slot, armour["BODY"] )
			end

			-- How many levels are there?
			self.armour_stats["body"].total = self.armour_stats["body"].total + item:GetMaxItemLevel()
		end
	end

	-- Refresh stats
	self.armour_stats["creatures"].stat_widget:SetValue(string.format(self.armour_stats["creatures"].value, self.armour_stats["creatures"].current, self.armour_stats["creatures"].total))
		:AnimateProgress(self.armour_stats["creatures"].current/self.armour_stats["creatures"].total)
	self.armour_stats["head"].stat_widget:SetValue(string.format(self.armour_stats["head"].value, self.armour_stats["head"].current, self.armour_stats["head"].total))
		:AnimateProgress(self.armour_stats["head"].current/self.armour_stats["head"].total)
	self.armour_stats["body"].stat_widget:SetValue(string.format(self.armour_stats["body"].value, self.armour_stats["body"].current, self.armour_stats["body"].total))
		:AnimateProgress(self.armour_stats["body"].current/self.armour_stats["body"].total)

end

function ItemCodex:AddCraftableWidget(monster_id, unlocked)
	local armour = itemutil.GetArmourForMonster(monster_id)

	local w = self.list_container:AddChild(MonsterArmourWidget(self.player, monster_id, armour))
	w:SetOnClickFn(function() self:OnItemClicked(w, self.player, monster_id, armour) end)
	w:SetOnFocused(function() if TheFrontEnd:IsRelativeNavigation() then self:OnItemFocused(w, self.player, monster_id, armour) end end)
	w:SetOnChange(function()
		self:_UpdateTabAvailableActions()
		self:_RefreshArmourStats()
	end)
	return w
end

function ItemCodex:OnItemClicked(button, player, id, armour)
	if self.onClickFn then
		self.onClickFn(button, player, id, armour)
	end

	-- Select correct button
	for k, btn in ipairs(self.list_container.children) do
		btn:SetSelected(button == btn)
	end

	return self
end

function ItemCodex:OnItemFocused(button, player, id, armour)
	if self.onFocusFn then
		self.onFocusFn(button, player, id, armour)
	end

	return self
end

function ItemCodex:HasCreatures()
	return self.list_container:HasChildren()
end

function ItemCodex:FocusOnIndex(idx)
	if idx and idx <= #self.list_container.children then
		self.list_container.children[idx]:SetFocus()
	elseif self.list_container:HasChildren() then
		self.list_container.children[1]:SetFocus()
	end
	return self
end

function ItemCodex:GetItemWidgets()
	return self.list_container.children
end

function ItemCodex:SetOnItemClick(fn)
	self.onClickFn = fn
	return self
end

function ItemCodex:SetOnItemFocused(fn)
	self.onFocusFn = fn
	return self
end

function ItemCodex:NextTab(delta)
	self.tabs_widget:NextTab(delta)
	return self
end

function ItemCodex:SetOnBiomeChangedFn(fn)
	self.on_biome_changed_fn = fn
	return self
end

function ItemCodex:OnCategoryTabClicked(selected_tab_btn, location)
	if self.current_location ~= location then
		self:SetCurrentLocation(location)

		-- Notify parent
		if self.on_biome_changed_fn then self.on_biome_changed_fn() end
	end
end

function ItemCodex:SetOnCloseFn(fn)
	self.close_button:SetOnClick(fn)
		:SetShown(fn)
	return self
end

return ItemCodex
