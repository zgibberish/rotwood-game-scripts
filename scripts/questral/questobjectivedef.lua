local RotwoodActor = require "questral.game.rotwoodactor"

local Enum = require "util.enum"
local iterator = require "util.iterator"
local lume = require "util.lume"
local kstring = require "util.kstring"
local kassert = require "util.kassert"
local loc = require "questral.util.loc"
local krandom = require "util.krandom"
local mapgen = require "defs.mapgen"


local QuestObjectiveDef = Class(function(self, ...) self:init(...) end)

function QuestObjectiveDef:init(quest_class, id)
    self.quest_class = quest_class
    self.id = id
    self.event_handlers = {}
    self.cast_event_handlers = {}
    self.scenario_event_handlers = {}
    self.variable_callbacks = {}

    self.unlock_player_flags_on_complete = {}
    self.lock_player_flags_on_complete = {}
    
    self.unlock_world_flags_on_complete = {}
    self.lock_world_flags_on_complete = {}

    self.marked_cast = {}

    self.importance = nil -- nil by default so the quest default importance can override
end

local function always_true()
    return true
end

function QuestObjectiveDef:OnActivate(fn)
    self.on_activate_fn = fn
    return self
end

function QuestObjectiveDef:OnEvent(event, fn)
    assert(self.event_handlers[event] == nil, "Duplicate event handler.")
    self.event_handlers[event] = fn
    return self
end

function QuestObjectiveDef:OnVar(var, fn)
    assert(self.variable_callbacks[var] == nil, "Duplicate variable callbacks")
    self.variable_callbacks[var] = fn
    return self
end

local function _RequestDungeonNPC(quest, cast_id, locations)
    local priority = quest:GetPriority()
    local prefab = quest:GetCastMember(cast_id).prefab
    TheDungeon.progression.components.meetingmanager:RequestDungeonNPC(prefab, priority, locations)
end

--character appears in the first room in the dungeon
function QuestObjectiveDef:AppearInDungeon_Entrance(fn, cast_id)
    cast_id = cast_id or "giver"

    self:OnEvent("evaluate_npc_spawns_dungeon", function(quest, prefab)
        if fn and not fn(quest, prefab) then return end
        _RequestDungeonNPC(quest, cast_id, { "entrance" })
    end)

    return self
end

--character appears in the dungeon room where you refill your potion (doc hoggins' room)
function QuestObjectiveDef:AppearInDungeon_Shop(fn, cast_id)
    cast_id = cast_id or "giver"

    self:OnEvent("evaluate_npc_spawns_dungeon", function(quest, prefab)
        if fn and not fn(quest, prefab) then return end
        _RequestDungeonNPC(quest, cast_id, { "potion", "powerupgrade" })
    end)

    return self
end

--character appears in the dungeon room where you upgrade powers (alki's room)
function QuestObjectiveDef:AppearInDungeon_Shop_Upgrade(fn, cast_id)
    cast_id = cast_id or "giver"

    self:OnEvent("evaluate_npc_spawns_dungeon", function(quest, prefab)
        if fn and not fn(quest, prefab) then return end
        _RequestDungeonNPC(quest, cast_id, { "powerupgrade" })
    end)

    return self
end

--character appears in the dungeon room where you buy potions (hoggins' room)
function QuestObjectiveDef:AppearInDungeon_Shop_Potion(fn, cast_id)
    cast_id = cast_id or "giver"

    self:OnEvent("evaluate_npc_spawns_dungeon", function(quest, prefab)
        if fn and not fn(quest, prefab) then return end
        _RequestDungeonNPC(quest, cast_id, { "potion" })
    end)

    return self
end

--character appears in the room before the boss
function QuestObjectiveDef:AppearInDungeon_Hype(fn, cast_id)
    cast_id = cast_id or "giver"

    self:OnEvent("evaluate_npc_spawns_dungeon", function(quest, prefab)
        if fn and not fn(quest, prefab) then return end
        _RequestDungeonNPC(quest, cast_id, { "hype" })
    end)

    return self
end

-- Appears in quest rooms that are included in normal map progression (not
-- forced: players can choose a different route).
function QuestObjectiveDef:AppearInDungeon_QuestRoom(fn, cast_id)
    fn = fn or always_true
    cast_id = cast_id or "giver"

    self:OnEvent("evaluate_npc_spawns_dungeon", function(quest, prefab)
        if not fn(quest, prefab) then return end
        _RequestDungeonNPC(quest, cast_id, { mapgen.roomtypes.RoomType.s.quest })
    end)

    return self
end

--character appears in the first room in the dungeon
-- the Exclusive means that this will not happen if the player has met a different NPC already this run.
function QuestObjectiveDef:AppearInDungeon_Entrance_Exclusive(fn, cast_id)
    cast_id = cast_id or "giver"

    self:OnEvent("evaluate_npc_spawns_dungeon", function(quest, prefab)
        if TheDungeon.progression.components.runmanager:HasMetNPC() then return end
        if fn and not fn(quest, prefab) then return end
        _RequestDungeonNPC(quest, cast_id, { "entrance" })
    end)

    return self
end

--character appears in the dungeon room where you refill your potion (doc hoggins' room)
-- the Exclusive means that this will not happen if the player has met a different NPC already this run.
function QuestObjectiveDef:AppearInDungeon_Shop_Exclusive(fn, cast_id)
    cast_id = cast_id or "giver"

    self:OnEvent("evaluate_npc_spawns_dungeon", function(quest, prefab)
        if TheDungeon.progression.components.runmanager:HasMetNPC() then return end
        if fn and not fn(quest, prefab) then return end
        _RequestDungeonNPC(quest, cast_id, { "potion", "powerupgrade" })
    end)

    return self
end

--character appears in the dungeon room where you upgrade powers (alki's room)
-- the Exclusive means that this will not happen if the player has met a different NPC already this run.
function QuestObjectiveDef:AppearInDungeon_Shop_Upgrade_Exclusive(fn, cast_id)
    cast_id = cast_id or "giver"

    self:OnEvent("evaluate_npc_spawns_dungeon", function(quest, prefab)
        if TheDungeon.progression.components.runmanager:HasMetNPC() then return end
        if fn and not fn(quest, prefab) then return end
        _RequestDungeonNPC(quest, cast_id, { "powerupgrade" })
    end)

    return self
end

--character appears in the dungeon room where you buy potions (hoggins' room)
-- the Exclusive means that this will not happen if the player has met a different NPC already this run.
function QuestObjectiveDef:AppearInDungeon_Shop_Potion_Exclusive(fn, cast_id)
    cast_id = cast_id or "giver"

    self:OnEvent("evaluate_npc_spawns_dungeon", function(quest, prefab)
        if TheDungeon.progression.components.runmanager:HasMetNPC() then return end
        if fn and not fn(quest, prefab) then return end
        _RequestDungeonNPC(quest, cast_id, { "potion" })
    end)

    return self
end

--character appears in the room before the boss
-- the Exclusive means that this will not happen if the player has met a different NPC already this run.
function QuestObjectiveDef:AppearInDungeon_Hype_Exclusive(fn, cast_id)
    cast_id = cast_id or "giver"

    self:OnEvent("evaluate_npc_spawns_dungeon", function(quest, prefab)
        if TheDungeon.progression.components.runmanager:HasMetNPC() then return end
        if fn and not fn(quest, prefab) then return end
        _RequestDungeonNPC(quest, cast_id, { "hype" })
    end)

    return self
end

-- Appears in quest rooms that are included in normal map progression (not
-- forced: players can choose a different route).
-- the Exclusive means that this will not happen if the player has met a different NPC already this run.
function QuestObjectiveDef:AppearInDungeon_QuestRoom_Exclusive(fn, cast_id)
    fn = fn or always_true
    cast_id = cast_id or "giver"

    self:OnEvent("evaluate_npc_spawns_dungeon", function(quest, prefab)
        if TheDungeon.progression.components.runmanager:HasMetNPC() then return end
        if not fn(quest, prefab) then return end
        _RequestDungeonNPC(quest, cast_id, { mapgen.roomtypes.RoomType.s.quest })
    end)

    return self
end

--character appears in town as a visitor (not a villager)
function QuestObjectiveDef:AppearInTown_Visitor(fn, cast_id)
    cast_id = cast_id or "giver"
    self:OnEvent("quest_start_town", function(quest, prefab)
        if fn and not fn(quest, prefab) then return end
        TheWorld.npcspawner:RequestNpc(quest:GetCastMember(cast_id), quest)
    end)
    return self
end

function QuestObjectiveDef:OnScenarioEvent(event, fn)
    assert(self.scenario_event_handlers[event] == nil, "Duplicate event handler.")
    self.scenario_event_handlers[event] = fn
    return self
end

function QuestObjectiveDef:OnCastEvent(cast, event, fn)
    self.cast_event_handlers[cast] = self.cast_event_handlers[cast] or {}
    assert(self.cast_event_handlers[cast][event] == nil, "Duplicate event handler.")
    self.cast_event_handlers[cast][event] = fn
    return self
end

function QuestObjectiveDef:LockRoom()
    --jambell: I'm making this so that writers have an easier time doing common things.
    --         However, this will break if they have a different thing added for "playerentered".
    --         In that case, they'll have to manually implement the function below in addition to the "playerentered" they wanted.

    self:OnEvent("playerentered", function(quest)
        local giver = quest:GetCastMember("giver")
        TheWorld:DoTaskInTicks(10, function()
            -- When this function is typically first called, giver's inst doesn't yet exist. Wait a few ticks.
            if giver and giver.inst then
                giver.inst:AddComponent("roomlock")
            end
        end)
    end)

    return self
end

--------
-- Flags that either lock or unlock when the objective is completed
--------

function QuestObjectiveDef:UnlockPlayerFlagsOnComplete(flags)
    self.unlock_player_flags_on_complete = flags
    return self
end

function QuestObjectiveDef:LockPlayerFlagsOnComplete(flags)
    self.lock_player_flags_on_complete = flags
    return self
end

function QuestObjectiveDef:UnlockWorldFlagsOnComplete(flags)
    self.unlock_world_flags_on_complete = flags
    return self
end

function QuestObjectiveDef:LockWorldFlagsOnComplete(flags)
    self.lock_world_flags_on_complete = flags
    return self
end

------

function QuestObjectiveDef:OnFinish(fn)
    self.on_finish_fn = fn
    return self
end

function QuestObjectiveDef:OnScenarioUpdate(fn)
    self.scenario_update_fn = fn
    return self
end

function QuestObjectiveDef:OnComplete(fn)
    if self.on_complete_fn then
        -- Could be redefined via UpdateObjective
        -- assert(nil, loc.format("duplicate oncomplete {1}:{2}", self.quest_class._classname, self.id))
    end
    self.on_complete_fn = fn
    return self
end

function QuestObjectiveDef:OnFail(fn)
    if self.on_fail_fn then
        assert(nil, loc.format("duplicate onfail {1}:{2}", self.quest_class._classname, self.id))
    end
    self.on_fail_fn = fn
    return self
end

function QuestObjectiveDef:AddStrings( t )
    self.quest_class:AddStrings( t )
    return self
end

function QuestObjectiveDef:LOC( id )
    return self.quest_class:LOC( id )
end

-- For adding to the player-visible quest log.
function QuestObjectiveDef:LogString(str)
    kassert.typeof("string", str)
    -- gln allowed input to be a function, but never used it. Require string instead.
    local id = "LOG_STRING_".. self.id
    self.quest_class:AddStrings{
        [id] = str
    }
    self.get_log_txt = function(quest) return quest:GetString( id ) end

    return self
end

function QuestObjectiveDef:MarkLocation(locations)
    self.marked_locations = locations
    return self
end

function QuestObjectiveDef:GetMarkedLocations()
    return self.marked_locations
end

function QuestObjectiveDef:SetIsImportant()
    self.importance = QUEST_IMPORTANCE.s.HIGH
    return self
end

function QuestObjectiveDef:SetIsUnimportant()
    self.importance = QUEST_IMPORTANCE.s.LOW
    return self
end

function QuestObjectiveDef:GetImportance()
    if self.importance then
        return self.importance
    else
        return self.quest_class:GetImportance()
    end
end

function QuestObjectiveDef:MakeExclusive()
    self.is_exclusive = true
    return self
end
function QuestObjectiveDef:InitialState( state )
    self.initial_state = state
    return self
end

function QuestObjectiveDef:SetRateLimited(bool)
    -- call this to overwrite the default state of the quest
    dbassert(bool ~= nil)
    self.rate_limited = bool
    return self
end

function QuestObjectiveDef:IsRateLimited()
    if self.rate_limited ~= nil then
        return self.rate_limited
    else
        return self.quest_class:IsRateLimited()
    end
end

function QuestObjectiveDef:SetChatCost(num)
    -- call this to overwrite default cost of quest
    dbassert(num ~= nil and num <= TOWN_CHAT_BUDGET) -- if num is greater the chat can never happen
    self.chat_cost = num
    return self
end

function QuestObjectiveDef:GetChatCost()
    if self.chat_cost ~= nil then
        return self.chat_cost
    else
        return self.quest_class:GetChatCost()
    end
end

function QuestObjectiveDef:NetworkSyncStates(states)
    dbassert(states ~= nil)

    self.network_sync = {}

    for _, state in ipairs(states) do
        self.network_sync[state] = true
    end

    return self
end

function QuestObjectiveDef:ShouldNetworkSync(state)
    if self.network_sync ~= nil then
        return self.network_sync[state]
    else
        return self.quest_class:ShouldNetworkSync(state)
    end
end

function QuestObjectiveDef:LocalSyncStates(states)
    dbassert(states ~= nil)
    self.local_sync = {}

    for _, state in ipairs(states) do
        self.local_sync[state] = true
    end
    return self
end

function QuestObjectiveDef:ShouldLocalSync(state)
    if self.local_sync ~= nil then
        return self.local_sync[state]
    else
        return self.quest_class:ShouldLocalSync(state)
    end
end

function QuestObjectiveDef:SetPriority(val)
    self.priority = val
    return self
end

function QuestObjectiveDef:GetPriority()
    if self.priority ~= nil then
        return self.priority
    else
        return self.quest_class:GetPriority()
    end
end

function QuestObjectiveDef:Mark(tbl)
    self.marked_cast = tbl
    return self
end

function QuestObjectiveDef:GetMarkedCast()
    return self.marked_cast
end

return QuestObjectiveDef
