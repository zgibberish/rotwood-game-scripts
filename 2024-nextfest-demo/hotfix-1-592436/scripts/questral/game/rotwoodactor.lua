local Agent = require "questral.agent"
local kstring = require "util.kstring"


-- Anything specific to how agents work within Rotwood's systems should go
-- here: components, dungeon, player, etc
local RotwoodActor = Class(Agent, function(self, inst)
    self.inst = inst
    self.prefab = inst and inst.prefab
end)

-- This is the npc system role and not related to roles/castdef in questral.
function RotwoodActor:SetNpcRole(role)
    self.role = role
    return self
end

function RotwoodActor:OverrideInteractingPlayerEntity(player)
    -- used for checking if hooks are valid
    self.player_override = player
end

function RotwoodActor:GetInteractingPlayerEntity()
    dbassert(self.inst or self.player_override, "We only know how to get players from conversation.")
    return self.player_override ~= nil and self.player_override or self.inst.components.conversation.target
end

function RotwoodActor:__tostring()
    return string.format("RotwoodActor[%s %s]", tostring(self.inst), kstring.raw(self))
end

function RotwoodActor:GetName()
    if self.prefab then
        return STRINGS.NAMES[self.prefab]
    end
end

return RotwoodActor
