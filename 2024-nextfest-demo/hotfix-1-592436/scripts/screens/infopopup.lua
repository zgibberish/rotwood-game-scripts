local Screen = require("widgets/screen")
local ActionButton = require("widgets/actionbutton")
local Text = require("widgets/text")
local Image = require("widgets/image")
local Widget = require("widgets/widget")

local PopupDialog = require("screens/dialogs/popupdialog")

local easing = require "util.easing"

local DIALOG_WIDTH = 556
local DIALOG_HEIGHT = 220
local DIALOG_PADDING = 40
local GLOW_PADDING = 200
local VERTICAL_TEXT_FUDGE_FACTOR = 8

-- TODO(ui): Use a common BubbleDialog base class extracted from ConfirmDialog.
-- It handles anchor and arrow placement better.
local InfoPopUp = Class(PopupDialog, function(self, controller, position, blocksScreen, title, dialogText, widthHeightTable)
	PopupDialog._ctor(self, "InfoPopUp", controller, blocksScreen)
	self.controller = controller

	self.root = self:AddChild(Widget())

	self.width = widthHeightTable and widthHeightTable.width or DIALOG_WIDTH
	self.height = widthHeightTable and widthHeightTable.height or DIALOG_HEIGHT

	self.chatDialogGlow = self.root:AddChild(Image("images/ui_ftf/gradient_circle.tex"))
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARKER)
	self.chatDialogBG = self.root:AddChild(Image("images/ui_ftf_shop/shopkeep_dialog_bg.tex"))
		:ScaleToSize(self.width, self.height)
		:SetMultColor(UICOLORS.BLACK)
	self.chatDialogArrow = self.root:AddChild(Image("images/ui_ftf_shop/shopkeep_dialog_arrow.tex"))
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.BLACK)
		:ScaleToSize(60, 30)
		:LayoutBounds("center", "below", self.chatDialogBG)
		:Offset(0, 5)

	self.dialogTextContainer = self.root:AddChild(Widget())
	self.dialogTitle = self.dialogTextContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_TITLE))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetHAlign(ANCHOR_LEFT)
		:SetAutoSize(self.width - DIALOG_PADDING * 2)
		:SetText(title)
		:SetShown(title)

	self.dialogText = self.dialogTextContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetHAlign(ANCHOR_LEFT)
		:SetAutoSize(self.width - DIALOG_PADDING * 2)
		:SetText(dialogText)
		:SetShown(dialogText)

	self.buttonsContainer = self.dialogTextContainer:AddChild(Widget("Buttons"))
	self.okButton = self.buttonsContainer:AddChild(ActionButton())
		:SetSize(BUTTON_W * 0.8, BUTTON_H)
		:SetPrimary()
		:SetText(STRINGS.UI.BUTTONS.OK)
		:SetOnClick(function()
			if onDoneFn then onDoneFn(true) end
			if self.controller then self.controller:NextDialog() end
		end)

	self.position = position
	self:_LayoutDialog()

	self.default_focus = self.okButton

	return self.root
end)

function InfoPopUp:_LayoutDialog()

	-- Calculate buttons width
	local buttonsWidth, buttonsHeight = self.buttonsContainer:GetSize()

	-- Resize text to match button width
	local textWidth = math.max(buttonsWidth, self.width - DIALOG_PADDING * 2)
	self.dialogTitle:SetAutoSize(textWidth)
	self.dialogText:SetAutoSize(textWidth)

	-- Position text contents on top of each other
	self.dialogTextContainer:LayoutChildrenInGrid(1, 5)
	self.buttonsContainer:LayoutBounds("center", "below", self.dialogTextContainer) -- Move buttons down

	-- Resize bubble to text contents
	local contentWidth, contentHeight = self.dialogTextContainer:GetSize()
	contentHeight = contentHeight - VERTICAL_TEXT_FUDGE_FACTOR
	self.chatDialogBG:ScaleToSize(contentWidth + DIALOG_PADDING * 2, contentHeight + DIALOG_PADDING * 2)
	self.chatDialogGlow:ScaleToSize(contentWidth + GLOW_PADDING * 2, contentHeight + GLOW_PADDING * 2)
	self.chatDialogArrow:LayoutBounds("center", "below", self.chatDialogBG)
		:Offset(0, 5)
	self.dialogTextContainer:LayoutBounds("left", "top", self.chatDialogBG)
		:Offset(DIALOG_PADDING, -DIALOG_PADDING + VERTICAL_TEXT_FUDGE_FACTOR)

	-- Position the whole bubble
	if self.position then
		self.root:LayoutBounds("center", "above", self.position.x, self.position.y + 35) -- The 30 is because of the arrow height
	end

	return self
end

function InfoPopUp:SetOnDoneFn(onDoneFn)
	self.okButton:SetOnClick(function()
		if onDoneFn then onDoneFn(true) end
		if self.controller then self.controller:NextDialog() end
	end)
	return self
end

function InfoPopUp:GetRootWidget()
	return self.root
end

-- Flips the arrow so it points up
function InfoPopUp:SetArrowUp()
	self.chatDialogArrow:LayoutBounds("center", "above", self.chatDialogBG)
		:Offset(0, -5)
		:SetScale(1, -1)
	return self
end

function InfoPopUp:SetArrowXOffset(offset)
	self.chatDialogArrow:Offset(offset, 0)
	return self
end

function InfoPopUp:SetButtonText(text)
	self.okButton:SetText(text)
		:SetShown(text)

	self:_LayoutDialog()
	return self
end

function InfoPopUp:OnBecomeActive()
	InfoPopUp._base.OnBecomeActive(self)

	-- Animate popup in if we're using a controller, meaning this is a conversation dialog sequence
	-- If not, it means this popup was created not using a controller
	if self.controller then
		self:AnimateIn()
	end
end

function InfoPopUp:AnimateIn()
	local x, y = self.root:GetPosition()
	self.root:ScaleTo(0.8, 1, 0.15, easing.outQuad)
		:SetPosition(x, y - 30)
		:MoveTo(x, y, 0.25, easing.outQuad)
	self.chatDialogGlow:SetMultColorAlpha(0)
		:AlphaTo(0.25, 0.4, easing.outQuad)

	self.default_focus:SetFocus()
	return self
end

return InfoPopUp
