local Image = require "widgets.image"
local AnimPuppet = require "widgets.animpuppet"
local Widget = require "widgets.widget"
local easing = require "util.easing"

local ARROW_SCALE = 0.70
local ARROW_SCALE_LARGE = 0.56 -- when target:HasTag("large") or target:HasTag("giant")
local ARROW_SIZE_BUFFER = 120
local ARROW_ROTATE_TIME = 0.08 -- time to rotate arrow when it changes orientation
local MAX_SCREEN_X = RES_X / 2
local MAX_SCREEN_Y = RES_Y / 2
local MAX_SCREEN_X_SAFE = MAX_SCREEN_X - ARROW_SIZE_BUFFER
local MAX_SCREEN_Y_SAFE = MAX_SCREEN_Y - ARROW_SIZE_BUFFER
local MOVE_SNAP_LIFETIME = 0.1 -- snap movements within this elapsed time; outside of this, MoveTo/RotateTo/ScaleTo will be used with 
local MOVE_TIME = 0.2 -- time to move from current to new position; acts like a damper since this tracks the entity movement
local PIP_H_POS_X = 192 -- offset used when arrow is pointing left/right
local PIP_V_POS_Y = 192 -- offset used when arrow is pointing down
local PIP_SCALE = 1.1
local PIP_SCALE_LARGE = 1.3 -- when target:HasTag("large") or target:HasTag("giant")
local PIP_SCALE_IN_TIME = 0.4
local PIP_SCALE_OUT_TIME = 0.2
local PUPPET_SCALE = 0.43 -- define tuning.lua TUNING.<enemyname>.custom_puppet_scale to override
local PUPPET_SCALE_LARGE = 0.22 -- when target:HasTag("large") or target:HasTag("giant")
local PUPPET_POS_Y = 84 -- offset used to adjust puppet in the PIP "window"
local PUPPET_HEAD_OFFSET_Y = 64 -- hacky offset to puppets with a separate head, like NPCs
local SCALE_MIN = 0.001 -- use non-zero value in case anything needs to transform into this


-- displays an arrow in screen space that indicates an entity is not seen by the camera at its world space location
-- the position the arrow resides in is based on the proxy for this unseen entity
-- offscreen_options:
--   hideBackground (bool) : hides the background frame + mask.  Puppet anchors, offsets, etc. may be affected
--   pipCustomWidget (widget) : bypass default PIP + animpuppet widget (UI animstate)
--   pipScale (number) : sets scale for the default PIP
--   puppetAnchorH (string) : defaults to "center"
--   puppetAnchorV (string) : defaults to "bottom"
--   puppetOffset (Vector2) : screen space coordinates
--   puppetScale (number)
--   urgent (bool) : explicitly set presentation style (defaults to true)
local OffScreenIndicatorWidget = Class(Widget, function(self, offscreen_options)
	Widget._ctor(self, "OffScreenIndicator")
	offscreen_options = offscreen_options or {}

	self.pipScale = offscreen_options.pipScale or (offscreen_options.pipCustomWidget and 1 or PIP_SCALE)
	
	-- puppetScale has a series of overrides when the target entity is set
	self.puppetScale = offscreen_options.puppetScale
	self.puppetOffset = offscreen_options.puppetOffset

	if offscreen_options.pipCustomWidget then
		self.pip = self:AddChild(Widget())
			:SetAnchors("center", "center")
		self.pipCustomWidget = self.pip:AddChild(offscreen_options.pipCustomWidget)
			:Show() -- a bit hacky to reveal custom PIP widget by default
	else
		self.pip = self:AddChild(Widget())
			:SetScale(self.pipScale)
			:SetAnchors("center", "center")
		if not offscreen_options.hideBackground then
			self.portraitBack = self.pip:AddChild(Image("images/ui_ftf_ingame/player_portrait_mask.tex"))
				:SetMultColor(UICOLORS.BACKGROUND_OVERLAY)
			self.portraitMask = self.pip:AddChild(Image("images/ui_ftf_ingame/player_portrait_mask.tex"))
				:SetMask()
		end
		self.puppet = self.pip:AddChild(AnimPuppet())
			:SetScale(self.puppetScale or PUPPET_SCALE)
			:SetAnchors(offscreen_options.puppetAnchorH or "center", offscreen_options.puppetAnchorV or "bottom")
		if not offscreen_options.hideBackground then
			self.puppet:SetMasked()
			self.portraitBg = self.pip:AddChild(Image("images/ui_ftf_ingame/player_portrait_bg.tex"))
				:SetAddColor(UICOLORS.BACKGROUND_MID)
		end
	end

	self.arrow = self:AddChild(Image("images/ui_ftf_ingame/ui_offscreen.tex"))
		:SetScale(ARROW_SCALE)
		:SetAnchors("center", "center")

	self:SetUrgent(offscreen_options.urgent or true)
end)

function OffScreenIndicatorWidget:SetUrgent(is_urgent)
	assert(is_urgent ~= nil)
	self.should_blink = is_urgent
	local color = UICOLORS.LIGHT_TEXT
	if is_urgent then
		color = UICOLORS.OVERLAY_ATTENTION_GRAB
	end
	self.arrow:SetMultColor(color)
	return self
end

function OffScreenIndicatorWidget:ClearTargetEntity()
	self:SetTargetEntity(nil, nil)
end

function OffScreenIndicatorWidget:GetTargetEntity()
	return self.target
end

function OffScreenIndicatorWidget:SetTargetEntity(proxy, target, isVisible)
	self.proxy = proxy
	self.target = target
	if self.proxy and self.target and not isVisible then
		local x,y = self:CalculateScreenPosition(true)
		self.lifetime = 0
		self:SetPosition(x,y)

		if self.puppet then
			self.puppet:SetTarget(target)
		end

		local custom_puppet_scale
		if self.puppetScale then
			custom_puppet_scale = self.puppetScale
		elseif TUNING[target.prefab] and TUNING[target.prefab].custom_puppet_scale then
			custom_puppet_scale = TUNING[target.prefab].custom_puppet_scale
			-- TheLog.ch.UI:printf("Using custom scale for %s: %1.3f", target.prefab, custom_puppet_scale)
		end

		if target:HasTag("large") or target:HasTag("giant") then
			self.arrow:SetScale(ARROW_SCALE_LARGE)
			if self.puppet then
				self.puppet:SetScale(custom_puppet_scale or PUPPET_SCALE_LARGE)
			end
			self.pip:ScaleTo(SCALE_MIN, PIP_SCALE_LARGE, PIP_SCALE_IN_TIME, easing.outElastic)
		else
			self.arrow:SetScale(ARROW_SCALE)
			if self.puppet then
				self.puppet:SetScale(custom_puppet_scale or PUPPET_SCALE)
			end
			self.pip:ScaleTo(SCALE_MIN, self.pipScale, PIP_SCALE_IN_TIME, easing.outElastic)
		end
		if self.puppet then
			self.puppet:SetPosition(self:CalculatePuppetPosition())
		end

		self:Show()
		self:StartUpdating()
	else
		self.lifetime = 0
		if self.puppet then
			self.puppet:ClearTarget()
		end
		self.pip:ScaleTo(self.pip:GetScale(), SCALE_MIN, PIP_SCALE_OUT_TIME, easing.outExpo, function() self:Hide() end)
		self:StopUpdating()
	end

	return self
end

function OffScreenIndicatorWidget:CalculatePuppetPosition()
	dbassert(self.puppet ~= nil)
	local headPos = self.puppet:GetSymbolPosition("head")
	local footPos = self.puppet:GetSymbolPosition("foot")
	local puppetPos = self.puppetOffset or Vector2(0, PUPPET_POS_Y)
	-- puppet symbol positions are in absolute screenspace UI
	-- the widget wants the local UI position
	-- if the symbols are available, use them to try and keep the puppet centered and in-frame
	if headPos and footPos then
		local approxHeight = math.abs((headPos - footPos).y)
		if self.puppet:HasExtraPart("head") then
			approxHeight = approxHeight + PUPPET_HEAD_OFFSET_Y
		end
		local yOffset = approxHeight * ((self.target:HasTag("large") or self.target:HasTag("giant")) and 0.1 or 0.5)
		-- TheLog.ch.UI:printf("Approx Height: %1.2f, Y Offset: %1.2f", approxHeight, yOffset)
		puppetPos.y = puppetPos.y - yOffset
	end

	return puppetPos.x, puppetPos.y
end

function OffScreenIndicatorWidget:CalculateScreenPosition(snapTransforms)
	if not self.target or not self.target.entity:IsValid() then
		return
	end
	local t = self.target:GetPosition()

	local minx,miny,minz,maxx,maxy,maxz = self.target.entity:GetWorldAABB()
	local halfheight = (maxy - miny) / 2 -- center the arrow on the screen-projected AABB
	local x,y = self:CalcLocalPositionFromWorldPoint(t.x, t.y + halfheight, t.z)

	-- on the first frame, sometimes it's possible that not everything is setup and NaN
	-- values will propagate through to the renderer
	if isnan(x) or isnan(y) then
		return
	end

	-- adjust layout of widget internals based on offscreen edge
	-- weird side effect of this function but need to set this before clamping x,y to screen extents
	local rotateTime = snapTransforms and 0 or ARROW_ROTATE_TIME
	local moveTime = snapTransforms and 0 or MOVE_TIME
	if x < -MAX_SCREEN_X_SAFE then
		if y < -MAX_SCREEN_Y then
			self.arrow:RotateTo(135, rotateTime)
			self.pip:MoveTo(PIP_H_POS_X, PIP_V_POS_Y, moveTime)
		elseif y > MAX_SCREEN_Y then
			self.arrow:RotateTo(-135, rotateTime)
			self.pip:MoveTo(PIP_H_POS_X, -PIP_V_POS_Y, moveTime)
		else
			self.arrow:RotateTo(180, rotateTime)
			self.pip:MoveTo(PIP_H_POS_X, 0, moveTime)
		end
	elseif x > MAX_SCREEN_X_SAFE then
		if y < -MAX_SCREEN_Y then
			self.arrow:RotateTo(45, rotateTime)
			self.pip:MoveTo(-PIP_H_POS_X, PIP_V_POS_Y, moveTime)
		elseif y > MAX_SCREEN_Y then
			self.arrow:RotateTo(-45, rotateTime)
			self.pip:MoveTo(PIP_H_POS_X, PIP_V_POS_Y, moveTime)
		else
			self.arrow:RotateTo(0, rotateTime)
			self.pip:MoveTo(-PIP_H_POS_X, 0, moveTime)
		end
	elseif y > MAX_SCREEN_Y then
		self.arrow:SetRotation(-90)
		self.pip:SetPosition(0, -PIP_V_POS_Y)
	elseif y < -MAX_SCREEN_Y then
		self.arrow:RotateTo(90, rotateTime)
		self.pip:MoveTo(0, PIP_V_POS_Y, moveTime)
	--else
		-- don't reset rotation; causes weird flip at the last moment
	end

	x = math.clamp(x, -MAX_SCREEN_X_SAFE, MAX_SCREEN_X_SAFE)
	y = math.clamp(y, -MAX_SCREEN_Y_SAFE, MAX_SCREEN_Y_SAFE)
	return x,y
end


function OffScreenIndicatorWidget:OnUpdate(dt)
	self.lifetime = self.lifetime + dt
	local x,y = self:CalculateScreenPosition(self.lifetime < MOVE_SNAP_LIFETIME)
	if x and y then
		self:MoveTo(x,y, MOVE_TIME, easing.outExpo)
	else
		self:ClearTargetEntity()
	end

	local alpha = 1
	if self.should_blink then
		-- deliberately clip alpha to allow full opaque to stay onscreen longer
		alpha = math.clamp(1.2 + 0.8 * math.sin(4 * GetTime() * math.pi), 0, 1)
	end
	self.arrow:SetMultColorAlpha(alpha)

	if self.puppet then
		self.puppet:SetPosition(self:CalculatePuppetPosition())
	end
end

return OffScreenIndicatorWidget
