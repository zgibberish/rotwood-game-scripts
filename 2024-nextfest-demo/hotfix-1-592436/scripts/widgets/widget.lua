local min, max = math.min, math.max

local Bound2 = require "math.modules.bound2"
local DebugPickers = require "dbui.debug_pickers"
local Enum = require "util.enum"
local TrackEntity = require "util.trackentity"
local easing = require "util.easing"
local fmodtable = require "defs.sound.fmodtable"
local kassert = require "util.kassert"
local lume = require "util.lume"
require "mathutil"

-- Global because we use it so much.
global "Updater"
Updater = require "ui.updater"

local function WidgetEntity_Remove(inst)
	assert(inst.has_removed_widget, "Don't call inst:Remove() on widgets! Use widget:Remove() instead.")
	return EntityScript.Remove(inst)
end


local Widget = Class(function(self, name)
	name = name or "Widget"

	self._widgetname = name

	-- Uncomment to see where widgets were created in DebugWidget.
	--~ self.creation_stack = debugstack()

	self.inst = CreateEntity()
		:MakeSurviveRoomTravel()
	self.inst.widget = self
	self.inst.name = name
	self.inst.Remove = WidgetEntity_Remove

	self.inst:AddTag("widget")
	self.inst:AddTag("UI")
	self.inst.entity:SetName(name)
	self.inst.entity:AddUITransform()

	self.enabled = true
	self.shown = true
	self.focus = false
	self.can_fade_alpha = true
	self.propagate_bb = true

	------------------------------------------- NEW
	self.children = table.empty
	self.focus_targets = nil
	self.dirtytransform = false


	self.node = self.inst.UITransform
	assert(self.node)
	self.hover = false

	self.x = 0
	self.y = 0
	self.z = 0
	self.sx = 1
	self.sy = 1
	self.r = 0
	self.layout_scale = 1

	self.hanchor = nil
	self.vanchor = nil
	self.anchorx = 0
	self.anchory = 0
	self.visible = false

	self.bboxcache = {valid = true, x1 = 0, y1 = 0, x2 = 0, y2 = 0 }

	--Special modes
	self.blocks_mouse = false
	self.hover_check = false
	self.fullscreen_hit = false

	-- Left click
	self.controldown_sound = fmodtable.Event.input_down
	self.controlup_sound = fmodtable.Event.input_up
	-- Right click
	self.altcontroldown_sound = fmodtable.Event.input_down
	self.altcontrolup_sound = fmodtable.Event.input_up
end)

Widget.DebugNodeName = "DebugWidget"

-- Make it easy to tack on a :DebugEdit() to init.
--
-- Don't submit code calling this function! You can call it after constructing
-- your widget to skip the interactive selection, but we don't want this
-- sprinkled throughout the code (don't want imgui activating unless
-- user-triggered).
function Widget:DebugEdit()
	print("Widget:DebugEdit called. Be sure to remove before submit!", debugstack())
	d_viewinpanel_autosize(self, true)
	return self
end

-- We usually only assign owning players to player-specific screens (i.e.
-- inventory), but sometimes we assign it to widgets (weapon tips, interact
-- prompts). Ownership allows "<p bind='Controls.Digital.ACTION'>" strings to
-- get the correct player.
function Widget:SetOwningPlayer(owningplayer)
	kassert.assert_fmt(
		not owningplayer -- You can clear before set to avoid this assert.
		or not self._widget_owningplayer
		or self._widget_owningplayer == owningplayer,
		"Changing owning player won't automatically apply to already constructed widgets using the previous player's state: [%s] -> [%s]. Better to rebuild the widget instead.",
		self._widget_owningplayer, owningplayer)
	-- TheLog.ch.FrontEnd:print("Widget:SetOwningPlayer=" .. tostring(owningplayer))
	-- Weird _name to prevent name clashes in children.
	self._widget_owningplayer = self:ChangeTrackedEntity(owningplayer, "_widget_owningplayer")
	return self
end

-- The player this widget represents or who we're displaying information for.
-- If it's nil, you may want to call in OnAddedToScreen.
function Widget:GetOwningPlayer()
	if self._widget_owningplayer then
		return self._widget_owningplayer
	end
	if self.parent then
		-- Recursion instead of iteration because Screen:GetOwningPlayer
		-- behaves differently.
		return self.parent:GetOwningPlayer()
	end
end

function Widget:IsDeepestFocus()
	if self.focus then
		for k,v in pairs(self.children) do
			if v.focus then return false end
		end
	end

	return true
end

function Widget:OnMouseButton(button, down, x, y)
	if not self.focus then return false end

	for k,v in pairs (self.children) do
		if v.focus and v:OnMouseButton(button, down, x, y) then return true end
	end
end


local direction_opposites =
{
	left = "right",
	right = "left",
	up = "down",
	down = "up",
	["next"] = "prev",
	prev = "next",
}

function Widget:ClearFocusDirs()
	self.focus_targets = nil
end

function Widget:SetFocusDir(direction, target, bidirectional, force_visible)
	self.focus_targets = self.focus_targets or {}
	self.focus_targets[direction] = target
	if bidirectional and target then
		target:SetFocusDir(direction_opposites[direction], self)
	end
	return self
end

function Widget:GetFocusDir(direction)
	if self.focus_lock then
		return self
	elseif self.focus_targets then
		local w = self.focus_targets[direction]
		if w and w.removed then
			self.focus_targets[direction] = nil
		else
			return w
		end
	end
end

-- Focus lock prevents focus from leaving this Widget or its children via OnFocusMove
-- by forwarding focus to itself.
function Widget:SetFocusLock( focus_lock )
    self.focus_lock = focus_lock
    return self
end

function Widget:HasFocusLock()
    return self.focus_lock
end

local function ScoreFocusChangeCandidate(dir, from, to)
	local from_x1, from_y1, from_x2, from_y2 = from:GetWorldBoundingBox()
	local to_x1, to_y1, to_x2, to_y2 = to:GetWorldBoundingBox()

	if (dir == "right" and to_x1 > from_x1 and to_x2 > from_x2) then
		return CalculateRectDistance(
			from_x1, from_y1, from_x2, from_y2,
			to_x1, to_y1, to_x2, to_y2 )

	elseif dir == "left" and to_x1 < from_x1 and to_x2 < from_x2 then
		return CalculateRectDistance(
			from_x1, from_y1, from_x2, from_y2,
			to_x1, to_y1, to_x2, to_y2 )

	elseif dir == "up" and to_y1 > from_y1 and to_y2 > from_y2 then
		return CalculateRectDistance(
			from_x1, from_y1, from_x2, from_y2,
			to_x1, to_y1, to_x2, to_y2 )

	elseif dir == "down" and to_y1 < from_y1 and to_y2 < from_y2 then
		return CalculateRectDistance(
			from_x1, from_y1, from_x2, from_y2,
			to_x1, to_y1, to_x2, to_y2 )
	end
end


function Widget:FindFocusWidget(dir, from, ignore_child)
	assert( dir and from )
	if not self.shown
		or self.ignore_input
		or self.dragging
	then
		return
	end

	if self.can_focus_with_nav then
		local score = ScoreFocusChangeCandidate( dir, from, self )
		if score or from:GetFocusDir( dir ) == self then
			-- print( from, dir, self, score )
			return self, score
		end

	else
		local best_widget, best_score
		local default_focus
		if self.default_focus
			and not self.default_focus.removed
			and self.default_focus.shown
			and not self:IsAncestorOf(from)
		then
			default_focus = self.default_focus
		end

		for i, child in ipairs( self.children ) do
			if child ~= ignore_child then
				local widget, score = child:FindFocusWidget( dir, from )
				if widget and (best_score == nil or score < best_score) then
					best_widget, best_score = widget, score
				end
			end
		end

		if best_widget then
			return default_focus or best_widget, best_score
		end
	end

	-- Found nothing, crawl up the parent.
	if ignore_child ~= nil and self.parent and not self.is_screen then
		local to = self:GetFocusDir( dir ) or self.parent
		if to ~= self then
			assert( not self:IsAncestorOf( to ))
			return to:FindFocusWidget( dir, from, self )
		end
	end
end

function Widget:OnFocusMove(dir, down)
--print ("OnFocusMove", self._widgetname or "?", self.focus, dir, down)
	-- Unlike GL, we generally call OnFocusMove on the focused widget (instead
	-- of every widget trying to move focus). Use SetFocus if you need to make
	-- another widget focused first.)
	local to = self:GetFocusDir( dir ) or self.parent
	-- print( "OnFocusMove", self, dir, to )
	if to == self then
		self:OnFocusNudge( dir )
		return true
	else
		local focus, score = to:FindFocusWidget( dir, self, self )
		if focus then
			-- print( "\tNew Focus:", focus, score )
			focus:SetFocus()
			return true
		else
			self:OnFocusNudge( dir )
			return false
		end
	end
end

-- When trying to navigate in a direction and there are no widgets to move
-- focus to, animate this widget to show input happened.
function Widget:OnFocusNudge(direction)
	local distance = 15
	local duration = 0.1
	self:Nudge(direction, distance, duration, easing.outQuad, easing.inOutQuad)
	--TheFrontEnd:GetSound():PlaySound(fmodtable.Event.error_bump)
	return self
end

function Widget:Nudge(direction, distance, duration, ease_out, ease_in, ondone_nudge_fn)
	if not self.nudging then
		self.nudging = true
		self.nudge_x, self.nudge_y = self:GetPos()
		if direction == "prev" or direction == "left" then
			self.nudge_x_target = self.nudge_x-distance
			self.nudge_y_target = self.nudge_y
		elseif direction == "next" or direction == "right" then
			self.nudge_x_target = self.nudge_x+distance
			self.nudge_y_target = self.nudge_y
		elseif direction == "down" then
			self.nudge_x_target = self.nudge_x
			self.nudge_y_target = self.nudge_y-distance
		elseif direction == "up" then
			self.nudge_x_target = self.nudge_x
			self.nudge_y_target = self.nudge_y+distance
		end
		self:MoveTo( self.nudge_x_target, self.nudge_y_target, duration, ease_out, 
			function() 
				self:MoveTo( self.nudge_x, self.nudge_y, duration, ease_in, 
				function() 
					self.nudging = false
					if ondone_nudge_fn then
						ondone_nudge_fn(self)
					end
				end)
			end
		)
	end
	return self
end

-- If the focus brackets need some nudging to look correct around this widget
function Widget:SetFocusBracketsOffset(x_offset, y_offset)
	self.x_offset = x_offset or 0
	self.y_offset = y_offset or 0
	return self
end

function Widget:GetFocusBracketsOffset()
	return self.x_offset or 0, self.y_offset or 0
end

function Widget:IsVisible()
	return self.shown and (self.parent == nil or self.parent:IsVisible())
end

function Widget:OnRawKey(key, down)
	if down then
		self:OnRawKeyDown(key)
	else
		self:OnRawKeyUp(key)
	end
end

function Widget:OnRawKeyDown(key)
	if not self.focus then return false end
	for k,v in pairs (self.children) do
		if v.focus and v:OnRawKeyDown(key) then return true end
	end
        if self.HandleRawKeyDown and self:HandleRawKeyDown(key) then
       	    return true
	end
end

function Widget:OnRawKeyUp(key)
	if not self.focus then return false end
	for k,v in pairs (self.children) do
		if v.focus and v:OnRawKeyUp(key) then return true end
	end
        if self.HandleRawKeyUp and self:HandleRawKeyUp(key) then
       	    return true
	end
end

function Widget:OnTextInput(text)
	--print ("text", self, text)
	if not self.focus then return false end
	for k,v in pairs (self.children) do
		if v.focus and v:OnTextInput(text) then return true end
	end
        if self.HandleTextInput and self:HandleTextInput(text) then
            return true
        end

end

function Widget:OnStopForceProcessTextInput()
end

-- Called when the *global* last input mode changes.
-- Notifies all children as well.
function Widget:_NotifyInputModeChanged(old_device_type, new_device_type)
	for k,v in pairs (self.children) do
		v:_NotifyInputModeChanged(old_device_type, new_device_type)
	end
	self:OnInputModeChanged(old_device_type, new_device_type)
end

-- Override for notifications when the *global* input mode changes. Hopefully
-- rarely necessary if you SetOwningPlayer on your widgets (since Text auto
-- adjusts for changes in its owning player's input state). We have multiple
-- players, so usually you want to track the owning player's state instead of
-- global input state.
function Widget:OnInputModeChanged(old_device_type, new_device_type)
end


function Widget:OnControl(controls, down, device_type, trace, device_id)
end



function Widget:OnControlDown(controls, device_type, trace, device_id)
	if trace then
		trace:PushWidget( self )
	end

	if not self.ignore_input and self.shown then

		if self.enabled then

			if self.HandlePreControlDown and self:HandlePreControlDown(controls, device_type, trace, device_id) then
				if trace then
					trace:PopWidget( "true: handled by self" )
				end
				return true
			end

			for k = 1, #self.children do
				local v = self.children[k]
				if v and (v.focus or v.hover) then
					if v:OnControlDown(controls, device_type, trace, device_id) then
						if trace then
							trace:PopWidget( "true: handled by child" )
						end
						return true
					end
				end
			end

			if self.HandleControlDown and self:HandleControlDown(controls, device_type, trace, device_id) then
				if trace then
					trace:PopWidget( "true: handled by self" )
				end
				return true
			end
		end


		-- Unlike GL, we send OnFocusMove from FrontEnd so we can control
		-- repeat delay instead of doing it here.

		if not self.enabled then
			if trace then
				trace:PopWidget( "false: not enabled" )
			end
			return self.blocks_mouse and ( device_type == "mouse" or device_type == "touch" )
		 end


		if self.blocks_mouse and ( device_type == "mouse" or device_type == "touch" ) then
			if not controls:Has(Controls.Digital.MENU_SCROLL_FWD, Controls.Digital.MENU_SCROLL_BACK) then
				if trace then
					trace:PopWidget( "true: blocks_mouse" )
				end
				return true
			end
		end
	end

	if trace then
		trace:PopWidget( "false" )
	end
end

function Widget:GetControlMap()
	return self.CONTROL_MAP, self
end

-- This is how GL uses CONTROL_MAP to display button prompts at the bottom of
-- the screen. Maybe we want to put the button icons in the buttons themselves,
-- so we wouldn't use this.
--~ function Widget:CollectControlHints(left, right, handled)
--~ 	handled = handled or {}
--~ 	if self.children then
--~ 		for k,v in ipairs(self.children) do
--~ 			if v.focus then
--~ 				v:CollectControlHints(left, right, handled)
--~ 			end
--~ 		end
--~ 	end

--~ 	local control_map, owner = self:GetControlMap()
--~ 	if control_map then
--~ 		for k,mapping in ipairs(control_map) do
--~ 			if mapping.hint and (not mapping.control or not handled[mapping.control]) and (not mapping.test or mapping.test(owner)) then
--~ 				if mapping.control then
--~ 					handled[mapping.control] = owner
--~ 				end
--~ 				mapping.hint(owner, left, right)
--~ 			end
--~ 		end
--~ 	end
--~ end

-- Shims so we can use our old OnControl. I still don't know if we should pull apart into ControlUp and ControlDown
function Widget:HandleControlDown(controls, device_type, trace, device_id)
	return self:OnControl(controls, true, device_type, trace, device_id)
end

function Widget:HandleControlUp(controls, device_type, trace, device_id)
	return self:OnControl(controls, false, device_type, trace, device_id)
end

function Widget:OnControlUp(controls, device_type, trace, device_id)
	if not self.ignore_input and self.shown then
		if not self.enabled then
			return self.blocks_mouse
		end

		for k = 1, #self.children do
			local v = self.children[k]
			if v and (v.focus or v.hover) then
				if v:OnControlUp(controls, device_type, trace, device_id) then
					return true
				end
			end
		end

		local control_map, owner = self:GetControlMap()

		if control_map then
			for _,mapping in ipairs(control_map) do
				if (mapping.control and controls:Has( mapping.control ))
					or (mapping.controls and controls:Has( table.unpack( mapping.controls )))
				then
					if not mapping.test or mapping.test(owner, device_type, device_id) then
						if mapping.fn and mapping.fn(owner) then
							return true
						end
					end
				end
			end
		end

		if self.HandleControlUp and self:HandleControlUp(controls, device_type, trace, device_id) then
			return true
		end

		if self.blocks_mouse and ( device_type == "mouse" or device_type == "touch" ) then
			if not controls:Has(Controls.Digital.MENU_SCROLL_FWD, Controls.Digital.MENU_SCROLL_BACK) then
				return true
			end
		end
	end
end


function Widget:SetParentScrollList(list)
	self.parent_scroll_list = list
end

function Widget:IsEditing()
	--recursive check to see if anything has text edit focus
	if self.editing then
		return true
	end

	for k, v in pairs(self.children) do
		if v:IsEditing() then
			return true
		end
	end

	return false
end

-- from and to should be numbers. Scaling is uniform.
function Widget:ScaleTo(from, to, time, easefn, fn)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	from = from or self:GetScale()
	self.inst.components.uianim:ScaleTo(from, to, time, easefn, fn)
	return self
end

-- Like ScaleTo but starts at current scale and automatically returns to
-- original scale.
function Widget:ScalePulseSingle(to, time, easefn, fn)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	local from = self:GetScale()
	self.inst.components.uianim:ScaleTo(from, to, time, easefn, function()
		self.inst.components.uianim:ScaleTo(to, from, time, easefn, fn)
	end)
	return self
end

-- Like ScaleTo but starts at current scale, overshoots the scale, overshoots downwards, and settles on the final value.
function Widget:ScaleToWithOvershoot(to, overshootPercent, time, fn)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end

	-- First, scale up to the first overshoot value
	-- Then, scale down to the second overshoot value
	-- Then, settle back to the intended scale.

	local from = self:GetScale()
	local overshootHigh = to + (to * overshootPercent)
	local overshootLow = to - (to * overshootPercent * 0.2) -- Overshoot low is much less

	local timeOvershootHigh = time
	local timeOvershootLow = time * 0.5
	local timeSettle = time * 0.25

	-- Define the functions for the sequence, in reverse order so they're available down the chain.
	-- "Then, settle back to the intended scale.""
	local bounceSettle = function()
		self:ScaleTo(overshootLow, to, timeSettle, easing.outQuad)
	end

	-- "Then, scale down to the second overshoot value"
	local bounceOverShootDown = function()
		self:ScaleTo(overshootHigh, overshootLow, timeOvershootLow, easing.outQuad, bounceSettle)
	end

	-- Start off with:
	-- First, scale up to the first overshoot value
	self:ScaleTo(from, overshootHigh, timeOvershootHigh, easing.inOutQuad, bounceOverShootDown)
end

function Widget:CancelMoveTo(run_complete_fn)
	if self.inst.components.uianim ~= nil then
		self.inst.components.uianim:CancelMoveTo(run_complete_fn)
	end
end

function Widget:MoveTo(x, y, time, easefn, fn)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	self.inst.components.uianim:MoveTo(self.x, self.y, x or self.x, y or self.y, nil, nil, time, easefn, fn)
	return self
end

-- Like MoveTo, but relative to position when it's first called.
function Widget:OffsetTo(dx, dy, time, easefn, fn)
	local x, y = self.x, self.y
	if self.before_offset then
		x, y = self.before_offset:unpack()
	else
		self.before_offset = self:GetPositionAsVec2()
	end
	return self:MoveTo(x + dx, y + dy, time, easefn, fn)
end

-------------------------------------------------
--
function Widget:CurveTo(x, y, control_x, control_y, time, easefn, fn)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	self.inst.components.uianim:MoveTo(self.x, self.y, x, y, control_x, control_y, time, easefn, fn)
	return self
end


function Widget:CancelRotateTo(run_complete_fn)
	if self.inst.components.uianim ~= nil then
		self.inst.components.uianim:CancelRotateTo(run_complete_fn)
	end
end

function Widget:RotateTo(to, time, easefn, fn)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	self.inst.components.uianim:RotateTo(self.r, to, time, easefn, fn, false)
	return self
end

function Widget:SizeTo(start_w, end_w, start_h, end_h, t, easefn, fn)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	self.inst.components.uianim:SizeTo(start_w, end_w, start_h, end_h, t, easefn, fn)
	return self
end


function Widget:ScissorTo(from, to, time, easefn, fn)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	self.inst.components.uianim:ScissorTo(from, to, time, easefn, fn, false)
	return self
end

function Widget:RotateIndefinitely( speed )
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	self.inst.components.uianim:RotateIndefinitely(speed)
	return self
end

function Widget:StopSpin()
	if self.inst.components.uianim then
		self.inst.components.uianim:StopSpin()
	end
	return self
end


function Widget:TintTo(from, to, time, easefn, fn)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	local start_colour = from or {self.mult_r or 1, self.mult_g or 1, self.mult_b or 1, self.mult_a or 1 }
	self.inst.components.uianim:TintTo(start_colour, to, time, easefn, fn)
	return self
end

function Widget:ColorAddTo(from, to, time, easefn, fn)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	local start_colour = from or {self.add_r or 0, self.add_g or 0, self.add_b or 0, self.add_a or 0 }
	self.inst.components.uianim:ColorAddTo(start_colour, to, time, easefn, fn)
	return self
end

function Widget:EaseTo(on_change_fn, start_v, end_v, t, easefn, on_done_fn)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	self.inst.components.uianim:EaseTo(on_change_fn, start_v, end_v, t, easefn, on_done_fn)
	return self
end

function Widget:Ease2dTo(on_change_fn, start_v, end_v, start_w, end_w, t, easefn, on_done_fn)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	self.inst.components.uianim:Ease2dTo(on_change_fn, start_v, end_v, start_w, end_w, t, easefn, on_done_fn)
	return self
end

function Widget:AlphaTo(a, t, easefn, fn)
	if a > 0 then
		self:Show()
	end

	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	local start_colour = {self.mult_r or 1, self.mult_g or 1, self.mult_b or 1, self.mult_a or 1 }
	local end_colour = {self.mult_r or 1,self.mult_g or 1, self.mult_b or 1, a or 1}

	self.inst.components.uianim:TintTo(start_colour, end_colour, t, easefn, fn)
	return self
end

-- Speed is delta per frame: roughly in [0.001, 0.1]
function Widget:PulseAlpha(from_alpha, to_alpha, speed)
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	self.inst.components.uianim:PulseAlpha(from_alpha, to_alpha, speed)
	return self
end

function Widget:PulseColor(c1, c2, duration, easefn)
	c1 = c1 or table.empty -- defaults to current tint
	dbassert(c2)
	-- c1,c2 should be RGB, RGBA, or color.lua colours. Try UICOLORS.
	return self:PulseRGBA(
		c1.r, c1.g, c1.b, c1.a,
		c2.r, c2.g, c2.b, c2.a,
		duration,
		easefn)
end

function Widget:PulseRGBA( r1,g1,b1,a1, r2,g2,b2,a2, duration, easefn )
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	self.inst.components.uianim:PulseRGBA(r1, g1, b1, a1, r2, g2, b2, a2, duration, easefn)
	return self
end

function Widget:StopPulse()
	self.inst.components.uianim:StopPulse()
	return self
end

function Widget:Blink( period_t, max_count, blink_fn, fn )
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	self.inst.components.uianim:Blink(period_t, max_count, blink_fn, fn )
	return self
end



function Widget:ForceStartWallUpdating()
	if Platform.IsConsole() then
		return --disabled for console
	end
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	self.inst.components.uianim:ForceStartWallUpdating(self)
end

function Widget:ForceStopWallUpdating()
	if Platform.IsConsole() then
		return --disabled for console
	end
	if not self.inst.components.uianim then
		self.inst:AddComponent("uianim")
	end
	self.inst.components.uianim:ForceStopWallUpdating(self)
end


function Widget:IsEnabled()
	if not self.enabled then return false end

	if self.parent then
		return self.parent:IsEnabled()
	end

	return true
end

function Widget:GetParent()
	return self.parent
end

function Widget:GetChildren()
	return self.children
end

function Widget:Enable()
	self.enabled = true
	self:OnEnable()
	return self
end

function Widget:Disable()
	self.enabled = false
	self:OnDisable()
	return self
end

function Widget:SetEnabled(enabled)
	self.enabled = enabled
	if self.enabled then self:OnEnable() else self:OnDisable() end
	return self
end

function Widget:OnEnable()
end

function Widget:OnDisable()
end

function Widget:Hide()
	if self.shown then
		self.inst.entity:Hide(false)
		self.shown = false
		self:ClearFocus()
		self:OnHide()

		self:InvalidateBBox()

		self:UpdateViz()
	end
	return self
end

function Widget:Show()
	if not self.shown then
		self.inst.entity:Show(false)
		self.shown = true
		self:OnShow()

		self:InvalidateBBox()

		self:UpdateViz()
	end
	return self
end


-- Absolute position on screen. Not relative to world entity position.
function Widget:GetWorldPosition()
	self:UpdateTransform(true) -- otherwise may not include local position.
	return Vector3(self.inst.UITransform:GetWorldPosition())
end

-- Returns position normalized to:
-- * 0,0 at centre of screen
-- * 1,1 at top right of screen
-- * -1,-1 at bottom left of screen
function Widget:GetNormalizedScreenPosition()
	local pos = self:GetWorldPosition()
	pos.x = pos.x * 4 / RES_X
	pos.y = pos.y * 4 / RES_Y
	return pos
end

function Widget:GetPosition()
	return self.x, self.y
end

-- shim
function Widget:GetPos()
	return self:GetPosition()
end

function Widget:GetWorldScale()
	return Vector3(self.inst.UITransform:GetWorldScale())
end

function Widget:GetPositionAsVec2()
	local x,y = self:GetPosition()
	return Vector2(x,y)
end

function Widget:GetLocalPosition()
	local x,y = self:GetPosition()
	return Vector3(x,y,0)
end

-- Determine the local position that would position us over the entity.
function Widget:CalcLocalPositionFromEntity(target_ent)
	return self:CalcLocalPositionFromWorldPoint(target_ent.Transform:GetWorldPosition())
end

-- Determine the local position that would position us over this point in the world.
function Widget:CalcLocalPositionFromWorldPoint(wx, wy, wz)
	local x, y = TheSim:WorldToScreenXY(wx, wy, wz)
	x, y = TheFrontEnd:WindowToUI(x, y)
	x, y = self.parent:TransformFromWorld(x, -y)
	return x,y
end

function Widget:SetMaxPropUpscale(val)
	self.inst.UITransform:SetMaxPropUpscale(val)
	return self
end

-- See ForceFullScreenBounds.
function Widget:SetScaleMode(mode)
-- TODO_KAJ Widget:SetScaleMode
--    self.inst.UITransform:SetScaleMode(mode)
	return self
end

-- Shim
function Widget:SetVAnchor(anchor)
	OBSOLETE("Widget:SetVAnchor", "Widget:SetAnchors")
	local VAnchors = {
			[ANCHOR_MIDDLE] = "center",
			[ANCHOR_TOP] = "top",
			[ANCHOR_BOTTOM] = "bottom"
		 }
	local vanchor = VAnchors[anchor]
	self:SetAnchors(self.hanchor,vanchor)
	return self
end

-- Shim
function Widget:SetHAnchor(anchor)
	OBSOLETE("Widget:SetHAnchor", "Widget:SetAnchors")
	local HAnchors = {
			[ANCHOR_MIDDLE] = "center",
			[ANCHOR_LEFT] = "left",
			[ANCHOR_RIGHT] = "right"
		 }
	local hanchor = HAnchors[anchor]
	self:SetAnchors(hanchor,self.vanchor)
	return self
end

function Widget:OnShow()
end

function Widget:OnHide()
end

--[[function Widget:Update(dt)
	if not self.enabled then return end
	if self.OnUpdate ~= nil then
		self:OnUpdate(dt)
	end

	for k, v in pairs(self.children) do
		if v.OnUpdate ~= nil or #v.children > 0 then
			v:Update(dt)
		end
	end
end--]]



local anchor_def = {
	horizontal = {
		"", -- set to nil
		"left",
		"center",
		"right",
		"fill",
	},
	vertical = {
		"", -- set to nil
		"bottom",
		"center",
		"top",
		"fill",
	},
}

local reg_def = {
	Horizontal = Enum{
		"left",
		"center",
		"right",
	},
	Vertical = Enum{
		"top",
		"center",
		"bottom",
	},
}

local function GetStencilSource(w)
	while w do
		if w.stencil_test then
			return w
		end
		w = w.parent
	end
end

-- Draws a section of data describing this widget to the current debug UI
-- window.
--
-- See imgui.h ( https://github.com/ocornut/imgui/blob/master/imgui.h#L112 )
-- for the API. Not all functions are available. Some type formats differ
-- (ImVec must be unpacked). Nonconst pointers are additional return values.
--
-- See imgui_demo.lua for usage examples.
function Widget:DebugDraw_AddSection(ui, panel)
	if ui:Button("SetFocus") then
		self:SetFocus()
	end
	ui:SameLineWithSpace()
	if ui:Button(self.shown and "Hide" or "Show", 50) then
		self:SetShown(not self.shown)
	end
	ui:SameLineWithSpace()
	if ui:Button(self.enabled and "Disable" or "Enable", 60) then
		self:SetEnabled(not self.enabled)
	end
	ui:SameLineWithSpace()
	if ui:Button("To Front") then
		self:SendToFront()
	end
	ui:SameLineWithSpace()
	if ui:Button("To Back") then
		self:SendToBack()
	end

	ui:Text(string.format("Widget: '%s'", tostring(self)))
	ui:Indent() do
		if self.creation_stack then
			if ui:Button("Construction Callstack") then
				ui:SetClipboardText(self.creation_stack)
			end
			ui:SetTooltipIfHovered("Click to copy:\n\n".. self.creation_stack)
		end
		ui:Value("IsShown", self:IsShown())
		ui:Value("IsVisible (recursive)", self:IsVisible())

		local in_x,in_y = self:GetPosition()
		local has_modified_x, out_x = ui:DragFloat("x position", in_x, 1, -4000, 4000)
		local has_modified_y, out_y = ui:DragFloat("y position", in_y, 1, -4000, 4000)
		if has_modified_x or has_modified_y then
			self:UpdatePosition(out_x,out_y)
		end

		local to_pop = ui:PushDisabledStyle()
		ui:DragVec2f("NormalizedScreenPosition", self:GetNormalizedScreenPosition())
		ui:PopStyleColor(to_pop)

		self.dbg_offset = self.dbg_offset or { offset = Vector2(), orig = self:GetPositionAsVec2() }
		if ui:DragVec2f("Offset", self.dbg_offset.offset, 0.1, -2000, 2000) then
			self:SetPosition(self.dbg_offset.orig:unpack())
				:Offset(self.dbg_offset.offset:unpack())
		end
		if ui:IsItemHovered() then
			ui:SetTooltip("Disable any :Offset() before editing here to get the correct values.")
		end

		local scale = Vector2(self:GetScale())
		-- Scale animates and often modifies other axes, so use awkward InputFloat2
		-- to discourage editing.
		local changed,x,y = ui:InputFloat2("scale", scale.x, scale.y)
		if changed then
			self:SetScale(x,y)
		end
		changed,x = ui:DragFloat("uniform scale", scale.x, 0.1, 0.1, 20, "%.3f")
		if changed then
			self:SetScale(x)
		end
		to_pop = ui:PushDisabledStyle()
		ui:InputFloat2("nested scale", self:GetNestedScale():unpack())
		ui:PopStyleColor(to_pop)

		local rotation = self.inst.UITransform:GetRotation()
		local changed_rot, rot = ui:DragFloat("rotation", rotation, 10, 0, 360)
		if changed_rot then
			self:SetRotation( rot )
		end

		do
			if self.GetBoundingBox == self._GetBoundingBoxForFullScreen then
				ui:Text("ForceFullScreenBounds enabled so size is determine from max resolution.")
			end
			local modified_w,modified_h
			local w,h = self:GetSize()
			if w and h then -- sometimes GetSize returns nil!?
				local popstyles = self.SetSize and 0 or ui:PushDisabledStyle()
				modified_w, w = ui:DragFloat("width##widget", w, nil, 1, 1000)
				modified_h, h = ui:DragFloat("height##widget", h, nil, 1, 1000)
				if self.SetSize and (modified_w or modified_h) then
					-- When underlying widget is a Panel, it may reject our values
					-- if they're below some threshold. I'm not sure why.
					self:SetSize(w,h)
				end
				ui:PopStyleColor(popstyles)
			end
		end


		if self.scissor_rect then
			local ins = self.scissor_inset or { 0, 0, 0, 0, self:GetSize(), }
			local orig_size = Vector2(ins[5], ins[6])
			ui:PushItemWidth((ui:GetContentRegionAvail() - 170)/2) do
				local region = Bound2.from_values(table.unpack(self.scissor_rect))
				local size = region:size()
				local max_coord = math.max(orig_size:unpack()) * 1.5
				changed = ui:DragVec2f("##Scissor.min", region.min, nil, -max_coord, max_coord)
				ui:SetTooltipIfHovered("x, y: window bottom left corner in pixels from center")
				ui:SameLine(nil, 5)
				changed = ui:DragVec2f("Scissor##Scissor.size", size, nil, -max_coord, max_coord) or changed
				ui:SetTooltipIfHovered("w, h: window size in pixels")
				if changed then
					self:SetScissor(region.min.x, region.min.y, size.x, size.y)
				end

				local s = {
					h = Vector2(ins[1], ins[2]),
					v = Vector2(ins[3], ins[4]),
				}
				changed = ui:DragVec2f("##ScissorInsetSides.horiz", s.h, nil, -max_coord, max_coord)
				ui:SetTooltipIfHovered("Left and right inset. Cuts off visibility on the sides.")
				ui:SameLine(nil, 5)
				changed = ui:DragVec2f("ScissorInsetSides##ScissorInsetSides.vert", s.v, nil, -max_coord, max_coord) or changed
				ui:SetTooltipIfHovered("Top and bottom inset. Cuts off visibility and reduces total height.")
				if changed then
					-- Limit to half inset to prevent invalid scissor region.
					local half_size = orig_size:scale(0.49)
					s.h = s.h:component_min(half_size)
					s.v = s.v:component_min(half_size)
					self:SetScissorInsetSides(s.h.x, s.h.y, s.v.x, s.v.y, orig_size:unpack())
				end

				if ui:Button("Clear Scissor") then
					self:SetScissor()
				end
			end

		elseif ui:Button("Start Scissor") then
			local w,h = self:GetSize()
			self:SetScissorInsetSides(0, 0, 0, 0, w, h)
		end


		-- Not 100% sure this is perfectly reliable since it's possible native
		-- code changes stencil test settings or infers values from somewhere
		-- else.
		local w = GetStencilSource(self)
		ui:Checkbox("Stencil Test", w)
		if w == self then
			ui:SameLineWithSpace()
			ui:Text("Due to SetMask")
		elseif w then
			ui:SameLineWithSpace()
			ui:Text("Due to parent:")
			ui:SameLineWithSpace()
			panel:AppendValue(ui, w)
		end

		local tooltip = {
			"How the widget is positioned relative to its parent.",
			"See Widget:SetAnchors for long explanation."
		}
		ui:Text("Anchors")
		ui:SetTooltipIfHovered(tooltip)
		ui:Columns(2,nil,false)

		local function anchor_tuner(label, def, anchor)
			local modified
			local anchor_type = type(anchor)
			if anchor_type == "number" then
				modified, anchor = ui:DragFloat(label, anchor)
				ui:SetTooltipIfHovered(tooltip)
			else
				local selection = lume.find(def, anchor) or 1
				modified, selection = ui:Combo(label, selection, def)
				ui:SetTooltipIfHovered(tooltip)
				if modified then
					anchor = nil
					if selection > 1 then
						anchor = def[selection]
					end
				end
			end
			return modified, anchor
		end
		local modified, anchor
		modified, anchor = anchor_tuner("Horizontal##widgetanchorcombo", anchor_def.horizontal, self.hanchor)
		if modified then
			self:SetAnchors(anchor, self.vanchor)
		end
		modified, anchor = anchor_tuner("Vertical##widgetanchorcombo", anchor_def.vertical, self.vanchor)
		if modified then
			self:SetAnchors(self.hanchor, anchor)
		end
		ui:NextColumn()
		ui:NextColumn()

		local changed, hanchor = ui:InputText("H",tostring(self.hanchor))
		if changed then
			if tonumber(hanchor) then
				self:SetAnchors(tonumber(hanchor),self.vanchor)
			elseif hanchor == "nil" then
				self.hanchor_alt = nil
				self:SetAnchors(nil,self.vanchor)
			elseif hanchor == "left"
				or hanchor == "center"
				or hanchor == "right"
				or hanchor == "fill"
			then
				self.hanchor_alt = nil
				self:SetAnchors(hanchor,self.vanchor)
			end
		end
		ui:NextColumn()
		local changed, hanchor_alt = ui:InputText("(stretchx)",tostring(self.hanchor_alt))
		if changed then
			if hanchor_alt == "nil" then
				self.hanchor_alt = nil;
				self:SetAnchors(self.hanchor, self.vanchor)
			elseif tonumber(hanchor_alt) and tonumber(self.hanchor) then
				self:StretchX(self.hanchor,hanchor_alt)
			end
		end
		ui:NextColumn()
		local changed, vanchor = ui:InputText("V",tostring(self.vanchor))
		if changed then
			if tonumber(vanchor) then
				self:SetAnchors(self.hanchor, tonumber(vanchor))
			elseif vanchor == "nil" then
				self.vanchor_alt = nil
				self:SetAnchors(self.hanchor,nil)
			elseif vanchor == "top"
				or vanchor == "center"
				or vanchor == "bottom"
				or vanchor == "fill"
			then
				self.vanchor_alt = nil
				self:SetAnchors(self.hanchor, vanchor)
			end
		end
		ui:NextColumn()
		local changed, vanchor_alt = ui:InputText("(stretchy)",tostring(self.vanchor_alt))
		if changed then
			if vanchor_alt == "nil" then
				self.vanchor_alt = nil;
				self:SetAnchors(self.hanchor, self.vanchor)
			elseif tonumber(vanchor_alt) and tonumber(self.vanchor) then
				self:StretchY(self.vanchor,vanchor_alt)
			end
		end
		ui:Columns(1)

		tooltip = {
			"How the widget is positioned relative to itself.",
			"See Widget:SetRegistration for long explanation."
		}
		ui:Text("Registration")
		ui:SetTooltipIfHovered(tooltip)
		local hreg = self.hreg or "center"
		local vreg = self.vreg or "center"
		modified, hreg = ui:Enum("Horizontal##widgetregistrationcombo", hreg, reg_def.Horizontal)
		ui:SetTooltipIfHovered(tooltip)
		if modified then
			self:SetRegistration(hreg, vreg)
		end
		modified, vreg = ui:Enum("Vertical##widgetregistrationcombo", vreg, reg_def.Vertical)
		ui:SetTooltipIfHovered(tooltip)
		if modified then
			self:SetRegistration(hreg, vreg)
		end

		ui:Spacing()
		local function ToTable(default, r, g, b, a)
			assert(default)
			if r then
				return { r, g, b, a or 1, }
			else
				return default
			end
		end
		tooltip = {
			"This color affects this widget and all child widgets, but doesn't include color from parent.",
			"This is how we usually modify color in ui code.",
		}
		local c = DebugPickers.Colour(ui, "Widget Additive", ToTable(WEBCOLORS.TRANSPARENT_BLACK, self:GetAddColor()))
		ui:SetTooltipIfHovered(tooltip)
		if c then
			self:SetAddColor(c)
		end

		c = DebugPickers.Colour(ui, "Widget Tint", ToTable(WEBCOLORS.WHITE, self:GetMultColor()))
		ui:SetTooltipIfHovered(tooltip)
		if c then
			self:SetMultColor(c)
		end
		ui:Spacing()


	end
	ui:Unindent()
end

function Widget:SetFadeAlpha(alpha, skipChildren)
	if not self.can_fade_alpha then return end

	if not skipChildren and self.children then
		for k,v in pairs(self.children) do
			v:SetFadeAlpha(alpha, skipChildren)
		end
	end
end

function Widget:SetCanFadeAlpha(fade, skipChildren)
	self.can_fade_alpha = fade

	if not skipChildren and self.children then
		for k,v in pairs(self.children) do
			v:SetCanFadeAlpha(fade, skipChildren)
		end
	end
end

-- Applies recursively to children. Allows mouse clicks to pass through to the
-- world. Great for overlays.
-- Will also prevent widget from being mouse selectable in widget debugger.
-- See also SetBlocksMouse, SetHoverCheck.
function Widget:SetClickable(val)
	self.inst.entity:SetClickable(val)
	return self
end

function Widget:UpdatePosition(x, y)
	self:SetPosition(x, y, 0)
	return self
end

function Widget:FollowMouse()
	if self.followhandler == nil then
		local function onmove(x, y)
			self:SetPosition(TheInput:GetVirtualMousePos())
		end
		self.followhandler = TheInput:AddMoveHandler(onmove)
		onmove()
	end
	return self
end

function Widget:StopFollowMouse()
	if self.followhandler ~= nil then
		self.followhandler:Remove()
		self.followhandler = nil
	end
	return self
end

--[[
function Widget:GetScale()
	local sx, sy = self.inst.UITransform:GetScale()
	if self.parent ~= nil then
		local scale = self.parent:GetScale()
		return Vector3(sx * scale.x, sy * scale.y, scale.z)
	end
	return Vector3(sx, sy, 1)
end
]]

function Widget:GetLooseScale()
	return self.inst.UITransform:GetScale()
end

---------------------------focus management

-- Don't call this directly! See GainFocus.
function Widget:OnGainFocus()
	-- Widgets child types can override this function. Instances should use
	-- SetOnGainFocus instead. That way they don't clobber each other.
end
function Widget:OnLoseFocus()
end

function Widget:SetOnGainFocus( fn )
	self.ongainfocusfn = fn
	return self
end

function Widget:SetOnLoseFocus( fn )
	self.onlosefocusfn = fn
	return self
end

function Widget:HasFocus()
	return self.focus == true
end

-- Child widgets may call this to simulate refreshing state due to focus gain.
function Widget:GainFocus()
	self.focus = true
	self:OnGainFocus()
	if self.ongainfocusfn then
		self.ongainfocusfn()
	end
end

-- This should only be called from FrontEnd:SetFocusWidget.
-- focus_widget: the terminal Widget receiving focus.
function Widget:GiveFocus( focus_widget )

	if self.parent then
		self.parent:GiveFocus( focus_widget or self )
	end

	-- Don't modify default_focus here. We want that to be static. Screens
	-- often get focus and shouldn't assign default_focus to themselves.

	if not self.focus then
		if self.gainfocus_sound then
--            AUDIO:PlayEvent( self.gainfocus_sound )
		end

		dbassert(self.GainFocus == Widget.GainFocus, "Override OnGainFocus, not GainFocus.")
		self:GainFocus()
	end
	return self
end

-- Prefer using TheFrontEnd:SetFocusWidget() or TheFrontEnd:ClearFocusWidget
-- unless you're just refreshing the visual state.
function Widget:LoseFocus()
	self.focus = false
	self:OnLoseFocus()
	if self.onlosefocusfn then
		self.onlosefocusfn()
	end

end

-- This should only be called from FrontEnd:ClearFocusWidget.
-- focus_widget: the terminal Widget receiving focus, if switching focus.
function Widget:RemoveFocus( focus_widget )
	if self.focus
		and (focus_widget == nil
			-- Ignore focus changes if still in the hierarchy of focus so a
			-- larger widget doesn't visually stutter because the mouse moved
			-- over a button inside it.
			or (focus_widget ~= self and not self:IsAncestorOf(focus_widget)))
	then
		self:LoseFocus()

		if self.parent then
			self.parent:RemoveFocus( focus_widget )
		end
	end
end


-- Shim
function Widget:SetFocusChangeDir(dir, widget, ...)
	return self:SetFocusDir(dir, widget)
end

function Widget:GetDeepestFocus()
	if self.focus then
		for k,v in pairs(self.children) do
			if v.focus then
				return v:GetDeepestFocus()
			end
		end

		return self
	end
end

function Widget:GetDeepestHover()
	if self.hover then

		if self.children then
			for k = 1, #self.children do
				local v = self.children[k]
				if v.hover then
					return v:GetDeepestHover()
				end
			end
		end
	else
		return nil
	end

	return self
end

function Widget:GetFocusChild()
	if self.focus then
		for k,v in pairs(self.children) do
			if v.focus then
				return v
			end
		end
	end
	return nil
end


function Widget:SetFocus()
	if self.focus_forward then
		-- Only supporting passing focus to widgets.
		kassert.typeof('table', self.focus_forward)
		assert(self.focus_forward ~= self, "Pointless to focus_forward to self. It will infinitely recurse.")
		self.focus_forward:SetFocus()
	else
		dbassert(not self.ignore_input, "Don't set focus on something ignoring input.")
		TheFrontEnd:SetFocusWidget(self)
	end
	return self
end

function Widget:ClearFocus()
	if self.focus then
		TheFrontEnd:ClearFocusWidget()
	end
	return self
end

function Widget:GetStr(indent)
	indent = indent or 0
	local indent_str = string.rep("\t",indent)

	local str = {}
	table.insert(str, string.format("%s%s%s%s\n", indent_str, tostring(self), self.focus and " (FOCUS) " or "", self.enabled and " (ENABLE) " or "" ))

	for k,v in pairs(self.children) do
		table.insert(str, v:GetStr(indent + 1))
	end

	return table.concat(str)
end

function Widget:__tostring()
	return tostring(self._widgetname)
end

-- Scissoring
----------------------------------------------------
-- ┌─────────────────┐
-- │          w/2,h/2│
-- │                 │
-- │                 │
-- │        ┼        │
-- │                 │
-- │                 │
-- │x,y              │
-- └─────────────────┘
-- Center based, so usually (-w/2, -h/2, w, h)
function Widget:SetScissor( x, y, w, h )
	if x then
		self.scissor_rect = { x, y, x + w, y + h }
		self.inst.UITransform:SetScissor(x, y, w, h)
		self:InvalidateBBox()
		self:MarkTransformDirty()
	else
		self.scissor_rect = nil
		self.scissor_inset = nil
		self.inst.UITransform:ClearScissor()
	end
	return self
end

-- Simple scissoring: use imgui to turn this on and tune some values. Only lets
-- you trim some off the sides. For more flexible scissor window positioning,
-- use SetScissor.
--
-- If called on creation, don't bother passing w,h.
function Widget:SetScissorInsetSides(left, right, top, bottom, w, h)
	kassert.typeof("number", left, right, top, bottom)
	if not w then
		self:SetScissor() -- clear to get unscissored size.
		w,h = self:GetSize()
	end
	self.scissor_inset = { left, right, top, bottom, w, h, }
	local x = -w/2 + left
	local y = -h/2 + bottom
	w = w - left - right
	h = h - top - bottom
	return self:SetScissor(x, y, w, h)
end

----------------------------------------------------------------- NEW -------------------------------------------------------

function Widget:AddChild(child, idx)
	assert( child ~= self )
	assert( child.parent == nil, "widget already has parent: "..tostring(child.parent) )
	assert( not child.removed )

	self:InvalidateBBox()
	self:MarkTransformDirty()

	if self.fe then
		child:SetFE(self.fe)
	end
	child:MarkTransformDirty()
	child:CollectDirtyDescendants()

	child.parent = self
	child.hover = false
	--child.focus = false -- KAJ: No, we rely on this being correct

	if self.children == table.empty then
		self.children = {}
	end

	if idx then
		idx = math.min(idx, #self.children+1)
		table.insert(self.children, idx, child)
--		self.inst.entity:AddChild(child.inst.entity, idx-1 ) -- 0-based -- KAJ: Hmmm, why don't we need this?
		child.inst.entity:SetParent(self.inst.entity, idx)
	else
		table.insert(self.children, child)
--		self.inst.entity:AddChild(child.inst.entity) -- 0-based -- KAJ: Hmmm, why don't we need this?
		-- add the child to the parent
		child.inst.entity:SetParent(self.inst.entity)
	end

	if child.OnAdded then
		child:OnAdded()
	end

	if self.resolved_mult_r then
		child:ApplyMultColorFromParent(self.resolved_mult_r, self.resolved_mult_g, self.resolved_mult_b, self.resolved_mult_a)
	end

	if self.resolved_sat then
		child:ApplySaturationFromParent(self.resolved_sat)
	end

	if self.ancestordirty or self.dirtytransform then
		child:MarkAncestorTransformDirty()
	end

	-- Screen has this set by its ctor.
	if self._widget_owning_screen and not child.is_screen then
		child:_NotifyAddedToScreen(self._widget_owning_screen)
	end

	child:UpdateViz()
	return child
end

function Widget:IsEmpty()
	return self.children == nil or #self.children == 0
end

function Widget:HasChildren()
	return self.children and #self.children > 0
end

function Widget:GetFirstChild()
	return self.children and #self.children > 0 and self.children[1]
end

function Widget:InvalidateBBox()
	self.bboxcache.valid = false
	if self.propagate_bb then
		if self.parent then
			self.parent:InvalidateBBox()
		end
	end
end

function Widget:MarkTransformDirty()

	if not self.dirtytransform then
		self.dirtytransform = true
		--self.dirtytransform = true
		if TheFrontEnd and not self.removed then
--       	if self.fe and not self.removed then
			TheFrontEnd:AddDirtyTransformWidget(self)
		end
		if self.children then
			for k,v in pairs(self.children) do
				v:MarkAncestorTransformDirty()
			end
		end
	end
end

function Widget:CollectDirtyDescendants()

	if self.fe and not self.removed then
		self.fe:AddDirtyTransformWidget(self)
	end

	if self.children then
		for k,v in pairs(self.children) do
			v:CollectDirtyDescendants()
		end
	end
end

function Widget:MarkAncestorTransformDirty()
	if not self.ancestordirty then
		self.ancestordirty = true
		if self.children then
			for k,v in pairs(self.children) do
				if not v.ancestordirty then
					v:MarkAncestorTransformDirty()
				end
			end
		end
	end
end

-- The widget (or its ancestor) was added to a screen and was not previously
-- part of that screen. This callback is a great place to check
-- GetOwningPlayer (which may only be set on the screen).
function Widget:_NotifyAddedToScreen(screen)
	self._widget_owning_screen = screen
	if self.OnAddedToScreen then
		self:OnAddedToScreen(screen)
	end
	if self.children then
		for k,v in pairs(self.children) do
			v:_NotifyAddedToScreen()
		end
	end
end

function Widget:UpdateViz()

	local viz
	if not self.shown then
		viz = false
	elseif not self.parent then
		viz = self.force_viz == true
	else
		viz = self.parent:IsVisible()
	end

	if viz ~= self.visible then
		self.visible = viz

		if self.OnVizChange then
			self:OnVizChange(self.visible)
		end

		if self.children then
			for k,child in ipairs(self.children) do
				child:UpdateViz()
			end
		end
	end
end

-- Ignore our size and the bounds of our children and use the screen bounds
-- instead. Use this on raw widgets instead of the deprecated
-- SetScaleMode(SCALEMODE_FILLSCREEN).
function Widget:ForceFullScreenBounds()
	assert(#self.children == 0, "Should setup bounds on construction and not later.")
	self.GetBoundingBox = self._GetBoundingBoxForFullScreen
	return self
end

function Widget:Stretch(axis, leftInset, rightInset, topInset, bottomInset)
	if  axis == Axis.All then
		self.hanchor = 0
		self.hanchor_alt = 1
		self.vanchor = 0
		self.vanchor_alt = 1
		self.insetLeft = leftInset
		self.insetRight = rightInset
		self.insetTop = topInset
		self.insetBottom = bottomInset
	elseif axis == Axis.X then
		self.hanchor = 0
		self.hanchor_alt = 1
		self.insetLeft = leftInset
		self.insetRight = rightInset
	elseif axis == Axis.Y then
		self.vanchor = 0
		self.vanchor_alt = 1
		self.insetTop = topInset
		self.insetBottom = bottomInset
	else
		self.hanchor = nil
		self.hanchor_alt = nil
		self.vanchor = nil
		self.vanchor_alt = nil
		self.insetLeft = nil
		self.insetRight = nil
		self.insetTop = nil
		self.insetBottom = nil
	end
	if self.hanchor or self.vanchor then
		self:SetHiddenBoundingBox( true )
	--else
	-- KAJ: This would stomp the setting if we already applied it
	--	self:SetHiddenBoundingBox( false )
	end
	self:InheritTransform(true)
	self:UpdateAnchors()
	return self
end

function Widget:StretchX(anchorMinX, anchorMaxX, leftInset, rightInset)
	self.hanchor = anchorMinX
	self.hanchor_alt = anchorMaxX
	self.insetLeft = leftInset
	self.insetRight = rightInset

	if self.hanchor or self.vanchor then
		self:SetHiddenBoundingBox( true )
	else
		self:SetHiddenBoundingBox( false )
	end
	self:InheritTransform(true)
	self:UpdateAnchors()
	return self
end

function Widget:StretchY(anchorMinY, anchorMaxY, topInset, bottomInset )
	self.vanchor = anchorMinY
	self.vanchor_alt = anchorMaxY
	self.insetTop = topInset
	self.insetBottom = bottomInset

	if self.hanchor or self.vanchor then
		self:SetHiddenBoundingBox( true )
	else
		self:SetHiddenBoundingBox( false )
	end
	self:InheritTransform(true)
	self:UpdateAnchors()
	return self
end

-- Set the anchor position this widget uses on its *parent* to compute its
-- position. During layout we find our anchor position on our parent and add
-- our position as an offset.
--
-- Essentially: how the widget is positioned relative to its parent.
--
-- See SetRegistration to set this widget's pivot to adjust how its laid out as
-- it grows.
--
-- By default, widgets are implicitly anchored center, center.
--
-- Set b's anchor to position it relative to its parent's bottom right corner:
--   a:AddChild(b)
--     :SetAnchors("right", "bottom")
-- ┌───────────┐
-- │aaaaaaaaaaa│
-- │aaaaaaaaaaa│
-- │aaaaaaaaaaa│
-- │aaaaaaaa┌─────┐
-- │aaaaaaaa│bbbbb│
-- └────────│bbbbb│
--          │bbbbb│
--          └─────┘
--
function Widget:SetAnchors(h, v)
	-- TODO: add support for h2, v2, insetLeft, insetRight, insetTop,
	-- insetBottom? Or maybe expose them as a new function. See r447853.
	if h then
		assert( h == "left" or h == "right" or h == "fill" or h == "center" or type(h) == "number" )
	end
	if v then
		assert( v == "top" or v == "bottom" or v == "fill" or v == "center" or type(h) == "number" )
	end

	self.hanchor = h
	self.vanchor = v

	if self.hanchor or self.vanchor then
		self:SetHiddenBoundingBox( true )
	else
		self:SetHiddenBoundingBox( false )
	end

	self:InheritTransform(true)
	self:UpdateAnchors()

	return self
end

function Widget:InheritTransform(val)
	self.node:InheritTransform(val)
	self:MarkTransformDirty()
	return self
end

function Widget:UpdateAnchorsInternal()
	local sw, sh = TheFrontEnd:GetScreenDims()
	if self.parent then
		sw,sh = self.parent:GetSize()
	end
	-- Okay this needs to change, GetSize for text should be GetGlyphSize so that GetSize can return the size
	if not sh then
		sw, sh = TheFrontEnd:GetScreenDims()
	end
	local w,h = sw, sh
	local x,y = 0,0
	--too wide!
	--if sw/sh > 21/9 then
	--    w = sh*(21/9)
	--    x = (sw-w)/2
	--too tall!
	--elseif sw/sh < 4/3 then
	--    h = w / (4/3)
	--    y = (sh-h)/2
	--end

	if self.hanchor == "left" then
		self.anchorx = -w * 0.5 --w*self:GetFE().horizontal_safe_zone*.5
	elseif self.hanchor == "right" then
		self.anchorx = w * 0.5 -- w - w*self:GetFE().horizontal_safe_zone*.5
	elseif self.hanchor == "center" then
		self.anchorx = 0
	elseif self.hanchor == "fill" then
		self.anchorx = 0 -- w/2
	elseif type(self.hanchor) == "number" then
		self.anchorx = -w  * 0.5 + w * self.hanchor
	else
		self.anchorx = 0
	end
	self.anchorx = self.anchorx + x

	if self.vanchor == "top" then
		self.anchory = h/2
	elseif self.vanchor == "bottom" then
		self.anchory = -h/2
	elseif self.vanchor == "center" then
		self.anchory = 0 --h/2
	elseif self.vanchor == "fill" then
		self.anchory = 0 --h/2
	elseif type(self.vanchor) == "number" then
		self.anchory = -h * 0.5 + h * self.vanchor
	else
		self.anchory = 0
	end
	self.anchory = self.anchory + y
end

function Widget:UpdateAnchors()
	self:UpdateAnchorsInternal()
	self:MarkTransformDirty()
end

function Widget:GetResolvedScale()
	local x0, y0 = self:TransformToWorld( 0, 0 )
	local x1, y1 = self:TransformToWorld( 0, 1 )
	local x2, y2 = self:TransformToWorld( 1, 1 )
	return Dist2D( x1, y1, x2, y2 ), Dist2D( x1, y1, x0, y0 )
end

function Widget:UpdateTransform(world_space)
	if not self.dirtytransform and not self.ancestordirty then
		return
	end
	if world_space and self.ancestordirty then
		self:UpdateAncestorTransforms( world_space )
	end
	self.dirtytransform = false

	local base_scale = 1
	if self.fe then
		base_scale = self:GetFE():GetBaseWidgetScale()
	end

	-- KAJ: Base scale needs to be a different concept now as we inherit scale by default, whereas
--    base_scale = 1
	-- ugh, base scale sometimes needs to be applied and sometimes not, what drives that?
	local parent_scale_x, parent_scale_y
	if self.base_scaling ~= false and (self.hanchor or self.vanchor or self.base_scaling) then
		parent_scale_x, parent_scale_y = base_scale, base_scale
	else
		parent_scale_x, parent_scale_y = 1, 1
	end
	parent_scale_x, parent_scale_y = 1, 1
	base_scale = 1
	if self.hanchor or self.vanchor then
		self:UpdateAnchorsInternal()
	end

	-- this is interesting. "fill" should be relative to the parent, the others should be relative to screen
	if self.hanchor == "fill"
		or self.vanchor == "fill"
		or self.hanchor_alt
		or self.vanchor_alt
	then
		--self.ignoreForBoundingBox = true
		local rw, rh = RES_X, RES_Y

		local w, h = TheSim:GetScreenSize()

		if self.parent then
			-- This bugs me to no end that I can't use GetBoundingBox
			w,h = self.parent:GetSize() -- is there any difference between those
			--local sx1,sy1,sx2,sy2 = self.parent:GetBoundingBox()	-- Can't use boundingbox as it calculates it on children, which includes me
			--local sw = sx2 - sx1
			--local sh = sy2 - sy1
			--w = sw
			--h = sh
		end
		-- KAJ changed so that it also works for images that are not of RES_X, RES_Y dimensions
		--local mw,mh = self:GetSize() -- is there any difference between those two?
		local x1,y1,x2,y2 = self:GetBoundingBox()
		local widgetw = x2-x1
		local widgeth = y2-y1

		if self.hanchor == "fill" then
			parent_scale_x = w/widgetw
		end
		if self.vanchor == "fill" then
			parent_scale_y = h/widgeth
		end

		local ox, oy = 0, 0
		if self.insetTop
			or self.insetBottom
			or self.insetLeft
			or self.insetRight
		then
			local root_scale = 1.1234
			if self.fe then
				root_scale = self:GetFE():GetBaseWidgetScale()
			end
			-- offset and resize the parent size based on insets - in screen space
			local parent_scale = self.parent:GetNestedScale()
			parent_scale = parent_scale / root_scale
			local left = self.insetLeft or 0
			local right = self.insetRight or 0
			local top = self.insetTop or 0
			local bottom = self.insetBottom or 0
			if self.parent then
				local deltax = (left+right)
				ox = ((left - right) / 2)  / parent_scale.x
				w = w -deltax / parent_scale.x

				local deltay = (top+bottom)
				oy = ((top - bottom) / 2)  / parent_scale.y
				h = h -deltay / parent_scale.y
			end
		end

		if self.vanchor_alt then
			local center = (self.vanchor + self.vanchor_alt) / 2
			self.anchory = -h/2 + center * h - oy
			local h_size = self.vanchor_alt - self.vanchor
			h = h * h_size
			parent_scale_y = h/widgeth
		end
		if self.hanchor_alt then
			local center = (self.hanchor + self.hanchor_alt) / 2
			self.anchorx = -w/2 + center * w + ox
			local w_size = self.hanchor_alt - self.hanchor
			w = w * w_size
			parent_scale_x = w/widgetw
		end
	end

	-- KAJ: Base scale needs to be a different concept now as we inherit scale by default, whereas
	base_scale = 1

	local trans_scale = 1
	if self.base_scaling ~= false and (self.hanchor or self.vanchor or self.base_scaling) then
		trans_scale = base_scale
	else
		trans_scale = 1
	end

	if self.hreg and self.vreg then
		self:SetRegistrationInternal(self.hreg, self.vreg)
	end

	self.resolved_transform = self.resolved_transform or {}
	local x = self.x * trans_scale + self.anchorx + trans_scale * (self.regx or 0)
	local y = self.y * trans_scale + self.anchory + trans_scale * (self.regy or 0)
	local z = self.z
	local sx = self.layout_scale * parent_scale_x * self.sx
	local sy = self.layout_scale * parent_scale_y * self.sy
	local sz = 1.0
	local rx = 0
	local ry = 0
	local rz = self.r
	if self.resolved_transform.x ~= x
		or self.resolved_transform.y ~= y
		or self.resolved_transform.z ~= z
		or self.resolved_transform.sx ~= sx
		or self.resolved_transform.sy ~= sy
		or self.resolved_transform.sz ~= sz
		or self.resolved_transform.rx ~= rx
		or self.resolved_transform.ry ~= ry
		or self.resolved_transform.rz ~= rz
	then
		self.node:SetTransform(x, y, z, sx, sy, sz, rx, ry, rz)
		self.resolved_transform.x = x
		self.resolved_transform.y = y
		self.resolved_transform.z = z
		self.resolved_transform.sx = sx
		self.resolved_transform.sy = sy
		self.resolved_transform.sz = sz
		self.resolved_transform.rx = rx
		self.resolved_transform.ry = ry
		self.resolved_transform.rz = rz
	end
end

function Widget:SetFE(fe)

	if self.fe then
		assert( self.fe == fe )
		return
	end

	self.fe = fe

	if self.hanchor or self.vanchor then
		self:UpdateAnchors() -- Dirtys transform internally.
	else
		self:MarkTransformDirty()
	end

	if self.children then
		for k,v in pairs(self.children) do
			v:MarkAncestorTransformDirty()
		end
	end


	if self.children then
		for k,v in pairs(self.children) do
			v:SetFE(fe)
		end
	end

	if self.is_updating then
		self:GetFE():StartUpdatingWidget(self)
	end


	return self
end

function Widget:GetFE()
--    assert(self.fe)             -- KAJ, we set a lot of focus before a screen is pushed, think we want this different and get rid of self.fe
	return self.fe or TheFrontEnd -- KAJ, we set a lot of focus before a screen is pushed
end

-- You can use negative scale to mirror/flip a widget.
function Widget:SetScale(x,y,keep_anim)
	dbassert(x)
	if type(x) == "table" then
		print("TODO:called Widget:SetScale with a vector")
		print(debugstack())
		x,y = x.x, x.y
	end
	return self:SetScaleInternal(x,y,keep_anim)
end

function Widget:SetScaleInternal(x,y, keep_anim)
	if not keep_anim and self.inst.components.uianim then
		self.inst.components.uianim.scale = nil
	end
	y = y or x

	if self.sx ~= x or self.sy ~= y then
		self.sx, self.sy = x, y
		self:InvalidateBBox()
		self:MarkTransformDirty()
	end
	return self
end

-- In degrees.
function Widget:SetRotation(r)
	if self.r ~= r then
		self.r = r
		self:InvalidateBBox()
		self:MarkTransformDirty()
	end

	return self
end

function Widget:GetBoundingBoxArea()
	local x1,y1,x2,y2 = self:GetBoundingBox()

	return (x2-x1) * (y2-y1)
end

function Widget:_GetBoundingBoxForFullScreen()
	local w, h = RES_X, RES_Y
	local x1, y1, x2, y2 = -w / 2, -h / 2, w / 2, h / 2
	return x1, y1, x2, y2
end

function Widget:GetBoundingBox()
	if self.bboxcache.valid then
		return self.bboxcache.x1, self.bboxcache.y1, self.bboxcache.x2, self.bboxcache.y2
	else
		local x1,x2,y1,y2
		if self.children then
			for k = 1, #self.children do
				local v = self.children[k]
				if v.shown and v.propagate_bb then
					local cx1, cy1, cx2, cy2 = v:GetBoundingBox()
					if cx1 and cy1 and cx2 and cy2 then

						local px1, py1 = v:TransformToParent(cx1, cy1)
						local px2, py2 = v:TransformToParent(cx2, cy2)
						local px3, py3 = v:TransformToParent(cx1, cy2)
						local px4, py4 = v:TransformToParent(cx2, cy1)

						local min_x = min( min(px1, px2), min(px3, px4) )
						local max_x = max( max(px1, px2), max(px3, px4) )

						local min_y = min( min(py1, py2), min(py3, py4) )
						local max_y = max( max(py1, py2), max(py3, py4) )

						x1 = x1 and min(x1, min_x) or min_x
						x2 = x2 and max(x2, max_x) or max_x

						y1 = y1 and min(y1, min_y) or min_y
						y2 = y2 and max(y2, max_y) or max_y
					end
				end
			end
		end
		if not x1 or not y1 then
			x1, y1, x2, y2 = 0, 0, 0, 0

		elseif self.scissor_rect then
			-- Intersect with scissor rect.
			x1, y1, x2, y2 = IntersectRect( x1, y1, x2, y2, table.unpack( self.scissor_rect ))
		end

		self.bboxcache.valid = true
		self.bboxcache.x1, self.bboxcache.y1, self.bboxcache.x2, self.bboxcache.y2 = x1,y1,x2,y2
		return x1,y1,x2,y2
	end
end

function Widget:CalculateBoundingBox( ... )
	local xmin, ymin, xmax, ymax = math.huge, math.huge, -math.huge, -math.huge
	local n = select( "#", ... )
	for i = 1, n do
		local widget = select( i, ... )
		if widget then
			local x0, y0, x1, y1 = widget:GetBoundingBox()
			if y1 then
				x0, y0 = self:TransformFromWorld(widget:TransformToWorld( x0, y0 ))
				x1, y1 = self:TransformFromWorld(widget:TransformToWorld( x1, y1 ))
				xmin = math.min( x0, xmin )
				xmax = math.max( x1, xmax )
				ymin = math.min( y0, ymin )
				ymax = math.max( y1, ymax )
			end
		end
	end
	return xmin, ymin, xmax, ymax
end

function Widget:GetWorldBoundingBox()
	local x1, y1, x2, y2 = self:GetBoundingBox()
	x1, y1 = self:TransformToWorld( x1, y1 )
	x2, y2 = self:TransformToWorld( x2, y2 )
	local xmin = math.min( x1, x2 )
	local xmax = math.max( x1, x2 )
	local ymin = math.min( y1, y2 )
	local ymax = math.max( y1, y2 )

	return xmin, ymin, xmax, ymax
end

function Widget:GetVirtualBoundingBox()
	local xmin, ymin, xmax, ymax = self:GetWorldBoundingBox()
	local scale = TheFrontEnd.base_scale
	return xmin / scale, ymin / scale, xmax / scale, ymax / scale
end

function Widget:SetShowDebugBoundingBox(enabled)
	self.debug_show_boundingbox = enabled == nil or enabled or nil
	return self
end

function Widget:GetShowDebugBoundingBox()
	return self.debug_show_boundingbox
end

function Widget:SetRect(x, y, w, h)
	if self.SetSize then
		-- not all widgets have their own concrete size... not sure what's correct here
		self:SetSize( w, h )
	end
	self:SetPosition( x + w/2, y - h/2 )
	return self
end

function Widget:SetPosition(x,y,z)
	-- this can be called with a vector3 as well
	if type(x) == "table" then
		x,y,z = x.x, x.y, x.z
	end
	if self.x ~= x or self.y ~= y or self.z ~= (z or 0)then
		self.x, self.y, self.z = x or self.x, y or self.y, z or self.z
		self:InvalidateBBox()
		self:MarkTransformDirty()
	end
	return self
end

-- Shim
function Widget:SetPos(x,y,z)
	return self:SetPosition(x,y,z)
end

-- takes either a table of children or a list of children
function Widget:AddChildren(child1, ...)
	local children
	if Widget.is_instance(child1) then
		children = {child1, ...}
	else
	children = child1
	end
	for k, child in ipairs(children) do
		self:AddChild(child)
	end
	self:InvalidateBBox()

	return self
end

-- Lays out this widget relative to the bounding box of 'prev'
function Widget:LayoutBounds( hreg, vreg, prev, _y )
	local dx, dy = self:CalcLayoutBoundsOffset( hreg, vreg, prev, _y )
	self:Offset( dx, dy )
	return self
end

function Widget:CalcLayoutBoundsOffset( hreg, vreg, prev, _y )
	local px1, py1, px2, py2
	local ancestor
	if prev and type(prev) == "number" then
		ancestor = self.parent
		px1, py1 = prev, _y or 0
		px2, py2 = px1, py1

	else
		if prev == nil then
			-- Default to the previous sibling.
			local i = self.parent:IndexOf( self )
			for j = i-1, 1, -1 do
				-- Go backwards through the siblings until you find a visible one
				local sibling = self.parent.children[ j ]
				if sibling and sibling:IsShown() then
					prev = sibling
					break
				end
			end
			-- prev = self.parent.children[ i - 1 ]
		end
		if prev then
			ancestor = self:FindCommonAncestor( prev )
			if ancestor == nil then
				-- Diagnostics for catching crash fix.
				print( "No common ancestor:", prev, self )
				print( prev.removed, self.removed)
			end

			px1, py1, px2, py2 = prev:GetBoundingBox()
			px1, py1 = ancestor:TransformFromWidget( prev, px1, py1 )
			px2, py2 = ancestor:TransformFromWidget( prev, px2, py2 )
			px1, px2 = math.min( px1, px2 ), math.max( px1, px2 )
			py1, py2 = math.min( py1, py2 ), math.max( py1, py2 )
		else
			ancestor = self.parent
			px1, py1 = 0, 0
			px2, py2 = px1, py1
		end
	end

	local x1, y1, x2, y2 = self:GetBoundingBox()
	x1, y1 = ancestor:TransformFromWidget( self, x1, y1 )
	x2, y2 = ancestor:TransformFromWidget( self, x2, y2 )
	-- Align this bounding box next to previous bounding box according to hreg, vreg.
	local dx, dy = 0, 0
	if hreg == "before" then
		dx = px1 - x2 -- Align previous left-bounds to this right-bounds (ie. before prev)
	elseif hreg == "left" then
		dx = px1 - x1 -- Align previous left-bounds to this left-bounds
	elseif hreg == "center_left" then
		dx = px1 -- KAJ - Added - Align center to previous left
	elseif hreg == "left_center" then
		dx = (px1 + px2)/2 - x1 -- Align left-bounds to previous centre point
	elseif hreg == "center" then
		dx = (px1 + px2)/2 - (x1 + x2)/2 -- Align centre points
	elseif hreg == "after" then
		dx = px2 - x1 -- Align previous right-bounds to this left-bounds (ie. after prev)
	elseif hreg == "right_center" then
		dx = (px1 + px2)/2 - x2 -- Align right-bounds to previous centre point
	elseif hreg == "center_right" then
		dx = px2 -- KAJ - Added - Align center to previous right point
	elseif hreg == "right" then
		dx = px2 - x2 -- Align previous right-bounds to this right-bounds
	elseif hreg ~= nil then
		print( "Bad layout hreg specifier:"..tostring(hreg))
	end

	if vreg == "below" then
		dy = py1 - y2 -- Align previous bottom-bounds to this top-bounds (ie. below prev)
	elseif vreg == "bottom" then
		dy = py1 - y1 -- Align previous bottom-bounds to this bottom_bounds
	elseif vreg == "bottom_center" then
		dy = (py1 + py2)/2 - y1 -- Align bottom-bounds to previous centre point
	elseif vreg == "center_bottom" then
		dy = py1 -- KAJ - Added - Align center to previous bottom-bounds
	elseif vreg == "center" then
		dy = (py1 + py2)/2 - (y1 + y2)/2 -- Align centre points
	elseif vreg == "above" then
		dy = py2 - y1 -- Align previous top-bounds to this bottom-bounds (ie. above prev)
	elseif vreg == "top_center" then
		dy = (py1 + py2)/2 - y2-- Align top-bounds to previous centre point
	elseif vreg == "center_top" then
		dy = py2 -- KAJ - Added - Align center to previous top-bounds
	elseif vreg == "top" then
		dy = py2 - y2 -- Align previous top-bounds to this top-bounds
	elseif vreg ~= nil then
		print( "Bad layout vreg specifier:"..tostring(vreg))
	end

	-- This offset is ancestor-space: convert to a local delta.
	dx, dy = self:TransformFromWidget( ancestor, dx, dy )
	local dx0, dy0 = self:TransformFromWidget( ancestor, 0, 0 )
	dx, dy = (dx - dx0) * self.sx * self.layout_scale, (dy - dy0) * self.sy * self.layout_scale

	return dx, dy
end

function Widget:FindCommonAncestor( other )
	local w1 = self
	while w1 do
		local w2 = other
		while w2 do
			if w2 == w1 then
				return w2
			end
			w2 = w2.parent
		end
		w1 = w1.parent
	end
	return nil
end

--takes in x and y in w space and puts it into local space
function Widget:TransformFromWidget(w, x, y)
	w:UpdateTransform(true)
	self:UpdateTransform(true)
	return self:TransformFromWorld(w:TransformToWorld(x,y))
end

function Widget:UpdateAncestorTransforms( world_space )
	if self.ancestordirty and self.parent and (self.parent.ancestordirty or self.parent.dirtytransform) then
		self.parent:UpdateTransform( world_space )
	end
	self.ancestordirty = false
end


function Widget:TransformToWorld(x,y)
	self:UpdateTransform(true)
	if self.node then
		return self.node:LocalToWorld(x or 0, y or 0, 0)
	else
		return 0,0,0
	end
end

function Widget:TransformFromWorld(x,y)
	self:UpdateTransform(true)
	return  self.node:WorldToLocal(x or 0, y or 0, 0)
end

function Widget:Offset( dx, dy )
	self:SetPosition( self.x + (dx or 0), self.y + (dy or 0) )
	return self
end

function Widget:GetScaledSize()
	local cx1, cy1, cx2, cy2 = self:GetBoundingBox()
	if cx1 and cy1 and cx2 and cy2 then

		local px1, py1 = self:TransformToParent(cx1, cy1)
		local px2, py2 = self:TransformToParent(cx2, cy2)
		local px3, py3 = self:TransformToParent(cx1, cy2)
		local px4, py4 = self:TransformToParent(cx2, cy1)

		local min_x = min( min(px1, px2), min(px3, px4) )
		local max_x = max( max(px1, px2), max(px3, px4) )

		local min_y = min( min(py1, py2), min(py3, py4) )
		local max_y = max( max(py1, py2), max(py3, py4) )

		return max_x - min_x, max_y - min_y
	else
		return 0, 0
	end
end

function Widget:TransformToParent(x,y)
	self:UpdateTransform()
	return self.node:TransformPoint(x,y)
end

-- Center children position around our centroid. Useful after
-- LayoutChildrenInGrid when you want grid to be centred on this widget instead
-- at the top left.
function Widget:CenterChildren()
	local offset_to_center = Vector2(self:GetCentroid()) * -1
	for _,w in ipairs(self.children) do
		w:Offset(offset_to_center:unpack())
	end
	return self
end

function Widget:LayoutChildrenInGrid( columns, spacing )
	local first_child
	local pos = 1
	for k, v in ipairs( self.children ) do
		if v:IsShown() then
			first_child = first_child or v
			v:LayoutInGrid( columns, pos, spacing, first_child )
			pos = pos + 1
		end
	end
	return self
end

function Widget:IsShown()
	return self.shown == true
end

-- Lays out this widget relative to its existing siblings in a grid.
--
-- When it wraps to a new row, it aligns itself to the left edge of
-- leftmost_element (which could be the first element on the grid for every
-- call)
function Widget:LayoutInGrid( columns, index, spacing, leftmost_element )
	if self ~= leftmost_element then -- KAJ - added this or the anchoring element will be moved to 0,0
		local newrow = (index % columns == 1) or columns == 1
		local horizontal_spacing = spacing
		local vertical_spacing = spacing
		if (type(spacing) == "table") then
			horizontal_spacing = spacing["h"]
			vertical_spacing = spacing["v"]
		end
		self:LayoutBounds( newrow and "left" or "after", newrow and "below" or "top" )
			:Offset( newrow and 0 or horizontal_spacing, newrow and -vertical_spacing or 0 )
		if newrow then
			self:LayoutBounds( "left", nil, leftmost_element )
		end
	end
	return self
end

-- Lays out children in a grid, even if the children are different sizes.
--
-- It checks the tallest child in each row, and the widest child in each
-- column, and sets their positions accordingly
function Widget:LayoutChildrenInAutoSizeGrid(columns, spacingH, spacingV)

	spacingH = spacingH or 0
	spacingV = spacingV or spacingH or 0

	local maxWidthperColumn = {}
	local maxHeightperRow = {}

	-- Get sizes
	for index, v in ipairs( self.children ) do
		local newrow = ((index - 1) % columns == 1) or columns == 1
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)

		local width, height = v:GetSize()

		maxWidthperColumn[column] = math.max(maxWidthperColumn[column] or 0, width)
		maxHeightperRow[row] = math.max(maxHeightperRow[row] or 0, height)
	end

	-- Position elements
	for index, v in ipairs( self.children ) do
		local newrow = ((index - 1) % columns == 1) or columns == 1
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)

		-- On the first row, position every widget after the previous one (self.children[index - 1])
		-- On the other rows, position widgets to the left of the one above (self.children[index - columns])
		-- On the first column, position every widget below the above one (self.children[index - columns])
		-- On the other columns, position every widget to the top of the one before (self.children[index - 1])
		v:LayoutBounds("left", nil, row == 0 and self.children[index - 1] or self.children[index - columns])
			:LayoutBounds(nil, "top", column == 0 and self.children[index - columns] or self.children[index - 1])
			:Offset(row == 0 and column > 0 and (maxWidthperColumn[column - 1] + spacingH), column == 0 and row > 0 and -(maxHeightperRow[row - 1] + spacingV))
	end

	return self
end

-- Lays out visible children of the widget in a column, independently of their heights, horizontally centered, and with an optional spacing
-- horizontal_alignment can be before, left, center, right, after
-- A position override is optional, to position the first widget in a specific position
function Widget:LayoutChildrenInColumn(spacing, horizontal_alignment, override_first_x, override_first_y)
    spacing = spacing or 0
    horizontal_alignment = horizontal_alignment or "center"
    local to_layout = {}
    for i, v in ipairs( self.children ) do
        if v:IsShown() then
            table.insert(to_layout, v)
        end
    end

    if #to_layout > 0 and (override_first_x or override_first_y) then
        local x, y = to_layout[1]:GetPos()
        x = override_first_x or x
        y = override_first_y or y
        to_layout[1]:LayoutBounds("left","top",x, y)
    end

    for i, child in ipairs( to_layout ) do
        if i > 1 then
            child:LayoutBounds(horizontal_alignment, "below", to_layout[i-1])
                :Offset(0, -spacing)
        end
    end
    return self
end

-- Lays out visible children of the widget in a row, independently of their widths, vertically centered, and with an optional spacing
-- vertical_alignment can be above, top, center, bottom, below
-- A position override is optional, to position the first widget in a specific position
function Widget:LayoutChildrenInRow(spacing, vertical_alignment, override_first_x, override_first_y)
    spacing = spacing or 0
    vertical_alignment = vertical_alignment or "center"
    local to_layout = {}
    for i, v in ipairs( self.children ) do
        if v:IsShown() then
            table.insert(to_layout, v)
        end
    end

    if #to_layout > 0 and (override_first_x or override_first_y) then
        local x, y = to_layout[1]:GetPos()
        x = override_first_x or x
        y = override_first_y or y
        to_layout[1]:LayoutBounds("left","top",x, y)
    end

    for i, child in ipairs( to_layout ) do
        if i > 1 then
            child:LayoutBounds("after", vertical_alignment, to_layout[i-1])
                :Offset(spacing, 0)
        end
    end
    return self
end

-- Lays out widgets in a pleasing diagonally-offset fashion
-- 2 widgets show side by side
-- 3 widgets show two on the first row, one on the second, in the middle
-- 4 show two and two
-- 5 show three and two
-- 6 show three and three
-- 7 show three, two, two
-- 8 show three, two, three
-- everything else shows five, four, five, four, ...
-- If there's a max_columns set, odd rows will have that number, even ones will have max-1
-- If there's an evenrow_offset, even rows will be offset by that amount,
--  otherwise they'll be offset by half of the first widget's width + half the spacing_h
function Widget:LayoutInDiagonal(max_columns, spacing_h, spacing_v, evenrow_offset)
	spacing_h = spacing_h or 10
	spacing_v = spacing_v or spacing_h

	local to_layout = {}
    for i, v in ipairs( self.children ) do
        if v:IsShown() then
            table.insert(to_layout, v)
        end
    end

    if #to_layout == 0 then return self end

    -- Get the width of the first widget
	local widget_w = to_layout[1]:GetSize()

    -- Check how many columns we need
    local oddrow_columns = 0
    local evenrow_columns = 0
    local evenrow_columns_offset = evenrow_offset or (widget_w/2 + spacing_h/2)
    if #to_layout == 2
		or #to_layout == 3
		or #to_layout == 4
	then
		oddrow_columns = 2
		evenrow_columns = 2

    elseif #to_layout == 5
		or #to_layout == 7
		or #to_layout == 8
	then
		oddrow_columns = 3
		evenrow_columns = 2

    elseif #to_layout == 6 then
		oddrow_columns = 3
		evenrow_columns = 3

	else
		oddrow_columns = 5
		evenrow_columns = 4
    end

    -- Apply max if any
    if max_columns and oddrow_columns > max_columns then
		oddrow_columns = max_columns
		evenrow_columns = (max_columns) - 1
    end

    local current_column = 1
    local current_row = 1
    local newrow = false
	for index, v in ipairs( to_layout ) do

		-- Check if this is an even row
		local even_row = current_row%2 == 0

		-- Position the widget
		if newrow then
			v:LayoutBounds("left", nil, to_layout[1])
				:LayoutBounds(nil, "below", to_layout[index - 1])
				:Offset(even_row and evenrow_columns_offset or 0, -spacing_v)
		else
			v:LayoutBounds("after", "center", to_layout[index - 1])
				:Offset(spacing_h, 0)
		end


		------------------------------------------------------------------------------------
		------------------------------------------------------------------------------------
		-- Renav and set up the focus directions for all the items

		if current_column > 1 then
			-- Link left to the previous widget
			v:SetFocusDir("left", to_layout[index - 1], true)
		end

		if current_row > 1 then
			-- Link up to the above widget
			-- This is trickier because of the difference in column counts between odd and even rows
			-- If we're on an even row, subtract the number of columns in the row before (odd)
			-- If we're on an odd row, subtract the number of columns in the row before (even)
			if even_row then
				v:SetFocusDir("up", to_layout[index - oddrow_columns], true)
			else
				v:SetFocusDir("up", to_layout[index - evenrow_columns], true)
			end
		end
		------------------------------------------------------------------------------------
		------------------------------------------------------------------------------------


		-- If this was a new row, the next one isn't
		if newrow then
			newrow = false
		end

		-- Increase the column for the next widget
		current_column = current_column + 1

		-- Check if the next widget should go to a new row
		if even_row and current_column > evenrow_columns then
			current_column = 1
			newrow = true
			current_row = current_row + 1
		end
		if not even_row and current_column > oddrow_columns then
			current_column = 1
			newrow = true
			current_row = current_row + 1
		end
    end

	return self
end

function Widget:IndexOf(child)
	return table.arrayfind( self.children, child )
end

-- Lays out the children in a row next to each other, based on their widths and spacing
function Widget:StackChildrenRow( spacing )
    local num = self.children and #self.children or 0
    local current_x = 0
    spacing = spacing or 0
    if num > 0 then
        for k, v in ipairs(self.children) do
            -- Get current widget dimensions
            local w, h = v:GetScaledSize()
            -- Check if it should be laid out
            if v:IsShown() and w > 0 then
                current_x = current_x + w/2
                v:LayoutBounds( "center", nil, current_x, 0 )
                current_x = current_x + w/2 + spacing
            end
        end
    end
    return self
end


-- Lays out the children at a fixed interval, independently of their widths
function Widget:ArrangeChildrenRow(offset)
	local num = self.children and #self.children or 0
	if num > 0 then
		local w = (num-1)*offset
		for k,v in ipairs(self.children) do
			local x = -w/2+(k-1)*offset
			v:SetPosition(x, nil)
		end
	end

	return self
end

function Widget:ArrangeChildrenColumn(offset)
	local num = self.children and #self.children or 0
	if num > 0 then
		local h = (num-1)*offset
		for k,v in ipairs(self.children) do
			local y = h/2-(k-1)*offset
			v:SetPosition(0, y)
		end
	end
	return self
end

function Widget:SetRegistrationInternal(hreg, vreg)
	self.hreg = hreg
	self.vreg = vreg

	local w, h = self:GetSize()
	local x, y = self:GetCentroid()

	-- KAJ - added or it doesn't work with scaled images - GetScaledSize would end up calling here
	w = w * self.sx
	h = h * self.sy

	if hreg == "center" then
		self.regx = -x
	elseif hreg == "left" then
		self.regx = -x + w/2
	elseif hreg == "right" then
		self.regx = -x - w/2
	else
		-- KAJ - added so we can also pass 0..1 for reg
		kassert.typeof("number", hreg, "SetRegistration expects (hreg, vreg)")
		self.regx = -x + w/2 - w * hreg
	end


	if vreg == "center" then
		self.regy = -y
	elseif vreg == "bottom" then
		self.regy = -y + h/2
	elseif vreg == "top" then
		self.regy = -y - h/2
	else
		-- KAJ - added so we can also pass 0..1 for reg
		kassert.typeof("number", vreg, "SetRegistration expects (hreg, vreg)")
		self.regy = -y - h/2 + h * vreg
	end

	return self
end

-- Set the pivot position this widget uses to determine its render origin.
-- During layout we find our anchor position on our parent and add
-- our position as an offset.
--
-- Essentially: how the widget is positioned relative to itself.
--
-- See SetAnchors to set the anchor position we use on the parent.
--
-- By default, widgets are implicitly registered center, center.
--
-- Set b's anchor to position it relative to its top left corner:
--   a:AddChild(b)
--     :SetRegistration("left", "top")
-- ┌───────────┐
-- │aaaaaaaaaaa│
-- │aaaaaaaaaaa│
-- │aaaaa┌───────┐
-- │aaaaa│bbbbbbb│
-- │aaaaa│bbbbbbb│
-- └─────│bbbbbbb│
--       └───────┘
-- Also set anchor to position our corner on parent's corner:
--   a:AddChild(b)
--     :SetRegistration("left", "top")
--     :SetAnchors("right", "bottom")
-- ┌───────────┐
-- │aaaaaaaaaaa│
-- │aaaaaaaaaaa│
-- │aaaaaaaaaaa│
-- │aaaaaaaaaaa│
-- │aaaaaaaaaaa│
-- └───────────┌───────┐
--             │bbbbbbb│
--             │bbbbbbb│
--             │bbbbbbb│
--             └───────┘
function Widget:SetRegistration(hreg, vreg)
	local oldrx, oldry = self.regx, self.regy

	self:SetRegistrationInternal(hreg, vreg)

	if oldrx ~= self.regx or oldry ~= self.regy then
		self:MarkTransformDirty()
		self:InvalidateBBox()
	end
	return self
end

function Widget:GetCentroid()
	local bx1,by1,bx2,by2 = self:GetBoundingBox()
	if bx1 then
		return (bx1+bx2)/2, (by2+by1)/2
	end
	return 0,0
end

function Widget:OnScreenResize(w,h)
	if self.children then
		for k,v in pairs(self.children) do
			v:OnScreenResize(w,h)
		end
	end

	if self.hanchor or self.vanchor or self.base_scaling == true then
		self:UpdateAnchors()
		self:MarkTransformDirty()
	end
end

function Widget:Remove()
	kassert.assert_fmt( not self.removed, "Double removing widget [%s].", self._widgetname )

	self:StopUpdating()
	self:ClearFocus()
--    self:ClearHover() -- Not sure I want this when using the old focus code

	while #self.children > 0 do
		self.children[ #self.children ]:Remove()
	end

	-- Detach from parent first: access to children etc. must still be valid for
	-- OnRemoved handlers.
	self.parent:_RemoveChild(self)
	assert( self.parent == nil, "Failed to remove child from parent." )


	-- Destroy widget properties.
	self.removed = true

	self.model = nil

-- TODO_KAJ    self.node:Clear()
-- TODO_KAJ    RecycleSceneGraphNode(self.node)

	if self.satval then
-- TODO_KAJ        RecycleShaderConstant(self.satval)
-- TODO_KAJ        self.satval = nil
	end

	if self.tint_mult_constant then
-- TODO_KAJ        RecycleShaderConstant(self.tint_mult_constant)
-- TODO_KAJ        self.tint_mult_constant = nil
	end

	self.node = nil
	if self.fe then
		self.fe.dirtytransforms[self] = nil
	end

	if self.fe and self.is_updating then
		self.is_updating = false
		self.fe:StopUpdatingWidget(self)
	end

	-- remove the entity -- which is the model in GL I guess, so maybe the model should be the uitransform and the node the transform?
	self.inst.widget = nil
	self.inst.has_removed_widget = true
	--self:StopFollowMouse()
	self.inst:Remove()

end

-- Call Widget:Remove() or Widget:Reparent() instead.
--
-- _RemoveChild is not reversible, so you might as well destroy the widget
-- instead. See GL r360289.
function Widget:_RemoveChild(child)
	for k = 1, #self.children do
		local v = self.children[k]
		if v == child then
			if child.listening_to then
				for k,v in pairs(child.listening_to) do
					k:RemoveListener( child )
				end
				child.listening_to = nil
			end

			child:ClearFocus()
--            child:ClearHover()	-- KAJ: Don't think this is needed in our setup?

--            child:StopListeningForAllGlobalEvents() -- KAJ: TODO, do I need this?
			child:StopAll()

			if child.is_updating and self.fe then
				child.is_updating = false
				self.fe:StopUpdatingWidget(child)
			end

			-- While this is inside _RemoveChild, it fires whenever a widget is
			-- removed (except for screen/scene root which are never destroyed).
			if child.OnRemoved then
				child:OnRemoved()
			end

			if child.coros then
				for k,v in pairs(child.coros) do
					v:Stop()
				end
			end

			if child.running_updaters then
				table.clear( child.running_updaters )
			end

			child._widget_owning_screen = nil
			child.parent = nil
			table.remove(self.children, k)
--            child.node:Orphan() -- KAJ - why is this not an issue in the old version?

			self:InvalidateBBox()
			child:UpdateViz()
			return
		end
	end
	error() -- Stop removing children that don't exist.
end

function Widget:StopAll()
	if self.inst.components.uianim then
		self.inst.components.uianim:StopAll()
	end
	return self
end

--KAJ Shim for old code
function Widget:Kill()
	self:Remove()
	return self
end

function Widget:RemoveAllChildren()
	while #self.children > 0 do
		self.children[ #self.children ]:Remove()
	end
	return self
end

--KAJ Shim for old code
function Widget:KillAllChildren()
	return self:RemoveAllChildren()
end

function Widget:IsAncestorOf( w )
	local parent = w.parent
	while parent do
		if parent == self then
			return true
		end
		parent = parent.parent
	end

	return false
end

-- MultColor
function Widget:SetMultColor(r,g,b,a)
	assert(r, "You must pass a color!")
	if type(r) == "number" then
		if not g then
			-- hex value
			r,g,b,a = HexToRGBFloats(r)
			-- else: r,g,b,a, all good
		end
	else
		-- table
		r,g,b,a = r[1],r[2],r[3],r[4]
	end
	self.mult_r = r
	self.mult_g = g
	self.mult_b = b
	self.mult_a = a

	self:UpdateMultColorInternal()
	return self
end

function Widget:GetMultColor()
	return self.mult_r, self.mult_g, self.mult_b, self.mult_a
end

function Widget:SetMultColorAlpha(a)
	local old_a = self.mult_a or 1
	assert(a)
	self.mult_a = a
	self:UpdateMultColorInternal()

	return self
end

function Widget:GetMultColorAlpha()
	return self.mult_a or 1
end

function Widget:UpdateMultColorInternal()
	self.resolved_mult_r, self.resolved_mult_g, self.resolved_mult_b, self.resolved_mult_a = self:GetResolvedMultColor()

	self:ApplyMultColor(self.resolved_mult_r, self.resolved_mult_g, self.resolved_mult_b, self.resolved_mult_a)

	if self.children then
		for k,v in pairs(self.children) do
			v:ApplyMultColorFromParent(self.resolved_mult_r, self.resolved_mult_g, self.resolved_mult_b, self.resolved_mult_a)
		end
	end
end

function Widget:GetResolvedMultColor()

	if self.parent and not self.ignoreparentmultcolor then
		local r,g,b,a = self.parent:GetResolvedMultColor()
		return (self.mult_r or 1)*r, (self.mult_g or 1)*g, (self.mult_b or 1)*b, (self.mult_a or 1)*a
	end

	return self.mult_r or 1, self.mult_g or 1, self.mult_b or 1, self.mult_a or 1
end

function Widget:ApplyMultColor(r,g,b,a)
	-- KAJ: This needs to be overridden for entities that have a visual. This is different from GL
	return self
end

function Widget:ApplyMultColorFromParent(parent_r,parent_g,parent_b,parent_a)
	if self.ignoreparentmultcolor then
		self.resolved_mult_r = self.mult_r or 1
		self.resolved_mult_g = self.mult_g or 1
		self.resolved_mult_b = self.mult_b or 1
		self.resolved_mult_a = self.mult_a or 1
	else
		self.resolved_mult_r = (parent_r or 1) * (self.mult_r or 1)
		self.resolved_mult_g = (parent_g or 1) * (self.mult_g or 1)
		self.resolved_mult_b = (parent_b or 1) * (self.mult_b or 1)
		self.resolved_mult_a = (parent_a or 1) * (self.mult_a or 1)
	end

	self:ApplyMultColor(self.resolved_mult_r, self.resolved_mult_g, self.resolved_mult_b, self.resolved_mult_a)

	if self.children then
		for k,v in pairs(self.children) do
			v:ApplyMultColorFromParent(self.resolved_mult_r, self.resolved_mult_g, self.resolved_mult_b, self.resolved_mult_a)
		end
	end
end

function Widget:IgnoreParentMultColor(val)
	self.ignoreparentmultcolor = val == nil or val
	self:UpdateMultColorInternal()
	return self
end

-- AddColor
function Widget:SetAddColor(r,g,b,a)

	if r and g and b then
		a = a or 0
	elseif r then
		r,g,b,a = r[1],r[2],r[3],r[4]
	end
	self.add_r = r
	self.add_g = g
	self.add_b = b
	self.add_a = a

	self:UpdateAddColorInternal()
	return self
end

function Widget:GetAddColor()
	return self.add_r, self.add_g, self.add_b, self.add_a
end

function Widget:SetAddAlpha(a)
	local old_a = self.add_a or 0
	assert(a)
	self.add_a = a
	self:UpdateAddColorInternal()

	return self
end

function Widget:GetAddColorAlpha()
	return self.add_a or 0
end

function Widget:UpdateAddColorInternal()
	self.resolved_add_r, self.resolved_add_g, self.resolved_add_b, self.resolved_add_a = self:GetResolvedAddColor()

	self:ApplyAddColor(self.resolved_add_r, self.resolved_add_g, self.resolved_add_b, self.resolved_add_a)

	if self.children then
		for k,v in pairs(self.children) do
			v:ApplyAddColorFromParent(self.resolved_add_r, self.resolved_add_g, self.resolved_add_b, self.resolved_add_a)
		end
	end
end

function Widget:GetResolvedAddColor()

	if self.parent and not self.ignoreparentaddcolor then
		local r,g,b,a = self.parent:GetResolvedAddColor()
		return (self.add_r or 0) + r, (self.add_g or 0) + g, (self.add_b or 0) + b, (self.add_a or 0) + a
	end

	return self.add_r or 0, self.add_g or 0, self.add_b or 0, self.add_a or 0
end

function Widget:ApplyAddColor(r,g,b,a)
	-- KAJ: This needs to be overridden for entities that have a visual. This is different from GL
	return self
end

function Widget:ApplyAddColorFromParent(parent_r,parent_g,parent_b,parent_a)
	if self.ignoreparentaddcolor then
		self.resolved_add_r = self.add_r or 0
		self.resolved_add_g = self.add_g or 0
		self.resolved_add_b = self.add_b or 0
		self.resolved_add_a = self.add_a or 0
	else
		self.resolved_add_r = (parent_r or 0) + (self.add_r or 0)
		self.resolved_add_g = (parent_g or 0) + (self.add_g or 0)
		self.resolved_add_b = (parent_b or 0) + (self.add_b or 0)
		self.resolved_add_a = (parent_a or 0) + (self.add_a or 0)
	end

	self:ApplyAddColor(self.resolved_add_r, self.resolved_add_g, self.resolved_add_b, self.resolved_add_a)

	if self.children then
		for k,v in pairs(self.children) do
			v:ApplyAddColorFromParent(self.resolved_add_r, self.resolved_add_g, self.resolved_add_b, self.resolved_add_a)
		end
	end
end

function Widget:IgnoreParentAddColor(val)
	self.ignoreparentaddcolor = val == nil or val
	self:UpdateAddColorInternal()
	return self
end

-- Saturation
function Widget:SetSaturation(saturation)

	self.saturation = saturation

	self:UpdateSaturationInternal()
	return self
end

function Widget:GetSaturation()
	return self.saturation
end

function Widget:UpdateSaturationInternal()
	self.resolved_saturation = self:GetResolvedSaturation()

	self:ApplySaturation(self.resolved_saturation)

	if self.children then
		for k,v in pairs(self.children) do
			v:SetSaturation(self.resolved_saturation)
			-- v:ApplySaturation(self.resolved_saturation)
		end
	end
end

function Widget:GetResolvedSaturation()

	if self.parent and not self.ignoreparentsaturation then
		local saturation = self.parent:GetResolvedSaturation()
		return (self.saturation or 1) * saturation
	end

	return self.saturation or 1
end

function Widget:ApplySaturation(saturation)
	-- KAJ: This needs to be overridden for entities that have a visual. This is different from GL
	return self
end

function Widget:ApplySaturationFromParent(parent_saturation)
	if self.ignoreparentsaturation then
		self.resolved_saturation = self.saturation or 1
	else
		self.resolved_saturation = (parent_saturation or 1) * (self.saturation or 1)
	end

	self:ApplySaturation(self.resolved_saturation)

	if self.children then
		for k,v in pairs(self.children) do
			v:ApplySaturationFromParent(self.resolved_saturation)
		end
	end
end

function Widget:IgnoreParentSaturation(val)
	self.ignoreparentsaturation = val == nil or val
	self:UpdateSaturationInternal()
	return self
end

-- brightness
function Widget:SetBrightness(brightness)

	self.brightness = brightness

	self:UpdateBrightnessInternal()
	return self
end

function Widget:GetBrightness()
	return self.brightness
end

function Widget:UpdateBrightnessInternal()
	self.resolved_brightness = self:GetResolvedBrightness()

	self:ApplyBrightness(self.resolved_brightness)

	if self.children then
		for k,v in pairs(self.children) do
			v:ApplyBrightness(self.resolved_brightness)
		end
	end
end

function Widget:GetResolvedBrightness()

	if self.parent and not self.ignoreparentbrightness then
		local brightness = self.parent:GetResolvedBrightness()
		return (self.brightness or 1) * brightness
	end

	return self.brightness or 1
end

function Widget:ApplyBrightness(brightness)
	-- KAJ: This needs to be overridden for entities that have a visual. This is different from GL
	return self
end

function Widget:ApplyBrightnessFromParent(parent_brightness)
	if self.ignoreparentbrightness then
		self.resolved_brightness = self.brightness or 1
	else
		self.resolved_brightness = (parent_brightness or 1) * (self.brightness or 1)
	end

	self:ApplyBrightness(self.resolved_brightness)

	if self.children then
		for k,v in pairs(self.children) do
			v:ApplyBrightnessFromParent(self.resolved_brightness)
		end
	end
end

function Widget:IgnoreParentBrightness(val)
	self.ignoreparentbrightness = val == nil or val
	self:UpdateBrightnessInternal()
	return self
end

-- Hue
function Widget:SetHue(hue)

	self.hue = hue

	self:UpdateHueInternal()
	return self
end

function Widget:GetHue()
	return self.hue
end

function Widget:UpdateHueInternal()
	self.resolved_hue= self:GetResolvedHue()

	self:ApplyHue(self.resolved_hue)

	if self.children then
		for k,v in pairs(self.children) do
			v:ApplyHueFromParent(self.resolved_hue)
		end
	end
end

function Widget:GetResolvedHue()

	if self.parent and not self.ignoreparenthue then
		local hue = self.parent:GetResolvedHue()
		return (self.hue or 0) + hue
	end

	return self.hue or 0
end

function Widget:ApplyHue(hue)
	-- KAJ: This needs to be overridden for entities that have a visual. This is different from GL
	return self
end

function Widget:ApplyHueFromParent(parent_hue)
	if self.ignoreparenthue then
		self.resolved_hue = self.hue or 0
	else
		self.resolved_hue = (parent_hue or 0) + (self.add_hue or 0)
	end

	self:ApplyHue(self.resolved_hue)

	if self.children then
		for k,v in pairs(self.children) do
			v:ApplyHueFromParent(self.resolved_hue)
		end
	end
end

function Widget:IgnoreParentHue(val)
	self.ignoreparenthue = val == nil or val
	self:UpdateHueInternal()
	return self
end
-- \Hue


function Widget:IgnoreParentColorTransform(val)
	self:IgnoreParentMultColor(val)
	self:IgnoreParentAddColor(val)
	self:IgnoreParentHue(val)
	self:IgnoreParentBrightness(val)
	self:IgnoreParentSaturation(val)
	return self
end

--this is a scale meant to accomdate different screen layouts (TV, mobile, monitor, etc) without changing the underlying code
function Widget:SetLayoutScale(sc)
	if self.layout_scale ~= sc then
		self.layout_scale = sc
		self:InvalidateBBox()
		self:MarkTransformDirty()
	end
	return self
end

function Widget:GetScale()
	return self.sx, self.sy
end

function Widget:RunUpdater(updater, _guard)
	assert(_guard == nil, "Should you be using a series node, Ricardo?")
	if not self.inst.components.uiupdater then
		self.inst:AddComponent("uiupdater")
	end
	return self.inst.components.uiupdater:RunUpdater(updater)
end


function Widget:StopUpdater(updater)
	if self.inst.components.uiupdater then
		self.inst.components.uiupdater:StopUpdater(updater)
	end
end

function Widget:ShouldBeUpdating()
	return  (self.update_requested and self.OnUpdate ~= Widget.OnUpdate)
end

function Widget:OnUpdate(dt)
	--there's no reason to be updating. stop it.
	if not self:ShouldBeUpdating() then
		self.is_updating = false
		TheFrontEnd:StopUpdatingWidget(self)
	end
end

function Widget:StartUpdating()
	self.update_requested = true
	self:TestUpdateStart()
end

function Widget:TestUpdateStart()
	assert( not self.removed )
	if self:ShouldBeUpdating() and not self.is_updating then
		self.is_updating = true
		TheFrontEnd:StartUpdatingWidget(self)
	end
	return self
end

function Widget:StopUpdating()
	self.update_requested = false

	if not self:ShouldBeUpdating() then
		self.is_updating = false
		TheFrontEnd:StopUpdatingWidget(self)
	end
end

--------------------------- TOOLTIP
-- The callback attributes are (focus_widget, tooltip_widget)
function Widget:SetToolTipLayoutFn(fn)
	self.tooltiplayoutfn = fn
	return self
end

function Widget:GetToolTipLayoutFn()
	return self.tooltiplayoutfn
end

function Widget:SetToolTipFn(fn)
	assert( type(fn) == "function" )
	self:SetHoverCheck(true)
	self.tooltipfn = fn
	return self
end

function Widget:GetToolTipClass()
	return self.tooltip_class
end

function Widget:SetToolTipClass( tt_class )
	self.tooltip_class = tt_class
	return self
end

function Widget:DisableToolTip(should_disable)
	assert(should_disable ~= nil)
	self.tooltip_disabled = should_disable
	return self
end

function Widget:SetToolTip(tt)
	--assert(tt == nil or type(tt) == "string", "Why do you want to set nonstring data in a tooltip?")
	assert(self.tooltipfn == nil, "Text Tooltip will be ignored after calling SetToolTipFn.")

	if type(tt) == "string" and #tt == 0 then
		tt = nil
	end

	if not self.hover_check and tt ~= nil then
		self:SetHoverCheck(true)
	end

	if tt ~= self.tooltip then
		self.tooltip = tt
		self:SetToolTipDirty( true )
	end

	return self
end

function Widget:GetToolTip()
	if self.tooltip_disabled then
		return
	end

	if self.tooltipfn then
		return self.tooltipfn(self)
	end
	return self.tooltip
end

function Widget:ShowToolTipOnFocus( show )
	self.show_tooltip_on_focus = show ~= false
	return self
end

function Widget:SetToolTipDirty( dirty )
	self.tooltip_dirty = dirty
end

function Widget:GetToolTipDirty()
	return self.tooltip_dirty
end

--------------------------- /TOOLTIP
--function Widget:GetSize()
--	return 0,0
--end
function Widget:GetSize()
	local bx1,by1,bx2,by2 = self:GetBoundingBox()
	if bx1 and bx2 and by1 and by2 then
		return math.abs(bx2 - bx1), math.abs(by2 - by1)
	else
		return 0, 0
	end
end



function Widget:SetBaseScaling( val )
	-- true: base scaling applied
	-- false: base scaling NOT applied
	-- nil: base scaling applied if hanchor/vanchor set (default)
	self.base_scaling = val
	if self.children then
		for k,v in pairs(self.children) do
--            v:SetBaseScaling( val )
		end
	end
	self:MarkTransformDirty()
	self:InvalidateBBox()
	return self
end

-- To make an overlay widget, use SetClickable instead.
function Widget:SetBlocksMouse(blocks)
	dbassert(blocks ~= nil)
	self.blocks_mouse = blocks
	return self
end

function Widget:SetHoverCheck(check)
	dbassert(check ~= nil)
	self.hover_check = check
	return self
end

function Widget:SetFullscreenHit(fullscreen)
	self.fullscreen_hit = fullscreen
	return self
end

-- TODO(dbriscoe): Rename to SetPropagatesBoundingBox
function Widget:SetHiddenBoundingBox( hidden )
	if hidden then
	-- KAJ: I am not sold on this. Shouldn't this be ignores input
--        self:SetHoverCheck(false)
--        self:SetBlocksMouse(false)
	end
	-- If true this widget's BB will contribute to the parent's BB.
	self.propagate_bb = not hidden
	return self
end

-- Removes from current parent and attaches to a new parent while preserving world bounds.
function Widget:Reparent( new_parent )

	assert( new_parent )
	assert( self.parent )

	self:ClearFocus()

	local x, y = new_parent:TransformFromWidget( self, 0, 0 )
	local old_sx, old_sy = self:GetResolvedScale()

	local idx = table.arrayfind( self.parent.children, self )
	assert( idx )
	table.remove( self.parent.children, idx )
	--self.node:Orphan()
	self.parent = nil

	new_parent:AddChild( self )

	local new_sx, new_sy = self:GetResolvedScale()
	local adj_sx, adj_sy = old_sx / new_sx, old_sy / new_sy
	self:SetPosition( x, y )
		:SetScale( self.sx * adj_sx, self.sy * adj_sy )
	return self
end

-- Sort children by input comparison function.
--   w:SortChildren(function(a, b)
--   	return a.player:GetHunterId() < b.player:GetHunterId()
--   end)
-- Child order determines which widget is on top and order for
-- LayoutChildrenIn* functions.
function Widget:SortChildren(cmp)
	kassert.typeof("function", cmp)
	local kids = shallowcopy(self.children)
	table.sort(kids, cmp)
	for _,w in ipairs(kids) do
		w:SendToFront()
	end
	dbassert(kids[1] == self.children[1], "Reordering function failed to set correct order.")
	return self
end

function Widget:SendToBack()
	local removed = table.removearrayvalue(self.parent.children, self)
	assert(removed == self)
	table.insert( self.parent.children, 1, self )
	self.inst.entity:MoveToBack()
	return self
end

function Widget:SendToFront()
	local removed = table.removearrayvalue(self.parent.children, self)
	assert(removed == self)
	table.insert( self.parent.children, self )
	self.inst.entity:MoveToFront()
	return self
end

-- TODO_KAJ I doubt this works?
--[[
function Widget:SendBehind( widget )
	assert( widget.node )
	local removed = table.removearrayvalue(self.parent.children, self)
	assert(removed == self)
	local idx = table.arrayfind( self.parent.children, widget )
	table.insert( self.parent.children, idx, self )
	self.inst.entity:MoveBehind( widget.node )
	return self
end
]]

-- Shim
function Widget:MoveToBack()
	return self:SendToBack()
end

-- Shim
function Widget:MoveToFront()
	return self:SendToFront()
end

function Widget:SetShown( is_shown )
	if not is_shown and self.shown then
		self:Hide()
	elseif is_shown and not self.shown then
		self:Show()
	end
	return self
end

function Widget:GetNestedScale()
	local sx, sy = self.sx, self.sy
	if self.parent ~= nil then
		local scale = self.parent:GetNestedScale()
		return Vector3(sx * scale.x, sy * scale.y, scale.z)
	end
	return Vector3(sx, sy, 1)
end

function Widget:SetHover(from_child)
	if not self.hover then
		if self.parent then
			self.parent:SetHover(self)
		end
		self.hover = true
		if self.hover_sound then
			TheFrontEnd:GetSound():PlaySound(self.hover_sound)
		end
		self:OnGainHover()
		if self.ongainhoverfn then
			self.ongainhoverfn()
		end
	end

	if self.children then
		for k = 1, #self.children do
			local v = self.children[k]
			if v.hover and v ~= from_child then
				v:ClearHover()
			end
		end
	end
end

function Widget:ClearHover()
	if self.hover then
		self.hover = false
		self:OnLoseHover()
		if self.onlosehoverfn then
			self.onlosehoverfn()
		end
		if self.children then
			for k = 1, #self.children do
				local v = self.children[k]
				if v.hover then
					v:ClearHover()
				end
			end
		end
	end
end

function Widget:SetOnGainHover( fn )
	self.ongainhoverfn = fn
	return self
end

function Widget:SetOnLoseHover( fn )
	self.onlosehoverfn = fn
	return self
end

function Widget:OnGainHover()
end

function Widget:OnLoseHover()
end

function Widget:IgnoreInput(ignore)
	self.ignore_input = ignore ~= false
	if self.ignore_input and self.focus then
		-- We check ignore_input elsewhere when trying to give focus, but
		-- otherwise only check self.focus for interactions. So you should
		-- never have focus when ignoring input.
		self:ClearFocus()
	end
--    self:SetHoverCheck(false)
--    self:SetBlocksMouse(false)
--    self.inst:AddTag("NOCLICK")
	return self
end

function Widget:CheckMouseHover(x,y,trace)

	if trace then
		trace:PushWidget( self )
	end

--    if self.ignore_input or not self.shown or self.dragging then -- uh, why can I not gain focus when dragging?
	if self.ignore_input or not self.shown then
		if trace then
			trace:PopWidget( "false : early bail" )
		end
		return false
	end


	if self.hover_check or self.blocks_mouse then
		local hit = self:CheckHit(x, y)
		if not hit then
			if trace then
				trace:PopWidget(string.format( "false : intersection %.1f, %.1f", x, y ))
			end
			return false
		end
	end

	if self.scissor_rect then
		local lx, ly = self:TransformFromWorld(x,y)
		local x1, y1, x2, y2 = table.unpack( self.scissor_rect )
		if lx < x1 or lx > x2 or ly < y1 or ly > y2 then
			if trace then
				trace:PopWidget( "false : scissor" )
			end
			return false -- Never hit success outside the scissor region.
		end
	end

	local is_blocked = false
	if self.children then
		for i = #self.children, 1, -1 do
			local child = self.children[i]
			if child
				and child.shown
				and ((child.children
					and #child.children > 0) or child.hover_check or child.blocks_mouse)
			then
				local blocked, hover = child:CheckMouseHover(x,y,trace)
				if blocked and hover then
					if trace then
						trace:PopWidget( "true : child blocked and hover" )
					end
					return blocked, hover
				elseif blocked then
					is_blocked = true
					break
				end
			end
		end
	end

	if self.hover_check or self.blocks_mouse then
		if self.hover_check then
			if trace then
				trace:PopWidget( "true : hover check" )
			end
			return true, self
		end

		if self.blocks_mouse then
			if trace then
				trace:PopWidget( "true : blocks_mouse" )
			end
			return true
		end
	end

	if trace then
		trace:PopWidget( string.format( "%s: return", tostring(is_blocked)))
	end
	return is_blocked
end

function Widget:CheckHit(x,y)
	if self.fullscreen_hit then
		return true
	end

	local lx, ly = self:TransformFromWorld(x,y)
	local x1,y1,x2,y2 = self:GetBoundingBox()
	if x1 and y1 and x2 and y2 then
		if lx >= x1 and lx <= x2 and ly >= y1 and ly <= y2 then
			return true
		end
	end

	return false
end

function Widget:SetStencilContext(val)
	val = val == nil or val
	self.node:SetStencilContext(val)
	return self
end

function Widget:SetStencilWrite(val)
	assert(val ~= nil, "Pass a STENCIL_MODES value or a bool.")
	self.node:SetStencilWrite(val)
	return self
end

function Widget:SetStencilTest(val)
	val = val == nil or val
	self.stencil_test = val or nil
	self.node:SetStencilTest(val)
	return self
end

-- This widget will be drawn only within the mask set by an Image/UIAnim drawn before.
-- The Mask can be used by:
-- * any descendents of the Mask
-- * any of siblings of the Mask that it's behind (SendToBack) or their descendents.
--
-- So all of these hierarchies should mask the tiles with frame_mask with
-- visible frame on top.
-- * root                                  * root
--   * frame_mask (SetMask)                  * frame_mask (SetMask)
--   * tile1 (SetMasked)                       * tile1 (SetMasked)
--   * tile2 (SetMasked)                       * tile2 (SetMasked)
--   * frame                                 * frame
--
-- * root                                  * root
--   * frame_mask (SetMask)                  * frame_mask (SetMask)
--   * tile_root (SetMasked)                 * tile_root
--     * tile1                                 * tile1 (SetMasked)
--     * tile2                                 * tile2 (SetMasked)
--   * frame                                 * frame
--
-- Nested masking (a child that also uses SetMask) is not supported.
function Widget:SetMasked(val)
	self:SetStencilTest(val)
	return self
end

function Widget:SetName(name)
	self._widgetname = name
	--self.node:SetName(name)
	self.inst.entity:SetName(name)
	return self
end

-- Can receive focus from navigation. Doesn't affect mouse focus.
function Widget:SetNavFocusable( focusable )
	self.can_focus_with_nav = focusable ~= false
	return self
end

-- void shim
function Widget:Bloom()
--	print("*** not implemented - Widget:Bloom ***")
--	print(debugstack())
	return self
end

-- Play a sound with parameters describing where it's positioned on screen. Use
-- with either / one of the "SpatialUI_" stereo panner presets in FMOD.
function Widget:PlaySpatialSound(eventname, params, volume, isautostop, ispredicted)
	local pos = self:GetNormalizedScreenPosition()
	local all_params = {
		screenPosition_X = pos.x,
		screenPosition_Y = pos.y,
	}
	all_params = lume.overlaymaps(all_params, params)
	-- defaults
	if not volume then
		volume = 1
	end
	if not isautostop then
		isautostop = 1
	end
	if not ispredicted then
		ispredicted = 1
	end
	return TheFrontEnd:GetSound():PlaySound_Autoname(eventname, volume, isautostop, ispredicted, all_params)
end

function Widget:SetControlDownSound(sound)
	self.controldown_sound = sound
	return self
end

function Widget:SetControlUpSound(sound)
	self.controlup_sound = sound
	return self
end

function Widget:SetHoverSound(sound)
	self.hover_sound = sound
	return self
end

function Widget:SetGainFocusSound(sound)
	self.gainfocus_sound = sound
	return self
end

Widget:add_mixin(TrackEntity)
return Widget
