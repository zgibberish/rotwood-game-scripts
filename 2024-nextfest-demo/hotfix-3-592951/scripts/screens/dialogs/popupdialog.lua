local Image = require("widgets/image")
local ImageButton = require "widgets.imagebutton"
local Screen = require("widgets/screen")

local PopupDialog = Class(Screen, function(self, id, controller, blocksScreen)
	local widgetId = id ~= nil and id or "PopupDialog"
	Screen._ctor(self, widgetId)
	self:SetAudioCategory(Screen.AudioCategory.s.Popup)

	self.controller = controller
	self.blocksScreen = blocksScreen == nil and true or blocksScreen
	-- TODO(dbriscoe): blocksScreen should proably set is_overlay

	-- Background fade out everything
	if self.blocksScreen then
		self:Configure_BlockScreen()
	end
end)

function PopupDialog:Configure_BlockScreen()
	-- TODO(ui): Rename this to screen_blocker.
	self.bg = self:AddChild(Image("images/global/square.tex"))
		:SetScale(100)
		:SetMultColor(0, 0, 0, 0.5)
end

PopupDialog.BG = {
	small = "images/bg_popup_small/popup_small.tex",
	flat = "images/bg_popup_flat/popup_flat.tex",
}

function PopupDialog:AddBackground(popup_bg)
	popup_bg = popup_bg or PopupDialog.BG.small

	self.glow = self:AddChild(Image("images/ui_ftf/gradient_circle.tex"))
		:SetName("Glow")
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARKER)

	self.bg = self:AddChild(Image(popup_bg))
		:SetName("Background")
		:SetSize(1600 * 0.9, 900 * 0.9)

	return self
end

function PopupDialog:AddCloseButton(close_cb)
	assert(close_cb or self.ClosePopup)
	self.close_button = self:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:SetOnClick(close_cb or function() self:ClosePopup() end)
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		:LayoutBounds("right", "top", self.bg)
		:Offset(-40, 0)

	return self
end

return PopupDialog
