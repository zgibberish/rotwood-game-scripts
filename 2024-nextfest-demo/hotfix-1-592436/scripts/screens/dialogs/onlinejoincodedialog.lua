local Widget = require("widgets/widget")
local ActionButton = require("widgets/actionbutton")
local ImageButton = require("widgets/imagebutton")
local Text = require("widgets/text")
local TextEdit = require("widgets/textedit")
local Image = require("widgets/image")
local Panel = require("widgets/panel")

local PopupDialog = require("screens/dialogs/popupdialog")

local Controls = require "input.controls"

local easing = require "util.easing"

----------------------------------------------------------------------
-- A dialog that allows the player to input a code
-- and join a friend's game

local OnlineJoinCodeDialog = Class(PopupDialog, function(self, device_type, device_id)
	PopupDialog._ctor(self, "OnlineJoinCodeDialog")

	self.max_text_width = 1300
	self.connecting_time_UI_delay = 0
	self.connecting_time_min_UI_delay = 1.5 -- Wait these seconds before moving on after connecting
	self.device_type = device_type
	self.device_id = device_id

	self.dialog_container = self:AddChild(Widget())
		:SetName("Dialog container")

	self.glow = self.dialog_container:AddChild(Image("images/ui_ftf/gradient_circle.tex"))
		:SetName("Glow")
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARKER)

	self.bg = self.dialog_container:AddChild(Image("images/ui_ftf_multiplayer/popup_join.tex"))
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
		:SetText(STRINGS.UI.MAINSCREEN.JOIN_DIALOG_TITLE)
	self.dialog_text = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_SUBTITLE*0.9))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(self.max_text_width)
		:SetText(STRINGS.UI.MAINSCREEN.JOIN_DIALOG_TEXT)
	self.dialog_inputbox = self.text_container:AddChild(TextEdit(FONTFACE.DEFAULT, 100))
		:SetSize(700, 180)
		:SetOnlineJoinTheme()
		:SetHAlign(ANCHOR_MIDDLE)
		:SetLines(1)
		:SetString("")
		:SetTextLengthLimit(5)
		:SetUppercase(true)
		:SetCharacterFilter("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
		:SetForceEdit(true)
		:SetFn(function(text) self:HandleJoinCodeInputted() end)

	self.dialog_inputbox.OnTextEntered = function(text)
		self:HandleJoinCodeInputted(text)
		if self.join_btn:IsEnabled() then
			self.join_btn:Click()
		end
	end
	self.join_btn = self.text_container:AddChild(ActionButton())
		:SetSize(BUTTON_W, BUTTON_H)
		:SetSecondary()
		:SetScaleOnFocus(false)
		:SetText(STRINGS.UI.MAINSCREEN.JOIN_DIALOG_BTN)
		:SetOnClick(function(device_type, device_id) self:OnClickJoin(device_type, device_id) end)
		:Disable()

	self:_LayoutDialog()

	self.default_focus = self.join_btn

end)

OnlineJoinCodeDialog.CONTROL_MAP =
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

function OnlineJoinCodeDialog:HandleJoinCodeInputted()
	self.join_btn:SetEnabled(TheNet:IsValidJoinCode(self.dialog_inputbox:GetText()))
end

function OnlineJoinCodeDialog:_LayoutDialog()

	local w, h = self.bg:GetSize()
	self.glow:SetSize(w + 500, h + 500)

	self.dialog_text:LayoutBounds("center", "below", self.dialog_title)
		:Offset(0, -20)
	self.dialog_inputbox:LayoutBounds("center", "below", self.dialog_text)
		:Offset(0, -70)
	self.join_btn:LayoutBounds("center", "below", self.dialog_inputbox)
		:Offset(0, -70)

	self.text_container:LayoutBounds("center", "center", self.bg)

	return self
end

function OnlineJoinCodeDialog:OnOpen()
	OnlineJoinCodeDialog._base.OnOpen(self)
	self:AnimateIn()

	----------------------------------------------------------------------
	-- Focus selection brackets
	self:EnableFocusBracketsForGamepad()
	-- self:EnableFocusBracketsForGamepadAndMouse()
	----------------------------------------------------------------------
end

function OnlineJoinCodeDialog:OnBecomeActive()
	OnlineJoinCodeDialog._base.OnBecomeActive(self)
	self.dialog_inputbox:SetFocus()
	self.dialog_inputbox:SetEditing(true)
	self.join_btn:Enable()
	self:StartUpdating()

	self:HandleJoinCodeInputted()

	-- Close the "Connecting..." popup, if any
	if self.connect_popup then self.connect_popup:Close() end
	self.connect_popup = nil
end

function OnlineJoinCodeDialog:OnClickClose()
	TheFrontEnd:PopScreen(self)
	self:StopUpdating()
	return self
end

function OnlineJoinCodeDialog:OnClickJoin(device_type, device_id)

	-- Disable the start button for the moment
	self.join_btn:Disable()

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

function OnlineJoinCodeDialog:HandleGameStart(device_type, device_id)

	-- Get code
	local code = self.dialog_inputbox and self.dialog_inputbox:GetText() or ""
	code = self:_SanitizeJoinCode(code)
	self.dialog_inputbox:SetText(code)

	-- Start the game
	-- Take the device type and id from the time that this dialog was activated. (as it's likely the person will have typed something and clicked OK with the mouse)
	local inputID = TheInput:ConvertToInputID(self.device_type, self.device_id)
	TheNet:StartGame(inputID, "invitejoincode", code)
end

-- really basic sanitization in conjunction with the preset limit + character filter
function OnlineJoinCodeDialog:_SanitizeJoinCode(code)
	if not code then
		return ""
	end

	return string.upper(code)
end

function OnlineJoinCodeDialog:AnimateIn()
	local x, y = self.dialog_container:GetPosition()
	self:ScaleTo(0.8, 1, 0.15, easing.outQuad)
		:SetPosition(x, y - 60)
		:MoveTo(x, y, 0.25, easing.outQuad)
	self.glow:SetMultColorAlpha(0)
		:AlphaTo(0.25, 0.4, easing.outQuad)
	return self
end

return OnlineJoinCodeDialog
