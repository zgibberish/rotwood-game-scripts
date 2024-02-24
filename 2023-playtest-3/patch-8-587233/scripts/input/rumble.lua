local kassert = require "util.kassert"


local Rumble = Class(function(self, id)
    self.id = id
    self.small = {}
    self.large = {}
end)

function Rumble:GetID()
    return self.id
end


function Rumble:SetLooping(val)
    self.looping = val
    return self
end

function Rumble:SetSmall(points)
    table.clear(self.small)
    for k = 1, #points, 2 do
        if points[k] < 0 then
            break
        end
        table.insert(self.small, points[k])
        table.insert(self.small, points[k+1])
    end
    return self
end

function Rumble:SetLarge(points)
    table.clear(self.large)
    for k = 1, #points, 2 do
        if points[k] < 0 then
            break
        end
        table.insert(self.large, points[k])
        table.insert(self.large, points[k+1])
    end
    return self
end

local function GetTrackValue(track, time, looping)
    if #track == 0 then
        return 0
    end

    local base_index = 1
    local max_time = #track > 0 and track[#track-1] or 0
    if looping then
        time = time % max_time
    end

    local end_index = nil

    for k = 1, #track, 2 do
        if track[k] >= time then
            end_index = k
            break
        end
        base_index = k
    end
    end_index = end_index or (#track-1)

    local t1 = track[base_index]
    local t2 = track[end_index]

    local v1 = track[base_index+1]
    local v2 = track[end_index+1]

    if t2 == t1 then
        return v1
    end

    local p = (time - t1)/(t2 - t1)
    return Lerp(v1, v2, p)
end

function Rumble:GetValues(time)
    return GetTrackValue(self.small, time, self.looping), GetTrackValue(self.large, time, self.looping)
end

function Rumble:IsDoneAtTime(t)
    if self.looping then
        return false
    end

    local max_time = 0
    if #self.small > 0 then
        max_time = math.max( max_time, self.small[#self.small-1])
    end

    if #self.large > 0 then
        max_time = math.max( max_time, self.large[#self.large-1])
    end

    return t >= max_time
end

-- I think the arguments are:
-- * small: is it a big or small shake
-- * maxt: imprecise duration of the shake in seconds
-- * dt: time between each rumble spike
-- * fn: function that returns the amplitude at input time
function Rumble:Sample(small, maxt, dt, fn)
    local track = small and self.small or self.large
    local t = 0
    while t < maxt do
        table.insert(track, t)
        table.insert(track, fn(t))
        t = t + dt
    end

    table.insert(track, maxt)
    table.insert(track, fn(maxt))

    return self
end

local RUMBLES = {}

local function AddRumble(rumble)
    RUMBLES[rumble:GetID()] = rumble
    return rumble
end

function GetRumble(id)
    -- TODO(dbriscoe): Make this more strict to fail fast.
    --~ kassert.typeof("string", id)
    return RUMBLES[id]
end

AddRumble( Rumble("VIBRATION_CAMERA_SHAKE"):Sample(false, 0.1, 1/30, function(x) return 1 end ) )
AddRumble( Rumble("VIBRATION_PLAYER_IDENTIFY"):Sample(true, 0.2, 1/30, function(x) return 1 end ) )
