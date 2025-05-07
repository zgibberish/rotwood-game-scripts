local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_dojo_master").QUESTS.WEAPON_UNLOCKS.twn_unlock_polearm

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGHEST)

Q:UpdateCast("giver")
	:FilterForPrefab("npc_dojo_master")

Q:AddObjective("unlock")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:SetRateLimited(true)

local opt1a_clicked = true
local opt1b_clicked = true

local function MainChoices(cx)
	if opt1a_clicked then
		if opt1b_clicked then --If the player went through option B first then change the wording of the option A button slightly to flow better
			cx:Opt("OPT_1A")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("OPT1A_RESPONSE")
					opt1a_clicked = false
					MainChoices(cx)
			end)
		else
			cx:Opt("OPT_1A_ALT")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("OPT1A_RESPONSE")
					opt1a_clicked = false
					MainChoices(cx)
			end)
		end
	end

	if opt1b_clicked then
	cx:Opt("OPT_1B")
		:MakePositive()
		:Fn(function(cx)
			cx:Talk("OPT1B_RESPONSE")
			opt1b_clicked = false
			MainChoices(cx)
		end)
	end

	cx:AddEnd("OPT_1C")
		:MakePositive()
		:Fn(function(cx)
			cx:Talk("OPT1C_RESPONSE")
			cx.quest:Complete()
		end)
end


-- player has tag "pf_first_miniboss_seen"

Q:OnTownChat("unlock", "giver")
	:RequiredPlayerFlags{"pf_first_miniboss_seen"}
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings)
	:Fn(function(cx)
		cx:Talk("TALK_GIVE_WEAPON")

		local player = cx.quest:GetPlayer()
		player:UnlockWeaponType(WEAPON_TYPES.POLEARM)
		quest_helper.PushWeaponUnlockScreen(cx, function(inst) quest_helper.GiveItemToPlayer(player, "WEAPON", "polearm_basic", 1, true) end, "polearm_basic")

		MainChoices(cx)
	end)

return Q