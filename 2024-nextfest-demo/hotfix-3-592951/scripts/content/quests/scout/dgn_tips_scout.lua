local Convo = require "questral.convo"
local Equipment = require "defs.equipment"
local Quest = require "questral.quest"
local Quip = require "questral.quip"

local quest_strings = require("strings.strings_npc_scout").QUESTS.dgn_tips_scout
local quip_strings = require("strings.strings_npc_scout").QUIPS.dgn_tips_scout

-- Grab the enum strings, for brevity.
local weapon = Equipment.WeaponTag.s


local Q = Quest.CreateJob()

Q:SetIsUnimportant()

Q:UpdateCast("giver")
	:FilterForPrefab("npc_scout")

Q:AddCast("current_dungeon")
	:CastFn(function(quest, root)
		return root:GetCurrentLocation()
	end)

Q:AddObjective("give_tip")
	:AppearInDungeon_Entrance()
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)

Q:AddObjective("polearm_full_convo")
	:AppearInDungeon_Entrance()
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)


Q:AddQuips {
	Quip("gameplay_tip")
		:Tag("gameplay_tip") -- need a scoring tag to tie with other weapon tips.
		:Not(weapon.cannon) -- cannon dodge is very different TODO(jambell): right?
		:PossibleStrings(quip_strings.DODGE_NO_CANNON),

	Quip("gameplay_tip", weapon.hammer)
		:PossibleStrings(quip_strings.HAMMER),

	Quip("gameplay_tip", weapon.polearm)
		:PossibleStrings(quip_strings.POLEARM),

	-- Fallback if nothing else matches.
	Quip("gameplay_tip")
		:Tag("gameplay_tip", 0) -- contribute nothing to score so we don't choose it over another quip.
		:PossibleStrings(quip_strings.FALLBACK)
}

Q:OnDungeonChat("polearm_full_convo", "giver", function(quest)
		local weapontag = quest:GetPlayer().components.inventory:GetEquippedWeaponTag()
		return Quest.Filters.InDungeon_Entrance and weapontag == weapon.polearm
	end)
	:SetPriority(Convo.PRIORITY.NORMAL)
	:Strings(quest_strings.POLEARM_FULL_CONVO)
	:Fn(function(cx)
		local function EndConvoOpt(btn_str)
			cx:AddEnd(btn_str)
				:MakePositive()
				:Fn(function()
					cx:Talk("END_RESPONSE")
					cx.quest:Complete("polearm_full_convo")
				end)
		end

		cx:Talk("TALK")
		cx:Opt("OPT_1A")
			:MakePositive()
			:Fn(function()
				cx:Talk("OPT1A_RESPONSE")
				cx:Opt("OPT_2A")
					:MakePositive()
					:Fn(function()
						cx:Talk("OPT2A_RESPONSE")
						EndConvoOpt("OPT_END")
					end)
				EndConvoOpt("OPT_END")
			end)
		EndConvoOpt("OPT_1B")
	end)

Q:OnDungeonChat("give_tip", "giver", Quest.Filters.InDungeon_Entrance)
	:SetPriority(Convo.PRIORITY.LOW)
	:Fn(function(cx)
		local giver = cx.quest:GetCastMember("giver")
		local player = giver:GetInteractingPlayerEntity()
		local weapontag = player.components.inventory:GetEquippedWeaponTag()
		-- The first tag must match. The following ones are optional.
		cx:Quip(giver, { "gameplay_tip", weapontag, })
	end)

return Q
