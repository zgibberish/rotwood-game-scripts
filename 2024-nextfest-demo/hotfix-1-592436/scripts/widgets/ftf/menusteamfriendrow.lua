local Widget = require("widgets/widget")
local Image = require ("widgets/image")
local ImageButton = require ("widgets/imagebutton")
local Panel = require ("widgets/panel")
local ScrollPanel = require ("widgets/scrollpanel")
local Text = require ("widgets/text")

local easing = require "util.easing"

----------------------------------------------------------------------
-- A single Steam friend row for a list

local MenuSteamFriendRow = Class(ImageButton, function(self, width, friend_data)
	ImageButton._ctor(self, "images/ui_ftf_multiplayer/friend_row.tex")

	-- Store data
	self.friend_data = friend_data
	self.friend_name = friend_data.name
	self.friend_lobby = friend_data.lobby

	-- Prepare sizes
	self.width = width or 600
	self.height = 90
	self.padding_h = 12
	self.padding_v = 12
	self.avatar_size = self.height - self.padding_v*2
	self.join_btn_width = 190

	-- Set ImageButton defaults
	self:SetScaleOnFocus(false)
		:SetSize(self.width, self.height)

	-- Add widgets
	self.row_avatar = self:AddChild(Image("images/global/square.tex"))
		:SetName("Avatar")
		:SetSize(self.avatar_size, self.avatar_size)
		:LayoutBounds("left", "center", self:GetImage())
		:Offset(self.padding_h)
		:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_MID)
		:SetMultColorAlpha(0.35)
	self.row_username = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetName("Username")
		:SetGlyphColor(UICOLORS.SPEECH_BUTTON_TEXT)
		:SetAutoSize(self.width - self.padding_h*4 - self.avatar_size - self.join_btn_width)
		:SetText(self.friend_name)
		:LayoutBounds("after", "center", self.row_avatar)
		:Offset(self.padding_h)

	if self.friend_lobby then
		-- You can join. Show button
		self.row_join_btn = self:AddChild(Image("images/ui_ftf_multiplayer/friend_row_btn.tex"))
			:SetName("Join button")
			:SetSize(self.join_btn_width, self.height)
			:LayoutBounds("right", "center", self:GetImage())
		self.row_join_text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
			:SetName("Join text")
			:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
			:SetAutoSize(self.join_btn_width - self.padding_h*2)
			:SetText(STRINGS.UI.STEAMFRIENDSWIDGET.JOIN_FRIEND_BTN)
			:LayoutBounds("center", "center", self.row_join_btn)
		self:Enable()
	else
		-- No lobby. The person is in the menu
		self.no_lobby_text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
			:SetName("No-lobby text")
			:SetGlyphColor(UICOLORS.LIGHT_BACKGROUNDS_DARK)
			:SetAutoSize(self.join_btn_width - self.padding_h*2)
			:SetText(STRINGS.UI.STEAMFRIENDSWIDGET.FRIEND_NOT_IN_LOBBY)
			:LayoutBounds("after", "center", self:GetImage())
		self.no_lobby_text:Offset(-self.join_btn_width/2 - self.no_lobby_text:GetSize()/2, 0)
		self:Disable()
	end

	self:SetOnGainFocus(function() self:OnFocusChanged(true) end)
	self:SetOnLoseFocus(function() self:OnFocusChanged(false) end)

end)

function MenuSteamFriendRow:OnFocusChanged(has_focus)
	if has_focus then
		-- self:GetImage():ColorAddTo(nil, UICOLORS.LIGHT_BACKGROUNDS_LIGHT, 0.1, easing.outQuad)
		if self.row_join_btn then self.row_join_btn:ColorAddTo(nil, HexToRGB(0x101010FF), 0.1, easing.outQuad) end
	else
		-- self:GetImage():ColorAddTo(nil, UICOLORS.BLACK, 0.2, easing.outQuad)
		if self.row_join_btn then self.row_join_btn:ColorAddTo(nil, UICOLORS.BLACK, 0.2, easing.outQuad) end
	end
	return self
end

return MenuSteamFriendRow