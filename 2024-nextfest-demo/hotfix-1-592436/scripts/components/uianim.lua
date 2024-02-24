local easing = require "util.easing"
local kassert = require "util.kassert"
require "util.bezier"

local UIAnim = Class(function(self, inst)
	self.inst = inst
end)

local function ProcessCancel(t, run_complete_fn)
	if run_complete_fn
		and t
		and t.fn
	then
		t.fn()
	end
end

function UIAnim:TintTo(start, dest, duration, ease, whendone)
	if not self.inst.widget.SetMultColor then
		return
	end

	local r1,g1,b1,a1 = start[1], start[2], start[3], start[4]

	self.colour = {
		start_colour = {
			r1 or self.tint_r or 1,
			g1 or self.tint_g or 1,
			b1 or self.tint_b or 1,
			a1 or self.tint_a or 1,
		},
		end_colour = dest,
		total_t = duration,
		t = 0,
		ease = ease or easing.linear,
		fn = whendone
	}

	self.inst:StartWallUpdatingComponent(self)
	self.inst.widget:SetMultColor(r1,g1,b1,a1)
end

function UIAnim:ColorAddTo(start, dest, duration, ease, whendone)
	if not self.inst.widget.SetAddColor then
		return
	end

	local r1,g1,b1,a1 = start[1], start[2], start[3], start[4]

	self.add_colour = {
		start_colour = {
			r1 or self.add_r or 0,
			g1 or self.add_g or 0,
			b1 or self.add_b or 0,
			a1 or self.add_a or 0,
		},
		end_colour = dest,
		total_t = duration,
		t = 0,
		ease = ease or easing.linear,
		fn = whendone
	}

	self.inst:StartWallUpdatingComponent(self)
	self.inst.widget:SetAddColor(r1,g1,b1,a1)
end

-- Just for text widgets
function UIAnim:ColorTo(start, dest, duration, ease, whendone)
	if not self.inst.widget.SetGlyphColor then
		return
	end

	local r1,g1,b1,a1 = start[1], start[2], start[3], start[4]

	self.text_colour = {
		start_colour = {
			r1 or self.tint_r or 1,
			g1 or self.tint_g or 1,
			b1 or self.tint_b or 1,
			a1 or self.tint_a or 1,
		},
		end_colour = dest,
		total_t = duration,
		t = 0,
		ease = ease or easing.linear,
		fn = whendone
	}

	self.inst:StartWallUpdatingComponent(self)
	self.inst.widget:SetGlyphColor(r1,g1,b1,a1)
end

function UIAnim:FinishCurrentScale()
	if not self.inst or not self.inst:IsValid() then
		-- sometimes the ent becomes invalid during a "finished" callback, but this gets run anyways.
		return
	end

	local s = self.scale.end_scale
	self.inst.widget:SetScale(s,s, true)
	if self.scale.fn then
		local func = self.scale.fn
		-- prevent infinite recursion if this callback is self-referential
		self.scale.fn = nil
		func(self)
	end
	self.scale = nil
end

function UIAnim:ScaleTo(start_scale, end_scale, duration, ease, whendone)
	if self.scale then
		self:FinishCurrentScale()
	end

	self.scale = {
		start_scale = start_scale or self:GetScale(),
		end_scale = end_scale,
		total_t = duration,
		t = 0,
		ease = ease or easing.linear,
		fn = whendone
	}

	self.inst:StartWallUpdatingComponent(self)
	self.inst.widget:SetScale(start_scale, nil, true)
	return self
end

function UIAnim:CancelMoveTo(run_complete_fn)
	ProcessCancel(self.move, run_complete_fn)
	self.move = nil
end

--    self.inst.components.uianim:MoveTo(self.x, self.y, x, y, nil, nil, time, easefn, fn)
function UIAnim:MoveTo(sx, sy, dx, dy, cx, cy, duration, ease, whendone)
	kassert.typeof("number", sx, sy, dx, dy, duration) -- cx, cy are optional
	ProcessCancel(self.move, true)

	self.move = {
		sx = sx,
		sy = sy,
		dx = dx,
		dy = dy,
		cx = cx,
		cy = cy,
		total_t = duration,
		t = 0,
		ease = ease or easing.linear,
		fn = whendone
	}

	self.inst:StartWallUpdatingComponent(self)
	self.inst.widget:SetPosition(sx,sy)
	return self
end

function UIAnim:CancelRotateTo( run_complete_fn )
	ProcessCancel(self.rotation, run_complete_fn)
	self.rotation = nil
end

function UIAnim:RotateTo(start, dest, duration, ease, whendone )
	ProcessCancel(self.rotation, true)

	self.rotation = {
		start_rotation = start,
		end_rotation = dest,
		total_t = duration,
		t = 0,
		ease = ease or easing.linear,
		fn = whendone,
	}

	self.inst:StartWallUpdatingComponent(self)
	self.inst.widget:SetRotation(start)
	return self
end

function UIAnim:RotateIndefinitely(speed)
	self.spin = {
		rotation = self.inst.widget.r,
		speed = speed
	}
	self.inst:StartWallUpdatingComponent(self)
	return self
end

function UIAnim:StopSpin()
	self.spin = nil
	return self
end

function UIAnim:PulseAlpha( from, to, speed )
	local low, high = from, to
	if high < low then
		low, high = high, low
	end
	self.pulse = {
		alpha = from,
		high = high,
		low = low,
		increasing = from < to,
		speed = speed
	}
	self.inst:StartWallUpdatingComponent(self)
	return self
end


function UIAnim:PulseRGBA( r1,g1,b1,a1, r2,g2,b2,a2, duration, ease )
	local _self = self.inst.widget
	self.pulse_colour = {
		start_colour = {r1 or _self.tint_r,g1 or _self.tint_g, b1 or _self.tint_b, a1 or _self.tint_a },
		end_colour = {r2,g2,b2,a2},
		increasing = true,
		t = 0,
		ease = ease or easing.linear,
		duration = duration or 1
	}
	self.inst:StartWallUpdatingComponent(self)
	return self
end

function UIAnim:ScissorTo(start_scissor, end_scissor, time, ease, fn)
	self.scissor = {
		start_scissor = {
			x=start_scissor[1],
			y=start_scissor[2],
			w=start_scissor[3],
			h=start_scissor[4],
		},
		end_scissor = {
			x=end_scissor[1],
			y=end_scissor[2],
			w=end_scissor[3],
			h=end_scissor[4],
		},
		total_t = time,
		t = 0,
		ease = ease or easing.linear,
		fn = fn
	}
	self.inst:StartWallUpdatingComponent(self)
	self.inst.widget:SetScissor(start_scissor[1],start_scissor[2],start_scissor[3],start_scissor[4])
	return self
end

function UIAnim:SizeTo(start_w, end_w, start_h, end_h, t, ease, fn)
	local w,h = self.inst.widget:GetSize()
	if start_w == nil then
		start_w = w
	end
	if end_w == nil then
		end_w = w
	end
	if start_h == nil then
		start_h = h
	end
	if end_h == nil then
		end_h = h
	end
	self.size = {
		start_w = start_w,
		end_w = end_w,
		start_h = start_h,
		end_h = end_h,
		total_t = t,
		t = 0,
		ease = ease or easing.linear,
		fn = fn
	}
	self.inst:StartWallUpdatingComponent(self)
	self.inst.widget:SetSize(start_w,start_h)
	return self
end

function UIAnim:EaseTo(on_change_fn, start_v, end_v, t, ease, on_done_fn)
	self.ease = {
		on_change_fn = on_change_fn,
		start_v = start_v,
		end_v = end_v,
		total_t = t,
		t = 0,
		ease = ease or easing.linear,
		on_done_fn = on_done_fn
	}
	self.inst:StartWallUpdatingComponent(self)
	on_change_fn(start_v)
	return self
end

function UIAnim:Ease2dTo(on_change_fn, start_v, end_v, start_w, end_w, t, ease, on_done_fn)
	self.ease2d = {
		on_change_fn = on_change_fn,
		start_v = start_v,
		end_v = end_v,
		start_w = start_w,
		end_w = end_w,
		total_t = t,
		t = 0,
		ease = ease or easing.linear,
		on_done_fn = on_done_fn
	}
	self.inst:StartWallUpdatingComponent(self)
	on_change_fn(start_v, start_w)
	return self
end

function UIAnim:StopPulse()
	self.pulse = nil
	self.pulse_colour = nil
	return self
end

function UIAnim:Blink( period_t, max_count, blink_fn, fn )
	self.blink = {
		on = true,
		t = 0,
		period_t = period_t,
		count = 0,
		max_count = max_count,
		blink_fn = blink_fn or self.inst.widget.SetShown,
		fn = fn
	}
	self.inst:StartWallUpdatingComponent(self)
	return self
end

function UIAnim:StopAll()
	self:CancelMoveTo()
	self:CancelRotateTo()
	self:StopPulse()
	self:StopSpin()
	self.blink = nil
	self.colour = nil
	self.add_colour = nil
	self.text_colour = nil
	self.scale = nil
	self.scissor = nil
	self.size = nil
	self.ease = nil
	self.ease2d = nil
	dbassert(not self:ShouldBeUpdating())
end

--    return self.colour or    - done
--        self.move or         - done
--        self.scale or        - done
--        self.rotation or     - done
--        self.spin or         - done
--        self.size or
--        self.scissor or      - done
--        self.pulse or		- done
--        self.pulse_colour or - done
--        self.uv_speed_set or
--        self.blink or
function UIAnim:ShouldBeUpdating()
	return self.colour or
	self.add_colour or
	self.text_colour or
	self.move or
	self.scale or
	self.rotation or
	self.spin or
	self.scissor or
	self.pulse or
	self.pulse_colour or
	self.blink or
	self.size or
	self.ease or
	self.ease2d
end

function UIAnim:OnWallUpdate(dt)
	if not self.inst:IsValid() then
		self.inst:StopWallUpdatingComponent(self)
		return
	end
	kassert.assert_fmt(self.inst.widget, "Lost our widget, but entity is still valid: '%s'", self.inst)

	if self.scale then
		self.scale.t = self.scale.t + dt

		if self.scale.t > self.scale.total_t then
			local s = self.scale.end_scale
			self.inst.widget:SetScale(s,s, true)
			local fn = self.scale.fn
			self.scale = nil
			if fn then
				fn()
			end
		else
			local s = self.scale.ease(self.scale.t, self.scale.start_scale, self.scale.end_scale - self.scale.start_scale, self.scale.total_t)
			self.inst.widget:SetScale(s,s, true)
		end
	end

	if self.move then

		self.move.t = self.move.t + dt

		if self.move.t > self.move.total_t then
			self.inst.widget:SetPosition(self.move.dx,self.move.dy)
			local fn = self.move.fn
			self.move = nil
			if fn then
				fn()
			end
		else
			local x,y
			if self.move.cx and self.move.cy then
				-- curve to target
				local factor = self.move.ease(self.move.t, 0.0, 1.0, self.move.total_t)

				-- bezier path: (not a constant speed bezier, so easying may be a bit weird!
				x, y = BezierEvaluate(factor, self.move.sx, self.move.sy, self.move.cx, self.move.cy, self.move.dx, self.move.dy);
			else
				x = self.move.ease(self.move.t, self.move.sx, self.move.dx - self.move.sx, self.move.total_t)
				y = self.move.ease(self.move.t, self.move.sy, self.move.dy - self.move.sy, self.move.total_t)
			end
			self.inst.widget:SetPosition(x,y)
		end

	end

	if self.colour then

		self.colour.t = self.colour.t + dt

		if self.colour.t > self.colour.total_t then
			self.inst.widget:SetMultColor(table.unpack(self.colour.end_colour))
			local fn = self.colour.fn
			self.colour = nil
			if fn then
				fn()
			end
		else
			local r = self.colour.ease(self.colour.t, self.colour.start_colour[1], self.colour.end_colour[1] - self.colour.start_colour[1], self.colour.total_t)
			local g = self.colour.ease(self.colour.t, self.colour.start_colour[2], self.colour.end_colour[2] - self.colour.start_colour[2], self.colour.total_t)
			local b = self.colour.ease(self.colour.t, self.colour.start_colour[3], self.colour.end_colour[3] - self.colour.start_colour[3], self.colour.total_t)
			local a = self.colour.ease(self.colour.t, self.colour.start_colour[4], self.colour.end_colour[4] - self.colour.start_colour[4], self.colour.total_t)

			self.inst.widget:SetMultColor(r,g,b,a)
		end

	end

	if self.add_colour then

		self.add_colour.t = self.add_colour.t + dt

		if self.add_colour.t > self.add_colour.total_t then
			self.inst.widget:SetAddColor(table.unpack(self.add_colour.end_colour))
			local fn = self.add_colour.fn
			self.add_colour = nil
			if fn then
				fn()
			end
		else
			local r = self.add_colour.ease(self.add_colour.t, self.add_colour.start_colour[1], self.add_colour.end_colour[1] - self.add_colour.start_colour[1], self.add_colour.total_t)
			local g = self.add_colour.ease(self.add_colour.t, self.add_colour.start_colour[2], self.add_colour.end_colour[2] - self.add_colour.start_colour[2], self.add_colour.total_t)
			local b = self.add_colour.ease(self.add_colour.t, self.add_colour.start_colour[3], self.add_colour.end_colour[3] - self.add_colour.start_colour[3], self.add_colour.total_t)
			local a = self.add_colour.ease(self.add_colour.t, self.add_colour.start_colour[4], self.add_colour.end_colour[4] - self.add_colour.start_colour[4], self.add_colour.total_t)

			self.inst.widget:SetAddColor(r,g,b,a)
		end

	end

	if self.text_colour then

		self.text_colour.t = self.text_colour.t + dt

		if self.text_colour.t > self.text_colour.total_t then
			self.inst.widget:SetGlyphColor(table.unpack(self.text_colour.end_colour))
			local fn = self.text_colour.fn
			self.text_colour = nil
			if fn then
				fn()
			end
		else
			local r = self.text_colour.ease(self.text_colour.t, self.text_colour.start_colour[1], self.text_colour.end_colour[1] - self.text_colour.start_colour[1], self.text_colour.total_t)
			local g = self.text_colour.ease(self.text_colour.t, self.text_colour.start_colour[2], self.text_colour.end_colour[2] - self.text_colour.start_colour[2], self.text_colour.total_t)
			local b = self.text_colour.ease(self.text_colour.t, self.text_colour.start_colour[3], self.text_colour.end_colour[3] - self.text_colour.start_colour[3], self.text_colour.total_t)
			local a = self.text_colour.ease(self.text_colour.t, self.text_colour.start_colour[4], self.text_colour.end_colour[4] - self.text_colour.start_colour[4], self.text_colour.total_t)

			self.inst.widget:SetGlyphColor(r,g,b,a)
		end

	end

	if self.rotation then
		self.rotation.t = self.rotation.t + dt

		if self.rotation.t > self.rotation.total_t then
			self.inst.widget:SetRotation(self.rotation.end_rotation, self.rotation.start_rotation, true)
			local fn = self.rotation.fn
			self.rotation = nil
			if fn then
				fn()
			end
		else
			local rot = self.rotation.ease(self.rotation.t, self.rotation.start_rotation, self.rotation.end_rotation - self.rotation.start_rotation, self.rotation.total_t)
			self.inst.widget:SetRotation(rot)
		end
	end

	if self.spin then
		self.spin.rotation = self.spin.rotation + self.spin.speed
		self.inst.widget:SetRotation( self.spin.rotation )
	end

	if self.size then
		self.size.t = self.size.t + dt

		if self.size.t > self.size.total_t then
			self.inst.widget:SetSize(self.size.end_w,self.size.end_h)
			local fn = self.size.fn
			self.size = nil
			if fn then
				fn()
			end
		else
			local w = self.size.ease(self.size.t, self.size.start_w, self.size.end_w - self.size.start_w, self.size.total_t)
			local h = self.size.ease(self.size.t, self.size.start_h, self.size.end_h - self.size.start_h, self.size.total_t)
			self.inst.widget:SetSize(w,h)
		end
	end

	if self.scissor then
		self.scissor.t = self.scissor.t + dt

		if self.scissor.t > self.scissor.total_t then
			self.inst.widget:SetScissor( self.scissor.end_scissor.x, self.scissor.end_scissor.y, self.scissor.end_scissor.w, self.scissor.end_scissor.h )
			local fn = self.scissor.fn
			self.scissor = nil
			if fn then
				fn()
			end
		else
			local x = self.scissor.ease(self.scissor.t, self.scissor.start_scissor.x, self.scissor.end_scissor.x - self.scissor.start_scissor.x, self.scissor.total_t)
			local y = self.scissor.ease(self.scissor.t, self.scissor.start_scissor.y, self.scissor.end_scissor.y - self.scissor.start_scissor.y, self.scissor.total_t)
			local w = self.scissor.ease(self.scissor.t, self.scissor.start_scissor.w, self.scissor.end_scissor.w - self.scissor.start_scissor.w, self.scissor.total_t)
			local h = self.scissor.ease(self.scissor.t, self.scissor.start_scissor.h, self.scissor.end_scissor.h - self.scissor.start_scissor.h, self.scissor.total_t)
			self.inst.widget:SetScissor( x, y, w, h )
		end
	end

	if self.pulse then
		if self.pulse.increasing     and self.pulse.alpha >= self.pulse.high then
			self.pulse.increasing = false
		end
		if not self.pulse.increasing and self.pulse.alpha <= self.pulse.low then
			self.pulse.increasing = true
		end
		if self.pulse.increasing then
			self.pulse.alpha = self.pulse.alpha + self.pulse.speed*3    -- wut?
		else
			self.pulse.alpha = self.pulse.alpha - self.pulse.speed
		end
		--print( "alpha", self.pulse.increasing and "increasing" or "decreasing", " at", self.pulse.alpha )
		self.inst.widget:SetMultColorAlpha( self.pulse.alpha )
	end


	if self.pulse_colour then
		if self.pulse_colour.increasing and self.pulse_colour.t >= self.pulse_colour.duration then
			self.pulse_colour.increasing = false
		end
		if not self.pulse_colour.increasing and self.pulse_colour.t <= 0 then
			self.pulse_colour.increasing = true
		end
		if self.pulse_colour.increasing then
			self.pulse_colour.t = self.pulse_colour.t + 3*dt
		else
			self.pulse_colour.t = self.pulse_colour.t - dt
		end
		local r = self.pulse_colour.ease(self.pulse_colour.t, self.pulse_colour.start_colour[1], self.pulse_colour.end_colour[1] - self.pulse_colour.start_colour[1], self.pulse_colour.duration)
		local g = self.pulse_colour.ease(self.pulse_colour.t, self.pulse_colour.start_colour[2], self.pulse_colour.end_colour[2] - self.pulse_colour.start_colour[2], self.pulse_colour.duration)
		local b = self.pulse_colour.ease(self.pulse_colour.t, self.pulse_colour.start_colour[3], self.pulse_colour.end_colour[3] - self.pulse_colour.start_colour[3], self.pulse_colour.duration)
		local a = self.pulse_colour.ease(self.pulse_colour.t, self.pulse_colour.start_colour[4], self.pulse_colour.end_colour[4] - self.pulse_colour.start_colour[4], self.pulse_colour.duration)
		self.inst.widget:SetMultColor(r,g,b,a)
	end

	if self.blink then
		self.blink.t = self.blink.t + dt
		if self.blink.t > self.blink.period_t then
			self.blink.on = not self.blink.on
			self.blink.blink_fn( self.inst.widget, self.blink.on )
			self.blink.t = self.blink.t - self.blink.period_t
			if self.blink.on then
				self.blink.count = self.blink.count + 1
				if self.blink.max_count and self.blink.count >= self.blink.max_count then
					local fn = self.blink.fn
					self.blink.blink_fn( self.inst.widget, true )
					self.blink = nil
					if fn then
						fn()
					end
				end
			end
		end
	end

	if self.ease then
		self.ease.t = self.ease.t + dt

		if self.ease.t > self.ease.total_t then
			self.ease.on_change_fn(self.ease.end_v)
			local fn = self.ease.on_done_fn
			self.ease = nil
			if fn then
				fn()
			end
		else
			local v = self.ease.ease(self.ease.t, self.ease.start_v, self.ease.end_v - self.ease.start_v, self.ease.total_t)
			self.ease.on_change_fn(v)
		end
	end

	if self.ease2d then
		self.ease2d.t = self.ease2d.t + dt

		if self.ease2d.t > self.ease2d.total_t then
			self.ease2d.on_change_fn(self.ease2d.end_v, self.ease2d.end_w)
			local fn = self.ease2d.on_done_fn
			self.ease2d = nil
			if fn then
				fn()
			end
		else
			local v = self.ease2d.ease(self.ease2d.t, self.ease2d.start_v, self.ease2d.end_v - self.ease2d.start_v, self.ease2d.total_t)
			local w = self.ease2d.ease(self.ease2d.t, self.ease2d.start_w, self.ease2d.end_w - self.ease2d.start_w, self.ease2d.total_t)
			self.ease2d.on_change_fn(v, w)
		end
	end

	if not self:ShouldBeUpdating() then
		self.inst:StopWallUpdatingComponent(self)
	end
end


return UIAnim

