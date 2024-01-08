local GameNode = require "questral.gamenode"
local Quest = require "questral.quest"
local QuestManager = require "questral.questmanager"
local QuipMatcher = require "questral.quipmatcher"
local RotwoodActor = require "questral.game.rotwoodactor"
local RotwoodLocation = require "questral.game.rotwoodlocation"
local biomes = require "defs.biomes"
local kstring = require "util.kstring"
local lume = require "util.lume"
require "class"

-- Central hub for Rotwood quest logic.

-- This is the main coordinator that digs into questral to provide entities or
-- trigger events.

-- Also the root of the quest GameNode hierarchy. This simplifies accessing
-- this object from quests: it's the root passed in to most functions.

-- Maybe also find conversations to start, spawn relevant npcs, move them into
-- place, etc.

-- Throttles town chats by determining which conversations should be valid 
-- each time the player enters the town

local QuestCentral = Class(GameNode, function(self, inst)
    self.inst = inst
    self.persistdata = {}

    self.gamecontent = TheGameContent
    self.quipmatcher = QuipMatcher(self)
    self.qman = QuestManager()

    self.max_repeatable_quests = 2
    self.quest_spawn_interval = 2 -- number of days
    self.last_quest_spawn = 0

    -- not sure if this is the best pattern.
    -- update quest marks when the player's inventory changed.
    -- this catches cases where an objective was invalid until the player picked up a certain item
    -- or an objective that used to be valid is now invalid because a certain item got consumed.

    local _update_marks = function() self:UpdateQuestMarks() end
    self.inst:ListenForEvent("inventory_changed", _update_marks)
    self.inst:ListenForEvent("inventory_stackable_changed", _update_marks)

    self.inst:ListenForEvent("on_player_set", function() self:EvaluateTownChats() end)
    self.inst:ListenForEvent("start_gameplay", function() self:EvaluateTownChats() end)

    self.inst:ListenForEvent("end_current_run", function(_, data) self:_OnEndRun(data) end, TheDungeon)
end)

function QuestCentral:OnRemoveEntity()
	-- Ensure quest GameNode hierarchy is destroyed so it stops responding to
	-- events.
	if self:GetParent() then
		self:TeardownNode()
	end
	if self.qman and self.qman:IsActivated() then
		self.qman:TeardownNode()
	end
	self.qman = nil
    self:GetCastManager():DetachPlayer(self.inst)

    if self._update_marks_task then
        self._update_marks_task:Cancel()
        self._update_marks_task = nil
    end
end

function QuestCentral:OnSave()
    local qm = self:GetQuestManager()

    if not qm:HasEverHadQuests() then
        -- We haven't loaded our new game saves. Probably a debug jump. Don't
        -- save anything so we'll load correctly next time we enter town.
        return
    end

    return {
        quest_state = qm:SaveQuestData(),
        persistdata = self.persistdata,
        last_quest_spawn = self.last_quest_spawn,
    }
end

function QuestCentral:_ActivateSelf()
    self:AttachChild(self:GetQuestManager())
    self:GetCastManager():AttachPlayer(self.inst)
end

function QuestCentral:OnLoad(data)
    if not next(data) then return end

    self:_ActivateSelf()

    self.persistdata = data.persistdata or {}
    self.last_quest_spawn = data.last_quest_spawn or 0
end

function QuestCentral:OnPostLoadWorld(data)
    if not data or not next(data) then return end
    -- this has to happen after CastManager:OnLoad() has happened.
    local npcnodes = self:GetCastManager():GetNPCNodes()
    local enemynodes = self:GetCastManager():GetEnemyNodes()

    local qm = self:GetQuestManager()
    local actornodes = lume.overlaymaps({}, npcnodes, enemynodes)
    qm:LoadQuestData(data.quest_state, actornodes)
    qm:ValidateQuests()

    self:UpdateQuestMarks()
end

function QuestCentral:OnPostSetPlayerOwner()
    local qm = self:GetQuestManager()

    if not qm:HasLoadedSaveData() then
        dbassert(qm:GetParent() == nil, "Already loaded?")

        self:_ActivateSelf()

        qm:SpawnQuest(self.gamecontent:GetContentLoader():GetNewGameQuest())
    end

    self:UpdateQuestMarks()

    -----------------------------------------------------------------------------------------------------------------------
    ------------------------------------------- REPEATABLE QUEST LOGIC ----------------------------------------------------
    -- if TheWorld:HasTag("town") then
    --  local repeatable_quests = self:GetActiveRepeatableQuests()

    --  if #repeatable_quests < self.max_repeatable_quests and self.last_quest_spawn >= self.quest_spawn_interval then
    --      self:SpawnRepeatableQuest()
    --      self.last_quest_spawn = 0
    --  end

    --  if self.persistdata.had_run then
    --      self.last_quest_spawn = self.last_quest_spawn + 1
    --  end
    -- end
    -----------------------------------------------------------------------------------------------------------------------
    -----------------------------------------------------------------------------------------------------------------------

    -- TODO(dbriscoe): Trigger confront.
end

function QuestCentral:__tostring()
    return string.format( "QuestCentral[%s %s]", self.inst, kstring.raw(self) )
end

function QuestCentral:UpdateQuestMarks()
    -- if we change a bunch of quests in a row, we don't want this to get called every time. 
    -- So just do it at the end of the frame, once.
    if not self._update_marks_task then
        self._update_marks_task = self.inst:DoTaskInTicks(0, function()
            TheWorld.components.questmarkmanager:RefreshQuestMarks(self)
            self._update_marks_task = nil
        end)
    end
end

function QuestCentral:GetCastManager()
    return TheDungeon.progression.components.castmanager
end

-- The conversation and quest system should never call this function, but
-- quest activation queries do.
function QuestCentral:GetPlayer()

    -- TODO(dbriscoe): How do we make this work in multiplayer? We have a group
    -- of players and quests that may query information on the players. Which
    -- player do they query? Do they activate separately for each player?
    return self.inst
end

function QuestCentral:GetEventEntities()
    return { TheWorld, TheDungeon }
end

function QuestCentral:GetEventEntity()
    return TheWorld
end

function QuestCentral:GetQuipMatcher()
    return self.quipmatcher
end

function QuestCentral:GetContentDB()
    return self.gamecontent:GetContentDB()
end

function QuestCentral:GetQuestManager()
    return self.qman
end

function QuestCentral:GetNpcCastForPrefab(prefab)
    local castmanager = self:GetCastManager()
    return castmanager:_GetCastForPrefab(prefab, castmanager:GetNPCNodes())
end

function QuestCentral:SpawnNpcIntroQuest(quest_name, npc_prefab)
    return self:GetQuestManager():SpawnQuest(quest_name, nil, nil, { giver = self:GetNpcCastForPrefab(npc_prefab), } )
end

function QuestCentral:_OnEndRun(data)
    -- TODO(dbriscoe): How to tell that player hasn't had a run this run of the
    -- exe? Write false on game start?
    self.persistdata.had_run = true
    self.persistdata.was_last_run_victorious = data.is_victory
end

function QuestCentral:GetDungeonBossForLocation(location_actor)
    local biome_location = location_actor:GetBiomeLocation()
    if biome_location.monsters then
        return self:_GetCastForPrefab(biome_location.monsters.bosses[1], self:GetCastManager():GetEnemyNodes())
    end
end

function QuestCentral:GetRandomDungeon()
    -- TODO(dbriscoe): Get an actual random dungeon.
    if not self.locations.random_hack then
        self.locations.random_hack = self:_GetLocation(biomes.locations.treemon_forest.id)
    end
    return self.locations.random_hack
end

-- Passthrough Functions -----

function QuestCentral:GetCurrentLocation()
    return self:GetCastManager():GetCurrentLocation()
end

function QuestCentral:_GetLocation(...)
    return self:GetCastManager():_GetLocation(...)
end

function QuestCentral:_GetCastForPrefab( ... )
    return self:GetCastManager():_GetCastForPrefab(...)
end

function QuestCentral:GetLocationActor(...)
    return self:GetCastManager():GetLocationActor(...)
end

function QuestCentral:AllocateEnemy(...)
    return self:GetCastManager():AllocateEnemy(...)
end

function QuestCentral:AllocateInteractable(...)
    return self:GetCastManager():AllocateInteractable(...)
end

------------------------------

function QuestCentral:_AddMarkedActor(actor, importance)
    -- Check if this actor is already marked. If yes, then only use the higher importance ranking.
    if self.marked_actors[actor] and QUEST_IMPORTANCE.id[importance] <= QUEST_IMPORTANCE.id[self.marked_actors[actor]] then
        return
    end

    self.marked_actors[actor] = importance
end

function QuestCentral:_AddMarkedLocation(location, importance)
    -- Check if this location is already marked. If yes, then only use the higher importance ranking.
    if self.marked_locations[location] and QUEST_IMPORTANCE.id[importance] <= QUEST_IMPORTANCE.id[self.marked_locations[location]] then
        return
    end

    self.marked_locations[location] = importance
end

local function _AddMark(tbl, mark, importance)
    if tbl[mark] and QUEST_IMPORTANCE.id[importance] <= QUEST_IMPORTANCE.id[tbl[mark]] then
        return
    end

    tbl[mark] = importance
end

local function _ConvertCastToLocationID(quest, cast)
    local location_id = cast
    local location_cast = quest:GetCastMember(location_id)

    if location_cast and location_cast:is_a(RotwoodLocation) then
        location_id = location_cast.id
    end

    return location_id
end

function QuestCentral:CollectQuestMarks()
    local quests = self:GetQuestManager():GetQuests()

    local marked_actors = {}
    local marked_locations = {}

    for _, quest in ipairs(quests) do
        -- first, look through every conversation the player can have
        for hook_type, hooks in pairs(quest.def.convo_hooks) do
            for _, hook in ipairs(hooks) do
                local objective = quest.def.objective[hook.objective_id]
                local cast = quest:GetCastMember(hook.cast_id)

                local is_active = quest:GetObjectiveState(hook.objective_id) == QUEST_OBJECTIVE_STATE.s.ACTIVE
                local cast_is_present = cast.inst ~= nil

                -- the rate-limit filtering is handled in the hook.fn, as this should be called after :EvaluateTownChats()
                local is_valid = is_active and cast_is_present and hook.fn(quest, cast, self)

                if is_valid then
                    if objective:GetImportance() ~= QUEST_IMPORTANCE.s.LOW then
                        -- by default, mark the cast of the convo
                        _AddMark(marked_actors, cast, objective:GetImportance())
                    end
                end
            end
        end

        for objective_id, objective in pairs(quest.def.objective) do
            local is_active = quest:GetObjectiveState(objective_id) == QUEST_OBJECTIVE_STATE.s.ACTIVE
            local is_valid = is_active

            if is_valid then
                if objective:GetImportance() ~= QUEST_IMPORTANCE.s.LOW then
                    -- objectives can also optionally define additional cast members to be marked.
                    for _, id in ipairs(objective:GetMarkedCast()) do
                        local addtl_marked_cast = quest:GetCastMember(id)
                        if addtl_marked_cast.inst ~= nil then
                            _AddMark(marked_actors, addtl_marked_cast, objective:GetImportance())
                        end
                    end
                end
            end
        end

        -- we only need to mark locations if we're in the town
        if TheWorld:HasTag("town") then
            local base_locations = quest:GetMarkedLocations()
            for _, location in ipairs(base_locations) do
                _AddMark(marked_locations, _ConvertCastToLocationID(quest, location), quest:GetImportance())
            end
            -- next, look through every quest objective the player has (not every objective has a conversation attached to it)
            for id, objective in pairs(quest.def.objective) do
                local is_active = quest:GetObjectiveState(id) == QUEST_OBJECTIVE_STATE.s.ACTIVE
                local obj_marked_locations = objective:GetMarkedLocations()

                if is_active and obj_marked_locations ~= nil and #obj_marked_locations > 0 then
                    -- add to list of marked locations

                    for _, location in ipairs(obj_marked_locations) do
                        _AddMark(marked_locations, _ConvertCastToLocationID(quest, location), objective:GetImportance())
                    end
                end
            end
        end
    end

    return marked_actors, marked_locations
end

function QuestCentral:EvaluateTownChats()
	-- Stops this from being called if the player isn't in town, or has not selected their character yet.
    if not TheWorld:HasTag("town") or not self:GetQuestManager():HasEverHadQuests() or self.selected_town_chats ~= nil then return end

    -- loop through all currently active quests
    -- if they have valid hooks, then add to list to be filtered
    local quests = self:GetQuestManager():GetQuests()
    local valid_chats = {}

    for _, quest in ipairs(quests) do
        local convo_hooks = quest.def.convo_hooks
        for hook_type, hooks in pairs(convo_hooks) do
            for _, hook in ipairs(hooks) do
                local objective = quest.def.objective[hook.objective_id]
                local cast = quest:GetCastMember(hook.cast_id)
                local is_active = quest:GetObjectiveState(hook.objective_id) == QUEST_OBJECTIVE_STATE.s.ACTIVE
                local is_limited = objective:IsRateLimited()
                local cast_is_present = cast.inst ~= nil
                local is_valid = is_active and is_limited and cast_is_present and hook.fn(quest, cast, self)

                if is_valid then
                    table.insert(valid_chats, {
                        quest = quest,
                        -- quest_name = quest._classname,

                        -- objective = objective,
                        objective_id = hook.objective_id,

                        cost = objective:GetChatCost(),
                        priority = objective:GetPriority(),

                        -- hook = hook,
                        cast = cast,
                    })
                end

            end
        end
    end

    -- We tried to evaluate too early (remote client before NPCs have spawned in?)
    -- return now so we can retry with a later event.
    if #valid_chats == 0 then return end

    -- filter hooks by quest and objective priority
    -- make list of valid quest/ objective pairs that can be advanced this time
    table.sort(valid_chats, function(a, b)
        if a.priority == b.priority then
            return a.cost < b.cost
        end
        return a.priority > b.priority
    end)

    local remaining_budget = TOWN_CHAT_BUDGET
    local selected_cast_members = {}
    self.selected_town_chats = {}

    for _, chat in ipairs(valid_chats) do
        if chat.cost <= remaining_budget and not selected_cast_members[chat.cast] then
            self:InsertTownQuest(chat.quest, chat.objective_id)
            selected_cast_members[chat.cast] = true
            remaining_budget = remaining_budget - chat.cost
        end

        if table.count(self.selected_town_chats) >= MAX_CHATS_PER_TOWN_VISIT or remaining_budget <= 0 then
            break
        end
    end

    self:UpdateQuestMarks()
end

function QuestCentral:InsertTownQuest(quest, objective_id)
    -- don't need to do this if we aren't in the town
    if not self.selected_town_chats then
        self:EvaluateTownChats()

        if self.selected_town_chats == nil then
            -- We tried to evaluate proper town chats and still don't have any.
            -- Just make an empty table so we can put this new quest in it.
            self.selected_town_chats = {}
        end
    end

    if TheWorld:HasTag("town") and not self.selected_town_chats[quest] then
        -- assert(self.selected_town_chats[quest] == nil, string.format("Quest already has selected objective in selected_town_chats (%s)", quest))

        local remove_fn = nil

        remove_fn = function()
            if quest:IsComplete(objective_id) then
                lume.remove(self.selected_town_chats[quest], objective_id)
                if #self.selected_town_chats[quest] == 0 then
                    self.selected_town_chats[quest] = nil
                end
                self.inst:RemoveEventCallback("quest_updated", remove_fn, self:GetQuestManager().inst)
                remove_fn = nil
            end
        end

        self.inst:ListenForEvent("quest_updated", remove_fn, self:GetQuestManager().inst)

        if not self.selected_town_chats[quest] then
            -- usually only one objective will be active per quest
            -- but it is possible to force multiple objectives to be active so we need to support it.
            self.selected_town_chats[quest] = {}
        end

        table.insert(self.selected_town_chats[quest], objective_id)
    end
end

function QuestCentral:GetTownQuests()
    return self.selected_town_chats
end

-- TODO(dbriscoe): Rename to GetDay and actually track and saveload the day.
function QuestCentral:GetCyclesPassed()
    return 1
end

function QuestCentral:WasLastRunVictorious()
    return self.persistdata.had_run and self.persistdata.was_last_run_victorious
end

function QuestCentral:RenderDebugUI(ui, panel)
    if ui:Button("QuipMatcher") then
        panel:PushDebugValue(self.quipmatcher)
    end
end


-------------------------------------------------------------------------------------------------
--------------------------------- Repeatable Quest Logic ----------------------------------------
-- player.components.questcentral:SpawnRepeatableQuest()
-- player.components.questcentral:DebugSpawnRepeat()

function QuestCentral:DebugSpawnRepeat()
    self:GetQuestManager():SpawnQuestByType(Quest.QUEST_TYPE.s.JOB, {"repeatable"}, {}, {giver = self:_GetCastForPrefab("npc_scout", self:GetCastManager():GetNPCNodes())})
end

function QuestCentral:GetActiveRepeatableQuests()
    local qm = self:GetQuestManager()
    local active_quests = qm:GetQuests()
    local repeatable_quests = {}

    for _, quest in pairs(active_quests) do
        if quest.def.tags:has("repeatable") then
            table.insert(repeatable_quests, quest)
        end
    end

    return repeatable_quests
end

-- TODO: this whole thing needs to be redone
function QuestCentral:HasAvailableRewards()
    -- local rewards =
    -- {
    --     "stone_lamp", "well", "kitchen_barrel", "kitchen_sign", "outdoor_seating",
    --     "outdoor_seating_stool", "chair1", "chair2", "street_lamp","bench_megatreemon",
    --     "hammock", "plushies_lrg", "plushies_mid", "plushies_sm", "plushies_stack",
    --     "wooden_cart", "weapon_rack", "tanning_rack", "dye1", "dye2", "dye3", "leather_rack"
    -- }

    -- for _, reward in ipairs(rewards) do
    --  if not TheWorld:IsUnlocked(reward) then
    --      return true
    --  end
    -- end

    return false
end

function QuestCentral:SpawnRepeatableQuest()
    local repeatable_quests = self:GetActiveRepeatableQuests()
    if #repeatable_quests >= self.max_repeatable_quests then
        print ("COULD NOT SPAWN QUEST: MAX ACTIVE QUESTS REACHED")
        return
    end

    if not self:HasAvailableRewards() then
        print ("COULD NOT SPAWN QUEST: NO AVAILABLE REWARDS")
        return
    end

    local qm = self:GetQuestManager()
    local active_quests = qm:GetQuests()
    local busy_npcs = {}

    for _, quest in pairs(active_quests) do
        if not quest.def.tags:has("shop") and not quest.def.tags:has("fallback") then
            for _, cast in pairs(quest.cast_members) do
                if cast.inst ~= nil and not table.contains(busy_npcs, cast.inst) and cast.inst.components.npc ~= nil then
                    --print ("NPC is busy:", quest, cast.inst)
                    table.insert(busy_npcs, cast.inst)
                end
            end
        end
    end

    local available_npcs = {}
    for _,v in pairs(self.npcs) do
        if not table.contains(busy_npcs, v) then
            table.insert(available_npcs, v.prefab)
        end
    end

    local quest = nil
    while (#available_npcs > 0) do
        local npc_prefab = table.remove(available_npcs, math.random(1, #available_npcs))
        local cast = self:_GetCastForPrefab(npc_prefab, self:GetCastManager():GetNPCNodes())
        quest = qm:SpawnQuestByType(Quest.QUEST_TYPE.s.JOB, {"repeatable"}, {}, {npc_prefab}, {giver = cast})

        if quest ~= nil then
            break
        end
    end

    if quest == nil then
        print ("COULD NOT SPAWN QUEST: SPAWN FAILED")
        return nil
    end

    return quest
end

------ Network Sync Logic


function QuestCentral:OnHostQuestCompleted(playerID, contentID, objectiveID, state)
    local quest = self:GetQuestManager():FindQuestByID(contentID)
    if quest and quest:IsActive() and quest:IsActive(objectiveID) then
        quest:_SetObjectiveState(objectiveID, state, playerID)
    end
end

function QuestCentral:ValidateRemoteQuestCompleted(playerID, contentID, objectiveID, state)

    -- validate that this quest even CAN be completed. If it can, call HostQuestCompleted.
    local quest = self:GetQuestManager():FindQuestByID(contentID)
    if quest and quest:IsActive() and quest:IsActive(objectiveID) then
        local can_complete_quest = false

        local objective_has_hooks = false

        for hook_type, hooks in pairs(quest.def.convo_hooks) do
            for _, hook in ipairs(hooks) do
                -- loop through all hooks that have this objectiveID
                if hook.objective_id == objectiveID then

                    objective_has_hooks = true

                    local cast = quest:GetCastMember(hook.cast_id)
                    if cast and cast:is_a(RotwoodActor) and cast.inst ~= nil then 
                        cast:OverrideInteractingPlayerEntity(self:GetPlayer())
                        -- if this hook is valid, then the quest can be completed.
                        can_complete_quest = hook.fn(quest, cast, self)
                        cast:OverrideInteractingPlayerEntity(nil)
                    end
                end

                if can_complete_quest then
                    break
                end
            end

            if can_complete_quest then
                break
            end
        end

        if not objective_has_hooks then
            can_complete_quest = true
        end

        return can_complete_quest
    end

    return false
end

-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------

return QuestCentral
