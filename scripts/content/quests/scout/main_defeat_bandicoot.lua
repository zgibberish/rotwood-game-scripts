local Convo = require "questral.convo"
local Quest = require "questral.quest"
local Quip = require "questral.quip"
local biomes = require "defs.biomes"
local quest_helper = require "questral.game.rotwoodquestutil"
local playerutil = require"util/playerutil"

------------------------------------------------------------------

local quest_strings = require("strings.strings_npc_scout").QUESTS.main_defeat_bandicoot

local Q = Quest.CreateMainQuest()
Q:SetIsImportant()
Q:SetPriority(QUEST_PRIORITY.HIGHEST)

Q:TitleString(quest_strings.TITLE) -- use String for all pretty text
Q:DescString(quest_strings.DESC)

Q:Icon("images/ui_ftf_dialog/convo_quest.tex")

function Q:Quest_Complete()
	-- spawn next main quest in chain
	-- self:GetQuestManager():SpawnQuest("twn_unlock_shotput")
end

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForPrefab("npc_scout")

Q:AddCast("target_dungeon")
	:CastFn(function(quest, root)
		return root:GetLocationActor(biomes.locations.kanft_swamp.id)
	end)

Q:MarkLocation{"target_dungeon"}

Q:AddCast("miniboss")
	:CastFn(function(quest, root)
		return root:AllocateEnemy("groak_elite")
	end)

Q:AddCast("last_boss")
	:CastFn(function(quest, root)
		return root:AllocateEnemy("owlitzer")
	end)

Q:AddCast("boss")
	:CastFn(function(quest, root)
		return root:AllocateEnemy("bandicoot")
	end)

local did_startup = false

local function FirstSwampRun(quest)
	if quest:IsActive("quest_intro") then
		local giver = quest:GetCastMember("giver")
		if giver and giver.inst then
			giver.inst:AddComponent("roomlock")
		end
	end
end

local function IsInSwamp(quest, prefab)
	local location = TheDungeon:GetDungeonMap().nav:GetBiomeLocation()
	return location.id == "kanft_swamp"
end

------OBJECTIVE DECLARATIONS------

Q:AddObjective("quest_intro")
	:OnActivate(function(quest)
		-- region and location
		local player = quest:GetPlayer()
		player:UnlockRegion("swamp")
		player:UnlockLocation("kanft_swamp")
	end)
	:AppearInDungeon_Entrance(IsInSwamp)
	:OnEvent("playerentered", function(quest)
		-- if you're in the dungeon entrance and in the swamp...
		if IsInSwamp()
			and Quest.Filters.InDungeon_Entrance(quest) -- debug jumped from entrance?
			and not did_startup -- could have multiple players
		then
			did_startup = true
			TheWorld:DoTaskInTicks(30, function() FirstSwampRun(quest) end)
		end
	end)
	:OnEvent("exit_room", function(quest)
		if IsInSwamp(quest) and Quest.Filters.InDungeon_Entrance(quest) then
			-- ok, you somehow left the first room of the swamp without completing this objective.
			-- for now, just complete the objective and move on with the quest.
			-- long term solution we need to poll each player's quest state and not allow the room to unlock if it should be locked for any player.
			quest:Complete("quest_intro")
		end
	end)
	:OnComplete(function(quest)
		local giver = quest:GetCastMember("giver")
		if giver and giver.inst then
			giver.inst:RemoveComponent("roomlock")
		end

		quest:ActivateObjective("pre_miniboss_death_convo")
			:ActivateObjective("find_target_miniboss")

	end)

Q:AddObjective("pre_miniboss_death_convo")
	:OnComplete(function(quest)
		quest:Complete("quest_intro") -- if this is still active somehow
	end)

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

Q:AddObjective("die_to_miniboss_convo")

Q:AddObjective("defeat_target_miniboss")

	:LogString("Defeat {miniboss}.")
	:OnComplete(function(quest)
		-- Unlock new weapons when defeating miniboss
		local player = quest:GetPlayer()

		player:UnlockRecipe("hammer_swamp")
		player:UnlockRecipe("polearm_swamp")
		player:UnlockRecipe("cannon_swamp1")
		player:UnlockRecipe("shotput_swamp1")

		quest:ActivateObjective("celebrate_defeat_miniboss")
		quest:ActivateObjective("find_target_boss")
		quest:Cancel("die_to_miniboss_convo")
		quest:GetQuestManager():SpawnQuest("twn_unlock_shotput")
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

Q:AddObjective("die_to_boss_convo")

Q:AddObjective("defeat_target_boss")
	:LogString("Defeat the {boss}.")
	:OnComplete(function(quest)
		quest:ActivateObjective("celebrate_defeat_boss")
		quest:Cancel("die_to_boss_convo")
	end)

Q:AddObjective("celebrate_defeat_boss")
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

------CONVERSATIONS AND QUESTS------


Q:OnDungeonChat("quest_intro", "giver", function(...) return IsInSwamp() and Quest.Filters.InDungeon_Entrance(...) end)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings.quest_intro)
	:Fn(function(cx)
		--used to keep track of if player has clicked the acid and/or the spore explainer yet
		local acidspore_btnstates = {}
		acidspore_btnstates = { false, false }

		--option that ends the conversation at the end of every dialogue branch
		local function Opt3B_EndConvo()
			cx:AddEnd("OPT_3B")
				:MakePositive()
				:Fn(function()
					cx:Talk("TALK2")
					cx.quest:Complete("quest_intro")
				end)
		end

		--used in AcidSporeMenu() to discuss the bandicoot, then end the conversation
		local function DescribeRotBossAndExit(btn_txt)
			cx:Opt(btn_txt) --end convo
				:MakePositive()
				:Fn(function()
					cx:Talk("OPT2C_RESPONSE")
					Opt3B_EndConvo()
				end)
		end

		--used to explain the concept of Acid and Spores
		local function AcidSporeMenu(opt2C_alt_text)
			if acidspore_btnstates[1] == false then --player hasn't done the acid explainer yet
				
				--player hasnt done either explainer, show all buttons with no alt text
				if acidspore_btnstates[2] == false then 
					cx:Opt("OPT_2A") --acid
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT2A_RESPONSE")
						acidspore_btnstates[1] = true
						AcidSporeMenu(opt2C_alt_text)
					end)
					cx:Opt("OPT_2B") --spores
						:MakePositive()
						:Fn(function()
							cx:Talk("OPT2B_RESPONSE")
							acidspore_btnstates[2] = true
							AcidSporeMenu(opt2C_alt_text)
						end)
					DescribeRotBossAndExit("OPT_2C") --end convo

				--player's hasnt done the acid explainer but already did the spore explainer, give acid and exit convo button their alt text
				else 
					cx:Opt("OPT_2A_ALT") --acid
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT2A_RESPONSE")
						acidspore_btnstates[1] = true
						AcidSporeMenu(opt2C_alt_text)
					end)
					DescribeRotBossAndExit(opt2C_alt_text) --end convo (alt text)
				end
			else --player's already done the acid explainer

				--player hasnt done the spore explainer but already did the acid explainer, give spore + end convo buttons their alt text
				if acidspore_btnstates[2] == false then
					cx:Opt("OPT_2B_ALT") --spore
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT2B_RESPONSE")
						acidspore_btnstates[2] = true
						AcidSporeMenu(opt2C_alt_text)
					end)
					DescribeRotBossAndExit(opt2C_alt_text) --end convo (alt text)
				--player's done both explainers, show end convo button with alt text
				else
					DescribeRotBossAndExit(opt2C_alt_text) --end convo (alt text)
				end
			end
		end

		cx:Talk("TALK")
		cx:Opt("OPT_1A") --player's never been to the swamp before
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1A_RESPONSE")
				AcidSporeMenu("OPT_2C_ALT")
			end)
		cx:Opt("OPT_1B") --player says they've been to the swamp before and probably wants to skip chatting
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1B_RESPONSE")

				AcidSporeMenu("OPT_3A")
				Opt3B_EndConvo()
			end)
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
	:TalkAndCompleteQuestObjective("TALK_FIRST_BOSS_KILL")

return Q
