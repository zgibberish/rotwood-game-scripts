local Image = require "widgets.image"
local Widget = require("widgets/widget")
local Text = require("widgets/text")
local easing = require "util.easing"

--- Displays a single player character's portrait and a health bar next to it
-- Check PlayerPortrait to see the portrait alone
-- Check PlayerStatusWidget to see this with an actions bar and buffs container
local PlayerHealthBar =  Class(Widget, function(self, owner)
	Widget._ctor(self, "PlayerHealthBar")

	self:SetScaleMode(SCALEMODE_PROPORTIONAL)

	self.container = self:AddChild(Widget())

	self.hp_bar = self.container:AddChild(Widget())
		:SetScale(0.3, 0.4)
		:SendToBack()

	self.hp_bar_bg = self.hp_bar:AddChild(Image("images/ui_ftf_ingame/boss_hp_back.tex"))

	self.hp_bar_mask = self.hp_bar:AddChild(Image("images/ui_ftf_ingame/boss_hp_mask.tex"))
		:LayoutBounds("left", "center", self.hp_bar_bg)
		:SetMask()

	self.hp_bar_hurt = self.hp_bar:AddChild(Image("images/ui_ftf_ingame/boss_hp_mask.tex"))
		:SetMultColor(1, 0, 0, 1)
		:SetMasked()

	self.hp_bar_health = self.hp_bar:AddChild(Image("images/ui_ftf_ingame/boss_hp_mask.tex"))
		:SetMultColor(owner.uicolor)
		:LayoutBounds("left", "center", self.hp_bar_bg)
		:SetMasked()

	self.hp_bar_hurt:LayoutBounds("left", "center", self.hp_bar_health)

	self.text_root = self.container:AddChild(Widget())
	self.textOutline = self:AddChild(Text(FONTFACE.DEFAULT, 18, nil, UICOLORS.BLACK))
		:EnableShadow()
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:EnableOutline()
		:SetOutlineColor(UICOLORS.BLACK)
	self.text = self:AddChild(Text(FONTFACE.DEFAULT, 18, nil, UICOLORS.LIGHT_TEXT_TITLE))

	self.text_root:LayoutBounds("center", "center", self.hp_bar)

	self._onhealthchanged = function(target, data)
		self:DoHealthDelta(data)
	end

	self.time_hurt_bar_visible = 1.0

	self._fade_hurt_bar_task = nil

	if owner then
		self:SetOwner(owner)
	end
end)

function PlayerHealthBar:SetOwner(owner)
	if owner ~= self.owner then
		if self.owner ~= nil then
			self.inst:RemoveEventCallback("healthchanged", self._onhealthchanged, self.owner)
		end

		self.owner = owner

		if self.owner ~= nil then
			self.inst:ListenForEvent("healthchanged", self._onhealthchanged, self.owner)
			if self.owner.components.health ~= nil then
				self:SetHealthPercent(self.owner.components.health:GetPercent())
			end
		end
	end
end

function PlayerHealthBar:DoHealthDelta(data)
	local new_percent = data.new/ data.max
	local bar_w, bar_h = self.hp_bar_bg:GetSize()
	local new_w_difference = (1 - new_percent) * bar_w
	local new_scissor = { -.5 * bar_w - new_w_difference, -.5 * bar_h, bar_w, bar_h  }
	self.hp_bar_health:SetScissor(table.unpack(new_scissor))

	if data.new > data.old then
		self.hp_bar_hurt:SetScissor(table.unpack(new_scissor))
	else
		self.hp_bar_hurt:SetMultColorAlpha(1)

		if self._fade_hurt_bar_task then
			self._fade_hurt_bar_task:Cancel()
			self._fade_hurt_bar_task = nil
		end

		self._fade_hurt_bar_task = self.inst:DoTaskInTime(self.time_hurt_bar_visible, function() self:FadeOutDamageChunk(new_scissor) end)
	end

	self:UpdateText()
end

function PlayerHealthBar:FadeOutDamageChunk(new_scissor)
	self._fade_hurt_bar_task = nil
	self.hp_bar_hurt:AlphaTo(0, 0.25, easing.inExpo, function()
		self.hp_bar_hurt:SetScissor(table.unpack(new_scissor))
	end)
end

function PlayerHealthBar:SetHealthPercent(percent)
	local bar_w, bar_h = self.hp_bar_mask:GetSize()

	local w_difference = (1 - percent) * bar_w
	self.hp_bar_health:SetScissor(-.5 * bar_w - w_difference, -.5 * bar_h, bar_w, bar_h)
	self.hp_bar_health:LayoutBounds("left", "center", self.hp_bar_bg)

	self.hp_bar_hurt:SetScissor(-.5 * bar_w - w_difference, -.5 * bar_h, bar_w, bar_h)
	self.hp_bar_hurt:LayoutBounds("left", "center", self.hp_bar_health)

	self:UpdateText()
end

function PlayerHealthBar:UpdateText()
	local current = math.ceil(self.owner.components.health:GetCurrent())
	local max = self.owner.components.health:GetMax()

	self.text:SetText(string.format("%s/%s", current, max))
	self.textOutline:SetText(string.format("%s/%s", current, max))
end

function PlayerHealthBar:Test_ShowHealthDrain(start_health)
	local health = start_health or 0.25
	self.test_drain_task = self.inst:DoPeriodicTask(0.2, function(inst_)
		health = health - 0.01
		print("Test_ShowHealthDrain", health)
		self:SetValue(health, 1)
		if health <= 0 then
			print("Dead!", self.inst)
			self:SetValue(1, 1)
			self.test_drain_task:Cancel()
			self.test_drain_task = nil
		end
	end)
end

function PlayerHealthBar:TOP_LEFT()
	self:SetHealthPercent(self.owner.components.health:GetCurrent()/self.owner.components.health:GetMax())
end

function PlayerHealthBar:TOP_RIGHT()
	self:SetHealthPercent(self.owner.components.health:GetCurrent()/self.owner.components.health:GetMax())
end

function PlayerHealthBar:BOTTOM_LEFT()
	self:SetHealthPercent(self.owner.components.health:GetCurrent()/self.owner.components.health:GetMax())
end

function PlayerHealthBar:BOTTOM_RIGHT()
	self:SetHealthPercent(self.owner.components.health:GetCurrent()/self.owner.components.health:GetMax())
end

return PlayerHealthBar
