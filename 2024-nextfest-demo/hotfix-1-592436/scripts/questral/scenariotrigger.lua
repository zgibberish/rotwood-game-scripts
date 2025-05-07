local ScenarioTrigger = Class(function(self, ...) self:init(...) end)

function ScenarioTrigger:init(id, objective_id, filter_fn)
    self.id = id
    self.objective_id = objective_id
    self.filter_fn = filter_fn
end

function ScenarioTrigger:Delay(time)
    self.delay_time = time
    return self
end

function ScenarioTrigger:Repeat()
    self.repeats = true
    return self
end

function ScenarioTrigger:Throttle(time)
    self.throttle_time = time
    return self
end

function ScenarioTrigger:Fn(fn)
    assert(self.fn == nil, "Duplicate fn call!")
    self.fn = fn
    return self
end

function ScenarioTrigger:ProcessTrigger(quest, scenario, state, trigger_state, dt)
    
    if trigger_state.count and not self.repeats then
        return
    end
    local now = scenario:GetFlightTime()
    

    if self.delay_time and now < self.delay_time then
        return
    end

    if self.objective_id then
        if not quest:IsActive(self.objective_id) then
            return
        end
    end

    if self.throttle_time then
        local time_since_last = trigger_state.last_time and now - trigger_state.last_time or math.huge
        if time_since_last < self.throttle_time then
            return
        end
    end

    if self.filter_fn then
        if not self.filter_fn(quest, scenario, state) then
            return
        end
    end

    local ret = self.fn and self.fn(quest, scenario, state)
    
    local triggered = true
    
    if self.repeats then
        triggered = ret
    end

    if triggered then
        trigger_state.count = (trigger_state.count or 0) + 1
        trigger_state.last_time = now
    end
end

return ScenarioTrigger
