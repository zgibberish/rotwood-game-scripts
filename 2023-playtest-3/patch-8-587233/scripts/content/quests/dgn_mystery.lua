local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_specialeventhost").QUESTS.dgn_mystery

local Q = Quest.CreateRecurringChat()


Q:SetIsUnimportant()

Q:TitleString(quest_strings.TITLE)

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForRole(Npc.Role.s.specialeventhost)

------FUNCTIONS------

local function StartMysteryEvent(cx)
	local node = quest_helper.GetGiver(cx)
	local inst = node.inst
	local player = node:GetInteractingPlayerEntity()
	local erm = inst.specialeventroommanager
	erm.components.specialeventroommanager:StartEvent(player)
end

--See if the interacting player specifically has used the event-- Used state does not carry over between rooms
local function CheckEventUsed(inst, player)
	--if players dont have a used_event state set up, make one and default to false
	if not inst.components.conversation.temp.used_event then
		inst.components.conversation.temp.used_event = {}
		for i=1,#AllPlayers do
			inst.components.conversation.temp.used_event[AllPlayers[i]] = false
		end
	end

	return inst.components.conversation.temp.used_event[player]
end

--After completing an event, mark it as used. Used state does not carry over between rooms 
local function SetEventUsed(cx)

	local node = quest_helper.GetGiver(cx)
	local inst = node.inst
	local player = node:GetInteractingPlayerEntity()

	-- Only persists in the current room -- not in next room.
	if not inst.components.conversation.temp.used_event then
		inst.components.conversation.temp.used_event = {}
		for i=1,#AllPlayers do
			inst.components.conversation.temp.used_event[AllPlayers[i]] = true
		end
	end

	inst.components.conversation.temp.used_event[player] = true

end

local function Filter_CorrectEventAndNotUsed(quest, node, sim, objective_id)
	local inst = node.inst
	local erm = inst.specialeventroommanager
	local eventname = erm and erm.components.specialeventroommanager.selectedevent.name or ""
	local player = node:GetInteractingPlayerEntity()

	local correct_event = eventname == objective_id
	local used = CheckEventUsed(inst, player)

	return correct_event and not used
end

local function Filter_TestPrototype(quest, node, sim, objective_id)
	local inst = node.inst
	local erm = inst.specialeventroommanager
	local eventname = erm and erm.components.specialeventroommanager.selectedevent.name or ""

	return eventname == TheSaveSystem.cheats:GetValue("test_minigame")
end

------OBJECTIVE DECLARATIONS------

-- NOTE TO WRITERS:
-- The objective ID here MUST match the ID of the special event itself. Check conversationspecialeventrooms.lua.

Q:AddObjective("done")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("chat_only")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

--Raises max health or damages them (currently does 250dmg)
Q:AddObjective("coin_flip_max_health_or_damage")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("free_power_epic")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("free_power_legendary")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("potion_refill")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

--[[
	-- these are disabled because of a bug that causes them to crash since the event opens a screen and ends the conversation
Q:AddObjective("lose_power_gain_health")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)
		SetEventUsed(quest:GetPlayer())
	end)

Q:AddObjective("transmute_power")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)
		SetEventUsed(quest:GetPlayer())
	end)
--]]

Q:AddObjective("upgrade_random_power")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

-- Minigames

Q:AddObjective("event_prototype")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("bomb_game")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("dodge_game")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("dps_check")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("hit_streak")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("mini_cabbage_swarm")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

------CONVERSATIONS AND QUESTS------

Q:OnAttract("chat_only", "giver", function(quest, node, sim)
	-- Only when he has nothing else to say.
	return true
end)
	:SetPriority(Convo.PRIORITY.LOWEST)
	:Strings(quest_strings.chat_only)
	:Fn(function(cx)
		cx:Talk("TALK_CHAT_ONLY")

		cx:AddEnd("OPT_NEXT_TIME")
	end)

Q:OnAttract("done", "giver", function(quest, node, sim)
	local inst = node.inst
	local player = node:GetInteractingPlayerEntity()
	return CheckEventUsed(inst, player) == true
end)
	:Strings(quest_strings.done)
	:Fn(function(cx)

		cx:Talk("TALK_DONE")

		cx:AddEnd("OPT_EXIT")
	end)

local function FlipChoice(cx, choice)
	local node = quest_helper.GetGiver(cx)
	local inst = node.inst
	local player = node:GetInteractingPlayerEntity()
	local erm = inst.specialeventroommanager
	erm.player_choices[player] = choice
	erm.components.specialeventroommanager:StartEvent(player)
end

--Puts the player to full health or damages them (currently does 250dmg)
Q:OnAttract("coin_flip_max_health_or_damage", "giver", Filter_CorrectEventAndNotUsed)
	:Strings(quest_strings.coin_flip_max_health_or_damage)
	:Fn(function(cx)
		cx:Talk("TALK_COIN_FLIP_MAX_HEALTH_OR_DAMAGE")

		--"choiceStr" should be either "heads" or "tails"
		local function Opt_HeadsTails(choiceStr)
			FlipChoice(cx, choiceStr)
			quest_helper.ConvoCooldownGiver(cx, 5)
			cx:End()
			SetEventUsed(cx)
		end

		cx:Opt("OPT_HEADS")
			:MakePositive()
			:Fn(function()
				Opt_HeadsTails("heads")
			end)

		cx:Opt("OPT_TAILS")
			:MakePositive()
			:Fn(function()
				Opt_HeadsTails("tails")
			end)

		cx:AddEnd("OPT_BACK")
end)

Q:OnAttract("free_power_epic", "giver", Filter_CorrectEventAndNotUsed)
	:Strings(quest_strings.free_power_epic)
	:Fn(function(cx)
		cx:Talk("TALK_FREE_POWER_EPIC")

		cx:Opt("OPT_ACCEPT")
			:MakePositive()
			:Fn(function()
				StartMysteryEvent(cx)
				quest_helper.ConvoCooldownGiver(cx, 5)
				cx:End()
				SetEventUsed(cx)
			end)

		cx:AddEnd("OPT_BACK")
	end)


Q:OnAttract("free_power_legendary", "giver", Filter_CorrectEventAndNotUsed)
	:Strings(quest_strings.free_power_legendary)
	:Fn(function(cx)
		cx:Talk("TALK_FREE_POWER_LEGENDARY")

		cx:Opt("OPT_ACCEPT")
			:MakePositive()
			:Fn(function()
				StartMysteryEvent(cx)
				cx:End()
				SetEventUsed(cx)
			end)

		cx:AddEnd("OPT_BACK")
	end)

 Q:OnAttract("potion_refill", "giver", Filter_CorrectEventAndNotUsed)
	:Strings(quest_strings.potion_refill)
	:Fn(function(cx)
		cx:Talk("TALK")

		cx:Opt("OPT_ACCEPT")
			:MakePositive()
			:Fn(function()
				StartMysteryEvent(cx)
				quest_helper.ConvoCooldownGiver(cx, 5)
				cx:End()
				SetEventUsed(cx)
			end)

		cx:AddEnd("OPT_BACK")
	end)

-- Q:OnAttract("lose_power_gain_health", "giver", Filter_CorrectEventAndNotUsed)
-- 	:Strings(quest_strings.LOSE_POWER_GAIN_HEALTH)
-- 	:Fn(function(cx)
-- 		cx:Talk("TALK_LOSE_POWER_GAIN_HEALTH")

-- 		cx:Opt("OPT_ACCEPT")
-- 			:MakePositive()
-- 			:Fn(function()
-- 				StartMysteryEvent(cx)
-- 				cx:End()
--				cx.quest:Complete("lose_power_gain_health")
-- 			end)

-- 		cx:AddEnd("OPT_BACK")
-- 	end)


-- Q:OnAttract("transmute_power", "giver", Filter_CorrectEventAndNotUsed)
-- 	:Strings(quest_strings.TRANSMUTE_POWER)
-- 	:Fn(function(cx)
-- 		cx:Talk("TALK_TRANSMUTE_POWER")

-- 		cx:Opt("OPT_ACCEPT")
-- 			:MakePositive()
-- 			:Fn(function()
-- 				StartMysteryEvent(cx)
-- 				cx:End()
--				cx.quest:Complete("transmute_power")
-- 			end)

-- 		cx:AddEnd("OPT_BACK")
-- 	end)


Q:OnAttract("upgrade_random_power", "giver", Filter_CorrectEventAndNotUsed)
	:Strings(quest_strings.upgrade_random_power)
	:Fn(function(cx)
		cx:Talk("TALK_UPGRADE_RANDOM_POWER")

		cx:Opt("OPT_ACCEPT")
			:MakePositive()
			:Fn(function()
				StartMysteryEvent(cx)
				cx:End()
				SetEventUsed(cx)
			end)

		cx:AddEnd("OPT_BACK")
	end)


--MINIGAMES: temporarily here for now

local function StartMinigameCountdown(cx)
	local node = quest_helper.GetGiver(cx)
	local inst = node.inst
	local player = node:GetInteractingPlayerEntity()
	local erm = inst.specialeventroommanager
	erm.components.specialeventroommanager:StartCountdown(player)
end

Q:OnAttract("event_prototype", "giver", Filter_TestPrototype)
	:Strings(quest_strings.event_prototype)
	:Fn(function(cx)
		cx:Talk("TALK_EVENT_PROTOTYPE")

		cx:Opt("OPT_ACCEPT")
			:MakePositive()
			:Fn(function()
				StartMinigameCountdown(cx)
				cx:End()
				SetEventUsed(cx)
			end)

		cx:AddEnd("OPT_BACK")
	end)


Q:OnAttract("bomb_game", "giver", Filter_CorrectEventAndNotUsed)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings.bomb_game)
	:Fn(function(cx)
		cx:Talk("TALK_BOMB_GAME")

		cx:Opt("OPT_ACCEPT")
			:MakePositive()
			:Fn(function()
				StartMinigameCountdown(cx)
				cx:End()
				SetEventUsed(cx)
			end)

		cx:AddEnd("OPT_BACK")
	end)


Q:OnAttract("dodge_game", "giver", Filter_CorrectEventAndNotUsed)
	:Strings(quest_strings.dodge_game)
	:Fn(function(cx)
		cx:Talk("TALK_DODGE_GAME")

		cx:Opt("OPT_ACCEPT")
			:MakePositive()
			:Fn(function()
				StartMinigameCountdown(cx)
				cx:End()
				SetEventUsed(cx)
			end)

		cx:AddEnd("OPT_BACK")
	end)


Q:OnAttract("dps_check", "giver", Filter_CorrectEventAndNotUsed)
	:Strings(quest_strings.dps_check)
	:Fn(function(cx)
		cx:Talk("TALK_DPS_CHECK")

		cx:Opt("OPT_ACCEPT")
			:MakePositive()
			:Fn(function()
				StartMinigameCountdown(cx)
				cx:End()
				SetEventUsed(cx)
			end)

		cx:AddEnd("OPT_BACK")
	end)


Q:OnAttract("hit_streak", "giver", Filter_CorrectEventAndNotUsed)
	:Strings(quest_strings.hit_streak)
	:Fn(function(cx)
		cx:Talk("TALK_HIT_STREAK")

		cx:Opt("OPT_ACCEPT")
			:MakePositive()
			:Fn(function()
				StartMinigameCountdown(cx)
				cx:End()
				SetEventUsed(cx)
			end)

		cx:AddEnd("OPT_BACK")
	end)


Q:OnAttract("mini_cabbage_swarm", "giver", Filter_CorrectEventAndNotUsed)
	:Strings(quest_strings.mini_cabbage_swarm)
	:Fn(function(cx)
		cx:Talk("TALK_MINI_CABBAGE_SWARM")

		cx:Opt("OPT_ACCEPT")
			:MakePositive()
			:Fn(function()
				StartMinigameCountdown(cx)
				cx:End()
				SetEventUsed(cx)
			end)

		cx:AddEnd("OPT_BACK")
	end)

return Q