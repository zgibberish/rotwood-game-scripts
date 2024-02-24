local Widget = require("widgets/widget")
local Text = require("widgets/text")
local HotkeyWidget = require "widgets.hotkeywidget"
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local AscensionLevelWidget = require("widgets/ftf/dungeonselection/ascensionlevelwidget")

local easing = require"util.easing"

local SuperFrenzySelectionWidget = Class(Widget, function(self)
	Widget._ctor(self, "SuperFrenzySelectionWidget")

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
	self.centre_bg = self:AddChild(Image("images/map_ftf/frenzy_center_bg.tex"))
		:SetName("Centre background")
		:SetPos(0, 30)

	-- Weapon details
	self.weapon_name = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT, "", UICOLORS.SPEECH_BUTTON_TEXT))
		:SetName("Weapon name")
		:SetText("Cannon")
		:SetAutoSize(220)
	self.weapon_shadow = self:AddChild(Image("images/icons_ftf/inventory_weapon_cannon.tex"))
		:SetName("Weapon shadow")
		:SetSize(160, 160)
		:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_DARK)
	self.weapon_icon = self:AddChild(Image("images/icons_ftf/inventory_weapon_cannon.tex"))
		:SetName("Weapon icon")
		:SetSize(170, 170)
		:SetMultColor(UICOLORS.SPEECH_BUTTON_TEXT)

	-- Weapon-switch button
	self.weapon_button = self:AddChild(ImageButton("images/map_ftf/frenzy_weapon_btn.tex"))
		:SetName("Weapon button")
		:SetText(STRINGS.ASCENSIONS.WEAPON_BUTTON)
		:SetTextSize(FONTSIZE.SCREEN_TEXT * 1.1)
		:OverrideLineHeight(FONTSIZE.SCREEN_TEXT * 0.9)
		:SetNavFocusable(false)
		:SetScaleOnFocus(false)
		:SetImageNormalColour(HexToRGB(0xffffffFF))
		:SetImageFocusColour(HexToRGB(0xeeeeeeFF))
		:SetOnClickFn(function()
			if self.onChangeWeaponClick then self.onChangeWeaponClick() end
		end)

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

	self:Layout()
end)

function SuperFrenzySelectionWidget:SetPlayer(player)
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
	return self
end

function SuperFrenzySelectionWidget:OnInputModeChanged(old_device_type, new_device_type)
	if not TheFrontEnd:IsRelativeNavigation() then
		-- This doesn't do anything... why is it here?
	end
	self.weapon_button:RefreshText()
end

function SuperFrenzySelectionWidget:ShouldShow()
	local player = self:GetOwningPlayer()
	local ascension_data = player.components.unlocktracker:GetAllAscensionData()

	for location, weapons in pairs(ascension_data) do
		for weapon, level in pairs(weapons) do
			if level >= 0 then
				return true
			end
		end
	end

	return false
end

function SuperFrenzySelectionWidget:ShowUnlockedMode()

	self.title_bg:Show()
	self.title:Show()
	self.prev_icon:Show()
	self.next_icon:Show()
	self.centre_bg:Show()
	self.weapon_name:Show()
	self.weapon_shadow:Show()
	self.weapon_icon:Show()
	self.weapon_button:Show()
	self.level_description:Show()
	self.bar_base:Show()
	self.locked_info_label:Hide()

	return self
end

-- Just a label saying ascension is locked
function SuperFrenzySelectionWidget:ShowLockedMode()

	self.title_bg:Hide()
	self.title:Hide()
	self.prev_icon:Hide()
	self.next_icon:Hide()
	self.centre_bg:Hide()
	self.weapon_name:Hide()
	self.weapon_shadow:Hide()
	self.weapon_icon:Hide()
	self.weapon_button:Hide()
	self.level_description:Hide()
	self.bar_base:Hide()
	self.locked_info_label:Show()

	return self
end

function SuperFrenzySelectionWidget:OnUpdate()
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

function SuperFrenzySelectionWidget:CollectPlayerData()
	local player_weapon_data = {}
	for _, player in ipairs(AllPlayers) do
		player_weapon_data[player] = player.components.inventory:GetEquippedWeaponType()
	end
	return player_weapon_data
end

function SuperFrenzySelectionWidget:SetLocation(data)
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

	-- this can't be more than the maximum number of ascensions
	max_allowed_level_for_party = 3
	max_seen_level = 3 -- math.min(max_seen_level, #ascensionmanager.ascension_data)

	-- Since ascensions are tracked in two separate systems (unlocktracker and
	-- ascensionmanager, it's possible that they're not in sync (especially
	-- with debug). So ensure we show widgets for the maximum.
	local max_displayed_level = math.max(max_seen_level, max_allowed_level_for_party)

	---------------------------------------------------------------------------------------
	-- Add empty level widget for base-difficulty
	local level_widget = self.bar_level_widgets_container:AddChild(AscensionLevelWidget("images/map_ftf/frenzy_1.tex"))
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

			level_widget = self.bar_level_widgets_container:AddChild(AscensionLevelWidget(level_data.icon))
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

function SuperFrenzySelectionWidget:SetSelectedLevel(level)
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
		local weapon_type = player.components.inventory:GetEquippedWeaponType()
		local weapon_str = STRINGS.NAMES[string.lower("weapon_" .. weapon_type)]

		-- Update title
		if self.selected_level == 0 then
			self.title:SetText(string.format(STRINGS.ASCENSIONS.NO_LEVEL, weapon_str:upper()))
		else
			self.title:SetText(string.format(STRINGS.ASCENSIONS.LEVEL, weapon_str:upper(), self.selected_level))
		end

		-- Update weapon icon and name
		self.weapon_icon:SetTexture(WEAPON_TYPE_TO_TEX[weapon_type])
		self.weapon_shadow:SetTexture(WEAPON_TYPE_TO_TEX[weapon_type])
		self.weapon_name:SetText(weapon_str)

		-- Update level description, along with the player level-limit, if any
		self.level_description:SetText(desc_text .. self.level_limit_string)
	end

	ascensionmanager:StoreSelectedAscension(self.location_data.id, level)

	if self.onSelectLevelFn then
		self.onSelectLevelFn()
	end

	self:Layout()
end

function SuperFrenzySelectionWidget:BuildTooltipString()
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

function SuperFrenzySelectionWidget:SetOnSelectLevelFn(fn)
	self.onSelectLevelFn = fn
	return self
end

function SuperFrenzySelectionWidget:SetOnChangeWeaponClickFn(fn)
	self.onChangeWeaponClick = fn
	return self
end

function SuperFrenzySelectionWidget:DeltaLevel(delta)
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

function SuperFrenzySelectionWidget:Layout()

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

	-- Layout weapon details
	self.weapon_button:LayoutBounds("left", "center", self.bg)
		:Offset(1, -160)
	self.weapon_icon:LayoutBounds("center", "above", self.weapon_button)
		:Offset(0, 20)
	self.weapon_shadow:LayoutBounds("center", "center", self.weapon_icon)
		:Offset(0, -15)
	self.weapon_name:LayoutBounds("center", "center", self.weapon_icon)
		:Offset(0, 115)

	-- Layout text description
	self.level_description:LayoutBounds("after", "center", self.weapon_button)
		:Offset(30, 5)

	-- Layout bar
	self.bar_level_widgets_container:LayoutChildrenInRow(-self.level_horizontal_overlap)
		:LayoutBounds("left", nil, self.level_description)
		:LayoutBounds(nil, "center", self.bg)
		:Offset(10, 20)

	return self
end

return SuperFrenzySelectionWidget
