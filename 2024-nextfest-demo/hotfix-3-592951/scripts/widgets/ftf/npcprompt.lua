local FollowPrompt = require("widgets/ftf/followprompt")
local Image = require("widgets/image")
local SpeechBalloon = require("widgets/ftf/speechballoon")
local SpeechButton = require("widgets/speechbutton")
local Panel = require("widgets/panel")
local Widget = require("widgets/widget")
local fmodtable = require "defs.sound.fmodtable"
local easing = require "util.easing"


------------------------------------------------------------------------------------------
-- Parameter tuning:
-- * Balloons display before actions.
-- * Actions hide before balloons.

local ANIMATING_IN_ACTIONS =
{
	FADE_IN_TIME = 0.25,
	BETWEEN_EACH_ACTION = 0.15,
}

local ANIMATING_OUT_ACTIONS =
{
	FADE_OUT_TIME = 0.05, -- A single action button fades out over this time
	BETWEEN_EACH_ACTION = 0.01, -- After an action button has animated out, wait this long before moving onto the next one
}

local ANIMATING_OUT_BALLOONS =
{
	BETWEEN_EACH_BALLOON = 0.01, -- After a balloon has animated out, wait this long before moving onto the next one.
}

-- local IGNORE_INPUT_BUFFER_WHILE_FADING_IN = 0.2 -- How long is Input Ignored after a balloon fades out and a new one is fading in?
-- 												-- Too small means accidental double clicks skips text invisibly
-- 												-- Too large means lots of clicks get ignored
-- 												-- jambell: planning to iterate on speech bubbles so we can see text history, but this should help for now.

local IGNORE_INPUT_BUFFER_AFTER_SKIPPING = 0.2 -- How long is Input Ignored after the player clicks to skip the text animation?


------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
--- Displays NPC interactions.
--- Contains speech balloons and convo buttons
----
local NpcPrompt = Class(FollowPrompt, function(self, owning_player, npc)

	FollowPrompt._ctor(self, owning_player)
	assert(npc)
	self:SetName("NpcPrompt")

	self:SetFullscreenHit(true)

	self.player = owning_player -- TODO: Use GetOwningPlayer instead or self.player
	self.npc = npc
	self.modal = false

	-- A dot above the NPC's head, so we can align our dialog bubbles to it
	self.rootAnchor = self:AddChild(Image("images/global/square.tex"))
		:SetSize(10, 10)
		:SetMultColor(UICOLORS.RED)
		:Offset(0, 250) -- over head
		:SetMultColorAlpha(0)

	-- Shows the speech balloon(s)
	self.speechBlock = self:AddChild(Widget("Speech Block"))
		:SetControlDownSound(nil)
		:SetControlUpSound(nil)
		:SetHoverSound(nil)
		:SetGainFocusSound(nil)
	-- Shows the interactive widgets in this dialog
	self.actionsBlock = self:AddChild(Widget("Actions Block"))

	-- Item selection brackets
	self.selection_brackets = self:AddChild(Panel("images/ui_ftf_dialog/speech_button_brackets.tex"))
		:SetName("Selection brackets")
		:SetNineSliceCoords(78, 94, 80, 96)
		:SetNineSliceBorderScale(0.8)
		:SetHiddenBoundingBox(true)
		:IgnoreInput(true)
		:Hide()

	-- Animate them too
	local speed = 1.35
	local amplitude = 14
	self.selection_brackets_w, self.selection_brackets_h = SpeechButton.WIDTH, SpeechButton.HEIGHT
	self.selection_brackets:RunUpdater(
		Updater.Loop({
			Updater.Ease(function(v) self.selection_brackets:SetSize(self.selection_brackets_w + v, self.selection_brackets_h + v) end, amplitude, 0, speed, easing.inOutQuad),
			Updater.Ease(function(v) self.selection_brackets:SetSize(self.selection_brackets_w + v, self.selection_brackets_h + v) end, 0, amplitude, speed, easing.inOutQuad),
		}))
end)

function NpcPrompt:Remove()
	self:_CancelShutup()
	-- self.npc:PushEvent("shutup")
	NpcPrompt._base.Remove(self)
end

function NpcPrompt:_CancelShutup()
	if self.shutup_task then
		self.shutup_fn()
		-- self.shutup_task:Cancel()
		-- self.shutup_task = nil
	end
end

function NpcPrompt:SetModal(modal)
	self.modal = modal
	self:SetBlocksMouse(modal)
	return self
end

function NpcPrompt:IsModal()
	return self.modal
end

function NpcPrompt:_IsNpcFacingRight()
	if self.npc.components.conversation ~= nil then
		local target = self.npc.components.conversation:GetTarget()
		if target ~= nil then
			local x = self.npc.Transform:GetWorldXZ()
			local x1 = target.Transform:GetWorldXZ()
			if x1 > x then
				return true
			elseif x1 < x then
				return false
			end
		end
	end
	return self.npc.Transform:GetFacing() == FACING_RIGHT
end

function NpcPrompt:_HideSelectionBrackets()
	self.last_target_button = nil
	self.selection_brackets:Hide()
	return self
end

function NpcPrompt:_GetDefaultActionButton()
	return self.actionsBlock.children and self.actionsBlock.children[1]
end

function NpcPrompt:_ResizeSelectionBrackets(target_button)
	target_button = target_button or self.last_target_button or self:_GetDefaultActionButton()

	if target_button then
		local w, h = target_button:GetSize()
		self.selection_brackets_w, self.selection_brackets_h = w + 40, h + 30
		self.selection_brackets:SetSize(self.selection_brackets_w, self.selection_brackets_h)
			:LayoutBounds("center", "center", target_button)
	end

	return self
end

function NpcPrompt:_UpdateSelectionBrackets(target_button)

	if self.last_target_button == target_button then return self end

	-- Get the brackets' starting position
	local start_pos = self.selection_brackets:GetPositionAsVec2()

	-- Align them with the target
	self.selection_brackets:LayoutBounds("center", "center", target_button)
		:Offset(0, 0)

	-- Get the new position
	local end_pos = self.selection_brackets:GetPositionAsVec2()

	-- Calculate midpoint
	local mid_pos = start_pos:lerp(end_pos, 0.2)
	-- Calculate a perpendicular vector from the midpoint
	local dir = start_pos - end_pos
	dir = dir:perpendicular()
	dir = dir:normalized()
	dir = mid_pos + dir*100

	-- Move them back and animate them in
	self.selection_brackets:Show()
		:SetPos(start_pos.x, start_pos.y)
		:CurveTo(end_pos.x, end_pos.y, dir.x, dir.y, 0.35, easing.outElasticUI)

	self.last_target_button = target_button
	return self
end

---
-- Animates out and removes all contents to prepare for a different dialog
--
function NpcPrompt:ResetAll(onDoneFn, callbackDelay, clearModal)
	--~ local stack = debug.traceback("Before animation started:")

	self:_HideSelectionBrackets()

	-- disable buttons while animating out
	-- TODO: does _StopInputAndFocus make this redundant?
	for _k, button in ipairs(self.actionsBlock.children) do
		button:IgnoreInput(true)
	end
	self.actions_animating = true
	self:_StopInputAndFocus()

	-- Animate out speech balloons.
	-- 2023-06-02: We don't currently use more than one balloon at a time.
	local balloonsUpdater = Updater.Series()
	for k, balloon in ipairs(self.speechBlock.children) do

		-- Animate each balloon out
		balloonsUpdater:Add(balloon:CreateAnimateOut())
		balloonsUpdater:Add(Updater.Do(function()
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.speechBubble_close)
		end))

		-- And add a delay before the next balloon starts animating out too
		balloonsUpdater:Add(Updater.Wait(ANIMATING_OUT_BALLOONS.BETWEEN_EACH_BALLOON))
	end

	-- Animate out actions
	local actionsUpdater = Updater.Series()
	for k, button in ipairs(self.actionsBlock.children) do

		-- Get button position
		local buttonX, buttonY = button:GetPosition()

		-- Animate each button out
		actionsUpdater:Add(Updater.Parallel({
			Updater.Ease(function(v) button:SetMultColorAlpha(v) end, 1, 0, ANIMATING_OUT_ACTIONS.FADE_OUT_TIME, easing.inQuad),
			Updater.Ease(function(v) button:SetPosition(buttonX, v) end, buttonY, buttonY + 20 * HACK_FOR_4K, ANIMATING_OUT_ACTIONS.FADE_OUT_TIME, easing.inQuad)
		}))

		-- And add a delay before the next button starts animating out too
		actionsUpdater:Add(Updater.Wait(ANIMATING_OUT_ACTIONS.BETWEEN_EACH_ACTION))
	end

	-- Run the whole animation
	self:RunUpdater(Updater.Series({
		-- Buttons first
		actionsUpdater,

		-- Then balloons
		balloonsUpdater,

		Updater.Do(function()
			if clearModal then
				self:SetModal(false)
			end
			self.speechBlock:RemoveAllChildren()
			self.actionsBlock:RemoveAllChildren()
			self.last_target_button = nil
			self.balloon = nil -- was child of speechBlock
		end),

		-- Wait for a beat
		Updater.Wait(onDoneFn and (callbackDelay or 0.1) or 0),

		-- Then the callback, if any
		Updater.Do(function()
			self.actions_animating = false
			self:_ResumeInputAndFocus()
			--~ print("onDone. Stack at start:", stack)
			if onDoneFn then onDoneFn() end
		end)
	}))

	return self
end

function NpcPrompt:Click()
	if self.balloon and self.balloon.actionsButton then
		self.balloon.actionsButton:Click()
	end
end

---
-- Makes all the buttons alpha = 0 in anticipation to their
-- fading in
--
function NpcPrompt:_PrepareAnimationActions()

	for k, button in ipairs(self.actionsBlock.children) do
		button:SetMultColorAlpha(0)
		-- Block input to prevent triggering selection bracket from appearing
		-- over an invisible button or clicking while animating. Separate from
		-- input blocking in _StopInputAndFocus.
		button:IgnoreInput(true)
	end

	self:_ResizeSelectionBrackets()
	self:_HideSelectionBrackets()

	-- prevent focus from being given to something until the animation is done
	self.actions_animating = true

	return self
end

---
-- Animates the actions buttons in
--
function NpcPrompt:AnimateInActions(onDoneFn)

	local buttons = {}
	for k = #self.actionsBlock.children, 1, -1 do
		table.insert(buttons, self.actionsBlock.children[k])
	end

	local actionsUpdater = Updater.Parallel()

	local current_delay = 0
	for k, button in ipairs(buttons) do

		-- Fade out button
		button:SetMultColorAlpha(0)

		-- Get button position
		local buttonX, buttonY = button:GetPosition()

		actionsUpdater:Add(Updater.Series{
			Updater.Wait(current_delay),
			Updater.Parallel{
				Updater.Ease(function(v) button:SetMultColorAlpha(v) end, 0, 1, ANIMATING_IN_ACTIONS.FADE_IN_TIME, easing.outQuad),
				Updater.Ease(function(v) button:SetPosition(buttonX, v) end, buttonY-50, buttonY, ANIMATING_IN_ACTIONS.FADE_IN_TIME*2, easing.outElasticSpeechBubble)
			},
		})

		current_delay = current_delay + ANIMATING_IN_ACTIONS.BETWEEN_EACH_ACTION
	end

	-- enable buttons only when they have all completely finished animating in
	local actionsFinished = Updater.Do(function()
		for _k, button in ipairs(buttons) do
			button:IgnoreInput(false)
		end
	end)

	-- Run the whole animation
	self:RunUpdater(Updater.Series({
		Updater.Do(function()
			self:_PrepareAnimationActions()
		end),
		actionsUpdater,
		actionsFinished,

		-- Then the callback, if any
		Updater.Do(function()
			self.actions_animating = false

			-- This will select the first action available
			self:_ResumeInputAndFocus()

			if onDoneFn then onDoneFn() end
		end)
	}))

	return self
end

---
-- Formats and positions the balloons + actions, and animates them in
--
function NpcPrompt:AnimateIn(onDoneFn)
	self:DoFocusHookups()

	local facingRight = self:_IsNpcFacingRight()
	local sign = facingRight and 1 or -1
	local arrowOffset = 70 * HACK_FOR_4K
	local talk_chars = 0

	-- Go through the balloons and configure them properly
	for k, balloon in ipairs(self.speechBlock.children) do

		-- The first balloon should show the name,
		-- if the player knows the character already
		if k == 1 then
			if self.npcName then
				balloon:SetTitleText(self.npcName)
			end
		end

		-- Not setting balloons to float because of complaints it was distracting.
		--~ balloon:AnimateFloating()

		-- The last ballon should show the arrow
		if k == #self.speechBlock.children then
			-- Show arrow
			balloon:SetArrowShown(true, facingRight, arrowOffset)
		else
			balloon:SetArrowShown(false)
		end

		local text = balloon:GetText()
		if text then
			talk_chars = talk_chars + text:len()
		end
	end

	-- Layout balloons relative to the anchor point
	self.speechBlock:LayoutChildrenInGrid(1, 10 * HACK_FOR_4K)
		:LayoutBounds(facingRight and "before" or "after", "above", self.rootAnchor)
		-- TODO: Not sure how to make this layout more precicely above the root
		-- anchor. Take the arrow position into account?
		:Offset(arrowOffset * sign * 1.7, -45 * HACK_FOR_4K)
	-- :DebugEdit()

	-- Layout the action buttons
	self.actionsBlock:LayoutChildrenInGrid(1, 10 * HACK_FOR_4K)
		:LayoutBounds(facingRight and "after" or "before", "bottom", self.speechBlock)
		:Offset(20 * sign * HACK_FOR_4K, 75 * HACK_FOR_4K)

	-- Hide all the buttons
	self:_PrepareAnimationActions()

	self:_CancelShutup()
	if talk_chars > 0 then
		local tar = self.target
		tar:PushEvent("talk")
		local char_per_sec = 12 * 2 -- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6007935/#sec002
		local talk_sec = talk_chars / char_per_sec
		self.shutup_fn = function()
			tar:PushEvent("shutup")
			self.shutup_task = nil
			self.shutup_fn = nil
		end
		self.shutup_task = tar:DoTaskInTime(talk_sec, self.shutup_fn)
	end


	-- Animate in --------------------------------------------------------

	local balloonsUpdater = Updater.Series()

	-- Stop all input
	balloonsUpdater:Add(Updater.Do(function()
		self:_StopInputAndFocus()
	end))

	-- Prepare each balloon and set its animation
	for k, balloon in ipairs(self.speechBlock.children) do

		-- Fade out ballon
		balloon:PrepareAnimation()

		-- Animate each balloon in
		balloonsUpdater:Add(Updater.Do(function() balloon:AnimateIn() end))

		-- And add a delay before the next balloon starts animating in too
		balloonsUpdater:Add(Updater.Wait(0.05)) --TODO PARAMETERIZE.
	end

	balloonsUpdater:Add(Updater.Do(function()
		-- Balloons are in, so we want input so we can skip unspooling.
		self:_ResumeInputAndFocus()
	end))

	-- Animate in the actions
	balloonsUpdater:Add(Updater.Until(function()
		return self.completed_spooling
	end))
	balloonsUpdater:Add(Updater.Do(function()
		-- This resumes input and sets focus after the last action is
		-- displayed. We don't wait for actions to display before running our
		-- done callback.
		self:AnimateInActions()
	end))
	-- TODO(dbriscoe): Run the callback after anim completes

	-- Run the callback, if any
	balloonsUpdater:Add(Updater.Do(function()
		if onDoneFn then onDoneFn() end
	end))

	-- Run the whole animation
	self:RunUpdater(balloonsUpdater)

	return self
end

---
-- Displays a dialog bubble above an npc
-- onClickFn can be a function (displays the bar under the balloon) or nil (displays the dialog text only)
-- actionsList is a table in this format { {icon = "images/ui_ftf_dialog/convo_chat.tex", text = "Talk", fn = function() end}, ... }
-- hasActionBar if true, displays a "talk" on the balloon
--
function NpcPrompt:ShowDialogBalloon(dialogText, onClickFn, hasActionBar)
	-- Always complete when no spooling
	self.completed_spooling = true

	-- Add our speech balloon
	self.balloon = self.speechBlock:AddChild(SpeechBalloon())
		:SetConvoText(dialogText or "")
		:SnapSpool()
		:SetGainFocusSound(nil)
		:SetHoverSound(nil)

	if onClickFn ~= nil then
		local function _onclick()
			-- This animates out and destroys all the speech balloons
			self:SetModal(true)
				:ResetAll(onClickFn, 0.1)
		end
		if hasActionBar then
			self.balloon:SetInputString("<p bind='Controls.Digital.ACTION' color=0> "..STRINGS.UI.ACTIONS.TALK)
				:SetActionClick(_onclick)
			-- I think we're trying to limit the appear sound to once per convo.
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.speechBubble_appear)
		else
			self.balloon:SetFullscreenActionClick(_onclick)
		end
	end

	self.balloon:SetFocus()

	return self
end

function NpcPrompt:ShowDialogBalloonSpooled(line, personality, onClickFn, hasActionBar)
	self.balloon = self.speechBlock:AddChild(SpeechBalloon())
		:SetGainFocusSound(nil)
		:SetHoverSound(nil)

	self.completed_spooling = false
	local function complete_cb(was_snapped)
		self.balloon:SetContinueArrowShown(true)
		self.completed_spooling = true
	end
	self.balloon:SetPersonalityText(line, complete_cb, personality)
		:SetContinueArrowShown(false)

	if onClickFn ~= nil then
		local function _onclick()
			if self.completed_spooling then
				if self.actionsBlock:IsEmpty() then
					-- This animates out and destroys all the speech balloons
					self:SetModal(true)
						:ResetAll(onClickFn, 0.1)
				else
					-- If we have actions, player must click them instead of bubble.
					-- Give actions focus:
					self:_ResumeInputAndFocus()
				end
			else
				-- Finish the line. and show the continue arrow.
				self.balloon:SnapSpool() -- will fire the above callback
				TheFrontEnd:GetSound():PlaySound(fmodtable.Event.speechBubble_skip)

				self:_StopInputAndFocus()
				self.npc:DoTaskInTime(IGNORE_INPUT_BUFFER_AFTER_SKIPPING, function()
					self:_ResumeInputAndFocus()
				end)
			end
		end
		if hasActionBar then
			self.balloon:SetInputString("<p bind='Controls.Digital.ACTION' color=0> "..STRINGS.UI.ACTIONS.TALK)
				:SetActionClick(_onclick)
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.speechBubble_appear)
		else
			self.balloon:SetFullscreenActionClick(_onclick)
		end
	end

	self:_ResumeInputAndFocus()

	return self
end

function NpcPrompt:SnapSpool()
	self.balloon:SnapSpool()
	return self
end

function NpcPrompt:_StopInputAndFocus()
	if self.speechBlock then
		self.speechBlock:IgnoreInput()
	end
	if self.actionsblock then
		self.actionsBlock:IgnoreInput()
	end
	return self
end

function NpcPrompt:_ResumeInputAndFocus()
	if self.speechBlock then
		self.speechBlock:IgnoreInput(false)
	end
	if self.actionsblock then
		self.actionsBlock:IgnoreInput(false)
	end

	-- Give something focus
	local focusWidget = self:GetDefaultFocus()
	if focusWidget then
		focusWidget:SetFocus()
	end
	if not focusWidget then
		TheLog.ch.Convo:print("NpcPrompt:_ResumeInputAndFocus() - nothing to focus on")
	end
	return self
end

function NpcPrompt:BeginModalConversation(cb)
	self:SetModal(true)
		:ResetAll(cb, 0.1)
	return self
end

---
-- Displays a title over the first dialog bubble
-- npcName can be a string (e.g. "Mysterious figure") or false/nil (displays nothing)
--
function NpcPrompt:ShowNpcName(npcName)
	self.npcName = npcName or false
	return self
end

--- Displays an action button next to the speech balloons
function NpcPrompt:ShowActionButton(right_text, text, onClickFn, callbackDelay, clearModal)
	local btn = self.actionsBlock:AddChild(self:_GenerateDialogButton(text, right_text or ""))
		:SetName("SpeechButton - " .. text)
		:SetControlDownSound(fmodtable.Event.select_speechBubble)
		:SetOnClick(function()
			-- This animates out and destroys all the speech balloons
			self:ResetAll(onClickFn, callbackDelay or 0.25, clearModal)
		end)
	btn:SetOnGainFocus(function() self:_UpdateSelectionBrackets(btn) end)

	-- If we have actions, then silently gain focus to the bubble. Otherwise it
	-- makes excessive sounds and its focus isn't relevant.
	for k, balloon in ipairs(self.speechBlock.children) do
		balloon:SetGainFocusSound(nil)
	end
	return btn
end

function NpcPrompt:_GenerateDialogButton(text, right_text)
	return SpeechButton(text, right_text)
end

function NpcPrompt:ShowRecipeMenu(player, line, personality, recipe, onClickFn)
	assert(line, "Looks weird without some text here.")
	self:ShowDialogBalloonSpooled(line, personality, onClickFn)
	self.balloon:PopulateHireRequirements(recipe, player)
	return self
end

function NpcPrompt:GetDefaultFocus()
	if not self.actions_animating
		and self.completed_spooling
		and self.actionsBlock
		and self.actionsBlock.children
		and #self.actionsBlock.children > 0
	then
		return self:_GetDefaultActionButton()
	else
		return self.balloon
	end
end

function NpcPrompt:DoFocusHookups()
	for k, v in ipairs(self.actionsBlock.children) do
		if k > 1 then
			self.actionsBlock.children[k]:SetFocusChangeDir(MOVE_UP, self.actionsBlock.children[k-1])
		end
		if k < #self.actionsBlock.children then
			self.actionsBlock.children[k]:SetFocusChangeDir(MOVE_DOWN, self.actionsBlock.children[k+1])
		end
	end
	return self
end

function NpcPrompt:OnFocusMove(dir, down)
	-- Never do super. We want to push focus moving down to the focus widget.
	local focus = self:GetFE():GetFocusWidget()
	if focus == nil or focus:IsAncestorOf(self) then
		focus = self:GetDefaultFocus()
		if focus then
			focus:SetFocus()
		end
	end
	-- Ancestor check avoids infinite recursion.
	if focus and not focus:IsAncestorOf(self) then
		return focus:OnFocusMove(dir, down)
	end
end


return NpcPrompt
