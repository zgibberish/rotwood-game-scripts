local Screen = require "widgets.screen"
local Widget = require "widgets.widget"
local Panel = require "widgets.panel"
local Image = require "widgets.image"
local ImageButton = require "widgets.imagebutton"
local TextButton = require "widgets.textbutton"
local PlayersScreenRow = require "widgets.playersscreenrow"
local PlayersScreenBannedRow = require "widgets.playersscreenbannedrow"
local Text = require "widgets.text"
local ScrollPanel = require "widgets/scrollpanel"
local ExpandingTabGroup = require "widgets/expandingtabgroup"
local ConfirmDialog = require "screens.dialogs.confirmdialog"
local fmodtable = require "defs.sound.fmodtable"

local easing = require "util.easing"

----------------------------------------------------------------------
-- A popup with a list of the players currently playing
-- with the local player

local PlayersScreen =  Class(Screen, function(self, data)
	
	self:SetAudioCategory(Screen.AudioCategory.s.Fullscreen)
	self:SetAudioExitOverride(nil)

	Screen._ctor(self, "PlayersScreen")

	self.refresh_time_remaining = 0
	self.refresh_period = 0.1

	self.error_time_remaining = 0
	self.error_duration = 4

	-- Font sizes
	self.label_font_size = FONTSIZE.SCREEN_TITLE*0.6

	-- Darkens the screen below the dialog
	self.scrim = self:AddChild(Image("images/global/square.tex"))
		:SetSize(RES_X, RES_Y)
		:SetMultColor(UICOLORS.BACKGROUND_DARKEST)
		:SetMultColorAlpha(0)

	self.dialog_container = self:AddChild(Widget())
		:SetName("Dialog container")

	self.bg = self.dialog_container:AddChild(Image("images/ui_ftf_online/screen_players.tex"))
		:SetName("Background")
	self.panel_w, self.panel_h = self.bg:GetSize()

	----------------------------------------------------------------------------------
	-- PLAYERS TAB CONTENT
	-- To be shown on the players tab, but not on the banned tab

	self.players_content = self.dialog_container:AddChild(Widget())
		:SetName("Players content")
	self.players_content_bg = self.players_content:AddChild(Image("images/ui_ftf_online/screen_players_footer_bg.tex"))
		:SetName("Players bottom overlay")
	-- Corner buttons
	self.copycode_btn = self.players_content:AddChild(TextButton())
		:SetName("Copy-code button")
		:SetTextSize(self.label_font_size)
		:OverrideLineHeight(self.label_font_size * 0.8)
		:SetText(STRINGS.UI.PLAYERSSCREEN.COPYCODE_BUTTON)
		:SetTextColour(UICOLORS.BACKGROUND_DARK)
		:SetTextFocusColour(UICOLORS.FOCUS_DARK)
		:SetOnClickFn(function() self:OnCopyCodeClicked() end)
	self.addlocalplayer_btn = self.players_content:AddChild(TextButton())
		:SetName("Add local-player button")
		:SetTextSize(self.label_font_size)
		:OverrideLineHeight(self.label_font_size * 0.8)
		:SetText(STRINGS.UI.PLAYERSSCREEN.ADDLOCALPLAYER_BUTTON)
		:SetTextColour(UICOLORS.BACKGROUND_DARK)
		:SetTextFocusColour(UICOLORS.FOCUS_DARK)
		:SetOnClickFn(function() self:OnAddLocalPlayerClicked() end)
		:SetFocusDir("left", self.copycode_btn, true)

	-- Players
	self.players_container = self.players_content:AddChild(Widget())
		:SetName("Players container")
	for k = 1, 4 do
		self.players_container:AddChild(PlayersScreenRow())
	end

	-- Code labels
	self.code_text = self.players_content:AddChild(TextButton())
		:SetName("Code text")
		:SetTextSize(FONTSIZE.SCREEN_TEXT*2.0)
		:SetTextColour(UICOLORS.BACKGROUND_DARK)
		:SetTextFocusColour(UICOLORS.FOCUS_DARK)
		:SetOnClickFn(function() self:OnCopyCodeClicked() end)
		:SetNavFocusable(false)
	self.code_label = self.players_content:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetName("Code label")
		:SetText(STRINGS.UI.PLAYERSSCREEN.SHARECODE_LABEL)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)

	----------------------------------------------------------------------------------
	-- BANNED TAB CONTENT

	self.banned_content = self.dialog_container:AddChild(Widget())
		:SetName("Banned content")
	self.banned_scroll = self.banned_content:AddChild(ScrollPanel())
		:SetName("Banned scroll")
		:SetVirtualMargin(120)
		-- These values were set with the banned_content_top_bg and banned_content_bottom_bg translucent,
		-- to make sure the top and bottom edges of the scroll panel get overlapped by those textures
		:SetSize(self.panel_w - 260, self.panel_h - 240)
		:SetPosition(0, -35)
		:SetBarInset(100)
		:SetScrollBarVerticalOffset(-10)
	self.banned_scroll_contents = self.banned_scroll:AddScrollChild(Widget())
	self.banned_scroll:RefreshView()
	self.banned_content_top_bg = self.banned_content:AddChild(Image("images/ui_ftf_online/screen_players_ban_list_top_overlay.tex"))
		:SetName("Banned top overlay")
	self.banned_content_bottom_bg = self.banned_content:AddChild(Image("images/ui_ftf_online/screen_players_ban_list_bottom_overlay.tex"))
		:SetName("Banned bottom overlay")

	-- Info label for when the list is empty
	self.banned_empty_label = self.banned_content:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT*1.3))
		:SetText(STRINGS.UI.PLAYERSSCREEN.BANNED_LIST_EMPTY)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetAutoSize(500)

	self.close_button = self.dialog_container:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:SetOnClick(function() self:OnClickClose() end)
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		:LayoutBounds("right", "top", self.bg)
		:Offset(-40, 0)

	-- Tabs container
	self.tabs_container = self.dialog_container:AddChild(Widget())
		:SetName("Tabs container")
	self.tabs_background = self.tabs_container:AddChild(Panel("images/ui_ftf_online/tabs_bg.tex"))
		:SetName("Tabs background")
		:SetNineSliceCoords(26, 0, 195, 150)
		:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_MID)
	self.tabs_spacing = 5
	self.tabs_widget = self.tabs_container:AddChild(ExpandingTabGroup())
		:SetName("Tabs widget")
		:SetTabOnClick(function(tab_btn) self:OnTabClicked(tab_btn) end)
		:SetOnTabSizeChange(function()
			self.tabs_widget:LayoutChildrenInGrid(100, self.tabs_spacing)
			local tabs_w, tabs_h = self.tabs_widget:GetSize()
			self.tabs_background:SetSize(tabs_w + 100, tabs_h + 60)
			self.tabs_widget:LayoutBounds("center", "center", self.tabs_background)
		end)
	self.tab_players = self.tabs_widget:AddTab("images/ui_ftf_online/ic_players.tex", STRINGS.UI.PLAYERSSCREEN.TAB_PLAYERS)
	if TheNet:IsHost() then
		self.tab_banned = self.tabs_widget:AddTab("images/ui_ftf_online/ic_banned.tex", STRINGS.UI.PLAYERSSCREEN.TAB_BANNED)
		self.tabs_widget:AddCycleIcons()
	end
	self.tabs_widget:SetNavFocusable(false) -- rely on CONTROL_MAP

	-- Add-player error widget
	self.addplayer_error_widget = self.dialog_container:AddChild(Widget())
		:SetName("Add-player error widget")
		:SetHiddenBoundingBox(true)
		:SetMultColorAlpha(0)
		:Hide()
	self.addplayer_error_bg = self.addplayer_error_widget:AddChild(Image("images/ui_ftf_online/sharecode_popup_arrow.tex"))
		:SetName("Add-player error bg")
	self.addplayer_error_text = self.addplayer_error_widget:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetName("Add-player error text")
		:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(450)

	self:Layout()

	self.default_focus = self.close_button
end)

PlayersScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.CANCEL,
		fn = function(self)
			self:OnClickClose()
			return true
		end,
	},
	{
		control = Controls.Digital.SHOW_PLAYERS_LIST,
		fn = function(self)
			self:OnClickClose()
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_TAB_PREV,
		fn = function(self)
			self:NextTab(-1)
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_TAB_NEXT,
		fn = function(self)
			self:NextTab(1)
			return true
		end,
	},

}

function PlayersScreen:OnOpen()
	PlayersScreen._base.OnOpen(self)

	-- If there's a join code, adjust layout accordingly
	if TheNet:HasJoinCode() then
		-- There's a join code
		self.copycode_btn:Show()
		self.players_content_bg:SetTexture("images/ui_ftf_online/screen_players_code_bg.tex")
		self.code_text:Show()
			:SetText(TheNet:GetJoinCode())
			:LayoutBounds("center", "center", self.players_content_bg)
			:Offset(0, -73) -- Aligning the text with the texture
		self.code_label:Show()
			:LayoutBounds("center", "center", self.players_content_bg)
			:Offset(0, -177) -- Aligning the text with the texture
	else
		-- No join code
		self.copycode_btn:Hide()
		self.players_content_bg:SetTexture("images/ui_ftf_online/screen_players_footer_bg.tex")
		self.code_text:Hide()
		self.code_label:Hide()
	end

	-- This enables the brackets, which will focus on the close_button first

	----------------------------------------------------------------------
	-- Focus selection brackets
	self:EnableFocusBracketsForGamepad()
	-- self:EnableFocusBracketsForGamepadAndMouse()
	----------------------------------------------------------------------

	-- This will set the default_focus to one of the players
	self.tabs_widget:OpenTabAtIndex(1)

	-- After animating, place the brackets on the new default_focus
	self:AnimateIn(function()
		self:_UpdateSelectionBrackets(self.default_focus)
	end)

end

function PlayersScreen:OnUpdate(dt)
	self.refresh_time_remaining = math.max(0, self.refresh_time_remaining - dt)

	if self.refresh_time_remaining <= 0 then
		self.refresh_time_remaining = self.refresh_period
		self:UpdatePlayersList()
		self:UpdateBanList()
	end

	self.error_time_remaining = math.max(0, self.error_time_remaining - dt)

	if self.error_time_remaining <= 0 then
		self:HideErrorMessage()
	end
end

function PlayersScreen:UpdatePlayersList()

	local player_row_idx = 1

	-- Get all clients
	local clients = TheNet:GetClientList()
	for k, v in ipairs(clients) do

		-- Get players in this client
		local players = TheNet:GetPlayerListForClient(v.id)
		if players then
			for j, player_id in pairs(players) do
				local player_guid = TheNet:FindGUIDForPlayerID(player_id)
				local player_entity = Ents[player_guid]

				local row_widget = self.players_container.children[player_row_idx]
					:SetPlayerId(player_id)
					:SetOnClick(function() end) -- Resets the click function
					:HideBanButton()
					:HideRemoveButton()
					:SetPlayer(player_entity)
					:SetUsername(player_entity and player_entity:GetCustomUserName())
					:SetHost(player_id == 0) -- This is the host

				if not player_entity then
					row_widget:SetLoading()
				end

				-- Can this client be banned?
				if TheNet:IsHost() -- I am the host
				and j == 1 -- This is a client connected to the host
				and k > 1 -- and not the host itself
				then
					row_widget:ShowBanButton()
						:SetOnClick(function() self:OnClickBanClient(row_widget, v.id) end)
				end

				-- Can this local player be removed?
				if player_entity and player_entity:IsLocal() -- It's a local player
				and j > 1 -- But not the first
				then
					row_widget:ShowRemoveButton()
						:SetOnClick(function() self:OnClickRemovePlayer(row_widget, player_entity) end)
				end

				-- Show players indented under their client player
				row_widget:SetPlayerIndex(j)

				player_row_idx = player_row_idx + 1
			end
		end

	end

	while player_row_idx <= 4 do
		self.players_container.children[player_row_idx]
			:SetEmpty()
			:SetOnClick(function() end) -- Resets the click function
		player_row_idx = player_row_idx + 1
	end

	return self
end

function PlayersScreen:UpdateBanList()

	-- Get banned players
	local new_blacklist = TheNet:GetBlackList() or {}
	-- new_blacklist = {
	-- 	{ip = 132153235, name = "Username 1"},
	-- 	{ip = 947956799, name = "Username 2"},
	-- 	{ip = 253263673, name = "Username 3"},
	-- 	{ip = 759434636, name = "Username 4"},
	-- 	{ip = 759434636, name = "Username 5"},
	-- 	{ip = 759434636, name = "Username 7"},
	-- }

	-- Compare the number of banned players with the number of widgets already on the list
	if #new_blacklist > #self.banned_scroll_contents.children then
		-- There are more players than widgets
		-- Add widgets
		local count_to_add = #new_blacklist - #self.banned_scroll_contents.children
		for i = 1, count_to_add do
			self.banned_scroll_contents:AddChild(PlayersScreenBannedRow())
		end
	elseif #new_blacklist < #self.banned_scroll_contents.children then
		-- There are more widgets than players
		-- Remove widgets
		local count_to_remove = #self.banned_scroll_contents.children - #new_blacklist
		for i = 1, count_to_remove do
			self.banned_scroll_contents.children[1]:Remove()
		end
	end

	-- Refresh the content of each row
	for k, row_widget in ipairs(self.banned_scroll_contents.children) do
		row_widget:SetIP(new_blacklist[k].ip)
			:SetUsername(new_blacklist[k].name)
			:SetOnClick(function() self:OnClickRemoveBan(row_widget) end)
	end

	-- Layout widgets
	self.banned_scroll_contents:LayoutChildrenInColumn(20)
		:LayoutBounds("center", "top", 0, 0)
	self.banned_scroll:RefreshView()

	-- Show empty-label if nothing on the list
	self.banned_empty_label:SetShown(self.banned_scroll_contents:IsEmpty())

end

function PlayersScreen:OnClickRemoveBan(row_widget)

	TheNet:RemoveFromBlackList(row_widget:GetIP())
	self.refresh_time_remaining = 0.2 -- make it refresh in 0.2 seconds

end

function PlayersScreen:OnClickBanClient(row_widget, client_id)

	local player_entity = row_widget:GetPlayer()

	local title = string.format(STRINGS.UI.PLAYERSSCREEN.POPUP_BAN_TITLE, player_entity:GetCustomUserName())
	local subtitle = nil
	local message = STRINGS.UI.PLAYERSSCREEN.POPUP_BAN_TEXT
	local popup = ConfirmDialog(nil, nil, true,
			title,
			subtitle,
			message
		)
		:HideNoButton()
		:SetCancelButtonText(STRINGS.UI.BUTTONS.CANCEL)

	popup:SetOnDoneFn(function(picked_ban)
			if picked_ban == true then
				TheNet:KickClient(client_id)
			end
			TheFrontEnd:PopScreen(popup)
		end)
		:HideArrow()
		:SetMinWidth(650)
		:CenterText()
		:CenterButtons()

	TheFrontEnd:PushScreen(popup)
	popup:AnimateIn()

	return self
end

function PlayersScreen:OnClickRemovePlayer(row_widget, player_entity)

	net_removeplayer(row_widget:GetPlayerId())

	return self
end

function PlayersScreen:NextTab(delta)
	self.tabs_widget:NextTab(delta)
	return self
end

function PlayersScreen:OnClickClose()
	TheFrontEnd:PopScreen(self)
	self:StopUpdating()
	return self
end

function PlayersScreen:OnCopyCodeClicked()
	if TheNet:HasJoinCode() then
		TheNet:CopyJoinCodeToClipboard()

		if not self.notification_widget then

			-- Show a notification
			self.notification_widget = TheFrontEnd:ShowTextNotification("images/ui_ftf_notifications/sharecode.tex", STRINGS.UI.PLAYERSSCREEN.NOTIFICATION_CODE_COPIED_TITLE, string.format(STRINGS.UI.PLAYERSSCREEN.NOTIFICATION_CODE_COPIED_TEXT, TheNet:GetJoinCode()), 6)

			-- Prevent multiple notifications from being triggered
			self.notification_widget:SetOnRemoved(function() self.notification_widget = nil end)
		end
	end
end

function PlayersScreen:OnAddLocalPlayerClicked()
	local can_add_player, return_error = net_canaddplayer()
	if can_add_player then
		-- NW: Can't do this anymore. net_addplayer HAS to be called with a valid inputID. 
		--net_addplayer()
		--self:HideErrorMessage()
		local AddPlayerDialog = require ("screens/dialogs/addplayerdialog")
		TheFrontEnd:PushScreen(AddPlayerDialog())
	else
		if return_error == "ERROR_NO_FREE_INPUT_DEVICE" then
			self.addplayer_error_text:SetText(STRINGS.UI.PLAYERSSCREEN.ERROR_NO_FREE_INPUT_DEVICE)
		elseif return_error == "ERROR_NO_AVAILABLE_SLOTS" then
			self.addplayer_error_text:SetText(STRINGS.UI.PLAYERSSCREEN.ERROR_NO_AVAILABLE_PLAYER_SLOTS)
		end

		-- Animate in the error message
		self.addplayer_error_widget_displayed = true
		self.addplayer_error_widget:SetPosition(self.addplayer_error_widget_x, self.addplayer_error_widget_y - 40)
			:SetMultColorAlpha(0)
			:MoveTo(self.addplayer_error_widget_x, self.addplayer_error_widget_y, 0.95, easing.outElasticUI)
			:AlphaTo(1, 0.2, easing.outQuad)
			:Show()
		TheFrontEnd:GetSound():PlaySound(fmodtable.Event.error_bump)

		-- So the message disappears after some time
		self.error_time_remaining = self.error_duration
	end
end

function PlayersScreen:HideErrorMessage()
	if self.addplayer_error_widget_displayed then
		self.addplayer_error_widget_displayed = false
		self.addplayer_error_widget:AlphaTo(0, 0.15, easing.outQuad)
			:MoveTo(self.addplayer_error_widget_x, self.addplayer_error_widget_y - 10, 0.95, easing.outElasticUI, function()
				self.addplayer_error_widget:Hide()
			end)
	end
end

function PlayersScreen:OnTabClicked(btn)
	if btn == self.tab_players then
		self.banned_content:Hide()
		self.players_content:Show()
		if self.players_container:HasChildren() then
			self.default_focus = self.players_container.children[1]
		else
			self.default_focus = self.copycode_btn
		end
	elseif btn == self.tab_banned then
		self.players_content:Hide()
		self.banned_content:Show()
		if self.banned_scroll_contents:HasChildren() then
			self.default_focus = self.banned_scroll_contents.children[1]
		else
			self.default_focus = self.banned_empty_label
		end
	end
	if TheFrontEnd:IsRelativeNavigation() and self.default_focus then
		self.default_focus:SetFocus()
	end
end

function PlayersScreen:Layout()
	self.tabs_container:LayoutBounds("center", "top", self.bg)
		:Offset(0, -70)

	self.players_container:LayoutChildrenInColumn(20, "center")
		:LayoutBounds("center", "top", self.bg)
		:Offset(0, -290)

	self.players_content_bg:LayoutBounds("center", "bottom", self.bg)
	self.copycode_btn:LayoutBounds("center", "center", self.bg)
		:Offset(-self.panel_w/2 + 220, -self.panel_h/2 + 190)
	self.addlocalplayer_btn:LayoutBounds("center", "center", self.bg)
		:Offset(self.panel_w/2 - 200, -self.panel_h/2 + 190)

	self.banned_content_top_bg:LayoutBounds("center", "top", self.bg)
	self.banned_content_bottom_bg:LayoutBounds("center", "bottom", self.bg)

	self.addplayer_error_text:LayoutBounds("center", "center", self.addplayer_error_bg)
		:Offset(-5, -10)
	self.addplayer_error_widget:LayoutBounds("center", "below", self.addlocalplayer_btn)
		:Offset(0, -15)
	self.addplayer_error_widget_x, self.addplayer_error_widget_y = self.addplayer_error_widget:GetPos() -- For animation

	return self
end

function PlayersScreen:AnimateIn(on_done)
	local x, y = self.dialog_container:GetPosition()
	self.dialog_container:ScaleTo(0.8, 1, 0.15, easing.outQuad)
		:SetPosition(x, y - 60)
		:MoveTo(x, y, 0.25, easing.outQuad)
	self.scrim:SetMultColorAlpha(0)
		:AlphaTo(0.85, 0.3, easing.outQuad, on_done)
	return self
end

return PlayersScreen
