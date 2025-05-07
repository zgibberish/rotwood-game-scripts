local Image = require "widgets.image"
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local easing = require("util/easing")

local DPSTracker = Class(Widget, function(self, owner)
	Widget._ctor(self, "DPSTracker")

	self.owner = owner

	self.damage_log = { }
	self.dps_value_log = { }
	self.damage_count = 0
	self.damage_total = 0
	self.dps_peak = 0
	self.timer = 0

	self.decay_bar_w = 200
	self.decay_bar_h = 60

	self.visualize_iframes = false

	--[[
	self.combo_count = 0
	self.combo_count_max = 0
	self.combo_timeout = 1
	self.combo_max = 0
	]]
	self.hitstreak = 0
	self.hitstreak_max = 0

	self.text_root = TheDungeon.HUD:AddChild(Widget())
		:SetAnchors("center", "bottom")

	self.dps_label = self.text_root:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
		:SetText("DPS")
		:SetFontSize(64)
		:SetPosition(0, 360)

	self.damage_5s_average = self.text_root:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
		:SetText("0.0")
		:SetFontSize(128)
		:SetPosition(0, 260)

	self.dps_peak_text = self.damage_5s_average:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
		:SetText("maxDPS:0")
		:SetFontSize(48)
		:SetPosition(160, 0)
	self.dps_peak_text:SetRegistration("left", "center")

	--[[
	self.combo_text = self.damage_5s_average:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
		:SetText("combo:0 max:0")
		:SetFontSize(24)
		:SetPosition(-160, 0)
	--]]

	self.hitstreak_text = self.damage_5s_average:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
		:SetText("hits:0 max:0")
		:SetFontSize(48)
		:SetPosition(160, -64)
	self.hitstreak_text:SetRegistration("left", "center")

	self.hitstreak_decay_bar = self.text_root:AddChild(Image("images/ui_ftf_hud/hitstreak_decay_bar.tex"))
		:SetSize(self.decay_bar_w, self.decay_bar_h)
		:LayoutBounds("center", "above", self.dps_label)
		:SetMultColor(UICOLORS.LIGHT_TEXT)
	self.hitstreak_decay_text = self.hitstreak_decay_bar:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.DARK_TEXT))
		:SetText(string.format("%.2f sec", 0))
		:LayoutBounds("left", "center", self.hitstreak_decay_bar)
		-- :SetGlyphColor(0, 0, 0, 1)


	self.hitstreak_dropped_bar = self.text_root:AddChild(Image("images/ui_ftf_hud/hitstreak_decay_bar.tex"))
		:SetSize(self.decay_bar_w, self.decay_bar_h)
		:LayoutBounds("center", "center", self.hitstreak_decay_bar)
		:SetMultColor(UICOLORS.PENALTY)

	self.hitstreak_dropped_text = self.hitstreak_dropped_bar:AddChild(Text(FONTFACE.DEFAULT, 30, "DROPPED", RGB(0,0,0)))
		:LayoutBounds("center", "center", self.hitstreak_dropped_bar)

	self.hitstreak_dropped_bar:Hide()

	self.damage_total_text = self.text_root:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
		:SetText("0")
		:SetFontSize(96)
		:SetPosition(0, 160)
	

	self._onhitstreak = function(inst, data)
		if inst:IsLocal() then
			self:LogHit(data)
		end
	end
	self.inst:ListenForEvent("hitstreak", self._onhitstreak, owner)

	owner:StartUpdatingComponent(self)
end)

local SAMPLE_SECONDS = 1 -- how many seconds should the sample be? e.g. average dps over 5 seconds, over 3 seconds, etc

function DPSTracker:LogDamage(damage)
	table.insert(self.damage_log, { damage = damage, time_active = 0})
end

function DPSTracker:LogHit(data)
	--[[
	if (data.combo_count < self.combo_count) then
		self.combo_count_max = self.combo_count
	elseif data.combo_count > self.combo_count_max then
		self.combo_count_max = data.combo_count
	end
	self.combo_count = data.combo_count
	self.combo_timeout = 1
	]]

	local old = self.hitstreak

	self.hitstreak = data.hitstreak
	self.hitstreak_max = math.max(data.hitstreak, self.hitstreak_max)

	if self.hitstreak == 0 and old ~= 0 then
		self.hitstreak_dropped_bar:Show()
		self.hitstreak_dropped_bar:SetMultColorAlpha(1)
		self.hitstreak_dropped_bar:AlphaTo(0, 0.25, easing.linear, function() self.hitstreak_dropped_bar:Hide() end)
	end


	-- self.combo_text:SetText(string.format("combo:%d max:%d", data.combo_count, self.combo_count_max))
	self.hitstreak_text:SetText(string.format("hits:%d max:%d", data.hitstreak, self.hitstreak_max))
end

function DPSTracker:VisualizeIframes(toggle)
	self.visualize_iframes = toggle
end

function DPSTracker:OnUpdate(dt)
	--[[
	if self.combo_timeout > 0 then
		self.combo_timeout = self.combo_timeout - dt
		if self.combo_timeout <= 0 then
			self.combo_timeout = 0
			self.combo_count = 0
			self.combo_count_max = math.max(self.combo_count_max, self.combo_count)
			self.combo_text:SetText(string.format("combo:0 max:%d", self.combo_count_max, self.combo_count_max))
		end
	end
	]]

	if self.visualize_iframes then
		if self.owner.HitBox:IsInvincible() then
			self.owner.components.coloradder:PushColor("visualize_iframes", 0/255, 255/255, 0/255, 1)
			self.owner.AnimState:SetBloom( 0/255, 255/255, 0/255, 0.5)
		elseif not self.owner.HitBox:IsEnabled() then
			self.owner.components.coloradder:PushColor("visualize_iframes", 255/255, 255/255, 0/255, 1)
			self.owner.AnimState:SetBloom( 255/255, 255/255, 0/255, 0.5)
		else
			self.owner.components.coloradder:PushColor("visualize_iframes", 255/255, 0/255, 0/255, 1)
			self.owner.AnimState:SetBloom( 255/255, 0/255, 0/255, 0.1)
		end
	end

	self.timer = self.timer + dt
	self.damage_count = 0
	for k,v in pairs(self.damage_log) do
		if v ~= nil then
			v.time_active = v.time_active + dt
			if v.time_active >= 1 then
				table.remove(self.damage_log, k)
			else
				self.damage_count = self.damage_count + v.damage
			end
		end
	end

	if self.timer >= 1 then
		self.timer = self.timer - 1

		table.insert(self.dps_value_log, self.damage_count)
		if #self.dps_value_log == SAMPLE_SECONDS then
			local total_damage = 0
			for i = 1, #self.dps_value_log do
				total_damage = total_damage + self.dps_value_log[i]
			end
			local dps = total_damage / SAMPLE_SECONDS
			self.damage_5s_average:SetText(tonumber(string.format("%.1f", dps)))

			self.damage_total = self.damage_total + total_damage
			self.damage_total_text:SetText(self.damage_total)
			if dps > self.dps_peak then
				self.dps_peak = math.max(self.dps_peak, dps)
				self.dps_peak_text:SetText(string.format("maxDPS:%1.1f", dps))
					:SetGlyphColor(WEBCOLORS.LIME)
			else
				self.dps_peak_text:SetGlyphColor(UICOLORS.LIGHT_TEXT)
			end
			self.dps_value_log = { }
		end
	end

	local hitstreak_decay = self.owner.components.combat:GetHitStreakDecay()
	local hitstreak_decay_percentage = hitstreak_decay/TUNING.PLAYER.HIT_STREAK.MAX_TIME

	self.hitstreak_decay_text:SetText(string.format("%.2f sec", hitstreak_decay))
	self.hitstreak_decay_bar:SetScissor( - 0.5 * self.decay_bar_w - (1 - hitstreak_decay_percentage) * self.decay_bar_w, -0.5 * self.decay_bar_h, self.decay_bar_w, self.decay_bar_h)
end

return DPSTracker
