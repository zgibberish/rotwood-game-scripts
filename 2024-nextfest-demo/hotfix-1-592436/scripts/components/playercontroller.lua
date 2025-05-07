local DebugDraw = require "util.debugdraw"
local cursor = require "content.cursor"
local easing = require "util.easing"
local PlayersScreen = require "screens.playersscreen"

local function OnPlayerActivated(inst)
	inst.components.playercontroller:Activate()
end

local function OnPlayerDeactivated(inst)
	inst.components.playercontroller:Deactivate()
end

local INVALID_INPUT_ID <const> = -1 -- matches InvalidValue in inputid.h
local KEYBOARD_INPUT_ID <const> = 0

local PlayerController = Class(function(self, inst)
	self.inst = inst

	--cache variables
	self.interacttarget = nil
	self.placer = nil

	self.build_mode = false

	self.aim_pointer = nil

	self.handler = nil
	self.gamepadhandler = nil

	self.deferredcontrols = nil
	self.controlspool = ControlSetPool()
	self.controlqueue = {}
	self.controlqueueticks =
	{
		["lightattack"] = 6,
		["heavyattack"] = 6,
		["dodge"] = 4,
		["skill"] = 6,
		["potion"] = 6,
		["interact"] = 4,
	}
	-- victorc: 60Hz, double tick length for 30Hz timings
	for k,v in pairs(self.controlqueueticks) do
		self.controlqueueticks[k] = v * ANIM_FRAMES
	end

	self.controlqueuetickoverrides = {} -- Hard over-rides of control queue ticks
					-- TODO: Currently every example of these ^ in the game does [num] * ANIM_FRAMES and if they don't it's probably a bug...
					-- Should probably refactor this to use AnimFrames all the way through.
					-- Same for controlqueuetickmods below.
	self.controlqueuetickmods = {} 	    -- Modifiers to control queue ticks (store the name of the modifier, so multiple modifiers can be active at once without wiping all of them)
	self.input = TheInput
	self.last_input = {
		device_type = "unknown",
		--device_id = nil,
	}
	self.changed_cursor = nil

	inst:StartUpdatingComponent(self)

	inst:ListenForEvent("playeractivated", OnPlayerActivated)
	inst:ListenForEvent("playerdeactivated", OnPlayerDeactivated)

	self._onGamepadConnectionHandler = function(is_connected, device_id)
		if is_connected then
			self:OnGamepadConnected(device_id)
		end
	end

	TheInput:RegisterGamepadConnectionHandler(self, self._onGamepadConnectionHandler)
end)

--------------------------------------------------------------------------

function PlayerController:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("playeractivated", OnPlayerActivated)
	self.inst:RemoveEventCallback("playerdeactivated", OnPlayerDeactivated)

	self:Deactivate()

	TheInput:UnregisterGamepadConnectionHandler(self)
end

PlayerController.OnRemoveEntity = PlayerController.OnRemoveFromEntity

--------------------------------------------------------------------------

function PlayerController:MakeAimPointer()
	if not self.aim_pointer then
		self.aim_pointer = SpawnPrefab("aim_pointer", self.inst)
		self.aim_pointer.components.aimindicator:SetFollowTarget(self.inst)
	end
end

function PlayerController:ClearAimPointer()
	if self.aim_pointer then
		self.aim_pointer:Remove()
		self.aim_pointer = nil
	end
end

function PlayerController:HasInputDevice()
	return self.inputID ~= nil
end

function PlayerController:HasGamepad()
	return self.gamepad_id ~= nil and self.gamepad_id >= 0
end

function PlayerController:GetInputImageAtlas()
	return TheInput:GetDeviceImageAtlas(self:_GetInputTuple())
end

-- For passing into many Input functions.
-- Returns: device_type, device_id
function PlayerController:_GetInputTuple()
	if not self:HasInputDevice() then
		return nil
	elseif self:HasGamepad() then
		return "gamepad", self.gamepad_id
	else
		return "keyboard", TheInput:GetKeyboardMouseDeviceId()
	end
end

-- Texture name for input control to show button icons with Image widget.
function PlayerController:GetLabelForDevice()
	if self.inst:IsLocal() then
		return TheInput:GetLabelForDevice(self:_GetInputTuple())
	end
	return string.format("<p img='images/ui_ftf/input_remote.tex' color=0 scale=1.5>")
end

-- Texture name for input control to show button icons with Image widget.
function PlayerController:GetTexForControl(control)
	return TheInput:GetTexForControlName(control.key, self:_GetInputTuple())
end

-- Texture name for input control to show button icons with Image widget.
function PlayerController:GetTexForControlName(control_key)
	return TheInput:GetTexForControlName(control_key, self:_GetInputTuple())
end

-- Texture for input control to show button icons with Text widget.
function PlayerController:GetLabelForControl(control)
	local tex = self:GetTexForControl(control)
	if tex then
		return string.format("<p img='%s'>", tex)
	end
	-- Probably no input device.
	return ""
end

function PlayerController:_ReleaseGamepad(clearInputID)
	assert(clearInputID ~= nil)

	if self.gamepad_id then
		-- Remove deviceunregistered callback first so we don't get our own message.
		self.inst:RemoveEventCallback("deviceunregistered", self._OnDeviceUnregistered)
		self.input:UnregisterDeviceOwner("gamepad", self.gamepad_id)

		if clearInputID then
			-- Clear inputID so input system doesn't think we still have it setup.
			net_modifyplayer(self.inst.Network:GetPlayerID(), INVALID_INPUT_ID)
		end

		if self.gamepadhandler then
			self.gamepadhandler:Remove()
			self.gamepadhandler = nil
		end

		self.gamepadhandler = nil
		self.gamepad_id = nil
		self.inputID = nil
	end
end

function PlayerController:_ReleaseKeyboard(clearInputID)
	assert(clearInputID ~= nil)

	if self.handler ~= nil then
		self.handler:Remove()
		self.handler = nil
	end
	if self.inputID == KEYBOARD_INPUT_ID then
		self.inputID = nil
		if clearInputID then
			-- Clear inputID so input system doesn't think we still have it setup.
			net_modifyplayer(self.inst.Network:GetPlayerID(), INVALID_INPUT_ID)
		end
	end
end

function PlayerController:IsActivated()
	return self.deferredcontrols ~= nil
end

function PlayerController:ReInitInputs(clearInputID)
	self:_ReleaseKeyboard(clearInputID)
	self:_ReleaseGamepad(clearInputID)

	-- Register the gamepad if this player is registered to have one
	self.inputID = TheNet:FindInputIDForGUID(self.inst.GUID)
	if self.inputID == INVALID_INPUT_ID then
		self.inputID = nil
	end

	if self.inputID and self.inputID ~= KEYBOARD_INPUT_ID then		-- a gamepad is assigned to this Player
		local device_ent = self.input:GetDeviceOwner("gamepad", self.inputID)
		local is_valid = self.input:IsDeviceValid("gamepad", self.inputID)
		if not is_valid or (device_ent and device_ent ~= self.inst) then
			TheLog.ch.Player:printf("Failed to use native-assigned gamepad id %d (in use[%s] or invalid[%s]).", self.inputID, device_ent, not is_valid)
			self.gamepad_id = nil
		else
			self.gamepad_id = self.input:RegisterDeviceOwner(self.inst, "gamepad", self.inputID)
			if self.gamepad_id then
				TheLog.ch.Player:printf("Registered gamepad %s to player %s", self.inputID, self.inst.Network:GetPlayerID())

				self._OnDeviceUnregistered =
					function(ent, data)
						-- TheLog.ch.Player:printf("deviceunregistered: ent=%s device=%s id=%s", tostring(ent), data.device_type, data.device_id)
						self:OnDeviceUnregistered(data.device_type, data.device_id)
					end

				self.inst:ListenForEvent("deviceunregistered", self._OnDeviceUnregistered)
			end
		end
	end

	local deferred_control_handler = function(controls, down)
		self:DeferControls(controls, down)
	end

	if self.gamepad_id then
		self.gamepadhandler = self.input:AddGeneralControlHandlerForGamepad(self.gamepad_id, deferred_control_handler)
	end

	-- keyboard inputs go to main local player
	if self.inputID == KEYBOARD_INPUT_ID then
		self.handler = self.input:AddGeneralControlHandler(deferred_control_handler)
		TheLog.ch.Player:print("Registered keyboard to player " .. self.inst.Network:GetPlayerID())
	end

	if self.gamepad_id or (self.inputID and self.inputID ~= INVALID_INPUT_ID) then
		self.deferredcontrols = {}
	end

	self.inst:PushEvent("input_device_changed", { self:_GetInputTuple() })
end

function PlayerController:Activate()
	dbassert(not self:IsActivated(), "Trying to Activate() multiple times")

	self:ReInitInputs(true)
end

function PlayerController:Deactivate()
	self:ClearAimPointer()
	self:ClearDeferredControls()
	self.deferredcontrols = nil

	-- only truly release input devices for players that disconnect/leave while in-game
	-- when the world is getting destroyed via nosimreset, those players need to retain input IDs
	local clearInputID = TheWorld and not TheWorld.is_destroying
	self:_ReleaseKeyboard(clearInputID)
	self:_ReleaseGamepad(clearInputID)
end

--------------------------------------------------------------------------

function PlayerController:SetEnabled(val)
end

function PlayerController:IsEnabled()
	local hud = TheDungeon.HUD
	if hud ~= nil then
		local hudfocus, reason = hud:IsHudSinkingInput()
		if hudfocus then
			return false, reason
		end
	end
	return true
end

function PlayerController:IsControlDown(control)
	local device_type = self.gamepad_id ~= nil and "gamepad" or ""
	return self.input:IsControlDown(control, device_type, self.gamepad_id)
end

function PlayerController:IsAnyOfControlsDown(...)
	local device_type = self.gamepad_id ~= nil and "gamepad" or ""
	for i, v in ipairs({...}) do
		if self.input:IsControlDown(v, device_type, self.gamepad_id) then
			return true
		end
	end
end

--------------------------------------------------------------------------

function PlayerController:DeferControls(controls, down)
	dbassert(self.inst:IsValid(), "Invalid self means that entity did not unregister this callback from the input system")
	if self:IsEnabled() then
		local n = #self.deferredcontrols
		local cloned_controls = self.controlspool:Get()
		cloned_controls:Copy(controls)
		self.deferredcontrols[n + 1] = cloned_controls
		self.deferredcontrols[n + 2] = down
		dbassert(#self.deferredcontrols == n + 2)
	end
end

function PlayerController:ClearDeferredControls()
	if self.deferredcontrols == nil then
		return
	end

	for i = 1, #self.deferredcontrols, 2 do
		local controls = self.deferredcontrols[i]
		controls:Clear()
		self.controlspool:Recycle(controls)
		self.deferredcontrols[i] = nil
		self.deferredcontrols[i + 1] = nil
	end
end

function PlayerController:ProcessDeferredControls()
	self:UpdateControlQueue()

	if self.deferredcontrols == nil then
		return
	end

	for i = 1, #self.deferredcontrols, 2 do
		local controls = self.deferredcontrols[i]
		local down = self.deferredcontrols[i + 1]
		self.deferredcontrols[i] = nil
		self.deferredcontrols[i + 1] = nil

		self:OnControl(controls, down)

		controls:Clear()
		self.controlspool:Recycle(controls)

		if self.deferredcontrols == nil then
			--Deactivated
			return
		end
	end

	--Make sure we didn't generate new controls
	dbassert(next(self.deferredcontrols) == nil)
end

function PlayerController:SetInputStealer(target)
	self.input_stealer = target
end

function PlayerController:GetLastInputDeviceType()
	return self.last_input.device_type
end

function PlayerController:_SetLastInputDeviceType(device_type)
	if self.last_input.device_type ~= device_type then
		--TheLog.ch.Player:printf("Last Input Device Change for Player (%s) old=%s new=%s",
		--	tostring(self.inst), self.last_input.device_type, device_type)
		self.last_input.device_type = device_type
		-- Listen to input_device_changed instead so you can tell multiple
		-- gamepads apart (they might have different icons).
		-- self.inst:PushEvent("input_type_changed", device_type)
	end
end

function PlayerController:OnControl(controls, down)
	if not self:IsEnabled() or self.input:IsEditingBlockingGameplay() then
		return
	end

	self:_SetLastInputDeviceType(controls:GetDeviceTypeName())

	if self.input_stealer then
		self.input_stealer:OnControl(controls, down)
		return
	end

	--Placer controls have highest priority
	if self:IsPlacing() then
		if down then
			if controls:Has(Controls.Digital.CLICK_PRIMARY, Controls.Digital.ACCEPT) then
				self:OnCommitPlacer()
			elseif controls:Has(Controls.Digital.CLICK_SECONDARY, Controls.Digital.CANCEL) then
				self:OnCancelPlacer()
			elseif controls:Has(Controls.Digital.SKILL) then
				self:OnFlipPlacer()
			elseif controls:Has(Controls.Digital.USE_POTION) then
				self:OnAdvanceVariation()
			end
		end
		return
	end

	--Process action/combat controls in order of priority
	if controls:Has(Controls.Digital.ACTION) then
		local ismousebtn = controls:IsMouseButton(Controls.Digital.ACTION)
		self:OnActionButton(down, ismousebtn)
		if not self:IsEnabled() then
			return
		end
	end
	if controls:Has(Controls.Digital.USE_POTION) then
		local ismousebtn = controls:IsMouseButton(Controls.Digital.USE_POTION)
		self:OnPotionButton(down, ismousebtn)
		if not self:IsEnabled() then
			return
		end
	end
	if controls:Has(Controls.Digital.DODGE) then
		local ismousebtn = controls:IsMouseButton(Controls.Digital.DODGE)
		self:OnDodgeButton(down, ismousebtn)
		if not self:IsEnabled() then
			return
		end
	end
	if controls:Has(Controls.Digital.SKILL) then
		local ismousebtn = controls:IsMouseButton(Controls.Digital.SKILL)
		self:OnSkillButton(down, ismousebtn)
		if not self:IsEnabled() then
			return
		end
	end
	if controls:Has(Controls.Digital.ATTACK_HEAVY) then
		local ismousebtn = controls:IsMouseButton(Controls.Digital.ATTACK_HEAVY)
		self:OnHeavyAttackButton(down, ismousebtn)
		if not self:IsEnabled() then
			return
		end
	end
	if controls:Has(Controls.Digital.ATTACK_LIGHT) then
		local ismousebtn = controls:IsMouseButton(Controls.Digital.ATTACK_LIGHT)
		self:OnLightAttackButton(down, ismousebtn)
	end

	if controls:Has(Controls.Digital.SHOW_PLAYER_STATUS) then
		self.inst:PeekFollowStatus({showPlayerId = true, showPotionStatus = true, showPowers = true, toggleMode = down and "down" or "up"})
	end

	if controls:Has(Controls.Digital.SHOW_PLAYER_LOADOUT) then
		if not self.inst:IsSpectating() then
			self.inst:PeekPlayerLoadout({ toggleMode = down and "down" or "up" })
		end
	end

	if controls:Has(Controls.Digital.SHOW_EMOTE_RING) then
		if not self.inst:IsSpectating() then
			self.inst:PeekEmoteRing({toggleMode = down and "down" or "up"})
		end
	end

	if controls:Has(Controls.Digital.SHOW_PLAYERS_LIST) then
		TheFrontEnd:PushScreen(PlayersScreen())
	end
end

--------------------------------------------------------------------------

function PlayerController:GetAnalogDir()
	if self.forced_analog_dir then
		return self.forced_analog_dir
	end

	if self.inputID ~= nil then
		local device_type, device_id = self.input:ConvertFromInputID(self.inputID)

		local ignoreDigitalInput = device_type == "gamepad"
		local xdir = self.input:GetAnalogControlValue(Controls.Analog.MOVE_RIGHT, device_type, device_id, ignoreDigitalInput) - self.input:GetAnalogControlValue(Controls.Analog.MOVE_LEFT, device_type, device_id, ignoreDigitalInput)
		local ydir = self.input:GetAnalogControlValue(Controls.Analog.MOVE_DOWN, device_type, device_id, ignoreDigitalInput) - self.input:GetAnalogControlValue(Controls.Analog.MOVE_UP, device_type, device_id, ignoreDigitalInput)

		-- analogs sticks take priority over dpad
		local check_digital_movement = true
		if check_digital_movement and xdir == 0 and ydir == 0 and device_type == "gamepad" and self.gamepad_id then
			xdir = xdir + (self.input:GetDigitalControlValue(Controls.Digital.MOVE_RIGHT, device_type, device_id) - self.input:GetDigitalControlValue(Controls.Digital.MOVE_LEFT, device_type, device_id))
			ydir = ydir + (self.input:GetDigitalControlValue(Controls.Digital.MOVE_DOWN, device_type, device_id) - self.input:GetDigitalControlValue(Controls.Digital.MOVE_UP, device_type, device_id))
		end

		local had_input
		xdir, ydir, had_input = self.input:ApplyDeadZone(xdir, ydir)
		if had_input then
			return math.deg(math.atan(ydir, xdir))
		end
	end
end

function PlayerController:GetRadialMenuDir()
	local device_type = self.gamepad_id ~= nil and "gamepad" or ""
	local xdir = self.input:GetAnalogAxisValue(Controls.Analog.RADIAL_RIGHT, Controls.Analog.RADIAL_LEFT, device_type, self.gamepad_id)
	local ydir = self.input:GetAnalogAxisValue(Controls.Analog.RADIAL_DOWN, Controls.Analog.RADIAL_UP, device_type, self.gamepad_id)
	local had_input
	xdir, ydir, had_input = self.input:ApplyDeadZone(xdir, ydir)

	if had_input then
		local r = math.sqrt(xdir * xdir + ydir * ydir)
		local angle = math.deg(math.atan(ydir, xdir))
		return r, angle
	end
end

-- Force input to automate player movement.
function PlayerController:ForceAnalogMoveDir(dir)
	self.forced_analog_dir = dir
end

--------------------------------------------------------------------------

-- Only plays rumble if valid for player to receive it (right input type, settings).
-- We already automatically rumble via camera shakes, so don't double up!
function PlayerController:TryPlayRumble(...)
	if self:GetLastInputDeviceType() == "gamepad"
		and self.gamepad_id
		and self.gamepad_id ~= INVALID_INPUT_ID
	then
		TheInput:PlayRumble(self.gamepad_id, ...)
	end
end

function PlayerController:TryPlayRumble_IdentifyPlayer()
	self:TryPlayRumble("VIBRATION_PLAYER_IDENTIFY", 1, 0.25)
end

--------------------------------------------------------------------------

local Interactable = require "components.interactable"

function PlayerController:GetInteractableUnderMouse()
	local target = self.input:GetWorldEntityUnderMouse()
	if target and target.GetInteractionClickStealer then
		return target:GetInteractionClickStealer()
	end
	return target
end

function PlayerController:UpdateInteractTarget()
	local x, z = self.inst.Transform:GetWorldXZ()

	local target = self:GetInteractTarget()
	if target ~= nil then
		local interactable = target.components.interactable
		if interactable:IsPlayerInteracting(self.inst) then
			-- Cannot abort an in-progress interaction.
			return
		end
		local radius = interactable:GetRadius()
		if radius > 0
			and target:IsNearXZ(x, z, radius + .5) -- pad to prevent oscillation
			and interactable:CanPlayerInteract(self.inst, true)
		then
			-- Keep current interact target
			return
		end
	end

	local ents = TheSim:FindEntitiesXZ(x, z, Interactable.MAX_RADIUS, { "interactable" })
	for i,candidate in ipairs(ents) do
		local interactable = candidate.components.interactable
		if candidate:IsNearXZ(x, z, interactable:GetRadius())
			and interactable:CanPlayerInteract(self.inst)
		then
			-- Pick new target
			self:SetInteractTarget(candidate)
			return
		end
	end
	self:SetInteractTarget(nil)
end

function PlayerController:SetInteractTarget(target)
	if self.input:IsEditMode()
		and target
		and target:HasTag("prop")
	then
		-- Prevent accidentally picking up and removing objects while editing.
		return
	end

	if target == self.interacttarget then
		return
	end

	--~ TheLog.ch.Player:print("Interaction target change:", self.interacttarget, "->", target)
	local new_interactable = target and target.components.interactable
	dbassert(
		not new_interactable or new_interactable:CanPlayerInteract(self.inst), 
		"Focusing a disallowed interaction."
	)
	
	local old_interactable = self.interacttarget 
		and self.interacttarget:IsValid() 
		and self.interacttarget.components.interactable
	if old_interactable then
		old_interactable:OnLoseInteractFocus(self.inst)
	end

	self.interacttarget = target

	if new_interactable then
		new_interactable:OnGainInteractFocus(self.inst)
	end
end

function PlayerController:GetInteractTarget()
	if self.interacttarget ~= nil and (self.interacttarget.components.interactable == nil or not self.interacttarget:IsValid()) then
		self.interacttarget = nil
	end
	return self.interacttarget
end

function PlayerController:DebugDrawEntity(ui, panel, colors)

	ui:TextColored(colors.header, "General")
	local isenabled, reason = self:IsEnabled()
	ui:Value("Enabled", isenabled and "yes" or "no due to ".. tostring(reason))
	ui:Value("ProcessingActionButtons", not self:_SkipProcessingActionButtons())

	ui:TextColored(colors.header, "Interact")
	if ui:Button("Clear InteractTarget") then
		print("Force clearing InteractTarget.")
		self:SetInteractTarget(nil)
	end
	if ui:Button("UpdateInteractTarget") then
		self:UpdateInteractTarget()
		print("Force updated InteractTarget. Got:", self:GetInteractTarget())
	end

	ui:Text("InteractTarget:")
	ui:SameLineWithSpace()
	panel:AppendTable(ui, self:GetInteractTarget())

	local color = WEBCOLORS.ORANGE
	ui:Value("Interactable.MAX_RADIUS", Interactable.MAX_RADIUS)
	ui:SameLineWithSpace()
	ui:ColorButton("Interaction radius", color)
	local x,z = self.inst.Transform:GetWorldXZ()
	DebugDraw.GroundCircle(x, z, Interactable.MAX_RADIUS, color)

	if ui:CollapsingHeader("Nearby Interactables") then
		local nearby = TheSim:FindEntitiesXZ(x, z, Interactable.MAX_RADIUS, { "interactable" })
		panel:AppendTableInline(ui, nearby, "nearby")
	end

	ui:Value("HUDEntityUnderMouse", self.input:GetHUDEntityUnderMouse())
	ui:Value("WorldEntityUnderMouse", self.input:GetWorldEntityUnderMouse())
	ui:Value("InteractableUnderMouse", self:GetInteractableUnderMouse())
end

--------------------------------------------------------------------------

function PlayerController:MoveCameraTowardsMouse(dt)
	local movement_space = 0.33
	local min_move_speed = 5
	local max_move_speed = 20

	-- Get screenspace position where we clicked
	local sx, sy = TheSim:GetScreenSize()

	local left_bounds_max = sx/2 * -1
	local left_bounds_min = left_bounds_max - (left_bounds_max * movement_space)

	local right_bounds_max = sx/2
	local right_bounds_min = right_bounds_max - (right_bounds_max * movement_space)

	local down_bounds_max = sy/2 * -1
	local down_bounds_min = down_bounds_max - (down_bounds_max * movement_space)

	local up_bounds_max = sy/2
	local up_bounds_min = up_bounds_max - (up_bounds_max * movement_space)

	local mouse_x, mouse_y = TheFrontEnd:GetUIMousePos()

	local horizontal_speed = 0
	if mouse_x < left_bounds_min then
		local total_distance = left_bounds_min - left_bounds_max
		local mouse_distance = math.abs(mouse_x - left_bounds_min)
		horizontal_speed = -easing.inCubic(mouse_distance, min_move_speed, max_move_speed - min_move_speed, total_distance)
	elseif mouse_x > right_bounds_min then
		local total_distance = right_bounds_max - right_bounds_min
		local mouse_distance = math.abs(mouse_x - right_bounds_min)
		horizontal_speed = easing.inCubic(mouse_distance, min_move_speed, max_move_speed - min_move_speed, total_distance)
	end

	local vertical_speed = 0
	if mouse_y < down_bounds_min then
		local total_distance = down_bounds_min - down_bounds_max
		local mouse_distance = math.abs(mouse_y - down_bounds_min)
		vertical_speed = -easing.inCubic(mouse_distance, min_move_speed, max_move_speed - min_move_speed, total_distance)
	elseif mouse_y > up_bounds_min then
		local total_distance = up_bounds_max - up_bounds_min
		local mouse_distance = math.abs(mouse_y - up_bounds_min)
		vertical_speed = easing.inCubic(mouse_distance, min_move_speed, max_move_speed - min_move_speed, total_distance)
	end

	local offset = TheCamera:GetOffset()
	local x = offset.x + (horizontal_speed * dt)
	local z = offset.z + (vertical_speed * dt)
	TheCamera:SetOffset(x, offset.y, z)
end

function PlayerController:OnUpdate(dt)
	if self.forced_analog_dir then
		-- Even update when disabled to allow scripted movement.
		self:_UpdateMovement()
		return
	end

	local isenabled, reason = self:IsEnabled()
	if not isenabled then
		self:ClearDeferredControls()
		self:ClearControlQueue()

		if reason ~= "console" then
			self:StopPlacer()
		end

		-- Convos can have screens appear over top of them.
		if reason ~= "prompt" and reason ~= "screen" then
			self:SetInteractTarget(nil)
		end

		if self.inst.sg:HasStateTag("moving") then
			self.inst.components.locomotor:Stop()
		end
		return
	end

	if self:IsPlacing() then
		self:ClearControlQueue()
		-- self:SetInteractTarget(nil)

		if self.inst.sg:HasStateTag("moving") then
			self.inst.components.locomotor:Stop()
		end

		self:MoveCameraTowardsMouse(dt)

		return
	end

	if not self.inst.sg:HasStateTag("interact") then
		self:UpdateInteractTarget()
	end

	local canmove = true
	if self.inst.sg:HasStateTag("busy") and not self.inst.sg:HasStateTag("canmovewhilebusy") then
		canmove = false	
	end

	if canmove then
		self:_UpdateMovement()

		if self.changed_cursor or self:GetLastInputDeviceType() == "keyboard" then
			local target = self:GetInteractTarget()
			if target
				and self:GetInteractableUnderMouse() == target
			then
				TheFrontEnd:SetCursor(cursor.Style.s.interact)
				self.changed_cursor = true
			else
				self:_ResetCursor()
			end
		end
	end
end

function PlayerController:_UpdateMovement()
	local dir = self:GetAnalogDir()
	if dir ~= nil then
		self.inst.components.locomotor:RunInDirection(dir)
	elseif self.inst.sg:HasStateTag("moving") then
		self.inst.components.locomotor:Stop()
	end
end

function PlayerController:_ResetCursor()
	TheFrontEnd:SetCursor(cursor.Style.s.pointer)
	self.changed_cursor = nil
end

--------------------------------------------------------------------------

function PlayerController:EnterBuildingMode()
	if self.build_mode == false then
		local isenabled, reason = self:IsEnabled()
		if isenabled or reason == "console" then
			self.build_mode = true
		end
	end
end

function PlayerController:ExitBuildingMode()
	if self.build_mode == true then
		self.build_mode = false
	end
end

function PlayerController:IsBuilding()
	return self.build_mode == true
end

--------------------------------------------------------------------------

function PlayerController:StartPlacer(name, validatefn, onplacefn, oncancelfn, isbuilding)
	if self.placer == nil then
		local isenabled, reason = self:IsEnabled()
		if isenabled or reason == "console" then
			self.placer = SpawnPrefab(name, self.inst)
			if self.placer ~= nil then
				self.placer.components.placer:SetValidateFn(validatefn)
				self.placer.components.placer:SetOnPlaceFn(onplacefn)
				self.placer.components.placer:SetOnCancelFn(oncancelfn)
				self.placer.components.placer.isbuilding = isbuilding

				--if DEV_MODE then
				-- if self.placer.components.snaptogrid ~= nil then
				-- 	self.placer.components.snaptogrid:SetDrawGridEnabled(true, RGB(0,255,0,255))
				-- end
				--end

				-- self:SetInteractTarget(nil)
				self.inst.sg:GoToState("idle")
				self.inst:RemoveFromScene()
				-- TheCamera:SetTarget(TheWorld)
				TheCamera:SetZoom(15)
				TheCamera:SetOffset(0, 0, -2)
				TheWorld:PushEvent("startplacing", self.placer)
				return self.placer
			end
		end
	end
end

function PlayerController:StopPlacer()
	if self.placer ~= nil then
		local wasplaced = self.placer.components.placer:HasPlaced()
		self.placer:Remove()
		self.placer = nil
		self.inst.sg:GoToState("idle")
		self.inst:ReturnToScene()
		TheCamera:SetTarget(TheFocalPoint)
		TheCamera:SetZoom(0)
		TheCamera:SetOffset(0, 0, 0)
		TheWorld:PushEvent("stopplacing", wasplaced)
	end
end

function PlayerController:IsPlacing()
	return self.placer ~= nil
end

function PlayerController:OnCommitPlacer()
	if self.placer.components.placer:CanPlace() then
		if not self.placer.components.placer:OnPlace() then
			print("Failed to place "..tostring(self.placer.components.placer.placed_prefab))
		end
		-- self:StopPlacer()
	end
end

function PlayerController:OnAdvanceVariation()
	if self.placer ~= nil then
		self.placer.components.placer:AdvanceVariation()
	end
end

function PlayerController:OnFlipPlacer()
	if self.placer ~= nil then
		self.placer.components.placer:FlipPlacer()
	end
end

function PlayerController:OnCancelPlacer()
	self:StopPlacer()
end

--------------------------------------------------------------------------

function PlayerController:OverrideControlQueueTicks(control, ticks)
	self.controlqueuetickoverrides[control] = ticks
end

function PlayerController:AddControlQueueTicksModifier(control, ticks, source)
	-- If we don't have any mods for this control yet, start a new table.
	if self.controlqueuetickmods[control] == nil then
		self.controlqueuetickmods[control] = {}
	end
	-- Add the new modifier, indexed by the source of the modifier.
	self.controlqueuetickmods[control][source] = ticks
end

function PlayerController:RemoveControlQueueTicksModifier(control, source)
	-- Make sure we're already modifying that button
	if self.controlqueuetickmods[control] ~= nil then
		for src,ticks in pairs(self.controlqueuetickmods[control]) do
			-- Found it!
			if source == src then
				-- Remove the modifier.
				self.controlqueuetickmods[control][source] = nil

				-- If that was the last modifier, clear the table entirely.
				if not next(self.controlqueuetickmods[control]) then
					self.controlqueuetickmods[control] = nil
				end
			end
		end
	end
end

function PlayerController:AddGlobalControlQueueTicksModifier(frames, source)
	self:AddControlQueueTicksModifier("dodge", frames, source)
	self:AddControlQueueTicksModifier("lightattack", frames, source)
	self:AddControlQueueTicksModifier("heavyattack", frames, source)
	self:AddControlQueueTicksModifier("potion", frames, source)
	self:AddControlQueueTicksModifier("skill", frames, source)
end

function PlayerController:RemoveGlobalControlQueueTicksModifier(source)
	self:RemoveControlQueueTicksModifier("dodge", source)
	self:RemoveControlQueueTicksModifier("lightattack", source)
	self:RemoveControlQueueTicksModifier("heavyattack", source)
	self:RemoveControlQueueTicksModifier("potion", source)
	self:RemoveControlQueueTicksModifier("skill", source)
end

function PlayerController:SnapToInteractEvent(data)
	self:ClearControlQueue()
	self:OnControlDownEvent("interact", data)
	self:OnControlUpEvent("interact", data)
end

function PlayerController:OnControlDownEvent(control, data)
	for i = 1, #self.controlqueue do
		if self.controlqueue[i].control == control then
			dbassert(self.controlqueue[i].released)
			table.remove(self.controlqueue, i)
			break
		end
	end
	data.control = control
	data.ticks = 0
	-- verbose control detail
	-- data.simtick = TheSim:GetTick()
	self.controlqueue[#self.controlqueue + 1] = data
	self.inst:PushEvent("controlevent", data)
end

function PlayerController:OnControlUpEvent(control)
	for i = 1, #self.controlqueue do
		local data = self.controlqueue[i]
		if data.control == control then
			if not data.released then
				data.released = true
				self.inst:PushEvent("controlupevent", { control = control })
			end
			break
		end
	end
end

function PlayerController:IsControlHeld(control)
	for i = 1, #self.controlqueue do
		local data = self.controlqueue[i]
		if data.control == control then
			return not data.released
		end
	end
	return false
end

function PlayerController:GetControlHeldTicks(control)
	for i = 1, #self.controlqueue do
		local data = self.controlqueue[i]
		if data.control == control and not data.released then
			--Can be 0 if it went down this frame
			return data.ticks
		end
	end
	return 0
end

function PlayerController:GetQueuedControl(...)
	local nargs = select("#", ...)
	for i = 1, #self.controlqueue do
		local data = self.controlqueue[i]
		if not data.flushed then
			for j = 1, nargs do
				if select(j, ...) == data.control then
					return data
				end
			end
		end
	end
end

function PlayerController:GetQueuedControlExcluding(...)
	local nargs = select("#", ...)
	for i = 1, #self.controlqueue do
		local data = self.controlqueue[i]
		if not data.flushed then
			local exclude = false
			for j = 1, nargs do
				if select(j, ...) == data.control then
					exclude = true
					break
				end
			end
			if not exclude then
				return data
			end
		end
	end
end

function PlayerController:GetNextQueuedControl()
	for i = 1, #self.controlqueue do
		local data = self.controlqueue[i]
		if not data.flushed then
			return data
		end
	end
end

function PlayerController:UpdateControlQueue()
	local j = 1
	for i = 1, #self.controlqueue do
		local data = self.controlqueue[i]
		-- Apply any overrides, if they exist, here
		local queueticks = self.controlqueuetickoverrides[data.control] or self.controlqueueticks[data.control]

		-- Then, if we have any mods, add them here.
		local modticks = 0
		if self.controlqueuetickmods[data.control] ~= nil then
			for source,ticks in pairs(self.controlqueuetickmods[data.control]) do
				modticks = modticks + ticks
			end
			queueticks = queueticks + modticks
		end


		dbassert(queueticks ~= nil, data.control)
		local keep = data.ticks < (queueticks or 0)
		if not keep and not data.released then
			data.flushed = true
			keep = true
		end
		if keep then
			data.ticks = data.ticks + 1
			if j < i then
				self.controlqueue[j] = data
			end
			j = j + 1
		end
	end
	for i = j, #self.controlqueue do
		self.controlqueue[i] = nil
	end
end

--Flush all queued controls
function PlayerController:FlushControlQueue()
	local j = 1
	for i = 1, #self.controlqueue do
		local data = self.controlqueue[i]
		if not data.released then
			data.flushed = true
			if j < i then
				self.controlqueue[j] = data
			end
			j = j + 1
		end
	end
	for i = j, #self.controlqueue do
		self.controlqueue[i] = nil
	end
end

--Flush queued controls up to and including targetdata
function PlayerController:FlushControlQueueAt(targetdata)
	local keepall = false
	local j = 1
	for i = 1, #self.controlqueue do
		local data = self.controlqueue[i]
		local keep = keepall
		if not keep then
			if data == targetdata then
				keepall = true
				--don't keep this data, keepall kicks in next loop
			end
			if not data.released then
				data.flushed = true
				keep = true
			end
		end
		if keep then
			if j < i then
				self.controlqueue[j] = data
			end
			j = j + 1
		end
	end
	dbassert(keepall, "targetdata not found in control queue.")
	for i = j, #self.controlqueue do
		self.controlqueue[i] = nil
	end
end

--Clears our control state as if every control was released
function PlayerController:ClearControlQueue()
	for i = 1, #self.controlqueue do
		local data = self.controlqueue[i]
		self.controlqueue[i] = nil
		if not data.released then
			self.inst:PushEvent("controlupevent", { control = data.control })
		end
	end
	dbassert(next(self.controlqueue) == nil)
end

--------------------------------------------------------------------------

function PlayerController:GetMouseActionDirection()
	local angle_degrees
	if TheInputProxy:IsMouseAiming() then
		-- Convert the entity's position from worldspace to screenspace
		local ent_x, ent_y, ent_z = self.inst.Transform:GetWorldPosition()
		local z_offset = 2 -- Offset the z position slightly so we're comparing from the player's waist, not feet.
		local screen_ent_x, screen_ent_y = TheSim:WorldToScreenXY(ent_x, ent_y, ent_z + z_offset)


		screen_ent_x, screen_ent_y = TheFrontEnd:WindowToUI(screen_ent_x, screen_ent_y)
		screen_ent_x, screen_ent_y = screen_ent_x, -screen_ent_y

		-- Get screenspace position where we clicked
		local mouse_x, mouse_y = TheFrontEnd:GetUIMousePos()

		-- Compare the two
		angle_degrees = math.deg(math.atan(screen_ent_y - mouse_y, mouse_x - screen_ent_x))
	else
		-- Using a controller - just use the joystick angle.
		angle_degrees = self:GetAnalogDir() or self.inst.Transform:GetFacingRotation() -- if no direction is pressed, just use the direction they were facing
	end

	return angle_degrees
end

function PlayerController:_SkipProcessingActionButtons()
	return TheDungeon.HUD and TheDungeon.HUD:IsPreviewingTravel()
end

function PlayerController:OnLightAttackButton(down, ismousebtn)
	if self:_SkipProcessingActionButtons() then
		return
	end

	if down then
		if ismousebtn and self.input:GetHUDEntityUnderMouse() ~= nil then
			return
		end

		local data = {}
		if ismousebtn then
			data.target = self.input:GetWorldEntityUnderMouse()
			if data.target ~= nil then
				data.dir = self.inst:GetAngleTo(data.target)
			else
				data.dir = self:GetMouseActionDirection()
			end
		else
			data.dir = self:GetAnalogDir()
		end

		self:OnControlDownEvent("lightattack", data)
	else
		self:OnControlUpEvent("lightattack")
	end
end

function PlayerController:OnHeavyAttackButton(down, ismousebtn)
	if self:_SkipProcessingActionButtons() then
		return
	end

	if down then
		if ismousebtn and self.input:GetHUDEntityUnderMouse() ~= nil then
			return
		end

		local data = {}
		if ismousebtn then
			data.target = self.input:GetWorldEntityUnderMouse()
			if data.target ~= nil then
				data.dir = self.inst:GetAngleTo(data.target)
			else
				data.dir = self:GetMouseActionDirection()
			end
		else
			data.dir = self:GetAnalogDir()
		end

		self:OnControlDownEvent("heavyattack", data)
	else
		self:OnControlUpEvent("heavyattack")
	end
end

function PlayerController:OnDodgeButton(down, ismousebtn)
	if self:_SkipProcessingActionButtons() then
		return
	end

	if down then
		if ismousebtn and self.input:GetHUDEntityUnderMouse() ~= nil then
			return
		end

		local data = {}
		if ismousebtn then
			data.dir = self.inst:GetAngleToXZ(self.input:GetWorldXZWithHeight(0))
		else
			data.dir = self:GetAnalogDir()
		end

		self:OnControlDownEvent("dodge", data)
	else
		self:OnControlUpEvent("dodge")
	end
end

function PlayerController:OnSkillButton(down, ismousebtn)
	if self:_SkipProcessingActionButtons() then
		return
	end

	if down then
		if ismousebtn and self.input:GetHUDEntityUnderMouse() ~= nil then
			return
		end

		local data = {}
		if ismousebtn or TheInputProxy:IsMouseAiming() and self:GetLastInputDeviceType() == "keyboard" then
			data.dir = self:GetMouseActionDirection()
		else
			data.dir = self:GetAnalogDir()
		end

		self:OnControlDownEvent("skill", data)
	else
		self:OnControlUpEvent("skill")
	end
end

function PlayerController:OnPotionButton(down, ismousebtn)
	if self:_SkipProcessingActionButtons() then
		-- Don't allow accidental drinks while travelling.
		return
	end
	if TheDungeon.HUD:IsCraftMenuOpen() then
		-- potion and navigating tabs are the same key.
		return
	end
	if down then
		if ismousebtn and self.input:GetHUDEntityUnderMouse() ~= nil then
			return
		end

		local data = {}
		if ismousebtn then
			data.dir = self.inst:GetAngleToXZ(self.input:GetWorldXZWithHeight(0))
		else
			data.dir = self:GetAnalogDir()
		end

		self:OnControlDownEvent("potion", data)
	else
		self:OnControlUpEvent("potion")
	end
end

function PlayerController:OnActionButton(down, ismousebtn)
	if self:_SkipProcessingActionButtons() then
		return
	end

	if down then
		local target = self:GetInteractTarget()
		if target == nil then
			return
		elseif ismousebtn then
			if self.input:GetHUDEntityUnderMouse() or self:GetInteractableUnderMouse() ~= target then
				return
			end
		end

		if self.changed_cursor then
			-- TODO: Show fx at cursor position to indicate click?
			self:_ResetCursor()
		end

		local data =
		{
			target = target,
			dir = self.inst:GetAngleTo(target),
		}

		self:OnControlDownEvent("interact", data)
	else
		self:OnControlUpEvent("interact")
	end
end

function PlayerController:OnDeviceUnregistered(device_type, device_id)
	if device_type == "gamepad" and device_id == self.gamepad_id then
		TheLog.ch.Player:printf("Player [%s] unregistered device [%s,%s]", self.inst, device_type, device_id)
		self:_ReleaseGamepad(true)

		-- Owner should be released, but we can't do this assert because native
		-- input assignment is deferred. Can't even DoTaskInTime because
		-- unregister could occur during pause (and we're about to pause
		-- anyway).
		-- assert(TheInput:GetDeviceOwner(device_type, device_id) == nil, "Native didn't release the input owner.")

		if InGamePlay() then
			TheDungeon.HUD:ShowGamepadDisconnectedPopup()
		end
	end
end

function PlayerController:GetDebugString()
	return string.format("interact: %s", tostring(self:GetInteractTarget()))
end


function PlayerController:OnGamepadConnected(connected_device_id)
	-- See what device_id this playercontroller should be linked to
	local device_type, device_id = self.input:ConvertFromInputID(self.inputID)

	if device_type == "gamepad" and device_id == connected_device_id then
		self:ReInitInputs(false)
	end
end


return PlayerController
