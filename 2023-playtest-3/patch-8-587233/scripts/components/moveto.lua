require "class"
require "mathutil"


local function noop() end

-- Translate toward a destination object.
local MoveTo = Class(function(self, inst)
	self.inst = inst
	self.onupdate_fn = noop
	self.oncomplete_fn = noop
end)

function MoveTo:SetTarget(ent)
	self.target = ent
	return self
end

function MoveTo:SetOnUpdate(onupdate_fn)
	self.onupdate_fn = onupdate_fn or noop
	return self
end

function MoveTo:SetOnComplete(oncomplete_fn)
	self.oncomplete_fn = oncomplete_fn or noop
	return self
end

function MoveTo:StartMove(duration_ticks, curve)
	if self.move_task then
		self.move_task:Cancel()
		self.move_task = nil
	end

	self.duration_ticks = duration_ticks

	local start_pos = self.inst:GetPosition()
	local fn = function(inst_, progress)
		local t = curve and EvaluateCurve(curve, progress) or progress
		local dest = self.target:GetPosition()
		local pos = Vector3.lerp(start_pos, dest, t)
		self.inst.Transform:SetPosition(pos:unpack())
		self.onupdate_fn(self.inst, t)
		if progress >= 1 then
			self.oncomplete_fn(self.inst)
		end
	end

	self.move_task = self.inst:DoDurationTaskForTicks(duration_ticks, fn)

	return self
end

return MoveTo
