local coroutine = coroutine

local Task = Class(function(self, ...)
	self.args = toarrayornil(...)
	--self.retired = false --can leave this as nil
	self.activelist = nil
	self.targettick = nil

	--Only used by EntityScript
	--self.inst = nil --can leave this as nil
end)

function Task:GetTicksRemaining()
	local t = (self.targettick or math.huge) - GetTick()
	-- networking2022, victorc - figure out why net serialization of timers calls this when targettick has expired
	if t < 0 then
		TheLog.ch.Task:printf("Task:GetTicksRemaining() prevented from returning negative value: %d", t)
	end
	return math.max(0, t)
end

function Task:Cancel()
	if not self.retired then
		Scheduler:RemoveTask(self)
		self.retired = true
		if self.inst ~= nil then
			self.inst:OnCancelTask(self)
		end
	end
end

function Task:IsDone()
	return self.retired or self:GetTicksRemaining() == 0
end

local Periodic = Class(Task, function(self, fn, period, limit, ...)
	Task._ctor(self, ...)
	self.fn = fn
	self.period = period
	self.limit = limit
end)

function Periodic:__tostring()
	return string.format("PERIODIC: %d ticks", self.period)
end

local Thread = Class(Task, function(self, fn, ...)
	Task._ctor(self, ...)
	self.started = false
	self.co = coroutine.create(fn)
end)

local TaskScheduler = Class( function(self)
	self.lasttick = 0
	self.numtasks = 0
	self.numthreads = 0
	self.tickwaiters = {}
	self.waiterspool = SimpleTablePool()
end)

Scheduler = TaskScheduler()

function TaskScheduler:__tostring()
	return string.format("Running Tasks: %d, Threads: %d", self.numtasks, self.numthreads)
end

function TaskScheduler:SendToList(task, list)
	dbassert(not task.retired)
	if task.activelist ~= list and not task.retired then
		if task.activelist ~= nil then
			task.activelist[task] = nil
		end
		task.activelist = list
		if list ~= nil then
			list[task] = true
		end
	end
end

function TaskScheduler:RemoveTask(task)
	dbassert(task:is_a(Task))
	task.targettick = nil
	self:SendToList(task, nil)
	if task:is_a(Thread) then
		self.numthreads = self.numthreads - 1
		dbassert(self.numthreads >= 0)
	else
		self.numtasks = self.numtasks - 1
		dbassert(self.numtasks >= 0)
	end
end

function TaskScheduler:Sleep(task, targettick)
	local waiters = self.tickwaiters[targettick]
	if waiters == nil then
		waiters = self.waiterspool:Get()
		self.tickwaiters[targettick] = waiters
	end
	task.targettick = targettick
	self:SendToList(task, waiters)
end

function TaskScheduler:ExecuteInTime(time, fn, ...)
	return self:ExecutePeriodicTicks(math.ceil(time * SECONDS), fn, 1, nil, ...)
end

function TaskScheduler:ExecuteInTicks(ticks, fn, ...)
	return self:ExecutePeriodicTicks(ticks, fn, 1, nil, ...)
end

function TaskScheduler:ExecutePeriodic(period, fn, limit, initialdelay, ...)
	return self:ExecutePeriodicTicks(math.ceil(period * SECONDS), fn, limit, initialdelay ~= nil and math.ceil(initialdelay * SECONDS) or nil, ...)
end

function TaskScheduler:ExecutePeriodicTicks(period, fn, limit, initialdelay, ...)
	dbassert(fn)
	--Always wait till at least the next sim tick.
	local targettick = GetTick() + math.max(1, initialdelay or period)
	local task = Periodic(fn, math.max(1, period), limit, ...)
	self:Sleep(task, targettick)
	self.numtasks = self.numtasks + 1
	return task
end

function TaskScheduler:StartThread(fn, ...)
	dbassert(fn)
	--Threads can start this sim tick if Scheduler update hasn't passed yet.
	local task = Thread(fn, ...)
	self:Sleep(task, self.lasttick + 1)
	self.numthreads = self.numthreads + 1
	return task
end

function TaskScheduler:WakeThread(task)
	if not task:is_a(Thread) then
		dbassert(false)
		return
	end
	self:Sleep(task, self.lasttick + 1)
end

function TaskScheduler:Update(currenttick)
	dbassert(currenttick == self.lasttick + 1)

	local waiters = self.tickwaiters[currenttick]
	if waiters ~= nil then
		local task = next(waiters)
		while task ~= nil do
			if task.fn ~= nil then
				dbassert(task:is_a(Periodic))
				if task.args == nil then
					task.fn(task.inst)
				elseif task.inst ~= nil then
					task.fn(task.inst, table.unpack(task.args))
				else
					task.fn(table.unpack(task.args))
				end
				if not task.retired then
					if task.limit == nil then
						self:Sleep(task, currenttick + task.period)
					elseif task.limit > 1 then
						task.limit = task.limit - 1
						self:Sleep(task, currenttick + task.period)
					else
						task:Cancel()
					end
				end
			else
				dbassert(task:is_a(Thread))
				local success, sleepticks
				if task.started then
					success, sleepticks = coroutine.resume(task.co)
				else
					task.started = true
					if task.args == nil then
						success, sleepticks = coroutine.resume(task.co, task.inst)
					elseif task.inst ~= nil then
						success, sleepticks = coroutine.resume(task.co, task.inst, table.unpack(task.args))
					else
						success, sleepticks = coroutine.resume(task.co, table.unpack(task.args))
					end
				end
				if not success then
					print("Task failed", debug.traceback(task.co))
					dbassert(false)
					task:Cancel()
				elseif not task.retired then
					if coroutine.status(task.co) == "dead" then
						task:Cancel()
					elseif sleepticks == nil then
						task.targettick = nil
						self:SendToList(task, nil)
					else
						self:Sleep(task, currenttick + math.max(1, sleepticks))
					end
				end
			end
			task = next(waiters)
		end
		self.tickwaiters[currenttick] = nil
		self.waiterspool:Recycle(waiters)
	end

	self.lasttick = currenttick
end

--------------------------------------------------------
--These are to be called from within a thread

function Yield()
	coroutine.yield(0)
end

function Sleep(time)
	coroutine.yield(math.ceil(time * SECONDS))
end

function SleepTicks(ticks)
	coroutine.yield(ticks)
end

function Hibernate()
	coroutine.yield()
end
