local DebugNodes = require "dbui.debug_nodes"
local DebugSettings = require "debug.inspectors.debugsettings"


local DebugCamera = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug Camera")
	self.free_camera = false
	self.pan_toggle_down = false
	self.pan_mode = false
	self.camera_helper_mode = false
	self.saved = DebugSettings("debugcamera.saved.")
		:Option("enabled", false)
		:Option("min_zoom", -35)
		:Option("max_zoom", 20)
		:Option("zoom_scale", 0.2)
		:Option("pan_scale", 0.2)
		:Option("gamepad_id", 0 )
end)

DebugCamera.PANEL_WIDTH = 500
DebugCamera.PANEL_HEIGHT = 400

function DebugCamera:Update()
	if not self.saved.enabled then
		return
	end

	local player = GetDebugPlayer()
	if not player then
		return
	end

	-- Once per game launch, force show DebugCamera if it's running. Avoids
	-- problems where Pan Mode was enabled but forgotten, and it mysteriously
	-- messes with inputs.
	if not TheSaveSystem.cheats:GetValue("debugcam_has_force_shown") then
        TheSaveSystem.cheats:SetValue("debugcam_has_force_shown", true)
		DebugCamera:FindOrCreateEditor()
	end

	if not self.default_pitch then
		--store defaults for reset
		self.default_pitch = TheCamera:GetPitch()
		self.default_fov = TheCamera:GetFOV()
	end

	self.saved.gamepad_id = self.saved.gamepad_id ~= 0 and self.saved.gamepad_id or player.components.playercontroller.gamepad_id

	if self.saved.gamepad_id == nil then
		self.saved.gamepad_id = 0
	end

	if TheInput:IsControlDown(Controls.Digital.RADIAL_ACTION, "gamepad", self.saved.gamepad_id) then
		if not self.pan_toggle_down then
			self:TogglePanMode()
		end
		self.pan_toggle_down = true
	else
		self.pan_toggle_down = false
	end

	if TheInput:IsKeyDown(InputConstants.Keys.F) then
		local inst = ConsoleWorldEntityUnderMouse()
		if inst then
			TheCamera:SetTarget(inst)
		end
	end

	if TheInput:IsKeyDown(InputConstants.Keys.R) then
		self:Reset()
	end

	if self.pan_mode then
		self:PanCamera(
			TheInput:GetAnalogControlValue(Controls.Analog.RADIAL_UP, "gamepad", self.saved.gamepad_id),
			TheInput:GetAnalogControlValue(Controls.Analog.RADIAL_DOWN, "gamepad", self.saved.gamepad_id),
			TheInput:GetAnalogControlValue(Controls.Analog.RADIAL_LEFT, "gamepad", self.saved.gamepad_id),
			TheInput:GetAnalogControlValue(Controls.Analog.RADIAL_RIGHT, "gamepad", self.saved.gamepad_id)
			)
	else
		local input_up = TheInput:GetAnalogControlValue(Controls.Analog.RADIAL_UP, "gamepad", self.saved.gamepad_id)
		local input_down = TheInput:GetAnalogControlValue(Controls.Analog.RADIAL_DOWN, "gamepad", self.saved.gamepad_id)
		input_up, input_down = TheInput:ApplyDeadZone(input_up, input_down)

		if input_up ~= 0 then
			TheCamera:SetZoom( TheCamera:GetZoom() - input_up*input_up*self.saved.zoom_scale )
		elseif input_down ~= 0 then
			TheCamera:SetZoom( TheCamera:GetZoom() + input_down*input_down*self.saved.zoom_scale )
		end

		local zoom = TheCamera:GetZoom()
		zoom = math.clamp(zoom, self.saved.min_zoom, self.saved.max_zoom)
		TheCamera:SetZoom(zoom)
	end

	if self.camera_helper_mode then
		self:PanCamera(
			TheInput:GetAnalogControlValue(Controls.Analog.MOVE_UP, "gamepad", self.saved.gamepad_id),
			TheInput:GetAnalogControlValue(Controls.Analog.MOVE_DOWN, "gamepad", self.saved.gamepad_id),
			TheInput:GetAnalogControlValue(Controls.Analog.MOVE_LEFT, "gamepad", self.saved.gamepad_id),
			TheInput:GetAnalogControlValue(Controls.Analog.MOVE_RIGHT, "gamepad", self.saved.gamepad_id)
			)
	end
end

function DebugCamera:PanCamera( up, down, left, right )
	local offset = TheCamera:GetOffset()

	up, down = TheInput:ApplyDeadZone(up, down)
	left, right = TheInput:ApplyDeadZone(left, right)

	if up ~= 0 then
		offset.z = offset.z + up*up*self.saved.pan_scale
	elseif down ~= 0 then
		offset.z = offset.z - down*down*self.saved.pan_scale
	end

	if left ~= 0 then
		offset.x = offset.x - left*left*self.saved.pan_scale
	elseif right ~= 0 then
		offset.x = offset.x + right*right*self.saved.pan_scale
	end

	TheCamera:SetOffset(offset.x, offset.y, offset.z)
end

function DebugCamera:ToggleFreeCamera()
	if self.free_camera then
		self.free_camera = false
		TheCamera:SetTarget(GetDebugPlayer())
		TheCamera:SetOffset(0,0,0)
		TheCamera:Snap()
	else
		self.free_camera = true
		TheCamera:SetTarget(nil)
		TheCamera:Snap()
	end
end

function DebugCamera:Reset()
	TheCamera:SetZoom(0)
	TheCamera:SetOffset(0,0,0)
	TheCamera:SetPitch(self.default_pitch)
	TheCamera:SetFOV(self.default_fov)
	TheCamera:SetTarget(GetDebugPlayer())
	self.free_camera = false
end

function DebugCamera:TogglePanMode()
	self.pan_mode = not self.pan_mode
end

function DebugCamera:ToggleHelperMode()
	self.camera_helper_mode = not self.camera_helper_mode
end

function DebugCamera:RenderPanel( ui, panel )

	ui:Text("Hover me for help on using the Camera Tool")
	if ui:IsItemHovered() then
		ui:BeginTooltip()
		ui:Text("- When Camera is not in pan mode, use the RStick to zoom the camera")
		ui:Text("- When Camera is in pan mode, use the RStick to pan the camera")
		ui:Text("- Click the RStick to toggle pan vs zoom mode")
		ui:Text("- The RStick uses a Quadratic Lerp")
		ui:Text("- Zoom and pan scale changes how sensitive the RStick is")
		ui:Text("- Press F to set the focus of the camera to the entity under the mouse")
		ui:Text("- Press R to reset the camera")
		ui:EndTooltip()
	end

	local changed, value = ui:Checkbox( "Enabled", self.saved.enabled )
	if changed then
		self.saved:Set("enabled", value)
		self.saved:Save()
	end

	if ui:IsItemHovered() then
		ui:SetTooltip("Enables camera controls on the gamepad. Works even if this panel is closed.")
	end

	ui:SameLineWithSpace()
	changed, value = ui:Checkbox( "Pan Mode", self.pan_mode )
	if changed then
		self:TogglePanMode()
	end

	if ui:IsItemHovered() then
		ui:SetTooltip("Makes it so RStick pans instead of zooms")
	end

	ui:SameLineWithSpace()
	changed, value = ui:Checkbox( "Helper Mode", self.camera_helper_mode )
	if changed then
		self:ToggleHelperMode()
	end

	if ui:IsItemHovered() then
		ui:SetTooltip("Makes it so Lstick pans. Good for a camera helper.")
	end

	ui:SameLineWithSpace()
	changed, value = ui:Checkbox( "Free Camera", self.free_camera )
	if changed then
		self:ToggleFreeCamera()
	end

	if ui:IsItemHovered() then
		ui:SetTooltip("Makes it so the camera is no longer following an entity.")
	end

	local gamepad_ids = {}
	for i = 1, TheInput:GetGamepadCount() do
		table.insert(gamepad_ids, i )
	end

	local changed, idx = ui:Combo("Gamepad", self.saved.gamepad_id, gamepad_ids)
	if changed then
		self.saved:Set("gamepad_id", gamepad_ids[idx])
		self.saved:Save()
	end

	changed, value = ui:SliderInt( "Zoom", TheCamera:GetZoom(), self.saved.min_zoom, self.saved.max_zoom)
	if changed then
		TheCamera:SetZoom(value)
	end

	ui:PushItemWidth(150)
	changed, value = ui:SliderInt( "###min_zoom", self.saved.min_zoom, -50, 0)
	if changed then
		self.saved:Set("min_zoom", value)
		self.saved:Save()
	end
	ui:PopItemWidth()

	ui:SameLineWithSpace()

	ui:PushItemWidth(150)
	changed, value = ui:SliderInt( "Min/Max Zoom###max_zoom", self.saved.max_zoom, 0, 50)
	if changed then
		self.saved:Set("max_zoom", value)
		self.saved:Save()
	end
	ui:PopItemWidth()

	changed, value = ui:SliderFloat( "Zoom Scale", self.saved.zoom_scale, 0.1, 2)
	if changed then
		self.saved:Set("zoom_scale", value)
		self.saved:Save()
	end

	changed, value = ui:SliderFloat( "Pan Scale", self.saved.pan_scale, 0.1, 2)
	if changed then
		self.saved:Set("pan_scale", value)
		self.saved:Save()
	end

	if ui:Button("Reset Camera") then
		self:Reset()
	end

	if ui:CollapsingHeader( "Advanced" ) then
		changed, value = ui:SliderFloat( "Set FOV", TheCamera:GetFOV(), 0, 100)
		if changed then
			TheCamera:SetFOV(value)
		end

		changed, value = ui:SliderFloat( "Set Pitch", TheCamera:GetPitch(), 10, 30)
		if changed then
			TheCamera:SetPitch(value)
		end
	end

	if ui:CollapsingHeader( "Camera Info" ) then
		ui:Text("Zoom level: "..tostring(TheCamera:GetZoom()))
		ui:Text("Fov: "..tostring(TheCamera:GetFOV()))
		ui:Text("Pitch: "..tostring(TheCamera:GetPitch()))
		local offset = TheCamera:GetOffset()
		ui:Text(string.format("Offset: %.1f, %.1f, %.1f", offset.x, offset.y, offset.z))
		ui:Text("Target: "..tostring(TheCamera:GetTarget()))
		ui:Text("Pos: "..tostring(TheCamera.currentpos))
		if ui:Button("Raw Debug TheCamera") then
			panel:PushDebugValue(TheCamera)
		end
	end
end

DebugNodes.DebugCamera = DebugCamera

return DebugCamera
