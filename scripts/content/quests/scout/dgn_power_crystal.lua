local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"

local quest_strings = require("strings.strings_npc_scout").QUESTS.dgn_power_crystal

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGH)

Q:AddTags({"shop"})

Q:UpdateCast("giver")
	:FilterForPrefab("npc_scout")

Q:AddObjective("dgn_power_crystal")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

--keep track of if the player has clicked OPT2A, OPT2B, OPT2C or OPT2D yet
local menu_btnstates = {}
menu_btnstates = { false, false, false, false }

local function Opt2ButtonMenu(cx)
	--player asks how to use the crystal
	if menu_btnstates[1] == false then
		cx:Opt("OPT_2A")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT2A_RESPONSE")
				menu_btnstates[1] = true
				Opt2ButtonMenu(cx)
			end)
	else
		--player asks how long powers last
		if menu_btnstates[2] == false then
			cx:Opt("OPT_2B")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("OPT2B_RESPONSE")
					menu_btnstates[2] = true
					Opt2ButtonMenu(cx)
				end)
		end
	end

	--player asks how the crystal got there
	if menu_btnstates[3] == false then
		cx:Opt("OPT_2C")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT2C_RESPONSE")
				menu_btnstates[3] = true
				Opt2ButtonMenu(cx)
			end)
	else
		--player makes sure flitt doesnt want the crystal (only appears if player's already shown interest in lore by clicking previous option)
		if menu_btnstates[4] == false then
			cx:Opt("OPT_2D")
				:MakePositive()
				:Fn(function(cx)
					cx:Talk("OPT2D_RESPONSE")
					menu_btnstates[4] = true
					Opt2ButtonMenu(cx)
				end)
		end
	end

	--option always available, ends the conversation
	cx:AddEnd("OPT_2E")
		:MakePositive()
		:Fn(function(cx)
			cx:Talk("TALK2")
			cx.quest:Complete("dgn_power_crystal")
		end)
end

Q:OnDungeonChat("dgn_power_crystal")
	:SetPriority(Convo.PRIORITY.HIGH)
	:Strings(quest_strings)
	:Fn(function(cx)
		cx:Talk("TALK") 
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1A_RESPONSE")
				Opt2ButtonMenu(cx)
			end)
		cx:Opt("OPT_1B")
			:MakePositive()
			:Fn(function(cx)
				cx:Talk("OPT1B_RESPONSE")
				cx:Opt("OPT_3A")
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("OPT3A_RESPONSE")
						Opt2ButtonMenu(cx)
					end)
				cx:AddEnd("OPT_3B")
					:MakePositive()
					:Fn(function(cx)
						cx:Talk("TALK2")
						cx.quest:Complete("dgn_power_crystal")
					end)
			end)
	end)

return Q