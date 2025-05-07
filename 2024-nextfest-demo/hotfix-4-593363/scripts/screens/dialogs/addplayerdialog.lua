local Controls = require "input.controls"
local Image = require "widgets.image"
local ImageButton = require "widgets.imagebutton"
local PopupDialog = require "screens.dialogs.popupdialog"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local easing = require "util.easing"


----------------------------------------------------------------------
-- A dialog that asks a player to press any key on their controller

local AddPlayerDialog = Class(PopupDialog, function(self, success_cb)
	PopupDialog._ctor(self, "AddPlayerDialog")

	assert(success_cb)
	self.success_cb = success_cb
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
		:SetText(STRINGS.UI.ADDPLAYERDIALOG.TITLE)
	self.dialog_text = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_SUBTITLE*0.9))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(self.max_text_width)
		:SetText(STRINGS.UI.ADDPLAYERDIALOG.SUBTITLE)

	-- Contains an animated gamepad icon below the text
	self.icon_container = self.text_container:AddChild(Widget())
		:SetName("Icon container")
	self.icon_hitbox = self.icon_container:AddChild(Image("images/global/square.tex"))
		:SetName("Hitbox")
		:SetSize(300, 300)
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0)
	-- A wiggling gamepad image to hint the player should get a gamepad.
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
		:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(self.max_text_width)
		:SetText(STRINGS.UI.ADDPLAYERDIALOG.CONFIRM_HINT)
		:Hide()

	self.cancel_text = self.actions_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.CONFIRM_DIALOG_SUBTITLE*0.9))
		:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(self.max_text_width)
		:SetText(STRINGS.UI.ADDPLAYERDIALOG.CANCEL_HINT)
		:Hide()

	self:_LayoutDialog()

	self.default_focus = self.glow

end)

AddPlayerDialog.CONTROL_MAP = {
	{
		control = Controls.Digital.CANCEL,
		fn = function(self)
			self.close_button:Click()
			return true
		end,
	},
}

function AddPlayerDialog:HandleControlDown(controls, device_type, trace, device_id)
	device_id = device_id or 0 -- keyboard is 0
	if self.selected_device
		and self.selected_device.device_type == device_type
		and self.selected_device.device_id == device_id
	then
		-- Handle accept control here instead of CONTROL_MAP to make the
		-- ordering clear. We want to require two inputs on the device: one to
		-- activate and one to confirm.
		if controls:Has(Controls.Digital.MENU_ACCEPT) then
			local inputID = TheInput:ConvertToInputID(self.selected_device.device_type, self.selected_device.device_id)
			net_addplayer(inputID)
			self:OnClickClose(true)
			return true
		end
	end

	local tex = TheInput:GetTexForDevice(device_type, device_id)

	self.selected_device = nil
	if device_type == "mouse" then
		-- The mouse was used which is not enough info to select a device. Hide
		-- selected gamepad.
		self.generic_gamepad_icon:Show()
		self.selected_device_icon:Hide()
		self.confirm_text:Hide()
		self.cancel_text:Hide()

	else
		self.selected_device_icon:SetTexture(tex)
		self.generic_gamepad_icon:Hide()
		self.selected_device_icon:Show()
		self.confirm_text:SetText(STRINGS.UI.ADDPLAYERDIALOG.CONFIRM_HINT)
		self.confirm_text:Show()
		self.cancel_text:Show()
		local existing_player = TheInput:GetDeviceOwner(device_type, device_id)
		if existing_player then
			self.confirm_text:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		else
			self.confirm_text:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
			-- It's available to a new player.
			self.selected_device = {
				device_type = device_type,
				device_id = device_id,
			}
		end
	end

	self:_RefreshButtonIcons()

	-- Delay one frame so input/text system recognizes the new input device.
	-- Use Updater instead of DoTaskInTicks so it works during pause.
	self:RunUpdater(
		Updater.Series{
			Updater.Wait(0),
			Updater.Do(function()
				self:_RefreshButtonIcons()
			end)
		}
	)
end

function AddPlayerDialog:_RefreshButtonIcons()
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

function AddPlayerDialog:OnClickClose(created_new_player)
	TheFrontEnd:PopScreen(self)
	if created_new_player then
		self.success_cb()
	end
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
