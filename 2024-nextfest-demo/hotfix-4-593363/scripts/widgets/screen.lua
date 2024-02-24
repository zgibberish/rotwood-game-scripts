local Enum = require "util.enum"
local Image = require "widgets.image"
local Panel = require "widgets.panel"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local fmodtable = require "defs.sound.fmodtable"
local kassert = require "util.kassert"
local lume = require "util.lume"
local strict = require "util.strict"


local Screen = Class(Widget, function(self, name)
	Widget._ctor(self, name)
	--self.focusstack = {}
	--self.focusindex = 0
	self.handlers = {}
	--self.inst:Hide()
	self.is_screen = true
	self.flush_inputs = true

	-- Partial overlays are the most common, so default to that.
	self:SetAudioCategory(self.AudioCategory.s.PartialOverlay)

	-- Function to handle and propagate input mode changes while the screen is active
	self.on_notify_input_mode_changed = function(old_device_type, new_device_type)
		self:_NotifyInputModeChanged(old_device_type, new_device_type)
	end

	-- Called from here so widgets are notified when added as a child of a
	-- Screen and before the screen is added to the frontend.
	self:_NotifyAddedToScreen(self)
end)

Screen.AudioCategory = Enum{
	"None",           -- No default sounds.
	"Fullscreen",     -- Visibly blocks what's behind it.
	"PartialOverlay", -- Window with stuff visible behind.
	"Popup",          -- Small window with lots visible behind.
}

-- Override in screens to make it easy to test screens with d_open_screen.
--
-- This fallback implementation passes the input player since most screens
-- either take nothing or take the player.
function Screen.DebugConstructScreen(cls, player)
	assert(Screen ~= cls, "Cannot DebugConstructScreen for Screen: it's abstract.")
	return cls(player)
end

-- We usually only assign owning players to player-specific screens (i.e.
-- inventory). The player-specific input component will be used instead of
-- TheInput singleton see FrontEnd:Update.
function Screen:SetOwningPlayer(owningplayer)
	-- Ignore Widget:SetOwningPlayer. We're more strict since ownership limits control.
	-- TheLog.ch.FrontEnd:print("Screen:SetOwningPlayer=" .. tostring(owningplayer))
	self.owningplayer = self:ChangeTrackedEntity(owningplayer, "owningplayer")
	assert(not self.owningplayer or not self.owningplayer:IsLocal() or self.owningplayer.components.playercontroller:HasInputDevice(), "SetOwningPlayer requires an associated input device for local players.")
end

function Screen:GetOwningPlayer()
	-- Ignore Widget:GetOwningPlayer. Buck stops here.
	-- TheLog.ch.FrontEnd:print("Screen:GetOwningPlayer=" .. tostring(self.owningplayer))
	return self.owningplayer
end

function Screen:SetOwningDevice(device_type, device_id)
	assert(self.owningplayer == nil)
	assert(device_type and device_id, "Clearing owning device not yet supported.")
	self.owningdevice = {
		device_type = device_type,
		device_id = device_id,
	}
end

function Screen:CanDeviceInteract(device_type, device_id, device_owner)
	assert(device_type and device_id)
	if self.owningplayer then
		return self.owningplayer == device_owner

	elseif self.owningdeviceid then
		return (self.owningdeviceid.device_type == device_type
			and self.owningdeviceid.device_id == device_id)
	end
	return true
end

function Screen:IsRelativeNavigation()
	if self.owningplayer then
		local last_device = self.owningplayer.components.playercontroller:GetLastInputDeviceType()
		return last_device ~= "mouse"
	end
	return TheFrontEnd:IsRelativeNavigation()
end

-- Prefer Screen:IsRelativeNavigation() unless you are specifically excluding
-- keyboard.
function Screen:IsUsingGamepad()
	if self.owningplayer then
		local last_device = self.owningplayer.components.playercontroller:GetLastInputDeviceType()
		return last_device == "gamepad"
	end
	return TheInput:WasLastGlobalInputGamepad()
end

function Screen:SetAudioCategory(cat)
	dbassert(Screen.AudioCategory:Contains(cat))
	-- Audio people: Setup defaults for each category here:
	if cat == Screen.AudioCategory.s.Fullscreen then
		self:SetAudioSnapshotOverride(fmodtable.Event.FullscreenOverlay_LP)
			:SetAudioEnterOverride(fmodtable.Event.ui_fullscreen_enter)
			:SetAudioExitOverride(fmodtable.Event.ui_fullscreen_exit)
			-- Careful here. This is only okay because fullscreen is not the default.
			:PushAudioParameterWhileOpen(fmodtable.GlobalParameter.Music_InMenu)

	elseif cat == Screen.AudioCategory.s.Popup then
		self:SetAudioSnapshotOverride(fmodtable.Event.PopUp_LP)
			:SetAudioEnterOverride(fmodtable.Event.ui_popup_enter)
			:SetAudioExitOverride(fmodtable.Event.ui_popup_exit)

	elseif cat == Screen.AudioCategory.s.PartialOverlay then
		self:SetAudioSnapshotOverride(fmodtable.Event.PartialOverlay_LP)
			:SetAudioEnterOverride(fmodtable.Event.ui_overlay_enter)
			:SetAudioExitOverride(fmodtable.Event.ui_overlay_exit)

	elseif cat == Screen.AudioCategory.s.None then
		self:SetAudioSnapshotOverride(nil)
			:SetAudioEnterOverride(nil)
			:SetAudioExitOverride(nil)
	end
	return self
end

-- This must be an fmod event that plays a snapshot! That allows us to play
-- multiple snapshots and stack them on top of each other so removing the top
-- one doesn't remove them all.
-- Snapshots of consecutive screens will stack, so you need to control how they
-- interact in fmod (instance limit to 1).
function Screen:SetAudioSnapshotOverride(sound_event)
	dbassert(sound_event == nil or lume.find(fmodtable.Event, sound_event), "SetAudioSnapshotOverride requires an event, not a snapshot.")
	self.snapshot_sound = sound_event
	return self
end
-- Sound that plays on enter. Will be stopped by next screen enter sound.
function Screen:SetAudioEnterOverride(sound_event)
	self.enter_sound = sound_event
	return self
end
-- Sound that plays on exit. Will be stopped by next screen exit sound.
function Screen:SetAudioExitOverride(sound_event)
	self.exit_sound = sound_event
	return self
end

-- So long as this screen is open (but maybe not active or visible), we'll keep
-- this parameter set.
function Screen:PushAudioParameterWhileOpen(param)
	assert(param and type(param) == "string", "Should be an fmodtable entry: fmodtable.GlobalParameter.Music_InMenu")
	self.audio_params_while_open = self.audio_params_while_open or {}
	table.insert(self.audio_params_while_open, param)
	TheFrontEnd:PushAudioParameter(param)
	return self
end


local audiohandles = strict.strictify{
	screen_enter = "screen_enter",
	screen_exit = "screen_exit",
}

-- OnOpen is only called once when this instance is first displayed.
-- OnBecomeInactive is called when another screen is pushed on top and
-- OnBecomeActive when screens are popped off and this screen is displayed
-- again.
--
-- Not hugely different from ctor, but screen is hooked up to fe and active.
function Screen:OnOpen()
	if self.snapshot_sound then
		self.snapshot_handle = TheFrontEnd:GetSound():PlaySound_Autoname(self.snapshot_sound)
	end
	-- Kill any previous enter sound to avoid stacking long sounds.
	TheFrontEnd:GetSound():KillSound(audiohandles.screen_enter)
	TheFrontEnd:GetSound():KillSound(audiohandles.screen_exit)
	if self.enter_sound then
		TheFrontEnd:GetSound():PlaySound(self.enter_sound, audiohandles.screen_enter)
	end
end

function Screen:OnClose()
	for _,param in ipairs(self.audio_params_while_open or table.empty) do
		TheFrontEnd:PopAudioParameter(param)
	end
	TheFrontEnd:GetSound():KillSound(audiohandles.screen_enter)
	TheFrontEnd:GetSound():KillSound(audiohandles.screen_exit)
	if self.exit_sound then
		TheFrontEnd:GetSound():PlaySound(self.exit_sound, audiohandles.screen_exit)
	end
	if self.snapshot_handle then
		TheFrontEnd:GetSound():KillSound(self.snapshot_handle)
		self.snapshot_handle = nil
	end
	if self.close_cb then
		self.close_cb()
	end
end

function Screen:SetCloseCallback(cb)
	assert(not cb or not self.close_cb, "Clobbering close callback.")
	self.close_cb = cb
end

function Screen:OnUpdate(dt)
	Screen._base.OnUpdate(self, dt)
	return true
end

function Screen:OnBecomeInactive()
	self.last_focus = self:GetDeepestFocus()

	-- If this screen lost top, and has brackets, hide them
	if self.selection_brackets then
		self.selection_brackets:Hide()
	end

	TheInput:UnregisterForDeviceChanges(self.on_notify_input_mode_changed)
end

-- Called every time this instance is displayed. See OnOpen.
function Screen:OnBecomeActive()
	TheSim:SetUIRoot(self.inst.entity)
	if self.last_focus and self.last_focus.inst.entity:IsValid() then
		self.last_focus:SetFocus()
	else
		self.last_focus = nil
		if self.default_focus then
			self.default_focus:SetFocus()
		end
	end

	-- If this screen regained top, and should be showing brackets, do it
	if self.selection_brackets
	and (self.focus_brackets_mouse_enabled or TheFrontEnd:IsRelativeNavigation()) then
		self.selection_brackets:Show()
	end

	TheInput:RegisterForDeviceChanges(self.on_notify_input_mode_changed)
end

function Screen:AddEventHandler(event, fn)
	if not self.handlers[event] then
		self.handlers[event] = {}
	end

	self.handlers[event][fn] = true

	return fn
end

function Screen:RemoveEventHandler(event, fn)
	if self.handlers[event] then
		self.handlers[event][fn] = nil
	end
end

function Screen:HandleEvent(type, ...)
	local handlers = self.handlers[type]
	if handlers then
		for k, v in pairs(handlers) do
			k(...)
		end
	end
end

function Screen:SetDefaultFocus()
	if self.default_focus then
		self.default_focus:SetFocus()
		return true
	end
end

function Screen:SetNonInteractive()
	self.is_noninteractive = true
	return self
end

function Screen:OnFocusMove(dir, down)
	-- Never do super. We want to push focus moving down to the focus widget.
	if self.is_noninteractive then
		return false
	end
	local focus = self:GetFE():GetFocusWidget()
	if not focus or focus == self then
		self:SetDefaultFocus()
		focus = self:GetFE():GetFocusWidget()
		kassert.assert_fmt(
			focus,
			"Failed to find a focus widget. Set default_focus or implement SetDefaultFocus on '%s'.",
			self._widgetname
		)
		kassert.assert_fmt(
			focus ~= self,
			"Failed to find nonscreen focus widget. Set default_focus or implement SetDefaultFocus on '%s'.",
			self._widgetname
		)
	end
	return focus:OnFocusMove(dir, down)
end

-- show_immediately makes the focus brackets display on this widget straight away, no animation to it
function Screen:OnFocusChanged(new_focus, show_immediately)
	if self.focus_brackets_enabled
	and new_focus
	and new_focus.can_focus_with_nav
	then
		if self.focus_brackets_mouse_enabled or TheFrontEnd:IsRelativeNavigation() then
			-- Give focus with mouse or direction keys
			if self.selection_brackets:IsShown() == false then
				-- The player moved the gamepad joystick for the first time. Focus on the button
				self.selection_brackets:Show()
			end
			-- Move brackets to the focused element
			self:_UpdateSelectionBrackets(new_focus, show_immediately)
		else
			self.selection_brackets:Hide()
		end
	end
end

function Screen:GetBoundingBox()
	local w, h = RES_X, RES_Y
	if self.fe then
		--w, h = self.fe:GetScreenDims()
		w, h = self:GetSize()
	end

	local x1, y1, x2, y2 = -w / 2, -h / 2, w / 2, h / 2
	return x1, y1, x2, y2
end

function Screen:OnScreenResize(w, h)
	Screen._base.OnScreenResize(self, w, h)
end

function Screen:GetSize()
	local w, h = RES_X, RES_Y
	--local w,h = TheFrontEnd:GetScreenDims()
	return w, h
end

function Screen:IsOnStack()
	if self.fe and self.fe:FindScreen(self) ~= nil then
		return true
	else
		return false
	end
end

function Screen:SinksInput()
	return not self.is_overlay or self.sinks_input
end

function Screen:SetupUnderlay( fade )
    if self.underlay then
        return
    end

    self.underlay = Image( "images/bg_loading/loading.tex" )
    self.underlay:SetAnchors( "fill", "fill" )
    self:AddChild( self.underlay, 1 )
		:MoveToBack()
    if fade then
        self.underlay:SetMultColorAlpha( 0 )
        self.underlay:AlphaTo( 1.0, 0.3, easing.outQuad )
    end
end

function Screen:SetTabLoop(tab_loop)
    for k,v in ipairs(tab_loop) do
        if k == 1 then
            v:SetFocusDir("prev", tab_loop[#tab_loop])
        else
            v:SetFocusDir("prev", tab_loop[k-1])
        end

        if k == #tab_loop then
            v:SetFocusDir("next", tab_loop[1])
        else
            v:SetFocusDir("next", tab_loop[k+1])
        end
    end
end

----------------------------------------------------------------------
-- Animate transitions                                             {{{

-- Offset matches 1.1 scale to ensures we don't see the edges of the screen bg.
local MAX_ANIM_OFFSET = Vector2(150, 150)

-- Simple screen transition animation for basic screens. Some screens should
-- have completely custom transitions, but many can just use this blend from
-- full transparency with a bit of motion.
--
-- Should gracefully handle quitting during animation with _AnimateOutToDirection.
--
-- @param dir Vector2: direction the screen appears from. Try stuff like:
--		-Vector2.unit_x
--		Vector2.unit_y:rotate(math.pi * 2 * 0.25)
--		Vector2.zero -- no movement, just alpha!
--		etc
function Screen:_AnimateInFromDirection(dir, total_duration)
	if self._screentask_anim_in then
		return
	end

	total_duration = total_duration or 0.5
	local offset = dir * MAX_ANIM_OFFSET

	self:StopUpdater(self._screentask_anim_out)
	self._screentask_anim_out = nil

	-- Hide elements
	self:SetMultColorAlpha(0)

	-- Alpha blend is slower to be smoother but still move into place quick.
	local move_duration = total_duration - 0.2

	local start_pos = self:GetPositionAsVec2()
	self._screentask_anim_in = Updater.Series({
			Updater.Parallel({
					Updater.Ease(function(v) self:SetMultColorAlpha(v) end, 0, 1, total_duration, easing.outQuad),
					Updater.Ease(function(v) self:SetScale(v) end, 1.1, 1, move_duration, easing.outQuad),
					Updater.Ease(function(v)
						local step_pos = start_pos + offset * v
						self:SetPosition(step_pos:unpack())
					end, 1, 0, move_duration, easing.outQuad),
				}),
			Updater.Do(function()
				self._screentask_anim_in = nil
			end),
		})

	self:RunUpdater(self._screentask_anim_in)
end

function Screen:_AnimateOutToDirection(dir, total_duration)
	if self._screentask_anim_out then
		return
	end

	total_duration = total_duration or 0.3
	local offset = dir * MAX_ANIM_OFFSET

	self:StopUpdater(self._screentask_anim_in)
	self._screentask_anim_in = nil

	TheFrontEnd:PopScreensAbove(self)
	self:Disable()

	local start_pos = self:GetPositionAsVec2()
	self._screentask_anim_out = Updater.Series({
			Updater.Parallel({
					-- Unlike animate in, we use the same duration for alpha to be a bit faster.
					Updater.Ease(function(v) self:SetMultColorAlpha(v) end, 1, 0, total_duration, easing.outQuad),
					Updater.Ease(function(v) self:SetScale(v) end, 1, 1.1, total_duration, easing.outQuad),
					Updater.Ease(function(v)
						local step_pos = start_pos + offset * v
						self:SetPosition(step_pos:unpack())
					end, 0, 1, total_duration, easing.outQuad),
				}),
			Updater.Do(function()
				self._screentask_anim_out = nil
				TheFrontEnd:PopScreen(self)
			end),
		})

	self:RunUpdater(self._screentask_anim_out)
end


----------------------------------------------------------------------
-- Selection brackets                                              {{{

function Screen:_EnableFocusBrackets(texture, minx, miny, maxx, maxy, border_scale)
	if self.selection_brackets then
		-- Don't add more brackets
		return self
	end

	minx = minx or 78
	miny = miny or 94
	maxx = maxx or 80
	maxy = maxy or 96
	border_scale = border_scale or 0.8

	self.selection_brackets = self:AddChild(Panel(texture or "images/ui_ftf_runsummary/selection_brackets.tex"))
		:SetName("Selection brackets")
		:SetNineSliceCoords(minx, miny, maxx, maxy)
		:SetNineSliceBorderScale(border_scale)
		:SetHiddenBoundingBox(true)
		:IgnoreInput(true)
		:Hide()

	-- Animate them too
	local speed = 1.35
	local amplitude = 14
	self.selection_brackets_w = 100
	self.selection_brackets_h = 100
	self.selection_brackets:RunUpdater(
		Updater.Loop({
			Updater.Ease(function(v) self.selection_brackets:SetSize(self.selection_brackets_w + v, self.selection_brackets_h + v) end, amplitude, 0, speed, easing.inOutQuad),
			Updater.Ease(function(v) self.selection_brackets:SetSize(self.selection_brackets_w + v, self.selection_brackets_h + v) end, 0, amplitude, speed, easing.inOutQuad),
		}))
	return self
end

function Screen:EnableFocusBracketsForGamepad(texture, minx, miny, maxx, maxy, border_scale)
	self.focus_brackets_enabled = true
	self:_EnableFocusBrackets(texture, minx, miny, maxx, maxy, border_scale)
	self:OnFocusChanged(self.default_focus, true)
	return self
end

function Screen:EnableFocusBracketsForGamepadAndMouse(texture, minx, miny, maxx, maxy, border_scale)
	self.focus_brackets_enabled = true
	self.focus_brackets_mouse_enabled = true
	self:_EnableFocusBrackets(texture, minx, miny, maxx, maxy, border_scale)
	self:OnFocusChanged(self.default_focus, true)
	return self
end

-- If show_immediately, then the brackets will show on the target_widget
-- straight away, with no animation. Used when opening a screen
function Screen:_UpdateSelectionBrackets(target_widget, show_immediately)
	if not self.focus_brackets_enabled then return self end

	if self.last_target_widget == target_widget then return self end

	-- Get the brackets' starting position
	local start_pos = self.selection_brackets:GetPositionAsVec2()
	-- Get starting size
	local start_w, start_h = self.selection_brackets:GetSize()

	-- Align them with the target
	self.selection_brackets:LayoutBounds("center", "center", target_widget)
		:Offset(target_widget:GetFocusBracketsOffset())

	-- Get the new position
	local end_pos = self.selection_brackets:GetPositionAsVec2()
	-- And the new size
	local w, h = target_widget:GetScaledSize()
	local end_w, end_h = w + 60, h + 60

	-- If we're starting the brackets right now, don't animate them into place
	-- Just start them at the end position
	if show_immediately then
		start_pos = end_pos
		start_w, start_h = end_w, end_h
	end

	-- Calculate midpoint
	local mid_pos = start_pos:lerp(end_pos, 0.2)
	-- Calculate a perpendicular vector from the midpoint
	local dir = start_pos - end_pos
	dir = dir:perpendicular()
	dir = dir:normalized()
	dir = mid_pos + dir*250

	-- Move them back and animate them in
	self.selection_brackets:SetPos(start_pos.x, start_pos.y)
		:CurveTo(end_pos.x, end_pos.y, dir.x, dir.y, 0.35, easing.outElasticUI)
		:Ease2dTo(function(w, h)
			self.selection_brackets_w = w
			self.selection_brackets_h = h
		end, start_w, end_w, start_h, end_h, 0.1, easing.linear)

	self.last_target_widget = target_widget
	return self
end

----------------------------------------------------------------------{{{

return Screen
