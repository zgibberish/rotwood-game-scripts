local Image = require "widgets.image"
local Widget = require "widgets.widget"
local easing = require "util.easing"
local kassert = require "util.kassert"

local FullscreenEffect = Class(Widget, function(self, tex, timing, tuning)
	Widget._ctor(self, "FullscreenEffect")

	self.timing = timing or {}
	self.tuning = tuning or {}

	self.timing.fadein  = self.timing.fadein or 1
	self.timing.life    = self.timing.life or 1
	self.timing.fadeout = self.timing.fadeout or 2

	self.tuning.min_alpha = self.tuning.min_alpha or 0

	self.multcolor = { 1, 1, 1 }

	self.img = self:AddChild(Image(tex))

	self.setalpha_fn = function(a)
		self:SetAlpha(a)
	end
	self.hide_fn = function(a)
		self:Hide()
	end

	self:SetClickable(false)
	self:SetAlpha(0) -- ensure alpha is initialized
	self:Hide()
end)

function FullscreenEffect:SetMultColor(r, g, b)
	assert(b)
	self.multcolor = { r, g, b }
end

function FullscreenEffect:SetAlpha(a)
	local r, g, b = table.unpack(self.multcolor)
	self.img:SetMultColor(r, g, b, a)
	self.alpha = a
end

function FullscreenEffect:StartOneShot()
	if not TheGameSettings:Get("graphics.screen_flash") then
		return
	end
	self:Show()
	self:RunUpdater(Updater.Series({
				Updater.Ease(self.setalpha_fn, 0, 1, self.timing.fadein, easing.outQuart),
				Updater.Wait(self.timing.life),
				Updater.Ease(self.setalpha_fn, 1, 0, self.timing.fadeout, easing.inSine),
				Updater.Do(self.hide_fn),
		}))
end

function FullscreenEffect:StartLooping()
	if not TheGameSettings:Get("graphics.screen_flash") then
		return
	elseif self.updater then
		-- updater existing means we're already looping.
		return
	end
	self:Show()
	local ease = easing.inOutSine
	self.updater = Updater.Series({
			-- Ease in from zero alpha
			Updater.Ease(self.setalpha_fn, 0, 1, self.timing.fadein, ease),
			Updater.Wait(self.timing.life),
			Updater.Ease(self.setalpha_fn, 1, self.tuning.min_alpha, self.timing.fadeout, ease),
			-- Loop with desired min alpha
			Updater.Loop({
					Updater.Ease(self.setalpha_fn, self.tuning.min_alpha, 1, self.timing.fadein, ease),
					Updater.Wait(self.timing.life),
					Updater.Ease(self.setalpha_fn, 1, self.tuning.min_alpha, self.timing.fadeout, ease),
				}),
		})
	self:RunUpdater(self.updater)
end

function FullscreenEffect:StopLooping()
	if not self.updater then
		-- Ignore graphics.screen_flash so we correctly restore if the setting
		-- was modified while effect was active.
		-- TODO(dbriscoe): Stop active effects when screen flash setting changes.
		return
	end
	assert(self.updater)
	self:StopUpdater(self.updater)
	self.updater = nil
	self:RunUpdater(Updater.Series({
				Updater.Ease(self.setalpha_fn, self.alpha, 0, self.timing.fadeout, easing.inOutSine),
				Updater.Do(self.hide_fn),
		}))
end

function FullscreenEffect:SetLooping(should_loop)
	kassert.typeof("boolean", should_loop)
	if should_loop then
		self:StartLooping()
	else
		self:StopLooping()
	end
end

return FullscreenEffect
