local Convo = require "questral.convo"
local Npc = require "components.npc"
local Quest = require "questral.quest"
local Quip = require "questral.quip"
local fmodtable = require "defs.sound.fmodtable"
local quest_helper = require "questral.game.rotwoodquestutil"

local quest_strings = require("strings.strings_npc_refiner").QUESTS.dgn_meeting_research

------QUEST SETUP------

local Q = Quest.CreateJob()
	:SetPriority(QUEST_PRIORITY.HIGH)

Q:TitleString(quest_strings.TITLE)

------OBJECTIVE DECLARATIONS------

------CONVERSATIONS/IMPLEMENTATIONS------

return Q
