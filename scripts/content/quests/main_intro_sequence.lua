local Quest = require "questral.quest"

local Q = Quest.CreateMainQuest()

Q:TitleString("Intro Sequence")

Q:UpdateCast("giver")
	:CastFn(function(quest, root)
		return root:GetCurrentLocation()
	end)

function Q:Quest_Complete()
	self:GetQuestManager():SpawnQuest("dgn_tips_scout")
	local intro_quest = self:GetQuestManager():SpawnQuest("main_defeat_megatreemon")
	self:GetPlayer():DoTaskInTime(0, function()
		-- Time delayed so the quest state has time to settle before we kick a room change
		intro_quest:ActivateObjective("quest_intro")
	end)
end

Q:OnEvent("new_game_started", function(quest)
	quest:ActivateObjective("intro_slideshow")
end)

Q:AddObjective("intro_slideshow")
	-- :InitialState(QUEST_OBJECTIVE_STATE.s.ACTIVE)
	:OnActivate(function(quest)
		if TheSaveSystem.cheats:GetValue("skip_new_game_flow")
			or not TheNet:IsGameTypeLocal() then -- if you're in a networked game, don't do this cinematic.
			quest:Complete('intro_slideshow')
			return
		end

		local SlideshowScreen = require "screens.slideshowscreen"
		TheFrontEnd:PushScreen(SlideshowScreen( "rotwood_intro", function() quest:Complete('intro_slideshow') end, nil))
		TheFrontEnd:Fade(FADE_IN, 0.5)
	end)
	:OnComplete(function(quest)
		quest:Complete()
	end)

return Q