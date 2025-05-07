local qconstants = require "questral.questralconstants"
local loc = require "questral.util.loc"
--~ local ScalarAccumulator = require "util.scalaraccumulator"
local QuestralActor = require "questral.questralactor"

---------------------------------------------------------------

-- Agent is usually an NPC. They're an actor who can speak in conversations.
-- They could also be a location or enemy or something else.
local Agent = Class(QuestralActor)
Agent:add_mixin( require "questral.contentnode" )
--~ Agent:add_mixin( require "sim.conditionholder" )
--~ Agent:CreateClassBucket( require "sim.condition" )

Agent.DebugNodeName = "DebugAgent"

Agent:AddStrings{
    TITLE_NAME = "<@RANK{3}>{1} {2}",
    TITLE_NAME_NORANK = "{1} {2}",
    IDENTITY_ROLE = "<@RANK{1}>{2} {3}", -- eg. [2] Thickets Maurader
    IDENTITY_ROLE_NORANK = "{2} {3}", -- eg. [2] Thickets Maurader
    IDENTITY_SPECIES = "<RANK{1}>Unknown {2}", -- eg. [2] Unknown Shroke
    IDENTITY_SPECIES_NORANK = "Unknown {2}", -- eg. [2] Unknown Shroke
}

function Agent:RemovePossession(obj)
    if obj.agent_owner == obj then
        obj.agent_owner = nil
    end
    if self.possessions then
        table.removearrayvalue(self.possessions, obj)
    end
    return self
end

function Agent:AddPossession(obj)
    self.possessions = self.possessions or {}
    table.insert_unique(self.possessions, obj)
    if obj.agent_owner and obj.agent_owner.possessions then
        table.removearrayvalue( obj.agent_owner.possessions, obj )
    end

    obj.agent_owner = self
end

function Agent:GetPossessions()
    return self.possessions or table.empty
end

function Agent:GetGender()
    return self.skin:GetGender()
end

function Agent:GetRank()
    return self.rank or 1
end

function Agent:SetRank( rank )
    self.rank = rank
end

function Agent:GetSpecies()
    return self.skin:GetSpecies()
end

function Agent:OnActivate()
    -- TODO(dbriscoe): Setup proper skins
    --~ if self.skin == nil then
    --~     self:SetSkin( self:GetContentDB():Get( require "questral.agentskin", "DEFAULT" ))
    --~ end
    self.skin = {
        id = "default",
        quip_tag = "", -- appropriate quips?
        role = "scout", -- npc job
    }
end

function Agent:OnDeactivate()
end

function Agent:GetSkin()
    return self.skin
end

function Agent:GetPlayerCharacterData()
    return self.playerdata
end

function Agent:SetSkin(skin, name)
    if name then
        self.name = name
    end
    self.skin = skin

    self:BroadcastEvent("SKIN_CHANGED")
    return self
end

function Agent:GetVoice()
    return self.skin:GetVoice()
end

-- TODO(dbriscoe): Rename GetName -> GetPrettyName
function Agent:GetName()
    if self.name then
        return self.name:Get()
    --~ elseif self.skin and self.skin:GetName() then
    --~     return self.skin and self.skin:GetName()
    else
        return "[NONAME]"
    end
end

function Agent:GetRankName()
    return loc.format( LOC "UI.AGENT_RANK_NAME", self:GetRank(), self )
end

function Agent:GetUIName(hide_rank)
    if not self:IsIdentityKnown() then
        local role_name = self:GetFactionRoleName()
        if role_name then
            -- If we have a role_name, we must have a faction.
            return loc.format( hide_rank and self:LOC "IDENTITY_ROLE_NORANK" or self:LOC "IDENTITY_ROLE", self:GetRank(), self:GetFaction():GetName(), role_name )
        else
            return loc.format( hide_rank and self:LOC "IDENTITY_SPECIES_NORANK" or self:LOC "IDENTITY_SPECIES", self:GetRank(), self:GetSpecies():GetName() )
        end
    else
        return self:GetTitleName(hide_rank)
    end
end

function Agent:GetUndecoratedName()
    if self.name then
        return self.name:Get()
    elseif self.skin then
        return self.skin and self.skin:GetUndecoratedName()
    else
        return "[NONAME]"
    end
end

function Agent:GetTitleName(hide_rank)
    local title = self:GetTitle()
    return title and loc.format( hide_rank and self:LOC"TITLE_NAME_NORANK" or self:LOC"TITLE_NAME", title, self:GetName(), self:GetRank() ) or self:GetRankName()
end

function Agent:GetFaction()
    return self.faction
end

function Agent:GetFactionRole()
    return self.role or (self.skin and self.skin.role)
end

function Agent:GetFactionRoleData()
    local role = self:GetFactionRole()
    return self.faction and self.faction:GetRole( role )
end

function Agent:GetFactionRoleName()
    local role = self:GetFactionRole()
    return self.faction and role and self.faction:GetRoleName(role)
end

function Agent:SetFaction( faction )
    self.faction = faction
end

function Agent:GetVoice()
    return self.skin:GetVoice()
end

function Agent:GetSectorAncestor()
    return self:GetAncestorByClass( require "sim.sector" )
end

function Agent:HasTag(tag)
    local role_data = self:GetFactionRoleData()
    if role_data and role_data.tags:has(tag) then
        return true
    end
    return Agent._base.HasTag(self, tag)
end

function Agent:IsPlayer()
    return self:HasTag( qconstants.ETAG.s.PLAYER )
end

function Agent:GetMoney()
    return self.money or 0
end

function Agent:DeltaMoney( delta )
    local old_money = self.money or 0
    self.money = math.max( 0, (self.money or 0) + delta )
    if self.money ~= old_money then
        self:BroadcastEvent( "MONEY_CHANGED", self.money, old_money )
    end
    return self
end

function Agent:SetMoney( val )
    return self:DeltaMoney( val - self:GetMoney() )
end

function Agent:IsKilled()
    return self.killed == true
end

function Agent:_AwardBounty( killer )
    local bounty = self:GetComponent( require "sim.components.agent.cmpbounty" )
    if bounty then
        local BountyReceivedNotification = require "sim.notifications.bountyreceivednotification"
        killer:GetQC():Notify(BountyReceivedNotification(self, bounty:GetBountyAmount()))
        killer:DeltaMoney( bounty:GetBountyAmount() )
    end
end

function Agent:Kill(killer)
    if killer then
        if killer.GetPilot then
            killer = killer:GetPilot()
        else
            killer = nil
        end
    end
    assert( killer == nil or Agent.is_instance(killer))

    self.killed = true
    self.killed_by = killer

    if self:IsCurrentlyImportant() then
        print( self, "was killed!" )

        if killer then
            self:AddOpinion( "KILLED_BY", { sector = self:GetSectorAncestor(), killer = killer } )
        else
            self:AddOpinion( "KILLED_UNKNOWN" )
        end
    end

    self:BroadcastEvent("AGENT_KILLED")

    if killer and killer:IsPlayer() then
        self:_AwardBounty( killer )
    end
end

function Agent:MakeCorpse()
    assert( self.killed )

    -- Coffin maintains reference to us, but we're not 'in it' until the coffin is attached by the caller.
    local ItemCoffin = require "sim.items.itemcoffin"
    local item = ItemCoffin()
    item:SetAgent( self )
    return item
end

function Agent:IsHostile()
    return self.is_hostile
end

function Agent:SetHostile(hostile)
    assert(hostile ~= nil)
    self.is_hostile = hostile
    return self
end

function Agent:IsOpenToIdleConversation()
    return not self:IsHostile()
end

function Agent:__tostring()
    if self.activationId then
        return string.format( "%d-%s'%s'", self.activationId, self.role or self._classname, (self.name and self.name.id) or (self.skin and self.skin.id))
    else
        return string.format( "%s'%s'", self.role or self._classname, (self.name and self.name.id) or (self.skin and self.skin.id) )
    end
end

function Agent:LocMacro(value, ...)
    if value == nil then
        return string.format( "<!node_%d><#ACTOR_NAME>%s</></>", self:GetActivationID() or 0000, self:GetName() )

    elseif value == "name" then
        return self:GetName()

    elseif value == "title_name" then
        return string.format( "<!node_%d><#ACTOR_NAME>%s</></>", self:GetActivationID() or 0000, self:GetTitleName() )

    elseif value == "ui" then
        return self:GetUIName()

    elseif value == "ui_norank" then
        local hide_rank = true
        return self:GetUIName(hide_rank)

    elseif value == "gender" then
        local gender = self:GetGender()
        local args = {...}
        if gender == qconstants.GENDER.s.MALE then
            return args[1] or "[MISSING MALE WORD]"
        elseif gender == qconstants.GENDER.s.FEMALE then
            return args[2] or "[MISSING FEMALE WORD]"
        else
            return args[3] or "[MISSING NONBINARY WORD]"
        end

    else
        local gender_nouns = (require "content.strings").GENDER_NOUNS
        local gender = self:GetGender()
        return gender_nouns[gender][value]
    end

    return loc.format("[BAD AGENT LOCMACRO '{1}']", value)
end

function Agent:GetBio()
    local StringFormatter = require "questral.util.stringformatter"
    local formatter = StringFormatter()
    formatter:AddLookup("agent", self)
    return formatter:FormatString(self.skin and self.skin:GetBio() or "")
end

function Agent:GetTitle()
    local StringFormatter = require "questral.util.stringformatter"
    local formatter = StringFormatter()
    formatter:AddLookup("agent", self)
    local title = self.playerdata and self.playerdata:GetTitle( ) or self:GetFactionRoleName( ) or ""
    return formatter:FormatString( title )
end

function Agent:FillOutQuipTags(tag_dict)
    Agent._base.FillOutQuipTags(self, tag_dict)

    if self.playerdata and self.playerdata.quip_tag then
        tag_dict[self.playerdata.quip_tag] = true
    end


    local faction = self:GetFaction()
    if faction then
        tag_dict[faction:GetQuipTag()] = true

        local role = self:GetFactionRole()
        if role then
            tag_dict[role] = true
        end
        local title = faction:GetPlayerTitle()
        if title then
            tag_dict.player_has_title = true
            if title.quip_tags then
                for k,v in ipairs(title.quip_tags) do
                    tag_dict[v] = true
                end
            end
        end
    end

    if self:IsHostile() then
        tag_dict.hostile = true
    else
        tag_dict.not_hostile = true
    end
end

--~ function Agent:GetOpinion()
--~     local CmpAgentHistory = require "sim.components.agent.cmpagenthistory"
--~     local cmp = self:GetComponent( CmpAgentHistory )
--~     if cmp then
--~         return cmp:GetOpinion()
--~     else
--~         return qconstants.OPINION.s.NEUTRAL, 0
--~     end
--~ end

--~ function Agent:HasOpinion( opinion_id, since_time )
--~     local CmpAgentHistory = require "sim.components.agent.cmpagenthistory"
--~     local cmp = self:GetComponent( CmpAgentHistory )
--~     return cmp and cmp:FindOpinionEventByID( opinion_id, since_time ) ~= nil
--~ end

--~ function Agent:GetRelationship()
--~     local CmpAgentHistory = require "sim.components.agent.cmpagenthistory"
--~     local cmp = self:GetComponent( CmpAgentHistory )
--~     return cmp and cmp:GetRelationship() or qconstants.RELATIONSHIP.s.STRANGER
--~ end

--~ function Agent:IsIdentityKnown()
--~     return qconstants.RELATIONSHIP_PROPERTIES[ self:GetRelationship() ].identity_known == true
--~ end

--~ function Agent:IsFriendly()
--~     return qconstants.RELATIONSHIP_PROPERTIES[ self:GetRelationship() ].friendly == true
--~ end

--~ function Agent:IsUnfriendly()
--~     return qconstants.RELATIONSHIP_PROPERTIES[ self:GetRelationship() ].unfriendly == true
--~ end

--~ function Agent:AddOpinion( id, params )
--~     local sim = self:GetQC()
--~     if not sim or not sim.GetPlayer then
--~         d_view{ "Agent needs to be attached to receive opinion events", self, id, debug.traceback() }
--~         return
--~     end

--~     local OpinionEvent = require "sim.opinionevent"
--~     local when = sim:GetCyclesPassed()
--~     local op_class = OpinionEvent.GetEvent( id )
--~     if not op_class then
--~         LOGWARN( "Invalid AddOpinion( %s ) to %s", tostring(id), tostring(self) )
--~     else
--~         local op = op_class( self, sim:GetPlayer(), when, params )
--~         self:AddOpinionEvent( op )
--~         return op
--~     end
--~ end

--~ function Agent:AddOpinionEvent( ev )
--~     local CmpAgentHistory = require "sim.components.agent.cmpagenthistory"
--~     local cmp = self:GetComponent( CmpAgentHistory )
--~     if cmp == nil then
--~         cmp = self:AddComponent( CmpAgentHistory() )
--~     end
--~     cmp:AddOpinionEvent( ev )
--~ end

function Agent:CanDistribute()
    for i, quest in ipairs( self:GetQuests() ) do
        local ok, reason = quest:CanDistributeAgent( self )
        if not ok then
            return false, (reason or "in quest") .. " " .. tostring(quest)
        end
    end

    if self:IsManaged() then
        return false, "managed"
    end
    if self:IsPlayer() then
        return false, "player"
    else
        local ship = self:GetAncestorByClass( require "sim.entities.ships.configurableship" )
        if ship and ship:IsPlayer() then
            -- I'm an NPC on the player ship
            return false, "in player ship"
        end
    end

    return true
end

function Agent:IsCurrentlyImportant()
    for i, quest in ipairs( self:GetQuests() ) do
        if quest:IsCastImportant( self ) then
            return true
        end
    end

    if self:IsPlayer() then
        return true
    end

    if self:IsIdentityKnown() then
        return true
    end

    if self.possessions and #self.possessions > 0 then
        return true
    end

    return false
end

function Agent:Remember(id)
    local now = self:GetQC():GetCyclesPassed() or 0
    self.memories = self.memories or {}
    self.memories[id] = now
end

function Agent:HasMemory(id)
    return self.memories and self.memories[id] ~= nil
end

function Agent:GetTimeSinceMemory(id)
    local now = self:GetQC():GetCyclesPassed() or 0
    local when = self.memories and self.memories[id]
    if when then
        return now - when
    end
end

function Agent:TestMemory(id, time_since_test)
    local time_since = self:GetTimeSinceMemory(id)
    return time_since and time_since <= time_since_test
end

--~ function Agent:GetAccumulatedValue( event_name, default_value, ... )
--~     local acc = ScalarAccumulator()
--~     return acc:CalculateValue( self, event_name, default_value, ... )
--~ end

--~ function Agent:PreviewAccumulatedValue( event_name, default_value, ... )
--~     local acc = ScalarAccumulator()
--~     return acc:PreviewValue( self, event_name, default_value, ... )
--~ end


--this is "where" and agent is for the purposes of conversation. It's not technically the same place
--as where they are, because the player agent never really leaves their ship. It's "the room you are talking to".
function Agent:SetConvoLocation( convoloc )
    local CmpAtLocation = require "sim.components.agent.cmpatlocation"
    local atloc = self:GetComponent(CmpAtLocation)
    if convoloc then
        if not atloc then
            atloc = self:AddComponent(CmpAtLocation())
        end
        atloc:SetLocation(convoloc)
    else
        if atloc then
            self:RemoveComponent(atloc)
        end
    end
end

function Agent:GetConvoLocation( agent )
    local atloc = nil -- self:GetComponent(require "sim.components.agent.cmpatlocation")
    local atloc_loc = atloc and atloc:GetLocation()

    if atloc_loc then
        return atloc_loc
    end

    return self:GetParent()
end

function Agent:RefreshInventory()
    local roledata = self:GetFactionRoleData()

    local base_money
    if roledata.base_money then
        base_money = roledata.base_money
    elseif self:HasTag("TRADER") then
        base_money = qconstants.MONEY.MERCHANT_CASH_BY_RANK[self:GetRank()]
    else
        base_money = qconstants.MONEY.AGENT_CASH_BY_RANK[self:GetRank()]
    end

    local money = math.round( math.randomGauss(base_money*.75, base_money*1.25) )
    self:SetMoney( money )
end

function Agent:GetMaxMorale()
    if not self:IsPlayer() then
        local role_data = self:GetFactionRoleData()
        return role_data and role_data.max_morale
    end
end

return Agent
