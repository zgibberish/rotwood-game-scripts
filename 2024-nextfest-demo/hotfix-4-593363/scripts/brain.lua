local BrainWrangler = Class(function(self)
	self.lasttick = 0
	self.updaters = {}
	self.swapupdaters = {}
	self.tickwaiters = {}
	self.waiterspool = SimpleTablePool()
end)

BrainManager = BrainWrangler()

function BrainWrangler:SendToList(braininst, list)
	dbassert(not braininst.retired)
	if braininst.activelist ~= list and not braininst.retired then
		if braininst.activelist ~= nil then
			braininst.activelist[braininst] = nil
		end
		braininst.activelist = list
		if list ~= nil then
			list[braininst] = true
		end
	end
end

function BrainWrangler:OnForceUpdate(braininst)
	self:SendToList(braininst, self.updaters)
end

function BrainWrangler:AddInstance(braininst)
	self:SendToList(braininst, self.updaters)
end

function BrainWrangler:RemoveInstance(braininst)
	self:SendToList(braininst, nil)
end

function BrainWrangler:Sleep(braininst, targettick)
	local waiters = self.tickwaiters[targettick]
	if waiters == nil then
		waiters = self.waiterspool:Get()
		self.tickwaiters[targettick] = waiters
	end
	self:SendToList(braininst, waiters)
end

function BrainWrangler:Update(currenttick)
	dbassert(currenttick == self.lasttick + 1)

	local waiters = self.tickwaiters[currenttick]
	if waiters ~= nil then
		for k in pairs(waiters) do
			k.activelist = self.updaters
			self.updaters[k] = true
			waiters[k] = nil
		end
		self.tickwaiters[currenttick] = nil
		self.waiterspool:Recycle(waiters)
	end

	TheSim:ProfilerPush("updaters")
	local braininst = next(self.updaters)
	while braininst ~= nil do
		TheSim:ProfilerPush(braininst.inst.prefab or "entity")
		local sleepticks = braininst:Update()
		TheSim:ProfilerPop()
		if braininst.activelist ~= nil then
			if sleepticks == nil then
				self:SendToList(braininst, nil)
			elseif sleepticks > 1 then
				self:Sleep(braininst, currenttick + sleepticks)
			else
				self:SendToList(braininst, self.swapupdaters)
			end
		end
		braininst = next(self.updaters)
	end
	TheSim:ProfilerPop()

	self.lasttick = currenttick

	local temp = self.updaters
	self.updaters = self.swapupdaters
	self.swapupdaters = temp
end

Brain = Class(BT, function(self, inst, root)
	BT._ctor(self, root)
	self.inst = inst
	self.forceupdate = false
	--self.events = nil --can leave this as nil
end)

function Brain:GetDebugString()
	return string.format("sleep ticks: %d\n%s", self:GetSleepTicks(), Brain._base.GetDebugString(self))
end

Brain.DebugNodeName = "DebugBrain"

--NOTE: these events won't be triggered when the brain instance is hibernating.
function Brain:AddEventHandler(event, fn)
	if self.events == nil then
		self.events = { [event] = { fn } }
	else
		local handlers = self.events[event]
		if handlers == nil then
			self.events[event] = { fn }
		else
			handlers[#handlers + 1] = fn
		end
	end
end

function Brain:GetSleepTicks()
	return self.forceupdate and 0 or Brain._base.GetSleepTicks(self)
end

function Brain:ForceUpdate()
	dbassert(self.inst.brain ~= nil and self.inst.brain.brain == self)
	--Forward this call to the BrainInstance
	self.inst.brain:ForceUpdate()
end

function Brain:Update()
	Brain._base.Update(self)
	self.forceupdate = false
end

BrainInstance = Class(function(self, inst, brainclass)
	self.inst = inst
	self.brainclass = brainclass
	self.brain = nil
	--self.retired = false --can leave this as nil
	self.paused = {}
	self.activelist = nil --used by BrainWrangler
end)

function BrainInstance:GetDebugString()
	return self.brain and self.brain:GetDebugString() or "<no brain>"
end

BrainInstance.DebugNodeName = "DebugBrain"

function BrainInstance:PushEvent(event, data)
	dbassert(not self.retired)
	local handlers = self.brain ~= nil and self.brain.events ~= nil and self.brain.events[event] or nil
	if handlers ~= nil then
		for i = 1, #handlers do
			handlers[i](self.inst, data)
			if self.retired then
				return
			end
		end
	end
end

function BrainInstance:OnRemoveFromEntity()
	BrainManager:RemoveInstance(self)
	self.retired = true
end

BrainInstance.OnRemoveEntity = BrainInstance.OnRemoveFromEntity

function BrainInstance:Start()
	if next(self.paused) == nil and self.brain == nil then
		self.brain = self.brainclass(self.inst)
		BrainManager:AddInstance(self)
	end
end

function BrainInstance:Pause(reason)
	if reason == nil then
		print(self.inst, "Brain paused without [reason].")
	end
	self.paused[reason or ""] = true
	if self.brain ~= nil then
		BrainManager:RemoveInstance(self)
		self.brain = nil
	end
end

function BrainInstance:IsPausedFor(reason)
	if not reason or self.brain then
		return false
	end
	return self.paused[reason] ~= nil
end

function BrainInstance:Resume(reason)
	if reason == nil then
		print(self.inst, "Brain paused without [reason].")
	end
	if self.brain == nil and self.paused[reason or ""] then
		self.paused[reason or ""] = nil
		if next(self.paused) == nil then
			self.brain = self.brainclass(self.inst)
			BrainManager:AddInstance(self)
		end
	end
end

function BrainInstance:ForceUpdate()
	if self.brain ~= nil and not self.brain.forceupdate then
		self.brain.forceupdate = true
		BrainManager:OnForceUpdate(self)
	end
end

function BrainInstance:Update()
	self.brain:Update()

	if self.activelist == nil then
		return
	end
	return self.brain:GetSleepTicks()
end
