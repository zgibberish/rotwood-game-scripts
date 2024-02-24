local Enum = require "util.enum"
local Widget = require("widgets/widget")
local Text = require("widgets/text")
local easing = require("util.easing")
local krandom = require "util.krandom"


local CounterStates = Enum{
	"HIDDEN",
	"FADE_IN",
	"ACTIVE",
	"FADE_OUT",
}

local HitCounter = Class(Widget, function(self, owner)
	Widget._ctor(self, "HitCounter")

	self:SetOwningPlayer(owner)
	self.owner = owner -- TODO(ui): Use GetOwningPlayer instead of self.owner
	self.container = self:AddChild(Widget())

	self.active_timer = 0
	self.hitstreak = 0
	self.hitstreakdecaytime = 0
	self.hit_threshold = 5
	self.hit_threshold_warm = 7
	self.hit_threshold_hot = 10
	self.damagetotal = 0

	self.fontsize_number = 120
	self.fontsize_hits = 72
	self.fontsize_damagecount = 72
	self.fontsize_dmg_max_addition = 24
	self.fontsize_dmg = 48

	-- For decaying fontsize & alpha over time during the active state, to visualize the hitstreak decay time fading out
	self.fontsize_decayfade_startpercent = .4
	self.active_fontsize = 0
	self.active_maxfontsize = 0

	self.color_default = UICOLORS.WHITE
	self.color_streak = UICOLORS.GREY
	self.color_streak_warm = UICOLORS.GOLD
	self.color_streak_hot = UICOLORS.RED

	-- We're limited in how we can align the numbers with their corresponding
	-- text because the numbers grow as the hit counts grow, but the text is
	-- static.

	local text_spacing = 8
	local offcenter = 8
	local toward_center = 15

	self.number = self.container:AddChild(Text(FONTFACE.DEFAULT, self.fontsize_number, "00", self.color_streak))
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()
		:SetRegistration("right", "bottom")
		:Offset(-offcenter, -toward_center)

	self.hits_label = self.container:AddChild(Text(FONTFACE.DEFAULT, self.fontsize_hits, STRINGS.UI.HUD.HITCOUNTER.HIT_STREAK, self.color_default))
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()
		:SetRegistration("left", "center")
		:LayoutBounds("after", "center", self.number)
		:Offset(text_spacing, 0)

	self.damage_number = self.container:AddChild(Text(FONTFACE.DEFAULT, self.fontsize_damagecount + self.fontsize_dmg_max_addition, "000", self.color_default))
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()
		:SetRegistration("left", "top")
		:Offset(offcenter, toward_center)

	self.dmg_label = self.container:AddChild(Text(FONTFACE.DEFAULT, self.fontsize_dmg, STRINGS.UI.HUD.HITCOUNTER.DAMAGE_SUM, self.color_default))
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()
		:SetRegistration("right", "center")
		:LayoutBounds("before", "center", self.damage_number)
		:Offset(-text_spacing, 0)

	self.fade_in_time = 0.2
	self.fade_out_time = 0.05
	self.decay_fade_out_time = 0.6
	self.decay_fade_in_time = 0.05

	-- for the "shake" when a new hit comes
	self.y_offset_target = 20
	self.x_offset_target = 20
	self.shake_time = 0.25

	self:SetState(CounterStates.s.HIDDEN)
	self:SetClickable(false)

	-- listen for hitstreak and decay time events from combat
	self.inst:ListenForEvent("hitstreak", function(inst, event_data)
		self:ProcessHitStreakEvent(inst, event_data)
	end, owner)

	self.inst:ListenForEvent("hitstreakdecay", function(inst, event_data)
		self:ProcessHitStreakDecayEvent(event_data)
	end, owner)

	self:Hide()
end)

function HitCounter:DebugDraw_AddSection(ui, panel)
	HitCounter._base.DebugDraw_AddSection(self, ui, panel)

	ui:Spacing()
	ui:Text("HitCounter")
	ui:Indent() do
		if ui:Button("Set to random numbers") then
			self:Show()
			local data = { hitstreak = krandom.Integer(10), damagetotal = krandom.Integer(300) }
			-- Skip ProcessHitStreakEvent because we just want to see the text.
			self:ProcessEvent(GetDebugPlayer(), data)
			self:UpdateText()
		end
		-- These always seem to lead to nan crashes, so don't allow for now.
		--~ if ui:Button("FadeIn", nil, nil, self.state ~= CounterStates.s.HIDDEN) then
		--~ 	self:FadeIn()
		--~ end
		--~ if ui:Button("FadeOut", nil, nil, self.state == CounterStates.s.HIDDEN) then
		--~ 	self:FadeOut()
		--~ end
	end
	ui:Unindent()
end

function HitCounter:SetState(state)
	self.state = state
end

function HitCounter:GetState()
	return self.state
end

function HitCounter:ShouldShowHitCounter(data)
	return data.hitstreak >= self.hit_threshold or (self.owner:HasTag(POWER_TAGS.USES_HITSTREAK) and data.hitstreak > 0)
end

function HitCounter:ProcessHitStreakEvent(inst, data)
	if self.state == CounterStates.s.HIDDEN and not self:ShouldShowHitCounter(data) then
		return
	elseif data.hitstreak == 0 and (self.state == CounterStates.s.FADE_IN or self.state == CounterStates.s.ACTIVE)then
		self:FadeOut()
		return
	end

	self:ProcessEvent(inst, data)

	if self.state == CounterStates.s.HIDDEN or
		(self.state == CounterStates.s.FADE_OUT and self:ShouldShowHitCounter(data)) then
		self:FadeIn()
	end
end

function HitCounter:ProcessHitStreakDecayEvent(data)
	-- TheLog.ch.Combat:printf("New hitstreak decay time: %1.2f", data.hitstreakdecaytime)
	self.hitstreakdecaytime = data.hitstreakdecaytime
end

function HitCounter:FadeIn()
	self:SetState(CounterStates.s.FADE_IN)
	self:UpdatePosition()
	self:UpdateText()
	self:Show()
	self:StartUpdating()
	self.container:AlphaTo(1, self.fade_in_time, easing.outExpo, function()
		self:SetState(CounterStates.s.ACTIVE)
	end)
end

function HitCounter:FadeOut()
	self:SetState(CounterStates.s.FADE_OUT)
	self.container:AlphaTo(0, self.fade_out_time, easing.inExpo, function()
		if self:GetState() == CounterStates.s.FADE_OUT then
			self:SetState(CounterStates.s.HIDDEN)
			self:StopUpdating()
			self:Hide()
			self.active_maxfontsize = 0
		end
	end)
end

function HitCounter:ProcessEvent(inst, data)
	self.active_timer = 0
	self.hitstreak = data.hitstreak
	self.damagetotal = data.damagetotal
	-- TODO: local vs remote presentation style with inst:IsLocal()
	if self:ShouldShowHitCounter(data) then
		self:UpdateText()
	end
end

function HitCounter:UpdateText()
	local hits_text = string.format("%d", self.hitstreak)
	local hits_fontsize_new = self.fontsize_number + math.min(48, math.floor(self.hitstreak / 5 * 6))

	local dmg = math.floor(self.damagetotal) -- jambell: sometimes this is crashing from no integer representation... try rounding to fix crash?
											 -- This may show incorrect information, be careful.
	local damage_text = string.format("%d", dmg)
	local damage_fontsize_new = self.fontsize_damagecount + math.min(self.fontsize_dmg_max_addition, math.floor(self.damagetotal / 5 * 6))

	local color
	if self.hitstreak >= self.hit_threshold_hot then
		color = self.color_streak_hot
	elseif self.hitstreak >= self.hit_threshold_warm then
		color = self.color_streak_warm
	else
		color = self.color_streak
	end

	self.number:SetText(hits_text)
		:SetFontSize(hits_fontsize_new)
		:SetGlyphColor(color)

	self.damage_number:SetText(damage_text)
		:SetFontSize(damage_fontsize_new)
		:SetGlyphColor(color)

	self.active_fontsize = hits_fontsize_new
	if self.active_fontsize > self.active_maxfontsize then
		self.active_maxfontsize = self.active_fontsize
	end
end

function HitCounter:UpdatePosition(dt)
	local y_offset = 20
	local x_offset = 20
	if self.state == CounterStates.s.ACTIVE or self.state == CounterStates.s.FADE_IN then
		y_offset = easing.outElastic(self.active_timer, 0, self.y_offset_target, self.shake_time, 100, 0.1)
		x_offset = easing.outExpo(self.active_timer, 0, self.x_offset_target, self.shake_time)
	end
	local x, y = self:CalcLocalPositionFromEntity(self.owner)
	self:SetPosition(x + x_offset, y + y_offset + 440)
end

function HitCounter:UpdateDecayFade(dt)
	if self.active_timer >= self.fontsize_decayfade_startpercent * self.hitstreakdecaytime then
		-- Fade Fontsize:
		local lerp_duration = math.max(TICKS, self.hitstreakdecaytime)

		local fontsize_new = easing.linear(
			self.active_timer - (self.fontsize_decayfade_startpercent * self.hitstreakdecaytime),
			self.active_maxfontsize,
			-(self.active_maxfontsize - self.fontsize_number),
			lerp_duration)
		self.number:SetFontSize(fontsize_new)
		self.active_fontsize = fontsize_new

		local alpha = easing.linear(
			self.active_timer - (self.fontsize_decayfade_startpercent * self.hitstreakdecaytime),
			1,
			-0.7,
			lerp_duration)
		self.container:SetFadeAlpha(alpha)
	else
		self.number:SetFontSize(self.active_fontsize)
		self.container:SetFadeAlpha(1)
	end

	if self.active_timer >= self.hitstreakdecaytime then
		self:FadeOut()
	end
end

function HitCounter:OnUpdate(dt)
	self.active_timer = self.active_timer + dt
	self:UpdatePosition(dt)

	if self:GetState() == CounterStates.s.ACTIVE then
		self:UpdateDecayFade(dt)
	end
end

return HitCounter
