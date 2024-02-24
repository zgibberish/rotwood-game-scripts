local ActionButton = require("widgets/actionbutton")
local Text = require("widgets/text")
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local Panel = require("widgets/panel")
local Widget = require("widgets/widget")
local PopupDialog = require("screens/dialogs/popupdialog")
local Controls = require "input.controls"
local easing = require "util.easing"


local DIALOG_WIDTH = 1112
local DIALOG_HEIGHT = 440
local DIALOG_PADDING_H = 100
local DIALOG_PADDING_V = 80
local GLOW_PADDING = 400
local VERTICAL_TEXT_FUDGE_FACTOR = 16

-- TODO(ui): Extract a common BubbleDialog base class.

---
-- Shows a dialog, with three text levels, all optional (title, subtitle, text), and up to three buttons (ok, no, cancel)
--
-- anchor_widget is the anchor that we position the bubble around (usually a
-- button). It automatically adjusts to the target's size.
-- Use SetAnchorOffset to adjust it.
--
local ConfirmDialog = Class(PopupDialog, function(self, controller, anchor_widget, blocksScreen, title, subtitle, dialogText, onDoneFn, onOpenFn)
	PopupDialog._ctor(self, "ConfirmDialog", controller, blocksScreen)
	self.controller = controller
	self.anchor_widget = anchor_widget

	self:SetCallbackActionLabels(true, false, -1)
	self.root = self:AddChild(Widget())
	self.min_width = 100

	self.chatDialogGlow = self.root:AddChild(Image("images/ui_ftf/gradient_circle.tex"))
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARKER)
	self.chatDialogBG = self.root:AddChild(Panel("images/ui_ftf/dialog_bg.tex"))
		:SetName("Chat dialog bg")
		:SetNineSliceCoords(50, 28, 550, 239)
		:SetSize(DIALOG_WIDTH, DIALOG_HEIGHT)
	self._chat_dialog_arrow_x_offset = 0
	self.chatDialogArrow = self.root:AddChild(Image("images/ui_ftf/dialog_arrow.tex"))
		:SetHiddenBoundingBox(true)

	self.dialogTextContainer = self.root:AddChild(Widget())
	self.dialogTitle = self.dialogTextContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_TITLE))
		:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
		:SetHAlign(ANCHOR_LEFT)
		:SetAutoSize(DIALOG_WIDTH - DIALOG_PADDING_H * 2)
		:SetText(title)
		:SetShown(title)
	self.dialogSubtitle = self.dialogTextContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_SUBTITLE))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetHAlign(ANCHOR_LEFT)
		:SetAutoSize(DIALOG_WIDTH - DIALOG_PADDING_H * 2)
		:SetText(subtitle)
		:SetShown(subtitle)
	self.dialogText = self.dialogTextContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetHAlign(ANCHOR_LEFT)
		:SetAutoSize(DIALOG_WIDTH - DIALOG_PADDING_H * 2)
		:SetText(dialogText)
		:SetShown(dialogText)

	self.buttonsContainerTop = self.dialogTextContainer:AddChild(Widget("Buttons Top"))
	self.yesButton = self.buttonsContainerTop:AddChild(ActionButton())
		:SetSize(BUTTON_W * 0.8, BUTTON_H)
		:SetPrimary()
		:SetScaleOnFocus(false)
		:SetText(STRINGS.UI.BUTTONS.OK)
		:SetOnClick(function()
			if onDoneFn then onDoneFn(true) end
			if self.controller then self.controller:NextDialog() end
		end)
	self.noButton = self.buttonsContainerTop:AddChild(ActionButton())
		:SetSize(BUTTON_W * 0.8, BUTTON_H)
		:SetSecondary()
		:SetFlipped()
		:SetScaleOnFocus(false)
		:SetText(STRINGS.UI.BUTTONS.NO)
		:SetControlUpSound(nil)
		:SetOnClick(function()
			if onDoneFn then onDoneFn(false) end
			if self.controller then self.controller:NextDialog() end
		end)

	self.buttonsContainerBottom = self.dialogTextContainer:AddChild(Widget("Buttons Bottom"))
	self.cancelButton = self.buttonsContainerBottom:AddChild(ActionButton())
		:SetSize(BUTTON_W * 0.8, BUTTON_H)
		:SetSecondary()
		:SetScaleOnFocus(false)
		:SetText(STRINGS.UI.BUTTONS.CANCEL)
		:SetOnClick(function()
			if onDoneFn then onDoneFn(-1) end
			if self.controller then self.controller:NextDialog() end
		end)
		:Hide()

	self.close_button = self.root:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetName("Close button")
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		:SetOnClick(function()
			if onDoneFn then onDoneFn(-1) end
			if self.controller then self.controller:NextDialog() end
		end)
		:Hide()

	self.onOpenFn = onOpenFn

	-- Don't bother with layout here because we do it OnOpen.
	-- self:_LayoutDialog()

	self.default_focus = self.yesButton

	return self.root
end)

ConfirmDialog.CONTROL_MAP =
{
	{
		control = Controls.Digital.CANCEL,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.CANCEL", Controls.Digital.CANCEL))
		end,
		fn = function(self)
			if self.cancelButton:IsShown() then
				self.cancelButton:Click()
			elseif self.close_button:IsShown() then
				self.close_button:Click()
			elseif self.noButton:IsShown() then
				self.noButton:Click()
			end
			return true
		end,
	}
}

function ConfirmDialog:SetTitle(text)
	self.dialogTitle:SetText(text)
		:SetShown(text)
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:SetSubtitle(text)
	self.dialogSubtitle:SetText(text)
		:SetShown(text)
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:SetText(text)
	self.dialogText:SetText(text)
		:SetShown(text)
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:SetMinWidth(min_width)
	self.min_width = min_width
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:AddButton(text, fn)
	self.buttonsContainerTop:AddChild(ActionButton())
		:SetSize(BUTTON_W * 0.8, BUTTON_H)
		:SetSecondary()
		:SetScaleOnFocus(false)
		:SetText(text)
		:SetOnClick(function()
			if fn then fn(true) end
			if self.controller then self.controller:NextDialog() end
		end)
		:SetShown(text)

	-- Move cancel button behind any added ones
	self.cancelButton:SendToFront()

	self:_LayoutDialog()
	return self
end

function ConfirmDialog:SetYesButton(text, fn)
	self.yesButton:SetText(text)
		:SetOnClick(function()
			if fn then fn(true) end
			if self.controller then self.controller:NextDialog() end
		end)
		:SetShown(text)
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:SetYesTooltip(txt)
	self.yesButton:SetToolTip(txt)
	return self
end

function ConfirmDialog:SetNoTooltip(txt)
	self.noButton:SetToolTip(txt)
	return self
end

function ConfirmDialog:SetNoButton(text, fn)
	self.noButton:SetText(text)
		:SetOnClick(function()
			if fn then fn(false) end
			if self.controller then self.controller:NextDialog() end
		end)
		:SetShown(text)
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:MoveCancelButtonToTop()
	self.cancelButton:Reparent(self.buttonsContainerTop)
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:SetCancelButton(text, fn)
	self.cancelButton:SetText(text)
		:SetOnClick(function()
			if fn then fn(-1) end
			if self.controller then self.controller:NextDialog() end
		end)
		:SetShown(text)
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:GetCancelButton()
	return self.cancelButton
end

function ConfirmDialog:SetCloseButton(fn)
	self.close_button:SetOnClick(function()
			if fn then fn(-1) end
			if self.controller then self.controller:NextDialog() end
		end)
		:Show()
	return self
end

function ConfirmDialog:HideYesButton()
	self.yesButton:Hide()
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:SetYesButtonEnabled(enabled)
	self.yesButton:SetEnabled(enabled)
	return self
end

function ConfirmDialog:HideNoButton()
	self.noButton:Hide()
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:CenterText()
	self.centerText = true
	self.dialogTitle:SetHAlign(ANCHOR_MIDDLE)
	self.dialogSubtitle:SetHAlign(ANCHOR_MIDDLE)
	self.dialogText:SetHAlign(ANCHOR_MIDDLE)
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:CenterButtons()
	self.centerButtons = true
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:HideButtons()
	self.buttonsContainerTop:Hide()
	self.buttonsContainerBottom:Hide()
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:SetWideButtons()
	for _,btn in ipairs(self.buttonsContainerTop:GetChildren()) do
		btn:SetSize(BUTTON_W, BUTTON_H)
	end
	for _,btn in ipairs(self.buttonsContainerBottom:GetChildren()) do
		btn:SetSize(BUTTON_W, BUTTON_H)
	end
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:SetSameYesNoAppearance()
	self.yesButton:SetPrimary()
	self.noButton:SetPrimary()
	self.noButton:SetFlipped()
end

function ConfirmDialog:_LayoutDialog()

	-- Calculate buttons width
	self.buttonsContainerTop:LayoutChildrenInGrid(100, 30)
	local buttonsWidth = self.buttonsContainerTop:IsShown() and self.buttonsContainerTop:GetSize() or 0

	-- Resize text to match button width
	local textWidth = math.max(buttonsWidth, DIALOG_WIDTH - DIALOG_PADDING_H * 2)
	self.dialogTitle:SetAutoSize(textWidth)
	self.dialogSubtitle:SetAutoSize(textWidth)
	self.dialogText:SetAutoSize(textWidth)

	-- Position text contents on top of each other
	self.dialogTextContainer:LayoutChildrenInColumn(10, self.centerText and "center" or "left")
	self.dialogSubtitle:Offset(0, 16) -- Move subtitle up
	self.buttonsContainerTop:Offset(0, -30) -- Move buttons down

	-- Resize bubble to text contents
	local contentWidth, contentHeight = self.dialogTextContainer:GetSize()
	contentWidth = math.max(self.min_width, contentWidth)
	contentHeight = contentHeight - VERTICAL_TEXT_FUDGE_FACTOR
	self.chatDialogBG:SetSize(contentWidth + DIALOG_PADDING_H * 2, contentHeight + DIALOG_PADDING_V * 2)
	self.chatDialogGlow:ScaleToSize(contentWidth + GLOW_PADDING * 2, contentHeight + GLOW_PADDING * 2)
	self:_LayoutArrow()
	self.dialogTextContainer:LayoutBounds(self.centerText and "center" or "left", "top", self.chatDialogBG)
		:Offset(self.centerText and 0 or DIALOG_PADDING_H, -DIALOG_PADDING_V + VERTICAL_TEXT_FUDGE_FACTOR)
	if self.centerButtons then
		self.buttonsContainerTop:LayoutBounds("center", nil, self.chatDialogBG)
		self.buttonsContainerBottom:LayoutBounds("center", nil, self.chatDialogBG)
	end

	self.buttonsContainerBottom:LayoutBounds("center", "below", self.buttonsContainerTop)

	local topButtonsShown = false
	for i,button in ipairs(self.buttonsContainerTop.children) do
		if button:IsShown() then
			topButtonsShown = true
			break
		end
	end
	if topButtonsShown then
		self.buttonsContainerBottom:Offset(0, -30) -- Move buttons down
	end
	-- Position close button
	self.close_button:LayoutBounds("right", "top", self.chatDialogBG)
		:Offset(-40, 20)

	-- Position the whole bubble
	if self.position then
		self.root:LayoutBounds("center", "above", self.position.x, self.position.y)
	end

	return self
end

-- TODO(dbriscoe): Use SetCallbackActionLabels everywhere and remove initial argument to onDoneFn.
function ConfirmDialog:SetCallbackActionLabels(yes, no, cancel)
	self.cb_action_label = {
		yes = yes,
		no = no,
		cancel = cancel,
	}
end

function ConfirmDialog:SetOnDoneFn(onDoneFn)
	self.yesButton:SetOnClick(function()
		if onDoneFn then onDoneFn(true, self.cb_action_label.yes) end
		if self.controller then self.controller:NextDialog() end
	end)
	self.noButton:SetOnClick(function()
		if onDoneFn then onDoneFn(false, self.cb_action_label.no) end
		if self.controller then self.controller:NextDialog() end
	end)
	self.cancelButton:SetOnClick(function()
		if onDoneFn then onDoneFn(-1, self.cb_action_label.cancel) end
		if self.controller then self.controller:NextDialog() end
	end)
	return self
end

-- Try passing anchor_widget and using SetAnchorOffset instead!
function ConfirmDialog:GetRootWidget()
	return self.root
end

function ConfirmDialog:HideArrow()
	self.chatDialogArrow:Hide()
	return self
end

-- Flips the arrow so it points up
function ConfirmDialog:SetArrowUp()
	self.is_below_target = true
	self:_LayoutArrow()
	return self
end

function ConfirmDialog:SetArrowXOffset(offset)
	self._chat_dialog_arrow_x_offset = offset
	self.chatDialogArrow:Offset(offset, 0)
	return self
end

function ConfirmDialog:_LayoutArrow()
	local direction = 1
	local arrow_v_reg = "below"
	if self.is_below_target then
		direction = -1
		arrow_v_reg = "above"
	end
	self.chatDialogArrow
		:SetScale(1, 1)
		:LayoutBounds("center", arrow_v_reg, self.chatDialogBG)
		:Offset(self._chat_dialog_arrow_x_offset, 25 * direction)

	if self.is_below_target then
		-- Undid scale above to simplify layout math.
		self.chatDialogArrow:SetScale(1, -1)
	end
	return self
end

-- Widget-space offset from the anchor widget's position (like :Offset() but
-- for the balloon instead of the whole screen).
function ConfirmDialog:SetAnchorOffset(dx, dy)
	self.anchor_offset = Vector2(dx, dy)
	self:_LayoutDialog()
	return self
end

function ConfirmDialog:SetYesButtonText(text)
	self.yesButton:SetText(text)
		:SetShown(text)

	self:_LayoutDialog()
	return self
end

function ConfirmDialog:SetNoButtonText(text)
	self.noButton:SetText(text)
		:SetShown(text)

	self:_LayoutDialog()
	return self
end

function ConfirmDialog:SetCancelButtonText(text)
	self.cancelButton:SetText(text)
		:SetShown(text)

	self:_LayoutDialog()
	return self
end

function ConfirmDialog:OnOpen()
	ConfirmDialog._base.OnOpen(self)
	if self.anchor_widget then
		-- Deferred this positioning until now because we need a parent to
		-- translate world position into widget space.
		local _,h = self.anchor_widget:GetSize()
		local direction = self.is_below_target and -1 or 1
		local arrow_height = 70
		local offset = self.anchor_offset or Vector2.zero:clone()
		offset = offset + Vector2.unit_y:scale((arrow_height + h/2) * direction)
		if self.is_below_target then
			_,h = self.root:GetSize()
			offset.y = offset.y - h -- move bubble above
		end
		self:SetArrowXOffset(self._chat_dialog_arrow_x_offset - offset.x) -- additive to respect existing offset
		self.position = Vector2(self:TransformFromWorld(self.anchor_widget:GetWorldPosition():unpack())) + offset
		self.anchor_widget = nil
		self:_LayoutDialog()
	end

	----------------------------------------------------------------------
	-- Focus selection brackets
	if self.yesButton:IsVisible()
		or self.noButton:IsVisible()
		or self.cancelButton:IsVisible()
	then
		self:EnableFocusBracketsForGamepad()
		-- self:EnableFocusBracketsForGamepadAndMouse()
	end
	-- else: Probably shouldn't use ConfirmDialog, but we do...
	----------------------------------------------------------------------

	if self.onOpenFn ~= nil then
		self.onOpenFn()
	end
end

function ConfirmDialog:OnBecomeActive()
	ConfirmDialog._base.OnBecomeActive(self)

	-- Animate popup in if we're using a controller, meaning this is a conversation dialog sequence
	-- If not, it means this popup was created not using a controller
	if self.controller then
		self:AnimateIn()
	end
end

function ConfirmDialog:Close()
	TheFrontEnd:PopScreen(self)
	return self
end

function ConfirmDialog:AnimateIn()
	local x, y = self.root:GetPosition()
	self.root:ScaleTo(0.8, 1, 0.15, easing.outQuad)
		:SetPosition(x, y - 60)
		:MoveTo(x, y, 0.25, easing.outQuad)
	self.chatDialogGlow:SetMultColorAlpha(0)
		:AlphaTo(0.25, 0.4, easing.outQuad)
	return self
end

return ConfirmDialog
