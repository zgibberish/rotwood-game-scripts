local Screen = require "widgets/screen"
local HuntProgressWidget = require "widgets/ftf/accoladewidgets/huntprogresswidget"
local templates = require "widgets/ftf/templates"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local ACCOLADE_SEQUENCE =
{
	{
		make_widget = function()
			return HuntProgressWidget()
		end,
	},
}

local HuntAccoladesScreen = Class(Screen, function(self, data)
	Screen._ctor(self, "HuntAccoladesScreen")
	self:SetAudioCategory(Screen.AudioCategory.s.PartialOverlay)
	self:SetAudioEnterOverride(nil)
	self:SetAudioExitOverride(nil)
	self:PushAudioParameterWhileOpen(fmodtable.GlobalParameter.g_isRunSummaryScreen)

	self.sequence_idx = 0
	self.presentation_sequence = ACCOLADE_SEQUENCE
	self.should_progress = true

    self.black = self:AddChild(templates.BackgroundTint())
		:SetMultColor(HexToRGB(0x211A1AFF))
		:SetMultColorAlpha(0.77)

	self.continue_btn = self:AddChild(templates.Button("Continue"))
		:SetPrimary()
		:SetOnClick(function() self:OnContinueClicked() end)
		:LayoutBounds("center", "bottom", self)
		:Offset(0, 100)

	self.default_focus = self.continue_btn

	self.animate_time = 0.2

	self:StartUpdating()
end)

-- TODO: someone -- copied from RunSummaryScreen, review presentation BEGIN
function HuntAccoladesScreen:OnBecomeActive()
	self._base.OnBecomeActive(self)
	if self.is_defeat then
		TheWorld.components.ambientaudio:SetEveryoneDead(true)
	end

	-- self:AnimateIn()
	TheDungeon.HUD:AnimateOut()
end

function HuntAccoladesScreen:OnBecomeInactive()
	self._base.OnBecomeInactive(self)
	-- Debug Flow: If you cheat health on this screen, restore previous state.
	self:_StopAudio()
	TheDungeon.HUD:AnimateIn()
end

function HuntAccoladesScreen:_StopAudio()
	if self.is_defeat then
		TheWorld.components.ambientaudio:SetEveryoneDead(false)
	end
end
-- TODO: someone -- copied from RunSummaryScreen, review presentation END

function HuntAccoladesScreen:OnContinueClicked()
	self.should_progress = true
	self.continue_btn:Disable()
end

function HuntAccoladesScreen:ShouldProgressSequence()
	return self.should_progress
	-- if host, logic here
	-- if not host, wait for the host to tell you to progress!
end

function HuntAccoladesScreen:ProgressSequence()
	local updater = {}

	self.should_progress = false

	if self.primary_widget then
		table.insert(updater, Updater.Do(function() self.primary_widget:AnimateOut(self.animate_time) end))
		table.insert(updater, Updater.Wait(self.animate_time))
		table.insert(updater, Updater.Do(function()
			self.primary_widget:Remove()
			self.primary_widget = nil
		end))
	else
		self:Hide()
		table.insert(updater, Updater.Wait(1))
		table.insert(updater, Updater.Do(function()
			self:Show()
			self.default_focus:SetFocus()
		end))
	end

	table.insert(updater, Updater.Do(function()
		self.sequence_idx = self.sequence_idx + 1
		self.presentation_data = self.presentation_sequence[self.sequence_idx]
		if self.presentation_data then
			self.primary_widget = self:AddChild(self.presentation_data.make_widget())
			self.primary_widget:LayoutBounds("center", "top", self)
				:Offset(0, -100)
		end
	end))

	table.insert(updater, Updater.Do(function()
		if self.primary_widget then
			self.primary_widget:AnimateIn(self.animate_time)
		else
			TheFrontEnd:PopScreen(self)
		end
	end))

	self:RunUpdater(Updater.Series(updater))
end

function HuntAccoladesScreen:OnUpdate(dt)
	if self:ShouldProgressSequence() then
		self:ProgressSequence()
	end
	-- look at RunSummaryScreen:OnUpdate() for network implementation details
end

return HuntAccoladesScreen
