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
-- A dialog that asks a player to press any key on their controller

local AddPlayerDialog = Class(PopupDialog, function(self, device_type, device_id)
	PopupDialog._ctor(self, "AddPlayerDialog")

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
		:SetText(STRINGS.UI.ADPLAYERDIALOG.TITLE)
	self.dialog_text = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_SUBTITLE*0.9))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(self.max_text_width)
		:SetText(STRINGS.UI.ADPLAYERDIALOG.SUBTITLE)

	-- Contains an animated gamepad icon below the text
	self.icon_container = self.text_container:AddChild(Widget())
		:SetName("Icon container")
	self.icon_hitbox = self.icon_container:AddChild(Image("images/global/square.tex"))
		:SetName("Hitbox")
		:SetSize(300, 300)
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0)
	self.generic_gamepad_icon = self.icon_container:AddChild(Image("images/ui_ftf/input_gamepad.tex"))
		:SetName("Generic gamepad icon")
		:SetHiddenBoundingBox(true)
		:SetSize(290, 290)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
	self.selected_device_icon = self.icon_container:AddChild(Image("images/ui_ftf/input_1.tex"))
		:SetName("Selected gamepad icon")
		:SetHiddenBoundingBox(true)
		:SetSize(290, 290)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:Hide()

    self.generic_gamepad_icon:RunUpdater(Updater.Series{ -- Animate the icon
        Updater.Wait(math.random() * 0.5 + 0.1),
        Updater.Loop{
            Updater.Ease(function(deg)
				self.generic_gamepad_icon:SetRotation(deg)
				self.selected_device_icon:SetRotation(deg)
            end, 0, 10, 1.25, easing.inElastic),
            Updater.Ease(function(deg)
				self.generic_gamepad_icon:SetRotation(deg)
				self.selected_device_icon:SetRotation(deg)
            end, 10, 0, 1.25, easing.outElastic),
        }
    })


    self.actions_container = self.dialog_container:AddChild(Widget())
		:SetName("Actions container")
	self.confirm_text = self.actions_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_SUBTITLE*0.9))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(self.max_text_width)
		:SetText(STRINGS.UI.ADPLAYERDIALOG.CONFIRM_HINT_KEYBOARD)
		:SetText(STRINGS.UI.ADPLAYERDIALOG.CONFIRM_HINT)
		:Hide()

	self.cancel_text = self.actions_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_SUBTITLE*0.9))
		:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(self.max_text_width)
		:SetText(STRINGS.UI.ADPLAYERDIALOG.CANCEL_HINT)
		:Hide()

	self:_LayoutDialog()

	self.default_focus = self.glow

end)

AddPlayerDialog.CONTROL_MAP =
{
	{
		control = Controls.Digital.CANCEL,
		fn = function(self)
			self.close_button:Click()
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_ACCEPT,
		fn = function(self)
			if self.selected_device == 0 then
				-- This player can be added
				net_addplayer(self.selected_device)
				self.close_button:Click()
			end
			return true
		end,
	},
	{
		control = Controls.Digital.A,
		fn = function(self)
			if self.selected_device then
				-- This player can be added
				net_addplayer(self.selected_device)
				self.close_button:Click()
			end
			return true
		end,
	}
}

function AddPlayerDialog:OnControl(controls, down, device_type, trace, device_id)

	if device_type == "mouse" then
		-- The mouse was used, hide selected gamepad
		self.generic_gamepad_icon:Show()
		self.selected_device_icon:Hide()
		self.selected_device = nil
		self.confirm_text:Hide()
		self.cancel_text:Hide()
	elseif down
	and device_type == "keyboard" then
		-- The keyboard was used. Check if it's available to a new player
		local player = TheInput:GetDeviceOwner("keyboard", device_id)
		if not player then
			self.selected_device = 0
			-- Show correct icon
			self.selected_device_icon:SetTexture("images/ui_ftf/input_kbm.tex")
			self.generic_gamepad_icon:Hide()
			self.selected_device_icon:Show()
			self.confirm_text:SetText(STRINGS.UI.ADPLAYERDIALOG.CONFIRM_HINT_KEYBOARD)
			self.confirm_text:Show()
			self.cancel_text:Show()
		end
	elseif down
	and device_type == "gamepad" then
		-- A gamepad button was used. Check if it's available to a new player
		local player = TheInput:GetDeviceOwner(device_type, device_id)
		if not player then
			self.selected_device = device_id
			-- Show correct icon
			if device_id == 1 then
				self.selected_device_icon:SetTexture("images/ui_ftf/input_1.tex")
			elseif device_id == 2 then
				self.selected_device_icon:SetTexture("images/ui_ftf/input_2.tex")
			elseif device_id == 3 then
				self.selected_device_icon:SetTexture("images/ui_ftf/input_3.tex")
			elseif device_id == 4 then
				self.selected_device_icon:SetTexture("images/ui_ftf/input_4.tex")
			end
			self.generic_gamepad_icon:Hide()
			self.selected_device_icon:Show()
			self.confirm_text:SetText(STRINGS.UI.ADPLAYERDIALOG.CONFIRM_HINT)
			self.confirm_text:Show()
			self.cancel_text:Show()
		end
	end

	self.confirm_text:RefreshText()
	self.cancel_text:RefreshText()
	self:_LayoutDialog()
end

function AddPlayerDialog:_LayoutDialog()

	local w, h = self.bg:GetSize()
	self.glow:SetSize(w + 500, h + 500)

	self.dialog_text:LayoutBounds("center", "below", self.dialog_title)
		:Offset(0, -10)
	self.icon_container:LayoutBounds("center", "below", self.dialog_text)
		:Offset(0, 0)
	self.confirm_text:LayoutBounds("center", "below", self.icon_container)
		:Offset(0, 0)

	self.text_container:LayoutBounds("center", "center", self.bg)
		:Offset(0, 70)

	self.actions_container:LayoutChildrenInRow(40)
		:LayoutBounds("center", "bottom", self.bg)
		:Offset(0, 70)

	return self
end

function AddPlayerDialog:OnOpen()
	AddPlayerDialog._base.OnOpen(self)
	self:AnimateIn()
end

function AddPlayerDialog:OnBecomeActive()
	AddPlayerDialog._base.OnBecomeActive(self)
end

function AddPlayerDialog:OnClickClose()
	TheFrontEnd:PopScreen(self)
	return self
end

function AddPlayerDialog:OnClickJoin(device_type, device_id)

	return self
end

function AddPlayerDialog:AnimateIn()
	local x, y = self.dialog_container:GetPosition()
	self:ScaleTo(0.8, 1, 0.15, easing.outQuad)
		:SetPosition(x, y - 60)
		:MoveTo(x, y, 0.25, easing.outQuad)
	self.glow:SetMultColorAlpha(0)
		:AlphaTo(0.25, 0.4, easing.outQuad)
	return self
end

return AddPlayerDialog
