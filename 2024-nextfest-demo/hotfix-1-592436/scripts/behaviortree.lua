BNState =
{
	SUCCESS = "SUCCESS",
	FAILED = "FAILED",
	READY = "READY",
	RUNNING = "RUNNING",
}

---------------------------------------------------------------------------------------

BT = Class(function(self, root)
	self.root = root
end)

function BT:Update()
	self.root:Visit()
	self.root:SaveStatus()
	self.root:Step()
end

function BT:Reset()
	self.root:Reset()
end

function BT:GetSleepTicks()
	return self.root:GetTreeSleepTicks()
end

function BT:GetDebugString()
	return self.root:GetTreeString()
end

---------------------------------------------------------------------------------------

local NODE_COUNT = 0

BehaviorNode = Class(function (self, name, children)
	self.name = name or ""
	self.children = children
	self.parent = nil
	self.status = BNState.READY
	self.lastresult = BNState.READY
	self.nextupdatetick = 0

	--jcheng: this is for imgui to have an id to use
	self.id = NODE_COUNT
	NODE_COUNT = NODE_COUNT + 1

	if children ~= nil then
		for i = 1, #children do
			children[i].parent = self
		end
	end
end)

function BehaviorNode:GetTreeString(indent)
	indent = indent or ""
	local str = string.format("%s%s>%d\n", indent, self:GetString(), self:GetTreeSleepTicks() or 0)
	if self.children ~= nil then
		for i = 1, #self.children do
			local v = self.children[i]
			--Uncomment this to see only the "active" part of the tree.
			--if v.status == BNState.RUNNING or v.status == BNState.SUCCESS or v.lastresult == BNState.RUNNING or v.lastresult == BNState.SUCCESS then
				str = str..v:GetTreeString(indent.."   >")
			--end
		end
	end
	return str
end

function BehaviorNode:DBString()
	return ""
end

function BehaviorNode:SleepTicks(ticks)
	self.nextupdatetick = GetTick() + ticks
end

function BehaviorNode:Sleep(time)
	self:SleepTicks(math.ceil(time * SECONDS))
end

function BehaviorNode:GetSleepTicks()
	if self.status == BNState.RUNNING and self.children == nil and not self:is_a(ConditionNode) then
		return math.max(0, self.nextupdatetick - GetTick())
	end
end

function BehaviorNode:GetTreeSleepTicks()
	local sleepticks = self:GetSleepTicks()
	if self.children ~= nil then
		for i = 1, #self.children do
			local v = self.children[i]
			if v.status == BNState.RUNNING then
				local ticks = v:GetTreeSleepTicks()
				if ticks ~= nil and (sleepticks == nil or sleepticks > ticks) then
					sleepticks = ticks
				end
			end
		end
	end
	return sleepticks
end

function BehaviorNode:GetString()
	return string.format("%s - %s <%s> (%s)", self.name, self.status or "UNKNOWN", self.lastresult or "?", self.status == BNState.RUNNING and self:DBString() or "")
end

function BehaviorNode:Visit()
	TheSim:ProfilerPush(self.name)
	self.status = BNState.FAILED
	TheSim:ProfilerPop()
end

function BehaviorNode:SaveStatus()
	self.lastresult = self.status
	if self.children ~= nil then
		for i = 1, #self.children do
			self.children[i]:SaveStatus()
		end
	end
end

function BehaviorNode:Step()
	if self.status ~= BNState.RUNNING then
		self:Reset()
	elseif self.children ~= nil then
		for i = 1, #self.children do
			self.children[i]:Step()
		end
	end
end

function BehaviorNode:Reset()
	if self.status ~= BNState.READY then
		self.status = BNState.READY
		if self.children ~= nil then
			for i = 1, #self.children do
				self.children[i]:Reset()
			end
		end
	end
end

---------------------------------------------------------------------------------------

DecoratorNode = Class(BehaviorNode, function(self, name, child)
	BehaviorNode._ctor(self, name or "Decorator", { child })
end)

---------------------------------------------------------------------------------------

ConditionNode = Class(BehaviorNode, function(self, inst, fn, name)
	BehaviorNode._ctor(self, name or "Condition")
	self.inst = inst
	self.fn = fn
end)

function ConditionNode:Visit()
	TheSim:ProfilerPush(self.name)
	self.status = self.fn(self.inst) and BNState.SUCCESS or BNState.FAILED
	TheSim:ProfilerPop()
end

---------------------------------------------------------------------------------------

ConditionWaitNode = Class(BehaviorNode, function(self, inst, fn, name)
	BehaviorNode._ctor(self, name or "Wait")
	self.inst = inst
	self.fn = fn
end)

function ConditionWaitNode:Visit()
	TheSim:ProfilerPush(self.name)
	self.status = self.fn(self.inst) and BNState.SUCCESS or BNState.RUNNING
	TheSim:ProfilerPop()
end

---------------------------------------------------------------------------------------

ActionNode = Class(BehaviorNode, function(self, inst, action, name)
	BehaviorNode._ctor(self, name or "ActionNode")
	self.inst = inst
	self.action = action
end)

function ActionNode:Visit()
	TheSim:ProfilerPush(self.name)
	self.action(self.inst)
	self.status = BNState.SUCCESS
	TheSim:ProfilerPop()
end

---------------------------------------------------------------------------------------

WaitNode = Class(BehaviorNode, function(self, time)
	BehaviorNode._ctor(self, "Wait")
	self.wait_time = time
	self.wake_time = nil
end)

function WaitNode:DBString()
	return string.format("%2.2f", self.wake_time - GetTime())
end

function WaitNode:Visit()
	TheSim:ProfilerPush(self.name)
	local current_time = GetTime()

	if self.status ~= BNState.RUNNING then
		self.wake_time = current_time + self.wait_time
		self.status = BNState.RUNNING
	end

	if current_time >= self.wake_time then
		self.status = BNState.SUCCESS
	else
		self:Sleep(current_time - self.wake_time)
	end
	TheSim:ProfilerPop()
end

---------------------------------------------------------------------------------------

SequenceNode = Class(BehaviorNode, function(self, children)
	BehaviorNode._ctor(self, "Sequence", children)
	self.idx = 1
end)

function SequenceNode:DBString()
	return tostring(self.idx)
end

function SequenceNode:Reset()
	SequenceNode._base.Reset(self)
	self.idx = 1
end

function SequenceNode:Visit()
	TheSim:ProfilerPush(self.name)
	if self.status ~= BNState.RUNNING then
		self.idx = 1
	end

	while self.idx <= #self.children do
		local child = self.children[self.idx]
		child:Visit()
		if child.status == BNState.RUNNING or child.status == BNState.FAILED then
			self.status = child.status
			TheSim:ProfilerPop()
			return
		end
		self.idx = self.idx + 1
	end

	self.status = BNState.SUCCESS
	TheSim:ProfilerPop()
end

---------------------------------------------------------------------------------------

SelectorNode = Class(BehaviorNode, function(self, children)
	BehaviorNode._ctor(self, "Selector", children)
	self.idx = 1
end)

function SelectorNode:DBString()
	return tostring(self.idx)
end

function SelectorNode:Reset()
	SelectorNode._base.Reset(self)
	self.idx = 1
end

function SelectorNode:Visit()
	TheSim:ProfilerPush(self.name)
	if self.status ~= BNState.RUNNING then
		self.idx = 1
	end

	while self.idx <= #self.children do
		local child = self.children[self.idx]
		child:Visit()
		if child.status == BNState.RUNNING or child.status == BNState.SUCCESS then
			self.status = child.status
			TheSim:ProfilerPop()
			return
		end
		self.idx = self.idx + 1
	end

	self.status = BNState.FAILED
	TheSim:ProfilerPop()
end

---------------------------------------------------------------------------------------

NotDecorator = Class(DecoratorNode, function(self, child)
	DecoratorNode._ctor(self, "Not", child)
end)

function NotDecorator:Visit()
	TheSim:ProfilerPush(self.name)
	local child = self.children[1]
	child:Visit()
	if child.status == BNState.SUCCESS then
		self.status = BNState.FAILED
	elseif child.status == BNState.FAILED then
		self.status = BNState.SUCCESS
	else
		self.status = child.status
	end
	TheSim:ProfilerPop()
end

---------------------------------------------------------------------------------------

FailIfRunningDecorator = Class(DecoratorNode, function(self, child)
	DecoratorNode._ctor(self, "FailIfRunning", child)
end)

function FailIfRunningDecorator:Visit()
	TheSim:ProfilerPush(self.name)
	local child = self.children[1]
	child:Visit()
	self.status = child.status == BNState.RUNNING and BNState.FAILED or child.status
	TheSim:ProfilerPop()
end

---------------------------------------------------------------------------------------

-- Useful to make a prioritynode move to the next element whether a child succeeds or fails
FailIfSuccessDecorator = Class(DecoratorNode, function(self, child)
	DecoratorNode._ctor(self, "FailIfSuccess", child)
end)

function FailIfSuccessDecorator:Visit()
	TheSim:ProfilerPush(self.name)
	local child = self.children[1]
	child:Visit()
	self.status = child.status == BNState.SUCCESS and BNState.FAILED or child.status
	TheSim:ProfilerPop()
end
---------------------------------------------------------------------------------------

LoopNode = Class(BehaviorNode, function(self, children, maxreps)
	BehaviorNode._ctor(self, "Sequence", children)
	self.idx = 1
	self.maxreps = maxreps
	self.rep = 0
end)

function LoopNode:DBString()
	return tostring(self.idx)
end

function LoopNode:Reset()
	LoopNode._base.Reset(self)
	self.idx = 1
	self.rep = 0
end

function LoopNode:Visit()
	TheSim:ProfilerPush(self.name)
	if self.status ~= BNState.RUNNING then
		self.idx = 1
		self.rep = 0
	end

	while self.idx <= #self.children do
		local child = self.children[self.idx]
		child:Visit()
		if child.status == BNState.RUNNING or child.status == BNState.FAILED then
			self.status = child.status
			TheSim:ProfilerPop()
			return
		end
		self.idx = self.idx + 1
	end 

	self.idx = 1
	self.rep = self.rep + 1

	if self.maxreps ~= nil and self.rep >= self.maxreps then
		self.status = BNState.SUCCESS
	else
		for i = 1, #self.children do
			self.children[i]:Reset()
		end
	end
	TheSim:ProfilerPop()
end

---------------------------------------------------------------------------------------

RandomNode = Class(BehaviorNode, function(self, children)
	BehaviorNode._ctor(self, "Random", children)
	self.idx = nil
end)

function RandomNode:Reset()
	RandomNode._base.Reset(self)
	self.idx = nil
end

function RandomNode:Visit()
	TheSim:ProfilerPush(self.name)
	if self.status == BNState.READY then
		local start = math.random(#self.children)
		self.idx = start
		repeat
			local child = self.children[self.idx]
			child:Visit()
			if child.status ~= BNState.FAILED then
				self.status = child.status
				TheSim:ProfilerPop()
				return
			end
			self.idx = self.idx < #self.children and self.idx + 1 or 1
		until self.idx == start
		self.status = BNState.FAILED
	else
		local child = self.children[self.idx]
		child:Visit()
		self.status = child.status
	end
	TheSim:ProfilerPop()
end

---------------------------------------------------------------------------------------    

PriorityNode = Class(BehaviorNode, function(self, children, period, noscatter)
	BehaviorNode._ctor(self, "Priority", children)
	self.period = period or 1
	self.idx = nil
	if not noscatter then
		self.lasttime = GetTime() - self.period * .5 * math.random()
	end
end)

function PriorityNode:GetSleepTicks()
	if self.status == BNState.RUNNING then
		return self.lasttime ~= nil and math.max(0, math.ceil((self.lasttime + self.period - GetTime())) * SECONDS) or 0
	elseif self.status == BNState.READY then
		return 0
	end
end

function PriorityNode:DBString()
	local time_till = self.lasttime ~= nil and math.max(0, self.lasttime + self.period - GetTime()) or 0
	return string.format("execute %d, eval in %2.2f", self.idx or -1, time_till)
end

function PriorityNode:Reset()
	PriorityNode._base.Reset(self)
	self.idx = nil
end

function PriorityNode:Visit()
	TheSim:ProfilerPush(self.name)
	local time = GetTime()
	if self.lasttime == nil or self.lasttime + self.period < time then
		self.lasttime = time

		local old_event = nil
		if self.idx ~= nil and self.children[self.idx]:is_a(EventNode) then
			old_event = self.children[self.idx]
		end

		local found = false
		for idx = 1, #self.children do
			local child = self.children[idx]
			local should_test_anyway = old_event ~= nil and child:is_a(EventNode) and old_event.priority <= child.priority
			if not found or should_test_anyway then
				if child.status == BNState.FAILED or child.status == BNState.SUCCESS then
					child:Reset()
				end
				child:Visit()
				local cs = child.status
				if cs == BNState.SUCCESS or cs == BNState.RUNNING then
					if should_test_anyway and self.idx ~= idx then
						self.children[self.idx]:Reset()
					end
					self.status = cs
					found = true
					self.idx = idx
				end
			else
				child:Reset()
			end
		end
		if not found then
			self.status = BNState.FAILED
		end
	elseif self.idx then
		local child = self.children[self.idx]
		if child.status == BNState.RUNNING then
			child:Visit()
			self.status = child.status
			if self.status ~= BNState.RUNNING then
				self.lasttime = nil
			end
		end
	end
	TheSim:ProfilerPop()
end

---------------------------------------------------------------------------------------

ParallelNode = Class(BehaviorNode, function(self, children, name)
	BehaviorNode._ctor(self, name or "Parallel", children)
	--self.stoponanycomplete = false
end)

function ParallelNode:Step()
	if self.status ~= BNState.RUNNING then
		self:Reset()
	elseif self.children ~= nil then
		for i = 1, #self.children do
			local v = self.children[i]
			if v.status == BNState.SUCCESS and v:is_a(ConditionNode) then
				v:Reset()
			end
		end
	end
end

function ParallelNode:Visit()
	TheSim:ProfilerPush(self.name)
	local done = true
	local any_done = false
	for i = 1, #self.children do
		local child = self.children[i]
		if child:is_a(ConditionNode) then
			child:Reset()
		end
		if child.status ~= BNState.SUCCESS then
			child:Visit()
			if child.status == BNState.FAILED then
				self.status = BNState.FAILED
				TheSim:ProfilerPop()
				return
			end
		end
		if child.status == BNState.RUNNING then
			done = false
		else
			any_done = true
		end
	end
	self.status = (done or (any_done and self.stoponanycomplete)) and BNState.SUCCESS or BNState.RUNNING
	TheSim:ProfilerPop()
end

ParallelNodeAny = Class(ParallelNode, function(self, children)
	ParallelNode._ctor(self, children, "Parallel(Any)")
	self.stoponanycomplete = true
end)

---------------------------------------------------------------------------------------

EventNode = Class(BehaviorNode, function(self, brain, event, child, priority)
	BehaviorNode._ctor(self, "Event("..event..")", { child })
	self.brain = brain
	self.priority = priority or 0

	brain:AddEventHandler(event, function(inst, data) self:OnEvent(data) end)
end)

--Can override this to check data before triggering
function EventNode:OnEvent()--data)
	if self.status == BNState.RUNNING then
		self.children[1]:Reset()
	end

	self.triggered = true

	--Wake the parent!
	local parent = self.parent
	while parent ~= nil do
		if parent:is_a(PriorityNode) then
			parent.lasttime = nil
		end
		parent = parent.parent
	end

	self.brain:ForceUpdate()
end

function EventNode:Step()
	EventNode._base.Step(self)
	self.triggered = false
end

function EventNode:Reset()
	self.triggered = false
	EventNode._base.Reset(self)
end

function EventNode:Visit()
	TheSim:ProfilerPush(self.name)
	if self.status == BNState.READY and self.triggered then
		self.status = BNState.RUNNING
	end

	if self.status == BNState.RUNNING then
		local child = self.children[1]
		child:Visit()
		self.status = child.status
	end
	TheSim:ProfilerPop()
end

---------------------------------------------------------------

function WhileNode(inst, cond, name, node)
	return ParallelNode({
		ConditionNode(inst, cond, name),
		node,
	})
end

---------------------------------------------------------------

function IfNode(inst, cond, name, node)
	return SequenceNode({
		ConditionNode(inst, cond, name),
		node,
	})
end

---------------------------------------------------------------

LatchNode = Class(BehaviorNode, function(self, latchduration, child)
	BehaviorNode._ctor(self, "Latch ("..tostring(latchduration)..")", { child })
	self.latchduration = latchduration
	self.nextlatchtime = 0
end)

function LatchNode:Visit()
	TheSim:ProfilerPush(self.name)
	if self.status == BNState.READY then
		local t = GetTime()
		if t >= self.nextlatchtime then
			self.nextlatchtime = t + self.latchduration
			self.status = BNState.RUNNING
		else
			self.status = BNState.FAILED
		end
	end

	if self.status == BNState.RUNNING then
		self.children[1]:Visit()
		self.status = self.children[1].status
	end
	TheSim:ProfilerPop()
end
