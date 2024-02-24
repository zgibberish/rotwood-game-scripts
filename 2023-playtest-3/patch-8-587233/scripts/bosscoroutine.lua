-- not intended to act as a brain for the boss,
-- meant to control the state of the fight & progress through stages.
BossCoroutine = Class(function(self, inst)
	self.inst = inst
	self.thread = nil
	self.paused = {}
	self.phase = 1
	self.music_variation = 1
	self.phasechanged = nil

	self._on_spawncoordinator_ready = function(source) self:SpawnSetDressing() end
	self.inst:ListenForEvent("spawncoordinator_ready", self._on_spawncoordinator_ready, TheWorld)
	self.inst:ListenForEvent("dying", function() self.phasechanged = nil end) -- If we're dead, disable phasechanged so that we aren't running any coroutines after dying.
end)

-- Check for boss phase transitions via healh change.
function BossCoroutine:CheckHealthPhaseTransition(phase_thresholds)
	self.inst:ListenForEvent("healthchanged", function(_, data)
		if not data or not data.old or not data.new or not data.max or not phase_thresholds then
			return
		end

		local oldpercent = data.old / data.max
		local newpercent = data.new / data.max
		for i, percent in ipairs(phase_thresholds) do
			if oldpercent >= percent and newpercent < percent then
				self.inst:PushEvent("boss_phase_changed", i + 1)
				self.inst.boss_coro:SetPhase(i + 1)
				break
			end
		end
	end)
end

function BossCoroutine:SetPhase(phase)
	-- Phase changed, set flag indicating the phase changed.
	if self.phase ~= phase then
		self.phasechanged = true
	end
	self.phase = phase

end

function BossCoroutine:CurrentPhase()
	return self.phase
end

function BossCoroutine:SpawnSetDressing()
	-- We'll eventually die and be removed, but we're not a component so no
	-- easy cleanup. Remove handler immediately instead.
	self.inst:RemoveEventCallback("spawncoordinator_ready", self._on_spawncoordinator_ready, TheWorld)
end

function BossCoroutine:IsStopped()
	return next(self.paused)
end
function BossCoroutine:Stop(reason)
	assert(reason, "BossCoroutine stopped without [reason].")
	self.paused[reason] = true
	if self.thread then
		self.inst.components.cororun:StopCoroutine(self.thread)
		self.thread = nil
	end
end

function BossCoroutine:Resume(reason)
	assert(reason, "BossCoroutine paused without [reason].")
	if self.paused[reason] then
		self.paused[reason] = nil
		if not self:IsStopped() then
			self:Start()
		end
	end
end

function BossCoroutine:SendEvent(event, data)
	if not self.phasechanged then
		self.inst:PushEvent(event, data)
	end
end

function BossCoroutine:SetConditionalFunction(fn)
	self.conditional_fn = fn
end

function BossCoroutine:DoConditionalFunction(fn, ...)
	assert(self.thread:IsRunning())
	assert(self.conditional_fn ~= nil)

	if self.conditional_fn(self, self.inst) then
		fn(self, ...)
	end
end

function BossCoroutine:HealthAbovePercent(percent)
	return self.inst.components.health:GetPercent() >= percent
end

function BossCoroutine:HealthBelowPercent(percent)
	return self.inst.components.health:GetPercent() < percent
end

function BossCoroutine:WaitForSeconds(duration, respect_conditional_fn)
	assert(duration)
	assert(self.thread:IsRunning())

	while duration > 0 and (not self.conditional_fn or not respect_conditional_fn or (respect_conditional_fn and self.conditional_fn ~= nil and self.conditional_fn(self, self.inst))) do
		-- Coroutines run via cororun get delta time passed into their resume,
		-- so we can implement this here but can't inside coro.
		local dt = coroutine.yield()
		duration = duration - dt
	end
end

function BossCoroutine:WaitForNotBusy()
	assert(self.thread:IsRunning())
	while self.inst.sg:HasStateTag("busy") do
		if self.phasechanged then break end
		coroutine.yield()
	end
end

function BossCoroutine:WaitForEvent(event)
	assert(self.thread:IsRunning())
	local wait_for_event = true
	local event_fn = function() wait_for_event = false end
	self.inst:ListenForEvent(event, event_fn)
	while wait_for_event do
		if self.phasechanged then break end
		coroutine.yield()
	end
	self.inst:RemoveEventCallback(event, event_fn)
end

function BossCoroutine:WaitForHealthPercent(percent)
	assert(self.thread:IsRunning())
	while self.inst.components.health:GetPercent() > percent do
		if self.phasechanged then break end
		coroutine.yield()
	end
end

function BossCoroutine:DoUntilHealthPercent(percent, fn)
	assert(self.thread:IsRunning())
	while not self:HealthBelowPercent(percent) do
		if self.phasechanged then break end
		fn(self)
		coroutine.yield()
	end

	self.phasechanged = nil
end

function BossCoroutine:WaitForDefeatedPercentage(percentage)
	assert(self.thread:IsRunning())
	local current = TheWorld.components.roomclear:GetEnemyCount() - 1 -- ignore the boss
	local desired = math.floor(current * (1 - percentage))
	while TheWorld.components.roomclear:GetEnemyCount() - 1 > desired do
		if self.phasechanged then break end
		coroutine.yield()
	end
end

function BossCoroutine:DoIfAddsRemainingCount(count, conditional_fn)
	assert(self.thread:IsRunning())
	local current = TheWorld.components.roomclear:GetEnemyCount() - 1 -- The boss counts as one.
	if current <= count then
		conditional_fn()
	end
end

function BossCoroutine:WaitForDefeatedCount(count)
	assert(self.thread:IsRunning())
	local current = TheWorld.components.roomclear:GetEnemyCount() - 1 -- ignore boss
	local desired = current - count
	while TheWorld.components.roomclear:GetEnemyCount() - 1 > desired do
		if self.phasechanged then break end
		coroutine.yield()
	end
end

function BossCoroutine:WaitForAddsRemainingCount(count)
	assert(self.thread:IsRunning())
	while TheWorld.components.roomclear:GetEnemyCount() - 1 > count do -- ignore boss
		if self.phasechanged then break end
		coroutine.yield()
	end
end

function BossCoroutine:WaitToBeOnlyEnemy()
	assert(self.thread:IsRunning())
	while TheWorld.components.roomclear:GetEnemyCount() > 1 do
		if self.phasechanged then break end
		coroutine.yield()
	end
end

function BossCoroutine:WaitForRoomClear()
	assert(self.thread:IsRunning())
	while not TheWorld.components.roomclear:IsClearOfEnemies() do
		if self.phasechanged then break end
		coroutine.yield()
	end
end

function BossCoroutine:WaitForEnemyCount(count)
	assert(self.thread:IsRunning())
	while TheWorld.components.roomclear:GetEnemyCount() > count do
		if self.phasechanged then break end
		coroutine.yield()
	end
end

function BossCoroutine:Start()
	if self:IsStopped() then
		return
	end
	if self.thread then return end

	for _,player in ipairs(AllPlayers) do
		player.components.unlocktracker:UnlockEnemy(self.inst.prefab)
	end

	self.thread = self.inst.components.cororun:StartCoroutine(BossCoroutine._main_coro, self)
end

function BossCoroutine:_main_coro()
	coroutine.yield()
	self:Main()
end

function BossCoroutine:Main()
	print("BossCoroutine:Main()")
end
