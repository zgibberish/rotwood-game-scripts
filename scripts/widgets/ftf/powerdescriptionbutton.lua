local Image = require("widgets/image")
local slotutil = require "defs.slotutil"
local Clickable = require("widgets/clickable")
local Power = require "defs.powers"
local PowerIconWidget = require("widgets/powericonwidget")
local PriceWidget = require "widgets.pricewidget"
local RoomBonusButtonTitle = require("widgets/ftf/roombonusbuttontitle")
local SkillIconWidget = require("widgets/skilliconwidget")
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local easing = require "util.easing"


--- Common base for displaying a power and its description in a clickable button.
--
-- Doesn't have any player-specific functionality or screen logic. Just
-- displays a power and its information.
local PowerDescriptionButton = Class(Clickable, function(self)
    Clickable._ctor(self)

    -- Set default size
    self.scale = 1
    self.width = 901 * self.scale
    self.height = 498 * self.scale
    self.padding = 35 * HACK_FOR_4K
    self.iconScale = self.scale * 1.4
		self.skillScale = self.scale * 1.2
		self.powerScale = self.scale * 1.4
    self.shadowScale = self.scale * 0.9

    -- Setup default scale
    self.focus_scale =  {1.03, 1.03, 1.03} -- How big the entire widget gets on focus
    self.normal_scale = {1, 1, 1}

    -- Animation tuning for hovering one of the buttons:
    self.iconFocusScale = 1 -- How big the icon itself gets on focus
    self.shadowFocusScaleModifier = 1 -- How much bigger than the iconFocusScale set does the shadow get?
	self.liftReleaseTime = 0.25 -- How long does it take to lift/release the icon on focus
	self.liftReleaseOvershootPercent = 0.05 -- When lifting/releasing the icon, how much % should we overshoot the size before settling back to normal?
    self.shadowFocusOffset = 3 -- Move the shadow Left/Right and Up/Right under the icon on focus
    self.shadowNormalAlpha = 0.5 -- Fade the shadow under the icon on focus
    self.shadowFocusAlpha = 0.3 -- Fade the shadow under the icon on focus

	self.iconSelectedTint = UICOLORS.WHITE
	self.iconFocusedTint = { 0.9, 0.9, 0.9, 1.0 }
	self.iconUnfocusedTint = { 0.9, 0.9, 0.9, 1.0 }
	-- Go transparent so user focuses on the power they picked.
	self.iconDeselectedTint = WEBCOLORS.TRANSPARENT_BLACK

	-- self.skinParticleSystem = self:AddChild(ParticleSystemWidget())
	-- self.skinParticleSystem:LoadParticlesParams("lucky_drop")
	-- self.skinParticleSystem:SetScale(0.66, 0.66)
	-- self.skinParticleSystem:Hide()

	self.image = self:AddChild(Image("images/ui_ftf_relic_selection/relic_bg_blank.tex"))
		:SetSize(self.width, self.height)

    self.icon = self:AddChild(PowerIconWidget())
		:SetScale(self.iconScale)

    -- Add bg line frame to indicate focus
    self.frame = self.image:AddChild(Image("images/ui_ftf_relic_selection/relic_selected_check.tex"))
		:LayoutBounds("center", "center", self.image)
		:SetScale(self.scale)
		:Offset(23 * HACK_FOR_4K, -5 * HACK_FOR_4K)
		-- :SendToFront()
		:Hide()

    -- Add text contents
    self.textContainer = self.image:AddChild(Widget())

    --RBS
    self.title = self.image:AddChild(RoomBonusButtonTitle(self, "images/ui_ftf_relic_selection/relic_nameornament.tex"))

	self.description = self.textContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(HexToRGB(0xB28C77FF))
		:SetHAlign(ANCHOR_MIDDLE)
		-- :OverrideLineHeight(FONTSIZE.ROOMBONUS_TEXT * 0.9)
		:EnableWordWrap(true)
		:SetRegionSize(self.width * 0.6, 326)
		:SetVAlign(ANCHOR_TOP)
		:ShrinkToFitRegion(true)

	-- Ornament at the bottom
	self.bottomOrnament = self.image:AddChild(Image("images/ui_ftf_relic_selection/relic_bg_bottom_ornament.tex"))
		:SetScale(self.scale)
		--Laid out after laying out text+description
end)

function PowerDescriptionButton:OnGainFocus()
	PowerDescriptionButton._base.OnGainFocus(self)
	if not self.frame then
		-- ImageButton cycles focus in ctor.
		return
	end

	self.frame:AlphaTo(1, 0.15, easing.outQuad)
	self:LiftIcon()

	self:AnimateFloating() -- TODO(jambell): shadow doesn't animate
	self:DoGainFocusPresentation()
end

function PowerDescriptionButton:OnLoseFocus()
	PowerDescriptionButton._base.OnLoseFocus(self)
	if not self.frame then
		return
	end

	self.frame:AlphaTo(0, 0.15, easing.outQuad, function()
		self.frame:Hide()
	end)
	self:DoLoseFocusPresentation()
	self:ReleaseIcon()
	self:StopAnimateFloating() -- TODO(jambell): shadow doesn't animate
end


-- Make the button look like the "focused/picked" state, but don't respond to
-- clicks. Converts to a static widget instead of a button.
function PowerDescriptionButton:SetUnclickableAsFocused()
	self:GainFocus()
	return self:SetUnclickable()
end
-- Convert to a static widget instead of a button.
function PowerDescriptionButton:SetUnclickable()
	local function noop() end
	self.OnGainFocus = noop
	self.OnLoseFocus = noop
	self:Select()
	self:SetNavFocusable(false)
	return self
end

function PowerDescriptionButton:SetPowerToolTip(btn_idx, num_buttons, is_lucky)
	assert(self.power, "Call SetPower first.")
	assert(btn_idx <= num_buttons)

	local def = self.power:GetDef()
	local tooltip = slotutil.BuildToolTip(def, { is_lucky = is_lucky, })

	-- TODO: Should we unconditionally set this? Maybe that prevents a weird
	-- tooltip from showing from some parent?
	self:ShowToolTipOnFocus(true)

	if tooltip then
		self:SetToolTip(tooltip)
		self:SetToolTipLayoutFn(function(w, tooltip_widget)
			tooltip_widget:LayoutBounds("center", "below", w)
				:Offset(0, -40)
		end)
	end
	return self
end

function PowerDescriptionButton:AddPriceDisplay(player)
	assert(player)
	self.price_widget = self.image:AddChild(PriceWidget(player))
		:SetTheme_Dark()
		:SetScale(1.4)
	return self
end

function PowerDescriptionButton:SetPrice(price, is_free)
	assert(self.price_widget, "Call AddPriceDisplay!")

	self.price_widget:SetPrice(price)
	if is_free then
		self.price_widget:Hide()
	else
		self.price_widget:LayoutBounds("center", "bottom", self.image)
			:Offset(125, 75)
	end
end

function PowerDescriptionButton:SetPower(power, islucky, can_select)
	self.power = power
	
	if not power then
		return self
	end

	local def = self.power:GetDef()

	self.can_select = can_select

	if def.power_type == Power.Types.SKILL then
		self.iconScale = self.skillScale
		self.icon:Remove()
		self.icon = self.image:AddChild(SkillIconWidget())
			:SetScale(self.iconScale)
		self.icon:SetSkill(self.power)
		-- Hide shadow for skills
		self.shadowNormalAlpha = 0
		self.shadowFocusAlpha = 0
	else
		self.icon:SetPower(self.power)
	end

	-- Update text
	self.title:SetTitle(string.upper(def.pretty.name))

	-- self.title:SetHAlign(ANCHOR_MIDDLE)
	self.description:SetText(Power.GetDescForPower(self.power))

	-- Layout icon
	self.icon:LayoutBounds("center", "top", self.image)
		:Offset(-450, self.height * 0.1)

	self.shadow = self.image:AddChild(Image("images/ui_ftf_relic_selection/relic_shadow.tex"))
		:SetScale(self.scale)
		:LayoutBounds("center", "center", self.icon)
		:Offset(-4 * HACK_FOR_4K, -20 * HACK_FOR_4K)---self.height * .125)
		:AlphaTo(self.shadowNormalAlpha, 0)

	self.icon:SendToFront()

	if islucky then
		self.title:SetMultColor(HexToRGB(0x8fd95dff))
		-- self.frame:SetMultColor(HexToRGB(0x387e4fff))
		-- self.skinParticleSystem:Show()
		-- self.skinParticleSystem:LayoutBounds("center", "center", self.icon)
	end

	local titleXOffset = 130
	-- Position text elements on the button
	self.title:LayoutBounds("center", "center", self.image)
		:Offset(titleXOffset, 160)
	self.description:LayoutBounds("center", "below", self.title)
		:Offset(0, -10 * HACK_FOR_4K)

	-- If the description is really long, hide the bottom ornament. Otherwise, lay it out in the same spot every time.
	local descx,descy = self.description:GetSize()
	if descy > 140 * HACK_FOR_4K then
		self.bottomOrnament:Hide()
	else
		self.bottomOrnament:LayoutBounds("center", "center", self.image)
			:Offset(titleXOffset, -100 * HACK_FOR_4K)
	end

	-- TODO: We no longer have a player ref here. (powermanager isn't synced for remote players)
	if not self.can_select then
		self:SetSaturation(0)
		self.image:SetSaturation(0)
		self:SetToolTip("Cannot pick a power you already have.")
	end

	-- Store the post-arranged position of these elements so that we can make sure we return to it after lifting/releasing the button.
	local iconX, iconY = self.icon:GetPosition()
	local shadowX, shadowY = self.shadow:GetPosition()
	self.iconPos = { x = iconX, y = iconY }
	self.shadowPos = { x = shadowX, y = shadowY }

	return self
end

function PowerDescriptionButton:GetPower()
	return self.power
end

function PowerDescriptionButton:LiftIcon()
	self.icon:ScaleToWithOvershoot(self.iconScale * self.iconFocusScale, self.liftReleaseOvershootPercent, self.liftReleaseTime)
	self.shadow:ScaleToWithOvershoot(self.scale * self.iconFocusScale * self.shadowFocusScaleModifier, self.liftReleaseOvershootPercent * 0.5, self.liftReleaseTime)

	self.shadow:OffsetTo(-self.shadowFocusOffset, -self.shadowFocusOffset, 0.1, easing.inOutQuad)
	self.shadow:AlphaTo(self.shadowFocusAlpha, self.liftReleaseTime, easing.outQuad)
end

function PowerDescriptionButton:ReleaseIcon()
	self.icon:ScaleTo(self.iconScale * self.iconFocusScale, self.iconScale, self.liftReleaseTime, easing.outQuad)
	self.shadow:ScaleTo(self.scale * self.iconFocusScale * self.shadowFocusScaleModifier, self.scale, self.liftReleaseTime, easing.outQuad)
	self.shadow:AlphaTo(self.shadowNormalAlpha, self.liftReleaseTime, easing.outQuad)

	-- If our object has moved at all during the lifted state, move back to its original position.
	local iconX, iconY = self.icon:GetPosition()
	local shadowX, shadowY = self.shadow:GetPosition()
	local iconDiffX = self.iconPos.x - iconX
	local iconDiffY = self.iconPos.y - iconY
	local shadowDiffX = self.shadowPos.x - shadowX
	local shadowDiffY = self.shadowPos.y - shadowY

	self.icon:OffsetTo(iconDiffX, iconDiffY, self.liftReleaseTime, easing.inOutQuad)
	self.shadow:OffsetTo(shadowDiffX, shadowDiffY, self.liftReleaseTime, easing.outQuad)
end

function PowerDescriptionButton:DoGainFocusPresentation()
	self.title:AlphaTo(self.iconFocusedTint[4], 0.2, easing.outQuad)
	self.description:AlphaTo(self.iconFocusedTint[4], 0.2, easing.outQuad)
	self.frame:AlphaTo(1, 0.2, easing.outQuad)
	self.icon:TintTo(nil, self.iconFocusedTint, 0.2, easing.outQuad)
end

function PowerDescriptionButton:DoLoseFocusPresentation()
	self.title:AlphaTo(self.iconUnfocusedTint[4], 0.2, easing.outQuad)
	self.description:AlphaTo(self.iconUnfocusedTint[4], 0.2, easing.outQuad)
	self.icon:TintTo(nil, self.iconUnfocusedTint, 0.2, easing.outQuad)
	self.frame:AlphaTo(self.picked and 1 or 0, 0.2, easing.outQuad)
end

function PowerDescriptionButton:DoSelectedPresentation()
	self.title:AlphaTo(self.iconSelectedTint[4], 0.2, easing.outQuad)
	self.description:AlphaTo(self.iconSelectedTint[4], 0.2, easing.outQuad)
	self.icon:TintTo(nil, self.iconSelectedTint, 0.2, easing.outQuad)
	self.frame:AlphaTo(1, 0.2, easing.outQuad)
end

function PowerDescriptionButton:DoUnselectedPresentation()
	self.frame:AlphaTo(0, 0.2, easing.outQuad)
	-- Picked and disabled means we're not allowing interaction, but not
	-- that we're not available. So don't grey us out.
	self.icon:TintTo(nil, self.iconSelectedTint, 0.2, easing.outQuad)
end

function PowerDescriptionButton:DoDisablePresentation(disabled_but_picked)
	if disabled_but_picked then
		-- Picked and disabled means we're not allowing interaction, but not
		-- that we're not available. So don't grey us out.
		self.icon:TintTo(nil, self.iconSelectedTint, 0.2, easing.outQuad)
	else
		-- self:SetScaleOnFocus(false)
		self:TintTo(nil, self.iconDeselectedTint, 0.5, easing.outExpo)
	end
end

function PowerDescriptionButton:PrepareAnimation()

	return self
end

function PowerDescriptionButton:AnimateIn()

	return self
end

function PowerDescriptionButton:AnimateFloating(speed, amplitude)
	speed = speed or 0.3
	speed = speed * 4
	amplitude = amplitude or 5
	local widgetX, widgetY = self.icon:GetPosition()
	local shadowX, shadowY = self.shadow:GetPosition()

	-- Store the current positions so we can force them back to original position when we stop animating.
	self.iconReturnPosX = widgetX
	self.shadowReturnPosX = shadowX
	self.iconReturnPosY = widgetY
	self.shadowReturnPosY = shadowY
	self.updater = self:RunUpdater(
		Updater.Loop({
			Updater.Ease(function(v) self.icon:SetPosition(widgetX, v) end, widgetY, widgetY + amplitude, speed * 0.8, easing.outQuad),

			Updater.Wait(speed * 0.5),

			Updater.Ease(function(v) self.icon:SetPosition(widgetX, v) end, widgetY + amplitude, widgetY - amplitude * 1.2, speed * 1.8, easing.inOutQuad),

			Updater.Wait(speed * 0.2),

			Updater.Ease(function(v) self.icon:SetPosition(widgetX, v) end, widgetY - amplitude * 1.2, widgetY + amplitude * 1.3, speed * 1.6, easing.inOutQuad),

			Updater.Wait(speed * 0.4),

			Updater.Ease(function(v) self.icon:SetPosition(widgetX, v) end, widgetY + amplitude * 1.3, widgetY - amplitude, speed * 1.7, easing.inOutQuad),

			Updater.Wait(speed * 0.3),

			Updater.Ease(function(v) self.icon:SetPosition(widgetX, v) end, widgetY - amplitude, widgetY, speed * 0.8, easing.inQuad),
		})
	)
	return self
end

function PowerDescriptionButton:StopAnimateFloating()
	if self.updater then
		self:StopUpdater(self.updater)
	end
end

return PowerDescriptionButton
