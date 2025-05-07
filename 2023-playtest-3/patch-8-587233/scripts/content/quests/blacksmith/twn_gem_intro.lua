local Convo = require "questral.convo"
local EquipmentGem = require "defs.equipmentgems.equipmentgem"
local InfoPopUp = require "screens.infopopup"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local Quip = require "questral.quip"
local quest_strings = require ("strings.strings_npc_blacksmith").QUESTS.twn_gem_intro
local fmodtable = require "defs.sound.fmodtable"

------QUEST SETUP------

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGH)

Q:TitleString(quest_strings.TITLE)

--[[
Quests are synced by default
If a quest has sync set to false, when a player completes that quest it will
only complete that quest for them and not the other players on the same quest step
]]


--popup tutorializing weapon gems
local function PROTOTYPE_ShowGemTip(player)
	assert(TheDungeon.HUD.townHud)

	if TheDungeon.HUD.townHud then
		player:DoTaskInAnimFrames(30, function()

			-- temp popup for prototype!
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.Mus_weaponUnlock_Stinger)
			local button_base = TheDungeon.HUD.townHud.inventoryButton
			local confirmation = nil
			confirmation = InfoPopUp(nil, nil, true,
				STRINGS.UI.GEMSCREEN.UNLOCK_POPUP.TITLE,
				STRINGS.UI.GEMSCREEN.UNLOCK_POPUP.DESC,
				{ width = 920, height = 220 })--STRINGS.UI.WEAPONSELECTIONSCREEN.CHOICES.DESC)
				:SetButtonText(STRINGS.UI.BUTTONS.OK)
				:SetOnDoneFn(function(accepted)
					TheFrontEnd:PopScreen(confirmation)
					button_base:Show()
				end)
				:SetScale(1, 1)
				:SetArrowXOffset(-160)

			TheFrontEnd:PushScreen(confirmation)

			-- local rootWidget = confirmation:GetRootWidget()
			-- rootWidget:LayoutBounds("center", "above", button_base)
			-- 	:Offset(150, 30)

			button_base:Hide()

			-- And animate it in!
			confirmation:AnimateIn()
		end)
	end
end

------CAST DECLARATIONS------

Q:UpdateCast("giver")
	:FilterForPrefab("npc_blacksmith")

------OBJECTIVE DECLARATIONS------

Q:AddObjective("gem_tips")
	:InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnComplete(function(quest)

		local player = quest:GetPlayer()

		local items = EquipmentGem.GetItemList(EquipmentGem.Slots.GEMS, nil)
		for _, def in pairs(items) do
			if def.tags.tutorial_gem then
				player.components.gemmanager:GiveGem(def)
			end
		end

		PROTOTYPE_ShowGemTip(player)

		quest:Complete()
	end)

------CONVERSATIONS AND QUESTS------

Q:OnTownChat("gem_tips", "giver", Quest.Filters.InTown)
	:FlagAsTemp()
	:Strings(quest_strings.gem_tips)
	:Fn(function(cx)
		cx:Talk("GEM_INTRO")
		cx:AddEnd("OPT_GEM")
			:MakePositive()
			:Fn(function(cx)
				cx.quest:Complete("gem_tips")
			end)
	end)

return Q
