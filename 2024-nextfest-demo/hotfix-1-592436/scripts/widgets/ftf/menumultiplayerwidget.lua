local Widget = require("widgets/widget")
local Image = require ("widgets/image")
local Text = require ("widgets/text")
local ActionButton = require ("widgets/actionbutton")
local MenuButton = require ("widgets/ftf/menubutton")
local fmodtable = require "defs.sound.fmodtable"

local easing = require "util.easing"

----------------------------------------------------------------------
-- After the player clicks PLAY on the main menu,
-- this shows the buttons to play single or multiplayer

local MenuMultiplayerWidget = Class(Widget, function(self, player)
	Widget._ctor(self, "MenuMultiplayerWidget")

	self.error_duration = 4

	self.buttons_container = self:AddChild(Widget())
		:SetName("Buttons container")

	self.single_player_button = self.buttons_container:AddChild(MenuButton(600, 800))
		:SetName("Single player button")
		:SetTexture("images/ui_ftf_multiplayer/multiplayer_btn_solo.tex")
		:SetNineSliceCoords(0, 50, 670, 60)
		:SetText(STRINGS.UI.MAINSCREEN.BTN_SINGLE_PLAYER_TITLE, STRINGS.UI.MAINSCREEN.BTN_SINGLE_PLAYER_TEXT)
		:SetTextColor(nil, HexToRGB(0x97660Eff))
		:AddImage("images/ui_ftf_multiplayer/multiplayer_img_solo.tex")
		:SetControlUpSound(fmodtable.Event.ui_input_up_play)

	self.multi_player_button = self.buttons_container:AddChild(MenuButton(600, 800))
		:SetName("Single player button")
		:SetTexture("images/ui_ftf_multiplayer/multiplayer_btn_multiplayer.tex")
		:SetNineSliceCoords(0, 50, 670, 60)
		:SetText(STRINGS.UI.MAINSCREEN.BTN_MULTI_PLAYER_TITLE, STRINGS.UI.MAINSCREEN.BTN_MULTI_PLAYER_TEXT)
		:SetTextColor(nil, HexToRGB(0x006D58ff))
		:AddImage("images/ui_ftf_multiplayer/multiplayer_img_multiplayer.tex")

	self.buttons_container:LayoutChildrenInRow(40)

	-- Save button positions for animation purposes
	self.single_player_button_x, self.single_player_button_y = self.single_player_button:GetPos()
	self.multi_player_button_x, self.multi_player_button_y = self.multi_player_button:GetPos()

	self.info_label = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_BACKGROUNDS_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(900)
		:SetText(STRINGS.UI.MAINSCREEN.MULTIPLAYER_INFO)
		:LayoutBounds("center", "below", self.buttons_container)
		:Offset(0, -60)

	-- Add-player error widget
	self.offline_error_widget = self:AddChild(Widget())
		:SetName("Offline error widget")
		:SetHiddenBoundingBox(true)
		:SetMultColorAlpha(0)
		:Hide()
	self.offline_error_bg = self.offline_error_widget:AddChild(Image("images/ui_ftf_online/sharecode_popup_arrow.tex"))
		:SetName("Offline error bg")
	self.offline_error_text = self.offline_error_widget:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetName("Offline error text")
		:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
		:SetText(STRINGS.UI.MAINSCREEN.OFFLINE_ERROR)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(450)
		:LayoutBounds("center", "center", self.offline_error_bg)
		:Offset(-5, -10)
	self.offline_error_widget:LayoutBounds("center", "bottom", self.multi_player_button)
		:Offset(0, -40)
	self.offline_error_widget_x, self.offline_error_widget_y = self.offline_error_widget:GetPos() -- For animation

	self.default_focus = self.single_player_button

end)

function MenuMultiplayerWidget:SetOnSingleplayerFn(fn)
	self.single_player_button:SetOnClick(fn)
	return self
end

function MenuMultiplayerWidget:SetOnMultiplayerFn(fn)
	self.multi_player_button:SetOnClick(fn)
	return self
end

-- Disables the multiplayer button if offline
function MenuMultiplayerWidget:SetOnline(is_online)
	self.multi_player_button:SetText(STRINGS.UI.MAINSCREEN.BTN_MULTI_PLAYER_TITLE,
		is_online and STRINGS.UI.MAINSCREEN.BTN_MULTI_PLAYER_TEXT or STRINGS.UI.MAINSCREEN.BTN_MULTI_PLAYER_TEXT_OFFLINE)
	return self
end

function MenuMultiplayerWidget:ShowOfflineError()
	-- Animate in the error message if there isn't one already
	if not self.error_message_updater
	or (self.error_message_updater and self.error_message_updater:IsDone()) then
		self.error_message_updater = self.offline_error_widget:RunUpdater(Updater.Series{
			Updater.Do(function()
				self.offline_error_widget:SetPosition(self.offline_error_widget_x, self.offline_error_widget_y - 40)
					:SetMultColorAlpha(0)
					:MoveTo(self.offline_error_widget_x, self.offline_error_widget_y, 0.95, easing.outElasticUI)
					:AlphaTo(1, 0.2, easing.outQuad)
					:Show()
			end),
			Updater.Wait(self.error_duration),
			Updater.Do(function()
				self:HideOfflineError()
			end)
		})
	end
end

function MenuMultiplayerWidget:HideOfflineError()
	self.offline_error_widget:AlphaTo(0, 0.15, easing.outQuad)
		:MoveTo(self.offline_error_widget_x, self.offline_error_widget_y - 10, 0.95, easing.outElasticUI, function()
			self.offline_error_widget:Hide()
		end)
end

function MenuMultiplayerWidget:AnimateIn(on_done_fn)
	self.single_player_button:SetMultColorAlpha(0)
	self.multi_player_button:SetMultColorAlpha(0)

	self:RunUpdater(Updater.Parallel{
		Updater.Ease(function(a) self.single_player_button:SetMultColorAlpha(a) end, 0, 1, 0.25, easing.outQuad),
		Updater.Ease(function(y) self.single_player_button:SetPos(self.single_player_button_x, y) end, self.single_player_button_y-40, self.single_player_button_y, 0.75, easing.outElasticUI),

		Updater.Series{
			Updater.Wait(0.1),
			Updater.Parallel{
				Updater.Ease(function(a) self.multi_player_button:SetMultColorAlpha(a) end, 0, 1, 0.25, easing.outQuad),
				Updater.Ease(function(y) self.multi_player_button:SetPos(self.multi_player_button_x, y) end, self.multi_player_button_y-40, self.multi_player_button_y, 0.75, easing.outElasticUI),
			}
		},

		Updater.Series{
			Updater.Wait(0.25),
			Updater.Do(function()
				if on_done_fn then on_done_fn() end
			end)
		}

	})
	return self
end

function MenuMultiplayerWidget:AnimateOut(on_done_fn)
	if on_done_fn then on_done_fn() end
	return self
end

return MenuMultiplayerWidget