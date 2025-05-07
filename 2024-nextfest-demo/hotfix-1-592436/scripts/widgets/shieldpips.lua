local Power = require "defs.powers"
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local ShieldIconWidget = require("widgets/shieldiconwidget")
local easing = require "util.easing"

--KNOWN ISSUE: scale of shield covers health bar so you can't see how much damage is taken, if your health is in the middle section
--TODO: if entering a room, don't do shield pulse

local ShieldPips = Class(Widget, function(self, owner)
	Widget._ctor(self, "ShieldPips")

	self.shield_scissor_time = 0.25 -- how long the bar takes to lerp between values
	self.shield_scale_time = 2.5 -- how long the shield icon bounce takes
	self.shield_scale_size = 1.5 -- how big the shield icon bounce gets

	self.shield_icon_disabled_brightness = 0.75 -- how big the shield icon bounce gets
	self.shield_icon_highlight_brightness = 1.5 -- how big the shield icon bounce gets
	self.shield_icon_enabled_brightness = 1.25 -- how big the shield icon bounce gets

	self._shield_pip_widgets = {}

	-- Widgets container
	self.container = self:AddChild(Widget())
		:Hide()

	self.shield_bar = self.container:AddChild(Widget())
		:SetPosition(0,10)

	self.shield_bar_frame = self.shield_bar:AddChild(Image("images/ui_ftf_ingame/ui_shield_bar_frame.tex"))

	self.shield_bar_fill = self.shield_bar:AddChild(Image("images/ui_ftf_ingame/ui_shield_bar_fill.tex"))
		:LayoutBounds("left", "center", self.shield_bar_frame)
		:SendToBack()

	self.max_fill_w, self.max_fill_h = self.shield_bar_fill:GetSize()

	self.shield_bar_bg = self.shield_bar:AddChild(Image("images/ui_ftf_ingame/ui_shield_bar_bg.tex"))
		:LayoutBounds("center", "center", self.shield_bar_frame)
		:SendToBack()

	self.shield_icon_root = self.shield_bar:AddChild(Widget("Shield Icon"))
		:SetScale(0.9)

	self.shield_bar_icon_bg = self.shield_icon_root:AddChild(Image("images/ui_ftf_ingame/ui_shield_hud_hp_iconBg.tex"))

	self.shield_bar_icon = self.shield_icon_root:AddChild(Image("images/ui_ftf_ingame/ui_shield_bar_icon.tex"))
		:LayoutBounds("center", "center", self.shield_bar_icon_bg)
		:SetBrightness(self.shield_icon_disabled_brightness)

	self.shield_bar_icon_broken = self.shield_icon_root:AddChild(Image("images/ui_ftf_ingame/ui_shield_bar_icon_broken.tex"))
		:LayoutBounds("center", "center", self.shield_bar_icon_bg)
		:SetBrightness(self.shield_icon_disabled_brightness)
		:Hide()

	self.shield_icon_root:LayoutBounds("center", "bottom", self.shield_bar_frame)
		:Offset(0, 1)

	-- listen for shield power update, add or remove shield pips based on counter
	self._onupdate_power = function(source, data) self:OnUpdatePower(data) end
	self._onadd_power = function(source, data) self:OnAddPower(data) end
	self:SetOwner(owner)
end)

function ShieldPips:SetTheme_UnitFrame()
	self.shield_bar_frame:SetTexture("images/ui_ftf_hud/UI_HUD_shieldFrame.tex")
	self.shield_bar_fill:SetTexture("images/ui_ftf_hud/UI_HUD_shieldBar.tex")
	self.shield_bar_bg:SetTexture("images/ui_ftf_hud/UI_HUD_shieldBar.tex")
		:SetMultColor(0.5, 0.5, 0.5, 1)
	self.shield_icon_root:LayoutBounds("center", "bottom", self.shield_bar_frame)
		:SetScale(1.1)
	return self
end

function ShieldPips:OnUpdatePower(data)
	local is_shield = false
	local tags = nil
	if data.def ~= nil and data.def.tags ~= nil then
		tags = data.def.tags
	elseif data.pow ~= nil and data.pow.def.tags ~= nil then --this 'data' can be quite different depending on whether it's an add_power or a deltapowerstacks. Might be worth splitting into two On____() funcs
		tags = data.pow.def.tags
	end
	if tags then
		for i, tag in ipairs(tags) do
			if tag == POWER_TAGS.SHIELD or tag == POWER_TAGS.PROVIDES_SHIELD_SEGMENTS then
				is_shield = true
				break
			end
		end
	end
	if is_shield then
		self.owner.components.powermanager:RefreshTags() -- kind of sketchy, but the order of operations here means we need to update tags before updating the UI. We receive this event before tags have been refreshed
		self:RefreshLayout(data)
	end
end

function ShieldPips:OnAddPower(data)
	local is_shield = false
	if data.def ~= nil and data.def.tags ~= nil then
		for i, tag in ipairs(data.def.tags) do
			if tag == POWER_TAGS.SHIELD or tag == POWER_TAGS.PROVIDES_SHIELD_SEGMENTS then
				is_shield = true
				break
			end
		end
	end

	if is_shield then
		self.owner.components.powermanager:RefreshTags() -- kind of sketchy, but the order of operations here means we need to update tags before updating the UI. We receive this event before tags have been refreshed
		self:RefreshLayout(data)
	end
end


function ShieldPips:RefreshLayout(data)
	-- do update stuff
	local shield_def = Power.Items.SHIELD.shield
	local pm = self.owner.components.powermanager
	if (self.owner:HasTag(POWER_TAGS.SHIELD) and pm:GetPowerStacks(shield_def) > 0) or self.owner:HasTag(POWER_TAGS.PROVIDES_SHIELD_SEGMENTS) then
		self.container:Show()
		local old_pips = data ~= nil and data.old or 0
		local pips = data ~= nil and data.new or self:GetNumShieldPips()
		local max = self:GetMaxShieldPips()

		local old_percent = old_pips / max
		local new_percent = pips / max

		local bar_w, bar_h = self.shield_bar_fill:GetSize()

		local old_w_difference = (1 - old_percent) * bar_w
		local new_w_difference = (1 - new_percent) * bar_w

		local old_scissor = { -.5 * bar_w - old_w_difference, -.5 * bar_h, bar_w, bar_h }
		local new_scissor = { -.5 * bar_w - new_w_difference, -.5 * bar_h, bar_w, bar_h  }

		local fullshield = pips == max

		if old_pips == max and pips == 0 then
			-- SHIELD BREAK!
			local duration = self.shield_scale_time
			self.shield_bar_icon_broken:Show()
			self.shield_bar_icon_broken:SetBrightness(self.shield_icon_enabled_brightness)
			self.shield_bar_icon:Hide()

			self.shield_bar_icon_broken:ScaleTo(1, self.shield_scale_size*1.25, duration*1.25 * 0.05, easing.inOutQuad, function()
				self.owner:PushEvent("shield_ui_bg_update", { enabled = false, could_have_shield = true, })
				self.shield_bar_icon_broken:ScaleTo(self.shield_scale_size*1.25, 1, duration*1.25 * 0.2, easing.inBack, function()
					self.shield_bar_icon:Show()
					self.shield_bar_icon_broken:Hide()

					self.shield_bar_icon:SetBrightness(self.shield_icon_disabled_brightness)
				end)
			end)
			self.shield_bar_icon_bg:ScaleTo(1, self.shield_scale_size*1.25, duration*1.25 * 0.05, easing.inOutQuad, function()
				self.shield_bar_icon_bg:ScaleTo(self.shield_scale_size*1.25, 1, duration*1.25 * 0.2, easing.inBack)
			end)
		end

		if data.dont_animate then
			local target_brightness = self.shield_icon_disabled_brightness
			if fullshield then
				target_brightness = self.shield_icon_enabled_brightness
			end
			self.shield_bar_icon:SetBrightness(target_brightness)
			self.shield_bar_fill:SetScissor(new_scissor[1], new_scissor[2], new_scissor[3], new_scissor[4])
			self.owner:DoTaskInTicks(1, function() self.owner:PushEvent("shield_ui_bg_update", { enabled = fullshield, dont_animate = true, could_have_shield = true, }) end)
		else
			self.shield_bar_fill:ScissorTo(old_scissor, new_scissor, self.shield_scissor_time, easing.linear, function()
				if fullshield then
					-- SHIELD GET!
					local duration = self.shield_scale_time
					self.shield_bar_icon:SetBrightness(self.shield_icon_highlight_brightness)
					self.shield_bar_icon:ScaleTo(1, self.shield_scale_size, duration * 0.05, easing.inOutQuad, function()
						self.owner:PushEvent("shield_ui_bg_update", { enabled = true, could_have_shield = true, })
						self.shield_bar_icon:ScaleTo(self.shield_scale_size, 1, duration * 0.2, easing.inBack)
						self.shield_bar_icon:SetBrightness(self.shield_icon_enabled_brightness)
					end)
					self.shield_bar_icon_bg:ScaleTo(1, self.shield_scale_size, duration * 0.05, easing.inOutQuad, function()
						self.shield_bar_icon_bg:ScaleTo(self.shield_scale_size, 1, duration * 0.2, easing.inBack)
					end)
				end
			end)
		end
	else
		self.container:Hide()
		self.owner:PushEvent("shield_ui_bg_update", { enabled = false, could_have_shield = false, })
	end

	self.owner:PushEvent("refresh_hud")
end

function ShieldPips:SetOwner(owner)
	if owner ~= self.owner then
		if self.owner ~= nil then
			self.inst:RemoveEventCallback("power_stacks_changed", self._onupdate_power, self.owner)
			self.inst:RemoveEventCallback("power_stacks_changed_remote", self._onupdate_power, self.owner)
			self.inst:RemoveEventCallback("add_power", self._onadd_power, owner)

		end

		self.owner = owner

		if self.owner ~= nil then
			self.inst:ListenForEvent("power_stacks_changed", self._onupdate_power, self.owner)
			self.inst:ListenForEvent("power_stacks_changed_remote", self._onupdate_power, self.owner)
			self.inst:ListenForEvent("add_power", self._onadd_power, self.owner)
			self:RefreshLayout( { dont_animate = true } )
		end
	end
end

function ShieldPips:GetNumShieldPips()
	local shield_def = Power.Items.SHIELD.shield
	return self.owner.components.powermanager:GetPowerStacks(shield_def)
end

function ShieldPips:GetMaxShieldPips()
	local shield_def = Power.Items.SHIELD.shield
	return shield_def.max_stacks
end

return ShieldPips
