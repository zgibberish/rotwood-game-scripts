local Image = require "widgets.image"
local Power = require "defs.powers"
local ShieldPips = require("widgets/shieldpips")
local Widget = require("widgets/widget")
local easing = require "util.easing"
local SegmentedHealthBar = require("widgets/ftf/segmentedhealthbar")
local PlayerUsernameWidget = require("widgets/ftf/playerusernamewidget")

local PlayerFollowHealthBar =  Class(Widget, function(self, owner)
	Widget._ctor(self, "PlayerFollowHealthBar")

	self:SetOwningPlayer(owner)

	self:SetScaleMode(SCALEMODE_PROPORTIONAL)

	-- Widgets container
	self.container = self:AddChild(Widget())

	self.shield_pips = self.container:AddChild(ShieldPips(owner))
		:SetScale(.525 * HACK_FOR_4K)

	self.hp_bar = self.container:AddChild( SegmentedHealthBar(owner) )
		:SetHealthBounds(150, 1000, 1500)
		:SetScale(0.35 * HACK_FOR_4K)
		:SendToBack()
		:LayoutBounds("center", "below", self.shield_pips)

	self.hp_bar.text_root:Hide()

	self.hp_bar:SetOnSizeChangeFn(function()
		self.hp_bar:LayoutBounds("center", "below", self.shield_pips)
		self:UpdateShieldBGSize()
	end)

	self.shield_hp_border = self.container:AddChild(Image("images/ui_ftf_ingame/ui_shield_hp_border.tex"))
		:SetScale(self.hp_bar:GetScale())
		:AlphaTo(0, 0, easing.outExpo)
		:SendToBack()

	self:UpdateShieldBGSize()

	self.username = self:AddChild(PlayerUsernameWidget(owner))
		:SetFontSize(FONTSIZE.COMMON_HUD)
		:LayoutBounds("center", "below", self.hp_bar)
		:Offset(0, -5 * HACK_FOR_4K)
		:SetMultColor(owner.uicolor)
		:Hide()

	self.fade_out_time = 0.25
	self.time_visible = 2.0 -- how long the bar is visible after showing damage
	self.time_visible_shield = 3.0 -- how long the bar is visible after showing damage when you have a shield power

	self._onremovetarget = function() self:SetOwner(nil) end
	self._onmaxhealthchanged = function (target, data) self:Reveal() end
	self._onhealthchanged = function(target, data) if data and not data.silent and data.old ~= data.new then self:Reveal() end end
	self._onupdate_power = function(source, data) self:OnUpdatePower(data) end
	self._onupdate_ui_color = function(source, rgb) self:_RefreshColor() end
	self._onadd_power = function(source, data) self:OnAddPower(data) end
	self._onupdate_shieldbg = function(source, data) self:OnUpdateShieldBackground(data) end
	self._on_enterroom = function(source, data) self:OnEnterRoom(data) end
	self._do_hide = function(source, data) self:Hide() end
	self._do_show = function(source, data) self:Show() end
	self._on_preview_health_change = function() self:ShowHealthBar(true) end
	self._on_preview_health_change_end = function() self:HideHealthBar() end

	self:Hide()

	self:SetOwner(owner)
end)

function PlayerFollowHealthBar:UpdateShieldBGSize()
	local new_w, new_h = self.hp_bar:GetSize()
	local pad = 30
	self.shield_hp_border:SetSize(new_w + pad, new_h + pad)
		:LayoutBounds("center", "center", self.hp_bar)
end

function PlayerFollowHealthBar:_RefreshColor()
	self.username:SetMultColor(self.owner.uicolor)
	self.hp_bar:RefreshColor()
end

function PlayerFollowHealthBar:OnUpdatePower(data)
	local is_shield = false

	local shield_def = Power.Items.SHIELD.shield
	if data.power_def == shield_def then
		is_shield = true
	end

	if is_shield then
		self.time_visible = self.time_visible_shield
		self:Reveal()
	end
end

function PlayerFollowHealthBar:OnAddPower(data)
	local is_shield = false
	if data.def ~= nil and data.def.tags ~= nil then
		for i, tag in ipairs(data.def.tags) do
			if tag == POWER_TAGS.PROVIDES_SHIELD then
				is_shield = true
				break
			end
		end
	end

	if is_shield then
		self.time_visible = self.time_visible_shield
		self:Reveal()
	end
end

function PlayerFollowHealthBar:OnUpdateShieldBackground(data)
	if data.enabled then
		self.shield_hp_border:AlphaTo(1, data.dont_animate and 0 or .4, easing.inExpo)
	else
		self.shield_hp_border:AlphaTo(0, data.dont_animate and 0 or .4, easing.outExpo)
	end
end

function PlayerFollowHealthBar:OnEnterRoom(data)
	local should_reveal = false
	if self.owner:HasTag(POWER_TAGS.PROVIDES_SHIELD) or
		self.owner.components.health:IsLow() then
		should_reveal = true
	end

	if should_reveal then
		self:Reveal()
	end
end

function PlayerFollowHealthBar:SetOwner(owner)
	if owner ~= self.owner then
		if self.owner ~= nil then
			self.inst:RemoveEventCallback("onremove", self._onremovetarget, self.owner)
			self.inst:RemoveEventCallback("maxhealthchanged", self._onmaxhealthchanged, self.owner)
			self.inst:RemoveEventCallback("healthchanged", self._onhealthchanged, self.owner)
			self.inst:RemoveEventCallback("power_stacks_changed", self._onupdate_power, self.owner)
			self.inst:RemoveEventCallback("update_ui_color", self._onupdate_ui_color, self.owner)
			self.inst:RemoveEventCallback("add_power", self._onadd_power, owner)
			self.inst:RemoveEventCallback("shield_ui_bg_update", self._onupdate_shieldbg, owner)
			self.inst:RemoveEventCallback("enter_room", self._on_enterroom, owner)
			self.inst:RemoveEventCallback("playerfollowhealthbar_hide", self._do_hide, self.owner)
			self.inst:RemoveEventCallback("playerfollowhealthbar_show", self._do_show, self.owner)
			self.inst:RemoveEventCallback("previewhealthchange", self._on_preview_health_change, self.owner)
			self.inst:RemoveEventCallback("previewhealthchange_end", self._on_preview_health_change_end, self.owner)
		end

		self.owner = owner

		if self.owner ~= nil then
			self.inst:ListenForEvent("onremove", self._onremovetarget, self.owner)
			self.inst:ListenForEvent("maxhealthchanged", self._onmaxhealthchanged, self.owner)
			self.inst:ListenForEvent("healthchanged", self._onhealthchanged, self.owner)
			self.inst:ListenForEvent("power_stacks_changed", self._onupdate_power, self.owner)
			self.inst:ListenForEvent("update_ui_color", self._onupdate_ui_color, self.owner)
			self.inst:ListenForEvent("add_power", self._onadd_power, self.owner)
			self.inst:ListenForEvent("shield_ui_bg_update", self._onupdate_shieldbg, self.owner)
			self.inst:ListenForEvent("enter_room", self._on_enterroom, self.owner)
			self.inst:ListenForEvent("playerfollowhealthbar_hide", self._do_hide, self.owner)
			self.inst:ListenForEvent("playerfollowhealthbar_show", self._do_show, self.owner)
			self.inst:ListenForEvent("previewhealthchange", self._on_preview_health_change, self.owner)
			self.inst:ListenForEvent("previewhealthchange_end", self._on_preview_health_change_end, self.owner)
		end

		self.hp_bar:SetOwner(self.owner)
	end
end

function PlayerFollowHealthBar:Reveal()
	if not TheWorld:HasTag("town") then
		if self.owner:IsLocal() then
			TheNetEvent:HealthBarReveal(self.owner.GUID) -- caught by HandleNetEventHealthBarReveal()
		end
	end
end

function PlayerFollowHealthBar:ShowHealthBar(permanent)
	self:StartUpdating()
	self:UpdatePosition()
	self:Show()

	if #AllPlayers > 1 then
		self.username:Show()
	else
		self.username:Hide()
	end

	self.container:SetMultColorAlpha(1)

	-- Send permanent=true if you want to hold this up until we manually hide it again.
	if not permanent then
		self:StartUpdating()
		self:MakeFadeOutTask()
	else
		-- Since this Show is supposed to be permanent, cancel any fades that may have already begun.
		if self._fade_out_task then
			self._fade_out_task:Cancel()
			self._fade_out_task = nil
		end
	end
end

function PlayerFollowHealthBar:HideHealthBar()
	self:StartUpdating()
	self:MakeFadeOutTask()
end

function PlayerFollowHealthBar:MakeFadeOutTask()
	if self._fade_out_task then
		self._fade_out_task:Cancel()
		self._fade_out_task = nil
	end

	self._fade_out_task = self.inst:DoTaskInTime(self.time_visible, function()
		self.container:AlphaTo(0, self.fade_out_time, easing.inExpo, function()
			self:StopUpdating()
			self:Hide()
		end)
	end)
end

function PlayerFollowHealthBar:UpdatePosition()
	local x, y = self:CalcLocalPositionFromEntity(self.owner)
	self:SetPosition(x, y + 180 * HACK_FOR_4K)
end

function PlayerFollowHealthBar:OnUpdate(dt)
	self:UpdatePosition()
end

return PlayerFollowHealthBar
