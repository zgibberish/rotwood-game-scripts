local Widget = require("widgets/widget")
local Text = require("widgets/text")

--- Displays a hotkey button and the action description after it.
-- Place attached to on-screen buttons.
local HotkeyWidget = Class(Widget, function(self, control, text)
	Widget._ctor(self, "HotkeyWidget")

	self.control = control

	-- Icon
	self.action_icon = self:AddChild(Text(FONTFACE.DEFAULT, 22 * HACK_FOR_4K))
		:SetName("Hotkey name (icon)")

	-- Text label
	self.action_label = self:AddChild(Text(FONTFACE.DEFAULT, 22 * HACK_FOR_4K))
		:SetName("Action text (label)")
		:SetText(text)

	self._ondevicechange_fn = function(old_device_type, device_type)
		if self.locked_player then
			device_type = self.locked_player.components.playercontroller:GetLastInputDeviceType()
		end
		self:RefreshHotkeyIcon(device_type)
	end
	TheInput:RegisterForDeviceChanges(self._ondevicechange_fn)
	self:RefreshHotkeyIcon(TheInput.last_input.device_type)
end)

function HotkeyWidget:OnRemoved()
	TheInput:UnregisterForDeviceChanges(self._ondevicechange_fn)
end

function HotkeyWidget:SetIconSize(size)
	self.action_icon:SetFontSize(size)
	return self
end

function HotkeyWidget:SetIconMultColor(c)
	self.action_icon:SetMultColor(c)
	return self
end

function HotkeyWidget:SetTextMultColor(c)
	self.action_label:SetMultColor(c)
	return self
end

function HotkeyWidget:LockToPlayer(player)
	self.locked_player = player
	return self
end

function HotkeyWidget:SetOnlyShowForGamepad()
	self.only_show_for_gamepad = true
	self:RefreshHotkeyIcon(TheInput.last_input.device_type)
	return self
end

function HotkeyWidget:RefreshHotkeyIcon(device_type)
	if not self.only_show_for_gamepad
		or device_type == "gamepad"
	then
		self.action_icon:SetText(TheInput:GetLabelForControl(self.control))
	else
		self.action_icon:SetText("")
	end
	self:_Layout()
end

function HotkeyWidget:SetOnLayoutFn(fn)
	self.on_layout_fn = fn
	self:_Layout()
	return self
end

local function Layout_TextAbove(self)
	self.action_label:LayoutBounds("center", "above", self.action_icon)
		:Offset(0, 10)
end

function HotkeyWidget:SetLayout_TextAbove()
	self.action_label:SetFontSize(35 * HACK_FOR_4K)
	self.action_icon:SetFontSize(55 * HACK_FOR_4K)
	return self:SetOnLayoutFn(Layout_TextAbove)
end

function HotkeyWidget:_Layout()
	self.action_icon:LayoutBounds("center", "center", 0, 0)
	self.action_label:LayoutBounds("after", "center", self.action_icon)
		:Offset(5, 0)
	if self.on_layout_fn then self.on_layout_fn(self) end
	return self
end

return HotkeyWidget
