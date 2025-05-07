local GameNode = require "questral.gamenode"
local kstring = require "util.kstring"
require "class"

local RepeatableQuestManager = Class(GameNode, function(self, inst)
	self.inst = inst

	-- TODO: QUEST REFACTOR - What does this do?
	self.quest_manager = ThePlayer.components.questcentral:GetQuestManager()

	--TODO
	-- Track NPCS
	-- Max repeatable quests param (per NPC count?)
	-- Spawn quests every x days

	-- EXTERNAL TODO:
	-- Add the shop hook
end)

function RepeatableQuestManager:__tostring()
    return string.format( "RepeatableQuestManager[%s %s]", self.inst, kstring.raw(self) )
end

function RepeatableQuestManager:SpawnQuest()
	local active_quests = self.quest_manager:GetQuests()
	local available_npcs = {}

	--TODO
	-- Count all active repeatable quests
	-- Get All NPCS in town
	-- Remove the ones already in a quest
	-- Spawn the appropriate quest

	self.quest_manager:SpawnQuestByType(Quest.QUEST_TYPE.s.JOB, {"repeatable"}, {}, available_npcs)
end

return RepeatableQuestManager
