local CheckBox = require "widgets.checkbox"
local ConfirmDialog = require "screens.dialogs.confirmdialog"
local Enum = require "util.enum"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Panel = require "widgets/panel"
local Screen = require "widgets/screen"
local Text = require "widgets/text"
local TextEdit = require "widgets/textedit"
local Widget = require "widgets/widget"
local fmodtable = require "defs.sound.fmodtable"
local lume = require "util.lume"
local templates = require "widgets.ftf.templates"


local TEXT_W = 1080
local INPUT_H = 100

local Emote = Enum{
	-- These string values are defined by #backend.
	-- They match the order in game.cpp
	"new_player",
	"experienced",
	"seasoned",
	"veteran",
	"hardcore",
}

local function MakeCheckBox()
	local w = CheckBox()
	w:SetSize(60, 60)
	w:SetTextSize(50)
	return w
end

local Category = Enum{
	"AUDIO",
	"VISUAL",
	"WORDS",
	"OTHER",
	-- Too many categories to include these too. Don't want analysis paralysis.
	--~ "GAMEPLAY",
	--~ "LEVEL_DESIGN",
	--~ "NETWORK", -- online multiplayer
	--~ "UI",
}

--- Local Games: TIME DOES NOT PASS WHILE THIS SCREEN IS UP! DO NOT ANIMATE ANYTHING!!!
--- Network Games: Time still passes ...
FeedbackScreen = Class(Screen, function(self, gamestate, screen_shot_texture)
	Screen._ctor(self, "FeedbackScreen")

	self.is_popup = true
	self:SetAnchors("center", "center")

	self.send_save_file = true
	self.send_screenshot = true
	self.send_log = true

	-- Get the screen size
	local screen_w, screen_h = TheFrontEnd:GetScreenDims()
	self.screen_w = math.ceil(screen_w / TheFrontEnd:GetBaseWidgetScale())
	self.screen_h = math.ceil(screen_h / TheFrontEnd:GetBaseWidgetScale())

	local form_font_size = 44

	-- Add scrim
	self.scrim = self:AddChild(Image("images/square.tex"))
		:SetMultColor(0x221C1Aff)
		:SetMultColorAlpha(0.9)
		:SetSize(self.screen_w, self.screen_h)

	-- And popup panel
	self.popup_bg = self:AddChild(Panel("images/bg_feedback_screen_bg/feedback_screen_bg.tex"))
		:SetNineSliceCoords(0, 400, 3841, 450)
		:SetSize(RES_X, 1600)
		:LayoutBounds("center", "center", self.scrim)

	-- Hitbox for content alignment
	self.hitbox = self:AddChild(Image("images/square.tex"))
		:SetMultColor(0xFF0000ff)
		:SetMultColorAlpha(0.1)
		:SetSize(3200, 1000)
		:Hide()

	-- Calculate screenshot size
	local sw, sh = TheSim:GetTextureSize("screen_capture")
	local limit = 900
	local img_scale = 1620 / sw
	if sh * img_scale > limit then
		img_scale = limit / sh
	end

	-- Titles
	self.title = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TITLE))
		:SetText(STRINGS.UI.FEEDBACK_SCREEN.TITLE)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:Bloom(0.1)

	-- Contains the info panel, form and image
	self.contents = self:AddChild(Widget())

	-- And info panel
	self.info_bg = self.contents:AddChild(Image("images/ui_ftf_feedback/InfoBg.tex"))
		:SetScale(1.1)
	self.about = self.contents:AddChild(Text(FONTFACE.DEFAULT, 48))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetFadeAlpha(0.6)
		:SetWordWrap(true)
		:SetAutoSize(460)
		:SetText(STRINGS.UI.FEEDBACK_SCREEN.ABOUT)

	self.subject_label = self.contents:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetFadeAlpha(0.6)
		:SetWordWrap(true)
		:SetAutoSize(TEXT_W)
		:SetText(STRINGS.UI.FEEDBACK_SCREEN.SUBJECT_LABEL)
	self.subject_inputbox = self.contents:AddChild(TextEdit(FONTFACE.DEFAULT, form_font_size))
		:SetSize(TEXT_W, INPUT_H)
		:SetEditing(false)
		:SetHAlign(ANCHOR_LEFT)
		:SetForceEdit(true)
		:SetTextPrompt(STRINGS.UI.FEEDBACK_SCREEN.SUBJECT_PROMPT)
		:SetFn(function()
			self:_RefreshSendButton()
		end)

	self.message_label = self.contents:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetFadeAlpha(0.6)
		:SetWordWrap(true)
		:SetAutoSize(TEXT_W)
		:SetText(STRINGS.UI.FEEDBACK_SCREEN.MESSAGE_LABEL)
	self.message_inputbox = self.contents:AddChild(TextEdit(FONTFACE.DEFAULT, form_font_size))
		:SetSize(TEXT_W, 700)
		:SetEditing(false)
		:SetAllowNewline(true)
		:SetHAlign(ANCHOR_LEFT)
		:SetVAlign(ANCHOR_TOP)
		:SetForceEdit(true)
		:EnableWordWrap(true)
		:SetLines(15)
		:SetString("")

	self.subject_inputbox:SetOnTabGoToTextEditWidget(self.message_inputbox)
	self.message_inputbox:SetOnTabGoToTextEditWidget(self.subject_inputbox)

	self.illustration = self.contents:AddChild(Image("images/ui_ftf_feedback/PlaneIllustration.tex"))
		:SetHiddenBoundingBox(true)

	self.img = self.contents:AddChild(Image("screen_capture")
		:SetSize(sw * img_scale, sh * img_scale))
		:Offset(0, -40)


	-- local EMO_SZ = 200
	-- self.emotion_buttons = {}

	-- self.emotion_highlight = self.contents:AddChild(Image("images/ui_ftf_feedback/Selected.tex"))
	-- 	:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
	-- 	:SetSize(EMO_SZ + 20, EMO_SZ + 20)
	-- 	:SetFadeAlpha(0.7)
	-- 	:Hide()
	-- self.emotion_button_root = self:AddChild(Widget())

	local function RefreshAttachmentFace()
		local sending_anything = (self.send_log
			or self.send_screenshot
			or self.send_save_file
			or self.send_replay)

		local needs_visual = self.category == Category.s.VISUAL
			or self.category == Category.s.WORDS

		local needs_something = self.category == Category.s.OTHER

		self.attachment_face:SetShown(
			not self.send_screenshot and needs_visual
			or not sending_anything and needs_something)
	end

	self.attachments_root = self.contents:AddChild(Widget())

	self.attachment_face = self.attachments_root:AddChild(Widget("attachment_face"))
		:Hide()
	self.attachment_face.emotion = self.attachment_face:AddChild(Image("images/ui_ftf_feedback/bad.tex"))
		:SetScale(0.5)
		:Offset(-50, 0)
	self.attachment_face.label = self.attachment_face:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
		:SetText(STRINGS.UI.FEEDBACK_SCREEN.BUG_ATTACHMENTS)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetRegistration("left", "center")
		:SetAutoSize(300)
		:LayoutBounds("after", "center", self.attachment_face.emotion)
		:Offset(20, 0)

	-- don't have checkbox yet
	self.attachments_root:AddChild(MakeCheckBox())
		:SetText(STRINGS.UI.FEEDBACK_SCREEN.SEND_LOG)
		:SetOnChangedFn(function(val)
			self.send_log = val
			RefreshAttachmentFace()
		end)
		:SetValue(true)

	self.attachments_root:AddChild(MakeCheckBox())
		:SetText(STRINGS.UI.FEEDBACK_SCREEN.SEND_SCREENSHOT)
		:SetOnChangedFn(function(val)
			self.send_screenshot = val
			RefreshAttachmentFace()
		end)
		:SetValue(true)

	self.attachments_root:AddChild(MakeCheckBox())
		:SetText(STRINGS.UI.FEEDBACK_SCREEN.SEND_SAVE)
		:SetOnChangedFn(function(val)
			self.send_save_file = val
			RefreshAttachmentFace()
		end)
		:SetValue(true)

	if TheWorld
		and TheFrontEnd
		and TheFrontEnd.debugMenu
		and TheFrontEnd.debugMenu.history
		and TheFrontEnd.debugMenu.history:IsEnabled()
	then
		self.attachments_root:AddChild(MakeCheckBox())
			:SetText(STRINGS.UI.FEEDBACK_SCREEN.SEND_REPLAY)
			:SetToolTip(STRINGS.UI.FEEDBACK_SCREEN.SEND_REPLAY_TT)
			:SetOnChangedFn(function(val)
				self.send_replay = val
				RefreshAttachmentFace()
			end)
			:SetValue(false)
	end

	self.attachment_face:MoveToFront() -- to bottom


	self.categories_root = self.contents:AddChild(Widget())
	self.category_checks = {}

	for k, v in ipairs(Category:Ordered()) do
		local cat = v
		self.category_checks[v] = self.categories_root:AddChild(MakeCheckBox())
			:SetText(STRINGS.UI.FEEDBACK_SCREEN.CATEGORIES[v])
			:SetOnChangedFn(function(val)
				self:SetCategory(cat)
				RefreshAttachmentFace()
			end)
			:LayoutBounds("left", "below")
			:Offset(0, -20)
	end

	-- Back button
	self.close_btn = self:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		:SetOnClick(function()
			-- Print feedback so you can copypaste.
			TheLog.ch.Feedback:printf("Cancelling feedback:\n%s\n%s", self.subject_inputbox:GetText(), self.message_inputbox:GetText())
			TheSim:CancelFeedback()
			TheFrontEnd:PopScreen(self)
		end)

	-- Submit button
	self.send_btn = self:AddChild(templates.Button(STRINGS.UI.FEEDBACK_SCREEN.SUBMIT))
		:SetOnClickFn(function()
			self:SendFeedback()
		end)

	self:Layout()

	self:SetCategory(Category.s.OTHER)
	-- self:SetEmotion(1)

	self:_RefreshSendButton()
end)

function FeedbackScreen:SetCustomInstructionText(msg)
	assert(msg)
	-- Also change colours to draw attention to the changed instructions.
	self.about:SetText(msg)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_TITLE)
	self.info_bg
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
	return self
end

function FeedbackScreen:TriggerAutoSend()
	-- Untranslated because they're only for our benefit! But these strings are
	-- visible to players while they send.
	self.subject_inputbox:HandleTextInput("Autosending feedback") -- must not be empty so send succeeds
	self.message_inputbox:HandleTextInput("")
	self:SendFeedback()
	return self
end

function FeedbackScreen:_GetFeedbackName()
	for i,player in ipairs(AllPlayers) do
		local name = player.Network:GetClientName()
		if name and name:len() > 0 then
			return player.Network:GetClientName()
		end
	end
	-- In main menu, we have no players so we'll keep a cached name.
	return Profile:GetFeedbackName()
end

function FeedbackScreen:OnOpen()
	FeedbackScreen._base.OnOpen(self)
	self.subject_inputbox:SetFocus()
	TheFeedbackScreen = self
	if TheNet:IsGameTypeLocal() then
		TheSim:SetTimeScale(0)
	end
	self.subject_inputbox:SetEditing(true)
end

function FeedbackScreen:OnClose()
	FeedbackScreen._base.OnClose(self)
	TheFeedbackScreen = nil
	if TheNet:IsGameTypeLocal() then
		TheSim:SetTimeScale(1)
	end
end

function FeedbackScreen:SetDefaultFocus()
	self.message_inputbox:SetFocus()
end

function FeedbackScreen:SendFeedback()
	if self.submitting then
		TheLog.ch.Feedback:print("Can't send feedback: already sending.")
		return
	end
	self.submitting = true

	local submit_popup = ConfirmDialog(nil, nil, true)
		:SetTitle(STRINGS.UI.FEEDBACK_SCREEN.SUBMITTING_TITLE)
		:HideArrow()
		:HideYesButton()
		:HideNoButton()
		:SetCancelButton(STRINGS.UI.FEEDBACK_SCREEN.CANCEL, function()
			self.submitting = false
			TheFrontEnd:PopScreen(self.submit_popup)
		end)
		:CenterButtons()

	self.submit_popup = submit_popup
	local timer = 0
	self.submit_popup.OnUpdate = function(self, dt)
		timer = timer + dt * 2
		local dots = math.floor(timer % 3) + 1
		local prompt = STRINGS.UI.FEEDBACK_SCREEN.SUBMITTING_BODY
		prompt = prompt .. string.rep(".", dots)
		submit_popup:SetText(prompt)
	end

	self:RunUpdater(
		Updater.Series({
				-- Wait long enough to ensure the popup is visible.
				Updater.Wait(5 * TICKS),
				Updater.Do(function()

					local gamestatus = "" -- string to populate a txt file
					local infodotlua = "" -- string to populate a lua file
					local input_title = self.subject_inputbox:GetText() or ""

					if self.send_replay then
						TheFrontEnd.debugMenu.history:Save()
					end
					if self.send_log then
						pcall(function()
							print("-- Extra Feedback Logging --")
							-- Don't send user-identifying information here (usernames)!
							print("TheWorld:", TheWorld)
							c_printsettings()
							c_printplayerdata()
						end)
						print("Feedback Title:", input_title)
					end

					local data = {}
					pcall(function()
						data.safefile_runs = TheSaveSystem.progress:GetValue("num_runs")
						data.lifetime_runs = TheSaveSystem.permanent:GetValue("num_runs")
						data.playercount_total = #AllPlayers
						data.playercount_local = lume.count(AllPlayers, EntityScript.IsLocal)
						data.playercount_remote = data.playercount_total - data.playercount_local
						data.net_join_code = TheNet:GetJoinCode()

						data.player_name = self:_GetFeedbackName()
						Profile:SetFeedbackName(data.player_name)
						-- If something goes wrong, this point may not get hit. All
						-- above values may be nil.
					end)

					local postfix = ("\n----\nRuns in save: %i\nRuns in life: %i"):format(data.safefile_runs or 0, data.lifetime_runs or 0)
					if (data.playercount_total or 0) > 1 then
						postfix = postfix .. ("\nPlayers: %i local, %i remote"):format(data.playercount_local or 0, data.playercount_remote or 0)
					end
					if data.net_join_code and data.net_join_code:len() > 0 then
						postfix = postfix .. ("\nJoin Code: %s"):format(data.net_join_code)
					end
					if RELEASE_CHANNEL ~= "dev" then
						postfix = postfix .. "\n* release channel: ".. RELEASE_CHANNEL
					end
					TheSim:CreateFeedback(
						input_title,
						(self.message_inputbox:GetText() or "")..postfix,
						data.player_name or "Anonymous",
						self.category,
						gamestatus,
						infodotlua,
						self:GetEmotion(data.lifetime_runs or 0),
						self.send_save_file,
						self.send_screenshot,
						self.send_log,
						self.send_replay
						)
					end),
		}))

	TheFrontEnd:PushScreen(self.submit_popup)
end

function FeedbackScreen:GetEmotion(lifetime_runs)
	-- Not using emotions for "this sucks":
	-- https://klei.slack.com/archives/CN40PCAGH/p1687891007207319?thread_ts=1687313131.276339&cid=CN40PCAGH

	-- Use emotion to bucket player experience to draw more attention to
	-- late-game experience. Emotion is "how good the player is".
	if lifetime_runs > 200 then
		return Emote.id.hardcore
	elseif lifetime_runs > 100 then
		return Emote.id.veteran
	elseif lifetime_runs > 60 then
		return Emote.id.seasoned
	elseif lifetime_runs > 20 then
		return Emote.id.experienced
	else
		return Emote.id.new_player
	end
end

function FeedbackScreen:SubmitFeedbackResult(response_code, response)
	if self.submitting then
		self.submitting = false
		TheLog.ch.Feedback:print("Feedback response code:", response_code)
		TheLog.ch.Feedback:print("response:", response)
		TheFrontEnd:PopScreen() -- pop the sending... dialog
		if response_code == 200 then
			-- think this went okay
			TheFrontEnd:PushScreen(
				ConfirmDialog(nil, nil, true)
					:SetTitle(STRINGS.UI.FEEDBACK_SCREEN.SUBMITTED_TITLE)
					:SetText(STRINGS.UI.FEEDBACK_SCREEN.SUBMITTED_BODY)
					:HideArrow()
					:SetYesButton(STRINGS.UI.FEEDBACK_SCREEN.SUBMITTED_OK, function()
						-- Pop dialog and feedbackscreen
						TheFrontEnd:PopScreen()
						TheFrontEnd:PopScreen()
					end)
					:HideNoButton()
					:CenterButtons()
			)
		else
			if response_code == 413 then
				-- too large
				TheFrontEnd:PushScreen(
					ConfirmDialog(nil, nil, true)
						:SetTitle(STRINGS.UI.FEEDBACK_SCREEN.SUBMITTED_TITLE_ERROR)
						:SetText(STRINGS.UI.FEEDBACK_SCREEN.SUBMITTED_BODY_ERROR_TOO_LARGE)
						:HideArrow()
						:SetYesButton(STRINGS.UI.FEEDBACK_SCREEN.SUBMITTED_OK, function()
							-- Only pop dialog
							TheFrontEnd:PopScreen()
						end)
						:HideNoButton()
						:CenterButtons()
				)
			else
				-- other error
				TheFrontEnd:PushScreen(
					ConfirmDialog(nil, nil, true)
						:SetTitle(STRINGS.UI.FEEDBACK_SCREEN.SUBMITTED_TITLE_ERROR)
						:SetText(STRINGS.UI.FEEDBACK_SCREEN.SUBMITTED_BODY_ERROR_UNKNOWN)
						:HideArrow()
						:SetYesButton(STRINGS.UI.FEEDBACK_SCREEN.SUBMITTED_OK, function()
							-- Only pop dialog
							TheFrontEnd:PopScreen()
						end)
						:HideNoButton()
						:CenterButtons()
				)
			end
		end
	else
		TheLog.ch.Feedback:print("Not submitting - ignore result")
	end
end

function FeedbackScreen:Layout()
	-- Get the screen size
	local screen_w, screen_h = TheFrontEnd:GetScreenDims()
	self.screen_w = math.ceil(screen_w / TheFrontEnd:GetBaseWidgetScale())
	self.screen_h = math.ceil(screen_h / TheFrontEnd:GetBaseWidgetScale())

	-- Layout title
	self.title:LayoutBounds("center", "above", self.hitbox)
		:Offset(0, 30)

	-- Layout form content
	self.info_bg:LayoutBounds("left", "top", self.hitbox)
		:Offset(0, -80)
	self.about:LayoutBounds("center", "center", self.info_bg)
		:Offset(-5, 0)
	self.illustration:LayoutBounds("after", "top", self.info_bg)
		:Offset(-60, 230)
	self.subject_label:LayoutBounds(nil, "top", self.hitbox)
		:LayoutBounds("after", nil,  self.info_bg)
		:Offset(60, 0)
	self.subject_inputbox:LayoutBounds("left", "below", self.subject_label)
		:Offset(0, -5)
	self.categories_root:LayoutChildrenInAutoSizeGrid(8, 60, 20)
		:CenterChildren()
		:LayoutBounds("center", "below", self.subject_inputbox)
		:Offset(0, -20)
	self.message_label:LayoutBounds("left", "below", self.subject_inputbox)
		:Offset(0, -15 - 80)
	self.message_inputbox:LayoutBounds("left", "below", self.message_label)
		:Offset(0, -5)

	local left_column_x_offset = 40
	self.img:LayoutBounds("after", "bottom", self.message_inputbox)
		:Offset(left_column_x_offset, 0)

	--~ self.emotion_button_root:LayoutBounds("center", "below", self.hitbox)
	--~ 	:Offset(0, 70)

	self.attachments_root:LayoutChildrenInAutoSizeGrid(1, 60, 20)
		-- :LayoutBounds("left", "below", self.img)
		:LayoutBounds("center", "below", self.info_bg)
		:Offset(0, -50)

	self.contents:LayoutBounds("center", nil, self.hitbox)

	self.close_btn:LayoutBounds("right", nil, self)
		:LayoutBounds(nil, "above", self.hitbox)
		:Offset(-100, 100)

	self.send_btn:LayoutBounds("center", "below", self.hitbox)
		:Offset(0, -160)

	return self
end


function FeedbackScreen:_RefreshSendButton()
	if self.subject_inputbox:GetText():len() < 5 then
		self.send_btn:Disable()
			:SetToolTip(STRINGS.UI.FEEDBACK_SCREEN.REQUIRE_SUMMARY)
	else
		self.send_btn:Enable()
			:SetToolTip()
	end
end

function FeedbackScreen:SetCategory(cat)
	for k, v in pairs(self.category_checks) do
		v:SetValue(k == cat, true)
	end
	self.category = cat

	self.message_inputbox:SetTextPrompt(STRINGS.UI.FEEDBACK_SCREEN.CATEGORY_PROMPT[cat])
end

-- function FeedbackScreen:SetEmotion(idx)
-- 	if idx and self.emotion_buttons[idx] then
-- 		self.emotion_highlight:LayoutBounds("center", "center", self.emotion_buttons[idx])
-- 		self.emotion_highlight:Show()
-- 		self.emotion_idx = idx
-- 	end
-- end

function FeedbackScreen:HandleControlUp(control, device)
	if control:Has(Controls.Digital.MENU_CANCEL) then
		self:GetFE():PopScreen(self)
		return true

	elseif control:Has(Controls.Digital.MENU_SUBMIT) then
		if self.subject_inputbox:IsEnabled() then
			self:SendFeedback()
		end
		return true
	end

	return false
end

function FeedbackScreen:OnBecomeActive()
	FeedbackScreen._base.OnBecomeActive(self)

	TheAudio:StartFMODSnapshot(fmodtable.Snapshot.FullscreenOverlay)
end

function FeedbackScreen:OnBecomeInactive()
	FeedbackScreen._base.OnBecomeInactive(self)

	TheAudio:StopFMODSnapshot(fmodtable.Snapshot.FullscreenOverlay)
end

return FeedbackScreen
