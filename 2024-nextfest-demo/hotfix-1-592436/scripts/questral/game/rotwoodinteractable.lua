local Agent = require "questral.agent"
local kstring = require "util.kstring"

local RotwoodInteractable = Class(Agent, function(self, inst)
    self.inst = inst
    self.prefab = inst and inst.prefab
end)

function RotwoodInteractable:SpawnReservation()
    assert(self.is_reservation, "Can only spawn if already reserved.")
    assert(self.prefab)
    return SpawnPrefab(self.prefab)
end

function RotwoodInteractable:__tostring()
    return string.format("RotwoodInteractable[%s %s]", tostring(self.inst), kstring.raw(self))
end

function RotwoodInteractable:GetName()
    if self.prefab then
        return STRINGS.NAMES[self.prefab]
    end
end

return RotwoodInteractable
