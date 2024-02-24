local Image = require "widgets.image"
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local easing = require("util/easing")

local HitStunVisualizer = Class(Widget, function(self, owner)
	Widget._ctor(self, "HitStunVisualizer")

	self.owner = owner

	-- self.damage_log = { }
	-- self.dps_value_log = { }
	-- self.damage_count = 0
	-- self.damage_total = 0
	-- self.dps_peak = 0
	-- self.timer = 0

	-- self.decay_bar_w = 100
	-- self.decay_bar_h = 30

	-- self.visualize_iframes = false

	-- --[[
	-- self.combo_count = 0
	-- self.combo_count_max = 0
	-- self.combo_timeout = 1
	-- self.combo_max = 0
	-- ]]
	-- self.hitstreak = 0
	-- self.hitstreak_max = 0

	-- self.text_root = TheDungeon.HUD:AddChild(Widget())
	-- 	:SetAnchors("center", "bottom")

	-- self.dps_label = self.text_root:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
	-- 	:SetText("DPS")
	-- 	:SetFontSize(32)
	-- 	:SetPosition(0, 240)

	-- self.damage_5s_average = self.text_root:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
	-- 	:SetText("0.0")
	-- 	:SetFontSize(64)
	-- 	:SetPosition(0, 190)

	-- self.dps_peak_text = self.damage_5s_average:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
	-- 	:SetText("maxDPS:0")
	-- 	:SetFontSize(24)
	-- 	:SetPosition(160, 0)
	-- self.dps_peak_text:SetRegistration("left", "center")

	-- --[[
	-- self.combo_text = self.damage_5s_average:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
	-- 	:SetText("combo:0 max:0")
	-- 	:SetFontSize(24)
	-- 	:SetPosition(-160, 0)
	-- --]]

	-- self.hitstreak_text = self.damage_5s_average:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
	-- 	:SetText("hits:0 max:0")
	-- 	:SetFontSize(24)
	-- 	:SetPosition(160, -32)
	-- self.hitstreak_text:SetRegistration("left", "center")

	-- self.hitstreak_decay_bar = self.text_root:AddChild(Image("images/ui_ftf_hud/hitstreak_decay_bar.tex"))
	-- 	:SetSize(self.decay_bar_w, self.decay_bar_h)
	-- 	:LayoutBounds("center", "above", self.dps_label)
	-- 	:SetMultColor(UICOLORS.LIGHT_TEXT)
	-- self.hitstreak_decay_text = self.hitstreak_decay_bar:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.DARK_TEXT))
	-- 	:SetText(string.format("%.2f sec", 0))
	-- 	:LayoutBounds("left", "center", self.hitstreak_decay_bar)
	-- 	-- :SetGlyphColor(0, 0, 0, 1)


	-- self.hitstreak_dropped_bar = self.text_root:AddChild(Image("images/ui_ftf_hud/hitstreak_decay_bar.tex"))
	-- 	:SetSize(self.decay_bar_w, self.decay_bar_h)
	-- 	:LayoutBounds("center", "center", self.hitstreak_decay_bar)
	-- 	:SetMultColor(UICOLORS.PENALTY)

	-- self.hitstreak_dropped_text = self.hitstreak_dropped_bar:AddChild(Text(FONTFACE.DEFAULT, 30, "DROPPED", RGB(0,0,0)))
	-- 	:LayoutBounds("center", "center", self.hitstreak_dropped_bar)

	-- self.hitstreak_dropped_bar:Hide()

	-- self.damage_total_text = self.text_root:AddChild(Text(FONTFACE.DEFAULT, 30, "", UICOLORS.LIGHT_TEXT))
	-- 	:SetText("0")
	-- 	:SetFontSize(48)
	-- 	:SetPosition(0, 140)
	

	-- self._onhitstreak = function(inst, data) self:LogHit(data) end
	-- self.inst:ListenForEvent("hitstreak", self._onhitstreak, owner)

	owner:StartUpdatingComponent(self)
end)

function HitStunVisualizer:OnUpdate(dt)
	if self.owner.sg:HasStateTag("hit") then
		-- Hitstun
		self.owner.components.coloradder:PushColor("visualize_hitstun", 255/255, 0/255, 0/255, 1)
		self.owner.AnimState:SetBloom( 255/255, 0/255, 0/255, 0.5)
	elseif self.owner.sg:HasStateTag("attack") and self.owner.sg:HasStateTag("busy") then
		-- Attack, non-interruptible
		self.owner.components.coloradder:PushColor("visualize_hitstun", 0/255, 0/255, 255/255, 1)
		self.owner.AnimState:SetBloom( 0/255, 0/255, 255/255, 0.5)
	else
		-- Normal state
		self.owner.components.coloradder:PushColor("visualize_hitstun", 0/255, 255/255, 0/255, 1)
		self.owner.AnimState:SetBloom( 0/255, 255/255, 0/255, 0.1)
	end
end

return HitStunVisualizer
