local Widget = require("widgets/widget")
local Text = require("widgets/text")
local HotkeyWidget = require "widgets.hotkeywidget"
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local FrenzyLevelWidget = require("widgets/ftf/dungeonselection/frenzylevelwidget")

local easing = require"util.easing"

local FrenzySelectionWidget = Class(Widget, function(self)
	Widget._ctor(self, "FrenzySelectionWidget")

	-- Background
	self.bg = self:AddChild(Image("images/map_ftf/frenzy_panel_bg.tex"))
		:SetName("Background")

	-- Title
	self.title_bg = self:AddChild(Image("images/map_ftf/panel_title_bg.tex"))
		:SetName("Title background")
	self.title = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT*1.25, "", UICOLORS.BACKGROUND_MID))
		:SetName("Title")
		:SetText("Frenzy Level")
	self.prev_icon = self:AddChild(HotkeyWidget(Controls.Digital.MENU_TAB_PREV))
		:SetOnlyShowForGamepad()
		:SetMultColor(UICOLORS.SPEECH_BUTTON_TEXT)
		:SetHiddenBoundingBox(true)
		:SetScale(1.1)
	self.next_icon = self:AddChild(HotkeyWidget(Controls.Digital.MENU_TAB_NEXT))
		:SetOnlyShowForGamepad()
		:SetMultColor(UICOLORS.SPEECH_BUTTON_TEXT)
		:SetHiddenBoundingBox(true)
		:SetScale(1.1)

	-- Centre panel
	self.centre_bg = self:AddChild(Image("images/map_ftf/frenzy_center_bg_simple.tex"))
		:SetName("Centre background")
		:SetPos(0, 30)

	-- Level description
	self.level_description = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT, "", UICOLORS.LIGHT_TEXT_DARK))
		:SetName("Level description")
		:SetAutoSize(900)
		:LeftAlign()

	-- Locked info-label
	self.locked_info_label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT, "", UICOLORS.LIGHT_TEXT_DARK))
		:SetName("Locked info-label")
		:SetText(STRINGS.UI.MAPSCREEN.LOCKED_INFO_LABEL)
		:Hide()

	self.selected_level = 0

	-- Progress bar
	self.bar_base = self:AddChild(Widget("Bar Base"))
	self.bar_max_width = 880
	self.level_horizontal_overlap = 10
	self.bar_level_widgets_container = self.bar_base:AddChild(Widget("Bar level widgets container"))

	self.ascension_level_widgets = {}
end)

function FrenzySelectionWidget:SetPlayer(player)
	dbassert(player)
	self:SetOwningPlayer(player)
	self.prev_icon:RefreshHotkeyIcon()
	self.next_icon:RefreshHotkeyIcon()
	if self:ShouldShow() then
		self:ShowUnlockedMode()
	else
		self:ShowLockedMode()
		self:Hide()
	end
	self:Layout()
	return self
end

function FrenzySelectionWidget:OnInputModeChanged(old_device_type, new_device_type)
	-- This doesn't do anything... why is it here?
	if not TheFrontEnd:IsRelativeNavigation() then
	end
end

function FrenzySelectionWidget:ShouldShow()
	local player = self:GetOwningPlayer()
	local ascension_data = player.components.unlocktracker:GetAllAscensionData()

	-- has the player completed the base level with ANY weapon type?

	for location, weapons in pairs(ascension_data) do
		for weapon, level in pairs(weapons) do
			if level >= 0 then
				return true
			end
		end
	end

	return false
end

function FrenzySelectionWidget:ShowUnlockedMode()

	self.title_bg:Show()
	self.title:Show()
	self.prev_icon:Show()
	self.next_icon:Show()
	self.centre_bg:Show()
	self.level_description:Show()
	self.bar_base:Show()
	self.locked_info_label:Hide()

	return self
end

-- Just a label saying ascension is locked
function FrenzySelectionWidget:ShowLockedMode()

	self.title_bg:Hide()
	self.title:Hide()
	self.prev_icon:Hide()
	self.next_icon:Hide()
	self.centre_bg:Hide()
	self.level_description:Hide()
	self.bar_base:Hide()
	self.locked_info_label:Show()

	return self
end

function FrenzySelectionWidget:OnUpdate()
	-- called from MapSidebar:OnUpdate()

	local current_data = self:CollectPlayerData()

	-- player count changed ?
	local do_refresh = table.count(current_data) ~= table.count(self.player_data)

	if not do_refresh then
		for player, weapon in pairs(current_data) do
			local old_weapon = self.player_data[player]
			if not old_weapon or old_weapon ~= weapon then
				-- either no record of the player, or the player changed weapons
				do_refresh = true
				break
			end
		end
	end

	if do_refresh then
		self:SetLocation(self.location_data)
	end
end

function FrenzySelectionWidget:CollectPlayerData()
	local player_weapon_data = {}
	for _, player in ipairs(AllPlayers) do
		player_weapon_data[player] = player.components.inventory:GetEquippedWeaponType()
	end
	return player_weapon_data
end

function FrenzySelectionWidget:SetLocation(data)
	local player = self:GetOwningPlayer()

	-- Remove old widgets
	self.bar_level_widgets_container:RemoveAllChildren()
	self.ascension_level_widgets = {}

	-- Get all data
	local ascensionmanager = TheDungeon.progression.components.ascensionmanager
	self.location_data = data
	local num_ascensions = ascensionmanager.num_ascensions
	local max_widget_width = self.bar_max_width/num_ascensions + self.level_horizontal_overlap

	-- Data about the player viewing the screen
	local unlocktracker = player.components.unlocktracker
	local equipped_weapon_type = player.components.inventory:GetEquippedWeaponType()
	local max_seen_level = unlocktracker:GetHighestSeenAscension()
	local highest_personal_ascension_level = unlocktracker:GetCompletedAscensionLevel(self.location_data.id, equipped_weapon_type)

	-- Data about the party
	local highest_common_ascension_level, limiting_player = ascensionmanager:GetHighestCompletedLevelForParty(self.location_data.id)
	local max_allowed_level_for_party = ascensionmanager:GetMaxAllowedLevelForParty(self.location_data)
	self.player_data = self:CollectPlayerData()

	-- Since ascensions are tracked in two separate systems (unlocktracker and
	-- ascensionmanager, it's possible that they're not in sync (especially
	-- with debug). So ensure we show widgets for the maximum.
	local max_displayed_level = math.max(max_seen_level, max_allowed_level_for_party)

	-- this widget only displays the NORMAL frenzy levels. Don't go past that.
	max_displayed_level = math.min(max_displayed_level, NORMAL_FRENZY_LEVELS)

	---------------------------------------------------------------------------------------
	-- Add empty level widget for base-difficulty
	local level_widget = self.bar_level_widgets_container:AddChild(FrenzyLevelWidget("images/map_ftf/frenzy_1.tex"))
		:SetName("Level " .. 0)
		:SetNavFocusable(false)
		:SetAvailable(true)
		:SetCompleted(highest_personal_ascension_level >= 0)
		:RefreshColors()
		:SetOnClickFn(function() self:SetSelectedLevel(0) end)
		:SetBaseLevel(true)

	if max_displayed_level > 0 then
		level_widget:ShowConnector(max_widget_width)
	end

	self.ascension_level_widgets[0] = level_widget
	---------------------------------------------------------------------------------------

	---------------------------------------------------------------------------------------
	-- Add new level widgets

	for level, level_data in ipairs(ascensionmanager.ascension_data) do
		-- Show only levels the player has seen
		if level <= max_displayed_level then

			level_widget = self.bar_level_widgets_container:AddChild(FrenzyLevelWidget(level_data.icon))
				:SetName("Level " .. level)
				:SetNavFocusable(false)
				:SetAvailable(level <= max_allowed_level_for_party)
				:SetCompleted(level <= highest_personal_ascension_level)
				:RefreshColors()
				:SetOnClickFn(function() self:SetSelectedLevel(level) end)

			-- Show a connector on every widget except last
			if level < max_displayed_level then
				level_widget:ShowConnector(max_widget_width)
			end

			self.ascension_level_widgets[level] = level_widget
		end
	end

	---------------------------------------------------------------------------------------

	-- If there's more than one player, display whether one is limiting the others

	if max_seen_level > max_allowed_level_for_party then
		local limiting_weapon_type = limiting_player.components.inventory:GetEquippedWeaponType()
		local limited_level = highest_common_ascension_level >= 0 and highest_common_ascension_level or STRINGS.ASCENSIONS.NO_LEVEL_INFO
		if limiting_player == self:GetOwningPlayer() then
			self.level_limit_string = string.format(STRINGS.ASCENSIONS.LEVEL_LIMIT_INFO_SELF, STRINGS.ITEM_CATEGORIES[limiting_weapon_type], limited_level)
		else
			self.level_limit_string = string.format(STRINGS.ASCENSIONS.LEVEL_LIMIT_INFO, limiting_player:GetCustomUserName(), STRINGS.ITEM_CATEGORIES[limiting_weapon_type], limited_level)
		end
	else
		self.level_limit_string = ""
	end

	self:SetSelectedLevel(max_allowed_level_for_party)

	self:Layout()
	return self
end

function FrenzySelectionWidget:SetSelectedLevel(level)
	local ascensionmanager = TheDungeon.progression.components.ascensionmanager

	local max_allowed_level = ascensionmanager:GetMaxAllowedLevelForParty(self.location_data)
	level = math.clamp(level, 0, max_allowed_level)

	-- Set correct state on all levels
	for k, level_widget in pairs(self.ascension_level_widgets) do
		level_widget:SetActive(k <= level)
			:RefreshColors()
		if k == level then
			self.selected_level_widget = level_widget
		end
	end

	self.selected_level = level

	local desc_text = STRINGS.ASCENSIONS.NORMAL
	if level > 0 then
		desc_text = ascensionmanager.ascension_data[level].stringkey
	end


	local player = self:GetOwningPlayer()
	if player then
		-- Update title
		if self.selected_level == 0 then
			self.title:SetText(STRINGS.ASCENSIONS.NO_LEVEL_SIMPLE)
		else
			self.title:SetText(string.format(STRINGS.ASCENSIONS.LEVEL_SIMPLE, self.selected_level))
		end
		-- Update level description, along with the player level-limit, if any
		self.level_description:SetText(desc_text .. self.level_limit_string)
	end

	ascensionmanager:StoreSelectedAscension(self.location_data.id, level)

	if self.onSelectLevelFn then
		self.onSelectLevelFn()
	end

	self:Layout()
end

function FrenzySelectionWidget:BuildTooltipString()
	-- TODO: TEMP INFO, THIS SHOULD BE PRESENTED IN A BETTER WAY
	local data = TheDungeon.progression.components.ascensionmanager:GetPartyAscensionData(self.location_data.id)
	local str = "Highest Frenzy Completed:"
	for id = 0, 3 do
		local player_data = data[id]
		if player_data then
			local highest = player_data.level >= 0 and player_data.level or "None"
			str = str..string.format("\n%s %s: %s [%s]", STRINGS.UI.BULLET_POINT, player_data.player:GetCustomUserName(), highest, STRINGS.ITEM_CATEGORIES[player_data.weapon_type])
		end
	end
	return str
end

function FrenzySelectionWidget:SetOnSelectLevelFn(fn)
	self.onSelectLevelFn = fn
	return self
end

function FrenzySelectionWidget:DeltaLevel(delta)
	if not self:IsVisible() then
		-- Not visible, then not interactable.
		return
	end
	-- TODO(dbriscoe): POSTVS We should probably call Click on buttons directly
	-- to get the same sound behaviour as mouse clicks, but that currently
	-- doesn't play sound. Too big to change now.
	TheFrontEnd:GetSound():PlaySound(self.controldown_sound)
	self:SetSelectedLevel(self.selected_level + delta)

	self.selected_level_widget:ScaleTo(1.1, 1, 0.15, easing.outQuad)
end

function FrenzySelectionWidget:Layout()

	-- Layout title and its bg
	local title_w, title_h = self.title:GetSize()
	self.title_bg:SetSize(title_w + 80, title_h + 30)
		:LayoutBounds("center", "top", self.bg)
		:Offset(0, -45)
	self.title:LayoutBounds("center", "center", self.title_bg)
		:Offset(0, 5)
	self.prev_icon:LayoutBounds("before", "bottom", self.title_bg)
		:Offset(-15, 5)
	self.next_icon:LayoutBounds("after", "bottom", self.title_bg)
		:Offset(20, 5)

	-- Layout bar
	self.bar_level_widgets_container:LayoutChildrenInRow(-self.level_horizontal_overlap)
		:LayoutBounds("center", "center", self.bg)
		:Offset(10, 20)

	-- Layout text description
	self.level_description:LayoutBounds("left", "below", self.centre_bg)
		:Offset(100, 0)

	return self
end

return FrenzySelectionWidget
