local qconstants = require "questral.questralconstants"
local GameNode = require "questral.gamenode"
local ScenarioTrigger = require "questral.scenariotrigger"
local ContentNode = require "questral.contentnode"
local TagSet = require "questral.util.tagset"
local contentutil = require "questral.util.contentutil"

local Enum = require "util.enum"
local iterator = require "util.iterator"
local lume = require "util.lume"
local kstring = require "util.kstring"
local kassert = require "util.kassert"
local loc = require "questral.util.loc"
local krandom = require "util.krandom"
local mapgen = require "defs.mapgen"
local playerutil = require"util.playerutil"

-- Game-specific modules
local RotwoodActor = require "questral.game.rotwoodactor"
local RotwoodLocation = require "questral.game.rotwoodlocation"

local QuestObjectiveDef = require "questral.questobjectivedef"
local QuestCastDef = require "questral.questcastdef"

-----------------------------------------------------------------------------

-- Each in-game quest is a subclass of Quest. They live in ContentDB and when
-- they are ready to be used are explicitly spawned (instanced). Quests should
-- spawn other quests to keep the quest lines going. Additionally, we could
-- have types of quests that can be be queried from ContentDB and randomly
-- spawned.
--
-- Only quests that can be active are instanced, but an instanced quest may be
-- invisible to the user until they do something that triggers its objectives.
--
-- Quests have some weird calling conventions where sometimes we use : to call
-- class methods. These should all be guarded with asserts.

local Quest = Class(GameNode, function(self, ...) self:init(...) end)
Quest:add_mixin( ContentNode )
Quest:SetContentKey("Quest")
Quest._classname = "Quest"

Quest.DebugNodeName = "DebugQuest"
Quest.CanUseDebugNodeOnClass = true

Quest.QUEST_TYPE = Enum{
    "MAIN",
    "CHAT",
    "JOB",
    "TRIAL",
    "STORY",
    "DISABLED",
    "CONTRACT",
}

Quest.MAX_RANK = 5

-- Hooks are categorized based on *how* we present the interaction to the
-- player.
Quest.CONVO_HOOK = Enum{
	"ATTRACT",
	"CONFRONT",
	"HUB",
	"CHAT_DUNGEON",
	"CHAT_TOWN",
    "CHAT_TOWN_SHOP",
}

-- For debug display.
function Quest.GetStatusColour( state )
    if state == QUEST_OBJECTIVE_STATE.s.ACTIVE then
        return WEBCOLORS.LIME
    elseif state == QUEST_OBJECTIVE_STATE.s.INACTIVE then
        return WEBCOLORS.DARKGRAY
    elseif state == QUEST_OBJECTIVE_STATE.s.COMPLETED then
        return WEBCOLORS.FORESTGREEN
    elseif state == QUEST_OBJECTIVE_STATE.s.FAILED then
        return WEBCOLORS.DARKRED
    else
        return WEBCOLORS.WHITE
    end
end

function Quest.Create( quest_type, classname )
    assert(Quest.QUEST_TYPE:Contains(quest_type), quest_type)
    classname = (classname or debug.getinfo(2, "S").source:match("^.*/(.*).lua$")):lower()
    local class = Class(Quest, function(self, ...)
        self:init(...)
    end)
    class._classname = classname
    class._class = class

    class.def = {
        quest_type = quest_type,
        cast = {},
        cast_order = {},
        cast_candidates = {}, -- Used by repeatable quests
        objective = {},
        convo_hooks = {},
        formatters = {},
        event_handlers = {},
        scenario_event_handlers = {},
        tags = TagSet(),
        opinion_events = {},
        scenario_triggers_by_id = {},
        scenario_triggers = {},
        variables = {},
        min_rank = 1,
        max_rank = Quest.MAX_RANK,
        network_sync = {}, -- by default, no state changes are synced.
        local_sync = {}, -- by default, no state changes are synced.
        rate_limited = true,
        chat_cost = DEFAULT_CHAT_COST,

        unlock_player_flags_on_complete = {},
        lock_player_flags_on_complete = {},

        unlock_world_flags_on_complete = {},
        lock_world_flags_on_complete = {},

        marked_locations = {},
        importance = QUEST_IMPORTANCE.s.DEFAULT,
    }
    class.def.tags:Add( classname )
    return class
end

-- some of the fields in the def table need to copied with care, because they are tables of tables
--[[
function Quest.InheritFrom( quest_name, base_quest_class )
    local class = Class(quest_name, base_quest_class)

    class.def = {
        quest_type = base_quest_class.def.quest_type,
        cast = shallowcopy(base_quest_class.def.cast),
        cast_order = shallowcopy(base_quest_class.def.cast_order),
        cast_candidates = shallowcopy(base_quest_class.def.cast_candidates),
        objective = shallowcopy(base_quest_class.def.objective),
        convo_hooks = {},
        formatters = shallowcopy(base_quest_class.def.formatters),
        event_handlers = {},
        scenario_event_handlers = {},
        tags = base_quest_class.def.tags:Clone(),
        opinion_events = shallowcopy(base_quest_class.def.opinion_events),
        scenario_triggers_by_id = {},
        scenario_triggers = shallowcopy(base_quest_class.def.scenario_triggers),
        min_rank = base_quest_class.def.min_rank,
        max_rank = base_quest_class.def.max_rank,
    }

    for hook, convos in pairs(base_quest_class.def.convo_hooks) do
        class.def.convo_hooks[hook] = shallowcopy(convos)
    end

    for event, handlers in pairs(base_quest_class.def.scenario_event_handlers) do
        class.def.scenario_event_handlers[event] = shallowcopy(handlers)
    end

    for event, handlers in pairs(base_quest_class.def.event_handlers) do
        class.def.event_handlers[event] = shallowcopy(handlers)
    end

    for id, handlers in pairs(base_quest_class.def.scenario_triggers_by_id) do
        class.def.scenario_triggers_by_id[id] = shallowcopy(handlers)
    end

    class.def.tags:Add( quest_name )
    return class
end
--]]

function Quest:MarkAsDebug()
    assert(not self:is_class(), "Call only on an instance")
    self.quest_created_from_debug = true
    if self.Quest_DebugSpawned then
        self:Quest_DebugSpawned()
    end
    return self
end

function Quest:SetIsTemporary(bool)
    self.forbid_serialize = bool
end

function Quest:CanSerialize()
    return not self.forbid_serialize
end

function Quest:WasLoadedFromSave()
    return self.was_loaded
end

function Quest:ValidateDef()
    if self == Quest then
        return true
    end

    assert(self:is_class())
    local def = self.def
    assert( def, self._classname )

    -- Validate that all hooks specify valid cast_id and objective_ids.
    for hook, hook_tables in pairs( def.convo_hooks ) do
        for i, hook_table in ipairs( hook_tables ) do
            if hook_table.cast_id then
                assert( def.cast[ hook_table.cast_id ] ~= nil, string.format( "%s has invalid cast_id '%s' specified for hook %s", self._classname, hook_table.cast_id, hook ))
            end
            if hook_table.objective_id then
                assert( def.objective[ hook_table.objective_id ] ~= nil, string.format( "%s has invalid objective_id '%s' specified for hook %s", self._classname, hook_table.objective_id, hook ))
            end
        end
    end

    return true
end

-- Never complete or save state.
-- TODO(dbriscoe): Instead of being recurring, I think we should spawn these
-- when we want to use them. Potionmaster can spawn their potion quest and it
-- doesn't save any data at all (not even completion). That reduces the amount
-- of ongoing quests to ones that are actually relevant.
function Quest.CreateRecurringChat()
    local Q = Quest.Create(Quest.QUEST_TYPE.s.CHAT, contentutil.BuildClassNameFromCallingFile())
    Q:AddCast("giver")
    -- Don't persist state so it can fire next time. We still persist quest
    -- existence so it doesn't need to be respawned.
    Q.skip_state_persist = true
    return Q
end

-- The main story path. Can only ever have a single 'main' quest at a time. Can always be progressed.
function Quest.CreateMainQuest()
    local Q = Quest.Create(Quest.QUEST_TYPE.s.MAIN, contentutil.BuildClassNameFromCallingFile())
    Q:AddCast("giver")
    return Q
end

-- Side quests that only happen once. Limited to progressing X number of objectives per visit to town.
-- Organized by priority. A high priority quest or objective will be progressable sooner than one with lower priority
function Quest.CreateJob()
    local Q = Quest.Create(Quest.QUEST_TYPE.s.JOB, contentutil.BuildClassNameFromCallingFile())
    Q:AddCast("giver")
    return Q
end

local function IsValidVarType(val)
    return type(val) == "number"
        or type(val) == "string"
        or type(val) == "boolean"
end

-- Vars serialize, but can only be basic types. They're stored as params so
-- they also work in quest strings.
function Quest:AddVar(id, start_val)
    assert(self:is_class(), "Don't call this on an instance")
    assert(self._class.def.variables[id] == nil, "Duplicate variable id")
    dbassert(id:is_lower(), "variable ids must be lower case.")
    assert(IsValidVarType(start_val), start_val)

    self._class.def.variables[id] = start_val
    return self._class.def.variables[id]
end

-- These params can be used in quest strings:
-- q:SetParam("height", 10)
-- q:SetParam("person", GetScout())
-- ...
-- :Strings{
--   BLAH = "{person} is {height} m tall.",
-- }
-- Good for constants or complex tables.
function Quest:SetParam(var, start_val)
    assert(self.is_param_init or self._class.def.variables[var] == nil, "Use AddVar and SetVar to modify vars.")
    self.param[var] = start_val
end

-- Works for getting params or vars.
function Quest:GetVar(var)
    return self.param[var]
end

function Quest:IncrementVar(var, delta)
    kassert.assert_fmt(self._class.def.variables[var], "Input id is not a counter: %s", var)
    local val = self:GetVar(var)
    kassert.typeof("number", val)
    delta = delta or 1
    return self:SetVar(var, val + delta)
end

function Quest:SetVar(var, val)
    if self.param[var] ~= val then
        self.param[var] = val
        for id, def in pairs(self.def.objective) do
            if def.variable_callbacks[var] ~= nil then
                def.variable_callbacks[var](self, val)
            end
        end
    end
    return val
end

function Quest:Debug_GetDebugName()
    return self:GetContentID()
end

function Quest:GetRankRange()
    return self.def.min_rank, self.def.max_rank
end

function Quest:GetRank()
    return self.rank
end

function Quest:GetType()
    return self.def and self.def.quest_type
end

function Quest:AddTags(tags)
    assert(self:is_class(), "Don't call this on an instance")
    for k,v in ipairs(tags) do
        self.def.tags:AddTag(v)
    end
    return self
end

function Quest:SetCastCandidates(candidates)
    self.def.cast_candidates = candidates
end

function Quest:GetTags()
    return self.def.tags
end

function Quest:HasTag(tag)
    return self.def.tags:has(tag)
end

--name of a quest
function Quest:TitleString(str)
    assert(self:is_class(), "Don't call this on an instance")
    self:AddStrings{TITLE = str}
    return self
end

--quick recap description of what the player's objective is
function Quest:DescString(str)
    assert(self:is_class(), "Don't call this on an instance")
    self:AddStrings{DESC = str}
    return self
end

function Quest:Icon(path)
    assert(self:is_class(), "Don't call this on an instance")
    self:PreloadTexture("ICON", path)
    return self
end

function Quest:RankRange( min_rank, max_rank )
    assert( min_rank >= 1 )
    assert( max_rank <= Quest.MAX_RANK )
    self._class.def.min_rank = min_rank
    self._class.def.max_rank = max_rank
    return self
end

-- *Define* Quest_* functions with your behaviour. Don't call them! The awkward
-- underscore is the pattern for functions defined in quest definitions instead
-- of in Quest (gln uses OnStart, OnFinish, ... which makes it easy to confuse
-- when to call and when to define).
--
-- function Q:Quest_DebugSpawned() end
-- function Q:Quest_Start() end
-- function Q:Quest_Finish() end
-- function Q:Quest_Cancel() end
-- function Q:Quest_Fail() end
-- function Q:Quest_Complete() end
-- function Q:Quest_Validate() return true end -- optional function, return false if the quest should be auto-canceled

-- Don't call Quest_SetupCastMember from quest definitions. Define it with
-- initialization behaviour that depends on a cast member.
-- function Quest:Quest_SetupCastMember(node, cast_id) end

function Quest:OnEvent(event, fn)
    assert(self:is_class(), "Don't call this on an instance")
    assert(self._class.def.event_handlers[event] == nil, "Duplicate event handler.")
    self._class.def.event_handlers[event] = fn
    return self
end

function Quest:AddOpinionEvent(args)
    assert(self:is_class(), "Don't call this on an instance")
    assert(args.id, "No id for opinion event.")
    local OpinionEvent = require "sim.opinionevent"
    local ev = OpinionEvent.Create(args)
    self._class.def.opinion_events[ ev:GetContentID() ] = ev
    return self
end

function Quest:OnScenarioEvent(event, fn)
    assert(self:is_class(), "Don't call this on an instance")
    assert(self._class.def.scenario_event_handlers[event] == nil, "Duplicate event handler.")
    self._class.def.scenario_event_handlers[event] = fn
    return self
end

function Quest:TriggerChange()
    self:GetQuestManager():OnQuestChanged(self)
end


-- This is *not* enough to know whether a specific npc can be in a quest, but
-- is a good high-level filter. Especially for debug.
function Quest:MatchesCastFilters(cast_id, cast_node, root)
    assert(not self:is_class(), "Call only on an instance")
    local cast_def = self.def.cast[cast_id]
    assert(cast_def, "Input id is an unknown cast member. Did you call Quest:AddCast?")
    return cast_def:_MatchesFilters(self, cast_node, root or self:GetRoot())
end

function Quest:FillCast(id, root)
    assert(root, "Why aren't you passing a root? This quest probably hasn't been added to the hierarchy yet.")

    local cast_def = self.def.cast[id]
    assert(cast_def, "Input id is an unknown cast member. Did you call Quest:AddCast?")
    local cast = self:GetCastMember(id)
    if cast then
        return cast
    else
        local new_member, clean_up_on_fail = cast_def:DoCasting(self, root or self:GetRoot())
        if new_member then
            if not new_member:IsActivated() then
                self:Log("Attempting to cast non-activated node:", id, tostring(new_member))
                new_member = nil
            else
                self:Log("Cast member:", id, tostring(new_member))
                self:AssignCastMember(id, new_member)
            end
        end
        return new_member, clean_up_on_fail
    end
end

function Quest:CanDistributeAgent( cast_member )
    for cast_id, node in pairs(self.cast_members) do
        if node == cast_member and cast_id ~= "giver" then
            return false
        end
    end
    return true
end

function Quest.SpawnQuestByName(classname, root, rank, params, cast_assignments)
    local quest_class = contentutil.GetContentDB():Get(Quest, classname)
    if not quest_class then
        error(string.format("Invalid quest class: '%s'", classname))
        return nil
    end
    return Quest.SpawnQuestFromClass(quest_class, root, rank, params, cast_assignments)
end

function Quest:SpawnQuestFromClass(root, rank, params, cast_assignments)
    assert(self:is_class(), "Don't call this on an instance")
    local quest = self(params, rank)

    quest:Log("Attempt to spawn quest", self._classname)

    local failed = false
    local to_clean = {}

    if cast_assignments then
        for id in pairs(cast_assignments) do
            if not quest.def.cast[id] then
                assert(nil, loc.format( "Trying to override non-existant cast member {1} in quest {2}", id, self._classname))
            end
        end
    end

    for id, cast_def in pairs(quest.def.cast) do
        if cast_def.is_required_at_spawn_time and (not cast_assignments or not cast_assignments[cast_def.id]) then
            quest:Log("Quest missing required cast assignment:", id)
            failed = true
        end
    end

    if rank < quest.def.min_rank then
        quest:Log( string.format( "Rank %d too low for this quest (%d-%d)", rank, quest.def.min_rank, quest.def.max_rank ))
        failed = true
    elseif rank > quest.def.max_rank then
        quest:Log( string.format( "Rank %d too high for this quest (%d-%d)", rank, quest.def.min_rank, quest.def.max_rank ))
        failed = true
    end

    for i, cast_def in pairs(quest.def.cast_order) do
        local id = cast_def.id
        local node = cast_assignments and cast_assignments[id]
        if failed then
            break
        elseif node then
            local ok, reason = true
            if type(cast_def.is_required_at_spawn_time) == "function" then
                -- is_required_at_spawn_time is a validator function.
                ok, reason = cast_def.is_required_at_spawn_time(quest, cast_assignments[id])
            end

            if ok then
                quest:AssignCastMember(id, cast_assignments[id])
            else
                quest:Log("Supplied cast failed validation: ", tostring(reason), id, tostring(cast_assignments[id]))
                failed = true
            end
        else
            if not cast_def.is_deferred then
                local new_member, clean_up_on_fail = quest:FillCast(id, root)
                if not new_member then
                    if cast_def:IsOptional() then
                        quest:Log("Did not cast optional member:", id)
                    else
                        quest:Log("Could not cast non-optional member:", id)
                        failed = true
                        break
                    end
                else
                    if clean_up_on_fail then
                        table.insert( to_clean, new_member )
                    end
                end

            end
        end
    end

    if not failed and quest.PreSpawn then
        local ok, reason = quest:PreSpawn(root, params or table.empty)
        if not ok then
            quest:Log("Failed PreSpawn:", tostring(reason))
            failed = true
        end
    end

    if failed then
        for k,v in ipairs(to_clean) do
            v:Detach()
        end
        for id, cast in pairs( quest.cast_members ) do
            cast:RemoveFromQuest( quest )
        end
        return nil, quest
    end

    return quest
end

function Quest:init(param, rank)
    self.param = param and shallowcopy(param) or {}
    self.rank = rank or 1
    self.log = {}
    self.cast_members = {} -- Dictionary of [cast_id -> QuestralActor]
    self.objective_state = {}

    self.marked_entities = {}
    self.marked_locations = {}

    self.is_param_init = true
    for id, val in pairs(self.def.variables) do
        self:SetParam(id, val)
    end
    self.is_param_init = nil

    for id,def in pairs(self.def.objective) do
        self.objective_state[id] = QUEST_OBJECTIVE_STATE.s.INACTIVE
    end

    self.state = QUEST_OBJECTIVE_STATE.s.INACTIVE
end

function Quest:GetStatus()
    return self.state
end

function Quest:OnActivate( root )
    dbassert(not self.inst)

    self.sim = self:GetQC()
    self.inst = CreateEntity(self:GetContentID())

    self.state = QUEST_OBJECTIVE_STATE.s.ACTIVE
    self.activate_time = self.sim:GetCyclesPassed()

    local listening = {}
    for id, cast_member in pairs(self.cast_members) do
        if not listening[cast_member] then
            local cast_def = self.def.cast[id]
            self:_RegisterCastMember(cast_member, cast_def)
            listening[cast_member] = true
        end
    end

    -- Collect all events and listen in HandleEvent instead of creating a
    -- closure for each event. Hopefully, calling HandleEvent instead of
    -- registering handlers directly allows hot reloading event handlers.
    -- TODO(dbriscoe): Does hot reload work?
    local all_events = lume(self.def.event_handlers)
        :keys()
        :invert()
        :result()
    for id, dat in pairs(self.def.objective) do
        if dat.event_handlers then
            for event, handler in pairs(dat.event_handlers) do
                all_events[event] = true
            end
        end
    end
    for event in pairs(all_events) do
        local fn = function(event_entity, data)
            self:HandleEvent(event, data)
        end

        local event_entities = self:GetQC():GetEventEntities()
        for _, ent in ipairs(event_entities) do
            self.inst:ListenForEvent(event, fn, ent)
        end
    end

    if not self.was_loaded or self.skip_state_persist then
        for id, def in pairs( self.def.objective ) do
            if def.initial_state then
                self:SetObjectiveState( id, def.initial_state )
            end
        end
    end
	-- else: we should have already loaded objective state before activating.

	-- First user-defineable call into a quest. Should have all roles filled,
	-- but they may still be reservations.
    -- Check self:WasLoadedFromSave() before spawning quests or other saved state!
    if self.Quest_Start then
        self:Quest_Start()
    end
end

function Quest:OnDeactivate( root )
    if self:GetQuestManager():GetMainQuest() == self then
        self:GetQuestManager():SetMainQuest(nil)
    end

    -- ASSUMPTION: Detaching a quest means it ended (not just the player
    -- dropped).
    local count = lume.count(self.objective_state)
    repeat
        local found_active = false
        for id, state in pairs( self.objective_state ) do
            if state == QUEST_OBJECTIVE_STATE.s.ACTIVE then
                self:SetObjectiveState( id, self.state )

                found_active = true
                count = count - 1
                assert(count >= -1, "Set an objective more than once per objective. Infinite loop where we're setting to active?")
            end
        end
    until not found_active

    if self.Quest_Finish then
        self:Quest_Finish()
    end

    self:_CleanupQuest()
end

function Quest:OnTeardown(root)
    self:_CleanupQuest()
end

function Quest:_CleanupQuest()
    for id, cast_member in pairs(self.cast_members) do
        cast_member:RemoveFromQuest( self )
        self:_RemoveListenersOnCast(cast_member)
    end

    self.inst:Remove()
    self.inst = nil
end

function Quest:DoPopulateScenario( scenario )
    -- Check current_scenario so we do not double-Populate for quests added during Scenario creation (from Quest:OnActivate and then QuestManager:OnScenarioStart)
    if self.current_scenario == nil then
        self.current_scenario = scenario
        self:ResetScenarioState()
        if self.Quest_PopulateScenario then
            self:Quest_PopulateScenario( scenario )
        end
    end
end

function Quest:DoDepopulateScenario( scenario )
    if self.current_scenario == scenario then
        if self.Quest_DepopulateScenario then
            self:Quest_DepopulateScenario( scenario )
        end
        self:ResetScenarioState()
        self.current_scenario = nil
    end

    self:_ClearTasks()
end

-- Debug logging.
-- Each quest collects its own log messages for easier debugging.
function Quest:Log(...)
    table.insert(self.log, table.concat({...}, " "))
end

function Quest:GetLogText(txt)
    return table.concat(self.log, "\n")
end

function Quest:OnSave()
    local data = { verbatim = {}, }
    data.verbatim.activate_time = self.activate_time
    data.verbatim.rank = self.rank
    data.verbatim.quest_created_from_debug = self.quest_created_from_debug
    if not self.skip_state_persist then
        data.verbatim.objective_state = self.objective_state
        data.verbatim.state = self.state
    end

    data.classname = self._classname
    data.cast_member_prefabs = lume.map(self.cast_members, 'prefab')
    data.vars = {}
    for key,val in pairs(self._class.def.variables) do
        kassert.assert_fmt(IsValidVarType(self.param[key]), "Invalid Var type in quest '%s'. Modified self.param directly?", self._classname)
        data.vars[key] = self.param[key]
    end
    return data
end

-- TODO(dbriscoe): Not sure how this works on gln
function Quest:__deserialize()
    self.def = contentutil.GetContentDB():Get(Quest, self._classname).def
    self.log = {}
    for id, dat in pairs(self.def.objective) do
        if self.objective_state[ id ] == nil then
            self.objective_state[ id ] = QUEST_OBJECTIVE_STATE.s.INACTIVE
        end
    end
    -- Cleanup objective states that may no longer exist.
    for id, state in pairs( self.objective_state ) do
        if self.def.objective[ id ] == nil then
            TheLog.ch.Quest:print("WARNING: Removing defunct objective", self._classname, id)
            self.objective_state[ id ] = nil
        end
    end
end

function Quest:LoadFromSaveData(data)
    self.was_loaded = true
    for key,val in pairs(data.verbatim) do
        self[key] = val
    end
    for key,default_val in pairs(self._class.def.variables) do
        local val = data.vars[key]
        if val == nil then
            val = default_val
        end
        kassert.equal(type(default_val), type(val))
        self.param[key] = val
    end
    self:__deserialize()
    return self
end

function Quest:HandleEvent(event, ...)
    if self.def.event_handlers[event] then
        self.def.event_handlers[event](self, ...)
    end

    for id, dat in pairs(self.def.objective) do
        if self:GetObjectiveState(id) == QUEST_OBJECTIVE_STATE.s.ACTIVE then
            if dat.event_handlers[event] then
                dat.event_handlers[event](self, ...)
            end
        end
    end
end

function Quest:HandleScenarioEvent(event, scenario, ...)
    if self.def.scenario_event_handlers[event] then
        self.def.scenario_event_handlers[event](self, scenario, ...)
    end

    for id, dat in pairs(self.def.objective) do
        if self:GetObjectiveState(id) == QUEST_OBJECTIVE_STATE.s.ACTIVE then
            if dat.scenario_event_handlers[event] then
                dat.scenario_event_handlers[event](self, ...)
            end
        end
    end
end

--add a character to the list of available speakers/targets for a quest
function Quest:AddCast(id)
    assert(self:is_class(), "Don't call this on an instance")
    assert( self.def.cast[id] == nil, "Duplicate cast id")
    local cast_def = QuestCastDef(self, id)
    self.def.cast[id] = cast_def
    table.insert( self.def.cast_order, cast_def )
    return cast_def
end

function Quest:UpdateCast(id)
    assert(self:is_class(), "Don't call this on an instance")
    local cast_def = self.def.cast[id]
    assert( cast_def, "Undefined override for cast id: "..id)
    -- Reorder this cast def.
    table.removearrayvalue( self.def.cast_order, cast_def )
    table.insert( self.def.cast_order, cast_def )
    return cast_def
end

function Quest:AddFormatter(id, fn)
    self._class.def.formatters[id] = fn
    return self
end

function Quest:GetPlayer()
    -- self.parent:GetQC() is used to ensure we avoid infinite recursion if self.parent == nil.
    return self.parent:GetQC():GetPlayer()
end

function Quest:GetCastMember(id)
    if id == "player" then
        return self:GetPlayer()

    end
    return self.cast_members[id]
end

function Quest:GetCastMemberPrefab(id)
    local cast = self:GetCastMember(id)
    return cast and cast.prefab
end

function Quest:FindCastID( node )
    return table.find( self.cast_members, node )
end

function Quest:IsCastImportant( node )
    local id = table.find( self.cast_members, node )
    return self.def.cast[ id ].is_important == true
end

function Quest:GetCastMembers()
    return self.cast_members
end

-- Any game-specific hooks here.
-- TODO(dbriscoe): Move to QuestCentral?
local function IsValidRotwoodHook(hook, quest, node, sim)
	if hook == Quest.CONVO_HOOK.s.CHAT_DUNGEON then
		if TheWorld:HasTag("town") then
			quest:Log("  EvaluateHook [location]: incorrect location for chat - town")
			return false
		end
	elseif hook == Quest.CONVO_HOOK.s.CHAT_TOWN then
		if not TheWorld:HasTag("town") then
			quest:Log("  EvaluateHook [location]: incorrect location for chat - not town")
			return false
		end
	end
	return true
end

-- Returns a Convo.
function Quest:AddHook(hook, objective_id, cast_id, filter_fn)
    assert(self:is_class(), "Don't call this on an instance")
    dbassert(Quest.CONVO_HOOK:Contains(hook))
    dbassert(objective_id:is_lower(), "Objective ids must be lower case.")
    local convo_id = string.format( "%s%d.%s.%s", hook, table.count( self:GetConvos() ), objective_id, cast_id )
    local state = self:AddConvo(convo_id, nil, objective_id)

    -- Whether it's valid to start this hook.
    local fn = function(quest, node, sim)
		if not IsValidRotwoodHook(hook, quest, node, sim) then
			return false
		end


        if objective_id then
            if not quest:IsActive(objective_id) then
                quest:Log("  EvaluateHook [objective]: objective not active:", objective_id)
                return false
            end
        end

        if cast_id then
            local qnode = quest:GetCastMember(cast_id)
            if qnode ~= node then
                quest:Log("  EvaluateHook [cast]: cast member doesn't match on", objective_id, cast_id, tostring(qnode), tostring(node))
                return false
            end
        end

        if filter_fn then
            if not filter_fn(quest, node, sim, objective_id) then
                quest:Log("  EvaluateHook [fail]: filter_fn failed on", objective_id)
                return false
            end
        end

        local flags = state:GetConvo().required_world_flags
        if flags then
            for _, flag in ipairs(flags) do
                if not TheWorld:IsFlagUnlocked(flag) then
                    quest:Log("  EvaluateHook [flags]: didn't have required world flag:", flag)
                    return false
                end
            end
        end

        flags = state:GetConvo().forbidden_world_flags
        if flags then
            for _, flag in ipairs(flags) do
                if TheWorld:IsFlagUnlocked(flag) then
                    quest:Log("  EvaluateHook [flags]: has forbidden world flag:", flag)
                    return false
                end
            end
        end

        flags = state:GetConvo().required_player_flags
        if flags then
            for _, flag in ipairs(flags) do
                if not quest:GetPlayer():IsFlagUnlocked(flag) then
                    quest:Log("  EvaluateHook [flags]: didn't have required player flag:", flag)
                    return false
                end
            end
        end

        flags = state:GetConvo().forbidden_player_flags
        if flags then
            for _, flag in ipairs(flags) do
                if quest:GetPlayer():IsFlagUnlocked(flag) then
                    quest:Log("  EvaluateHook [flags]: has forbidden player flag:", flag)
                    return false
                end
            end
        end

        if TheWorld:HasTag("town") and sim:GetTownQuests() ~= nil then
            -- You're in town and we've already selected which town chats should be valid this visit.
            -- Make sure you're in the list if you are a rate-limited quest.
            local objective = quest.def.objective[objective_id]

            -- if this objective isn't rate limited then it ignores the selected quests.
            if objective:IsRateLimited() then
                local town_quests = sim:GetTownQuests()

                if town_quests[quest] == nil then
                    quest:Log("  EvaluateHook [rate limit]: quest/ objective is rate limited:", quest._classname, objective_id)
                    return false
                end

                -- Is this the same convo we determined was valid before?

                -- This is a check for a specific hook if we need to get this specific.
                -- If we start having multiple convos per objective, we may need to switch back to this.
                -- I changed it look at objective_id instead for simplicity sake & to make other systems easier
                -- town_quests[quest].hook.state ~= state.convo:GetDefaultState()

                -- If we need to compare exact NPC too, we can add this check
                -- or town_quests[quest].cast ~= node
                if not lume.find(town_quests[quest], objective_id) then
                    quest:Log("  EvaluateHook [rate limit]: quest/ objective is rate limited:", quest._classname, objective_id)
                    return false
                end
            end
        end

        return true
    end

    self.def.convo_hooks[hook] = self.def.convo_hooks[hook] or {}
    local hook_table = self.def.convo_hooks[hook]

    table.insert(hook_table, {cast_id = cast_id, objective_id = objective_id, state = state, fn = fn })
    return state
end

function Quest:Debug_MakeConvoPicker(ui, colorscheme)
    ui:PushID(self._classname)

    for hook,hook_table in iterator.sorted_pairs(self.def.convo_hooks) do
        ui:TextColored(colorscheme.header, hook)
        for i,t in ipairs(hook_table) do
            if ui:Button(("Convo obj[%s] cast[%s]##%i"):format(t.objective_id, t.cast_id, i)) then
                ui:PopID()
                return t
            end
        end
    end

    ui:PopID()
end

-- TODO(dbriscoe): Move these to a game-specific location?
Quest.Filters = {}
function Quest.Filters.RequireMainPlayer(quest, node, sim)
    -- TODO(dbriscoe): Actual implementation
    return node == ThePlayer
end

function Quest.Filters.InDungeon_Entrance(quest, node, sim)
    return TheWorld:IsCurrentRoomType("entrance")
end

function Quest.Filters.InDungeon_Hype(quest, node, sim)
    return TheWorld:IsCurrentRoomType("hype")
end

function Quest.Filters.InDungeon_QuestRoom(quest, node, sim)
    return TheWorld:IsCurrentRoomType("quest")
end

function Quest.Filters.InDungeon_Insert(quest, node, sim)
    return TheWorld:IsCurrentRoomType("insert")
end

function Quest.Filters.InDungeon_Shop(quest, node, sim)
    return TheWorld:IsCurrentRoomType("potion") or TheWorld:IsCurrentRoomType("powerupgrade")
end

function Quest.Filters.InTown(quest, node, sim)
    return TheWorld:HasTag("town")
end

function Quest.Filters.CanCraft(quest, node, sim, slots, include_unlocks)
    local Equipment = require"defs.equipment"
    local recipes = require"defs.recipes"
    local playerutil = require"util.playerutil"
    local qplayer = node:GetInteractingPlayerEntity()

    slots = slots or { Equipment.Slots.WEAPON, Equipment.Slots.HEAD, Equipment.Slots.BODY }

    local shop_recipes = recipes.FindRecipesForSlots(slots)

    for slot, allrecipes in pairs(shop_recipes) do
        shop_recipes[slot] = recipes.FilterRecipesByCraftable(allrecipes, qplayer)
    end

    local can_craft_any = false
    for slot, slot_recipes in pairs(shop_recipes) do
        if #slot_recipes > 0 then
            can_craft_any = true
            break
        end
    end

    can_craft_any = can_craft_any or playerutil.CanUpgradeAnyHeldEquipment(qplayer, slots)

    if include_unlocks then
        can_craft_any = can_craft_any or playerutil.CanUnlockNewRecipes(qplayer, slots)
    end

    return Quest.Filters.InTown(quest, node, sim) and can_craft_any
end

-- Quest String skinning operates on unqualified string ID, so string IDs from different convos/states
-- are collapsed together. Purposefully not handling this for convenience!
--
-- It's easy to simply use unique string IDs, but
-- quite a pain (sometimes impossible: see Quest:AddHook) to fully qualify all strings by a <convo, state, string_id> tuple.

function Quest:SkinString( id, txt )
    assert(self:is_class())
    self:AddString( id, txt )
end

-- Confront: the npc will approach the player and initiate conversation. Spawn
-- npc if necessary, but location must match.
-- Returns a Convo.
function Quest:OnConfront(...)
    return self:AddHook(Quest.CONVO_HOOK.s.CONFRONT, ...)
end

-- Attract: if the npc is around, this is a possible option in their
-- conversations.
-- Returns a Convo.
function Quest:OnAttract(...)
    return self:AddHook(Quest.CONVO_HOOK.s.ATTRACT, ...)
end

-- Hub: Menu items at a location. Doesn't make sense in Rotwood.
function Quest:OnHub(...)
    error("No hub in Rotwood.")
    return self:AddHook(Quest.CONVO_HOOK.s.HUB, ...)
end

-- DungeonChat: player is in dungeon.
-- Returns a Convo.
function Quest:OnDungeonChat(...)
    return self:AddHook(Quest.CONVO_HOOK.s.CHAT_DUNGEON, ...)
end

-- TownChat: player is in town.
-- Returns a Convo.
function Quest:OnTownChat(...)
    return self:AddHook(Quest.CONVO_HOOK.s.CHAT_TOWN, ...)
end

function Quest:OnTownShopChat(...)
    return self:AddHook(Quest.CONVO_HOOK.s.CHAT_TOWN_SHOP, ...)
end


-- Finds the most relevant Convo of the input CONVO_HOOK type.
--
-- EvaluateHook(Quest.CONVO_HOOK.s.ATTRACT, qm) will return the highest
-- priority Convo created with OnAttract with a successful condition function
-- (passed to OnAttract).
function Quest:EvaluateHook(hook_id, node, sim)
    dbassert(Quest.CONVO_HOOK:Contains(hook_id))
    local hooks = self.def.convo_hooks[hook_id]
    local best_state, best_priority

    if hooks then
        self:Log("EvaluateHook on:", hook_id, tostring(self), "at tick", GetTick())
        local best_hook
        for _, hook in ipairs(hooks) do
            -- PERF: Consider inverting this order to evaluate priority first.
            if hook.fn(self, node, sim) then
                local priority = hook.state.convo:GetPriority()
                if best_priority == nil or best_priority < priority then
                    best_hook, best_priority = hook, priority
                else
                    self:Log("  EvaluateHook [priority]: too low priority on", hook.objective_id or "", hook.state.id)
                end
            end
			-- else, we log it in AddHook.
        end
        if best_hook then
            best_state = best_hook.state
            self:Log("  EvaluateHook result: Selected", best_hook.objective_id or "", best_state and best_state.id or "<none>")
        else
            self:Log("  EvaluateHook result: no match")
        end
    end

    return best_state, best_priority
end

function Quest:CollectHook(hook_id, node, sim, ret)
    dbassert(Quest.CONVO_HOOK:Contains(hook_id))
    local hooks = self.def.convo_hooks[hook_id]
    if hooks then
        for _, hook in ipairs(hooks) do
            if hook.fn(self, node, sim) then
                table.insert(ret, {quest = self, node = node, state = hook.state, priority = hook.state.convo:GetPriority() })
            end
        end
    end
end

function Quest:ScenarioTrigger(id, objective_id, filter_fn)
    assert(self:is_class(), "Don't call this on an instance")
    local trig = ScenarioTrigger(id, objective_id, filter_fn)
    table.insert( self._class.def.scenario_triggers, trig)
    self._class.def.scenario_triggers_by_id[id] = trig
    return trig
end

function Quest:AddObjective(id)
    assert(self:is_class(), "Don't call this on an instance")
    assert(self._class.def.objective[id] == nil, "Duplicate objective id")
    dbassert(id:is_lower(), "Objective ids must be lower case.")
    self._class.def.objective[id] = QuestObjectiveDef(self, id)
    return self._class.def.objective[id]
end

function Quest:UpdateObjective(id)
    assert(self:is_class(), "Don't call this on an instance")
    assert( self._class.def.objective[id] ~= nil, "Missing objective id to update")
    return self._class.def.objective[id]
end

function Quest:AssignCastMember(id, node)
    assert(self.cast_members[id] == nil, "Assigning Duplicate Cast member")
    assert( not self:FindCastID( node ), "Assigning Member to duplicate cast nodes: "..tostring(self) )

    node:AddToQuest(self)
    self.cast_members[id] = node

    local cast_def = self.def.cast[id]
    if cast_def.assign_fn then
        cast_def.assign_fn( self, node )
    end

    if self:IsActive() then
        self:_RegisterCastMember(node)
    end
end

function Quest:_RegisterCastMember(node)
    if not self:IsListening() then
        -- We shouldn't even get here, but QuestManager:LoadQuestData is
        -- loading old quests attached and active.
        -- TODO(dbriscoe): Can we load all quests without being active?
        return
    end

    if node.inst then
        self:_ListenForEventsOnCast(node)
    else
        node:OnFillReservation(function()
             -- time may have passed since previous check
            if self:IsListening() and self:FindCastID(node) then
                self:_ListenForEventsOnCast(node)
            end            
        end)
    end
end

function Quest:_UnregisterCastMember(node)
    if node.inst then
        self:_RemoveListenersOnCast(node)
    end
    -- else: no way to clear callback, but it's guarded by FindCastID.
end

local function add_keys(dst, src)
    for key,val in pairs(src) do
        dst[key] = true
    end
end
function Quest:_ListenForEventsOnCast(cast_member)
    assert(self.inst, "Only running quests should listen for events.")
    local cast_id = lume.find(self.cast_members, cast_member)
    if not cast_id then
        return
    end
    self.cast_event_fns = self.cast_event_fns or {}
    if self.cast_event_fns[cast_member] then
        error("Already listening for events on this actor. Why are we listening again?")
        return
    end

    -- Build up a map to ensure uniqueness.
    local all_events = {}
    local cast_def = self.def.cast[cast_id]
    if cast_def and cast_def.event_handlers then
        add_keys(all_events, cast_def.event_handlers)
    end

    for obj_id, dat in pairs(self.def.objective) do
        local event_handlers = dat.cast_event_handlers[cast_id]
        if event_handlers then
            add_keys(all_events, event_handlers)
        end
    end

    local event_fns = {}
    for eventname in pairs(all_events) do
        local fn = function(source, data)
            self:ReceivedCastEvent(eventname, cast_member, data)
        end
        self.inst:ListenForEvent(eventname, fn, cast_member.inst)
        event_fns[eventname] = fn
    end
    if next(event_fns) then
        self.cast_event_fns[cast_member] = event_fns
    end

    dbassert(cast_member.inst, "Expected entity to be available.")
    if self.Quest_SetupCastMember then
        self:Quest_SetupCastMember(cast_member, cast_id)
    end

    TheDungeon:PushEvent("cast_member_filled", cast_member)

    self:GetQC():UpdateQuestMarks()
end

function Quest:_RemoveListenersOnCast(cast_member)
    assert(self.inst)
    local event_fns = self.cast_event_fns and self.cast_event_fns[cast_member]
    if not event_fns then
        return
    end
    for eventname,fn in pairs(event_fns) do
        self.inst:RemoveEventCallback(eventname, fn, cast_member.inst)
    end
    self.cast_event_fns[cast_member] = nil

    self:GetQC():UpdateQuestMarks()
end

function Quest:UnassignCastMember(id)
    if self.cast_members[id] == nil then
        -- d_view{ "Unassigning Empty Cast member", id, self }
        return
    end
    local node = self.cast_members[id]
    self.cast_members[id] = nil

    node:RemoveFromQuest( self )
    self:_UnregisterCastMember(node)

    if self.def.cast[ id ].unassign_fn then
        self.def.cast[ id ].unassign_fn( self, node )
    end
end

function Quest:ReassignCastMember(id, node)
    if self.cast_members[id] then
        self:UnassignCastMember( id )
    end
    self:AssignCastMember( id, node )
end

-- Called in response to an event on a cast member.
-- Called OnCastEvent in gln.
function Quest:ReceivedCastEvent(event, cast_member, ...)
    local cast_id = lume.find(self.cast_members, cast_member)
    if not cast_id then
        return
    end

    local cast_def = self.def.cast[cast_id]
    local fn = cast_def
        and cast_def.event_handlers
        and cast_def.event_handlers[event]
    if fn then
        fn(self, cast_member, ...)
    end

    -- TODO(dbriscoe): gln removed objective cast events. Do we want them?
    for obj_id, dat in pairs(self.def.objective) do
        if self:GetObjectiveState(obj_id) == QUEST_OBJECTIVE_STATE.s.ACTIVE then
            --print (obj_id, cast_id, event, dat.cast_event_handlers[cast_id] and dat.cast_event_handlers[cast_id][event])
            if dat.cast_event_handlers[cast_id] and dat.cast_event_handlers[cast_id][event] then
                dat.cast_event_handlers[cast_id][event](self, ...)
            end
        end
    end
end

function Quest:Debug_Cancel()
    -- Cancel but ensure there are no errors regardless of our current state.
    -- For when we debug spawned a quest and want to cancel it.
    if not self:GetParent() then
        return
    end
    -- Should we assert that we're not active?
    assert(self.quest_created_from_debug, "Why Debug_Cancel() a quest that wasn't debug spawned?") -- see MarkAsDebug
    return self:Cancel()
end

function Quest:Cancel(id)
    if id then
        self:SetObjectiveState(id, QUEST_OBJECTIVE_STATE.s.CANCELED)
    else
        if self.state ~= QUEST_OBJECTIVE_STATE.s.CANCELED then
            self.state = QUEST_OBJECTIVE_STATE.s.CANCELED

            for id, dat in pairs(self.def.objective) do
                if self:GetObjectiveState(id) == QUEST_OBJECTIVE_STATE.s.ACTIVE then
                    self:SetObjectiveState(id, QUEST_OBJECTIVE_STATE.s.CANCELED)
                end
            end

            if self:GetQuestManager():GetMainQuest() == self then
                self:GetQuestManager():SetMainQuest(nil)
            end

            if self.Quest_Cancel then
                self:Quest_Cancel()
            end

            self:Detach()
        end
    end
end

function Quest:Fail(id)
    local giver = self:GetCastMember( "giver" )
    if giver and self:IsQuestAccepted() then
        giver:AddOpinion( "FAILED_JOB", { quest = self } )
    end

    if id then
        self:SetObjectiveState(id, QUEST_OBJECTIVE_STATE.s.FAILED)
    else
        if self.state ~= QUEST_OBJECTIVE_STATE.s.FAILED then
            self.state = QUEST_OBJECTIVE_STATE.s.FAILED

            for id, dat in pairs(self.def.objective) do
                if self:GetObjectiveState(id) == QUEST_OBJECTIVE_STATE.s.ACTIVE then
                    self:SetObjectiveState(id, QUEST_OBJECTIVE_STATE.s.FAILED)
                end
            end

            if self:GetQuestManager():GetMainQuest() == self then
                self:GetQuestManager():SetMainQuest(nil)
            end

            if self.Quest_Fail then
                self:Quest_Fail()
            end

            self:Detach()
        end
    end
end

function Quest:Complete(id)
    if id then
        self:SetObjectiveState(id, QUEST_OBJECTIVE_STATE.s.COMPLETED)
    else
        if self.state ~= QUEST_OBJECTIVE_STATE.s.COMPLETED then
            self.state = QUEST_OBJECTIVE_STATE.s.COMPLETED

            if self:GetQuestManager():GetMainQuest() == self then
                self:GetQuestManager():SetMainQuest(nil)
            end

            local def = self._class.def
            local player = self:GetPlayer()

            for _, flag in ipairs(def.unlock_player_flags_on_complete) do
                player:UnlockFlag(flag)
            end

            for _, flag in ipairs(def.lock_player_flags_on_complete) do
                player:LockFlag(flag)
            end

            for _, flag in ipairs(def.unlock_world_flags_on_complete) do
                TheWorld:UnlockFlag(flag)
            end

            for _, flag in ipairs(def.lock_world_flags_on_complete) do
                TheWorld:LockFlag(flag)
            end

            if self.Quest_Complete then
                self:Quest_Complete()
            end

            self:Detach()
        end
    end
end

-- Is the quest/objective currently running?
--
-- Beware of negating: not IsActive could mean complete, failed, etc.
-- *Inactive* usually means never started.
function Quest:IsActive(id)
    if id then
        if not self.objective_state[id] then
            error("Invalid objective id:" .. id)
        end
        return self:GetObjectiveState(id) == QUEST_OBJECTIVE_STATE.s.ACTIVE
    end
    return self.state == QUEST_OBJECTIVE_STATE.s.ACTIVE
end

function Quest:IsFailed()
    return self.state == QUEST_OBJECTIVE_STATE.s.FAILED
end

function Quest:IsCompleted()
    return self.state == QUEST_OBJECTIVE_STATE.s.COMPLETED
end

function Quest:IsComplete(id)
    if id then
        if not self.objective_state[id] then
            TheLog.ch.Quest:printf( "ERROR: Invalid objective id '%s' for quest %s", id, tostring(self))
            return false
        end
        return self:GetObjectiveState(id) == QUEST_OBJECTIVE_STATE.s.COMPLETED
    end
    return self.state == QUEST_OBJECTIVE_STATE.s.COMPLETED
end

-- Is quest in a state where it might take actions. Otherwise, it should be
-- dead and detached.
function Quest:IsListening()
    -- When inactive, we can respond to events which might make us active.
    -- Terminal states (completed, failed, canceled) shouldn't respond to
    -- anything. We currently expect to respawn quests rather than revive old
    -- ones.
    return self.inst
        and (self.state == QUEST_OBJECTIVE_STATE.s.ACTIVE
            or self.state == QUEST_OBJECTIVE_STATE.s.INACTIVE)
end

function Quest:ActivateObjective(id, ignore_rate_limit)
    self:SetObjectiveState(id, QUEST_OBJECTIVE_STATE.s.ACTIVE, ignore_rate_limit)
    return self
end

function Quest:NetworkSyncStates(states)
    dbassert(states ~= nil)
    for _, state in ipairs(states) do
        self._class.def.network_sync[state] = true
    end
    return self
end

function Quest:ShouldNetworkSync(state)
    return self._class.def.network_sync[state]
end

function Quest:LocalSyncStates(states)
    dbassert(bool ~= nil)
    for _, state in ipairs(states) do
        self._class.def.local_sync[state] = true
    end
    return self
end

function Quest:ShouldLocalSync(state)
    return self._class.def.local_sync[state]
end

function Quest:AllowDuplicates(bool)
    dbassert(bool ~= nil)
    self._class.def.allow_duplicates = bool
    return self
end

function Quest:CanBeDuplicated()
    return self._class.def.allow_duplicates
end

function Quest:SetRateLimited(bool)
    -- sets the default for objectives in this quest.
    -- objectives can still optionally overwrite this by calling it on themselves.
    dbassert(bool ~= nil)
    self._class.def.rate_limited = bool
    return self
end

function Quest:IsRateLimited()
    return self._class.def.rate_limited
end

function Quest:SetChatCost(num)
    -- sets the default cost for objectives in this quest.
    -- objectives can still optionally overwrite this by calling it on themselves.
    dbassert(num ~= nil and num <= TOWN_CHAT_BUDGET) -- if num is greater the chat can never happen
    self._class.def.chat_cost = num
    return self
end

function Quest:GetChatCost()
    return self._class.def.chat_cost
end

function Quest:MarkLocation(locations)
    self._class.def.marked_locations = locations
    return self
end

function Quest:GetMarkedLocations()
    return self._class.def.marked_locations
end

function Quest:SetIsImportant()
    self._class.def.importance = QUEST_IMPORTANCE.s.HIGH
    return self
end

function Quest:SetIsUnimportant()
    self._class.def.importance = QUEST_IMPORTANCE.s.LOW
    return self
end

function Quest:GetImportance()
    return self._class.def.importance
end

function Quest:SetPriority(val)
    self._class.def.priority = val
    return self
end

function Quest:GetPriority()
    return self._class.def.priority or QUEST_PRIORITY.LOWEST -- Higher numbers are higher priority
end

--------
-- Flags that either lock or unlock when the objective is completed
--------

function Quest:UnlockPlayerFlagsOnComplete(flags)
    self._class.def.unlock_player_flags_on_complete = flags
    return self
end

function Quest:LockPlayerFlagsOnComplete(flags)
    self._class.def.lock_player_flags_on_complete = flags
    return self
end

function Quest:UnlockWorldFlagsOnComplete(flags)
    self._class.def.unlock_world_flags_on_complete = flags
    return self
end

function Quest:LockWorldFlagsOnComplete(flags)
    self._class.def.lock_world_flags_on_complete = flags
    return self
end

------

-- On request from the host, will set objective states.
-- Also flows through here for local quest requests.
function Quest:_SetObjectiveState(objective_id, state, playerID, ignore_rate_limit)
    -- playerID is the ID of the player who completed it.
    local def = self.def.objective[objective_id]
    kassert.assert_fmt(def, "Unknown quest objective: %s", objective_id)
    assert(QUEST_OBJECTIVE_STATE:Contains(state))

    if self.objective_state[objective_id] ~= state then
        TheLog.ch.Quest:printf("Objective %s.%s:	state %s -> %s", self._classname, objective_id, self.objective_state[objective_id], state)

        self.objective_state[objective_id] = state

        -- TODO(dbriscoe): Cleanup:
        -- Simplify function picking.
        -- Don't run multiple callbacks.
        -- Don't allow state to change again within callback.

        if state == QUEST_OBJECTIVE_STATE.s.COMPLETED and def then
            local player = self:GetPlayer()

            for _, flag in ipairs(def.unlock_player_flags_on_complete) do
                player:UnlockFlag(flag)
            end

            for _, flag in ipairs(def.lock_player_flags_on_complete) do
                player:LockFlag(flag)
            end

            for _, flag in ipairs(def.unlock_world_flags_on_complete) do
                TheWorld:UnlockFlag(flag)
            end

            for _, flag in ipairs(def.lock_world_flags_on_complete) do
                TheWorld:LockFlag(flag)
            end

            if def.on_complete_fn then
                def.on_complete_fn(self, playerID)
            end
        end

        if state == QUEST_OBJECTIVE_STATE.s.FAILED and def and def.on_fail_fn then
            def.on_fail_fn(self, playerID)
        end

        if state == QUEST_OBJECTIVE_STATE.s.ACTIVE and def and def.on_activate_fn then
            def.on_activate_fn(self, playerID)
        end

        if state == QUEST_OBJECTIVE_STATE.s.ACTIVE and ignore_rate_limit then
            self:GetQC():InsertTownQuest(self, objective_id)
        end

        if state ~= QUEST_OBJECTIVE_STATE.s.ACTIVE and def and def.on_finish_fn then
            def.on_finish_fn(self, playerID)
        end

        if state == QUEST_OBJECTIVE_STATE.s.ACTIVE and def.is_exclusive then
            for other_id, other_state in pairs(self.objective_state) do
                if other_id ~= objective_id and other_state == QUEST_OBJECTIVE_STATE.s.ACTIVE then
                    self:Cancel(other_id)
                end
            end
        end

        if self.parent then
            self.parent:OnQuestChanged(self)
        end
    end
end

-- Local client changed objective state
-- Checks if that state change should be propagated between networked & local clients.
function Quest:SetObjectiveState(objective_id, new_state, ignore_rate_limit)
    local def = self.def.objective[objective_id]

    if def == nil then
        assert(nil, "Unknown quest objective: " .. objective_id)
    end

    assert(QUEST_OBJECTIVE_STATE:Contains(new_state))

    local old_state = self.objective_state[objective_id]

    -- only do this if the new_state is going from active to something else.
    if old_state ~= new_state then
        local player_id = self:GetPlayer().Network:GetPlayerID()
        local objective = self.def.objective[objective_id]

        if old_state == QUEST_OBJECTIVE_STATE.s.ACTIVE then

            if objective:ShouldNetworkSync(new_state) then -- Should other players (LOCAL & REMOTE) also complete this objective?
                TheNet:ClientRequestCompleteQuest(player_id, self:GetContentID(), objective_id, new_state) 
            end

            if objective:ShouldLocalSync(new_state) then -- Should other LOCAL players also complete this objective?
                playerutil.DoForAllLocalPlayers(function(player)
                    if player ~= self:GetPlayer() then
                        printf("%s/ %s/ %s/ %s", player_id, self:GetContentID(), objective_id, new_state)
                        local qc = player.components.questcentral
                        -- if qc:ValidateRemoteQuestCompleted(player_id, self:GetContentID(), objective_id, new_state) then
                            qc:OnHostQuestCompleted(player_id, self:GetContentID(), objective_id, new_state)
                        -- end
                    end
                end)
            end
        end

        self:_SetObjectiveState(objective_id, new_state, player_id, ignore_rate_limit)
    end
end

function Quest:GetObjectiveState(objective_id)
    return self.objective_state[objective_id]
end

function Quest:GetAllObjectives()
    local ids = {}
    for id, state in pairs( self.objective_state ) do
        table.insert(ids, id)
    end
    return ids
end

function Quest:GetActiveObjectives()
    local ids = {}
    for id, state in pairs( self.objective_state ) do
        if state == QUEST_OBJECTIVE_STATE.s.ACTIVE then
            table.insert(ids, id)
        end
    end
    return ids
end

function Quest:GetString(id, ...)
    local StringFormatter = require "questral.util.stringformatter"
    local formatter = StringFormatter()
    self:FillFormatter( formatter )
    return formatter:FormatString(self:LOC(id), ...)
end

function Quest:FillFormatter( formatter )
    for id, cast in pairs( self.cast_members ) do
        formatter:AddLookup( id, cast )
    end
    for k, param in pairs( self.param ) do
        formatter:AddLookup( k, param )
    end
    for k, fn in pairs( self.def.formatters ) do
        formatter:AddLookup( k, function()
            return fn( self, k )
        end )
    end
end

function Quest:GetTitle()
    return self:GetString("TITLE")
end

function Quest:GetIcon()
    return self:IMG("ICON")
end

function Quest:GetDesc(objective_id)

    if objective_id then
        assert(self.def.objective[objective_id], "Invalid objective id")
        local def = self.def.objective[objective_id]
        if def.get_log_txt then
            local txt = def.get_log_txt(self)
            return txt
        end
    end

    return self:GetString("DESC")
end

function Quest:FillLogEntries(t)
    if self:IsActive() then
        table.clear(t)

        if self.time_left and self.quest_accepted then
            table.insert(t, loc.format( self:LOC "TIME_LEFT", self.time_left + 1 ))
        end

        for id,state in pairs(self.objective_state) do
            if state == QUEST_OBJECTIVE_STATE.s.ACTIVE then
                local def = self.def.objective[id]
                if def.get_log_txt then
                    local txt = def.get_log_txt(self)
                    if txt then
                        table.insert(t, txt)
                    end
                end
            end
        end
    end
end

function Quest:SetTimeLeft(t)
    self.time_left = t
end

function Quest:GetTimeLeft()
    return self.time_left
end

-- TODO(dbriscoe): What is this?
function Quest:CanDrop()
    return (self:IsJob()
        and self:IsQuestAccepted() and self:IsActive())
end

function Quest:IsQuestAccepted()
    return self.quest_accepted
end

function Quest:__tostring()
    return string.format( "Quest[%s %s]", self._classname, kstring.raw(self) )
end

function Quest:AcceptQuest()
    self.quest_accepted = true
    --~ self:FollowQuest()

    -- TODO(dbriscoe): Automatic renown granting for accepting quests? Who does it go to?
    --~ if self:IsJob() then
    --~     local giver = self:GetCastMember( "giver" )
    --~     if giver then
    --~         giver:AddOpinion( "TOOK_JOB", { quest = self } )
    --~     end
    --~ end

    -- TODO(dbriscoe): Notification for new quest?
    --~ if self:IsJob() then
    --~     local NewQuestNotification = require "sim.notifications.newquestnotification"
    --~     self:GetQC():Notify( NewQuestNotification( self ))
    --~ end
end

function Quest:GetQuestManager()
    return self.parent
end

--~ function Quest:FollowQuest( is_following )
--~     if is_following ~= self.is_following then
--~         self.is_following = is_following
--~         self:GetQC():BroadcastEvent("FOLLOW_QUEST_CHANGED", self)
--~     end
--~ end

--~ function Quest:IsFollowing()
--~     return self.is_following
--~ end

function Quest:GetScenario()
    return self.sim:GetCurrentScenario()
end

function Quest:DoScenarioConvo(id, speaker, hide_player)
    self.sim:GetCurrentScenario():DoQuestConvo(self, id, speaker, hide_player)
end

function Quest:GetOpinionEvent(opinion_id)
    local OpinionEvent = require "sim.opinionevent"
    local event = self._class.def.opinion_events[opinion_id] or OpinionEvent.GetEvent(opinion_id)
    assert(event, "Opinion event does not exist.")
    return event
end

function Quest:GrantOpinion(cast_id, opinion_id)
    local Agent = require "questral.agent"

    local event = self:GetOpinionEvent(opinion_id)

    local cast
    if type(cast_id) == "string" then
        cast = self:GetCastMember(cast_id)
    elseif Agent.is_instance(cast_id) then
        cast = cast_id
    end

    assert(cast, "Invalid cast for opinion event.")
    return cast:AddOpinion( event:GetContentID() )
end

function Quest:ResetScenarioState()
    self.scenario_state = nil
end

function Quest:GetScenarioState()
    self.scenario_state = self.scenario_state or {}
    self.scenario_state.trigger_states = self.scenario_state.trigger_states or {}
    return self.scenario_state
end

function Quest:OnScenarioUpdate(scenario, dt)
    --make a state for each quest this scenario
    local state = self:GetScenarioState()

    for _, trigger in ipairs(self._class.def.scenario_triggers) do
        state.trigger_states[trigger.id] = state.trigger_states[trigger.id] or {}
        trigger:ProcessTrigger(self, scenario, state, state.trigger_states[trigger.id], dt)
    end

    for id,state in pairs(self.objective_state) do
        if state == QUEST_OBJECTIVE_STATE.s.ACTIVE then
            local def = self.def.objective[id]
            if def.scenario_update_fn then
                def.scenario_update_fn(self, scenario, dt)
            end
        end
    end

    if self.Quest_ScenarioUpdate then
        self:Quest_ScenarioUpdate(scenario, dt)
    end

end

function Quest:OnAddContent(db)
    if self.def and self.def.opinion_events then
        db:AddContentList(self.def.opinion_events)
    end
end

-- Quests can override this where necessary
function Quest:IsReadyForTurnIn()
    return self.objective_state["return"] and self.objective_state["return"] == QUEST_OBJECTIVE_STATE.s.ACTIVE
end

function Quest:SetReward( reward )
    self.param.reward = reward
end

--can be overridden by a specific quest
function Quest:GetBannerText()
    return nil
end

function Quest:IsJob()
    return self:GetType() == Quest.QUEST_TYPE.s.JOB
end

function Quest:GetQuipID()
    if not self._class.quip_id then
        self._class.quip_id = "in_quest_" .. self:GetContentID()
    end
    return self._class.quip_id
end

-- Quips can:
-- * Give variety within conversations. Use within a convo that's seen often to
--   change up the text. e.g., use this line in a convo: "%scout sad sigh"
-- * Give variety to greetings. Use as the first line to show as a greeting,
--   but beware of using quips that sound like the npc has something new to say.
function Quest:AddQuip(quip)
    -- Add our id to any defined-inline quips so they're only active when our
    -- quest and the target is part of our quest.
    quip:Tag(self:GetQuipID(), qconstants.QUIP_WEIGHT.Quest)
    ContentNode.AddQuip(self, quip)
end

function Quest:GetQC()
    -- get the quest central of this quest
    return self:GetQuestManager():GetQC()
end

return Quest
