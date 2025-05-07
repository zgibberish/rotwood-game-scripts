local Convo = require "questral.convo"
local Quest = require "questral.quest"
local recipes = require "defs.recipes"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_konjurist").QUESTS.first_meeting

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGHEST)



local function GetUpgradeablePowerCount(player)
	local powers = player.components.powermanager:GetUpgradeablePowers()
	return #powers
end

-- TODO(dbriscoe): Handle upgrade tracking with an objective.
local function CountUpgradesCompletedThisMeeting(inst, player)
	return inst.components.conversation.temp.upgrades_done and inst.components.conversation.temp.upgrades_done[player] or 0
end

local function OnDoUpgrade(inst, player)
	-- Only persists in the current room -- not in next room.
	if not inst.components.conversation.temp.upgrades_done then
		inst.components.conversation.temp.upgrades_done = {}
	end

	if not inst.components.conversation.temp.upgrades_done[player] then
		inst.components.conversation.temp.upgrades_done[player] = 0
	end

	inst.components.conversation.temp.upgrades_done[player] = inst.components.conversation.temp.upgrades_done[player] + 1
end

local function OpenUpgradeScreen(inst, player, cx)
	TheDungeon.HUD:HidePrompt(inst)

	local PowerSelectionScreen = require "screens.dungeon.powerselectionscreen"
	local powers = player.components.powermanager:GetUpgradeablePowers()
	local screen = PowerSelectionScreen(player, powers, PowerSelectionScreen.SelectAction.s.Upgrade, function()
		OnDoUpgrade(inst, player)
		quest_helper.ConvoCooldownGiver(cx, 145 * TICKS)
		inst:DoTaskInTicks(145, function()
			if GetUpgradeablePowerCount(player) > 0 then
				OpenUpgradeScreen(inst, player, cx)
			end
		end) --TODO: Roughly timed to upgrade anim length. With new conversation system, can maybe sequence this instead?
	end,
	inst.components.conversation.temp.upgrades_done == nil or -- Nobody has done any upgrades yet
		(inst.components.conversation.temp.upgrades_done and not inst.components.conversation.temp.upgrades_done[player]) or -- This player joined late and isn't in the list yet
		(inst.components.conversation.temp.upgrades_done and inst.components.conversation.temp.upgrades_done[player] and inst.components.conversation.temp.upgrades_done[player] == 0)) -- Someone has upgraded, they know about us, and we haven't done an upgrade yet.
	TheFrontEnd:PushScreen(screen)
end

local function OpenRemoveScreen(inst, player)
	-- Close prompt to ensure it doesn't activate during song.
	TheDungeon.HUD:HidePrompt(inst)
end

local function OnDoRemove(inst, player)
	-- remove_price:TakeIngredientsFromPlayer(player)
end

--the player's hunter species will be inserted here at runtime
Q:AddVar("species", "PLACEHOLDER")

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForRole("konjurist")

------OBJECTIVE DECLARATIONS------
function Q:Quest_Complete()
	self:GetQuestManager():SpawnQuest("dgn_seenmissingfriends_powerupgrade")
	TheDungeon.progression.components.runmanager:SetHasMetNPC(true)
end

Q:UnlockWorldFlagsOnComplete{"wf_konjurist"}

--first time you talk to Alki
Q:AddObjective("first_meeting")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)
		quest_helper.CompleteQuestOnRoomExit(quest)
	end)

quest_helper.AddCompleteQuestOnRoomExitObjective(Q)

------CONVERSATIONS AND QUESTS------

Q:OnAttract("first_meeting", "giver", function(quest, node, sim) return quest_helper.Filter_FirstMeetingSpecificNPC(quest, node, sim, "konjurist") end)
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings)
	:Fn(function(cx)
		local node = quest_helper.GetGiver(cx)
		local player = cx.quest:GetPlayer()

		local function CompleteQuest(chat_str)
			cx:Talk(chat_str)
			cx.quest:Complete('first_meeting')
		end

		local function EndConvo(chat_str)
			CompleteQuest(chat_str)
			cx:End()
		end

		cx:Talk("TALK")
		--ask who Alki is
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1A_RESPONSE")
			end)
		--ask what Alki's doing out here
		cx:Opt("OPT_1B")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1B_RESPONSE")
			end)

		cx:JoinAllOpt_Fn(function()
			cx:Talk("TALK2")

			--player asks for more conversation info
			cx:Opt("OPT_2A")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("OPT2A_RESPONSE")

					if GetUpgradeablePowerCount(player) > 0 then
						--player opens upgrade panel
						cx:Opt("OPT_3A")
							:MakePositive()
							:Fn(function(cx)
								EndConvo("OPT3A_RESPONSE")
								--Open Upgrade Panel
								OpenUpgradeScreen(node.inst, player, cx)
							end)
					end
					--player refuses getting upgrades
					cx:AddEnd("OPT_3B")
						:MakePositive()
						:Fn(function(cx)
							CompleteQuest("REFUSE_UPGRADE")
						end)
				end)
			if GetUpgradeablePowerCount(player) > 0 then
				--player skips conversation and goes straight to upgrade panel
				cx:Opt("OPT_2B")
					:MakePositive()
					:Fn(function(cx)
						EndConvo("OPT2B_RESPONSE")
						--Open Upgrade Panel
						OpenUpgradeScreen(node.inst, player, cx)
					end)
			end

			--player skips conversation and refuses upgrades (ends convo)
			cx:AddEnd("OPT_2C")
				:MakePositive()
				:Fn(function(cx)
					CompleteQuest("REFUSE_UPGRADE")
				end)
		end)
	end)

return Q
