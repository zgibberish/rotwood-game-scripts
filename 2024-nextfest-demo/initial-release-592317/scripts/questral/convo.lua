local ConvoState = require "questral.convostate"
local SimContent = require "questral.simcontent"
local qconstants = require "questral.questralconstants"
local strict = require "util.strict"


local Convo = Class(SimContent, function(self, ...) self:init(...) end)
Convo._classname = "Convo"

Convo.PRIORITY = {
    LOWEST = -100,
    LOW = -10,
    NORMAL = 0,
    HIGH = 10,
    HIGHEST = 100
}
strict.strictify(Convo.PRIORITY, "Convo.PRIORITY")

function Convo:init(id)
    Convo._base.init(self, id)
    self.id = id
    self.states = {}
end

function Convo:GetPriority()
    return self.priority or 0
end

function Convo:SetPriority(p)
    dbassert(p, "Don't call or pass 0 to reset to the default priority.")
    self.priority = p
    return self
end

function Convo:GetState(id)
    return self.states[id]
end

function Convo:GetStateIDs()
    return table.getkeys( self.states )
end

function Convo:AddState(id)
    id = id or ("STATE_" .. table.numkeys(self.states))
    assert(self.states[id] == nil, "Adding duplicate state!")
    local first_state = not next(self.states)
    self.states[id] = ConvoState(self, id)
    if first_state then
        self.default_state = self.states[id]
    end
    return self.states[id]
end

function Convo:GetDefaultState()
    return self.default_state
end


function Convo.Create( arg )
    assert( arg == nil )
    local classname = debug.getinfo(2, "S").source:match("^.*/(.*).lua$"):lower()
    return Convo(classname)
end

function Convo:GetQuipID()
    if not self.quip_id then
        self.quip_id = "in_convo_" .. self:GetContentID():lower()
    end
    return self.quip_id
end

function Convo:AddQuip(quip)
    -- Same as Quest:AddQuip.
    quip:Tag(self:GetQuipID(), qconstants.QUIP_WEIGHT.Convo)
    SimContent.AddQuip(self, quip)
end

return Convo
