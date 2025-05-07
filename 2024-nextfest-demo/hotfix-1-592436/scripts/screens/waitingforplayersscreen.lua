local Image = require("widgets/image")
local Screen = require "widgets.screen"
local Text = require "widgets.text"
local lume = require "util.lume"
local fmodtable = require "defs.sound.fmodtable"

local STATUS_REVEAL_WAIT_TIME = 0.2

local WaitingForPlayersScreen = Class(Screen, function(self, finishedcallback, savedata, profile)
	Screen._ctor(self, "WaitingForPlayersScreen")
	self.callback = finishedcallback
	self.savedata = savedata
	self.profile = profile
	self.close_started = false
	self.real_time_start = 0
	self.time_in_screen = 0.0
	self.min_visible_time = 0
	self:DoInit()
	self:SetAudioEnterOverride(fmodtable.Event.ui_waitingForPlayersScreen_show)
		:SetAudioCategory(Screen.AudioCategory.s.Fullscreen)
end)

function WaitingForPlayersScreen:DoInit()
	self:SetAnchors("center","center")

	TheGameSettings:GetGraphicsOptions():DisableStencil()
	TheGameSettings:GetGraphicsOptions():DisableLightMapComponent()

	-- Super ugly background image:
	self.bg = self:AddChild(Image("images/bg_loading/loading.tex"))
	self.bg:SetAnchors("fill","fill")
	self.bg:SetMultColor(0, 0, 0, 1.0)

	self.fixed_root = self:AddChild(Screen("WaitingForPlayersScreen_fixed_root"))
		:SetAnchors("center","center")
		:SetScaleMode(SCALEMODE_PROPORTIONAL)

	self.status_text = self.fixed_root:AddChild(Text(FONTFACE.DEFAULT, 90, STRINGS.UI.WAITINGFORPLAYERSSCREEN.WAITING_TEXT, UICOLORS.WHITE))
		:LayoutBounds("center", "center", self)
		:Hide()

	self:SetNonInteractive()
end

function WaitingForPlayersScreen:Close()
	self:StopUpdating() -- this doesn't guarantee a stop update

	if not self.close_started then
		TheLog.ch.Networking:printf("All players are ready. Starting game.")
		self.close_started = true
		TheFrontEnd:Fade(FADE_OUT, 0, function()
			-- TheLog.ch.Networking:printf("WaitingForPlayersScreen Fade Finished")
			self.callback(self.savedata, self.profile)

			-- the callback is expected to be OnAllPlayersReady, and that calls TheFrontEnd:ClearScreens()
			-- if for some reason this screen is still active, remove it
			if self.inst and self.inst:IsValid() then
				TheFrontEnd:PopScreen(self)
			end
		end)
	end
end

function WaitingForPlayersScreen:OnClose()
	WaitingForPlayersScreen._base.OnClose(self)
	if TheFrontEnd:GetFadeLevel() == 1 then
		local fade_delay = 0.1
		TheFrontEnd:Fade(FADE_IN, SCREEN_FADE_TIME, nil, fade_delay)
	end
end

function WaitingForPlayersScreen:OnUpdate(dt)
	-- peculiar logic to handle this screen being created at the end of a long load frame
	if dt == 0.0 then
		-- this update is called from TheFrontEnd:PushScreen
		self.real_time_start = TheSim:GetRealTime()
		return
	elseif lume.approximately(dt, 0.2, 0.001) then
		-- this is likely the first update after the long load frame
		local real_time_since_start = TheSim:GetRealTime() - self.real_time_start
		if real_time_since_start < 0.2 then
			dt = real_time_since_start
		end
	end

	self.time_in_screen = self.time_in_screen + dt
	-- TheLog.ch.Networking:printf("WaitingForPlayersScreen time in screen = %1.3f dt=%1.3f", self.time_in_screen, dt)

	if self.time_in_screen > self.min_visible_time and TheNet:IsReadyToStartRoom() then
		self:Close()
	elseif not self.close_started and self.time_in_screen > STATUS_REVEAL_WAIT_TIME and not self.status_text:IsVisible() then
		TheLog.ch.Networking:printf("WaitingForPlayersScreen showing status...")
		self.status_text:Show()
		-- stay on this screen briefly if status is shown, otherwise it will flash and look like a bug.
		self.min_visible_time = 1
	end
end

return WaitingForPlayersScreen
