local Convo = require "questral.convo"
local Quest = require "questral.quest"
local quest_strings = require("strings.strings_npc_scout").QUIPS.twn_tips_scout

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.LOWEST)

Q:UpdateCast("giver")
	:FilterForPrefab("npc_scout")

-- GLITZ TUTORIAL
Q:AddCast("mirror")
	:CastFn(function(quest, root)
		return root:AllocateInteractable("character_customizer_vshack")
	end)

Q:AddObjective("tutorial_glitz_start")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)
		quest:ActivateObjective("access_customization_screen", true)
	end)

Q:AddObjective("access_customization_screen")
	:Mark{"mirror"}
	:OnCastEvent("mirror", "perform_interact", function(quest, player)
		if player == quest:GetPlayer() then
			quest:Complete("access_customization_screen")
		end
	end)
	:OnComplete(function(quest)
		quest:ActivateObjective("tutorial_glitz_end", true)
	end)

Q:AddObjective("tutorial_glitz_end")
	-- :OnComplete(function(quest)
		-- local player = quest:GetPlayer()
		-- local Consumable = require "defs.consumable"
		-- local reward_amount = 1000
		-- player.components.inventoryhoard:AddStackable(Consumable.Items.MATERIALS.glitz, reward_amount)
		-- TheDungeon.HUD:MakePopText({ 
		-- 	target = player, 
		-- 	button = string.format(STRINGS.UI.INVENTORYSCREEN.GLITZ, reward_amount), 
		-- 	color = UICOLORS.KONJUR, 
		-- 	size = 100, 
		-- 	fade_time = 3.5,
		-- 	y_offset = 650,
		-- })
	-- end)

Q:OnTownChat("tutorial_glitz_start", "giver", function(quest) 
		local num_runs = quest:GetPlayer().components.progresstracker:GetValue("total_num_runs") or 0
		return num_runs >= 3
	end)
	:Strings(quest_strings.tutorial_glitz)
	:Fn(function(cx)
		local function EndConvo(endStr)
			cx:Talk(endStr)
			cx:End()
			cx.quest:Complete("tutorial_glitz_start")
		end

		cx:Talk("TALK_GO_CUSTOMIZE")
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function()
				EndConvo("OPT1A_RESPONSE")
			end)
		cx:Opt("OPT_1B")
			:MakePositive()
			:Fn(function()
				EndConvo("OPT1B_RESPONSE")
			end)
	end)

Q:OnTownChat("tutorial_glitz_end", "giver")
	:Strings(quest_strings.tutorial_glitz)
	:Fn(function(cx)
		cx:Talk("TALK_DONE_CUSTOMIZE")
		cx:AddEnd("OPT_END")
			:MakePositive()
			:Fn(function()
				cx:Talk("END_RESPONSE")
				cx.quest:Complete("tutorial_glitz_end")
			end)
	end)

return Q
