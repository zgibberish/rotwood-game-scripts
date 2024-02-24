local GameNode = require "questral.gamenode"
local contentutil = require "questral.util.contentutil"
local krandom = require "util.krandom"
local kstring = require "util.kstring"
local Agent = require "questral.agent"
local Quest = require "questral.quest"
local lume = require "util.lume"
local qconstants = require "questral.questralconstants"

local QuestManager = Class(GameNode, function(self, ...) self:init(...) end)

QuestManager.DebugNodeName = "DebugQuestManager"

function QuestManager:init()
    self.inst = CreateEntity("QuestManager")
    self.old_quests = {} -- completed or invalid
    self.quest_counts = {}
    self.loaded_data = nil
    self.can_activate_spawned_quests = true
end

function QuestManager:OnTeardown()
    self.inst:Remove()
    self.inst = nil
end

function QuestManager:__tostring()
    return string.format( "QuestManager[%s %s]", self.inst, kstring.raw(self) )
end

function QuestManager:HasEverHadQuests()
    return next(self.old_quests) or next(self:GetQuests())
end

function QuestManager:SaveQuestData()
    dbassert(not self.used_cheats_to_compromise_quest_state, "Cannot save quest data after using cheats (ConvoTester)!")
    local function is_serializable(q)
        return q:CanSerialize()
    end
    local data = {
        quest_counts = self.quest_counts,
        old_quests = lume(self.old_quests)
            :filter(is_serializable)
            :map(Quest.OnSave)
            :result(),
        current_quests = lume(self:GetQuests())
            :filter(is_serializable)
            :map(Quest.OnSave)
            :result(),
    }
    return data
end

function QuestManager:LoadQuestData(data, known_actors)
    if not next(data) then
        return
    end
    TheLog.ch.Quest:printf("Loading quests for [%s].", self:GetQC():GetPlayer())
    TheLog.ch.Quest:indent()

    local root = self:GetParent()
    assert(root)
    assert(not self:IsActivated(), "Loading quests when active will cause them to trigger actions based on their initial state before we can load their save state.")
    local function OnLoadQuest(quest_data)
        local cast_assignments = {}
        for cast_id,prefab in pairs(quest_data.cast_member_prefabs) do
            cast_assignments[cast_id] = known_actors[prefab]
        end
        -- TODO(dbriscoe): Possible issues with respawning?
        -- Respawning completed quests means re-casting, so we register
        -- reservations and then when we fill them, they're trying to fill a
        -- completed quest.
        -- Do we actually need completed quest state for anything?
        local q, err_quest = self:SpawnQuest(quest_data.classname, quest_data.verbatim.rank, quest_data.params, cast_assignments)
        if not q then
            d_view(self)
            d_view(err_quest)
            assert(q, "Failed to spawn quest for load. See above log.")
        end
        q:LoadFromSaveData(quest_data)
        return q
    end

    -- Don't activate old (completed) quests so they don't spawn more quests or
    -- interact with current state. We load these so we can query their state
    -- and debug the past.
    self.can_activate_spawned_quests = false
    local old_quests = lume.map(data.old_quests, OnLoadQuest)
    self.can_activate_spawned_quests = true

    local current_quests = lume.map(data.current_quests, OnLoadQuest)
    self.quest_counts = data.quest_counts
    self.loaded_data = data
    TheLog.ch.Quest:unindent()
    TheLog.ch.Quest:printf("Loaded %i active quests and %i past quests.", #current_quests, #old_quests)
end

function QuestManager:ValidateQuests()
    -- Loop through quests and call :Quest_Validate() on each quest
    -- Intended to be used in such a way that quests can validate if they are still needed or valid, then either cancel or complete themselves
    local failed_quests = {}

    for _, quest in ipairs(self:GetQuests()) do
        if quest.Quest_Validate then
            if not quest:Quest_Validate() then
                table.insert(failed_quests, quest)
            end
        end
    end

    for _, quest in ipairs(failed_quests) do
        quest:Cancel()
    end
end

function QuestManager:OnActivate()

end

function QuestManager:OnDeactivate()

end

function QuestManager:HasLoadedSaveData()
    return self.loaded_data ~= nil
end

function QuestManager:SpawnQuest( classname, rank, params, cast_assignments )
    local quest_class = contentutil.GetContentDB():Get(Quest, classname)

    if not quest_class:CanBeDuplicated() and self:FindQuestByID(classname) then
        TheLog.ch.Quest:printf("Failed to spawn quest [%s], it is already active and cannot be duplicated.", classname)
        return nil
    else
        return self:_SpawnSingleQuest(quest_class, self:GetRoot(), rank, params, cast_assignments)
    end

end

function QuestManager:_SpawnSingleQuest(quest_class, parent, rank, params, cast_assignments)
    assert(quest_class)
    rank = rank or 1
    local quest, err_quest = quest_class:SpawnQuestFromClass(parent, rank, params, cast_assignments)

    if quest then
        if self.can_activate_spawned_quests then
            if quest:GetType() == Quest.QUEST_TYPE.s.MAIN then
                assert(self.main_quest == nil, "Already have a main quest")
                self:SetMainQuest(quest)
            end

            self:AttachChild(quest)
            self:OnQuestChanged(quest)
        end

        local id = quest:GetContentID()
        self.quest_counts[ id ] = (self.quest_counts[ id ] or 0) + 1
        return quest
    else
        TheLog.ch.Quest:printf("ERROR. Failed to spawn quest '%s'. Log:\n%s\nEnd Log", quest_class._classname, err_quest and err_quest:GetLogText())
        return nil, err_quest
    end
end

function QuestManager:OnQuestChanged(quest)
    TheLog.ch.QuestSpam:print("Quest changed", quest)
    self.inst:PushEvent("quest_updated", quest)
    self:GetQC():UpdateQuestMarks()
end

function QuestManager:GetMarkedLocations()
    local locations = {}
    for _, quest in ipairs(self:GetQuests()) do
        locations = lume.concat(locations, quest.marked_locations)
    end
    locations = lume.unique(locations)
    locations = lume.invert(locations)
    return locations
end

function QuestManager:GetHubOptions(node)
    local quests = self:GetQuests()
    local sim = self:GetQC()

    local hub_options = {}
    for _, quest in ipairs(quests) do
        quest:CollectHook(Quest.CONVO_HOOK.s.HUB, node, sim, hub_options)
    end
    return hub_options
end

-- Finds the most relevant Quest and Convo of the input CONVO_HOOK type.
--
-- hook: The kind of convo to look for.
-- node: The context we're looking from (a location node or a specific npc).
--
-- EvaluateHook(Quest.CONVO_HOOK.s.ATTRACT, qm) will return a Convo (created
-- with Q:OnAttract) and its owning Quest. See Quest.EvaluateHook.
function QuestManager:EvaluateHook(hook, primary_node)
    dbassert(Quest.CONVO_HOOK:Contains(hook))
    local quests = self:GetQuests()

    local targets = {}
    if hook == Quest.CONVO_HOOK.s.CONFRONT then
        -- Anyone already here is a better target than the location.
        -- TODO(dbriscoe): Validate this behaves correctly.
        targets = lume.filter(primary_node:GetChildren(), Agent.is_instance)
    end

    -- The location may match on its own if it will spawn someone to talk to.
    table.insert(targets, primary_node)

    local best_state, best_quest, best_node, best_priority

    for _, node in ipairs(targets) do
        for _, quest in ipairs(quests) do
            local state, priority = quest:EvaluateHook(hook, node, self:GetQC())
            if priority then
                if best_priority == nil or best_priority < priority then
                    best_state, best_quest, best_node, best_priority = state, quest, node, priority
                end
            end
        end
    end

    return best_state, best_quest, best_node
end

-- Returns either the followed quest or the first active one
function QuestManager:GetCurrentQuest()
    for _, quest in ipairs(self:GetQuests()) do
        if quest:IsFollowing() then return quest end
    end
    for _, quest in ipairs(self:GetQuests()) do
        if quest:IsActive() then
            local log_entries = {}
            quest:FillLogEntries(log_entries)
            if #log_entries > 0 then return quest end
        end
    end
end

function QuestManager:GetMainQuest()
    return self.main_quest
end

function QuestManager:GetQuests()
    return self:GetChildren()
end

function QuestManager:GetSectorEvents()
    return self:GetBucketByID( "SECTOR_EVENTS" )
end

function QuestManager:FindQuestByID( id )
    for i, quest in ipairs( self:GetQuests() ) do
        if quest:GetContentID() == id then
            return quest
        end
    end
end

function QuestManager:FindCompletedQuestByID( id )
    for i, quest in ipairs( self.old_quests ) do
        if quest:GetContentID() == id then
            return quest
        end
    end
end

function QuestManager:FindAllQuestByID( id )
    local ret = {}
    for i, quest in ipairs( self:GetQuests() ) do
        if quest:GetContentID() == id then
            table.insert(ret, quest)
        end
    end
    return ret
end

function QuestManager:OnScenarioStart(scenario)
    local quests = self:GetQuests()

    local quest_list = shallowcopy(quests)
    for _, quest in ipairs(quest_list) do
        quest:DoPopulateScenario(scenario)
    end
    scenario:ListenForAny(self, QuestManager.OnScenarioEvent)
end

function QuestManager:OnScenarioEnd(scenario)
    scenario:RemoveListener(self)

    local quests = self:GetQuests()
    local quest_list = shallowcopy(quests)
    for _, quest in ipairs(quest_list) do
        quest:DoDepopulateScenario(scenario)
    end
end

function QuestManager:OnScenarioEvent(event, scenario, ...)
    local quests = self:GetQuests()
    for _, quest in ipairs(quests) do
        quest:HandleScenarioEvent(event, scenario, ...)
    end
end

function QuestManager:SetMainQuest(quest)
    if not quest:GetStatus() == QUEST_OBJECTIVE_STATE.s.COMPLETED then
        self.main_quest = quest
    end
end

function QuestManager:OnDetachChild(quest)
    self:OnQuestChanged(quest)
    table.insert(self.old_quests, quest)
end

function QuestManager:CountAcceptedQuests()
    local count = 0
    for i, quest in ipairs( self:GetQuests()) do
        if quest:IsQuestAccepted() then
            count = count + 1
        end
    end
    return count
end

function QuestManager:SortQuestBySpawnPriority( quest_ids )

    self.quest_counts = self.quest_counts or {}

    table.sort( quest_ids, function( a, b )
        local db = contentutil.GetContentDB()
        local class_a, class_b = db:Get(Quest, a), db:Get(Quest, b)
        local pa, pb = class_a:GetPriority(), class_b:GetPriority()
        if pa == pb then
            return (self.quest_counts[a] or 0) < (self.quest_counts[b] or 0)
        else
            return pa > pb
        end
    end )
end

function QuestManager:SortQuestBySpawnCount( quest_ids )
    table.sort( quest_ids, function( a, b ) return (self.quest_counts[a] or 0) < (self.quest_counts[b] or 0) end )
end

function QuestManager:AffirmJob( giver, rank )
    for i, quest in ipairs( giver:GetQuests()) do
        if quest:GetType() == Quest.QUEST_TYPE.s.JOB and quest:GetCastMember( "giver" ) == giver then
            return quest
        end
    end

    local role_data = giver:GetFactionRoleData()
    if not role_data then
        return nil -- Generic NPCs do not have jobs, because they have no faction roles.
    end

    local jobs_to_try = {}
    for i, class in ipairs(contentutil.GetContentDB():GetFiltered( Quest )) do
        local def = class.def
        if def and
            (def.quest_type == Quest.QUEST_TYPE.s.JOB or def.quest_type == Quest.QUEST_TYPE.s.CONTRACT) and
            rank >= def.min_rank and
            rank <= def.max_rank and
            table.contains( role_data.jobs or table.empty, class:GetContentID() )
        then
            --
            table.insert(jobs_to_try, class:GetContentID() )
        end
    end

    jobs_to_try = krandom.Shuffle(jobs_to_try)
    self:SortQuestBySpawnPriority( jobs_to_try )

    local cast
    if giver then
        cast = {giver = giver}
    end

    for _, quest_id in ipairs(jobs_to_try) do
        local quest, err = self:SpawnQuest( quest_id, rank, nil, cast)
        if quest then
            if quest:GetTimeLeft() == nil then
                quest:SetTimeLeft( qconstants.TIMES.JOB_TIME_DEFAULT )
            end
            return quest
        end
    end
end

function QuestManager:SpawnQuestByType(quest_type, must_have_tags, can_not_have_tags, cast_candidates, cast_assignments)
    local events_to_try = {}

    local classes = contentutil.GetContentDB():GetAll(Quest)

    for _, class in pairs( classes ) do
        if class.def.quest_type == quest_type then
            if class.def.tags:hasAll(must_have_tags) and not (can_not_have_tags and class.def.tags:hasAny(can_not_have_tags)) then

                if class.def.cast_candidates ~= nil then
                    if cast_candidates ~= nil then

                        for i,v in ipairs(class.def.cast_candidates) do
                            if table.contains(cast_candidates, v) then
                                table.insert(events_to_try, class._classname)
                            end
                        end

                    end
                else
                    table.insert(events_to_try, class._classname)
                end
            end
        end
    end

    krandom.Shuffle(events_to_try)
    self:SortQuestBySpawnPriority( events_to_try )

    for _, quest_id in ipairs(events_to_try) do
        local quest, err = self:SpawnQuest( quest_id, nil, nil, cast_assignments )
        if quest then
            return quest
        end
    end
end

function QuestManager:OnScenarioUpdate(scenario, dt)
    local quests = self:GetQuests()
    for _, quest in ipairs(quests) do
        quest:OnScenarioUpdate(scenario, dt)
    end
end

function QuestManager:GetBannerText()
    local t
    for k,v in ipairs(self:GetQuests()) do
        local txt = v:GetBannerText()
        if txt then
            t = t or {}
            table.insert(t, txt)
        end
    end
    if t then
        return table.concat(t, "\n")
    end
end

function QuestManager:GetQC()
    -- get the QuestCentral of this quest manager
    return self:GetParent()
end

return QuestManager
