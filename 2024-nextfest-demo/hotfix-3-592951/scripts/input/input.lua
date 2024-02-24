local gamepadguesser = require "input.gamepadguesser"
local kassert = require "util.kassert"
local lume = require "util.lume"
require "events"
require "input.rumble"

local CONTROLDEVICETYPE =
{
	["unknown"] = 1,
	["keyboard"] = 2,
	["mouse"] = 3,
	["gamepad"] = 4,
	["touch"] = 5,
}

local REVERSECONTROLDEVICETYPE =
{
	[1] = "unknown",
	[2] = "keyboard",
	[3] = "mouse",
	[4] = "gamepad",
	[5] = "touch",
}

ControlSet = Class(function(self)
	self._controls = {}
end)

function ControlSet:Copy(other)
	dbassert(ControlSet.is_instance(other))
	for i = 1, #other._controls do
		self._controls[i] = other._controls[i]
	end
	for i = #other._controls + 1, #self._controls do
		self._controls[i] = nil
	end
end

function ControlSet:Clear()
	table.clear(self._controls)
end

function ControlSet:IsEmpty()
	return #self._controls == 0
end

function ControlSet:GetSize()
	return #self._controls >> 1
end

function ControlSet:GetControlDetailsAt(i)
	if i >= 1 and i <= self:GetSize() then
		i = i << 1
		return self._controls[i - 1]	--control
			, self._controls[i]			--controldevicetypeid
	end
end

function ControlSet:RemoveControlAt(i)
	if i >= 1 and i <= self:GetSize() then
		local n = #self._controls
		for i = (i << 1) - 1, n - 2 do
			self._controls[i] = self._controls[i + 2]
		end
		self._controls[n - 1] = nil
		self._controls[n] = nil
	end
end

-- device type is a string like "gamepad", "keyboard", "mouse"
function ControlSet:AddControl(control, devicetype)
	local n = #self._controls
	self._controls[n + 1] = control
	self._controls[n + 2] = CONTROLDEVICETYPE[devicetype]
end

function ControlSet:Has(...)
	for i = 1, select("#", ...) do
		local control = select(i, ...)
		for j = 1, #self._controls, 2 do
			if self._controls[j] == control then
				return true
			end
		end
	end
	return false
end

function ControlSet:GetDeviceType(control)
	control = control or self._controls[1]
	for i = 1, #self._controls, 2 do
		if self._controls[i] == control then
			return self._controls[i + 1]
		end
	end
	return nil
end

function ControlSet:GetDeviceTypeName(control)
	local deviceTypeId = self:GetDeviceType(control)
	if deviceTypeId then
		return REVERSECONTROLDEVICETYPE[deviceTypeId]
	end
	return "unknown"
end

function ControlSet:IsMouseButton(control)
	return self:GetDeviceType(control) == CONTROLDEVICETYPE["mouse"]
end

function ControlSet:IsGamepadButton(control)
	return self:GetDeviceType(control) == CONTROLDEVICETYPE["gamepad"]
end

function ControlSet:Dump()
	local str = "[ "
	for i = 1, self:GetSize() do
		local control, deviceTypeId = self:GetControlDetailsAt(i)
		str = str..string.format("%s %s - %s ",
			i == 1 and "[" or "|",
			tostring(control.shortkey),
			tostring(REVERSECONTROLDEVICETYPE[deviceTypeId]))
	end
	return str.."]"
end

local ValidateEmptyControlSet
if DEV_MODE then
	ValidateEmptyControlSet = function(control_set)
		assert(control_set:IsEmpty(), "Recycled ControlSet is not empty.")
	end
end

ControlSetPool = Class(Pool, function(self)
	Pool._ctor(self, ControlSet, ValidateEmptyControlSet, ValidateEmptyControlSet)
end)

------------------------------------------------------------------------

Controls = require "input.controls"

-- LEGACY: Looks like TheInputProxy was DST's native input system, but
-- Rotwood's using Griftland's more lua-driven input where we get inputs pushed
-- to us via callbacks.
-- Remove InputProxy when possible.
local InputProxy = Class(function(self)
	-- Should be set by GameSetting:Load()
	self.enable_vibration = true
	self.mouse_aiming = true
end)

function InputProxy:GetInputDeviceCount()
	return 0
end

function InputProxy:IsInputDeviceConnected()
	return false
end

function InputProxy:IsInputDeviceEnabled()
	return false
end

function InputProxy:EnableInputDevice()
end

function InputProxy:LoadCurrentControlMapping()
end

function InputProxy:LoadDefaultControlMapping()
end

function InputProxy:ApplyControlMapping()
end

function InputProxy:LoadControls()
end

-- TODO(input): Move vibration and mouse aiming to TheInput. We should remove TheInputProxy.
function InputProxy:EnableVibration(enable)
	self.enable_vibration = enable
end

function InputProxy:EnableMouseAiming(enable)
	self.mouse_aiming = enable
end

function InputProxy:IsMouseAiming()
	return self.mouse_aiming
end

TheInput = nil
TheInputProxy = nil

local KBM_DEVICE_ID <const> = 1
local KBM_DEVICE_HANDLE <const> = "kbm"

local Input = Class(function(self)
	self.onkey = EventProcessor()     -- all keys, down and up, with key param
	self.onkeyup = EventProcessor()   -- specific key up, no parameters
	self.onkeydown = EventProcessor() -- specific key down, no parameters
	self.onmousebutton = EventProcessor()

	self.ongamepadbutton = EventProcessor()     -- all gamepadbuttons, down and up, with gamepadbutton param
	self.ongamepadbuttonup = EventProcessor()   -- specific gamepadbutton up, no parameters
	self.ongamepadbuttondown = EventProcessor() -- specific gamepadbutton down, no parameters

	self.active_inputs = {} -- map device handle to active state about each control.
	self.active_inputs[KBM_DEVICE_HANDLE] = {}

	self.position = EventProcessor()
	self.oncontrol = EventProcessor()
	self.ontextinput = EventProcessor()
	self.ongesture = EventProcessor()

	self.gamepadconnectionhandlers = {}

	self.hoverinst = nil
	self.enabledebugtoggle = true
	self.worldeditors = {}

	self.last_input = {
		-- TODO(input): Fetch this from native to get data from last simreset.
		device_type = "mouse",
		device_id = nil,
	}
	self.on_device_changed_callbacks = {}
	self.mouse_enabled = Platform.IsNotConsole()
	self.cursorvisible = TheSim:GetCursorVisibility()
	self.cursorvisible_mousemove = false
	self.cursorvisibleoverride = nil

	-- We won't get a valid position until the mouse moves, so use a default
	-- that's probably in-world.
	self:SetMousePos(RES_X / 2, RES_Y / 2)

	self.gamepads = {}
	self.keys = {}
	self.mousebuttons = {}

	self.playing_rumbles = {}

	self.control_state = {}
	self.axis_state = {}

	self.control_set_pool = ControlSetPool()

	self.gamepadowners = {} -- k:device_id, v: entity

	-- To turn on extra logging:
	--~ TheLog:enable_channel("InputSpam")
	--~ TheLog:enable_channel("InputControlSpam")
	self.per_gamepad_oncontrol = {} -- k:device_id, v:EventProcessor (similar to self.oncontrol)
	self.gamepad_control_state = {} -- k:device_id, v:state table (similar to self.control_state)
	self.gamepad_axis_state = {} -- k:device_id, v:state table (similar to self.axis_state)

	self:ResetControlState()
	self:ApplyInputBindings()

	TheInput = self
	TheInputProxy = InputProxy()

	self:DisableAllControllers()
end)

function Input:GetKeyboardMouseDeviceId()
	return KBM_DEVICE_ID
end

function Input:_TryAssignGamepad(device_id, pad_data, ent)
	if not self.gamepadowners[device_id] then
		self.gamepadowners[device_id] = ent
		TheLog.ch.InputSpam:printf("RegisterDeviceOwner: Gamepad id=%d name=[%s] assigned to entity GUID %d", device_id, pad_data.name, ent.GUID)
		return device_id

	elseif self.gamepadowners[device_id] == ent then
		TheLog.ch.InputSpam:printf("RegisterDeviceOwner: Gamepad id=%d name=[%s] already assigned to entity GUID %d", device_id, pad_data.name, ent.GUID)
		return device_id
	end
end

function Input:RegisterDeviceOwner(ent, device_type, device_id)
	device_id = device_id or -1
	if device_type == "gamepad" then
		if device_id == -1 then
			-- take whatever free gamepad is available
			for k,v in pairs(self.gamepads) do
				local id = self:_TryAssignGamepad(k, v, ent)
				if id then
					return id
				end
			end
		end

		if self.gamepads[device_id] then
			if self:_TryAssignGamepad(device_id, self.gamepads[device_id], ent) then
				return device_id
			end
		end

		TheLog.ch.Input:printf("RegisterDeviceOwner: Failed to register Gamepad id=%d to entity GUID %d", device_id, ent.GUID)
		return -1
	end
	-- else: all devices have ownership registered with TheNet, so no
	-- additional registration needed for keyboard.
	return nil
end

function Input:UnregisterDeviceOwner(device_type, device_id)
	if device_type == "gamepad" then
		local ent = self.gamepadowners[device_id]
		if ent then
			TheLog.ch.InputSpam:printf("UnregisterDeviceOwner %s for device_id=%d", tostring(ent), device_id)
			ent:PushEvent("deviceunregistered", {device_type = device_type, device_id = device_id})
		end
		self.gamepadowners[device_id] = nil
	end
end

function Input:GetDeviceOwner(device_type, device_id)
	local inputID = self:ConvertToInputID(device_type, device_id)
	local guid = TheNet:FindGUIDForLocalInputID(inputID)
	if guid and Ents[guid] then
		return Ents[guid]
	end

	return nil
end

function Input:IsDeviceFree(device_type, device_id)
	return self:GetDeviceOwner(device_type, device_id) == nil
end

function Input:IsDeviceValid(device_type, device_id)
	if device_type == "gamepad" then
		return self.gamepads[device_id] ~= nil
	end
end

function Input:FindFreeDeviceID(device_type)
	if device_type == "gamepad" then
		for k,_ in pairs(self.gamepads) do
			if self:IsDeviceFree(device_type, k) then
				return k
			end
		end
	end
	return nil
end

-- Returns a list of input tuples: device_type, device_id
function Input:GetAllFreeDevices()
	local free = {}
	if self:IsDeviceFree("keyboard", 0) then
		table.insert(free, {"keyboard", 0})
	end
	for k,_ in pairs(self.gamepads) do
		if self:IsDeviceFree("gamepad", k) then
			table.insert(free, {"gamepad", k})
		end
	end
	return free
end

local function ResetControlStateSet(control_state, axis_state)
	if not control_state or not axis_state then
		return
	end

	table.clear(control_state)
	table.clear(axis_state)

	for k,v in pairs(Controls.Digital) do
		control_state[v] = {down = false, t = 0, rep_time = 0}
	end
	for k,v in pairs(Controls.Analog) do
		axis_state[v] = {val=0}
	end
end

function Input:ResetControlState()
	-- global control state
	ResetControlStateSet(self.control_state, self.axis_state)
	-- per-device control state
	for k,_v in pairs(self.gamepads) do
		ResetControlStateSet(self.gamepad_control_state[k], self.gamepad_axis_state[k])
	end
end

function Input:ApplyInputBindings()
	local default_binds = require "input.bindings"
	self:SetKeyBinds(default_binds.keyboard)
	self:SetMouseBinds(default_binds.mouse)
	self:SetGamepadBinds(default_binds.gamepad)

	if self.input_settings then
		self.input_settings:ApplyInputBindings( self )
	end
end

function Input:UpdateInputBinding(binding)
	if self.input_settings then
		for i,v in pairs(self.input_settings) do
			print(i,v)
		end
	end
	assert(false)
end

function Input:AddKeyBind(binding)
	local bindings = self.keybindings[binding.key]
	if bindings == nil then
		bindings = {}
		self.keybindings[binding.key] = bindings
	end
	table.insert(bindings, binding)
	if #bindings > 1 then
		table.sort(bindings, function(a,b) return (a.control.priority or 0) > (b.control.priority or 0) end)
	end

	self.key_lookup[binding.control] = self.key_lookup[binding.control] or {}
	table.insert(self.key_lookup[binding.control], binding)
end

function Input:SetKeyBinds(bindings)
	self.keybindings = {}
	self.key_lookup = {} -- Maps of Control -> list of bindings

	for k,binding in pairs(bindings) do
		self:AddKeyBind(binding)
	end
end

function Input:SetMouseBinds(bindings)
	self.mousebindings = {}
	self.mouse_lookup = {}

	for k,v in pairs(bindings) do
		if v.control then
			self.mousebindings[v.button] = self.mousebindings[v.button] or {}
			table.insert(self.mousebindings[v.button], v)

			self.mouse_lookup[v.control] = self.mouse_lookup[v.control] or {}
			table.insert(self.mouse_lookup[v.control], v)
		end
	end

	for k, v in pairs(self.mousebindings) do
		table.sort(v, function(a,b) return (a.control.priority or 0) > (b.control.priority or 0) end)
	end
end

local function AddGamepadBind(dest_gamepadbindings, dest_gamepad_lookup, binding)
	local bindings = dest_gamepadbindings[binding.button]
	if bindings == nil then
		bindings = {}
		dest_gamepadbindings[binding.button] = bindings
	end
	table.insert(bindings, binding)
	if #bindings > 1 then
		table.sort(bindings, function(a,b) return (a.control.priority or 0) > (b.control.priority or 0) end)
	end

	dest_gamepad_lookup[binding.control] = dest_gamepad_lookup[binding.control] or {}
	table.insert(dest_gamepad_lookup[binding.control], binding)
end

-- Sets default bindings, but doesn't apply rebinds.
function Input:SetGamepadBinds(src_bindings)
	self.gamepadbindings = {} -- k:button (string) v:binding entry (button, control, etc.) (table)
	self.gamepad_lookup = {} -- k:control (table) v:binding entry (button, control, etc.) (table)
	for k,binding in pairs(src_bindings) do
		AddGamepadBind(self.gamepadbindings, self.gamepad_lookup, binding)
	end
end

function Input:DisableAllControllers()
	for i = 1, TheInputProxy:GetInputDeviceCount() - 1 do
		if TheInputProxy:IsInputDeviceEnabled(i) and TheInputProxy:IsInputDeviceConnected(i) then
			TheInputProxy:EnableInputDevice(i, false)
		end
	end
end

function Input:EnableAllControllers()
	for i = 1, TheInputProxy:GetInputDeviceCount() - 1 do
		if TheInputProxy:IsInputDeviceConnected(i) then
			TheInputProxy:EnableInputDevice(i, true)
		end
	end
end

function Input:IsControllerLoggedIn(controller)
	if Platform.IsXB1() then
		return TheInputProxy:IsControllerLoggedIn(controller)
	end
	return true
end

function Input:LogUserAsync(controller,cb)
	if Platform.IsXB1() then
		TheInputProxy:LogUserAsync(controller,cb)
	else
		cb(true)
	end
end

function Input:LogSecondaryUserAsync(controller,cb)
	if Platform.IsXB1() then
		TheInputProxy:LogSecondaryUserAsync(controller,cb)
	else
		cb(true)
	end
end

function Input:EnableMouse(enable)
	self.mouse_enabled = enable and Platform.IsNotConsole()
end

function Input:ControllerAttached()
	-- Reconsider checking for gamepad because it's bad for multiplayer! We
	-- should try to have necessary information in the control.
	OBSOLETE("playercontroller:HasGamepad() or TheInput:HasAnyConnectedGamepads()")
end

function Input:AddTextInputHandler(fn)
	return self.ontextinput:AddEventHandler("text", fn)
end

function Input:AddKeyUpHandler(key, fn)
	return self.onkeyup:AddEventHandler(key, fn)
end

function Input:AddKeyDownHandler(key, fn)
	return self.onkeydown:AddEventHandler(key, fn)
end

function Input:AddKeyHandler(fn)
	return self.onkey:AddEventHandler("onkey", fn)
end

function Input:AddMouseButtonHandler(fn)
	return self.onmousebutton:AddEventHandler("onmousebutton", fn)
end

function Input:AddMoveHandler(fn)
	return self.position:AddEventHandler("move", fn)
end

-- Register for a specific button to go up.
-- fn: function(gamepad_id, gamepadbutton, down)
function Input:AddGamepadButtonUpHandler(gamepadbutton, fn)
	return self.ongamepadbuttonup:AddEventHandler(gamepadbutton, fn)
end

-- Register for a specific button to go down.
function Input:AddGamepadButtonDownHandler(gamepadbutton, fn)
	return self.ongamepadbuttondown:AddEventHandler(gamepadbutton, fn)
end

function Input:AddGamepadButtonHandler(fn)
	return self.ongamepadbutton:AddEventHandler("ongamepadbutton", fn)
end

function Input:RemoveAnyGamepadButtonHandler(handler)
	assert(handler)
	self.ongamepadbuttonup:RemoveHandler(handler)
	self.ongamepadbuttondown:RemoveHandler(handler)
	self.ongamepadbutton:RemoveHandler(handler)
end

function Input:AddControlHandler(control, fn)
	return self.oncontrol:AddEventHandler(control, fn)
end

function Input:AddGeneralControlHandlerForGamepad(device_id, fn)
	if self.per_gamepad_oncontrol[device_id] then
		TheLog.ch.InputSpam:printf("Using general gamepad control handler for device=%s.", device_id)
		return self.per_gamepad_oncontrol[device_id]:AddEventHandler("oncontrol", fn)
	end
	return nil
end

function Input:RemoveGeneralControlHandlerForGamepad(device_id, handler)
	if self.per_gamepad_oncontrol[device_id] and handler then
		TheLog.ch.InputSpam:printf("Removing general gamepad control handler for device=%s.", device_id)
		return self.per_gamepad_oncontrol[device_id]:RemoveHandler(handler)
	end
	return false
end

function Input:AddGeneralControlHandler(fn)
	TheLog.ch.InputSpam:printf("Using general control handler")
	return self.oncontrol:AddEventHandler("oncontrol", fn)
end

function Input:AddControlMappingHandler(fn)
	return self.oncontrol:AddEventHandler("onmap", fn)
end

function Input:AddGestureHandler(gesture, fn)
	return self.ongesture:AddEventHandler(gesture, fn)
end

function Input:UpdatePosition(x, y)
	if self.mouse_enabled then
		self.position:HandleEvent("move", x, y)
	end
end

function Input:FlushInput()
	self:ResetControlState()
end

function Input:OnMouseButton(button, down, x, y)
	if self.mouse_enabled then
		self:SetMousePos(x, y)
		TheFrontEnd:OnMouseButton(button, down, x,y)
		self.onmousebutton:HandleEvent("onmousebutton", button, down, x, y)
	end
end

function Input:OnRawKey(key, down)
	self.onkey:HandleEvent("onkey", key, down)
	if down then
		return self.onkeydown:HandleEvent(key)
	else
		return self.onkeyup:HandleEvent(key)
	end
end

function Input:OnRawGamepadButton(gamepad_id, gamepadbutton, down)
	self.ongamepadbutton:HandleEvent("ongamepadbutton", gamepad_id, gamepadbutton, down)
	if down then
		return self.ongamepadbuttondown:HandleEvent(gamepadbutton, gamepad_id)
	else
		return self.ongamepadbuttonup:HandleEvent(gamepadbutton, gamepad_id)
	end
end

function Input:OnText(text)
	self.ontextinput:HandleEvent("text", text)
end

function Input:OnGesture(gesture)
	self.ongesture:HandleEvent(gesture)
end

function Input:OnControlMapped(deviceId, controlId, inputId, hasChanged)
	self.oncontrol:HandleEvent("onmap", deviceId, controlId, inputId, hasChanged)
end

function Input:OnFrameStart()
	self.hoverinst = nil
	self.hovervalid = false
end

function Input:SetMousePos(x,y)
	self.raw_mouse_x = x
	self.raw_mouse_y = y

	self.mouse_x = x
	self.mouse_y = (self.h or RES_Y) - y
end

-- Mouse position in window coordinates with 0,0 at bottom left and the max
-- values are TheFrontEnd:GetScreenDims()
function Input:GetMousePos()
	return self.mouse_x, self.mouse_y
end

-- Mouse position in window coordinates with 0,0 at center of screen and the
-- max values at half of TheFrontEnd:GetScreenDims()
function Input:GetUIMousePos()
	return TheFrontEnd:WindowToUI(self:GetMousePos())
end

-- Position using the same coordinate system as widget layout: with 0,0 at the
-- centre of the screen and max at RES_X/2, RES_Y/2.
-- Instead of actual mouse position, returns a position within our fixed
-- virtual window resolution.
function Input:GetVirtualMousePos()
	local mx, my = self:GetUIMousePos()
	return mx / TheFrontEnd.base_scale , my / TheFrontEnd.base_scale
end

function Input:GetWorldPosition()
	local x, z = TheSim:ScreenToWorldXZ(self:GetMousePos())
	return x ~= nil and z ~= nil and Vector3(x, 0, z) or nil
end

function Input:GetWorldXZ()
	-- ScreenToWorldXZ can return nil values if the mouse hasn't moved
	return TheSim:ScreenToWorldXZ(self:GetMousePos())
end

function Input:GetWorldXZWithHeight(height)
	local x, y = self:GetMousePos()
	-- ScreenToWorldXZ can return nil values if the mouse hasn't moved
	return TheSim:ScreenToWorldXZ(x, y, height)
end

function Input:GetAllEntitiesUnderMouse()
	return self.mouse_enabled and self.entitiesundermouse or {}
end

-- Only props when Alt is held.
function Input:GetAllWorldEntitiesUnderMouse(filter)
	if not self.mouse_enabled then
		return
	end

	local allents = self.entitiesundermouse or {}
	local ret = {}
	-- some entities consist of multiple entities
	local doubles = {}

	for i,v in pairs(allents) do
		if v:IsValid()
			and v:IsVisible()
			and not doubles[v]
			and v.Transform ~= nil
		then
			doubles[v] = true
			if not filter or filter(v) then
				table.insert(ret,v)
			end
		end
	end
	return ret
end

function Input:GetWorldEntityUnderMouse()
	return self.mouse_enabled and
		self.hoverinst ~= nil and
		self.hoverinst:IsValid() and
		self.hoverinst:IsVisible() and
		self.hoverinst.Transform ~= nil and
		self.hoverinst or nil
end

function Input:EnableDebugToggle(enable)
	self.enabledebugtoggle = enable
end

function Input:IsDebugToggleEnabled()
	return self.enabledebugtoggle
end

function Input:SetEditMode(source, enable)
	kassert.typeof("boolean", enable)
	self.worldeditors[source] = enable or nil
end

function Input:SetEditingBlocksGameplay(enable)
	self.worldeditblocksgameplay = enable
end

-- Is there something under edit? When maps are loaded in edit mode
-- (WorldMap:IsDebugMap), this is always true. Otherwise, it's true when
-- a tool is trying to edit.
-- To check if persistent data can be modified, check IsDebugMap.
function Input:IsEditMode()
	return next(self.worldeditors) ~= nil
end

function Input:IsEditingBlockingGameplay()
	return self:IsEditMode()
		and (self.worldeditblocksgameplay
			or self:IsKeyDown(InputConstants.Keys.ALT)
			or self:IsKeyDown(InputConstants.Keys.CTRL)
			or self:IsKeyDown(InputConstants.Keys.SHIFT))
end

function Input:GetHUDEntityUnderMouse()
	return self.mouse_enabled and
		self.hoverinst ~= nil and
		self.hoverinst:IsValid() and
		self.hoverinst:IsVisible() and
		self.hoverinst.Transform == nil and
		self.hoverinst or nil
end

function Input:IsMouseDown(buttonid)
	return self.mousebuttons[buttonid] == true
end

function Input:IsKeyDown(key)
--    local keyid = InputConstants.Keys[ key ]
--print("Input:IsKeyDown",key,"->",key)
	return self.keys[key] == true
end

-- victorc: hack - local multiplayer, looks expensive to call when device owners enabled
function Input:IsControlDownOnAnyDevice(control)
	if control then
		local state = self.control_state[control]
		if state and state.down == true then
			return true
		end

		for _k,v in pairs(self.gamepad_control_state) do
			state = v[control]
			if state and state.down == true then
				return true
			end
		end
	end
	return false
end

function Input:IsControlDown(control, device_type, device_id)
	if control then
		if device_type == "any" then
			return self:IsControlDownOnAnyDevice(control)
		end
		local state
		if device_type and device_type == "gamepad" then
			if device_id and self.gamepad_control_state[device_id] then
				state = self.gamepad_control_state[device_id][control]
			end
		else
			state = self.control_state[control]
		end

		return (state and state.down == true)
	end
	return false
end

function Input:GetDigitalControlValue(control, device_type, device_id)
	return self:IsControlDown(control, device_type, device_id) and 1 or 0
end

function Input:ApplyDeadZone(xdir, ydir)
	-- Note: We apply a deadzone of ~0.24 on LS and 0.27 on RS via native code.
	-- See kiln::SDLControllerInput::ConnectedGamepad::GetThumbStick
	-- If not seeing values in [0.5,1), see ignoreDigitalInput in GetAnalogControlValue.

	-- TODO(gamepad): Make deadzone configurable.
	local deadzone = 0.3
	if math.abs(xdir) >= deadzone or math.abs(ydir) >= deadzone then
		-- TODO(gamepad): Use Scaled Radial Dead Zone:
		-- https://www.gamedeveloper.com/disciplines/doing-thumbstick-dead-zones-right
		return xdir, ydir, true
	end
	return 0, 0, false
end

function Input:GetAnalogControlValue(control, device_type, device_id, ignoreDigitalInput)
	-- victorc: hack -- for some reason, sometimes we miss the 'up' digital input event
	-- and that messes up movement, making it feel "sticky"
	-- This ignores digital input outright in those cases
	ignoreDigitalInput = ignoreDigitalInput or false

	if control then
		local state
		if device_type and device_type == "gamepad" then
			if device_id and self.gamepad_axis_state[device_id] then
				state = self.gamepad_axis_state[device_id][control]
			end
		else
			state = self.axis_state[control]
		end

		if state then
			local digital = ((not ignoreDigitalInput) and state.down) and 1 or 0
			local analog = state.val or 0
			-- Using max here means we don't really receive analog inputs. Any
			-- value over 0.5 (the threshold for 'down') will be 1.0, so we'll
			-- return 0.7. Pass ignoreDigitalInput=true to get truely digital
			-- values.
			-- TODO(gamepad): Why isn't ignoreDigitalInput=true the default?
			return math.max(digital, analog)
		end
	end
	return 0
end

-- For a float value where two controls are opposite ends of the axis.
function Input:GetAnalogAxisValue(positive_control, negative_control, device_type, device_id, ignoreDigitalInput)
	local pos = self:GetAnalogControlValue(positive_control, device_type, device_id, ignoreDigitalInput)
	local neg = self:GetAnalogControlValue(negative_control, device_type, device_id, ignoreDigitalInput)
	return pos - neg
end

-- victorc: temporary troubleshooting helper function
function Input:DumpAnalogControlValue(control, device_type, device_id)
	if control then
		local state
		if device_type and device_type == "gamepad" then
			if device_id and self.gamepad_axis_state[device_id] then
				state = self.gamepad_axis_state[device_id][control]
			end
		else
			state = self.axis_state[control]
		end

		if state then
			local digital = state.down and 1 or 0
			local analog = state.val or 0
			TheLog.ch.Input:printf("DumpAnalogControlValue control=%s digital=%1.3f analog=%1.3f", control.key, digital, analog)
		end
	end
end

function Input:IsPasteKey(key)
	if key == InputConstants.Keys.V then
		if Platform.IsMac() then
			-- Command-v
			return self:IsKeyDown(InputConstants.Keys.LSUPER) or self:IsKeyDown(InputConstants.Keys.RSUPER)
		end
		return self:IsKeyDown(InputConstants.Keys.CTRL)
	end
	return key == InputConstants.Keys.INSERT and Platform.IsLinux() and self:IsKeyDown(InputConstants.Keys.SHIFT)
end

function Input:UpdateEntitiesUnderMouse()
	local x, y = self:GetMousePos()
	local props_only = self:IsEditMode() and self:IsKeyDown(InputConstants.Keys.ALT)
	self.entitiesundermouse = TheSim:GetEntitiesAtScreenPoint(x, y, true, props_only)
end

function Input:ForceWorldEntityUnderMouse(ent)
	if self.mouse_enabled then
		if ent ~= self.hoverinst then
			if ent ~= nil and ent.Transform ~= nil then
				ent:PushEvent("mouseover")
			end

			if self.hoverinst ~= nil and self.hoverinst:IsValid() then
				if self.hoverinst.components.prop ~= nil and self.hoverinst.components.prop:IsDragging() then
					self.hoverinst:PushEvent("stopdragging")
				end
				if self.hoverinst.Transform ~= nil then
					self.hoverinst:PushEvent("mouseout")
				end
			end
			self.hoverinst = ent
		end
	end
end

function Input:SelectHighlightedProp()
	if self.lockedprop then
		-- Don't select a different prop while we're locked.
		return self.lockedprop
	end

	-- Only includes props because we're only called while Alt is pressed.
	local allprops = TheInput:GetAllWorldEntitiesUnderMouse()
	local first_found
	for _,v in ipairs(allprops) do
		if v.components.prop and v.components.prop.edit_listeners then
			first_found = v
			if v == self.hoverprop then
				-- Don't change selection while hovering current selection.
				return v
			end
		end
	end
	return first_found
end

function Input:OnUpdate(dt)
	self:UpdateRumble(dt)

	for k,v in pairs(self.control_state) do
		if v.down and k.repeat_rate then
			v.rep_time = v.rep_time - dt
			if v.rep_time <= 0 then
				v.rep_time = 1/k.repeat_rate
				-- TODO: victorc - how to confirm that this is really a keyboard input
				self:DoControlRepeat(k, "keyboard", KBM_DEVICE_ID)
			end
		end
	end

	for id,_name in pairs(self.gamepads) do
		for k,v in pairs(self.gamepad_control_state[id]) do
			if v.down and k.repeat_rate then
				v.rep_time = v.rep_time - dt
				if v.rep_time <= 0 then
					v.rep_time = 1/k.repeat_rate
					self:DoControlRepeat(k, "gamepad", id)
				end
			end
		end
	end

	if self.mouse_enabled then
		if self.hoverinst ~= nil
			and self.hoverinst.components.prop ~= nil
			and self.hoverinst.components.prop:IsDragging()
			and self.hoverinst:IsValid()
		then
			return
		end

		self:UpdateEntitiesUnderMouse()

		local inst = self.entitiesundermouse[1]
		if inst ~= nil and inst.CanMouseThrough ~= nil then
			local mousethrough, keepnone = inst:CanMouseThrough()
			if mousethrough then
				for i = 2, #self.entitiesundermouse do
					local nextinst = self.entitiesundermouse[i]
					if nextinst == nil
						or nextinst:HasTag("player")
						or (nextinst.Transform ~= nil) ~= (inst.Transform ~= nil)
					then
						if keepnone then
							inst = nextinst
							mousethrough, keepnone = false, false
						end
						break
					end
					inst = nextinst
					if nextinst.CanMouseThrough == nil then
						mousethrough, keepnone = false, false
					else
						mousethrough, keepnone = nextinst:CanMouseThrough()
					end
					if not mousethrough then
						break
					end
				end
				if mousethrough and keepnone then
					inst = nil
				end
			end
		end

		if inst ~= self.hoverinst then
			if inst ~= nil and inst.Transform ~= nil then
				inst:PushEvent("mouseover")
			end

			if self.hoverinst ~= nil and self.hoverinst.Transform ~= nil then
				self.hoverinst:PushEvent("mouseout")
			end

			self.hoverinst = inst
		end
	end

	-- select active prop
	if self:IsEditMode() then
		local newprop
		if TheInput:IsKeyDown(InputConstants.Keys.ALT) then
			newprop = self:SelectHighlightedProp()
		else
			self.lockedprop = nil
		end
		if newprop ~= self.hoverprop then
			self:SetHoverProp(newprop)
		end
	end

	local newCursorVisible = self:UpdateCursorVisible()
	if newCursorVisible ~= self.cursorvisible then
		TheSim:SetCursorVisibility(newCursorVisible)
		self.cursorvisible = newCursorVisible
		TheLog.ch.InputSpam:printf("Cursor Visibility Changed: %s", tostring(newCursorVisible))
	end
end

function Input:UpdateCursorVisible()
	if self.cursorvisibleoverride then
		return self.cursorvisibleoverride
	end

	for _i,player in ipairs(AllPlayers) do
		local last_device_type = player.components.playercontroller:GetLastInputDeviceType()
		if not last_device_type
			or last_device_type == "mouse"
			or last_device_type == "keyboard"
		then
			return true
		end
	end

	if self:IsEditMode() or self.cursorvisible_mousemove then
		return true
	end

	return false
end

function Input:SetCursorVisibleOverride(isVisible)
	self.cursorvisibleoverride = isVisible
end

function Input:SetHoverProp(newprop)
	if self.hoverprop then
		self.hoverprop:PushEvent("propmouseout")
	end

	self.hoverprop = newprop
	if self.hoverprop then
		self.hoverprop:PushEvent("propmouseover")
	end
end

-- Look up bindings by their control key which is a name uniquely identifying a control.
function Input:_FindBindingByControlKey(device_type, control_key)
	local kbm = {
		{ atlas = "icons_mouse",    bindings = self.mousebindings, lookup = self.mouse_lookup, },
		{ atlas = "icons_keyboard", bindings = self.keybindings,   lookup = self.key_lookup,   },
	}
	local gamepad = {
		{ bindings = self.gamepadbindings, lookup = self.gamepad_lookup, },
	}
	local binding_sets_for_device = {
		gamepad = gamepad,
		mouse = kbm,
		keyboard = kbm,
	}

	local binding_sets = binding_sets_for_device[device_type]
	assert(binding_sets, device_type)
	for _,pack in ipairs(binding_sets) do
		for button_id,action_bindings in pairs(pack.bindings) do
			for _,bind in ipairs(action_bindings) do
				-- We display the first icon found in tables in bindings.lua
				-- and mouse before keyboard, but skip_for_display lets you
				-- keyboard icon to show instead of mouse. Make sure there's a
				-- keyboard binding!
				if not bind.skip_for_display
					and bind.control.key == control_key
				then
					-- The binding (from bindings.lua) and set of data it was
					-- pulled from (kbm above).
					return bind, pack
				end
			end
		end
	end
end

local function FindButtonForControl(self, device_type, control_key)
	local binding, pack = self:_FindBindingByControlKey(device_type, control_key)
	if pack then
		-- Find the first mapped control so we can have duplicates
		-- but only show icons for first specified in bindings.lua
		local first = pack.lookup[binding.control][1]
		return first.button or first.key, pack.atlas
	end
end

-- Get a tex representing the input device or an error image for invalid
-- device. Use string in an Image widget to display.
function Input:GetTexForDevice(device_type, device_id)
	if not device_type then
		return "images/ui_ftf/error_large.tex"
	elseif device_type == "keyboard"
		or device_type == "mouse"
	then
		return "images/ui_ftf/input_kbm.tex"
	else
		local lookup = {
			-- Indexes match image names.
			"images/ui_ftf/input_1.tex",
			"images/ui_ftf/input_2.tex",
			"images/ui_ftf/input_3.tex",
			"images/ui_ftf/input_4.tex",
		}
		return lookup[device_id] or "images/ui_ftf/input_n.tex"
	end
end

-- Get an icon representing the input device or an error image for invalid
-- device. Add this string to a Text widget to display.
function Input:GetLabelForDevice(device_type, device_id, scale)
	scale = scale or 1.5
	local tex = self:GetTexForDevice(device_type, device_id)
	return string.format("<p img='%s' color=0 scale=%.2f>", tex, scale)
end

-- GetLabelForControl for dynamic controls.
--
-- For inline ones, use "<p bind='Controls.Digital.MENU_ACCEPT'>"
--
-- Prepend into any string to get the current binding as an image. If you want
-- it to update with device changes, you must call after device changes.
function Input:GetLabelForControl(control, device_type, device_id)
	local tex = self:GetTexForControlName(control.key, device_type, device_id)
	if tex then
		return string.format("<p img='%s'>", tex)
	end
	return ""
end

-- Texture name for input control to show button icons with Image widget.
-- Convience to match playercontroller API.
function Input:GetTexForControl(control, device_type, device_id)
	return self:GetTexForControlName(control.key, device_type, device_id)
end

function Input:GetTexForControlName(control_key, device_type, device_id)
	assert(self.last_input.device_type, "How did last_input get cleared?")
	if not device_type then
		assert(not device_id, "Passed device_id but not type??")
		device_type = self.last_input.device_type
		device_id = self.last_input.device_id
	end

	local button_id, atlas = FindButtonForControl(self, device_type, control_key)
	if not button_id then
		TheLog.ch.InputSpam:printf("Failed to find button_id for control '%s' atlas '%s' device '%s'", control_key, atlas, device_type)
		return
	end
	return self:_GetTexForButtonId(button_id, atlas, device_type, device_id)
end

function Input:_GetTexForButtonId(button_id, atlas, device_type, device_id)
	device_type = device_type or "gamepad"
	device_id = device_id or 1 -- TODO: Remove this default so we always use the correct device.
	if not atlas then
		atlas = self:GetDeviceImageAtlas(device_type, device_id)
	end
	if atlas == "icons_keyboard" and button_id:find("SUPER", 2, true) then
		-- There's no universal symbol for Windows key.
		if Platform.IsMac() then
			button_id = "super_mac"
		else
			button_id = "super_win"
		end
	end
	button_id = button_id:lower() -- image paths are always lowercase
	return string.format("images/%s/%s.tex", atlas, button_id)
end

-- Different from self.gamepads[device_id].name because it returns basic
-- category ("xbox") for the detected appearance. Always returns values
-- in DEVICE_MAP.
function Input:GetGamepadAppearance(device_id)
	-- GetGamepadAppearance will return "Xbox 360 Controller" if Steam Input is
	-- enabled for your controller and steamworks doesn't have the game set to
	-- have Full Controller Support.
	-- If steam detects the input appearance, it will return a name in DEVICE_MAP.
	local device_name = TheSim:GetGamepadAppearance(device_id)
	if not DEVICE_MAP[device_name] then
		device_name = gamepadguesser.joystickNameToConsole(device_name)
	end
	return device_name
end

-- Return the name reported by the platform for the device.
function Input:GetDeviceName(device_type, device_id)
	if device_type == "keyboard" then
		return STRINGS.UI.KEYBOARD
	elseif device_id then
		return self.gamepads[device_id].name
	end
	-- else: Invalid input
end

-- Atlas containing button/key icons for the input image device.
function Input:GetDeviceImageAtlas(device_type, device_id)
	if device_type == "gamepad" then
		local device_name = self:GetGamepadAppearance(device_id)
		local atlas = DEVICE_MAP[device_name] or DEVICE_MAP.DEFAULT
		return atlas
	elseif device_type == "mouse" then
		return "icons_mouse"
	elseif device_type == "keyboard" then
		return "icons_keyboard"
	end
end

function Input:HasMouseWheel(control, device_type, device_id)
	assert(type(control) == "table" and type(control.key) == "string", "Must pass a Control.")
	assert(self.last_input.device_type, "How did last_input get cleared?")
	device_type = device_type or self.last_input.device_type
	if device_type ~= "mouse" then
		return false
	end
	local scroll_up   = InputConstants.MouseButtonById[InputConstants.MouseButtons.SCROLL_UP]
	local scroll_down = InputConstants.MouseButtonById[InputConstants.MouseButtons.SCROLL_DOWN]
	local btns = self.mouse_lookup[control]
	for _,bind in ipairs(btns or table.empty) do
		local key = bind.button
		if key == scroll_up or key == scroll_down then
			return true
		end
	end
	return false
end

function Input:PlatformUsesVirtualKeyboard()
	if Platform.IsConsole() then
		return true
	end

	return false
end

-- KAJ: Hmmm, I don't think this would survive a sim-reset unless it's being re-sent
function Input:OnScreenResize(w,h)
	self.w = w
	self.h = h
end

---------------- Globals

TheInput = Input()

function OnPosition(x, y)
end

function OnControl(control, digitalvalue, analogvalue)
end

function OnMouseButton(button, is_up, x, y)
end

function OnMouseMove(x, y)
end

function OnInputKey(key, is_up)
end

function OnInputText(text)
end

function OnGesture(gesture)
	TheInput:OnGesture(gesture)
end

function OnControlMapped(deviceId, controlId, inputId, hasChanged)
	TheInput:OnControlMapped(deviceId, controlId, inputId, hasChanged)
end

function Input:OnMouseMove(x, y)
	self:SetMousePos(x, y)
	self:UpdatePosition(x, y)
	if self.mouse_enabled then
		TheFrontEnd:OnMouseMove(x, y)
	end
	self.cursorvisible_mousemove = true
end

function Input:OnMouseButtonDown(x, y, button, device, is_scroll)
	-- TODO_KAJ
	self:RegisterMouseButtonDown(button, true)

	local simulate_touch_mode = false -- TheGame:GetLocalSettings().SIMULATE_TOUCH_MODE
	if not self:OnMouseButton(button, true, x, y) then
		self:OnMouseButtonDownInternal(x, y, button, simulate_touch_mode and "touch" or device or "mouse", is_scroll)
	end
end

function Input:OnMouseButtonUp(x, y, button, device, is_scroll)
	-- TODO_KAJ
	self:RegisterMouseButtonDown(button, false)

	local simulate_touch_mode = false -- TheGame:GetLocalSettings().SIMULATE_TOUCH_MODE
	if not self:OnMouseButton(button, false, x, y) then
		self:OnMouseButtonUpInternal(x, y, button, simulate_touch_mode and "touch" or device or "mouse", is_scroll)
	end
	-- KAJ: I am torn about whether I should put this in LockFocus(false)
	TheFrontEnd:FocusHoveredWidget()
end

-- Set active (pressed) binding for a control, return true if it's the first one down.
function Input:_SetActiveBinding(control, binding, device_handle)
	assert(device_handle)
	-- This will never nil deref because we add device tables on connect.
	local active_control = self.active_inputs[device_handle][control]

	if active_control
		and active_control[binding]
	then
		-- already had an active binding with the given device_handle. Don't process.
		return false
	end

	active_control = self.active_inputs[device_handle][control] or {}
	self.active_inputs[device_handle][control] = active_control

	active_control[binding] = true
	return true
end

-- Release active (pressed) binding for a control, return true if it's the last one down
function Input:_PopLastActiveBinding(control, binding, device_handle)
	assert(device_handle)
	local active_control = self.active_inputs[device_handle][control]

	local removed_active_context = false
	if active_control then
		if active_control[binding] then
			removed_active_context = true
			active_control[binding] = nil
			if table.numkeys(active_control) == 0 then
				self.active_inputs[device_handle][control] = nil
			end
		end
	end
	return removed_active_context
end

function Input:_SetLastInputDevice(device_type, device_id, device_handle)
	local old_device_type = self.last_input.device_type
	local changed_device = self.last_input.device_handle ~= device_handle
	self.last_input.device_type = device_type
	self.last_input.device_id = device_id
	-- device_handle is solely used as an index to active_inputs.
	self.last_input.device_handle = device_handle

	if changed_device then
		for _,cb in ipairs(self.on_device_changed_callbacks) do
			cb(old_device_type, device_type)
		end
	end


	if device_type == "gamepad" then
		self.cursorvisible_mousemove = false
	end
end

-- You should probably not use WasLastGlobalInputGamepad!
--
-- Use Screen:IsRelativeNavigation() or Screen:IsUsingGamepad() instead!
function Input:WasLastGlobalInputGamepad()
	return self.last_input.device_type == "gamepad"
end

-- Listener function receives two device types as arguments, the old device, and the new one
function Input:RegisterForDeviceChanges(on_changed_fn)
	table.insert(self.on_device_changed_callbacks, on_changed_fn)
end

function Input:UnregisterForDeviceChanges(on_changed_fn)
	lume.remove(self.on_device_changed_callbacks, on_changed_fn)
end

function Input:OnMouseButtonDownInternal(x, y, button, device_type, is_scroll)
	self:OnMouseMove(x, y)
	local button_id = InputConstants.MouseButtonById[button]
	local bindings = button_id and self.mousebindings[button_id]
	local control_set = self.control_set_pool:Get()
	if bindings then
		for k,v in ipairs(bindings) do
			if self:CheckModifiers(v) then
				if self:_SetActiveBinding(v.control, v, KBM_DEVICE_HANDLE) then
					-- TODO: victorc: Not sure why scrolling doesn't count as a mouse control
					control_set:AddControl(v.control, not is_scroll and "mouse" or "unknown")
				end
			end
		end
	end

	if not control_set:IsEmpty() then
		self:DoControlDown(control_set, device_type, KBM_DEVICE_ID)
		control_set:Clear()
	end
	self.control_set_pool:Recycle(control_set)

	self:_SetLastInputDevice("mouse", KBM_DEVICE_ID, KBM_DEVICE_HANDLE)
end

function Input:OnMouseButtonUpInternal(x, y, button, device_type, is_scroll)
	self:OnMouseMove(x, y)

	local button_id = InputConstants.MouseButtonById[button]
	local bindings = button_id and self.mousebindings[button_id]
	local control_set = self.control_set_pool:Get()
	if bindings then
		for k,v in pairs(bindings) do
			if self:CheckModifiers(v) then
				if self:_PopLastActiveBinding(v.control, v, KBM_DEVICE_HANDLE) then
					-- TODO: victorc: Not sure why scrolling doesn't count as a mouse control
					control_set:AddControl(v.control, not is_scroll and "mouse" or "unknown")
				end
			end
		end
	end
	if not control_set:IsEmpty() then
		self:DoControlUp(control_set, device_type, KBM_DEVICE_ID)
		control_set:Clear()
	end
	self.control_set_pool:Recycle(control_set)
end

function Input:OnMouseWheel(wheel)
	if wheel > 0 then
		self:OnMouseButtonDown(self.raw_mouse_x, self.raw_mouse_y, 1003, "mouse", true)
		self:OnMouseButtonUp(self.raw_mouse_x, self.raw_mouse_y, 1003, "mouse", true)
	elseif wheel < 0 then
		self:OnMouseButtonDown(self.raw_mouse_x, self.raw_mouse_y, 1004, "mouse", true)
		self:OnMouseButtonUp(self.raw_mouse_x, self.raw_mouse_y, 1004, "mouse", true)
	end
end

function Input:RegisterMouseButtonDown(buttonid, down)
	self.mousebuttons[buttonid] = down
end

function Input:GetMetaKey(keyid)
	local metakeys =
	{
		[InputConstants.Keys.LCTRL]  = InputConstants.Keys.CTRL,
		[InputConstants.Keys.RCTRL]  = InputConstants.Keys.CTRL,
		[InputConstants.Keys.LSHIFT] = InputConstants.Keys.SHIFT,
		[InputConstants.Keys.RSHIFT] = InputConstants.Keys.SHIFT,
		[InputConstants.Keys.LALT]   = InputConstants.Keys.ALT,
		[InputConstants.Keys.RALT]   = InputConstants.Keys.ALT,
	}
	return metakeys[keyid]
end

function Input:RegisterKeyDown(keyid, down)
	local meta = self:GetMetaKey(keyid)
	if meta then
		self.keys[meta] = down
	end

	self.keys[keyid] = down
end

function Input:IsModifierCtrl()
	return self:IsKeyDown(InputConstants.Keys.LCTRL) or self:IsKeyDown(InputConstants.Keys.RCTRL)
end

function Input:IsModifierShift()
	return self:IsKeyDown(InputConstants.Keys.LSHIFT) or self:IsKeyDown(InputConstants.Keys.RSHIFT)
end

function Input:IsModifierAlt()
	return self:IsKeyDown(InputConstants.Keys.LALT) or self:IsKeyDown(InputConstants.Keys.RALT)
end

function Input:IsModifierAny()
	return self:IsModifierCtrl() or self:IsModifierShift() or self:IsModifierAlt()
end

-- Is the input raw key name a modifier. All modifiers are L/R because this
-- isn't for input constants (CTRL, ALT, SHIFT).
function Input:IsModifierKey(key)
	local is = key == "LCTRL" or key == "RCTRL" or
			key == "LALT" or key == "RALT" or
			key == "LSHIFT" or key == "RSHIFT"
	return is
end

function Input:BindingToString(binding)
	local list = {}

	if binding.CTRL then table.insert(list, "CTRL") end
	if binding.SHIFT then table.insert(list, "SHIFT") end
	if binding.ALT then table.insert(list, "ALT") end

	if binding.key then
		table.insert(list, binding.key)
	elseif binding.button then
		-- TODO(input): Both mouse and gamepad use 'button'. We should pass the desired device.
		local s = string.format("<p img='%s'>", self:_GetTexForButtonId(binding.button))
		table.insert(list, s)
	end

	return table.concat(list, " + ")
end

function Input:GetControlPrettyName(control)
	-- binding_label_key is only required if the name (ATTACK_HEAVY) doesn't
	-- match the string name (HEAVY_ATTACK). Useful when an Analog and Digital
	-- control have the same name.
	local key = control.binding_label_key or control.shortkey
	return STRINGS.CONTROL_BINDINGS[key] or "MISSING:"..control.shortkey
end

function Input:CheckModifiers( binding )
	if binding.ANYMOD then
		return true
	end

	local ctrl = self:IsModifierCtrl()
	local alt = self:IsModifierAlt()
	local shift = self:IsModifierShift()

	local match = ((binding.CTRL ~= nil) == ctrl)
			and ((binding.SHIFT ~= nil) == shift)
			and ((binding.ALT ~= nil) == alt)
	return match
end

-- This was on game in GL.
function Input:OnControlDown(control, device_type, device_id)
	TheLog.ch.InputControlSpam:printf("OnControlDown %s %s", device_type, device_id)
	if self.debug and device_type == "gamepad" then
		if control:Has(Controls.Digital.TOGGLE_DEBUG_MENU) then
			self.debug:TogglePanel()
			self.debug_using_gamepad = self.debug:DebugPanelsOpen()
			return true
		end

		if self.debug_using_gamepad and self.debug:DebugPanelsOpen() then
			return true
		end
	end

	if self.debug == nil or not self.debug:IsConsoleDocked() then
		if TheFrontEnd:OnControlDown(control, device_type, nil, device_id) then
			return true
		end
		if device_type == "gamepad" and self.per_gamepad_oncontrol[device_id] then
			TheLog.ch.InputControlSpam:printf("OnControlDown HandleEvent %s %s", device_type, device_id)
			self.per_gamepad_oncontrol[device_id]:HandleEvent(control, true)
			self.per_gamepad_oncontrol[device_id]:HandleEvent("oncontrol", control, true)
		else
			self.oncontrol:HandleEvent(control, true)
			self.oncontrol:HandleEvent("oncontrol", control, true)
		end
	end

	if self.debug and self.debug:OnControlDown( control, device_type ) then
		return true
	end

	if control:Has(Controls.Digital.FEEDBACK) then
		-- Require at use because stuff inside feedback requires input to be
		-- fully loaded.
		local feedback = require "feedback"
		feedback.StartFeedback()
		return true
	end
end

function Input:DoControlDown( control_set, device_type, device_id )
	TheLog.ch.InputControlSpam:printf("DoControlDown %s %s", device_type, device_id)
	if device_type == "gamepad" and self.ignore_gamepad then
		return false
	end

	for i = control_set:GetSize(), 1, -1 do
		local control, deviceTypeId = control_set:GetControlDetailsAt(i)

		-- map digital to analog inputs as well
		local digitalstate, analogstate
		if device_type == "gamepad" and self.gamepads[device_id] then
			digitalstate = self.gamepad_control_state[device_id][control]
			analogstate = self.gamepad_axis_state[device_id][control]
		else
			digitalstate = self.control_state[control]
			analogstate = self.axis_state[control]
		end

		local state = digitalstate or analogstate

		local process = false
		if state then
			if not state.down then
				state.down = true
				if control.repeat_rate then
					state.rep_time = 1/control.repeat_rate
				end

				if digitalstate then
					process = true
					--self:OnControlDown( control, device_type, device_id )
				end
			end
		end
		if not process then
			control_set:RemoveControlAt(i)
		end
	end

	if not control_set:IsEmpty() then
		return self:OnControlDown( control_set, device_type, device_id )
	end
end

-- this was in Game in GL
function Input:OnControlUp(control, device_type, device_id)
	TheLog.ch.InputControlSpam:printf("OnControlUp %s %s", device_type, device_id)
	if self.debug and self.debug_using_gamepad and device_type == "gamepad" and self.debug:DebugPanelsOpen() then
		return true
	end

	if self.debug == nil or not self.debug:IsConsoleDocked() then
		if TheFrontEnd:OnControlUp(control, device_type, device_id) then
			return true
		end
		if device_type == "gamepad" and self.per_gamepad_oncontrol[device_id] then
			TheLog.ch.InputControlSpam:printf("OnControlUp HandleEvent %s %d", device_type, device_id)
			self.per_gamepad_oncontrol[device_id]:HandleEvent(control, false)
			self.per_gamepad_oncontrol[device_id]:HandleEvent("oncontrol", control, false)
		else
			self.oncontrol:HandleEvent(control, false)
			self.oncontrol:HandleEvent("oncontrol", control, false)
		end
	end
end

function Input:DoControlUp( control_set, device_type, device_id )
	if device_type == "gamepad" and self.ignore_gamepad then
		return false
	end

	for i = control_set:GetSize(), 1, -1 do
		local control, deviceTypeId = control_set:GetControlDetailsAt(i)

		-- map digital to analog inputs as well
		local digitalstate, analogstate
		if device_type == "gamepad" and self.gamepads[device_id] then
			digitalstate = self.gamepad_control_state[device_id][control]
			analogstate = self.gamepad_axis_state[device_id][control]
		else
			digitalstate = self.control_state[control]
			analogstate = self.axis_state[control]
		end

		local state = digitalstate or analogstate
		-- we need to make sure the control was down, not just the key
		-- as there may be multiple controls bound to one key, with different modifiers
		local process = false
		if state then
			if state.down then
				state.down = false
				if digitalstate then
					process = true
					--self:OnControlUp( control, device_type, device_id )
				end
			end
		end
		if not process then
			control_set:RemoveControlAt(i)
		end
	end

	if not control_set:IsEmpty() then
		return self:OnControlUp( control_set, device_type, device_id )
	end
end

function Input:DoControlRepeat(control, device_type, device_id)
	local control_set = self.control_set_pool:Get()
	control_set:AddControl(control, device_type)
	self:DoControlUp(control_set, device_type, device_id)
	self:DoControlDown(control_set, device_type, device_id)
	control_set:Clear()
	self.control_set_pool:Recycle(control_set)
end

function Input:OnKeyDown(keyid, modifiers)
	self.no_input_time = 0
	self:RegisterKeyDown(keyid, true)

	local key = InputConstants.KeyById[keyid]
	if not key then
		print( "Invalid key:", keyid)
		return
	end

	if self:OnRawKey(keyid, true) then
		return true
	end

	local meta_keyid = self:GetMetaKey(keyid)
	local metakey = meta_keyid and InputConstants.KeyById[meta_keyid]

	local bindings = self.keybindings[key]
	local control_set = self.control_set_pool:Get()
	if bindings then
		for k,v in ipairs(bindings) do
			if (self:IsModifierKey(key) or self:CheckModifiers(v)) then
				if self:_SetActiveBinding(v.control, v, KBM_DEVICE_HANDLE) then
					control_set:AddControl(v.control, "keyboard")
				end
			end
		end
	end
	-- is this a meta key?
	if metakey then
		local bindings = self.keybindings[metakey]
		if bindings then
			for k,v in ipairs(bindings) do
				if (self:IsModifierKey(metakey) or self:CheckModifiers(v)) then
					if self:_SetActiveBinding(v.control, v, KBM_DEVICE_HANDLE) then
						control_set:AddControl(v.control, "keyboard")
					end
				end
			end
		end
	end

	if not control_set:IsEmpty() then
		self:DoControlDown(control_set, "keyboard", KBM_DEVICE_ID)
		control_set:Clear()
	end
	self.control_set_pool:Recycle(control_set)
	self:_SetLastInputDevice("keyboard", KBM_DEVICE_ID, KBM_DEVICE_HANDLE)
end

function Input:OnKeyRepeat(keyid, modifiers)
	-- for now, just call OnKeyDown
	self:OnKeyDown(keyid, modifiers)
end

function Input:OnKeyUp(keyid, modifiers)
	self.no_input_time = 0
	if self.keys[keyid] then
		self:RegisterKeyDown(keyid, false)

		local key = InputConstants.KeyById[keyid]
		if not key then return end

		if self:OnRawKey(keyid, false) then
			return true
		end

		local meta_keyid = self:GetMetaKey(keyid)
		local metakey = meta_keyid and InputConstants.KeyById[meta_keyid]

		local bindings = self.keybindings[key]
		local control_set = self.control_set_pool:Get()
		if bindings then
			for k,v in ipairs(bindings) do
				if self:_PopLastActiveBinding(v.control, v, KBM_DEVICE_HANDLE) then
					control_set:AddControl(v.control, "keyboard")
				end
			end
		end
		-- is this a meta key?
		if metakey then
			local bindings = self.keybindings[metakey]
			if bindings then
				for k,v in ipairs(bindings) do
					if self:_PopLastActiveBinding(v.control, v, KBM_DEVICE_HANDLE) then
						control_set:AddControl(v.control, "keyboard")
					end
				end
			end
		end

		if not control_set:IsEmpty() then
			self:DoControlUp(control_set, "keyboard", KBM_DEVICE_ID)
			control_set:Clear()
		end
		self.control_set_pool:Recycle(control_set)
	end
end

function Input:OnGamePadButtonDown(gamepad_id, button)
	TheLog.ch.InputControlSpam:printf("OnGamePadButtonDown %d %d", gamepad_id, button)
	self.no_input_time = 0
	if self.gamepads[gamepad_id] then
		self.gamepads[gamepad_id][InputConstants.GamepadButtonById[button]] = true;

		if self:OnRawGamepadButton(gamepad_id, button, true) then
			return true
		end

		local button_id = InputConstants.GamepadButtonById[button]
		local bindings = self.gamepadbindings[button_id]
		local control_set = self.control_set_pool:Get()

		if bindings then
			for k,v in pairs(bindings) do
				if self:_SetActiveBinding(v.control, v, gamepad_id) then
					control_set:AddControl(v.control, "gamepad")
				else
					TheLog.ch.InputControlSpam:printf("OnGamePadButtonDown %d %d binding already active", gamepad_id, button)
				end
			end
		end

		if not control_set:IsEmpty() then
			self:DoControlDown(control_set, "gamepad", gamepad_id)
			control_set:Clear()
		end
		self.control_set_pool:Recycle(control_set)
	end
	self:_SetLastInputDevice("gamepad", gamepad_id)
end

function Input:OnGamePadButtonRepeat(gamepad_id, button)
	self:OnGamePadButtonDown(gamepad_id, button)
end

function Input:OnGamePadButtonUp(gamepad_id, button)
	TheLog.ch.InputControlSpam:printf("OnGamePadButtonUp %d %d", gamepad_id, button)
	self.no_input_time = 0

	if self.gamepads[gamepad_id] then
		self.gamepads[gamepad_id][InputConstants.GamepadButtonById[button]] = false;

		if self:OnRawGamepadButton(gamepad_id, button, false) then
			return true
		end

		local button_id = InputConstants.GamepadButtonById[button]
		local bindings = self.gamepadbindings[button_id]
		local control_set = self.control_set_pool:Get()

		-- Do we need to check modifiers?
		if bindings then
			for k,v in pairs(bindings) do
				if self:_PopLastActiveBinding(v.control, v, gamepad_id) then
					control_set:AddControl(v.control, "gamepad")
				else
					TheLog.ch.InputControlSpam:printf("OnGamePadButtonUp %d %d binding already active", gamepad_id, button)
				end
			end
		end
		if not control_set:IsEmpty() then
			self:DoControlUp(control_set, "gamepad", gamepad_id)
			control_set:Clear()
		end
		self.control_set_pool:Recycle(control_set)
	end
end

function Input:OnTextInput(text)
	self:OnText(text)
end

function Input:UpdateRumble(dt)
	local gamepadrumbles = {}
	local to_remove
	for k,rumble_instance in ipairs(self.playing_rumbles) do
		rumble_instance.time = rumble_instance.time + (dt * rumble_instance.speed)
		TheLog.ch.InputSpam:printf("rumble update: device_id=%d rumble_id=%s time=%1.3f",
			rumble_instance.device_id, rumble_instance.rumble.id, rumble_instance.time)
		if rumble_instance.rumble:IsDoneAtTime(rumble_instance.time) then
			to_remove = to_remove or {}
			table.insert(to_remove, rumble_instance)
		else
			if not gamepadrumbles[rumble_instance.device_id] then
				gamepadrumbles[rumble_instance.device_id] = { small_rumble_value = 0, large_rumble_value = 0 }
			end

			local small, large = rumble_instance.rumble:GetValues(rumble_instance.time)
			gamepadrumbles[rumble_instance.device_id].small_rumble_value = gamepadrumbles[rumble_instance.device_id].small_rumble_value + small * rumble_instance.amp
			gamepadrumbles[rumble_instance.device_id].large_rumble_value = gamepadrumbles[rumble_instance.device_id].large_rumble_value + large * rumble_instance.amp
		end
	end

	if to_remove then
		for k,v in ipairs(to_remove) do
			self:_KillRumbleInstance(v)
		end
	end

	for id,data in pairs(gamepadrumbles) do
		TheSim:GamepadRumble(id, data.small_rumble_value, data.large_rumble_value)
	end
end

function Input:PlayRumble(device_id, rumble, speed, amp)
	if not TheInputProxy.enable_vibration then
		return
	end

	TheLog.ch.InputSpam:printf("PlayRumble %s device: %d", rumble, device_id)

	local device_ids
	if not device_id or device_id == -1 then
		device_ids = table.getkeys(self.gamepadowners)
	else
		device_ids = {}
		device_ids[1] = device_id
	end

	local rumbles = {}
	for idx, id in ipairs(device_ids) do
		local rumble_data = GetRumble(rumble)
		if rumble_data then
			local rumble_instance = {device_id = id, rumble = rumble_data, time = 0, speed = speed or 1, amp = amp or 1}
			table.insert(self.playing_rumbles, rumble_instance)
			TheLog.ch.InputSpam:printf("Adding new rumble %s", rumble)
			table.insert(rumbles, rumble)
		else
			TheLog.ch.InputSpam:printf("Attempt to play invalid rumble: %s", rumble)
		end
	end

	return rumbles
end

function Input:_KillRumbleInstance(rumble_instance)
	local removed = table.removearrayvalue(self.playing_rumbles, rumble_instance)
	if not removed then
		TheLog.ch.Input:print("WARNING: Failed to remove rumble instance", table.inspect(rumble_instance))
	end
end

-- Kill rumbles by predicate. Predicate input is a rumble instance.
function Input:KillRumble_Predicate(shouldremove_fn)
	lume.removeall(self.playing_rumbles, shouldremove_fn)
end

-- Kill rumbles by the id returned by PlayRumble.
function Input:KillRumble(rumble)
	-- Don't worry about failing to remove a rumble, because it likely
	-- autostopped.
	local rumble_data = GetRumble(rumble)
	self:KillRumble_Predicate(function(rumble_instance)
		return rumble_instance.rumble == rumble_data
	end)
end

function Input:ClearRumble()
	table.clear(self.playing_rumbles)
end

function Input:GetGamepadCount()
	return #self.gamepads
end

-- Reconsider checking for gamepad because it's bad for multiplayer! We
-- should try to have necessary information in the control.
function Input:HasAnyConnectedGamepads()
	-- TODO(input): Add a native query for number of gamepads.
	-- We might have a gamepad after index 1, so check count to be certain
	-- we're correct.
	local any_counted = self:GetGamepadCount() > 0
	-- Gamepads don't count until we get a callback to register, which doesn't
	-- happen until a bit after first sim start.
	local any_seen = TheSim:GetGamepadAppearance(1):len() > 0
	return any_seen or any_counted
end

function Input:OnGamepadConnected(gamepad_id, gamepad_device_description)
	self.gamepads[gamepad_id] = {}
	-- The "name" is a description like "XInput Controller"
	self.gamepads[gamepad_id].name = gamepad_device_description;
	kassert.assert_fmt(self.active_inputs[gamepad_id] == nil, "Duplicate device? %s [%s]", gamepad_id, gamepad_device_description)
	self.active_inputs[gamepad_id] = {}

	-- Don't use TheLog.ch.InputSpam:printf so we see device names in bug reports!
	TheLog.ch.Input:printf("Input:OnGamepadConnected id=%d [%s] [%s]", gamepad_id, gamepad_device_description, self:GetGamepadAppearance(gamepad_id))

	self.per_gamepad_oncontrol[gamepad_id] = EventProcessor()
	self.gamepad_control_state[gamepad_id] = {}
	self.gamepad_axis_state[gamepad_id] = {}

	ResetControlStateSet(self.gamepad_control_state[gamepad_id], self.gamepad_axis_state[gamepad_id])

	-- nw: disabled this for now. Need to ask if we want to add the gamepad to the active player, or if we want to add a new
	-- player for it.
	-- special case to hot enable gamepads for single player
--	if #AllPlayers == 1 and not AllPlayers[1].components.playercontroller:HasGamepad() then
--		TheLog.ch.InputSpam:printf("Attempting to assign newly-connected gamepad to player 1...")
--		AllPlayers[1].components.playercontroller:TryChangeInputDevice("gamepad", gamepad_id)
--	end

	for source, fn in pairs(self.gamepadconnectionhandlers) do
		fn(true, gamepad_id)
	end
end

function Input:OnGamepadDisconnected(gamepad_id)
	local pad_data = self.gamepads[gamepad_id]
	TheLog.ch.Input:printf("Input:OnGamepadDisconnected id=%d [%s]", gamepad_id, pad_data and pad_data.name)

	self.gamepads[gamepad_id] = nil
	self.active_inputs[gamepad_id] = nil
	self:UnregisterDeviceOwner("gamepad", gamepad_id)

	self.per_gamepad_oncontrol[gamepad_id] = nil
	table.clear(self.gamepad_control_state[gamepad_id])

	-- see ResetControlState
	table.clear(self.gamepad_control_state[gamepad_id])
	table.clear(self.gamepad_axis_state[gamepad_id])

	for source, fn in pairs(self.gamepadconnectionhandlers) do
		fn(false, gamepad_id)
	end
end

function Input:OnGamepadAnalogInput(gamepad_id, ls_x, ls_y, rs_x, rs_y, lt, rt)
--	TheLog.ch.InputControlSpam:printf("OnGamepadAnalogInput: id=%d ls_x=%1.2f ls_y=%1.2f rs_x=%1.2f rs_y=%1.2f",
--		gamepad_id, ls_x, ls_y, rs_x, rs_y)
	local getButton = {
		LS_LEFT = function()
			return -1 * math.clamp(ls_x, -1, 0)
		end,
		LS_RIGHT = function()
			return math.clamp(ls_x, 0, 1)
		end,
		LS_UP = function()
			return math.clamp(ls_y, 0, 1)
		end,
		LS_DOWN = function()
			return -1 * math.clamp(ls_y, -1, 0)
		end,
		RS_LEFT = function()
			return -1 * math.clamp(rs_x, -1, 0)
		end,
		RS_RIGHT = function()
			return math.clamp(rs_x, 0, 1)
		end,
		RS_UP = function()
			return math.clamp(rs_y, 0, 1)
		end,
		RS_DOWN = function()
			return -1 * math.clamp(rs_y, -1, 0)
		end,
		LT = function()
			return -1 * math.clamp(lt, 0, 1)
		end,
		RT = function()
			return -1 * math.clamp(rt, 0, 1)
		end,
	}

	if self.gamepads[gamepad_id] then
			self.gamepads[gamepad_id].ls_x = ls_x;
			self.gamepads[gamepad_id].ls_y = ls_y;
			self.gamepads[gamepad_id].rs_x = rs_x;
			self.gamepads[gamepad_id].rs_y = rs_y;
			self.gamepads[gamepad_id].lt = lt;
			self.gamepads[gamepad_id].rt = rt;
	end

	for k,v in pairs(Controls.Analog) do
		local state = self.gamepad_axis_state[gamepad_id][v]
		if state then
			local lookup = self.gamepad_lookup[v]
			if lookup then
				--print("button:",lookup[1].button)
				--print("value:",state.val)
				local func = getButton[lookup[1].button]
				if func then
					state.val = func()
				end
			end
		end
	end
end

-- shim
function Input:IsMousePosReset()
--	print("*** TODO: Input:IsMousePosReset ***")
	return false
end

local function RemoveBind(control, lookup, binding_set, input_id)
	assert(input_id == "key" or input_id == "button", "Should be identifier used in bindings.lua")
	local bindings = lookup[ control ]
	if bindings then
		-- Remove every binding that binds this control. I think
		-- we use reverse order to make remove() faster.
		for j = #bindings, 1, -1 do
			local binding = bindings[j]
			-- print( "Removing binding ", serpent.line(binding))
			local b = binding_set[ binding[input_id] ]
			assert(b)
			local removed = table.removearrayvalue(b, binding)
			assert(nil ~= removed, "Binding wasn't found. lookup and bindings tables are out of sync.")
			table.remove( bindings, j )
		end
	end
end

function Input:RemoveKeyBind(control)
	RemoveBind(control, self.key_lookup, self.keybindings, "key")
end

function Input:RebindKey( binding )
	assert(binding)
	self:RemoveKeyBind( binding.control )
	if binding.key then
		self:AddKeyBind( binding )
	end
	-- else: key was unbound
end

function Input:_RemoveGamepadButtonBind(control)
	return RemoveBind(control, self.gamepad_lookup, self.gamepadbindings, "button")
end

function Input:_AddGamepadButtonBind(binding)
	return AddGamepadBind(self.gamepadbindings, self.gamepad_lookup, binding)
end

function Input:RebindGamepadButton(binding)
	assert(binding)
	self:_RemoveGamepadButtonBind(binding.control)
	if binding.button then
		self:_AddGamepadButtonBind(binding)
	end
	-- else: key was unbound
end

local function PrintDeviceOwner(device_owner, device_type, device_id, device_name)
	local player_pretty_name = device_owner and device_owner:GetCustomUserName() or ""
	TheLog.ch.Input:printf("[%s,%d] name=\"%s\" owner=[%s] \"%s\"",
		device_type, device_id or -1, device_name, device_owner and tostring(device_owner) or "free", player_pretty_name)
end
function Input:DebugListDevices(device_type, verbose)
	if not device_type then
		-- Dig into multiple lists to track down inconsistencies.
		local function CheckDevice(device, device_id, data)
			-- Use GetDeviceOwner to use TheNet to discover device owners
			-- according to native; and check every input id and each player.
			local device_owner = TheInput:GetDeviceOwner(device, device_id)
			if device_owner then
				PrintDeviceOwner(device_owner, device, device_id, data and data.name or "<Unknown>")
			end
		end
		TheLog.ch.Input:print("Owned Devices:")
		TheLog.ch.Input:indent() do
			CheckDevice("keyboard", 0)
			for device_id=0,10 do
				CheckDevice("gamepad", device_id, self.gamepads[device_id])
			end
		end TheLog.ch.Input:unindent()

		TheLog.ch.Input:print("Input IDs:")
		TheLog.ch.Input:indent() do
			-- Check every reasonable input id to fetch total native state.
			for inputID=0,16 do
				local guid = TheNet:FindGUIDForLocalInputID(inputID)
				local player = Ents[guid]
				if player then
					local dev_type, dev_id = player.components.playercontroller:_GetInputTuple()
					PrintDeviceOwner(player, dev_type, dev_id, "inputID:".. inputID)
				end
			end
		end TheLog.ch.Input:unindent()

		TheLog.ch.Input:print("TheInput gamepads:")
		TheLog.ch.Input:indent() do
			-- Check Input's list of gamepads to expose inconsistencies with above.
			for k,v in pairs(self.gamepads) do
				PrintDeviceOwner(self.gamepadowners[k], "gamepad", k, v.name)
			end
		end TheLog.ch.Input:unindent()

		TheLog.ch.Input:print("Players:")
		TheLog.ch.Input:indent() do
			-- Check players just in case it doesn't match above.
			for i,player in ipairs(AllPlayers) do
				local dev_type, dev_id = player.components.playercontroller:_GetInputTuple()
				TheLog.ch.Input:printf("[%s] hunterid=%d device=[%s,%s]",
					player, player:GetHunterId(), dev_type, dev_id)
			end
		end TheLog.ch.Input:unindent()

	elseif device_type == "gamepad" then
		for k,v in pairs(self.gamepads) do
			PrintDeviceOwner(self.gamepadowners[k], device_type, k, v.name)
			if verbose then
				local analogLeft = self:GetAnalogControlValue(Controls.Analog.MOVE_LEFT, device_type, k)
				local analogRight = self:GetAnalogControlValue(Controls.Analog.MOVE_RIGHT, device_type, k)
				local analogUp = self:GetAnalogControlValue(Controls.Analog.MOVE_UP, device_type, k)
				local analogDown = self:GetAnalogControlValue(Controls.Analog.MOVE_DOWN, device_type, k)
				TheLog.ch.Input:printf("  Analog1 L:%1.2f R:%1.2f (xdir=%1.2f) U:%1.2f, D:%1.2f (ydir=%1.2f)",
					analogLeft, analogRight, analogRight - analogLeft,
					analogUp, analogDown, analogUp - analogDown)
				self:DumpAnalogControlValue(Controls.Analog.MOVE_LEFT, device_type, k)
				self:DumpAnalogControlValue(Controls.Analog.MOVE_RIGHT, device_type, k)
				self:DumpAnalogControlValue(Controls.Analog.MOVE_UP, device_type, k)
				self:DumpAnalogControlValue(Controls.Analog.MOVE_DOWN, device_type, k)
			end
		end
	end
	if verbose then
		TheLog:enable_channel("InputSpam")
		TheLog:enable_channel("InputControlSpam")
		TheLog.ch.Input:printf("Verbose logging ENABLED")
	end
end

function Input:ConvertToInputID(device_type, device_id)
	if device_type == "gamepad" then 
		return device_id
	else
		return 0
	end
end

function Input:ConvertFromInputID(inputID)
	if inputID == 0 then 
		return "keyboard", 1
	else
		return "gamepad", inputID
	end
end



function Input:RegisterGamepadConnectionHandler(source, fn)
	self.gamepadconnectionhandlers[source] = fn
end

function Input:UnregisterGamepadConnectionHandler(source)
	self.gamepadconnectionhandlers[source] = nil
end



return Input
