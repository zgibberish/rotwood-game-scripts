local FeedbackScreen = require "screens.feedbackscreen"
local PauseScreen = require "screens.redux.pausescreen"


local feedback = {}

local instructions_str
local autosend_feedback

local function OnFeedbackScreenshotReady(texture, texture_string )
	local pause = TheFrontEnd:FindScreen(PauseScreen)
	if pause then
		-- We unpaused when starting feedback (see below) which messes with the
		-- pause screen's internal state. Clear it and any screens above it to
		-- ensure we're back to normal.
		TheFrontEnd:PopScreensAbove(pause)
		pause:Unpause()
	end
	local screen = FeedbackScreen(texture, texture_string)
	if instructions_str then
		screen:SetCustomInstructionText(instructions_str)
	end
	TheFrontEnd:PushScreen(screen)
	if autosend_feedback then
		autosend_feedback = nil
		screen:TriggerAutoSend()
	end
end

function feedback.AutoSendFeedback(feedback_instructions_str)
	-- Open screen for autosend so users can see that feedback is sending and
	-- we use the normal code path.
	feedback.StartFeedback(feedback_instructions_str)
	autosend_feedback = true
end

function feedback.StartFeedback(feedback_instructions_str)
	instructions_str = feedback_instructions_str -- optional, only use for specific cases
	autosend_feedback = nil

	if TheFrontEnd.error_widget then
		-- Would be nice to do the work to make feedback work after
		-- errors, but not for now.
		local msg = "Feedback doesn't work after hitting an error, but we've sent an automatic crash report.\n\n"
		if DEV_MODE then
			msg = "Feedback doesn't work after hitting an error. Comment on your crash in #fromtheforge-crashes to tell us what happened or reload and send feedback.\n\n"
		end
		local text = TheFrontEnd.error_widget.text:GetText() or ""
		TheFrontEnd.error_widget.text:SetText(msg .. text)
		return
	end

	local feed = TheFrontEnd:FindScreen(FeedbackScreen)
	if not feed then
		local pause = TheFrontEnd:FindScreen(PauseScreen)
		if pause then
			-- Force pause screen to unpause time since the screen pauses the
			-- sim but we need the sim to tick to get our screenshot. Don't
			-- want to pop or Unpause the screen yet or the screenshot won't
			-- show the current screen (if submitting feedback on the pause
			-- screen itself).
			pause:ForceUnpauseTime()
		end
		TheScreenshotter:RequestScreenshot(OnFeedbackScreenshotReady)
	end
end

return feedback
