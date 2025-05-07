local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"
local quest_strings = require("strings.strings_npc_armorsmith").QUESTS.megatreemon

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGH)

function Q:Quest_Validate()
	return not self:GetPlayer():IsFlagUnlocked("pf_first_miniboss_defeated")
end


Q:SetIsImportant()

Q:UpdateCast("giver")
	:FilterForPrefab("npc_armorsmith")

Q:AddCast("miniboss")
	:CastFn(function(quest, root)
		return root:AllocateEnemy("yammo_elite")
	end)

Q:AddObjective("miniboss_tip")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)
		quest:Complete()
	end)

local function is_struggling_on_miniboss(runs, quest, node, sim)
	--player
	local player = quest:GetPlayer()

	-- player has done at least 3 runs, has seen yammo, but has not killed yammo.
	local num_runs = player.components.progresstracker:GetValue("total_num_runs") or 0
	local has_seen_miniboss = player:IsFlagUnlocked("pf_first_miniboss_seen")
	local has_killed_miniboss = player:IsFlagUnlocked("pf_first_miniboss_defeated")

	local is_struggle = num_runs >= runs and has_seen_miniboss and not has_killed_miniboss
	--~ TheLog.ch.Quest:print("twn_miniboss_tips - is_struggling_on_miniboss", num_runs, has_seen_miniboss, has_killed_miniboss, is_struggle)
	return is_struggle
end

Q:OnTownChat("miniboss_tip", "giver", function(...) return is_struggling_on_miniboss(3, ...) end)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings.armor_hint)
	:Fn(function(cx)
		cx:Talk("TALK")
		cx.quest:Complete("miniboss_tip")
		cx:End()
	end)

return Q
