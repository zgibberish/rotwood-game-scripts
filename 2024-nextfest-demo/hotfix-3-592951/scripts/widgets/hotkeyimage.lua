local Image = require "widgets.image"
local kassert = require "util.kassert"


--- Displays a hotkey button as an image.
--
-- See HotkeyWidget if you want a label and layout options.
local HotkeyImage = Class(Image, function(self, control)
	Image._ctor(self)
	self:SetName("HotkeyImage")

	self:SetControl(control)

	self.dbg_add_stack = DEV_MODE and debug.traceback() or "<no callstack in prod>"
end)

function HotkeyImage:OnAddedToScreen(screen)
	local owning_player = self:GetOwningPlayer()
	kassert.assert_fmt(owning_player, "HotkeyImage requires SetOwningPlayer on itself, a parent, or the screen. Call SetOwningPlayer before HotkeyImage is added to the screen tree. %s created at %s", self, self.dbg_add_stack)
	self:RefreshHotkeyIcon()
end

-- Beware: The widget may Show itself when input device changes. To directly
-- control visibility, hide its parent.
function HotkeyImage:SetOnlyShowForGamepad()
	self.only_show_for_gamepad = true
	return self:RefreshHotkeyIcon()
end

function HotkeyImage:SetControl(control)
	dbassert(control)
	self.control = control
	return self:RefreshHotkeyIcon()
end

function HotkeyImage:RefreshHotkeyIcon()
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
	local tex = playercontroller:GetTexForControl(self.control)
	if tex then
		self:SetTexture(tex)
	else
		local device_type, device_id = playercontroller:_GetInputTuple()
		TheLog.ch.FrontEnd:printf("HotkeyImage: Failed to find texture for %s and device: [%s,%s].", self.control.key, device_type, device_id)
	end

	if self.only_show_for_gamepad then
		self:SetShown(playercontroller:HasGamepad())
	end

	return self
end

return HotkeyImage
