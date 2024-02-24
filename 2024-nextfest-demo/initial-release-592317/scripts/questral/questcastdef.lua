local Enum = require "util.enum"
local iterator = require "util.iterator"
local lume = require "util.lume"
local kstring = require "util.kstring"
local kassert = require "util.kassert"
local loc = require "questral.util.loc"
local krandom = require "util.krandom"

local QuestCastDef = Class(function(self, ...) self:init(...) end)

function QuestCastDef:init(quest_class, id)
    self.quest_class = quest_class
    self.id = id
    self.event_handlers = {}
end

function QuestCastDef:SetDeferred()
    self.is_deferred = true
    return self
end

function QuestCastDef:IsRequiredAssignment()
    -- If this cast definition has no filters or explicit casting function, it must be assigned to something when spawned.
    return not self.is_optional and self.filters == nil and self.cast_fn == nil and self.spawn_fn == nil
end

function QuestCastDef:SpawnFactionRoleFn(faction_type, role_or_roles, sector_cast)
    self:SpawnFn(function(quest, node)
        local faction = node:GetQC():FindFactionByClass( faction_type )
        if faction then
            local role
            if type(role_or_roles) == "table" then
                role = krandom.PickFromArray(role_or_roles)
            elseif type(role_or_roles) == "string" then
                role = role_or_roles
            end
            local agent = faction:GenerateMember(role, quest:GetCastMember( sector_cast ), quest:GetRank())
            return agent
        end
    end)
    return self
end

function QuestCastDef:FilterForPrefab(prefab)
	return self:Filter(function(quest, node, root)
		if node.prefab ~= prefab then
			return false, "Requires specific prefab: ".. prefab
		end
		return true
	end)
end

function QuestCastDef:FilterForRole(role)
	return self:Filter(function(quest, node, root)
		if node.role ~= role then
			return false, "Requires specific role: ".. role
		end
		return true
	end)
end

-- fn: filter(quest, node, root) -> ok, reason
function QuestCastDef:Filter(fn)
    self.filters = self.filters or {}
    table.insert(self.filters, fn)
    return self
end

-- Function that selects who to cast for this role.
-- fn: cast_fn(quest, root)
function QuestCastDef:CastFn(fn)
    self.cast_fn = fn
    return self
end

-- See Quest:ReceivedCastEvent
-- fn: event_handler(quest, cast_member, ...)
function QuestCastDef:OnEvent(event, fn)
    assert(self.event_handlers[event] == nil, "Duplicate casting event handler.")
    self.event_handlers[event] = fn
    return self
end

function QuestCastDef:ScoringFn(fn)
    self.scoring_fn = fn
    return self
end

-- Function to spawn an actor to fill this role if none was found.
-- fn: spawn_fn(quest, root)
function QuestCastDef:SpawnFn(fn)
    self.spawn_fn = fn
    return self
end

-- fn: assign_fn(quest, node)
function QuestCastDef:OnAssign(fn)
    self.assign_fn = fn
    return self
end

function QuestCastDef:OnUnassign(fn)
    self.unassign_fn = fn
    return self
end

function QuestCastDef:IsOptional()
    return self.is_optional
end

function QuestCastDef:SetOptional()
    self.is_optional = true
    return self
end

function QuestCastDef:SetImportant( is_important )
    self.is_important = is_important
    return self
end

function QuestCastDef:_MatchesFilters(quest, node, root)
	for _,filter in ipairs(self.filters or table.empty) do
		local ok, reason = filter(quest, node, root)
		if not ok then
			if reason then
				quest:Log(self.id, ":", tostring(node), "is invalid. Reason:", tostring(reason))
			end
			return false, reason
		end
	end
	return true
end

function QuestCastDef:DoCasting(quest, root)
    local clean_up_on_fail = false

    quest:Log("DoCasting for cast id:", self.id)
    local cast
    if self.cast_fn then
        local result, reason = self.cast_fn(quest, root)
        if result then
            cast = result
        else
            quest:Log(self.id, ": cast_fn failed. Reason:", tostring(reason))
        end

    elseif self.filters then
        local candidates = {}
        local best_score = nil
        root:TraverseDescendantsInclusive(function(node)
            local is_good = self:_MatchesFilters(quest, node, root)
            if is_good then
                local score = self.scoring_fn and self.scoring_fn(quest, node) or 1
                quest:Log(self.id, ":",  tostring(node), "score is", tostring(score))
                if not best_score or score >= best_score then
                    if best_score and score > best_score then
                        table.clear(candidates)
                    end
                    best_score = score
                    table.insert(candidates, node)
                end
            end
        end)

        if #candidates > 0 then
            cast = krandom.PickFromArray(candidates)
        else
            quest:Log(self.id, ": found no cast candidates under root", tostring(root))
        end
    end

    if cast == nil and self.spawn_fn then
        cast = self.spawn_fn(quest, root)
        quest:Log(self.id, ": spawned", tostring(cast))
        clean_up_on_fail = true
    end

    local Agent = require "questral.agent"
    if self.spawn_ship_fn and Agent.is_instance(cast) then
        if self.spawn_ship_fn( quest, cast, root ) == false then
            quest:Log(self.id, ": could not spawn ship" )
            cast = nil -- Failed ship spawn.
        end
    end

    return cast, clean_up_on_fail
end

return QuestCastDef