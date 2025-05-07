local Image = require "widgets.image"
local Panel = require("widgets/panel")
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local bossdef = require "defs.monsters.bossdata"
local easing = require "util.easing"

local BossHealthBar =  Class(Widget, function(self)
	Widget._ctor(self, "BossHealthBar")

	self.target = nil

	-- Widgets container
	self.container = self:AddChild(Widget())

	-- Setup boss portrait widget
	self.portrait = self.container:AddChild(Widget())
		:SetStencilContext( true )

	self.portraitBg = self.portrait:AddChild(Image("images/ui_ftf_ingame/boss_portrait_bg.tex"))
	self.portraitMask = self.portrait:AddChild(Image("images/ui_ftf_ingame/boss_portrait_mask.tex"))
		:SetMask()
	self.portraitIcon = self.portrait:AddChild(Image())
		:SetHiddenBoundingBox(true)
		:SetStencilTest(true)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		-- :Hide()

	-- Setup boss name bar
	self.nameBar = self.container:AddChild(Widget())
		:SendToBack()
	self.nameBarBg = self.nameBar:AddChild(Panel("images/ui_ftf_ingame/boss_name_back.tex"))
		:SetMultColor(UICOLORS.BLACK)
		:SetNineSliceCoords(7, 39, 25, 82)
	self.nameBarLabel = self.nameBar:AddChild(Text(FONTFACE.DEFAULT, 24 * 2, nil, UICOLORS.WHITE))

	-- Setup boss health number label
	self.healthBar = self.container:AddChild(Widget())
		:SendToBack()
	self.healthBarBg = self.healthBar:AddChild(Panel("images/ui_ftf_ingame/boss_health_back.tex"))
		:SetMultColor(UICOLORS.BLACK)
		:SetNineSliceCoords(40, 32, 90, 82)
		:SetSize(120 * HACK_FOR_4K, 82 * HACK_FOR_4K)
	self.healthBarLabel = self.healthBar:AddChild(Text(FONTFACE.DEFAULT, 24 * 2.3, nil, UICOLORS.WHITE))

	-- Setup boss hp bar
	self.hpBar = self.container:AddChild(Widget())
		:SendToBack()
	self.hpBarBg = self.hpBar:AddChild(Image("images/ui_ftf_ingame/boss_hp_back.tex"))
	self.hpBarProgress = self.hpBar:AddChild(Image("images/ui_ftf_ingame/boss_hp_progress.tex"))
	self.hpBarShadow = self.hpBar:AddChild(Image("images/ui_ftf_ingame/boss_hp_shadow.tex"))
	-- Position hp bar
	self.hpBar:LayoutBounds("after", "bottom", self.portrait)
		:Offset(-25 * HACK_FOR_4K, 20 * HACK_FOR_4K)

	self:Hide()

	self._onremovetarget = function() self:SetTarget(nil) end
	self._onhealthchanged = function(target, data)
		local is_remote_death = false
		if target and not target:IsLocal() and target.sg and target.sg:HasStateTag("death") then
			is_remote_death = true
		end

		-- Update bar
		self:SetPercent(is_remote_death and 0 or data.new / data.max)

		if self.target then
			-- Update tooltip
			self:SetToolTip(string.format("<b>%s's Health</b>\n%d/%d (%0.0f%%)",
				self.target:GetDisplayName(),
				is_remote_death and 0 or self.target.components.health:GetCurrent(),
				self.target.components.health:GetMax(),
				is_remote_death and 0 or self.target.components.health:GetPercent() * 100),
				{ offset_y = -100, region_w = 200, region_h = 80, wordwrap = true})
		end
	end

	self.inst:ListenForEvent("bossactivated", function(world, target)
		self:SetTarget(target)
	end, TheWorld)

end)

function BossHealthBar:_GetAnimOffscreenY()
	local _, h = self:GetSize()
	return (h + 15)
end

function BossHealthBar:AnimateIn(force)
	if force then
		self.container:SetPosition(0, self:_GetAnimOffscreenY())
	end
	self.container:MoveTo(0, 0, 0.7, easing.outElastic)
	return self
end

function BossHealthBar:AnimateOut(cb)
	self.container:MoveTo(0, self:_GetAnimOffscreenY(), 0.2, easing.inQuad, cb)
	return self
end

function BossHealthBar:SetTarget(target)
	if target ~= self.target then
		if self.target ~= nil then
			self.inst:RemoveEventCallback("onremove", self._onremovetarget, self.target)
			self.inst:RemoveEventCallback("healthchanged", self._onhealthchanged, self.target)
		end
		if target ~= nil then
			self.inst:ListenForEvent("onremove", self._onremovetarget, target)
			self.inst:ListenForEvent("healthchanged", self._onhealthchanged, target)
			if target.components.health ~= nil then
				self:SetPercent(target.components.health:GetPercent())

				-- Update tooltip
				self:SetToolTip(string.format("<b>%s's Health</b>\n%d/%d (%0.0f%%)",
					target:GetDisplayName(),
					target.components.health:GetCurrent(),
					target.components.health:GetMax(),
					target.components.health:GetPercent() * 100), { offset_y = -100, region_w = 200, region_h = 80, wordwrap = true})

				self.healthBarLabel:SetText(string.format("<b>%d</>/%d", target.components.health:GetCurrent(), target.components.health:GetMax()))
				local text_w, text_h = self.healthBarLabel:GetSize()
				self.healthBarBg:SetSize(text_w + 110 * HACK_FOR_4K, 70)
				self.healthBarLabel:LayoutBounds("center", "center", self.healthBarBg)
					:Offset(0, 0)
				-- Position health number bar
				self.healthBar:Show()
					:LayoutBounds("right", "above", self.hpBar)
					:Offset(-4 * HACK_FOR_4K, -4 * HACK_FOR_4K)
			else
				self.healthBar:Hide()
			end

			-- Update boss name
			self.nameBarLabel:SetText(target:GetDisplayName())
			local text_w, text_h = self.nameBarLabel:GetSize()
			self.nameBarBg:SetSize(text_w + 130 * HACK_FOR_4K, 60)
			self.nameBarLabel:LayoutBounds("left", "center", self.nameBarBg)
				:Offset(70 * HACK_FOR_4K, 0)
			-- Position name bar
			self.nameBar:LayoutBounds("after", "top", self.portrait)
				:Offset(-27 * HACK_FOR_4K, -28 * HACK_FOR_4K)

			-- Update boss portrait
			self.portraitIcon:SetTexture(bossdef:GetBossStylizedIcon(target))

			-- Position self and animate into position
			self:Show()
			self:AnimateIn(true)
		else
			self:Hide()
		end
		self.target = target
	end
end

function BossHealthBar:SetPercent(percent)
	if percent > 0 then
		local minimal_visible_health = 0.07
		percent = Remap(percent, 0, 1, minimal_visible_health, 1)
	end
	local texture_left_fudge_w = 30
	local texture_right_fudge_w = 19
	local bar_w, bar_h = self.hpBarBg:GetSize()
	local w_difference = (1 - percent) * bar_w
	self.hpBarProgress
		:SetScissor(-.5 * bar_w + w_difference + texture_left_fudge_w, -.5 * bar_h, bar_w - texture_left_fudge_w - texture_right_fudge_w, bar_h)
		:SetPosition(-w_difference, 0)

	-- Update boss health number
	if self.target and self.target.components.health ~= nil then
		self.healthBarLabel:SetText(string.format("<b>%d</>/%d",
			percent == 0 and 0 or self.target.components.health:GetCurrent(), self.target.components.health:GetMax()))

		local text_w, text_h = self.healthBarLabel:GetSize()
		self.healthBarBg:SetSize(text_w + 110 * HACK_FOR_4K, 70)
		self.healthBarLabel:LayoutBounds("center", "center", self.healthBarBg)
			:Offset(0, 0)
		-- Position health number bar
		self.healthBar:Show()
			:LayoutBounds("right", "above", self.hpBar)
			:Offset(-4 * HACK_FOR_4K, -4 * HACK_FOR_4K)
	else
		self.healthBar:Hide()
	end
end


function BossHealthBar:Test_ShowHealthDrain(start_health)
	local health = start_health or 0.25
	self.test_drain_task = self.inst:DoPeriodicTask(0.2, function(inst_)
		health = health - 0.01
		print("Test_ShowHealthDrain", health)
		self:SetPercent(health)
		if health <= 0 then
			print("Dead!", self.inst)
			self:SetPercent(1)
			self.test_drain_task:Cancel()
			self.test_drain_task = nil
		end
	end)
end

return BossHealthBar
