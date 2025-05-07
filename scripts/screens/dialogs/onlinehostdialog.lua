local Widget = require("widgets/widget")
local ActionButton = require("widgets/actionbutton")
local ImageButton = require("widgets/imagebutton")
local PanelButton = require("widgets/panelbutton")
local Text = require("widgets/text")
local TextEdit = require("widgets/textedit")
local CheckBox = require "widgets.checkbox"
local Image = require("widgets/image")
local Panel = require("widgets/panel")
local PopupDialog = require("screens/dialogs/popupdialog")

local RoomLoader = require "roomloader"
local Controls = require "input.controls"
local easing = require "util.easing"

----------------------------------------------------------------------
-- A dialog that allows the player to input a code
-- and join a friend's game

local OnlineHostDialog = Class(PopupDialog, function(self)
	PopupDialog._ctor(self, "OnlineHostDialog")

	self.max_text_width = 1300
	self.connecting_time_UI_delay = 0
	self.connecting_time_min_UI_delay = 1.5 -- Wait these seconds before moving on after connecting
	self.delay_after_showing_join_code = 1.1 -- Wait these seconds before starting the game

	self.dialog_container = self:AddChild(Widget())
		:SetName("Dialog container")

	self.glow = self.dialog_container:AddChild(Image("images/ui_ftf/gradient_circle.tex"))
		:SetName("Glow")
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARKER)

	self.bg = self.dialog_container:AddChild(Image("images/ui_ftf_multiplayer/popup_host.tex"))
		:SetName("Background")

	self.close_button = self.dialog_container:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:SetOnClick(function() self:OnClickClose() end)
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		:LayoutBounds("right", "top", self.bg)
		:Offset(-40, 0)

	self.text_container = self.dialog_container:AddChild(Widget())
	self.dialog_title = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_TITLE))
		:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(self.max_text_width)
		:SetText(STRINGS.UI.MAINSCREEN.HOST_DIALOG_TITLE)
	self.dialog_text = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_SUBTITLE*0.9))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(self.max_text_width)
		:SetText(STRINGS.UI.MAINSCREEN.HOST_DIALOG_TEXT)
	self.dialog_subtext = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_SUBTITLE*0.75))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(self.max_text_width)
		:SetText(STRINGS.UI.MAINSCREEN.HOST_DIALOG_SUBTEXT)
	-- self.sharecode_btn = self.text_container:AddChild(PanelButton("images/ui_ftf_multiplayer/code_input_bg.tex"))
	-- 	:SetName("Sharecode button")
	-- 	:SetNineSliceCoords(40, 40, 80, 80)
	-- 	:SetSize(700, 180)
	-- 	:SetImageFocusColour(UICOLORS.LIGHT_TEXT_DARKER)
	-- 	:SetImageNormalColour(UICOLORS.LIGHT_TEXT_DARK)
	-- 	:SetImageDisabledColour(UICOLORS.LIGHT_TEXT_DARK)
	-- 	:SetScaleOnFocus(false)
	-- 	:Disable()
	-- self.sharecode_text = self.text_container:AddChild(Text(FONTFACE.DEFAULT, 100))
	-- 	:SetGlyphColor(UICOLORS.WHITE)
	-- 	:SetHAlign(ANCHOR_MIDDLE)
	-- 	:SetText(STRINGS.UI.MAINSCREEN.HOST_DIALOG_CODE)

	-- Code-copied widget
	-- self.code_copied_widget = self.text_container:AddChild(Widget())
	-- 	:SetName("Code-copied widget")
	-- 	:SetHiddenBoundingBox(true)
	-- 	:SetMultColorAlpha(0)
	-- 	:Hide()
	-- self.code_copied_bg = self.code_copied_widget:AddChild(Image("images/ui_ftf_multiplayer/code_popup_arrow.tex"))
	-- 	:SetName("Code-copied bg")
	-- self.code_copied_text = self.code_copied_widget:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT*1.7))
	-- 	:SetName("Code-copied text")
	-- 	:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
	-- 	:SetHAlign(ANCHOR_MIDDLE)
	-- 	:SetAutoSize(450)
	-- 	:SetText(STRINGS.UI.MAINSCREEN.HOST_DIALOG_COPIED)


	-- self.friends_only_checkbox = self.text_container:AddChild(CheckBox({
	-- 		primary_active = UICOLORS.LIGHT_TEXT_DARKER,
	-- 		primary_inactive = UICOLORS.LIGHT_TEXT_DARK,
	-- 	}))
	-- 	:SetName("Friends-only checkbox")
	-- 	:SetSize(60, 60)
	-- 	:SetIsSlider(true)
	-- 	:SetTextSize(FONTSIZE.CONFIRM_DIALOG_SUBTITLE*0.8)
	-- 	:SetTextWidth(1300)
	-- 	:SetText(STRINGS.UI.MAINSCREEN.HOST_DIALOG_FRIENDS_CHECKBOX)
	-- 	:SetValue(false)
	-- 	:SetOnChangedFn(function(val)
	-- 		self:OnFriendsOnlyCheckboxChanged()
	-- 	end)
	self.loading_text = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_SUBTITLE))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetText(STRINGS.UI.MAINSCREEN.HOST_DIALOG_LOADING_TEXT)
		:Hide()
	self.start_btn = self.text_container:AddChild(ActionButton())
		:SetSize(BUTTON_W, BUTTON_H)
		:SetSecondary()
		:SetScaleOnFocus(false)
		:SetText(STRINGS.UI.MAINSCREEN.HOST_DIALOG_BTN)
		:SetOnClick(function(device_type, device_id) self:OnClickStart(device_type, device_id) end)

	self:_LayoutDialog()

	self.default_focus = self.start_btn

end)

OnlineHostDialog.CONTROL_MAP =
{
	{
		control = Controls.Digital.CANCEL,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.CANCEL", Controls.Digital.CANCEL))
		end,
		fn = function(self)
			if self.close_button:IsShown() then
				self.close_button:Click()
			end
			return true
		end,
	}
}

function OnlineHostDialog:_LayoutDialog()

	local w, h = self.bg:GetSize()
	self.glow:SetSize(w + 500, h + 500)

	self.dialog_text:LayoutBounds("center", "below", self.dialog_title)
		:Offset(0, -20)
	self.dialog_subtext:LayoutBounds("center", "below", self.dialog_text)
		:Offset(0, -20)

	-- if self.sharecode_btn:IsShown() then
	-- 	self.sharecode_btn:LayoutBounds("center", "below", self.dialog_text)
	-- 		:Offset(0, -50)
	-- 	self.sharecode_text:LayoutBounds("center", "center", self.sharecode_btn)
	-- 		:Offset(0, 4)
	-- 	self.code_copied_text:LayoutBounds("center", "center", self.code_copied_bg)
	-- 		:Offset(-15, 5)
	-- 	self.code_copied_widget:LayoutBounds("before", "center", self.sharecode_btn)
	-- 		:Offset(-30, 0)
	-- 	self.code_copied_widget_x, self.code_copied_widget_y = self.code_copied_widget:GetPos() -- For animation
	-- 	self.friends_only_checkbox:LayoutBounds("center", "below", self.sharecode_btn)
	-- 		:Offset(0, -30)
	-- else
	-- 	self.friends_only_checkbox:LayoutBounds("center", "below", self.dialog_text)
	-- 		:Offset(0, -50)
	-- end
	-- self.start_btn:LayoutBounds("center", "below", self.friends_only_checkbox)
	self.start_btn:LayoutBounds("center", "below")
		:Offset(0, -100)
	self.loading_text:LayoutBounds("center", "center", self.start_btn)
		:Offset(0, 50)

	self.text_container:LayoutBounds("center", "center", self.bg)

	return self
end

-- function OnlineHostDialog:OnFriendsOnlyCheckboxChanged()
-- 	if self.friends_only_checkbox:IsChecked() then
-- 		self.dialog_text:SetText(STRINGS.UI.MAINSCREEN.HOST_DIALOG_TEXT_FRIENDSONLY)
-- 		self.sharecode_btn:Hide()
-- 		self.sharecode_text:Hide()
-- 	else
-- 		self.dialog_text:SetText(STRINGS.UI.MAINSCREEN.HOST_DIALOG_TEXT)
-- 		self.sharecode_btn:Show()
-- 		self.sharecode_text:Show()
-- 	end
-- 	self:_LayoutDialog()
-- 	return self
-- end

-- function OnlineHostDialog:_ShowCodeWidget()
-- 	if self.code_copied_widget:IsShown() then return self end

-- 	self.code_copied_widget:SetPosition(self.code_copied_widget_x - 40, self.code_copied_widget_y)
-- 		:MoveTo(self.code_copied_widget_x, self.code_copied_widget_y, 0.95, easing.outElasticUI)
-- 		:AlphaTo(1, 0.2, easing.outQuad)
-- 		:Show()

-- 	TheFrontEnd:ShowTextNotification("images/ui_ftf_notifications/sharecode.tex", STRINGS.UI.PLAYERSSCREEN.NOTIFICATION_CODE_COPIED_TITLE, string.format(STRINGS.UI.PLAYERSSCREEN.NOTIFICATION_CODE_COPIED_TEXT, TheNet:GetJoinCode()), 6)

-- 	return self
-- end

-- function OnlineHostDialog:_HideCodeWidget()
-- 	self.code_copied_widget:Hide()
-- 		:SetPosition(self.code_copied_widget_x, self.code_copied_widget_y)
-- 	return self
-- end

function OnlineHostDialog:OnOpen()
	OnlineHostDialog._base.OnOpen(self)
	self:AnimateIn()

	----------------------------------------------------------------------
	-- Focus selection brackets
	self:EnableFocusBracketsForGamepad()
	-- self:EnableFocusBracketsForGamepadAndMouse()
	----------------------------------------------------------------------
end

function OnlineHostDialog:OnBecomeActive()
	OnlineHostDialog._base.OnBecomeActive(self)
	self:StartUpdating()
end

function OnlineHostDialog:OnClickClose()
	TheFrontEnd:PopScreen(self)
	self:StopUpdating()
	return self
end

function OnlineHostDialog:OnClickStart(device_type, device_id)

	-- Disable the start button for the moment
	self.start_btn:Disable()

	-- Show a "Connecting..." popup
	self.connect_popup = ShowConnectingToGamePopup()

	-- Wait at least this amount of time before actually going into the game
	self.connecting_time_UI_delay = self.connecting_time_min_UI_delay

	-- Trigger the actual game start
	-- if self.friends_only_checkbox:IsChecked() then
	-- 	-- Player wants a friends only game!
	-- 	TheNet:StartGame(inputID, "friends")
	-- else
		-- Player wants a code + friends game!
		local inputID = TheInput:ConvertToInputID(device_type, device_id)
		TheNet:StartGame(inputID, "joincode")
	-- end

	return self
end

function OnlineHostDialog:OnUpdate(dt)

	-- Decrease the delay, if it's ongoing
	self.connecting_time_UI_delay = math.max(0, self.connecting_time_UI_delay - dt)

	-- If we're not attempting to start a game (showing the loading popup), bail
	if not self.connect_popup then return end

	-- Wait until delay is done before proceeding
	if self.connecting_time_UI_delay > 0 then return end

	if TheNet:IsGameReady() and TheNet:IsHost() then
		-- if self.friends_only_checkbox:IsChecked() then
		-- 	-- Player started a friends only game!
		-- 	self:HandleFriendsGameStart()
		-- else
			-- Player started a code + friends game!
			self:HandleCodeGameStart()
		-- end
	else
		-- Check if there was an error connecting. If the popup is up, we should be in game
		if not TheNet:IsInGame() then
			self:HandleGameStartFailed()
		end
	end

end

function OnlineHostDialog:HandleFriendsGameStart()

	-- Close the "Connecting..." popup
	if self.connect_popup then self.connect_popup:Close() end
	self.connect_popup = nil

	-- Hide button and show loading message
	self.start_btn:Hide()
	self.close_button:Hide()
	self.loading_text:Show()

	-- Start the game after a beat
	self:RunUpdater(Updater.Series{
		Updater.Wait(self.delay_after_showing_join_code),
		Updater.Do(function()
			self:StartGame()
		end)
	})
end

function OnlineHostDialog:HandleCodeGameStart()

	-- Close the "Connecting..." popup
	if self.connect_popup then self.connect_popup:Close() end
	self.connect_popup = nil

	-- Show the correct code
	-- self.sharecode_text:SetText(TheNet:GetJoinCode())
	-- self:_LayoutDialog()

	-- Copy it to the clipboard
	TheNet:CopyJoinCodeToClipboard()

	-- Show the "Code copied" widget
	-- self:_ShowCodeWidget()

	-- Hide button and show loading message
	self.start_btn:Hide()
	self.close_button:Hide()
	self.loading_text:Show()

	-- Start the game after a beat
	-- self:RunUpdater(Updater.Series{
	-- 	Updater.Wait(self.delay_after_showing_join_code),
	-- 	Updater.Do(function()
			self:StartGame()
	-- 	end)
	-- })
end

function OnlineHostDialog:HandleGameStartFailed()

	-- Close the "Connecting..." popup
	if self.connect_popup then self.connect_popup:Close() end
	self.connect_popup = nil

	-- Re-enable the start and close buttons
	self.start_btn:Show()
		:Enable()
	self.close_button:Show()

	-- Hide loading
	self.loading_text:Hide()

end

function OnlineHostDialog:StartGame()
	RoomLoader.LoadTownLevel(TOWN_LEVEL)
	self:StopUpdating()
	TheFrontEnd:PopScreen(self)
end

function OnlineHostDialog:AnimateIn()
	local x, y = self.dialog_container:GetPosition()
	self:ScaleTo(0.8, 1, 0.15, easing.outQuad)
		:SetPosition(x, y - 60)
		:MoveTo(x, y, 0.25, easing.outQuad)
	self.glow:SetMultColorAlpha(0)
		:AlphaTo(0.25, 0.4, easing.outQuad)
	return self
end

return OnlineHostDialog
