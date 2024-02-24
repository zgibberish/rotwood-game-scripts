-- CoroRun is similar to UIUpdater except that CoroRun uses actual lua
-- coroutines whereas UIUpdater has its own sequencing system that makes
-- parallel and easing easier.
--
-- You can use coroutine.yield() to yield and it will return the delta time for
-- the next section of the coroutine.

local Coro = require "util.coro"

-- update_wall (bool) : Uses wall update instead of sim update (i.e. sim pause won't affect coro usage)
local CoroRun = Class(function(self, inst, update_wall)
	self.inst = inst
	self.update_wall = update_wall
end)

function CoroRun:StartCoroutine(fn, ...)
	local coro = Coro(fn, ...)
	self.coros = self.coros or {}
	table.insert( self.coros, coro )
	if self.update_wall then
		self.inst:StartWallUpdatingComponent(self)
	else
		self.inst:StartUpdatingComponent(self)
	end
	return coro
end

function CoroRun:StopCoroutine(coro)
	coro:Stop()
	table.removearrayvalue(self.coros, coro)
end

function CoroRun:WaitForSeconds(coro, duration)
	assert(duration)
	-- To debug IsRunning assert failure:
	--~ if not coro:IsRunning() then
	--~ 	print(debug.traceback(coro.c, "Expected coroutine:"))
	--~ 	print(debug.traceback(coroutine.running(), "Actual coroutine:"))
	--~ 	print("Done")
	--~ end
	assert(coro:IsRunning(), "Must be the active thread to wait.")
	while duration > 0 do
		-- Coroutines run via cororun get delta time passed into their resume,
		-- so we can implement this here but can't inside coro.
		local dt = coroutine.yield()
		duration = duration - dt
	end
end

function CoroRun:_Update(dt)
	if self.coros and #self.coros > 0 then
		local i = 1
		while i <= #self.coros do
			local coro = self.coros[i]
			if not coro:Update(dt) then
				table.remove( self.coros, i )
			else
				i = i + 1
			end
		end
	end
end

function CoroRun:OnUpdate(dt)
	if self.update_wall then
		return
	end

	if not self.inst:IsValid() then
		self.inst:StopUpdatingComponent(self)
		return
	end

	self:_Update(dt)

	if not (self.coros and #self.coros > 0) then
		self.inst:StopUpdatingComponent(self)
	end
end

function CoroRun:OnWallUpdate(dt)
	if not self.update_wall then
		return
	end

	if not self.inst:IsValid() then
		self.inst:StopWallUpdatingComponent(self)
		return
	end

	self:_Update(dt)

	if not (self.coros and #self.coros > 0) then
		self.inst:StopWallUpdatingComponent(self)
	end
end

return CoroRun
