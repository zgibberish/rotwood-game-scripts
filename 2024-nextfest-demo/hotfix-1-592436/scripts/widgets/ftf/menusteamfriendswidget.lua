local Widget = require("widgets/widget")
local Image = require ("widgets/image")
local ImageButton = require ("widgets/imagebutton")
local Panel = require ("widgets/panel")
local ScrollPanel = require ("widgets/scrollpanel")
local Text = require ("widgets/text")
local MenuSteamFriendRow = require ("widgets/ftf/menusteamfriendrow")

local easing = require "util.easing"

----------------------------------------------------------------------
-- A list of Steam friends the player can see and potentially join

local MenuSteamFriendsWidget = Class(Widget, function(self, width, height)
	Widget._ctor(self, "MenuSteamFriendsWidget")

	-- How often to refresh the list, in seconds
	self.refresh_period = 5
	self.refresh_time_remaining = 0
	self.connecting_time_min_UI_delay = 0.5 -- Wait these seconds before moving on after connecting

	self.width = width or 900
	self.height = height or 900
	self.padding = 60

	-- Based on the bg texture
	self.header_size = 160
	self.footer_size = 54
	self.left_size = 40
	self.right_size = 40
	self.scroll_right_padding = 20 -- So the scrollbar doesn't touch the right edge
	self.scroll_contents_width = self.width - self.left_size - self.right_size - 100 -- So they have enough padding

	self.bg = self:AddChild(Panel("images/ui_ftf_multiplayer/multiplayer_btn_friends.tex"))
		:SetName("Background")
		:SetNineSliceCoords(70, 180, 600, 190)
		:SetSize(self.width, self.height)

	self.title = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.MENU_BUTTON_TITLE))
		:SetName("Title")
		:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
		:SetHAlign(ANCHOR_LEFT)
		:SetAutoSize(self.width - self.padding*2)
		:SetText(STRINGS.UI.STEAMFRIENDSWIDGET.TITLE)
		:LayoutBounds("left", "top", self.bg)
		:Offset(self.padding, -self.padding)

	self.scroll = self:AddChild(ScrollPanel())
		:SetName("Scroll")
		:SetSize(self.width - self.left_size - self.right_size - self.scroll_right_padding, self.height - self.header_size - self.footer_size)
		:SetVirtualMargin(50)
		:LayoutBounds("left", "top", self.bg)
		:Offset(self.left_size, -self.header_size)
	self.scroll_contents = self.scroll:AddScrollChild(Widget())
		:SetName("Scroll contents")

	self.empty_label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(self.scroll_contents_width)
		:SetText(STRINGS.UI.STEAMFRIENDSWIDGET.EMPTY_LABEL)
		:LayoutBounds("center", "top", self.bg)
		:Offset(0, -self.header_size-40)
end)

-- Start and StopUpdating have to be called by the parent
function MenuSteamFriendsWidget:OnUpdate(dt)

	self.refresh_time_remaining = math.max(0, self.refresh_time_remaining - dt)

	if self.refresh_time_remaining <= 0 then
		self.refresh_time_remaining = self.refresh_period
		self:RefreshFriendsList()
	end

end

function MenuSteamFriendsWidget:RefreshFriendsList()

	-- Remove old buttons, if any
	self.scroll_contents:RemoveAllChildren()

	-- Get a list of friends currently in game
	local friends = TheNet:GetFriendsPlayingThisGame()

	-- Add widgets for each
	for _i, friend_data in ipairs(friends) do
		local row_button = self.scroll_contents:AddChild(MenuSteamFriendRow(self.scroll_contents_width, friend_data))
		row_button:SetOnClickFn(function(device_type, device_id) self:OnClickJoinFriend(row_button, friend_data, device_type, device_id) end)
	end

	-- Layout
	self.scroll_contents:LayoutChildrenInColumn(25, "left")
		:LayoutBounds("center", "top", 0, 0)

	-- Hide empty label
	self.empty_label:SetShown(not self.scroll_contents:HasChildren())

	self.scroll:RefreshView()
end

function MenuSteamFriendsWidget:OnClickJoinFriend(row_button, friend_data, device_type, device_id)

	-- Disable the button for the moment
	self.selected_row_button = row_button
	self.selected_row_button:Disable()

	-- Keep track of the selected lobby
	self.selected_lobby = friend_data.lobby

	-- Show a "Connecting..." popup
	self.connect_popup = ShowConnectingToGamePopup()

	self:RunUpdater(Updater.Series{

		-- Wait at least this amount of time before actually going into the game
		Updater.Wait(self.connecting_time_min_UI_delay),

		-- Actually start the game
		Updater.Do(function()
			self:HandleGameStart(device_type, device_id)
		end)
	})

	return self
end

function MenuSteamFriendsWidget:HandleGameStart(device_type, device_id)

	-- Start the game
	local inputID = TheInput:ConvertToInputID(device_type, device_id)
	TheNet:StartGame(inputID, "invite", self.selected_lobby)
end

return MenuSteamFriendsWidget
