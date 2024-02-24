local GameNode = require "questral.gamenode"
local kstring = require "util.kstring"


--------------------------------------------------------------
-- A quest-system representation of an entity. The entity may not exist in the
-- current world.
--
-- Called Entity in gln but this is a stripped down version. Our self.inst is
-- an EntityScript once it's spawned.
local QuestralActor = Class(GameNode)

-- *Do not define constructor*.  No overhead, no obligation to call. Lazy-instantiate all fields.

function QuestralActor:__tostring()
    return string.format( "QuestralActor[%s %s]", self.inst, self.prefab, kstring.raw(self) )
end

function QuestralActor:SetWaitingForSpawn(prefab_name)
    self.is_reservation = true
    self.prefab = prefab_name
    return self
end

-- Manually trigger the spawn instead of relying on save/load or something else
-- to spawn the entity.
function QuestralActor:SpawnReservation()
    if self.inst then
        return self.inst
    end
    assert(self.is_reservation, "Can only spawn if already reserved.")
    assert(self.prefab)
    -- FillReservation should assign self.inst when the entity registers.
    return SpawnPrefab(self.prefab)
end

-- Note: There's no callback for destruction. Listen to the onremove yourself.
function QuestralActor:OnFillReservation(fn)
    dbassert(fn, "Must provide callback. Clear is unsupported.")
    self.onfillreservationfns = self.onfillreservationfns or {}
    table.insert(self.onfillreservationfns, fn)
end

function QuestralActor:FillReservation(inst)
    dbassert(EntityScript.is_instance(inst))
    if inst == self.inst then
        -- Already filled reservation with the same entity. Don't need to rerun.
        return
    end

    if not self.is_reservation then
        TheLog.ch.Quest:printf("FillReservation on [%s] but not waiting for a reservation. Current self.inst=[%s], incoming inst=[%s], self.prefab=[%s]. Ignoring new spawn.", self, self.inst, inst, self.prefab)
        -- Common to debug spawn the same npc twice, so don't assert. Quest
        -- stuff might get weird.
        assert(TheInput:IsEditMode(), "Already filled this reservation. Likely we accidentally spawned two of the same npc?")
        return
    end

    self.inst = inst
    self.is_reservation = false

    self._ononremove = function(source)
        self.inst = nil
        self.is_reservation = true
    end
    self.inst:ListenForEvent("onremove", self._ononremove)
    -- Preview phantoms aren't real enough to count as npcs.
    self.inst:ListenForEvent("debug_spawned_as_preview", self._ononremove)

    if self.onfillreservationfns then
        for _,fn in ipairs(self.onfillreservationfns) do
            fn(self)
        end
    end
end

function QuestralActor:HasTag(tag)
    return self.inst and self.inst:HasTag(tag)
end

function QuestralActor:FillOutQuipTags(tag_dict)
    if self.tags then
        self.tags:FillDict(tag_dict)
    end

    if self.STATIC_TAGS then
        self.STATIC_TAGS:FillDict(tag_dict)
    end

    for k, quest in ipairs(self:GetQuests()) do
        tag_dict[quest:GetQuipID()] = true
    end

    for i, cmp in ipairs(self:GetChildren()) do
        if cmp.FillOutQuipTags then
            cmp:FillOutQuipTags( tag_dict )
        end
    end
end

function QuestralActor:IsCastInQuest(quest)
    if quest then
        return self.quest_membership and table.contains( self.quest_membership, quest )
    else
        return self.quest_membership ~= nil
    end
end

function QuestralActor:AddToQuest(quest)
    self.quest_membership = self.quest_membership or {}
    table.insert( self.quest_membership, quest )
end

function QuestralActor:RemoveFromQuest(quest)
    table.removearrayvalue( self.quest_membership, quest )
    if #self.quest_membership == 0 then
        self.quest_membership = nil
    end
end

function QuestralActor:GetQuestOfType( type )
    if self.quest_membership then
        for i, quest in ipairs( self.quest_membership ) do
            if quest:GetType() == type then
                return quest
            end
        end
    end
    return nil
end

function QuestralActor:GetQuests()
    return self.quest_membership or table.empty
end

function QuestralActor:CollectServices(t)
end

function QuestralActor:GetQC()
    return self:GetParent():GetQC()
end

return QuestralActor

