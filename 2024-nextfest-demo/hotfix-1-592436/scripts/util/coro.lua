local Coro = Class(function(self,fn, ...)
    if fn == nil then
        self.done = true
    elseif type(fn) == "function" then
        self.c = coroutine.create(fn)
        self:Resume( ... )
    elseif type(fn) == "thread" then
        self.c = fn
    else
        error()
    end
end)

function Coro:Stop()
    self.done = true
end

function Coro:IsDone()
    return self.done
end

function Coro:IsRunning()
    return coroutine.running() == self.c
end

function Coro:IsSuspended()
    return coroutine.status(self.c) == "suspended"
end

-- Call from another coroutine to wait until this one completes. aka Join()
function Coro:WaitUntilComplete()
    assert( coroutine.running() ~= self.c )
    while not self.done do
        coroutine.yield()
    end
end

function Coro:Chain( fn )
    if self.done then
        self.done = false
        self.c = coroutine.create( fn )
        self:Resume()
    else
        if self.fns == nil then
            self.fns = {}
        end
        table.insert( self.fns, fn )
    end
end

global "ACTIVE_CORO"
local function wrap_resume(c, ...)
    ACTIVE_CORO = c
    local ret, err = coroutine.resume(c, ...)
    ACTIVE_CORO = nil
    return ret, err
end

function Coro:Resume( ... )
    if self.done then
        return false
    end

    -- Got Stale Component Reference?
    --
    -- To track down stacktraces pointing here instead of inside your
    -- coroutine, replace coroutine.resume with wrap_resume. Not enabled
    -- normally because it doesn't dump the stack locals and unnecessary for
    -- errors (only necessary for DebugDump from native).
    local ret, err = coroutine.resume(self.c, ...)
    if not ret then
        local stack = debug.traceback(self.c)
        error(tostring(err) .. "\n" .. stack)
    end

    if not self:IsSuspended() then
        if self.fns and #self.fns > 0 then
            local fn = table.remove( self.fns, 1 )
            self.c = coroutine.create( fn )
            self:Resume()
        else
            self.done = true
        end
    end
    return not self.done
end

function Coro:Update(...)
    return self:Resume( ... )
end

return Coro
