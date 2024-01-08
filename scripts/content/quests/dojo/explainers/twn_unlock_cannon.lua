local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"
local quest_strings = require("strings.strings_npc_dojo_master").QUESTS.WEAPON_UNLOCKS.twn_unlock_cannon

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGH)

Q:UpdateCast("giver")
	:FilterForPrefab("npc_dojo_master")

Q:AddObjective("unlock")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:OnTownChat("unlock", "giver")
	:Strings(quest_strings)
	:Fn(function(cx)

		cx:Talk("TALK")

		cx:Opt("OPT_1A")
			:MakePositive()
		cx:Opt("OPT_1B")
			:MakePositive()
			
		cx:JoinAllOpt_Fn(function()
			cx:Talk("TALK2")
			
			local player = cx.quest:GetPlayer()
			player:UnlockWeaponType(WEAPON_TYPES.CANNON)
			quest_helper.PushWeaponUnlockScreen(cx, function(inst) quest_helper.GiveItemToPlayer(player, "WEAPON", "cannon_basic", 1, true) end, "cannon_basic")

			cx:Opt("OPT_2")
				:MakePositive()
				:Fn(function()
					cx:Talk("TALK_GIVE_WEAPON")

					local skip_option = "OPT_SKIPINFO"
					cx:Opt("OPT_STARTEXPLAINER")
						:MakePositive()
						:Fn(function()
							cx:Talk("STARTEXPLAINER_RESPONSE")
							cx:Loop(function()
								cx:OptThatChanges("OPT_FIRINGMODES", "OPT_FIRINGMODES_ALT")
									:Fn(function(_, opt)
										if opt:HasPreviouslyPickedOption() then
											cx:Talk("FIRINGMODES_RESPONSE_ALT")
										else
											cx:Talk("FIRINGMODES_RESPONSE")
										end
										-- We'll return to the start of Loop() once the option function completes.
									end)
								cx:OptThatChanges("OPT_RELOADING", "OPT_RELOADING_ALT")
									:Fn(function(_, opt)
										if opt:HasPreviouslyPickedOption() then
											cx:Talk("RELOADING_RESPONSE_ALT")
										else
											cx:Talk("RELOADING_RESPONSE")
										end
									end)
								cx:OptThatChanges("OPT_MORTAR", "OPT_MORTAR_ALT")
									:Fn(function(_, opt)
										if opt:HasPreviouslyPickedOption() then
											cx:Talk("MORTAR_RESPONSE_ALT")
										else
											cx:Talk("MORTAR_RESPONSE")
										end
									end)

								cx:AddEnd(skip_option)
									:MakePositive()
									:Fn(function()
										cx:Talk("SKIPINFO_RESPONSE")
										cx:Talk("TALK_ALLDONE")
									end)
									:EndLoop()
									:CompleteObjective()
								-- We've displayed the default one once, so now always display the alt one.
								skip_option = "OPT_SKIPINFO_ALT"
							end)
					end)
					cx:AddEnd("OPT_SKIPEXPLAINER")
						:MakePositive()
						:Fn(function()
							cx:Talk("TALK_ALLDONE")
						end)
						:CompleteObjective()
					end)
			end)
	end)

return Q
