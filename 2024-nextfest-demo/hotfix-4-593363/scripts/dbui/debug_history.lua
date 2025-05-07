local DebugDraw = require "util.debugdraw"
local DebugEntity = require "dbui.debug_entity"
local DebugNodes = require "dbui.debug_nodes"
local FollowCamera = require("cameras/followcamera")
require "constants"

local DebugHistory = Class(DebugNodes.DebugNode, function(self)
	DebugNodes.DebugNode._ctor(self, "Debug History")
	self.HISTORY_DEBUGGING = false
	self.paused = false
	self.history = TheFrontEnd.debugMenu.history
	self.sim_tick_selected = self.history:GetMaxTick()

	--camera
	self.should_lock_camera = false
	self.lock_camera = FollowCamera()
	self.prev_camera = TheCamera

	--input
	self.back_key_down_time = 0
	self.fwd_key_down_time = 0

	if not TheSim:IsDebugPaused() then
		TheSim:ToggleDebugPause()
	end

	--playback
	self.start_playback_tick = self.history:GetMinTick()
	self.end_playback_tick = self.history:GetMaxTick()
	self.looping = true
	self.is_playing = false
	self.time_accum = 0
	self.fps = 30
end)

DebugHistory.PANEL_WIDTH = 550
DebugHistory.PANEL_HEIGHT = 400

function DebugHistory.CanBeOpened()
	return InGamePlay()
end

function DebugHistory:SetLockCamera(should_lock_camera)
	self.should_lock_camera = should_lock_camera
	if self.should_lock_camera then
		self.prev_camera = TheCamera
		self.lock_camera:SetTarget(nil)
		self.lock_camera:SetDistance(50)
		self.lock_camera:Snap()
		TheCamera = self.lock_camera
	else
		TheCamera = self.prev_camera
	end
end

function DebugHistory:GetPlaybackMinTick()
	return math.max( self.start_playback_tick, self.history:GetMinTick() )
end

function DebugHistory:GetPlaybackMaxTick()
	return math.min( self.end_playback_tick, self.history:GetMaxTick() )
end

function DebugHistory:Step(delta)
	if self.is_playing then
		-- if you're doing playback, then clamp to playback ticks, but you need to wait until you're past maxtick to clamp
		-- otherwise you can miss a frame or display the wrong frame
		self.sim_tick_selected = math.clamp(self.sim_tick_selected + delta, self:GetPlaybackMinTick(), self:GetPlaybackMaxTick() + 1)

		if self.sim_tick_selected > self:GetPlaybackMaxTick() then
			if self.looping then
				self.sim_tick_selected = self:GetPlaybackMinTick()
			else
				self.sim_tick_selected = self:GetPlaybackMaxTick()
				self.is_playing = false
			end
		end
	else
		--clamp to min / max ticks
		self.sim_tick_selected = math.clamp(self.sim_tick_selected + delta, self.history:GetMinTick(), self.history:GetMaxTick())
	end

	--play the frame
	self.history:GetAnimHistory():PlayState(self.sim_tick_selected)
end

function DebugHistory:Load()
	self.history:Load()
	if not TheSim:IsDebugPaused() then
		TheSim:ToggleDebugPause()
	end

	self.sim_tick_selected = self.history:GetMaxTick()
	self.history:GetAnimHistory():PlayState(self.sim_tick_selected)
	self:SetLockCamera(true)

	self.start_playback_tick = self.history:GetMinTick()
	self.end_playback_tick = self.history:GetMaxTick()
end

function DebugHistory:Resume()
	self.history:ResumeState()
	self.sim_tick_selected = TheSim:GetTick()
	self:SetLockCamera(false)
	self.is_playing = false
end

function DebugHistory:RenderPanel( ui, node, dt )
	-- Since we operate while sim paused, we need to force flushing or last
	-- frame's lines won't disappear.
	TheDebugRenderer:ForceTickCurrentFrame()

	-- Anything from DebugHistory should open in a new panel so we don't hide
	-- the history node and unpause playback.
	node.open_next_in_new_panel = true

	if self.HISTORY_DEBUGGING and ui:CollapsingHeader( "Debugging" ) then
		ui:Text("max tick: "..tostring(self:GetPlaybackMaxTick()))
		if ui:TreeNode("Self") then
			node:AppendKeyValues(ui, self)
			ui:TreePop()
		end
		if ui:TreeNode("Debug Anim History") then
			self.history:GetAnimHistory():DebugRenderPanel(ui, node, self.sim_tick_selected)
			ui:TreePop()
		end
		if ui:TreeNode("Debug Input History") then
			self.history:GetInputHistory():DebugRenderPanel(ui, node, self.sim_tick_selected)
			ui:TreePop()
		end
		if ui:TreeNode("Debug SG History") then
			self.history:GetSGHistory():DebugRenderPanel(ui, node, self.sim_tick_selected)
			ui:TreePop()
		end
	end

	local camera_changed, should_lock_camera = ui:Checkbox("Lock Camera", self.should_lock_camera)
	if camera_changed then
		self:SetLockCamera(should_lock_camera)
	end

	ui:SameLineWithSpace()
	local debug_changed, should_debug = ui:Checkbox("History Debug", self.HISTORY_DEBUGGING)
	if debug_changed then
		self.HISTORY_DEBUGGING = should_debug
	end

	if ui:Button("Save Replay") then
		self.history:Save()
	end

	ui:SameLineWithSpace()

	if ui:Button("Load Replay") then
		self:Load()
		return
	end

	ui:SameLineWithSpace()

	if ui:Button("Open Save Folder") then
		TheSim:OpenGameSaveFolder()
	end

	if not TheSim:IsDebugPaused() then
		self.sim_tick_selected = self.history:GetMaxTick()
		self.end_playback_tick = self.history:GetMaxTick()
		self.start_playback_tick = self:GetPlaybackMinTick()
	end

	--Sim tick controls
	local sizex, sizey = ui:GetWindowSize()
	ui:PushItemWidth(sizex - 250)
	local changed, new_tick = ui:SliderInt("Sim Tick", self.sim_tick_selected, self.history:GetMinTick(), self.history:GetMaxTick())
	if changed then
		self.sim_tick_selected = new_tick
		self.history:GetAnimHistory():PlayState(self.sim_tick_selected)
		if not TheSim:IsDebugPaused() then
			TheSim:ToggleDebugPause()
		end
	end
	ui:PopItemWidth()

	ui:SameLineWithSpace()
	if ui:Button(ui.icon.playback_step_back, ui.icon.width, nil, self.sim_tick_selected <= self.history:GetMinTick()) then
		self:Step(-1)
	end

	if ui:IsItemHovered() then
		ui:SetTooltip("LEFT-ARROW: Step back 1\nCTRL+LEFT-ARROW: Step back 5")
	end

	local back_pressed = ui:IsItemActive()

	ui:SameLineWithSpace()
	if ui:Button(ui.icon.playback_step_fwd, ui.icon.width, nil, self.sim_tick_selected >= self.history:GetMaxTick()) then
		self:Step(1)
	end

	if ui:IsItemHovered() then
		ui:SetTooltip("RIGHT-ARROW: Step forward 1\nCTRL+RIGHT-ARROW: Step forward 5")
	end

	local fwd_pressed = ui:IsItemActive()

	ui:SameLineWithSpace()
	if ui:Button(TheSim:IsDebugPaused() and "Resume" or "Pause", 60) then
		if TheSim:IsDebugPaused() then
			self:Resume()
		end
		TheSim:ToggleDebugPause()
	end

	if ui:CollapsingHeader( "Playback Controls" ) then

		ui:PushItemWidth(150)
		local min_changed, new_min = ui:SliderInt("##start_tick", self.start_playback_tick, self.history:GetMinTick(), self:GetPlaybackMaxTick())
		if min_changed then
			self.start_playback_tick = new_min
		end
		ui:PopItemWidth()

		ui:SameLineWithSpace(5)

		ui:PushItemWidth(150)
		local max_changed, new_max = ui:SliderInt("Start / End Tick", self.end_playback_tick, self:GetPlaybackMinTick(), self.history:GetMaxTick())
		if max_changed then
			self.end_playback_tick = new_max
		end
		ui:PopItemWidth()

		local loop_changed, new_loopval = ui:Checkbox("Looping", self.looping)
		if loop_changed then
			self.looping = new_loopval
		end

		ui:SameLineWithSpace()
		ui:PushItemWidth(100)
		local fps_changed, new_fps = ui:SliderInt("FPS", self.fps, 0, 60)
		if fps_changed then
			self.fps = new_fps
		end
		ui:PopItemWidth()

		local EditorBase = require "debug.inspectors.editorbase"
		local play_button_pressed = false
		if self.is_playing then
			EditorBase.PushRedButtonColor(self, ui)
			play_button_pressed = ui:Button( "Pause Playback", nil, nil, not TheSim:IsDebugPaused())
			EditorBase.PopButtonColor(self, ui)
		else
			EditorBase.PushGreenButtonColor(self, ui)
			play_button_pressed = ui:Button( "Start Playback", nil, nil, not TheSim:IsDebugPaused())
			EditorBase.PopButtonColor(self, ui)
		end
		if play_button_pressed then
			self.is_playing = not self.is_playing
			if self.sim_tick_selected >= self:GetPlaybackMaxTick() then
				self.sim_tick_selected = self:GetPlaybackMinTick()
			end
		end
	end

	if self.is_playing then
		--play back at fps
		self.time_accum = self.time_accum + dt
		local step_dt = 1/self.fps
		local steps = math.floor( self.time_accum / step_dt )

		if steps > 0 then
			self.time_accum = self.time_accum - step_dt * steps
			self:Step(steps)
		end
	end

	-- If the console is open, don't process keyboard input
	if not TheFrontEnd.console_root.shown then
		if TheInput:IsKeyDown( InputConstants.Keys.RIGHT ) then
			if not self.down then
				self.down = true
				self:Step(TheInput:IsKeyDown( InputConstants.Keys.CTRL ) and 5 or 1)
			else
				fwd_pressed = true
			end
		elseif TheInput:IsKeyDown( InputConstants.Keys.LEFT ) then
			if not self.down then
				self.down = true
				self:Step(TheInput:IsKeyDown( InputConstants.Keys.CTRL ) and -5 or -1)
			else
				back_pressed = true
			end
		else
			self.down = false
		end

		--if back or fwd are held, then repeat the steps
		self.back_key_down_time = back_pressed and self.back_key_down_time + dt or 0
		self.fwd_key_down_time = fwd_pressed and self.fwd_key_down_time + dt or 0

		if self.back_key_down_time > 0.3 then
			self:Step(-1)
		elseif self.fwd_key_down_time > 0.3 then
			self:Step(1)
		end
	end

	local debug_entity = GetDebugEntity() or AllPlayers[1]
	local sg_data = self.history:GetSGHistory():GetFrame(self.sim_tick_selected, debug_entity)
	local debug_name = debug_entity.components.replayproxy and string.format("proxy of %s", debug_entity.components.replayproxy:GetRealEntityPrefabName()) or tostring(debug_entity)
	if ui:CollapsingHeader( string.format("Stategraph (%s)", debug_name), ui.TreeNodeFlags.DefaultOpen ) then
		if not sg_data then
			ui:Text("No stategraph data. Press F1 over an entity to debug it.")
		else
			DebugEntity.RenderStateGraph(ui, node, sg_data)
			if sg_data.hitbox then
				local pt = debug_entity:GetPosition()
				if sg_data.hitbox.enabled then
					DebugDraw.GroundRect(pt.x - sg_data.hitbox.w, pt.z - sg_data.hitbox.h, pt.x + sg_data.hitbox.w, pt.z + sg_data.hitbox.h, BGCOLORS.WHITE)
				end

				if sg_data.hitbox.hitrects then
					for i, v in pairs(sg_data.hitbox.hitrects) do
						DebugDraw.GroundRect(v[1], v[2], v[3], v[4], BGCOLORS.CYAN)
					end
				end

				if sg_data.hitbox.hitcircles then
					for i, v in pairs(sg_data.hitbox.hitcircles) do
						DebugDraw.GroundCircle(v[1], v[2], v[3], BGCOLORS.CYAN)
					end
				end
			end
			if debug_entity.AnimState then
				DebugEntity.RenderAnimStateCurrentAnim(ui, debug_entity.AnimState)
			end
		end
	end

	local components_data = self.history:GetComponentHistory():GetFrame(self.sim_tick_selected, debug_entity)
	if ui:CollapsingHeader( string.format("Components (%s)###Components", debug_name) ) then
		if not components_data then
			ui:Text("No component_data data. Press F1 over an entity to debug it.")
		else
			for component_name, component_data in pairs(components_data) do
				if ui:TreeNode(string.format("%s###Component (%s%s)", component_name, component_name, debug_name)) then
					node:AppendKeyValues(ui, component_data)
					ui:TreePop()
				end
			end
		end
	end

	local brain_data = self.history:GetBrainHistory():GetFrame(self.sim_tick_selected, debug_entity)
	local debug_name = debug_entity.components.replayproxy and string.format("proxy of %s", debug_entity.components.replayproxy:GetRealEntityPrefabName()) or tostring(debug_entity)
	if ui:CollapsingHeader( string.format("Brain (%s)###Brain", debug_name) ) then
		if not brain_data then
			ui:Text("No brain data. Press F1 over an entity to debug it.")
		else
			self.history:GetBrainHistory():DisplayData(ui, node, brain_data)
		end
	end

	local direction_icons = {
		{
			min = -180,
			max = -90,
			icons = {ui.icon.arrow_left, ui.icon.arrow_up}
		},
		{
			min = -90,
			max = 0,
			icons = {ui.icon.arrow_up, ui.icon.arrow_right}
		},
		{
			min = 0,
			max = 90,
			icons = {ui.icon.arrow_right, ui.icon.arrow_down}
		},
		{
			min = 90,
			max = 180,
			icons = {ui.icon.arrow_down, ui.icon.arrow_left}
		},
	}

	local player_data = self.history:GetInputHistory():GetFrame(self.sim_tick_selected)
	if player_data and table.numkeys(player_data) > 0 then
		--display input history
		ui:Columns(table.numkeys(player_data), "players")
		for id, frame_data in pairs(player_data) do
			if ui:CollapsingHeader( string.format("Player ID: %s", id), ui.TreeNodeFlags.DefaultOpen ) then
				ui:BeginChild(tostring(id))
				ui:Columns(2, tostring(id))
				for control_name, val in pairs(frame_data.controls) do
					ui:PushStyleColor(ui.Col.Text, val and WEBCOLORS.WHITE or WEBCOLORS.RED)

					ui:Text( control_name )
					ui:NextColumn()

					if control_name == "Analog Dir" and type(val) == "number" then
						local icons = nil
						for _, v in ipairs(direction_icons) do
							if val == v.min then
								icons = {v.icons[1]}
							elseif val == v.max then
								icons = {v.icons[2]}
							elseif val > v.min and val < v.max then
								icons = v.icons
							end

							if icons ~= nil then
								break
							end
						end
						ui:Text( table.concat(icons, " ") )
						ui:SameLineWithSpace()
					end
					ui:Text( val )
					ui:NextColumn()

					ui:PopStyleColor()
				end
				ui:Columns(1, tostring(id))
				ui:EndChild();
			end
			ui:NextColumn()
		end
		ui:Columns(1, "players")
	end

	if ui:CollapsingHeader("Usage/Help") then
		-- Add more usage notes or shortcuts here.
		ui:TextWrapped("Hitboxes: only visible for the debug entity. Use F1 to select.")
	end
end

function DebugHistory:OnDeactivate()
	if TheSim:IsDebugPaused() then
		self:Resume()
		TheSim:ToggleDebugPause()
	end
end

DebugNodes.DebugHistory = DebugHistory

return DebugHistory
