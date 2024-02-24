local kassert = require "util.kassert"


--Updaters are meant to be used to create serial and parallel animations for widgets
local Updater = Class(function(self, name)
    self.status = "READY"
end)

function Updater:Stop()
    self:OnDone()
    if self.updaters then
        for k,v in pairs(self.updaters) do
            v:Stop()
        end
    end
end

function Updater:Reset()
    self:Stop()
    self.status = "READY"
    if self.OnReset then
        self:OnReset()
    end
    if self.updaters then
        for k,v in pairs(self.updaters) do
            v:Reset()
        end
    end
end

function Updater:Update(dt)
    if self.status == "READY" then
        self:OnStart()
    end
end

function Updater:OnStart()
    self.status = "RUNNING"
end

function Updater:OnDone()
    self.status = "DONE"
end

function Updater:IsDone()
    return self.status == "DONE"
end

function Updater:IsPaused()
    return self.status == "PAUSED"
end

function Updater:Pause()
    self.status = "PAUSED"
end

function Updater:Resume()
    self:OnStart()
end

----------------------------------------

Updater.Parallel = Class(Updater, function(self,Updaters)
    Updater._ctor(self)
    self.updaters = Updaters or {}
end)

function Updater.Parallel:Add(updater)
    table.insert(self.updaters, updater)
    return self
end

function Updater.Parallel:Update(dt)
    Updater.Parallel._base.Update(self, dt)

    if self:IsDone() or self:IsPaused() then
        return
    end

    for k,v in ipairs(self.updaters) do
        if not v:IsDone() then
            v:Update(dt)
        end
    end

    local all_done = true
    for k,v in ipairs(self.updaters) do
        if not v:IsDone() then
            all_done = false
            break
        end
    end

    if all_done then
        self:OnDone()
    end
end

----------------------------------------

Updater.Series = Class(Updater, function(self, updaters)
    Updater._ctor(self)
    self.updaters = updaters or {}
    self.idx = 1
end)

function Updater.Series:Add(updater)
    table.insert(self.updaters, updater)
    return self
end

function Updater.Series:AddList(updaters)
    for k,v in ipairs(updaters) do
        table.insert(self.updaters, v)
    end

    return self
end

function Updater.Series:OnReset()
    self.idx = 1
end

function Updater.Series:Update(dt)
    Updater.Series._base.Update(self, dt)
    if self:IsDone() or self:IsPaused() then
        return
    end

    local next_update = self.updaters[self.idx]
    while next_update do
        if not next_update:IsDone() then
            next_update:Update(dt)
        end

        if next_update:IsDone() then
            self.idx = self.idx + 1
            next_update = self.updaters[self.idx]
        else
            return
        end
    end

    self:OnDone()
end

----------------------------------------


Updater.Loop = Class(Updater, function(self, updaters, num_loops)
    Updater._ctor(self)
    self.updaters = updaters or {}
    self.idx = 1
    self.num_loops = num_loops
    self.num_loops_completed = 0
end)

function Updater.Loop:Add(updater)
    table.insert(self.updaters, updater)
    return self
end

function Updater.Loop:OnReset()
    self.idx = 1
    self.num_loops_completed = 0
end

function Updater.Loop:Update(dt)
    Updater.Loop._base.Update(self, dt)
    
    if self:IsDone() or self:IsPaused() then
        return
    end

    local next_update = self.updaters[self.idx]
    while next_update do
        
        if not next_update:IsDone() then
            next_update:Update(dt)
        end

        if next_update:IsDone() then
            self.idx = self.idx + 1
            if self.idx > #self.updaters then
                
                for k,v in ipairs(self.updaters) do
                    v:Reset()
                end
                self.idx = 1
                self.num_loops_completed = self.num_loops_completed + 1
                
                if self.num_loops and self.num_loops <= self.num_loops_completed then
                    self:OnDone()
                    return
                end

                return
            end
            next_update = self.updaters[self.idx]
        else
            return
        end
    end

    self:OnDone()
end


----------------------------------------

Updater.Wait = Class(Updater, function(self, time)
    Updater._ctor(self)
    kassert.typeof("number", time)
    self.init_time = time
    self.time = time
end)

function Updater.Wait:Update(dt)
    Updater.Wait._base.Update(self, dt)
    if self:IsDone() or self:IsPaused() then
        return
    end

    self.time = self.time - dt
    if self.time <= 0 then
        self:OnDone()
    end
end

function Updater.Wait:OnReset()
    self.time = self.init_time
end


----------------------------------------

Updater.Do = Class(Updater, function(self, fn)
    kassert.typeof("function", fn) -- Did you accidentally call a func instead of defining it?
    Updater._ctor(self)
    self.fn = fn
end)

function Updater.Do:Update(dt)
    Updater.Do._base.Update(self, dt)
    if self:IsDone() or self:IsPaused() then
        return
    end
    self.fn()
    self:OnDone()
end

----------------------------------------

Updater.While = Class(Updater, function(self, fn)
    kassert.typeof("function", fn) -- Did you accidentally call a func instead of defining it?
    Updater._ctor(self)
    self.fn = fn
end)

function Updater.While:Update(dt)
    Updater.While._base.Update(self, dt)
    if self:IsDone() or self:IsPaused() then
        return
    end
    
    if not self.fn() then
        -- print("Updater.While On Done")
        self:OnDone()
    end
end

----------------------------------------

Updater.Until = Class(Updater, function(self, fn)
    kassert.typeof("function", fn) -- Did you accidentally call a func instead of defining it?
    Updater._ctor(self)
    self.fn = fn
end)

function Updater.Until:Update(dt)
    Updater.Until._base.Update(self, dt)
    if self:IsDone() or self:IsPaused() then
        return
    end
    
    if self.fn() then
        self:OnDone()
    end
end

----------------------------------------
Updater.Ease = Class(Updater, function(self, application_fn, start_val, end_val, total_time, easing)
    kassert.typeof("number", start_val, end_val, total_time)
    Updater._ctor(self)
    
    self.application_fn = application_fn
    self.start_val = start_val
    self.end_val = end_val
    self.total_time = total_time
    self.easing = easing or easing.linear
    self.time = 0
end)

function Updater.Ease:OnReset()
    self.time = 0
end


function Updater.Ease:Update(dt)
    Updater.Ease._base.Update(self, dt)
    if self:IsDone() or self:IsPaused() then
        return
    end
    self.time = self.time + dt
    if self.time >= self.total_time then
        self.application_fn(self.end_val)
        self:OnDone()
    else
        self.application_fn(self.easing(self.time, self.start_val, self.end_val - self.start_val, self.total_time ))
    end

end

function Updater.Ease:SetStartValuePercent(p)
    self.time = self.total_time*p
    return self
end


Updater.Ease2D = Class(Updater, function(self, application_fn, start_val1, start_val2, end_val1, end_val2, total_time, easing)
    kassert.typeof("number", start_val1, start_val2, end_val1, end_val2, total_time)
    Updater._ctor(self)
    
    self.application_fn = application_fn
    
    self.start_val1 = start_val1
    self.end_val1 = end_val1
    self.start_val2 = start_val2
    self.end_val2 = end_val2
    
    self.total_time = total_time
    self.easing = easing or easing.linear
    self.time = 0
end)

function Updater.Ease2D:Update(dt)
    Updater.Ease2D._base.Update(self, dt)
    if self:IsDone() or self:IsPaused() then
        return
    end
    self.time = self.time + dt
    if self.time >= self.total_time then
        self.application_fn(self.end_val1, self.end_val2)
        self:OnDone()
    else
        self.application_fn(self.easing(self.time, self.start_val1, self.end_val1 - self.start_val1, self.total_time ),
                            self.easing(self.time, self.start_val2, self.end_val2 - self.start_val2, self.total_time ))
    end

end

function Updater.Ease2D:OnReset()
    self.time = 0
end

return Updater
