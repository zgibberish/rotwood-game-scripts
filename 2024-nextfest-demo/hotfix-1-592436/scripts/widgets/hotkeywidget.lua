local Text = require "widgets.text"
local Widget = require "widgets.widget"
local kassert = require "util.kassert"


--- Displays a hotkey button and the action description after it.
-- Place attached to on-screen buttons.
--
-- See HotkeyImage if you want more control over the display size and don't
-- want a label.
local HotkeyWidget = Class(Widget, function(self, control, text)
	Widget._ctor(self, "HotkeyWidget")

	-- Icon. See SetControl.
	self.action_icon = self:AddChild(Text(FONTFACE.DEFAULT, 22 * HACK_FOR_4K))
		:SetName("Hotkey name (icon)")

	-- Text label
	self.action_label = self:AddChild(Text(FONTFACE.DEFAULT, 22 * HACK_FOR_4K))
		:SetName("Action text (label)")
		:SetText(text)

	self:SetControl(control)

	self.dbg_add_stack = DEV_MODE and debug.traceback() or "<no callstack in prod>"
end)

function HotkeyWidget:OnAddedToScreen(screen)
	local owning_player = self:GetOwningPlayer()
	kassert.assert_fmt(owning_player, "HotkeyWidget requires SetOwningPlayer on itself, a parent, or the screen. Call SetOwningPlayer before HotkeyWidget is added to the screen tree. %s created at %s", self, self.dbg_add_stack)
	self:RefreshHotkeyIcon()
end

function HotkeyWidget:SetIconSize(size)
	self.action_icon:SetFontSize(size)
	return self
end

function HotkeyWidget:SetWidgetSize(size)
	self.action_icon:SetFontSize(size * HACK_FOR_4K)
	self.action_label:SetFontSize(size * HACK_FOR_4K)
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

function HotkeyWidget:SetOnlyShowForGamepad()
	self.only_show_for_gamepad = true
	return self:RefreshHotkeyIcon()
end

function HotkeyWidget:SetControl(control)
	dbassert(control)
	self.control = control
	return self:RefreshHotkeyIcon()
end

function HotkeyWidget:RefreshHotkeyIcon()
	local owning_player = self:GetOwningPlayer()
	if not owning_player then
		-- Waiting for OnAddedToScreen.
		return self
	end

	if not self._on_input_device_changed then
		self._on_input_device_changed = function(source, data)
			self:RefreshHotkeyIcon()
		end
		self.inst:ListenForEvent("input_device_changed", self._on_input_device_changed, owning_player)
	end

	local playercontroller = owning_player.components.playercontroller
	local want_visible = not self.only_show_for_gamepad or playercontroller:HasGamepad()
	if want_visible then
		self.action_icon:SetText(playercontroller:GetLabelForControl(self.control))
	else
		self.action_icon:SetText("")
	end

	self:_Layout()
	return self
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
