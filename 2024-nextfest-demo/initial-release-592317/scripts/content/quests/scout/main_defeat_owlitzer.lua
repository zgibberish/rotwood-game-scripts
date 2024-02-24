local Convo = require "questral.convo"
local Quest = require "questral.quest"
local Quip = require "questral.quip"
local biomes = require "defs.biomes"
local quest_helper = require "questral.game.rotwoodquestutil"

------------------------------------------------------------------

local quest_strings = require("strings.strings_npc_scout").QUESTS.main_defeat_owlitzer

local Q = Quest.CreateMainQuest()

Q:TitleString(quest_strings.TITLE) -- use String for all pretty text
Q:DescString(quest_strings.DESC)
Q:SetIsImportant()
Q:SetPriority(QUEST_PRIORITY.HIGHEST)
Q:Icon("images/ui_ftf_dialog/convo_quest.tex")

function Q:Quest_Complete()
	-- spawn next main quest in chain

	--[[
	-- Disabled for Next Fest build
	local intro_quest = self:GetQuestManager():SpawnQuest("main_defeat_bandicoot")
	intro_quest:ActivateObjective("quest_intro", true)
	--]]
end

Q:UpdateCast("giver")
	:FilterForPrefab("npc_scout")

Q:AddCast("target_dungeon")
	:CastFn(function(quest, root)
		return root:GetLocationActor(biomes.locations.owlitzer_forest.id)
	end)

Q:MarkLocation{"target_dungeon"}

Q:AddCast("miniboss")
	:CastFn(function(quest, root)
		return root:AllocateEnemy("gourdo_elite")
	end)

Q:AddCast("last_boss")
	:CastFn(function(quest, root)
		return root:AllocateEnemy("megatreemon")
	end)

Q:AddCast("boss")
	:CastFn(function(quest, root)
		return root:AllocateEnemy("owlitzer")
	end)

local function IsInGrove(quest, prefab)
	local location = TheDungeon:GetDungeonMap().nav:GetBiomeLocation()
	return location.id == "owlitzer_forest"
end

Q:AddObjective("quest_intro")
	:AppearInDungeon_Entrance(IsInGrove)
	:OnActivate(function(quest)
		quest:GetPlayer():UnlockLocation("owlitzer_forest")
		quest:ActivateObjective("find_target_miniboss")
	end)
	:UnlockPlayerFlagsOnComplete{"pf_can_meet_cook"}
	:OnComplete(function(quest)
		quest:ActivateObjective("pre_miniboss_death_convo")
	end)

Q:AddObjective("pre_miniboss_death_convo")

quest_helper.AddCompleteObjectiveOnCast(Q,
{
	objective_id = "find_target_miniboss",
	cast_id = "miniboss",
	on_complete_fn = function(quest)
		quest:Complete("quest_intro") -- if this is still active somehow
		quest:ActivateObjective("defeat_target_miniboss")
		quest:ActivateObjective("die_to_miniboss_convo")
		quest:Cancel("pre_miniboss_death_convo")
	end,
}):LogString("The {miniboss} was last sighted in {target_dungeon}.")
:UnlockPlayerFlagsOnComplete{"pf_owlitzer_miniboss_seen"}
:UnlockWorldFlagsOnComplete{"wf_owlitzer_miniboss_seen"}

Q:AddObjective("die_to_miniboss_convo")

Q:AddObjective("defeat_target_miniboss")
	:LogString("Defeat {miniboss}.")
	:UnlockPlayerFlagsOnComplete{"pf_owltizer_miniboss_defeated"}
	:UnlockWorldFlagsOnComplete{"wf_owltizer_miniboss_defeated"}
	:OnComplete(function(quest)
		quest:ActivateObjective("celebrate_defeat_miniboss")
		quest:ActivateObjective("find_target_boss")
		quest:Cancel("die_to_miniboss_convo")
	end)

Q:AddObjective("celebrate_defeat_miniboss")
	:LogString("{giver} won't believe what you encountered in the woods.")

quest_helper.AddCompleteObjectiveOnCast(Q,
{
	objective_id = "find_target_boss",
	cast_id = "boss",
	on_complete_fn = function(quest)
		quest:ActivateObjective("defeat_target_boss")
		quest:ActivateObjective("die_to_boss_convo")
		quest:Cancel("celebrate_defeat_miniboss")
	end,
}):LogString("The {boss} was last sighted in {target_dungeon}.")
:UnlockPlayerFlagsOnComplete{"pf_owlitzer_boss_seen"}
:UnlockWorldFlagsOnComplete{"wf_owlitzer_boss_seen"}

Q:AddObjective("die_to_boss_convo")

Q:AddObjective("defeat_target_boss")
	:LogString("Defeat the {boss}.")
	:OnComplete(function(quest)
		quest:ActivateObjective("celebrate_defeat_boss")
		quest:Cancel("die_to_boss_convo")
	end)

Q:AddObjective("celebrate_defeat_boss")
	:UnlockPlayerFlagsOnComplete{"pf_owlitzer_boss_defeated"}
	:UnlockWorldFlagsOnComplete{"wf_owlitzer_boss_defeated"}
	:SetRateLimited(false)
	:LogString("Tell {giver} of your triumph.")
	:OnComplete(function(quest)
		quest:Complete()
	end)

Q:OnEvent("player_seen", function(quest, ent)
	return quest_helper.CompleteObjectiveIfCastMatches(quest, "find_target_boss", "boss", ent.prefab)
		or quest_helper.CompleteObjectiveIfCastMatches(quest, "find_target_miniboss", "miniboss", ent.prefab)
end)

Q:OnEvent("player_kill", function(quest, victim)
	local player = quest:GetPlayer()
	if player and player.components.health:IsDead() then
		return false
	end

	return quest_helper.CompleteObjectiveIfCastMatches(quest, "defeat_target_boss", "boss", victim.prefab)
		or quest_helper.CompleteObjectiveIfCastMatches(quest, "defeat_target_miniboss", "miniboss", victim.prefab)
end)

Q:OnDungeonChat("quest_intro", "giver", function(...) return Quest.Filters.InDungeon_Entrance and quest_helper.IsInDungeon("owlitzer_forest") end)
	:FlagAsTemp()
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings.quest_intro)
	:Fn(function(cx)
		local function EndConvo()
			cx.quest:Complete("quest_intro")
			cx:End()
		end

		local function AskAboutBoss() --> must be complete to end the convo
			cx:AddEnd("OPT_1C")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1C_RESPONSE")
				cx:Opt("OPT_4A")
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT4A_RESPONSE")
						EndConvo()
					end)
				cx:Opt("OPT_4B")
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT4B_RESPONSE")
						EndConvo()
					end)
			end)
		end

		local function ChatAboutWind() --> optional chats about what the nocturne grove is like
			cx:Opt("OPT_2")
				:MakePositive()
				:Fn(function()
					cx:Talk("OPT2_RESPONSE")
					cx:Opt("OPT_3")
						:MakePositive()
						:Fn(function()
							cx:Talk("OPT3_RESPONSE")
							AskAboutBoss()
						end)
					AskAboutBoss()
				end)
			AskAboutBoss()
		end

		cx:Talk("TALK")
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1A_RESPONSE")
				ChatAboutWind()
			end)
		cx:Opt("OPT_1B")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1B_RESPONSE")
				ChatAboutWind()
			end)
		AskAboutBoss()
	end)

Q:OnTownChat("pre_miniboss_death_convo", "giver",
	function(quest, node, sim)
		local num_runs = quest:GetPlayer().components.progresstracker:GetValue("total_num_runs") or 0
		return num_runs > 0 and not sim:WasLastRunVictorious()
	end)
	:FlagAsTemp()
	:Strings(quest_strings.pre_miniboss_death_convo)
	:TalkAndCompleteQuestObjective("TALK_FIRST_PLAYER_DEATH")

-- Died during a fight against this cast member.
local function CreateCondition_DiedFighting(attacker_role)
	return function(quest, node, sim)
		local qplayer = quest:GetPlayer()
		if sim:WasLastRunVictorious() then
			-- if you won then you obviously didn't die
			return false
		end
		local prefab = quest:GetCastMemberPrefab(attacker_role)
		local seen = qplayer.components.unlocktracker:IsEnemyUnlocked(prefab)
		local defeated = qplayer.components.progresstracker:GetNumKills(prefab) > 0
		return seen and not defeated
	end
end

-- This would be if you were specifically defeated by that enemy.
local function CreateDiedToCondition(attacker_role)
	return function(quest, node, sim)
		return not sim:WasLastRunVictorious()
	end
end

Q:OnTownChat("die_to_miniboss_convo", "giver", CreateCondition_DiedFighting("miniboss"))
	:FlagAsTemp()
	:Strings(quest_strings.die_to_miniboss_convo)
	:TalkAndCompleteQuestObjective("TALK_DEATH_TO_MINIBOSS")

Q:OnTownChat("die_to_boss_convo", "giver", CreateCondition_DiedFighting("boss"))
	:FlagAsTemp()
	:Strings(quest_strings.die_to_boss_convo)
	:TalkAndCompleteQuestObjective("TALK_DEATH_TO_BOSS")

Q:OnTownChat("celebrate_defeat_miniboss", "giver")
	:FlagAsTemp()
	:Strings(quest_strings.celebrate_defeat_miniboss)
	:TalkAndCompleteQuestObjective("TALK_FIRST_MINIBOSS_KILL")

Q:OnTownChat("celebrate_defeat_boss", "giver")
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:FlagAsTemp()
	:Strings(quest_strings.celebrate_defeat_boss)
	:Fn(function(cx)
		cx:Talk("TALK_FIRST_BOSS_KILL")

		cx:AddEnd("OPT_1")
			:MakePositive()
			:Fn(function()
				cx:Talk("TALK2")
				cx.quest:Complete("celebrate_defeat_boss")
			end)
	end)

return Q
