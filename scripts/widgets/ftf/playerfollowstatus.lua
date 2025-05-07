local easing = require("util/easing")
local fmodtable = require "defs.sound.fmodtable"
local lume = require("util/lume")
local PotionWidget = require("widgets/ftf/potionwidget")
local PowerWidget = require("widgets/ftf/powerwidget")
local SkillWidget = require("widgets/ftf/skillwidget")
local FoodWidget = require("widgets/ftf/foodwidget")
local Text = require("widgets/text")
local Widget = require("widgets/widget")

local Power = require("defs.powers.power")

local BAR_STATES =
{
	["HIDDEN"] = "HIDDEN", -- currently hidden
	["FADE_IN"] = "FADE_IN", -- fading into the world
	["IDLE"] = "IDLE", -- visible, but not doing anything right now
	["FADE_OUT"] = "FADE_OUT", -- fading out of the world
}

local SOUND_EVENTS =
{
	["OPEN_DEFAULT"] = fmodtable.Event.ui_powerRing_open,
	["OPEN_POWERS"] = fmodtable.Event.ui_powerRing_open,
	["CLOSE"] = fmodtable.Event.ui_powerRing_close,
	["FOCUS"] = fmodtable.Event.ui_powerRing_hover,
}

-- Weirdly low because we put it in ring 2 since it's quite far.
local base_potion_offset = -50


local PlayerFollowStatus = Class(Widget, function(self, owner)
	Widget._ctor(self, "PlayerFollowStatus")
	self:SetHoverSound(fmodtable.Event.hover)
	--~ assert(owner) -- TODO(demo): enable after demo
	-- Don't set self.owner until last!

	-- Widgets container
	self.container = self:AddChild(Widget())
	self.container_y_offset = 64 * HACK_FOR_4K

	-- player id (i.e. "1P", "2P", etc.)
	self.playerid = self.container:AddChild(Widget())
	self.playerid.number = self.playerid:AddChild(Text(FONTFACE.BUTTON, 75 * HACK_FOR_4K, "", UICOLORS.RED))
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()
	self.playerid:Hide()

	-- potion status (type, stock/count)
	self.actions_size = 48 * HACK_FOR_4K
	self.potionstatus = self.container:AddChild(PotionWidget(self.actions_size, owner))
	self.potionstatus:Hide()
	self.potionstatus:ABOVE_HEAD()

	-- power status
	self.powers_add_time = 0.175
	self.powers_radius = 164 * HACK_FOR_4K
	self.powers = {}

	-- Add potion so it can be hovered from radial.
	self.powers.potionstatus_w = {
		name = "potionstatus_w",
		is_fake_power = true,
		fixed_position = true,
		y_offset = base_potion_offset,
		widget = self.potionstatus,
		posAngle = math.pi * 0.5, -- it's at the top
		ring = 2, -- better aligns and avoids size popping.
		initScale = 1,
		targetScale = 1,
	}

	self.powersstatus = self.container:AddChild(Widget())
	for _,pow in ipairs(owner.components.powermanager:GetAllPowersInAcquiredOrder()) do
		self:AddPower(pow.persistdata, owner)
	end

	self.inst:ListenForEvent("add_power", function(owner_, pow)
		if self.owner then
			assert(owner_ == self.owner)
			if not self.powers[pow.def.name] then
				self:AddPower(pow.persistdata, owner_)
			end
		end
	end, owner)

	self.inst:ListenForEvent("remove_power", function(owner_, pow)
		if self.owner then
			assert(owner_ == self.owner)
			if self.powers[pow.def.name] then
				self.powers[pow.def.name].widget:Remove()
				self.powers[pow.def.name] = nil
			end
		end
	end, owner)

	self._onupdate_shieldbg = function(source, data) self:_OnUpdateShieldBackground(data) end

	self:SetBarState(BAR_STATES.HIDDEN)
	self.container:SetFadeAlpha(0)
	self.fade_in_time = 0.5 -- how long it takes to fade in
	self.fade_out_time = 0.5 -- how long it takes to fade out
	self.time_visible_default = 1.1 -- how long the bar is visible after showing damage
	self.time_visible = self.time_visible_default
	self._start_fade_timer = 0

	self.lastFocusedPowerName = nil
	self._focus_timer = 0

	self.toggleMode = false
	self.isHovering = false

	self._onremovetarget = function() self:SetOwner(nil) end
	self:Hide()
	self:SetOwner(owner)
end)

function PlayerFollowStatus:_OnUpdateShieldBackground(data)
	if data.enabled then
		-- Push above healthbar's shield bg.
		self.powers.potionstatus_w.y_offset = base_potion_offset + 50
	else
		self.powers.potionstatus_w.y_offset = base_potion_offset
	end
end

function PlayerFollowStatus:GetBarState()
	return self.bar_state
end

function PlayerFollowStatus:SetBarState(new_state)
	self.bar_state = new_state
end

function PlayerFollowStatus:SetOwner(owner)
	if owner ~= self.owner then
		if self.owner ~= nil then
			self.inst:RemoveEventCallback("onremove", self._onremovetarget, self.owner)
			self.inst:RemoveEventCallback("shield_ui_bg_update", self._onupdate_shieldbg, self.owner)
		end

		self.owner = owner

		if self.owner ~= nil then
			self.inst:ListenForEvent("onremove", self._onremovetarget, self.owner)
			self.inst:ListenForEvent("shield_ui_bg_update", self._onupdate_shieldbg, self.owner)
		end
	end
end


function PlayerFollowStatus:CanShowPowers()
	-- return not self.owner.sg:HasStateTag("moving") and not self.owner.sg:HasStateTag("busy")
	return true
end

function PlayerFollowStatus:OnControlUp(controls, down)
	-- on hover, the front end takes priority over the player controller, so this
	-- needs to be implemented to turn off toggle mode
	if controls:Has(Controls.Digital.SHOW_PLAYER_STATUS) and self.toggleMode then
		self.toggleMode = false
	end
end

function PlayerFollowStatus:Reveal(data)
	if data.toggleMode then
		self.toggleMode = (data.toggleMode == "down")
	end
	if self.bar_state == BAR_STATES.IDLE then
		if data.show_powers and not self.powersstatus:IsVisible() and self:CanShowPowers() then
			local power_count = lume.count(self.powers)
			self.time_visible = self.time_visible_default + (self.powers_add_time * power_count)
			self.powersstatus:Show()
		elseif self.powersstatus:IsVisible() then
			self._start_fade_timer = self.time_visible - 0.05
		elseif self.playerid:IsVisible() and data.show_id then
			self._start_fade_timer = 0
		end
	elseif self.bar_state == BAR_STATES.HIDDEN then
		local y_offset = 180 * HACK_FOR_4K
		if data.show_potion then
			self.potionstatus:Show()
			-- potionstatus is positioned by powers, but it takes up space here.
			local pad = 130
			y_offset = y_offset + self.powers.potionstatus_w.y_offset + pad
		else
			self.potionstatus:Hide()
		end

		local actually_show_powers = data.show_powers and self:CanShowPowers()
		local power_count = 0
		if actually_show_powers then
			power_count = lume.count(self.powers)
			self.time_visible = self.time_visible_default + (self.powers_add_time * power_count)
			self.powersstatus:Show()
		else
			self.powersstatus:Hide()
		end

		if data.show_id then
			local text = string.format("%s", data.text)
			self.playerid.number:SetText(text)
			self.playerid:Show()

			if data.text_color then
				self.playerid.number:SetGlyphColor(data.text_color)
			end
			if data.text_outline_color then
				self.playerid.number:SetOutlineColor(data.text_outline_color)
			end

			y_offset = y_offset + 65 * HACK_FOR_4K
			self.playerid:SetPosition(0, y_offset)
		else
			self.playerid:Hide()
		end

		self.shake = data.shake
		self._start_fade_timer = 0
		self._focus_timer = 0
		self.lastFocusedPowerName = nil
		self:FadeIn()
		self:PlaySpatialSound((actually_show_powers and power_count > 0) and SOUND_EVENTS.OPEN_POWERS or SOUND_EVENTS.OPEN_DEFAULT, { Count = power_count }, nil, 1)
	end
end

function PlayerFollowStatus:CheckFocus(dt)
	for k,v in pairs(self.powers) do
		if v.widget.hover then
			self.isHovering = true
			self.lastCheckFocus = 0.3
			return
		end
	end

	-- throttle last check for mouse hover twitchiness
	-- gaps between widgets and the scaling effect can cause premature auto-close
	if self.lastCheckFocus then
		self.lastCheckFocus = self.lastCheckFocus - dt
		if self.lastCheckFocus <= 0 then
			self.lastCheckFocus = nil
		end
	end

	if self.lastCheckFocus == nil then
		self.isHovering = false
	end
end

function PlayerFollowStatus:ClearFocus()
	if self.lastFocusedPowerName then
		self.powers[self.lastFocusedPowerName].widget:ClearHover()
		self.lastFocusedPowerName = nil
		self._focus_timer = 0
	end
end

function PlayerFollowStatus:FadeIn()
	self.potionstatus:RefreshUses()
	self:SetBarState(BAR_STATES.FADE_IN)
	self:UpdatePosition()
	self:Show()
	self:StartUpdating()
	self.container:AlphaTo(1, self.fade_in_time, easing.outExpo, function()
		self:SetBarState(BAR_STATES.IDLE)
	end)
end

function PlayerFollowStatus:FadeOut()
	if self.powersstatus:IsVisible() then
		local power_count = lume.count(self.powers)
		if power_count > 0 then
			self:PlaySpatialSound(SOUND_EVENTS.CLOSE, { Count = power_count }, nil, 1)
		end
	end

	self:ClearFocus()
	self:SetBarState(BAR_STATES.FADE_OUT)
	self.container:AlphaTo(0, self.fade_out_time, easing.inExpo, function()
		self:SetBarState(BAR_STATES.HIDDEN)
		self:StopUpdating()
		self:Hide()
	end)
end

function PlayerFollowStatus:UpdatePosition()

	if self.owner then 
		local x, y = self:CalcLocalPositionFromEntity(self.owner)

		if self.shake and self.bar_state == BAR_STATES.FADE_IN then
			local y_offset_target = 0
			local y_offset_target_time = 0.5
			local amp = 30 * HACK_FOR_4K
			local period = 0.1
			local y_offset = easing.outElastic(self._start_fade_timer, 0, y_offset_target, y_offset_target_time, amp, period)
			y = y + y_offset
		end

		if self.bar_state == BAR_STATES.FADE_IN or self.bar_state == BAR_STATES.FADE_OUT then
			for k,v in pairs(self.powers) do
				local angle
				if v.fixed_position then
					angle = v.posAngle
				elseif self.bar_state == BAR_STATES.FADE_IN then
					local amp = 0.5
					local period = self.fade_in_time * 0.5
					local t = self._start_fade_timer
					angle = easing.outElastic(t, 0, v.posAngle, self.fade_in_time, amp, period)
				elseif self.bar_state == BAR_STATES.FADE_OUT then
					angle = v.posAngle - easing.inExpo(self._start_fade_timer, 0, v.posAngle, self.fade_out_time)
				end

				local wr = self.powers_radius * (0.8 + (0.35 * (v.ring - 1)))
				local wx = wr * math.cos(angle)
				local wy = wr * math.sin(angle)
				local extra_y = v.y_offset or 0
				v.widget:SetPosition(wx, wy + extra_y + self.container_y_offset)
				v.widget:SetScale(1,1)
			end
		elseif self.bar_state == BAR_STATES.IDLE then
			for k,v in pairs(self.powers) do
				local wr = self.powers_radius * (0.8 + (0.35 * (v.ring - 1)))
				wr = k == self.lastFocusedPowerName and wr + 8 or wr
				local wx = wr * math.cos(v.posAngle)
				local wy = wr * math.sin(v.posAngle)
				local extra_y = v.y_offset or 0
				v.widget:SetPosition(wx, wy + extra_y + self.container_y_offset)
			end
		end

		self:SetPosition(x, y)
	end
end

local kRoot2 = math.sqrt(2)
-- kMinRadialThreshold is for mouse since gamepad deadzone is handled elsewhere.
local kMinRadialThreshold = 0.1
local kOuterRingThreshold = 0.94

-- Estimate the maximum throw for a given angle generated from a pair of independent axes for XY from [-1,1]
-- This gets within 95-100% of the actual throw
local function CalcMaxThrow(angleRad)
	if angleRad >= 0.75 * math.pi or angleRad <= -0.75 * math.pi then
		return math.sqrt(1 + (kRoot2 * math.sin(angleRad)) ^ 2)
	elseif angleRad >= 0.5 * math.pi or angleRad <= -0.5 * math.pi then
		return math.sqrt(1 + (kRoot2 * math.cos(angleRad)) ^ 2)
	elseif angleRad >= 0.25 * math.pi or angleRad <= -0.25 * math.pi then
		return math.sqrt(1 + (kRoot2 * math.cos(angleRad)) ^ 2)
	else
		return math.sqrt(1 + (kRoot2 * math.sin(angleRad)) ^ 2)
	end
end

function PlayerFollowStatus:UpdateFocus()
	if self.owner then
		if self.bar_state ~= BAR_STATES.IDLE then
			return
		end

		local playercontroller = self.owner.components.playercontroller
		local r, angle = playercontroller:GetRadialMenuDir()
		local usingGamepad = playercontroller:GetLastInputDeviceType() == "gamepad"
		if not usingGamepad then
			if self.isHovering then
				-- generate r, angle for relative mouse position from widget origin
				local mx, my = TheInput:GetVirtualMousePos()
				local wx, wy = self:GetPosition()
				local dx = mx - wx
				local dy = my - wy - self.container_y_offset
				angle = math.deg(ReduceAngleRad(-math.atan(dy, dx)))
				local maxAxisLen = self.powers_radius * 0.9
				r = math.sqrt(dx * dx + dy * dy) / maxAxisLen
			end
		end

		if r and r >= kMinRadialThreshold then
			angle = -angle
			local angleRad = ReduceAngleRad(math.rad(angle))
			local maxThrow = CalcMaxThrow(angleRad)

			local powersSorted = {}
			local count = 0
			local maxRing = 1
			for k,v in pairs(self.powers) do
				count = count + 1
				powersSorted[count] = v
				maxRing = math.max(maxRing, v.ring)
			end

			local preferredRing = (r >= kOuterRingThreshold * maxThrow) and maxRing or 1

			if count > 0 then
				table.sort(powersSorted, function(a,b)
					local diffA = DiffAngleRad(a.posAngle, angleRad)
					local diffB = DiffAngleRad(b.posAngle, angleRad)
					if lume.approximately(diffA, diffB, 0.00001) then
						return math.abs(preferredRing - a.ring) < math.abs(preferredRing - b.ring)
					else
						return diffA < diffB
					end
				end)

				if not self.lastFocusedPowerName or powersSorted[1].name ~= self.lastFocusedPowerName then
					self._focus_timer = 0

					if self.lastFocusedPowerName then
						self.powers[self.lastFocusedPowerName].widget:ClearHover()
					end

					self.lastFocusedPowerName = powersSorted[1].name
					self:PlaySpatialSound(SOUND_EVENTS.FOCUS)
					if self.owner.components.playercontroller:GetLastInputDeviceType() == "gamepad" then
						powersSorted[1].widget:SetHover()
					end

					-- TheLog.ch.UI:printf("PlayerFollowStatus: radial focus: %s", powersSorted[1].name)
				end

				-- TheLog.ch.UI:printf("angle=%1.1f r=%1.3f maxThrow=%1.3f (%1.1f%%) prefRing=%d", angle, r, maxThrow, r / maxThrow * 100, preferredRing)

				for i,v in ipairs(powersSorted) do
					if self._focus_timer == 0 then
						v.initScale = v.widget:GetScale()
					end
					if i == 1 then
						v.targetScale = 1.4
						preferredRing = v.ring
						v.widget:SendToFront()
					elseif v.ring ~= preferredRing or (usingGamepad and (i == 2 or i == 3)) then
						v.targetScale = 0.8
					else
						v.targetScale = 1
					end

					local scale = v.targetScale
					local focus_time = 0.5
					local focus_neightbor_time = 0.3
					if i == 1 and self._focus_timer <= focus_time then
						scale = easing.outExpo(self._focus_timer, v.initScale, v.targetScale - v.initScale, focus_time)
					elseif self._focus_timer <= focus_neightbor_time then
						scale = easing.outExpo(self._focus_timer, v.initScale, v.targetScale - v.initScale, focus_neightbor_time)
					end

					if scale > 0 then
						v.widget:SetScale(scale, scale)
					end
				end
			end
		else
			self:ClearFocus()

			local focus_time = 0.2
			for k,v in pairs(self.powers) do
				v.targetScale = 1
				if self._focus_timer <= focus_time and v.widget:GetScale() ~= 1 then
					if self._focus_timer == 0 then
						v.initScale = v.widget:GetScale()
					end
					local scale = easing.outExpo(self._focus_timer, v.initScale, v.targetScale - v.initScale, focus_time)
					v.widget:SetScale(scale, scale)
				elseif v.widget:GetScale() ~= v.targetScale then
					v.widget:SetScale(v.targetScale, v.targetScale)
				end
			end
		end
	end
end

function PlayerFollowStatus:IsUserInteracting()
	if not self:CanShowPowers() and self.powersstatus:IsVisible() then
		self._start_fade_timer = self.time_visible + 0.1
		return false
	end
	return self.toggleMode == true or self.isHovering == true
end

function PlayerFollowStatus:OnUpdate(dt)
	self:CheckFocus(dt)
	if self.bar_state ~= BAR_STATES.HIDDEN then
		self._start_fade_timer = self._start_fade_timer + dt
		if self.bar_state ~= BAR_STATES.FADE_OUT
			and not self:IsUserInteracting()
			and self._start_fade_timer > self.time_visible
		then
			self:FadeOut()
			self._start_fade_timer = 0
		elseif self.potionstatus:IsVisible() then
			if self.owner then
				local follow_health_bar = self.owner.follow_health_bar
				if follow_health_bar then
					follow_health_bar:Reveal()
				end
			end
		end

		if self.bar_state == BAR_STATES.IDLE then
			self._focus_timer = self._focus_timer + dt
		end
	end

	self:UpdateFocus()
	self:UpdatePosition()
end

function PlayerFollowStatus:AddPower(power, owner)
	local def = power:GetDef()
	if not def.show_in_ui then return end

	-- TODO(demo): Rename to _AddPower and assert instead.
	owner = owner or self.owner

	if owner then 
		local widget_type = PowerWidget
		if def.power_type == Power.Types.FOOD then
			widget_type = FoodWidget
		elseif def.power_type == Power.Types.SKILL then
			widget_type = SkillWidget
		end

		local existing = lume.count(self.powers) + 1
		local w = self.powersstatus:AddChild(widget_type(self.actions_size, owner, power))
		w:SetClickable(false)

		local ring = (1 + math.floor(existing / 13))
		local angle = math.rad(90 + (ring + (existing % 13)) * 24)
		self.powers[def.name] = {
			name = def.name,
			widget = w,
			posAngle = angle, -- final placement angle when visible, idle state
			ring = ring, -- higher value ring == larger radius
			initScale = 1,
			targetScale = 1,
		}

		-- TheLog.ch.UI:printf("PlayerFollowStatus:AddPower name=%s posAngle=%1.2f ring=%d", def.name, angle, ring)
	end
end

return PlayerFollowStatus
