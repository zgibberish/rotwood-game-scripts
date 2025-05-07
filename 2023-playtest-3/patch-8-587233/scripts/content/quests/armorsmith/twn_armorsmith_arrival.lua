local Quest = require "questral.quest"

local Q = Quest.CreateRecurringChat() -- don't want to save

Q:UpdateCast("giver")
	:FilterForPrefab("npc_armorsmith")

function Q:Quest_Start()
	-- Armoursmith moved into town. Spawn all related quests and *immediately
	-- complete* so we don't ever get called again. This is the most reliable
	-- way to spawn multiple quests in a single call (because we move them into
	-- town from multiple locations in code).
	local qman = self:GetQuestManager()
	-- qman:SpawnQuest("twn_miniboss_tips")
	qman:SpawnQuest("twn_shop_armor")
	self:Complete()
end

return Q
