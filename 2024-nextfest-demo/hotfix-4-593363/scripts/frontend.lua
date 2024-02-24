
local CAN_USE_DBUI = DEV_MODE and Platform.IsWindows()

local cursor = require "content.cursor"
local easing = require("util.easing")
local kassert = require "util.kassert"
local lume = require "util.lume"
local Widget = require "widgets/widget"
local ChromaKeyScreen = require "screens.chromakeyscreen"
local DebugPanel = CAN_USE_DBUI and require "dbui.debug_panel" or nil
local DebugSettings = require "debug.inspectors.debugsettings"
local DebugMenu = require "debug/debugmenu"
local DebugNodes = CAN_USE_DBUI and require "dbui.debug_nodes" or nil
local Screen = require "widgets.screen"
local Text = require "widgets/text"
local UIAnim = require "widgets/uianim"
local Image = require "widgets/image"
local Letterbox = require "widgets.ftf.letterbox"
local ConsoleScreen = require "screens/consolescreen"
local ConfirmDialog = require "screens.dialogs.confirmdialog"
local templates = require "widgets/ftf/templates"
local LoadingWidget = require "widgets/redux/loadingwidget"
local ScriptErrorWidget = require "widgets/scripterrorwidget"
local NotificationsQueueWidget = require "widgets/notificationsqueuewidget"
local NotificationWidget = require "widgets/notificationwidget"
local Tooltip = require "widgets/tooltip"
local UIHelpers = require "ui/uihelpers"
local fmodtable = require "defs.sound.fmodtable"
require "constants"


local NAV_REPEAT_TIME = 0.25 -- see also Controls.Digital.MENU_RIGHT.repeat_rate.
local SCROLL_REPEAT_TIME = .05
local MOUSE_SCROLL_REPEAT_TIME = 0
local SPINNER_REPEAT_TIME = .25

local save_fade_time = .5


local TTDELAY = 0--.2



local FrontEnd = Class(function(self, name)
	-- We reference the global when creating our initial widgets.
	TheFrontEnd = self
	----------------------------------------- From GL  -----------------------------------------
	self.dirtytransforms = {}
	self.audio_param_stack = {}
	self.base_scale = 1

	self.horizontal_safe_zone = 0.0
	self.vertical_safe_zone = 0.0

	self.settings = DebugSettings("FrontEnd.settings")
		:Option("console_log_h", "center")
		:Option("console_log_v", "center")
		:Option("console_log_always_on", false)

	self.enable = true

	self.screen_mode = SCREEN_MODE.MONITOR
	--------------------------------------------------------------------------------------------

	self.screenstack = {}

	self.sceneroot = Widget("sceneroot") --:SetFE(self)

	self.fe_root = self.sceneroot

	-- Setup some primary roots as screens to allow their children to use fill
	-- anchors.
	self.underlayroot = self.sceneroot:AddChild(Screen("underlayroot"))
	self.underlayroot.is_overlay = true -- doesn't matter because not in screenstack
	self.screenroot = self.sceneroot:AddChild(Screen("screenroot")) --:SetFE(self)
	self.overlayroot = self.sceneroot:AddChild(Screen("overlayroot"))
	self.overlayroot.is_overlay = true -- doesn't matter because not in screenstack

	---- NOTIFICATIONS -------

	self.notifications_queue = self.sceneroot:AddChild(NotificationsQueueWidget())
		:SetName("Notifications queue widget")


	------ CONSOLE -----------
	self.console_root = self.sceneroot:AddChild(Widget("console_root"))
	local console_size = Vector2(1800, 812)
	self.consoletextbg = self.console_root:AddChild(Image("images/global/square.tex"))
		:SetSize(console_size:scale(1.1):unpack())
		:SetMultColor(0,0,0,0.25)

	self.consoletext = self.console_root:AddChild(Text(FONTFACE.CODE, FONTSIZE.COMMON_OVERLAY, "CONSOLE TEXT"))
	self.consoletext:SetVAlign(ANCHOR_BOTTOM)
	self.consoletext:SetHAlign(ANCHOR_LEFT)
	self.consoletext:SetAnchors("center","center")
	self.consoletext:SetScaleMode(SCALEMODE_PROPORTIONAL)

	self.consoletext:SetRegionSize(console_size:unpack())
	self.consoletext:SetPosition(0,0,0)

	self:SetConsoleLogCorner(self.settings.console_log_h, self.settings.console_log_v)

	local always_on = DEV_MODE and TheFrontEnd.settings.console_log_always_on
	if not always_on then
		self:HideConsoleLog()
	end
	-----------------

	self.blackoverlay = templates.BackgroundTint()
	self.blackoverlay:SetMultColor(0,0,0,0)
	self.blackoverlay:SetClickable(false)
	self.blackoverlay:Hide()

	self.topblackoverlay = templates.BackgroundTint()
	self.topblackoverlay:SetMultColor(0,0,0,0)
	self.topblackoverlay:SetClickable(false)
	self.topblackoverlay:Hide()

	local w, h = self:GetScreenDims()
	-- self.fader = self.overlayroot:AddChild(SolidBox(w, h , 1, 1, 0, 0):Hide():SetPos(w/2,h/2))
	-- self.fader:Show()
	-- TODO: Swipe is never visible. Not sure why?
	self.swipeoverlay = Image("images/global/noise.tex")
		:SetAnchors("fill", "fill")
	self.swipeoverlay:SetEffect( "shaders/swipe_fade.ksh" )
	self.swipeoverlay:SetEffectParams(0.5,0,0,0)
	self.swipeoverlay:SetMultColor(1,1,1,0)
	self.swipeoverlay:SetClickable(false)
	self.swipeoverlay:Hide()

	self.topswipeoverlay = Image("images/global/noise.tex")
		:SetAnchors("fill", "fill")
	self.topswipeoverlay:SetEffect( "shaders/swipe_fade.ksh" )
	self.topswipeoverlay:SetEffectParams(0,0,0,0)
	self.topswipeoverlay:SetMultColor(1,1,1,0)
	self.topswipeoverlay:SetClickable(false)
	self.topswipeoverlay:Hide()

	self.whiteoverlay = templates.BackgroundTint()
	self.whiteoverlay:SetMultColor(FADE_WHITE_COLOR[1], FADE_WHITE_COLOR[2], FADE_WHITE_COLOR[3], 0)
	self.whiteoverlay:SetClickable(false)
	self.whiteoverlay:Hide()

	self.vigoverlay = templates.BackgroundVignette()
	self.vigoverlay:SetClickable(false)
	self.vigoverlay:Hide()

	self.topwhiteoverlay = templates.BackgroundTint()
	self.topwhiteoverlay:SetMultColor(FADE_WHITE_COLOR[1], FADE_WHITE_COLOR[2], FADE_WHITE_COLOR[3], 0)
	self.topwhiteoverlay:SetClickable(false)
	self.topwhiteoverlay:Hide()

	self.topvigoverlay = templates.BackgroundVignette()
	self.topvigoverlay:SetClickable(false)
	self.topvigoverlay:Hide()

	self.overlayroot:AddChild(self.topblackoverlay)
	self.overlayroot:AddChild(self.topwhiteoverlay)
	self.overlayroot:AddChild(self.topvigoverlay)
	self.overlayroot:AddChild(self.topswipeoverlay)
	self.sceneroot:AddChild(self.blackoverlay)
	self.sceneroot:AddChild(self.whiteoverlay)
	self.sceneroot:AddChild(self.vigoverlay)
	self.sceneroot:AddChild(self.swipeoverlay)

	self.alpha = 0

	self.title = Text(FONTFACE.TITLE, 100)
	self.title:SetPosition(0, -30, 0)
	self.title:Hide()
	self.title:SetAnchors("center","center")
	self.overlayroot:AddChild(self.title)

	self.subtitle = Text(FONTFACE.TITLE, 70)
	self.subtitle:SetPosition(0, 70, 0)
	self.subtitle:Hide()
	self.subtitle:SetAnchors("center","center")
	self.overlayroot:AddChild(self.subtitle)

	if Platform.IsPS4() then
		self.saving_indicator = UIAnim()
		self.saving_indicator:GetAnimState():SetBank("saving_indicator")
		self.saving_indicator:GetAnimState():SetBuild("saving_indicator")
		self.saving_indicator:GetAnimState():PlayAnimation("save_loop", true)
		self.saving_indicator:SetAnchors("right","bottom")
		self.saving_indicator:SetScaleMode(SCALEMODE_PROPORTIONAL)
		self.saving_indicator:SetMaxPropUpscale(MAX_HUD_SCALE)
		self.saving_indicator:SetPosition(-10, 40)
		self.saving_indicator:Hide()
	end

	self:HideTitle()

	self.gameinterface = CreateEntity("GameInterface")
		:MakeSurviveRoomTravel()
	self.gameinterface.entity:AddSoundEmitter()
	self.gameinterface.entity:AddTwitchOptions()
	self.gameinterface.entity:AddAccountManager()

	TheInput:AddKeyHandler(function(key, down) self:OnRawKey(key, down) end )
	TheInput:AddTextInputHandler(function(text) self:OnTextInput(text) end )

	self.tracking_mouse = true
	self.repeat_time = -1
	self.scroll_repeat_time = -1
	self.spinner_repeat_time = -1

	self.topFadeHidden = false

	self.updating_widgets = setmetatable({}, {__mode="k"})
	self.num_pending_saves = 0
	self.save_indicator_time_left = 0
	self.save_indicator_fade_time = 0
	self.save_indicator_fade = nil
	self.autosave_enabled = true

	self.loading_widget = self.sceneroot:AddChild(LoadingWidget())
	self.loading_widget:SetEnabled(true)	-- Enable it by default on a new sim

	self.error_widget = nil

	self:CreateDebugMenu()


	self.tooltip_widgets = {}
	self.tooltip_delay = TTDELAY

	-- data from the current game that is to be passed back to the game when the server resets (used for showing results in events when back in the lobby)
	-- Never set this to nil or people will crash. If needed, test for empty list if needed to control flow.
	self.match_results = {}

	self:InitScreenSize()

	-- Start handling notifications
	self.notifications_queue:StartUpdating()

	if RUN_GLOBAL_INIT then
		cursor.CreateAllCursors()
	end
	self.current_cursor = cursor.Style.s.pointer -- required to call SetCursorSize
	self:SetCursorSize(TheGameSettings:Get("graphics.cursor_size"))
	self:SetCursor(self.current_cursor)

	TheLog.ch.FrontEnd:print("FrontEnd initialized")
end)

function FrontEnd:CreateDebugMenu()
	if CAN_USE_DBUI then
		self.imgui = require "dbui.imgui"
		self.imgui:SetMouseCursorScale(cursor.GetCursorScaleRelativeToStandard())
		self.imgui_font_size = Profile:GetValue("imgui_font_size") or 1
	end
	self.debug_panels = {}
	self.debugMenu = DebugMenu(CAN_USE_DBUI)
end

function FrontEnd:ShowSavingIndicator()
	if self.saving_indicator ~= nil and TheSystemService:IsStorageEnabled() then
		if not self.saving_indicator.shown then
			self.save_indicator_time_left = 3
			self.saving_indicator:Show()
			self.saving_indicator:ForceStartWallUpdating()
			self.save_indicator_fade_time = save_fade_time
			self.saving_indicator:GetAnimState():SetMultColor(1,1,1,0)
			self.save_indicator_fade = "in"
		end

		self.num_pending_saves = self.num_pending_saves + 1
	end
end

function FrontEnd:HideSavingIndicator()
	if self.saving_indicator ~= nil and self.num_pending_saves > 0 then
		self.num_pending_saves = self.num_pending_saves - 1
	end
end

function FrontEnd:HideTopFade()
	self.topwhiteoverlay:Hide()
	self.topvigoverlay:Hide()
	self.topblackoverlay:Hide()
	self.topswipeoverlay:Hide()
	self.topFadeHidden = true
end

function FrontEnd:ShowTopFade()
	self.topFadeHidden = false
	if self.fade_type == "white" then
		self.topwhiteoverlay:Show()
		self.topvigoverlay:Show()
	elseif self.fade_type == "black" then
		self.topblackoverlay:Show()
	elseif self.fade_type == "swipe" then
		self.topswipeoverlay:Show()
	end
end

function FrontEnd:ShowTextNotification(icon, title, description, duration)

	-- Regular notification widget with icon, title and description
	local new_notif = NotificationWidget.TextNotificationWidget(duration)
	new_notif:SetData(icon, title, description)

	self.notifications_queue:AddNotification(new_notif)

	return new_notif
end

function FrontEnd:GetFocusWidget()
	local top = self:GetActiveScreen()
	if top then
		return top:GetDeepestFocus()
	end
end

-- This returns the widget the mouse is over, regardless of whether it has focus (so it can be the text widget on a button)
function FrontEnd:GetHitWidget()
	local ents = TheInput:GetAllEntitiesUnderMouse()
	local ent = ents and ents[1]
	if ent then
		return ent.widget
	end
end

function FrontEnd:GetIntermediateFocusWidgets()
	local top = self:GetActiveScreen()
	if top then
		local widgs = {}
		local nextWidget = top:GetFocusChild()

		while nextWidget and nextWidget ~= self:GetFocusWidget() do
			table.insert(widgs, nextWidget)
			nextWidget = nextWidget:GetFocusChild()
		end
		return widgs
	end
end

function FrontEnd:StopTrackingMouse(autofocus)
	self.tracking_mouse = false
	if autofocus then
		local screen = self:GetActiveScreen()
		if screen ~= nil then
			screen:SetDefaultFocus()
		end
	end
end

function FrontEnd:IsControlsDisabled()
	return self:GetFadeLevel() > 0
		or (self.fadedir == FADE_OUT and self.fade_delay_time == nil)
end

-- Called when directional navigation was used to give something focus
-- (keyboard or gamepad)
function FrontEnd:OnFocusMove(dir, down, device_type, device_id)
	if self.focus_locked or self:IsControlsDisabled() then
		return true
	elseif #self.screenstack > 0 then
		if self.screenstack[#self.screenstack]:OnFocusMove(dir, down, device_type, device_id) then
			self:GetSound():PlaySound(fmodtable.Event.hover)
			self.tracking_mouse = false
			return true
		elseif self.tracking_mouse and down and self.screenstack[#self.screenstack]:SetDefaultFocus() then
			self.tracking_mouse = false
			return true
		end
	end
end

-- Called when something new gained focus
function FrontEnd:OnFocusChanged(new_focus)
	if self.error_widget then
		return
	end

	if self.focus_locked or self:IsControlsDisabled() then
		return true
	elseif #self.screenstack > 0 then
		self.screenstack[#self.screenstack]:OnFocusChanged(new_focus)
	end
end

function FrontEnd:OnControl(controls, down, device_type, trace, device_id)
	if controls:Has(Controls.Digital.TOGGLE_LOG) then
		print("Controls.Digital.TOGGLE_LOG down:",down)
	end
	-- if there is a textedit that is currently editing, stop editing if the player clicks somewhere else
	if self.textProcessorWidget ~= nil and not self.textProcessorWidget.focus and not down and controls:Has(Controls.Digital.CLICK_PRIMARY) then
		self:SetForceProcessTextInput(false, self.textProcessorWidget)
	end

	if controls:Has(Controls.Digital.INVENTORY_EXAMINE) then
		if self.tooltip_widget
			and self.tooltip_widget.OnExamine -- only if it supports examine
			and self.tooltip_focus
			and self.tooltip_widget.shown
			and not self.tooltip_focus.removed
			and not self.tooltip_widget.ignores_input
		then
			self.tooltip_widget:OnExamine(down)
			return true
		end
	end

	if self:IsControlsDisabled() then
		return false
	elseif #self.screenstack > 0
		and (self.textProcessorWidget ~= nil
			and not self.textProcessorWidget.focus
			and self.textProcessorWidget:OnControl(controls, down, device_type, trace, device_id))
	then
		-- while editing a text box and hovering over something else, consume the accept button (the raw key handlers will deal with it).
		return true

	elseif CONSOLE_ENABLED and not down and controls:Has(Controls.Digital.OPEN_DEBUG_CONSOLE) then
		local activeScreen = self:GetActiveScreen()
		if activeScreen and not activeScreen:is_a(ConsoleScreen) then
			self:PushScreen(ConsoleScreen())
			return true
		end
	elseif DEBUG_MENU_ENABLED and not down and controls:Has(Controls.Digital.OPEN_DEBUG_MENU) then
		if not self:GetActiveScreen():is_a(DebugMenuScreen) then
			self:PushScreen(DebugMenuScreen())
			return true
		end
	elseif SHOWLOG_ENABLED and not down and controls:Has(Controls.Digital.TOGGLE_LOG) then
		if self.console_root.shown then
			self:HideConsoleLog()
		else
			self:ShowConsoleLog()
		end
		return true

		--[[
	elseif controls:Has(Controls.Digital.CANCEL) then
		return screen:OnCancel(down)
--]]
	end
end

function FrontEnd:ShowTitle(text,subtext)
	self.title:SetText(text)
	self.title:Show()
	self.subtitle:SetText(subtext)
	self.subtitle:Show()
	self:StartTileFadeIn()
end

local fade_time = 2

function FrontEnd:DoTitleFade(dt)
	if self.fade_title_in == true or self.fade_title_out == true then
		dt = math.min(dt, 1/30)
		if self.fade_title_in == true and self.fade_title_time <fade_time then
			self.fade_title_time = self.fade_title_time + dt
		elseif self.fade_title_out == true and self.fade_title_time >0 then
			self.fade_title_time = self.fade_title_time - dt
		end

		self.fade_title_alpha = easing.inOutCubic(self.fade_title_time, 0, 1, fade_time)

		self.title:SetAlpha(self.fade_title_alpha)
		self.subtitle:SetAlpha(self.fade_title_alpha)

		if self.fade_title_in == true and self.fade_title_time >=fade_time then
			self:StartTileFadeOut()
		end
	end
end

function FrontEnd:StartTileFadeIn()
	self.fade_title_in = true
	self.fade_title_time = 0
	self.fade_title_out = false
	self:DoTitleFade(0)
end

function FrontEnd:StartTileFadeOut()
	self.fade_title_in = false
	self.fade_title_out = true
end

function FrontEnd:HideTitle()
	self.title:Hide()
	self.subtitle:Hide()
	self.fade_title_in = false
	self.fade_title_time = 0
	self.fade_title_out = false
end

function FrontEnd:LockFocus(lock)
	if lock == nil then
		lock = true
	end
	self.focus_locked = lock
	-- KAJ - I am torn if I should update the focus widget on an unlock
end

function FrontEnd:SendScreenEvent(type, message)
	local top = self:GetActiveScreen()
	if top then
		top:HandleEvent(type, message)
	end
end

function FrontEnd:Debug_GetChromaKeyOverlay()
	if not self.chroma_bg then
		self.chroma_bg = self.overlayroot:AddChild(ChromaKeyScreen())
	end
	self.chroma_bg:MoveToFront()
	return self.chroma_bg
end

function FrontEnd:GetLetterbox()
	if not self.letterbox then
		self.letterbox = self.underlayroot:AddChild(Letterbox())
		self.letterbox
			:SetAnchors("fill", "fill")
	end
	return self.letterbox
end

function FrontEnd:Debug_HideLetterbox()
	if self.letterbox then
		-- Don't use Hide so Letterbox still works the next time it's invoked.
		self.letterbox:SetDisplayAmount(0)
	end
end

function FrontEnd:GetSound()
	return self.gameinterface.SoundEmitter
end

function FrontEnd:GetTwitchOptions()
	return self.gameinterface.TwitchOptions
end

function FrontEnd:GetAccountManager()
	return self.gameinterface.AccountManager
end

function FrontEnd:SetFadeLevel(alpha, time, time_total)
	self.alpha = math.clamp(alpha, 0, 1)
	if alpha <= 0 then
		if self.blackoverlay ~= nil then
			self.blackoverlay:Hide()
			self.whiteoverlay:Hide()
			self.vigoverlay:Hide()
			self.swipeoverlay:Hide()
		end
		if self.topblackoverlay ~= nil then
			self.topblackoverlay:Hide()
			self.topwhiteoverlay:Hide()
			self.topvigoverlay:Hide()
			self.topswipeoverlay:Hide()
		end
		if self.fade_type == "alpha" then
			local screen = self:GetActiveScreen()
			if screen and screen.children then
				for k,v in pairs(screen.children) do
					v:SetFadeAlpha(1)
				end
			end
		end
	elseif self.fade_type == "white" then
		self.whiteoverlay:Show()
		self.whiteoverlay:SetMultColor(FADE_WHITE_COLOR[1], FADE_WHITE_COLOR[2], FADE_WHITE_COLOR[3], alpha)
		self.vigoverlay:Show()
		self.vigoverlay:SetMultColor(1, 1, 1, alpha)
		if not self.topFadeHidden then
			self.topwhiteoverlay:Show()
			self.topvigoverlay:Show()
		end
		self.topwhiteoverlay:SetMultColor(FADE_WHITE_COLOR[1], FADE_WHITE_COLOR[2], FADE_WHITE_COLOR[3], alpha)
		self.topvigoverlay:SetMultColor(1, 1, 1, alpha)
	elseif self.fade_type == "alpha" then
		local screen = self:GetActiveScreen()
		if screen ~= nil and screen.children ~= nil then
			for k, v in pairs(screen.children) do
				v:SetFadeAlpha(1 - alpha) -- "alpha" here is the intensity of the fade, 1 is full intensity, so 0 widget alpha
			end
		end
	elseif self.fade_type == "black" then
		self.blackoverlay:Show()
		self.blackoverlay:SetMultColor(0, 0, 0, alpha)
		if not self.topFadeHidden then
			self.topblackoverlay:Show()
		end
		self.topblackoverlay:SetMultColor(0, 0, 0, alpha)
	elseif self.fade_type == "swipe" then
		self.swipeoverlay:Show()
		self.swipeoverlay:SetMultColor(1, 1, 1, alpha)
		if not self.topFadeHidden then
			self.topswipeoverlay:Show()
		end
		self.topswipeoverlay:SetMultColor(1, 1, 1, alpha)

		local progress = 0 --progress should be a float from 0 to 1 over the whole fade in and out
		local phase_1 = 0
		local fade_progress = time and (time/time_total) or 0
		if self.fadedir == FADE_IN then
			progress = 0.5 + (fade_progress/2)
			phase_1 = 1
		else--if self.fadedir == FADE_OUT then
			progress = fade_progress/2
			phase_1 = 0
		end

		self.swipeoverlay:SetEffectParams(progress, phase_1, 0, 0)
		self.topswipeoverlay:SetEffectParams(progress, phase_1, 0, 0)
	end
end

function FrontEnd:GetFadeLevel()
	return self.alpha
end

function FrontEnd:DoFadingUpdate(dt)
	dt = math.min(dt, TICKS)
	if self.fade_delay_time ~= nil then
		self.fade_delay_time = self.fade_delay_time - dt
		if self.fade_delay_time <= 0 then
			self.fade_delay_time = nil
			if self.delayovercb ~= nil then
				self.delayovercb()
				self.delayovercb = nil
			end
		end
		return
	elseif self.fadedir ~= nil then
		self.fade_time = self.fade_time + dt

		local alpha = 0
		if self.fadedir == FADE_IN then
			if self.total_fade_time == 0 then
				alpha = 0
			else
				alpha = easing.inOutCubic(self.fade_time, 1, -1, self.total_fade_time)
			end
		elseif self.fadedir == FADE_OUT then
			if self.total_fade_time == 0 then
				alpha = 1
			else
				alpha = easing.outCubic(self.fade_time, 0, 1, self.total_fade_time)
			end
		end

		self:SetFadeLevel(alpha, self.fade_time, self.total_fade_time)
		if self.fade_time >= self.total_fade_time then
			self.fadedir = nil
			if self.fadecb ~= nil then
				local cb = self.fadecb
				self.fadecb = nil
				cb()
			end
		end
	end
end

function FrontEnd:UpdateConsoleOutput()
	local consolestr = table.concat(GetConsoleOutputList(), "\n")
	consolestr = consolestr.."\n(Press CTRL+L to close this log)"
	self.consoletext:SetText(consolestr)
end

function FrontEnd:CheckMouseHover( x, y, trace )
	local mouse_blocked, hover_widget
	for i = #self.screenstack, 1, -1 do
		local screen = self.screenstack[ i ]
		mouse_blocked, hover_widget = screen:CheckMouseHover(x,y,trace)
		if mouse_blocked or hover_widget or screen:SinksInput() then
			break
		end
	end
	if hover_widget then
		hover_widget:SetHover()
		return hover_widget
	else
		self.sceneroot:ClearHover()
	end
end

function FrontEnd:UpdateControls(dt)
	if self:IsControlsDisabled() then
		return false
	end

	--Spinner repeat
	if not (TheInput:IsControlDown(Controls.Digital.PREVVALUE)
			or TheInput:IsControlDown(Controls.Digital.NEXTVALUE))
	then
		self.spinner_repeat_time = -1
	elseif self.spinner_repeat_time > dt then
		self.spinner_repeat_time = self.spinner_repeat_time - dt
	elseif self.spinner_repeat_time < 0 then
		self.spinner_repeat_time = SPINNER_REPEAT_TIME > dt and SPINNER_REPEAT_TIME - dt or 0
	elseif TheInput:IsControlDown(Controls.Digital.PREVVALUE) then
		self.spinner_repeat_time = SPINNER_REPEAT_TIME
		self:OnControl(Controls.Digital.PREVVALUE, true)
	else--if TheInput:IsControlDown(Controls.Digital.NEXTVALUE) then
		self.spinner_repeat_time = SPINNER_REPEAT_TIME
		self:OnControl(Controls.Digital.NEXTVALUE, true)
	end

	--Scroll repeat
	if not (TheInput:IsControlDown(Controls.Digital.MENU_SCROLL_BACK)
			or TheInput:IsControlDown(Controls.Digital.MENU_SCROLL_FWD))
	then
		self.scroll_repeat_time = -1

	elseif self.scroll_repeat_time > dt then
		self.scroll_repeat_time = self.scroll_repeat_time - dt

	elseif TheInput:IsControlDown(Controls.Digital.MENU_SCROLL_BACK) then
		local repeat_time =
			TheInput:HasMouseWheel(Controls.Digital.MENU_SCROLL_BACK)
			and MOUSE_SCROLL_REPEAT_TIME
			or SCROLL_REPEAT_TIME
		if self.scroll_repeat_time < 0 then
			self.scroll_repeat_time = repeat_time > dt and repeat_time - dt or 0
		else
			self.scroll_repeat_time = repeat_time
			self:OnControl(Controls.Digital.MENU_SCROLL_BACK, true)
		end

	else--if TheInput:IsControlDown(Controls.Digital.MENU_SCROLL_FWD) then
		local repeat_time =
			TheInput:HasMouseWheel(Controls.Digital.MENU_SCROLL_FWD)
			and MOUSE_SCROLL_REPEAT_TIME
			or SCROLL_REPEAT_TIME
		if self.scroll_repeat_time < 0 then
			self.scroll_repeat_time = repeat_time > dt and repeat_time - dt or 0
		else
			self.scroll_repeat_time = repeat_time
			self:OnControl(Controls.Digital.MENU_SCROLL_FWD, true)
		end
	end

	-- victorc: hack - local multiplayer.
	-- This doesn't handle screen.owningdevice or players that are assigned to
	-- an inputID but not a device (adding new players). OnFocusMove should go
	-- through a similar flow to OnInputEvent so focus move and control events
	-- have the same player-restricting behaviour.
	--
	-- If the screen implements GetOwningPlayer for player-specific customization, etc. then
	-- use the owning player's PlayerController as the input "interface"
	-- Currently only need IsControlDown
	local topscreen = self:GetActiveScreen()
	local screen_owner = topscreen and topscreen:GetOwningPlayer() or nil

	local input
	local inputFunction

	if screen_owner and #AllPlayers > 1 then
		input = screen_owner.components.playercontroller
		inputFunction = input.IsControlDown
	else
		input = TheInput
		inputFunction = input.IsControlDownOnAnyDevice
	end

	if self.repeat_time > dt then
		if not inputFunction(input, Controls.Digital.MENU_LEFT)
			and not inputFunction(input, Controls.Digital.MENU_RIGHT)
			and not inputFunction(input, Controls.Digital.MENU_UP)
			and not inputFunction(input, Controls.Digital.MENU_DOWN)
		then
			self.repeat_time = 0
		else
			self.repeat_time = self.repeat_time - dt
		end
	elseif not (self.textProcessorWidget ~= nil) then -- Skip repeat while editing a text box
		self.repeat_time = NAV_REPEAT_TIME

		if inputFunction(input, Controls.Digital.MENU_LEFT) then
			self:OnFocusMove(MOVE_LEFT, true)
		elseif inputFunction(input, Controls.Digital.MENU_RIGHT) then
			self:OnFocusMove(MOVE_RIGHT, true)
		elseif inputFunction(input, Controls.Digital.MENU_UP) then
			self:OnFocusMove(MOVE_UP, true)
		elseif inputFunction(input, Controls.Digital.MENU_DOWN) then
			self:OnFocusMove(MOVE_DOWN, true)
		else
			self.repeat_time = 0
		end
	end
end

function FrontEnd:Update(dt)

	if CHEATS_ENABLED then
		ProbeReload(TheInput:IsKeyDown(InputConstants.Keys.F6))
	end

	if self.saving_indicator ~= nil and self.saving_indicator.shown then
		if self.save_indicator_fade then
			local alpha = 1
			self.save_indicator_fade_time = self.save_indicator_fade_time - math.min(dt, 1/60)

			if self.save_indicator_fade_time < 0 then
				if self.save_indicator_fade == "in" then
					alpha = 1
				else
					alpha = 0
					self.saving_indicator:ForceStopWallUpdating()
					self.saving_indicator:Hide()
				end
				self.save_indicator_fade = nil
			else
				if self.save_indicator_fade == "in" then
					alpha = math.max(0, 1 - self.save_indicator_fade_time/save_fade_time)
				elseif self.save_indicator_fade == "out" then
					alpha = math.min(1,self.save_indicator_fade_time/save_fade_time)
				end
			end
			self.saving_indicator:GetAnimState():SetMultColor(1,1,1,alpha)
		else
			self.save_indicator_time_left = self.save_indicator_time_left - dt
			if self.num_pending_saves <= 0 and self.save_indicator_time_left <= 0 then
				self.save_indicator_fade = "out"
				self.save_indicator_fade_time = save_fade_time
			end
		end
	end

	if self.console_root.shown then
		self:UpdateConsoleOutput()
	end

	if not self.error_widget then
		self:DoFadingUpdate(dt)
	end
	self:DoTitleFade(dt)

	if #self.screenstack > 0 then
		self.screenstack[#self.screenstack]:OnUpdate(dt)
	end

	self:UpdateControls(dt)

	self:OnRenderImGui(dt)
	--[[
	if CAN_USE_DBUI then
		if not self.imgui_is_running and self.imgui_enabled then

			local i = 1

			--jcheng: this is to stop imgui from re-running while inside imgui, for example if you do a sim step
			self.imgui_is_running = true

			while i <= #self.debug_panels do
				local panel = self.debug_panels[i]

				local ok, result = xpcall( function() return panel:RenderPanel(self.imgui, i) end, generic_error )
				if ok and panel:WantsToClose() then
					result = false
				end

				if not ok or not result then
					print("closing panel "..tostring(panel))
					panel:OnClose()
					table.remove( self.debug_panels, i )
					if not ok then
						print( tostring(result) )
						break
					end
				else
					i = i + 1
				end
			end

			if #self.debug_panels == 0 then
				self.imgui_enabled = false
			end

			self.imgui_is_running = false
		end

		self.debugMenu:Render(dt)
	end
	]]


	TheSim:ProfilerPush("update widgets")
	if not self.updating_widgets_alt then
		self.updating_widgets_alt = {}
	end

	for k,v in pairs(self.updating_widgets) do
		self.updating_widgets_alt[k] = v
	end

	for k,v in pairs(self.updating_widgets_alt) do
		if k.enabled then
			k:OnUpdate(dt)
		end
		self.updating_widgets_alt[k] = nil
	end

	if not self.debugfreeze then
		self:UpdateToolTip(dt)
	end


	TheSim:ProfilerPop()
end

function FrontEnd:StartUpdatingWidget(w)
	self.updating_widgets[w] = true
end

function FrontEnd:StopUpdatingWidget(w)
	self.updating_widgets[w] = nil
end

function FrontEnd:InsertScreenUnderTop(screen)
	self.screenroot:AddChild(screen)
	table.insert(self.screenstack, #self.screenstack, screen)
	self.screenstack[#self.screenstack]:MoveToFront()
end

function FrontEnd:IsScreenAtFront(screen)
	return self.screenstack[#self.screenstack] == screen
end

function FrontEnd:MoveScreenToFront(screenToMove)
	local top = self:GetActiveScreen()
	if top == screenToMove then
		return
	end

	local i = lume.find(self.screenstack, screenToMove)
	if i then
		if top then
			top:OnBecomeInactive()
		end
		table.remove(self.screenstack, i)
		table.insert(self.screenstack, screenToMove)
		screenToMove:MoveToFront()
		screenToMove:OnBecomeActive()
	end
end

function FrontEnd:PushScreen(screen)
	----- GL
	screen:SetFE(self)	-- huh, when I take this out everything breaks. Is it because used for sizing?
	----- \GL

	self.focus_locked = false
	self:SetForceProcessTextInput(false)
	if screen.flush_inputs then
		TheInput:FlushInput()
	end

	--jcheng: don't allow any other screens to push if we're displaying an error
	if self.error_widget ~= nil and self.error_widget ~= true then
		return
	end

	TheLog.ch.FrontEnd:print('PushScreen', screen._widgetname)
	if #self.screenstack > 0 then
		self.screenstack[#self.screenstack]:OnBecomeInactive()
	end

	self.screenroot:AddChild(screen)
	table.insert(self.screenstack, screen)

	-- screen:Show()
	if not self.tracking_mouse then
		screen:SetDefaultFocus()
	end

	screen:OnOpen()
	screen:OnBecomeActive()

	self:Update(0)

	--print("FOCUS IS", screen:GetDeepestFocus(), self.tracking_mouse)
	--self:Fade(FADE_IN, 2)
end

function FrontEnd:ClearScreens()
	local top = self:GetActiveScreen()
	if top then
		top:OnLoseFocus()
		top:OnBecomeInactive()
	end

	while #self.screenstack > 0 do
		local screen = table.remove(self.screenstack, #self.screenstack)
		screen:OnClose()
		screen:Remove()
	end
end

function FrontEnd:ShowConsoleLog()
	self.console_root:Show()
end

function FrontEnd:HideConsoleLog()
	self.console_root:Hide()
end

function FrontEnd:SetConsoleLogCorner(halign, valign)
	self.console_root:SetRegistration(halign, valign)
	self.console_root:SetAnchors(halign, valign)
	-- If above assert due to invalid inputs, we won't reach this point so we
	-- should never store invalid values.
	self.settings
		:Set("console_log_h", halign)
		:Set("console_log_v", valign)
		:Save()
	return self
end

function FrontEnd:DoFadeIn(time_to_take)
	self:Fade(FADE_IN, time_to_take)
end

--[[
function FrontEnd:FadeTransition(fn, time_to_take )
	time_to_take = time_to_take or .2

	if self.fading and self.fade_out then
		self.fade_fn = fn
	else
		self.fade_out = true
		self.fading = true

		self.fader:Show()
		self.fader:SetColour(0,0,0,0)
		self.fade_time_total = time_to_take
		self.fade_time = 0
		self.fade_fn = fn
	end
end
]]

-- **CAUTION** about using the "alpha" fade: it leaves your screen's widgets at alpha 0 when it's finished AND makes all children of the screen not clickable
-- It generally leaves the screen in bad state: don't use lightly for screens that will be returned to (ex: we only use it leading into a sim reset)
-- Fixup after using an "alpha" fade would include making the appropriate children of the screen clickable and setting alphas appropriately
function FrontEnd:Fade(in_or_out, time_to_take, cb, fade_delay_time, delayovercb, fadeType)
	local warn_about_non_cb_fades = false
	if self:IsFading()
		and ((self.fadecb or self.delayovercb)
			or warn_about_non_cb_fades)
	then
		TheLog.ch.FrontEnd:printf("Warning: Fade overwriting existing %s (fadecb=%s, delayovercb=%s)",
			self:GetFadeDirection() == FADE_IN and "Fade In" or "Fade Out",
			self.fadecb ~= nil,
			self.delayovercb ~= nil)

		if self.delayovercb then
			self.delayovercb()
			self.delayovercb = nil
		end

		if self.fadecb then
			self.fadecb()
			self.fadecb = nil
		end
	end

	self.fadedir = in_or_out
	self.total_fade_time = time_to_take or SCREEN_FADE_TIME
	self.fadecb = cb
	self.fade_time = 0
	self.fade_delay_time = fade_delay_time
	self.delayovercb = delayovercb
	self.fade_type = fadeType or "black"

	TheLog.ch.FrontEndSpam:printf("Fade: %s, time=%1.3f, fadecb=%s, delay=%1.3f, delayovercb=%s type=%s",
		self.fadedir == FADE_IN and "Fade In" or "Fade Out",
		self.total_fade_time,
		self.fadecb ~= nil,
		self.fade_delay_time or 0,
		self.delayovercb ~= nil,
		self.fade_type)

	if in_or_out == FADE_IN then
		self:SetFadeLevel(1)
	else
		-- starting a fade out, make the top fade visible again
		-- this place it can actually be out of sync with the backfade, so make it full trans
		if self.fade_type == "white" then
			self.topwhiteoverlay:SetMultColor(FADE_WHITE_COLOR[1], FADE_WHITE_COLOR[2], FADE_WHITE_COLOR[3], 0)
			self.topvigoverlay:SetMultColor(1,1,1,0)
		elseif self.fade_type == "black" then
			self.topblackoverlay:SetMultColor(0,0,0,0)
		elseif self.fade_type == "swipe" then
			self.topswipeoverlay:SetMultColor(1,1,1,0)
			self.topswipeoverlay:SetEffectParams(0,0,0,0)
		end
		self:ShowTopFade()
	end
end

-- Looking for FadeToScreen, FadeBack? Use
-- Screen:_AnimateInFromOffset/Screen:_AnimateOutToOffset or a custom anim for
-- a Rotwood-style anim instead.

-- expected to return FADE_IN, FADE_OUT or nil
function FrontEnd:GetFadeDirection()
	return self.fadedir
end

function FrontEnd:IsFading()
	return self.fadedir ~= nil
end

function FrontEnd:PopScreen(screen)
	self.focus_locked = false
	self:SetForceProcessTextInput(false)

	local old_head = self:GetActiveScreen()
	if screen then
		-- screen:Hide()
		if screen.flush_inputs then
			TheInput:FlushInput()
		end
		TheLog.ch.FrontEnd:print('PopScreen', screen._widgetname)
		local i = lume.find(self.screenstack, screen)
		if i then
			if old_head == screen then
				screen:OnBecomeInactive()
			end
			table.remove(self.screenstack, i)
			screen:OnClose()
			screen:Remove()
		end

	else
		TheLog.ch.FrontEnd:print('PopScreen')
		TheInput:FlushInput()
		if #self.screenstack > 0 then
			screen = table.remove(self.screenstack, #self.screenstack)
			screen:OnBecomeInactive()
			screen:OnClose()
			screen:Remove()
		end
	end

	local new_head = self:GetActiveScreen()
	if new_head and old_head ~= new_head then
		new_head:SetFocus()
		new_head:OnBecomeActive()

		TheInput:UpdateEntitiesUnderMouse()
		self:Update(0)

		--print ("POP!", new_head:GetDeepestFocus(), self.tracking_mouse)
		--self:Fade(FADE_IN, 1)
	end
end

function FrontEnd:PopScreensAbove(screen)
	assert(screen)
	dbassert(lume.find(self.screenstack, screen), "Screen must be in the stack.")
	local active_screen = self:GetActiveScreen()
	while active_screen and active_screen ~= screen do
		self:PopScreen()
		active_screen = self:GetActiveScreen()
	end
end

function FrontEnd:SetCursorSize(sz)
	assert(cursor.Size:Contains(sz), "Invalid size. See Size in cursor.lua")
	if self.cursor_size ~= sz then
		self.cursor_size = sz
		cursor.SetCursor(self.current_cursor, self.cursor_size)
	end
end

function FrontEnd:SetCursor(c)
	if self.current_cursor ~= c then
		kassert.assert_fmt(cursor.Style:Contains(c), "Unknown cursor '%s'.", c)
		self.current_cursor = c
		cursor.SetCursor(self.current_cursor, self.cursor_size)
	end
end

function FrontEnd:GetCurrentCursor()
	return self.current_cursor
end

function FrontEnd:GetActiveScreen()
	return #self.screenstack > 0 and self.screenstack[#self.screenstack] or nil
end

function FrontEnd:GetInputSinkScreenUnderConsole()
	--Second return value indicates whether there was a ConsoleScreen or not
	local num = #self.screenstack
	if num <= 0 then
		return nil, false
	end
	local has_console = false
	local scrn
	for i=num,1,-1 do
		scrn = self.screenstack[i]
		if scrn:is_a(ConsoleScreen) then
			has_console = true
		elseif scrn:SinksInput() then
			break
		end
	end
	return scrn, has_console
end

function FrontEnd:GetScreenStackSize()
	return #self.screenstack
end

function FrontEnd:ShowScreen(screen)
	self:ClearScreens()
	if screen then
		self:PushScreen(screen)
	end
end

function FrontEnd:SetForceProcessTextInput(takeText, widget)
	if takeText and widget then
		-- Tell whatever the previous widget was to quit it
		if self.textProcessorWidget then
			self.textProcessorWidget:OnStopForceProcessTextInput()
		end
		self.textProcessorWidget = widget
		self.forceProcessText = true
	elseif widget == nil or widget == self.textProcessorWidget then
		if self.textProcessorWidget then
			self.textProcessorWidget:OnStopForceProcessTextInput()
		end
		self.textProcessorWidget = nil
		self.forceProcessText = false
	end
end

function FrontEnd:OnRawKey(key, down)
	if self:IsControlsDisabled() then
		return false
	end

	local screen = self:GetActiveScreen()
	if screen ~= nil then
		if self.forceProcessText and self.textProcessorWidget ~= nil then
			self.textProcessorWidget:OnRawKey(key, down)
		elseif not screen:OnRawKey(key, down) and CHEATS_ENABLED then
			DoDebugKey(key, down)
		end
	end
end

function FrontEnd:OnTextInput(text)
	if self:IsControlsDisabled() then
		return false
	end

	local screen = self:GetActiveScreen()
	if screen ~= nil then
		if self.forceProcessText and self.textProcessorWidget ~= nil then
			self.textProcessorWidget:OnTextInput(text)
		else
			screen:OnTextInput(text)
		end
	end
end

function FrontEnd:GetHUDScale()
	local size = Profile:GetHUDSize()
	local min_scale = .75
	local max_scale = 1.1

	--testing high res displays
	local w, h = TheSim:GetScreenSize()

	local res_scale_x = math.max(1, w / RES_X)
	local res_scale_y = math.max(1, h / RES_Y)
	local res_scale = math.min(res_scale_x, res_scale_y)

	return easing.linear(size, min_scale, max_scale - min_scale, 10) * res_scale
end

function FrontEnd:OnMouseButton(button, down, x, y)
	if self:IsControlsDisabled() then
		return false
	end

	self.tracking_mouse = true

	local top = self:GetActiveScreen()
	if top and top:OnMouseButton(button, down, x, y) then
		return true
	end

	return CHEATS_ENABLED and DEV_MODE and DoDebugMouse(button, down, x, y)
end

function FrontEnd:FocusHoveredWidget()
	if not self.focus_locked then
		local x, y = self:GetUIMousePos()

		local hover_widget = self:CheckMouseHover( x, y )
		if hover_widget then
			hover_widget:SetFocus()
		elseif #self.screenstack > 0 then
			self.screenstack[#self.screenstack]:SetFocus()
		end
	end
end

function FrontEnd:OnMouseMove(x, y)
	if self:IsControlsDisabled() then
		return false
	end

	if self.lastx ~= nil
		and self.lasty ~= nil
		and self.lastx ~= x
		and self.lasty ~= y
	then
		self.tracking_mouse = true
	end

	self.lastx = x - self.screen_w/2
	self.lasty = y - self.screen_h/2

	-- Only apply mouse position to focus on move and not in update, so we can
	-- key away from a widget.
	self:FocusHoveredWidget()
end

function FrontEnd:OnSaveLoadError(operation, filename, status)
	self:HideSavingIndicator() -- in case it's still being shown for some reason

	local function retry()
		self:PopScreen() -- saveload error message box
		if operation == SAVELOAD.OPERATION.LOAD then
			local function OnProfileLoaded(success)
				--print("OnProfileLoaded", success)
			end
			Profile:Load(OnProfileLoaded)
		elseif operation == SAVELOAD.OPERATION.SAVE then
			-- the system service knows which files are not saved and will try to save them
			self:ShowSavingIndicator()
			TheSystemService:RetryOperation(operation, filename)
		elseif operation == SAVELOAD.OPERATION.DELETE then
			TheSystemService:RetryOperation(operation, filename)
		end
	end

	if status == SAVELOAD.STATUS.DAMAGED then
		print("OnSaveLoadError", "Damaged save data popup")
		local function overwrite()
			local function on_overwritten(success)
				self:HideSavingIndicator()
				TheSystemService:EnableAutosave(success)
			end

			-- OverwriteStorage will also try to resave any files found in the cache
			self:ShowSavingIndicator()
			TheSystemService:OverwriteStorage(on_overwritten)
			self:PopScreen() -- saveload error message box
		end

		local function cancel()
			TheSystemService:EnableStorage(TheSystemService:IsAutosaveEnabled())
			TheSystemService:ClearLastOperation()
			self:PopScreen() -- saveload error message box
		end

		local function confirm_autosave_disable()

			local function disable_autosave()
				TheSystemService:EnableStorage(false)
				TheSystemService:EnableAutosave(false)
				TheSystemService:ClearLastOperation()
				self:PopScreen() -- confirmation message box
				self:PopScreen() -- saveload error message box
			end

			local function dont_disable()
				self:PopScreen() -- confirmation message box
			end

			local title = STRINGS.UI.SAVELOAD.DISABLE_AUTOSAVE
			local subtitle = nil
			local message = nil
			TheFrontEnd:PushScreen(ConfirmDialog(nil, nil, true,
				title,
				subtitle,
				message,
				function()
				end
			):SetYesButton(STRINGS.UI.SAVELOAD.YES, disable_autosave)
			:SetNoButton(STRINGS.UI.SAVELOAD.NO, dont_disable)
			:HideArrow())
		end

		local cancel_cb = cancel
		if TheSystemService:IsAutosaveEnabled() then
			cancel_cb = confirm_autosave_disable
		end

		local title = STRINGS.UI.SAVELOAD.DATA_DAMAGED
		local subtitle = nil
		local message = nil
		TheFrontEnd:PushScreen(ConfirmDialog(nil, nil, true,
			title,
			subtitle,
			message,
			function()
			end
		):SetYesButton(STRINGS.UI.SAVELOAD.RETRY, retry)
		:SetNoButton(STRINGS.UI.SAVELOAD.OVERWRITE, overwrite)
		:SetCancelButton(STRINGS.UI.SAVELOAD.CANCEL, cancel_cb)
		:HideArrow())

	elseif status == SAVELOAD.STATUS.FAILED then

		local function cancel()
			TheSystemService:ClearLastOperation()
			self:PopScreen() -- saveload error message box
		end

		local title
		if operation == SAVELOAD.OPERATION.LOAD then
			title = STRINGS.UI.SAVELOAD.LOAD_FAILED
		elseif operation == SAVELOAD.OPERATION.SAVE then
			title = STRINGS.UI.SAVELOAD.SAVE_FAILED
		elseif operation == SAVELOAD.OPERATION.DELETE then
			title = STRINGS.UI.SAVELOAD.DELETE_FAILED
		end
		local subtitle = nil
		local message = nil
		TheFrontEnd:PushScreen(ConfirmDialog(nil, nil, true,
			title,
			subtitle,
			message,
			function()
			end
		):SetYesButton(STRINGS.UI.SAVELOAD.RETRY, retry)
		:SetNoButton(STRINGS.UI.SAVELOAD.CANCEL, cancel)
		:HideArrow())
	end
end

function OnSaveLoadError(operation, filename, status)
	TheFrontEnd:OnSaveLoadError(operation, filename, status)
end

function FrontEnd:IsScreenInStack(screen)
	for _,screen_in_stack in pairs(self.screenstack) do
		if screen_in_stack == screen then
			return true
		end
	end
	return false
end

function FrontEnd:SetOfflineMode(isOffline)
	self.offline = isOffline
end

function FrontEnd:GetIsOfflineMode()
	return self.offline
end

function FrontEnd:ToggleImgui(node)
	if not CAN_USE_DBUI then
		return
	end

	if self.imgui_enabled then
		self.imgui_enabled = false
	else
		self.imgui_enabled = true
		self.imgui:ActivateImgui()

		if #self.debug_panels == 0 and not node then
			self:CreateDebugPanel( DebugNodes.DebugEntity() )
		end
	end
end

function FrontEnd:CreateDebugPanel( node )
	if not CAN_USE_DBUI then
		return
	end

	local panel = DebugPanel( node )
	panel.type = node
	if not self.imgui_enabled then
		self:ToggleImgui(panel)
	end

	table.insert( self.debug_panels, panel )
	-- If you want to stuff values into the PrefabEditor, it's the input node
	-- that you want to modify, not this panel. If you want to modify windowing
	-- info, then this panel is where it's at.
	return panel
end

-- Takes the same argument as CreateDebugPanel -- the class of a debug panel
-- node.
function FrontEnd:FindOpenDebugPanel( node )
	for _, panel in ipairs(self.debug_panels) do
		if panel.type:is_a(node) then
			return panel
		end
	end
end

function FrontEnd:GetNumberOpenDebugPanels( node )
	local numOpenPanels = 0
	for _, panel in ipairs(self.debug_panels) do
		if panel.type:is_a(node) then
			numOpenPanels = numOpenPanels + 1
		end
	end

	return numOpenPanels
end

-- The "top" means the selected (because it's most in focus) or the earliest
-- created panel. We don't have a stack of panels. More likely you want
-- GetSelectedDebugPanel.
function FrontEnd:GetTopDebugPanel()
	return TheFrontEnd:GetSelectedDebugPanel() or self.debug_panels[1] -- could be nil
end

function FrontEnd:GetSelectedDebugPanel()
	for _, panel in ipairs(self.debug_panels) do
		if panel.isSelected then
			return panel
		end
	end

	return nil
end

function FrontEnd:GetFocusedDebugNode()
	local panel = self:GetSelectedDebugPanel()
	if panel then
		return panel:GetNode()
	end
end

function FrontEnd:SetImguiFontSize( font_size )
	self.imgui_font_size = font_size
	Profile:SetValue("imgui_font_size", self.imgui_font_size)
	Profile.dirty = true
	Profile:Save()
end

----------------------------------- GL ----------------------------------
--------------------------------------------- TOOLTIPS

function FrontEnd:UpdateToolTip(dt)
	if self.fading then
		if self.tooltip_widget then
			self.tooltip_widget:Hide()
		end
		return

	end
	local focus
	if self.tooltip_focus_override then
		if self.tooltip_focus_override.removed then
			self.tooltip_focus_override = nil
		else
			focus = self.tooltip_focus_override
		end
	end


	if focus == nil then
		-- Get hover widget
		focus = self:GetHoverWidget()
		-- If the current focused widget should show tooltip on focus, do that
		local focus_widget = self:GetFocusWidget()
		if focus_widget then
			if focus_widget.show_tooltip_on_focus then
				focus = focus_widget
			else
				-- If any ancestor of focus_widget is flagged 'show_child_tooltip_on_focus', then also show tooltip.
				local focus_parent = focus_widget.parent
				while focus_parent do
					if focus_parent.show_child_tooltip_on_focus then
						focus = focus_widget
						break
					end
					focus_parent = focus_parent.parent
				end
			end
		end
	end

	local tt_class = Tooltip
	local tt

	if focus then
		while tt == nil and focus do
			tt = focus:GetToolTip()
			tt_class = focus:GetToolTipClass() or Tooltip
			if not tt then
				focus = focus.parent
			elseif not type(tt) == 'string' then
				assert(type(tt) == 'string', ("A widget used self.tooltip for something other than the tooltip text: %s"):format(tostring(focus)))
			end
		end
	end

	if tt_class and self.tooltip_widgets[ tt_class ] == nil then
		--print( "Creating new shared tooltip: ", tt_class._classname )
		self.tooltip_widgets[ tt_class ] = self.fe_root:AddChild( tt_class():IgnoreInput( true ) )
	end
	local tooltip_widget = self.tooltip_widgets[ tt_class ]
	local want_hide = self.tooltip_widget ~= nil and (self.tooltip_widget ~= tooltip_widget or not tt)
	if want_hide then
		self.tooltip_delay = self.tooltip_delay - dt

		if self.tooltip_delay <= 0 or (self.tooltip_focus.removed or not self.tooltip_focus.shown) then
			self.tooltip_widget:Hide()
			self.tooltip_widget, self.tooltip_focus, self.tooltip_data = nil, nil, nil
			self.tooltip_delay = TTDELAY
		end
	end

	local want_show = tt and (focus ~= self.tooltip_focus or tt ~= self.tooltip_data or focus:GetToolTipDirty())
	if want_show then
		self.tooltip_delay = self.tooltip_delay - dt

		if self.tooltip_delay <= 0 or (self.tooltip_widget and self.tooltip_widget.shown) then
			local sm = self:GetScreenMode()
			local layout_scale
			if tooltip_widget.LAYOUT_SCALE then
				layout_scale = tooltip_widget.LAYOUT_SCALE[ sm ] or LAYOUT_SCALE[ sm ]
			else
				layout_scale = LAYOUT_SCALE[ sm ]
			end

			tooltip_widget:SetOwningPlayer(nil) -- Shared tooltips have all content re-applied, so okay to clear.
			tooltip_widget:SetOwningPlayer(focus and focus:GetOwningPlayer())

			tooltip_widget:SetLayoutScale( layout_scale )
			if tooltip_widget:LayoutWithContent(tt) then
				self.tooltip_widget = tooltip_widget
				self.tooltip_widget.nodebug = true
				self.tooltip_widget:Show()
				self.tooltip_focus = focus
				self.tooltip_data = tt
				self.tooltip_delay = TTDELAY
				focus:SetToolTipDirty( nil )
			else
				tooltip_widget:Hide()
			end
		end
	end

	if self.tooltip_widget
		and self.tooltip_focus
		and self.tooltip_widget.shown
		and not self.tooltip_focus.removed
	then
		self:UpdateToolTipPos( self.tooltip_widget )
		-- if self.tooltip_focus.LayoutToolTip then
		--     self.tooltip_focus:LayoutToolTip( self.tooltip_widget )
		-- end
		local tooltiplayoutfn = self.tooltip_focus:GetToolTipLayoutFn()
		if tooltiplayoutfn then
			tooltiplayoutfn( self.tooltip_focus, self.tooltip_widget )
			self:ConstrainToolTipPos( tooltip_widget )
		end
	end

end

function FrontEnd:SetToolTipOverride( tooltip_focus )
	self.tooltip_focus_override = tooltip_focus
end

function FrontEnd:GetToolTipOverride()
	return self.tooltip_focus_override
end

function FrontEnd:UpdateToolTipPos( tooltip_widget )
	if tooltip_widget and tooltip_widget.shown then
		-- take the letterbox into account.
		-- If we don't letterbox we want to use the widget's worldboundingbox and the screenDims instead
		local screenw, screenh = RES_X, RES_Y
		--        local screenw, screenh = self:GetScreenDims()
		local scrx_min, scrx_max = -screenw/2, screenw/2
		local scry_min, scry_max = -screenh/2, screenh/2

		local xmin, ymin, xmax, ymax = tooltip_widget:GetVirtualBoundingBox()
		--        local xmin, ymin, xmax, ymax = tooltip_widget:GetWorldBoundingBox()
		local tw, th = xmax - xmin, ymax - ymin

		local xmin, ymin, xmax, ymax = self.tooltip_focus:GetVirtualBoundingBox()
		--        local xmin, ymin, xmax, ymax = self.tooltip_focus:GetWorldBoundingBox()

		if (xmax  + tw)  <=  scrx_max and ymax <= scry_max then -- does it fit top right?
			tooltip_widget:LayoutBounds( "after", "top", self.tooltip_focus )
		elseif (xmin - tw) >= scrx_min and ymax <= scry_max then -- top left?
			tooltip_widget:LayoutBounds( "before", "top", self.tooltip_focus )
		elseif (xmax + tw) <= scrx_max and ymin >= scry_min then  -- bottom right?
			tooltip_widget:LayoutBounds( "after", "bottom", self.tooltip_focus )
		elseif (xmin - tw) >= scrx_min and ymin >= scry_min then -- bottom left?
			tooltip_widget:LayoutBounds( "before", "bottom", self.tooltip_focus )
		elseif (ymax + th) <= scry_max then -- center above
			tooltip_widget:LayoutBounds( "center", "above", self.tooltip_focus )
		else -- center below
			tooltip_widget:LayoutBounds( "center", "below", self.tooltip_focus )
			self:ConstrainToolTipPos( tooltip_widget )
		end
	end
end

function FrontEnd:ConstrainToolTipPos( tooltip_widget )
	UIHelpers.KeepOnScreen(tooltip_widget)
end

--------------------------------------------- TOOLTIPS

function FrontEnd:GetScreenMode()
	return self.screen_mode
end

function FrontEnd:GetScreenDims()
	return TheSim:GetScreenSize()
end

function FrontEnd:GetLetterboxDims()
	local x,y = RES_X, RES_X
	x = x / self.base_scale
	y = y / self.base_scale
	return x,y
end


function FrontEnd:AddDirtyTransformWidget(w)
	if not self.dirtytransforms[w] then
		self.dirtytransforms[w] = w
	end
end

function FrontEnd:OnRenderImGui(dt)
	if not CAN_USE_DBUI then
		return
	end

	if not self.imgui_is_running and self.imgui_enabled then

		local i = 1

		--jcheng: this is to stop imgui from re-running while inside imgui, for example if you do a sim step
		self.imgui_is_running = true

		while i <= #self.debug_panels do
			local panel = self.debug_panels[i]

			local ok, result = xpcall( function() return panel:RenderPanel(self.imgui, i, dt) end, generic_error )
			if ok and panel:WantsToClose() then
				result = false
			end

			if not ok or not result then
				print("closing panel "..tostring(panel))
				panel:OnClose()
				table.remove( self.debug_panels, i )
				if not ok then
					print( tostring(result) )
					break
				end
			else
				i = i + 1
			end
		end

		if #self.debug_panels == 0 then
			self.imgui_enabled = false
		end

		self.imgui_is_running = false
	end

	local ok, result = xpcall(function() self.debugMenu:Render(dt) end, generic_error)
	if not ok then
		print(result)
		-- Show error to user (no lua crash screen for pcall).
		TheFrontEnd:ShowConsoleLog()
		self.imgui:EmergencyCleanUpStackForError()
		-- Most likely debugMenu opened a window, but
		-- EmergencyCleanUpStackForError only cleans up within the current
		-- window and won't end it.
		self.imgui:End()
	end
end

function FrontEnd:OnRender(dt)
	if Debuggee then
		Debuggee.poll()
	end

	TheSim:ProfilerPush( "FrontEnd:OnRender: Updating Transforms")
	for k,v in pairs(self.dirtytransforms) do
		if not v.removed then
			v:UpdateTransform()
		end
	end
	table.clear(self.dirtytransforms)

	TheSim:ProfilerPop()
end

function FrontEnd:GetBaseWidgetScale()
	return self.base_scale
end

function FrontEnd:InitScreenSize()
	local w,h = self:GetScreenDims()
	self:OnScreenResize(w,h)
end

function FrontEnd:OnScreenResize(w,h)
	--    self.camera:SetScreenSize(w, h)
	local aspect = w/h
	local author_aspect = RES_X/RES_Y

	-- calculate base scale based on aspect, but allow a bit of fudge since the window will hardly
	-- ever be exactly at ratio and exact ratio calculation will by defintion undersize the derived axis
	if aspect >= author_aspect then
		-- make height dominant
		self.base_scale = h/RES_Y
		-- some small fudge
		local x_diff = w - self.base_scale * RES_X
		if x_diff < 2 then
			self.base_scale = w/RES_X
		end
	elseif aspect < author_aspect then
		-- make width dominant
		self.base_scale = w/RES_X
		-- some small fudge
		local y_diff = h - self.base_scale * RES_Y
		if y_diff < 2 then
			self.base_scale = h/RES_Y
		end
	end

	local sw,sh = w, h
	local x,y = 0,0
	--too wide!
	if aspect > 21/9 then
		sw = h*(21/9)
		x = (w-sw)/2
		--too tall!
	elseif aspect < 4/3 then
		sh = w / (4/3)
		y = (h-sh)/2
	end
	self.scissor_w = sw
	self.scissor_h = sh

	self.sceneroot:SetScale(self.base_scale, self.base_scale)
	-- +1 prevents one pixel border of game showing through UI when window is
	-- forced to unsuported aspect (maximized).
	self.sceneroot:SetScissor(-RES_X/2, -RES_Y/2, RES_X + 1, RES_Y + 1)
	for k,v in pairs(self.screenstack) do
		v:OnScreenResize(w,h)
	end

	self.screen_w_physical = w
	self.screen_h_physical = h

	self.screen_w = sw
	self.screen_h = sh

	--KAJ    self.fader:SetSize(w, h):SetPos(w/2, h/2)
	--KAJ    self.inker:SetSize(w, h):SetPos(w/2, h/2)
	--    self.bottom_bar:OnScreenResize(w, h)
	--        :SetPos( 0, nil )

	--    self.debugroot:OnScreenResize(w,h)
	--    self.dragroot:SetScale(self.base_scale)

	--    self.build_version:SetScale( self.base_scale ):LayoutBounds( "left", "bottom", 0, 0 )
end

function FrontEnd:SetGlobalErrorWidget(...)
	if not self.cachedError then
		self.cachedError = {...}
	end
end

function FrontEnd:ResetGlobalErrorWidget()
	self.cachedError = nil
end

function FrontEnd:CheckCachedError()
	if self.cachedError and not self.error_widget then
		-- set error_widget to SOMETHING so that the screen doesn't get pushed again
		-- it may error in the constructor and never get past that and thus never set it
		self.error_widget = true

		local widget = ScriptErrorWidget(table.unpack(self.cachedError))
		widget:MarkTransformDirty()
		self:PushScreen(widget)
		self:HideConsoleLog() -- hard to read error with console behind

		-- Pushing screens is not allowed after creating the error widget, so
		-- assign it last.
		self.error_widget = widget
	end
end

function FrontEnd:GetHoverWidget()
	return self.fe_root:GetDeepestHover()
end

-- Pass a Screen subclass or instance.
-- (Looking for GetOpenScreenOfType? Use this instead.)
function FrontEnd:FindScreen(screen_class)
	kassert.typeof("table", screen_class)
	for i, screen in ipairs(self.screenstack) do
		if screen == screen_class or screen:is_a(screen_class) then
			return screen, i
		end
	end
end

-- Mouse position in window coordinates with 0,0 at center of screen and the
-- max values at half of TheFrontEnd:GetScreenDims()
function FrontEnd:GetUIMousePos()
	-- TODO: Should this use the same coordinate system as widget layout?
	return TheInput:GetUIMousePos()
end

-- go from real window coords to the virtual screen coords
function FrontEnd:WindowToUI(x,y)
	local sx, sy = TheSim:GetScreenSize()
	x = x - sx / 2
	y = y - sy / 2
	return x, y
end

function FrontEnd:UIToWindow(x,y)
	local sx, sy = TheSim:GetScreenSize()
	x = x + sx / 2
	y = y + sy / 2
	return x,y
end

-- Looking for IsGamepadMode? This is probably what you want.
function FrontEnd:IsRelativeNavigation()
	-- True for both keyboard and gamepad navigation.
	return not self.tracking_mouse or Platform.IsBigPictureMode()
end

function FrontEnd:GetDragWidget()
	return self.drag and self.drag.w, self.drag and self.drag.id
end

function FrontEnd:OnControlDown( controls, device_type, trace, device_id )
	if not self.enable or (self.fading and self.fade_out) then
		return false
	end

	if ( device_type == "mouse" or device_type == "touch" ) then
		if not controls:Has(Controls.Digital.MENU_SCROLL_FWD, Controls.Digital.MENU_SCROLL_BACK) then
			-- Checking mouse hover here specifically for touch screens.
			-- Updating the hover in the update is 1 frame too late. It needs to happen immediately when the touch starts.
			self:FocusHoveredWidget()
		end
	end

	if self.drag then
		local mouse_cancel = device_type == "mouse" and controls:Has(Controls.Digital.MENU_ALT)
		if mouse_cancel or controls:Has(Controls.Digital.MENU_CANCEL) then
			self:CancelDrag()
			return true
		end
	end

	local ret = self:OnControl(controls, true, device_type, trace, device_id)
	if not ret then
		ret =  self:OnInputEvent( Widget.OnControlDown, controls, device_type, trace, device_id )
	end
	return ret
end

function FrontEnd:OnInputEvent( fn, controls, device_type, trace, device_id )


	--[[ KAJ: I don't think we want this?
	if ( device_type == "mouse" or device_type == "keyboard" ) then
		self:SetPendingControlMode( CONTROL_MODE.MOUSE_KEYBOARD, nil )
	elseif device_type == "touch" then
		self:SetPendingControlMode( CONTROL_MODE.TOUCH, device_type )
	elseif device_type == "gamepad" then
		self:SetPendingControlMode( CONTROL_MODE.GAMEPAD, device_id )
	end
]]
	if device_type == "gamepad" then
		if self.tracking_mouse then
			self:StopTrackingMouse(true)
		end
	end

	local device_owner = TheInput:GetDeviceOwner(device_type, device_id)
	for i = #self.screenstack, 1, -1 do
		local screen = self.screenstack[i]
		if device_type ~= "gamepad"
			or screen:CanDeviceInteract(device_type, device_id, device_owner)
		then
			if fn( screen, controls, device_type, trace, device_id ) then
				return true
			elseif screen:SinksInput() then
				break
			end
		end
	end
	return false
end

function FrontEnd:OnControlUp( controls, device_type, device_id )
	if self.drag and ( device_type == "mouse" or device_type == "touch" ) then
		return false
	end

	--local txt = ""
	--for i = 1, controls:GetSize() do
	--	local control, deviceTypeId = controls:GetControlDetailsAt(i)
	--	txt = txt..(control.shortkey or "").." "
	--end
	--print("CONTROL UP", device_type, txt)

	if not self.enable or (self.fading and self.fade_out) then
		return false
	end

	local ret = self:OnControl(controls, false, device_type, nil, device_id)
	if not ret then
		ret = self:OnInputEvent( Widget.OnControlUp, controls, device_type, nil, device_id )
	end
	-- When ending a click/tap, only clear hover after notifying all widgets, so that the focused/hovered ones get to process input
	--[[
	if self:IsTouchMode() then
		self.game:GetInput():ResetMousePos()
		self.fe_root:ClearHover()
		self:ClearFocusWidget()
	end
]]
	return ret
end

function FrontEnd:HintFocusWidget( widget )
	if self.tracking_mouse or widget == nil then
		TheFrontEnd:FocusHoveredWidget()
		-- Should we store the hint and activate it if we stop tracking the
		-- mouse? Right now we only stop using the mouse when changing focus.
	else
		widget:SetFocus()
	end
end

function FrontEnd:SetFocusWidget( widget )
	if widget ~= self.focus_widget then

		assert( widget:is_a(Widget))
		assert( not widget.removed, tostring(widget) )
		-- assert( widget.can_focus_with_nav, widget ) -- Can't assert this: FtF often gives screens focus.

		-- print( "FOCUS:", self.focus_widget, '->', widget, debug.traceback() )

		self:ClearFocusWidget(widget)
		self.focus_widget = widget

		-- Somewhat arbitrary according to the feature I'm implementing, but if focus changes, the tooltip override should be cleared.
		self.tooltip_focus_override = nil

		widget:GiveFocus()

		--TODO_KAJ        self.game:BroadcastEvent( "focus_changed", prev_focus, widget )
		self:OnFocusChanged(self.focus_widget)
		self.wants_control_option_refresh = true
	else
		--TODO_KAJ        self.game:BroadcastEvent( "focus_changed", self.focus_widget, nil )
	end
end

function FrontEnd:ClearFocusWidget(new_focus_widget)
	dbassert(not self.focus_locked)
	local widget = self.focus_widget
	--TODO_KAJ    self.game:BroadcastEvent( "focus_changed", widget, nil )
	if widget then
		-- print( "CLEAR FOCUS:", self.focus_widget, debug.traceback() )
		self.focus_widget = nil
		self.tooltip_focus_override = nil
		self.wants_control_option_refresh = true
		widget:RemoveFocus(new_focus_widget)
	end
end

function FrontEnd:GetScreenDims()
	return TheSim:GetScreenSize()
end

-- Push a parameter flag. You can push several times and the parameter is set
-- to 1. Once they're all popped, the parameter is set back to 0.
function FrontEnd:PushAudioParameter(param)
	dbassert(param)
	local current = self.audio_param_stack[param] or 0
	current = current + 1
	TheAudio:SetGlobalParameter(param, 1)
	self.audio_param_stack[param] = current
	--~ TheLog.ch.Audio:print("PushAudioParameter", param, current)
end

function FrontEnd:PopAudioParameter(param)
	local current = self.audio_param_stack[param]
	dbassert(param and current, param) -- only pop what was pushed
	current = current - 1
	if current == 0 then
		TheAudio:SetGlobalParameter(param, 0)
		current = nil
	end
	self.audio_param_stack[param] = current
	--~ TheLog.ch.Audio:print("PopAudioParameter", param, current)
end

function FrontEnd:PopEntireAudioParameterStack()
	TheLog.ch.Audio:print("PopEntireAudioParameterStack")
	for param,count in pairs(self.audio_param_stack) do
		TheAudio:SetGlobalParameter(param, 0)
		self.audio_param_stack[param] = nil
	end
end

function FrontEnd:EnableDebugFacilities()
	CAN_USE_DBUI = true
	DebugPanel = require "dbui.debug_panel"
	DebugNodes = require "dbui.debug_nodes"
	self:CreateDebugMenu()
end

return FrontEnd
