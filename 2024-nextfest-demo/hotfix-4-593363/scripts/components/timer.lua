local Timer = Class(function(self, inst)
	self.inst = inst
	self.timers = {}
end)

function Timer:OnRemoveFromEntity()
	for k, v in pairs(self.timers) do
		if v.task ~= nil then
			v.task:Cancel()
		end
	end
end

function Timer:GetDebugString()
	local str = ""
	for k, v in pairs(self.timers) do
		str = str..string.format(
			"\n    --%s: remaining: %.2f%s",
			k,
			self:GetTimeRemaining(k),
			self:IsPaused(k) and " (paused)" or ""
		)
	end
	return str
end

function Timer:HasTimer(name)
	return self.timers[name] ~= nil
end

local function OnTimerDone(inst, self, name)
	self:StopTimer(name)
	inst:PushEvent("timerdone", { name = name })
end

function Timer:StartTimer(name, time, force)
	self:StartTimerTicks(name, math.ceil(time * SECONDS), force)
end

function Timer:StartTimerAnimFrames(name, animframes, force)
	self:StartTimerTicks(name, animframes * ANIM_FRAMES, force)
end

function Timer:StartTimerTicks(name, ticks, force)
	local timer = self.timers[name]
	if timer == nil then
		timer = {}
		self.timers[name] = timer
	elseif not force then
		print("A timer with the name ", name, " already exists on ", self.inst, "!")
		return
	elseif timer.task ~= nil then
		timer.task:Cancel()
	else
		timer.ticksremaining = nil
	end
	timer.task = self.inst:DoTaskInTicks(ticks, OnTimerDone, self, name)
	timer.initialticks = ticks
end

function Timer:StartPausedTimer(name, time, force)
	self:StartPausedTimerTicks(name, math.ceil(time * SECONDS), force)
end

function Timer:StartPausedTimerTicks(name, ticks, force)
	local timer = self.timers[name]
	if timer == nil then
		timer = {}
		self.timers[name] = timer
	elseif not force then
		print("A timer with the name ", name, " already exists on ", self.inst, "!")
		return
	elseif timer.task ~= nil then
		timer.task:Cancel()
		timer.task = nil
	end
	timer.ticksremaining = ticks
	timer.initialticks = ticks
end

function Timer:StopTimer(name)
	local timer = self.timers[name]
	if timer == nil then
		return
	elseif timer.task ~= nil then
		timer.task:Cancel()
	end
	self.timers[name] = nil
end

function Timer:IsPaused(name)
	local timer = self.timers[name]
	return timer ~= nil and timer.task == nil
end

function Timer:PauseTimer(name)
	local timer = self.timers[name]
	if timer == nil or timer.task == nil then
		return
	end
	timer.ticksremaining = timer.task:GetTicksRemaining()
	timer.task:Cancel()
	timer.task = nil
end

function Timer:ResumeTimer(name)
	local timer = self.timers[name]
	if timer == nil or timer.task ~= nil then
		return
	end
	timer.task = self.inst:DoTaskInTicks(timer.ticksremaining, OnTimerDone, self, name)
	timer.ticksremaining = nil
end

function Timer:GetTicksRemaining(name)
	local timer = self.timers[name]
	if timer == nil then
		return
	end
	return timer.ticksremaining or timer.task:GetTicksRemaining()
end

function Timer:GetTimeRemaining(name)
	local timer = self.timers[name]
	if timer == nil then
		return
	end
	return (timer.ticksremaining or timer.task:GetTicksRemaining()) * TICKS
end

function Timer:GetAnimFramesRemaining(name)
	local timer = self.timers[name]
	if timer == nil then
		return
	end
	return math.ceil((timer.ticksremaining or timer.task:GetTicksRemaining()) / ANIM_FRAMES)
end

function Timer:SetTimeRemaining(name, time)
	self:SetTicksRemaining(name, math.ceil(time * SECONDS))
end

function Timer:SetTicksRemaining(name, ticks)
	local timer = self.timers[name]
	if timer == nil then
		return
	elseif timer.task ~= nil then
		timer.task:Cancel()
		timer.task = self.inst:DoTaskInTicks(ticks, OnTimerDone, self, name)
	else
		timer.ticksremaining = ticks
	end
end

function Timer:GetTicksElapsed(name)
	local timer = self.timers[name]
	if timer == nil then
		return
	end
	return timer.initialticks - (timer.ticksremaining or timer.task:GetTicksRemaining())
end

function Timer:GetTimeElapsed(name)
	local timer = self.timers[name]
	if timer == nil then
		return
	end
	return (timer.initialticks - (timer.ticksremaining or timer.task:GetTicksRemaining())) * TICKS
end

function Timer:GetProgress(name)
	local remaining = self:GetTicksRemaining(name)
	if remaining then
		local elapsed = self:GetTicksElapsed(name)
		return elapsed / (elapsed + remaining)
	end
end

function Timer:OnSave()
	if next(self.timers) == nil then
		return
	end
	local timers = {}
	for k, v in pairs(self.timers) do
		local timer = {}
		if v.task ~= nil then
			timer.ticksremaining = v.task:GetTicksRemaining()
		else
			timer.paused = true
			timer.ticksremaining = v.ticksremaining
		end
		if timer.ticksremaining < v.initialticks then
			timer.initialticks = v.initialticks
		end
		timers[k] = timer
	end
	return { timers = timers }
end

function Timer:OnLoad(data)
	for k, v in pairs(self.timers) do
		if v.task ~= nil then
			v.task:Cancel()
		end
		self.timers[k] = nil
	end
	if data.timers ~= nil then
		local tick = GetTick()
		for k, v in pairs(data.timers) do
			local timer = { initialticks = v.initialticks or v.ticksremaining }
			if v.paused then
				timer.ticksremaining = v.ticksremaining
			else
				timer.task = self.inst:DoTaskInTicks(v.ticksremaining, OnTimerDone, self, k)
			end
			self.timers[k] = timer
		end
	end
end

function Timer:OnEntityBecameLocal()
	for name,timer in pairs(self.timers) do
		if not timer.is_actually_paused then
			self:ResumeTimer(name)
			timer.is_actually_paused = nil
		end
	end
end

function Timer:OnEntityBecameRemote()
	for name,timer in pairs(self.timers) do
		timer.is_actually_paused = self:IsPaused(name)
		self:PauseTimer(name)
	end
end

local TimerCountNrBits = 4
local TimerCountMaxValue = (1 << TimerCountNrBits) - 1
local TimerTicksNrBits = 16
local TimerTicksMaxValue = (1 << TimerTicksNrBits) - 1

function Timer:OnNetSerialize()
	local e = self.inst.entity
	local timer_count = table.numkeys(self.timers)
	assert(timer_count < TimerCountMaxValue)
	e:SerializeUInt(timer_count, TimerCountNrBits)
	for name,timer in pairs(self.timers) do
		e:SerializeString(name) -- TODO: networking2022, add timer names to network string registry at source locations
		e:SerializeBoolean(self:IsPaused(name))
		local ticksremaining = timer.task and timer.task:GetTicksRemaining() or timer.ticksremaining
		e:SerializeUInt(math.clamp(ticksremaining, 0, TimerTicksMaxValue), TimerTicksNrBits)
		e:SerializeUInt(math.clamp(timer.initialticks, 0, TimerTicksMaxValue), TimerTicksNrBits)
	end
end

function Timer:OnNetDeserialize()
	local e = self.inst.entity
	local timer_count = e:DeserializeUInt(TimerCountNrBits)
	local timers_synced = {} -- k:name, v:is_valid

	for _i=1,timer_count do
		local name = e:DeserializeString()
		local paused = e:DeserializeBoolean()
		local ticksremaining = e:DeserializeUInt(TimerTicksNrBits)
		ticksremaining = (ticksremaining < TimerTicksMaxValue) and ticksremaining or math.huge
		local initialticks = e:DeserializeUInt(TimerTicksNrBits)
		initialticks = (initialticks < TimerTicksMaxValue) and initialticks or math.huge

		if not self.timers[name] then
			self:StartPausedTimerTicks(name, initialticks, true)
		else
			self:SetTicksRemaining(name, ticksremaining)
		end
		self.timers[name].is_actually_paused = paused

		timers_synced[name] = true
	end

	for name,_timer in pairs(self.timers) do
		if not timers_synced[name] then
			timers_synced[name] = false
		end
	end

	for name,is_valid in pairs(timers_synced) do
		if not is_valid then
			self:StopTimer(name)
		end
	end
end

return Timer
