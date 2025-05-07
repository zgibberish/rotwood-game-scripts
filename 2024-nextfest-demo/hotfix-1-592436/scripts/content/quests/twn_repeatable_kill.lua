local Quest = require "questral.quest"
local krandom = require "util.krandom"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_generic").QUESTS.twn_repeatable_kill

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.NORMAL)

Q:AddTags({"repeatable"})

Q:TitleString(quest_strings.TITLE)

Q:SetCastCandidates({"npc_blacksmith", "npc_armorsmith", "npc_refiner", "npc_cook", "npc_apothecary"})

Q:AddCast("target")
	:CastFn(function(quest, root)
		local mobs = quest_helper.GetAllDiscoveredMobs()
		local mob
		if #mobs > 0 then
			mob = krandom.PickFromArray(mobs)
		else
			mob = "cabbageroll" -- Fail safe
		end
		return root:AllocateEnemy(mob)
	end)

Q:AddVar("reward", "PLACEHOLDER")
Q:AddVar("kill_count", 0)
Q:AddVar("kill_amount", math.random(3, 10))

Q:OnEvent("player_kill", function(quest, victim)
	if not quest:IsActive("hunt_target") then
		return false
	end

	local player = quest:GetPlayer()

	if player and player.components.health:IsDead() then
		return false
	end

	if victim.prefab == quest:GetCastMember("target").prefab then
		local count = quest:GetVar("kill_count")
		count = count + 1
		if count >= quest:GetVar("kill_amount") then
			quest:Complete("hunt_target")
		else
			quest:SetVar("kill_count", count)
		end
	end
end)

Q:AddObjective("present_quest")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)
		quest:ActivateObjective("hunt_target")
	end)

Q:AddObjective("hunt_target")
	:OnComplete(function(quest) 
		quest:ActivateObjective("talk_post_hunt")
	end)

Q:AddObjective("talk_post_hunt")
	:OnComplete(function(quest)
		quest:Complete()
	end)

function Q:Quest_Complete()
	-- TODO: Mark it as done and add it back to the pool?
	print("###### QUEST COMPLETED")
end

Q:OnTownChat("present_quest", "giver")
	:FlagAsTemp()
	:Strings(quest_strings.present_quest)
	:Fn(function(cx)
		quest_helper.PickReward(cx)

		cx:Talk("INTRODUCE_QUEST")
		
		cx:Opt("OPT_OK")
			:CompleteObjective()
			:Fn(function(cx) 
				cx:Talk("TALK_THANKS")
				quest_helper.PushShopChat(cx, true)
			end)
		
		cx:Opt("CANCEL")
			:Fn(function()
				quest_helper.PushShopChat(cx, true)
			end)
	end)


Q:OnTownChat("hunt_target", "giver")
	:FlagAsTemp()
	:Strings(quest_strings.hunt_target)
	:Fn(function(cx)
		local agent = cx.quest:GetCastMember("giver")
		if not agent.reminded then -- HACK
			agent.reminded = true
			cx:Talk("TALK_REMINDER")
			quest_helper.PushShopChat(cx, true)
		else
			quest_helper.PushShopChat(cx)
		end

	end)

Q:OnTownChat("talk_post_hunt", "giver")
	:FlagAsTemp()
	:Strings(quest_strings.talk_post_hunt)
	:Fn(function(cx)
		cx:Talk("TALK_DELIVERY")
		cx:Opt("OPT_YES")
		:Fn(function(cx) 
				quest_helper.GiveReward(cx)
			end)
			:CompleteObjective()
	end)

return Q
