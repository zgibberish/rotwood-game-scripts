local Convo = require "questral.convo"
local Quest = require "questral.quest"
local quest_helper = require "questral.game.rotwoodquestutil"
local fmodtable = require "defs.sound.fmodtable"

local quest_strings = require("strings.strings_npc_apothecary").QUESTS.dgn_meeting_apothecary

------QUEST SETUP------

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.NORMAL)

Q:TitleString(quest_strings.TITLE)

------CAST DECLARATIONS------

------OBJECTIVE DECLARATIONS------

------CONVERSATIONS/IMPLEMENTATIONS------

return Q
