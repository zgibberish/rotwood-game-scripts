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
-- A dialog that displays a new input device that was just triggered,
-- and asks the player if they want to switch to using it, or add another
-- player to the game

local ChangeInputDialog = Class(PopupDialog, function(self, title, subtitle)
	PopupDialog._ctor(self, "ChangeInputDialog", nil, false)

	self.max_text_width = 1300

	self.dialog_container = self:AddChild(Widget())
		:SetName("Dialog container")

	self.glow = self.dialog_container:AddChild(Image("images/ui_ftf/gradient_circle.tex"))
		:SetName("Glow")
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARKER)

	self.bg = self.dialog_container:AddChild(Image("images/bg_popup_small/popup_small.tex"))
		:SetName("Background")
		:SetSize(1600 * 0.9, 900 * 0.9)

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
		:SetText(title)
	self.dialog_text = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_SUBTITLE*0.9))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(self.max_text_width)
		:SetText(subtitle)

    self.actions_container = self.text_container:AddChild(Widget())
		:SetName("Actions container")
	self.add_player_btn = self.actions_container:AddChild(ActionButton())
		:SetSize(BUTTON_W * 1.5, BUTTON_H*0.9)
		:SetNormalScale(0.9)
		:SetFocusScale(0.95)
		:SetScale(0.9)
		:SetPrimary()
		:SetTextAndResizeToFit(STRINGS.UI.PRESSED_START_IN_SINGLE_PLAYER.BTN_ADD_PLAYER, 60)
	self.change_input_btn = self.actions_container:AddChild(ActionButton())
		:SetSize(BUTTON_W * 1.4, BUTTON_H*0.9)
		:SetNormalScale(0.9)
		:SetFocusScale(0.95)
		:SetScale(0.9)
		:SetSecondary()
		:SetTextAndResizeToFit(STRINGS.UI.PRESSED_START_IN_SINGLE_PLAYER.BTN_CHANGE_INPUT, 60)

	self:_LayoutDialog()

	self.default_focus = self.add_player_btn

end)

ChangeInputDialog.CONTROL_MAP =
{
	{
		control = Controls.Digital.CANCEL,
		fn = function(self)
			self.close_button:Click()
			return true
		end,
	},
	-- {
	-- 	control = Controls.Digital.A,
	-- 	fn = function(self)
	-- 		if self.selected_gamepad then
	-- 			-- This player can be added
	-- 			net_addplayer(self.selected_gamepad)
	-- 			self.close_button:Click()
	-- 		end
	-- 		return true
	-- 	end,
	-- }
}

function ChangeInputDialog:SetOnAddPlayerClickFn(fn)
	self.add_player_btn:SetOnClick(fn)
	return self
end

function ChangeInputDialog:SetOnChangeInputClickFn(fn)
	self.change_input_btn:SetOnClick(fn)
	return self
end

function ChangeInputDialog:_LayoutDialog()

	local w, h = self.bg:GetSize()
	self.glow:SetSize(w + 500, h + 500)

	self.dialog_text:LayoutBounds("center", "below", self.dialog_title)
		:Offset(0, -10)
	self.actions_container:LayoutChildrenInColumn(20)
		:LayoutBounds("center", "below", self.dialog_text)
		:Offset(0, -70)

	self.text_container:LayoutBounds("center", "center", self.bg)
		:Offset(0, 20)

	return self
end

function ChangeInputDialog:OnOpen()
	ChangeInputDialog._base.OnOpen(self)
	self:AnimateIn()

	----------------------------------------------------------------------
	-- Focus selection brackets
	self:EnableFocusBracketsForGamepad()
	-- self:EnableFocusBracketsForGamepadAndMouse()
	----------------------------------------------------------------------
end

function ChangeInputDialog:OnBecomeActive()
	ChangeInputDialog._base.OnBecomeActive(self)
end

function ChangeInputDialog:OnClickClose()
	TheFrontEnd:PopScreen(self)
	return self
end

function ChangeInputDialog:AnimateIn()
	local x, y = self.dialog_container:GetPosition()
	self:ScaleTo(0.8, 1, 0.15, easing.outQuad)
		:SetPosition(x, y - 60)
		:MoveTo(x, y, 0.25, easing.outQuad)
	self.glow:SetMultColorAlpha(0)
		:AlphaTo(0.25, 0.4, easing.outQuad)
	return self
end

return ChangeInputDialog
