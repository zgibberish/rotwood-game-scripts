local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_dojo_master").QUESTS.WEAPON_UNLOCKS.twn_unlock_shotput

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGHEST)

Q:UpdateCast("giver")
	:FilterForPrefab("npc_dojo_master")

Q:AddObjective("unlock")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:SetRateLimited(true)

local function ShotputOptionsMenu(cx, opt1A_clicked, opt1B_clicked, chosePun)
	--keep track of if options 1A and 1B have been clicked or not
	local menuButtonState = {opt1A_clicked, opt1B_clicked}
	local chosePun = chosePun

	--Flavour option
	if menuButtonState[2] == false and menuButtonState[1] == false then
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1A_RESPONSE")

				--razz toot a lil
				cx:Opt("OPT_2A")
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT2A_RESPONSE")
					end)

				--make a pun at toot (worse than razzing)
				cx:Opt("OPT_2B")
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT2B_RESPONSE")
						chosePun = true
					end)

				cx:JoinAllOpt_Fn(function()
					menuButtonState[1] = true
					ShotputOptionsMenu(cx, menuButtonState[1], menuButtonState[2], chosePun)
				end)
			end)
	end

	--Button explaining how to use the shotput
	if menuButtonState[2] then
		cx:Opt("OPT_1B_ALT")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1B_RESPONSE_ALT") --regular response
				ShotputOptionsMenu(cx, menuButtonState[1], menuButtonState[2], chosePun)
			end)
	else
		cx:Opt("OPT_1B")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1B_RESPONSE")
				menuButtonState[2] = true
				ShotputOptionsMenu(cx, menuButtonState[1], menuButtonState[2], chosePun)
			end)
	end

	--Exit menu
	if chosePun then --if the player made a pun about the ball Toot makes a pun back
		cx:Opt("OPT_1C_ALT")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1C_RESPONSE_ALT")

				cx:Opt("BYE_A")
					:MakePositive()
				cx:Opt("BYE_B")
					:MakePositive()

				cx:JoinAllOpt_Fn(function()
					cx:End()
					cx.quest:Complete()
				end)
			end)
	else
		cx:AddEnd("OPT_1C")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1C_RESPONSE")
				cx.quest:Complete()
			end)
	end
end

-- Player has tag "pf_owlitzer_miniboss_seen"

Q:OnTownChat("unlock", "giver", function(quest, node, sim) return quest:GetPlayer():IsWeaponTypeUnlocked(WEAPON_TYPES.CANNON) end)
	:RequiredPlayerFlags{"pf_owlitzer_miniboss_seen"}
	:SetPriority(Convo.PRIORITY.HIGHEST)
	:Strings(quest_strings)
	:Fn(function(cx)
		cx:Talk("TALK")

		local player = cx.quest:GetPlayer()
		player:UnlockWeaponType(WEAPON_TYPES.SHOTPUT)
		quest_helper.PushWeaponUnlockScreen(cx, function(inst) quest_helper.GiveItemToPlayer(player, "WEAPON", "shotput_basic", 1, true) end, "shotput_basic")

		ShotputOptionsMenu(cx, false, false, false)
	end)

return Q
