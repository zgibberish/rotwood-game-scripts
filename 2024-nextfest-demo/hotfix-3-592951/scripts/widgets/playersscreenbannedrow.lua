local Widget = require("widgets/widget")
local Clickable = require("widgets/clickable")
local Text = require("widgets/text")
local Panel = require("widgets/panel")
local Image = require("widgets/image")

local easing = require "util.easing"

------------------------------------------------------------------------------------
-- Displays a single player on the PlayersScreen.

local PlayersScreenBannedRow = Class(Clickable, function(self) self:init() end)

PlayersScreenBannedRow.WIDTH = 1060
PlayersScreenBannedRow.HEIGHT = 240

function PlayersScreenBannedRow:init()
    Clickable._ctor(self, "PlayersScreen Banned Row")

    self.text_width = 500
	self.padding_h = 20
    self.right_btn_width = 300

    -- Add contents
    self.bg = self:AddChild(Panel("images/ui_ftf_online/player_bg.tex"))
		:SetName("Background")
		:SetNineSliceCoords(90, 0, 970, 240)
		:SetSize(PlayersScreenBannedRow.WIDTH, PlayersScreenBannedRow.HEIGHT)

	self.text_width = PlayersScreenBannedRow.WIDTH - 140 - self.right_btn_width

	self.text_container = self:AddChild(Widget())
		:SetName("Text container")
	self.title = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT*1.4))
		:SetName("Title")
		:SetGlyphColor(UICOLORS.SPEECH_BUTTON_TEXT)
		:OverrideLineHeight(FONTSIZE.SCREEN_TEXT * 1.2)
		:SetHAlign(ANCHOR_LEFT)
		:SetAutoSize(self.text_width)
	self.description = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetName("Description")
		:SetGlyphColor(UICOLORS.DARK_TEXT)
		:SetHAlign(ANCHOR_LEFT)
		:SetAutoSize(self.text_width)

	-- Ban and remove buttons
	self.row_unban_btn = self:AddChild(Image("images/ui_ftf_online/player_btn_remove.tex"))
		:SetName("Unban button")
		:SetSize(self.right_btn_width, PlayersScreenBannedRow.HEIGHT)
		:LayoutBounds("right", "center", self.bg)
	self.row_unban_text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetName("Unban text")
		:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
		:OverrideLineHeight(FONTSIZE.SCREEN_TEXT * 0.8)
		:SetAutoSize(self.right_btn_width - self.padding_h*2)
		:SetText(STRINGS.UI.PLAYERSSCREEN.UNBAN_BTN)
		:LayoutBounds("center", "center", self.row_unban_btn)

	self:SetOnGainFocus(function() self:OnFocusChanged(true) end)
	self:SetOnLoseFocus(function() self:OnFocusChanged(false) end)
end

function PlayersScreenBannedRow:GetClientId()
	return self.client_id
end

function PlayersScreenBannedRow:ShowBanButton()
	self.row_unban_btn:Show()
	self.row_unban_text:Show()
	self:Layout()
	return self
end

function PlayersScreenBannedRow:HideBanButton()
	self.row_unban_btn:Hide()
	self.row_unban_text:Hide()
	return self
end

function PlayersScreenBannedRow:SetIP(ip)
	self.ip = ip
	self.description:SetText(self.ip)
	return self
end

function PlayersScreenBannedRow:GetIP()
	return self.ip
end

function PlayersScreenBannedRow:SetUsername(username)
	self.username = username
	self.title:SetText(username)
	self:Layout()
	return self
end

function PlayersScreenBannedRow:GetUsername()
	return self.username
end

function PlayersScreenBannedRow:Layout()

	-- Position text widgets
	self.text_container:LayoutChildrenInColumn(0, "left")
		:LayoutBounds("left", "center", self.bg)
		:Offset(70, 3)

	return self
end

function PlayersScreenBannedRow:OnFocusChanged(has_focus)
	if has_focus then
		self.row_unban_btn:ColorAddTo(nil, HexToRGB(0x101010FF), 0.1, easing.outQuad)
	else
		self.row_unban_btn:ColorAddTo(nil, UICOLORS.BLACK, 0.2, easing.outQuad)
	end
	return self
end

return PlayersScreenBannedRow