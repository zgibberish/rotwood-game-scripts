local HotkeyWidget = require "widgets.hotkeywidget"
local Image = require "widgets.image"
local Text = require "widgets.text"
local Widget = require("widgets/widget")
local easing = require "util.easing"
local Power = require "defs.powers"
local recipes = require "defs.recipes"

local PotionWidget = Class(Widget, function(self, size, owner)
	Widget._ctor(self, "PotionWidget")

	self.size = size

	self.owner = owner
	self.equipped_potion_def = owner.components.potiondrinker:GetEquippedPotionDef("POTIONS")
	if self.equipped_potion_def ~= nil then
		self.potion_power = self.owner.components.powermanager:CreatePower(Power.FindPowerByName(self.equipped_potion_def.usage_data.power))
	end


	self.equipped_tonic_def  = owner.components.potiondrinker:GetEquippedPotionDef("TONICS")
	if self.equipped_tonic_def ~= nil then
		self.tonic_power = self.owner.components.powermanager:CreatePower(Power.FindPowerByName(self.equipped_tonic_def.usage_data.power))
	end

	local potionIcon
	if self.equipped_potion_def ~= nil then
		potionIcon = self.equipped_potion_def.ui_icon
	end

	self.potion_icon = self:AddChild(Image(potionIcon))
		:SetSize(self.size, self.size)
		:LayoutBounds("left", "above")
		:Offset(0, -self.size * 0.75)

	self.text_root = self:AddChild(Widget("Text Root"))
		-- :LayoutBounds("right", "top", self.bg)
		:Offset(-9, -12)

	self.text = self.text_root:AddChild(Text(FONTFACE.DEFAULT, 40, nil, UICOLORS.LIGHT_TEXT_TITLE))
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()


	self.hotkeyWidget = self:AddChild(HotkeyWidget(Controls.Digital.USE_POTION))
		:LayoutBounds("center", "below", self.text_root)
		:Offset(7, -25)
		:Hide()


	self.inst:ListenForEvent("refreshpotiondata", function(owner)
		self:RefreshIcons(true)
		self:RefreshUses()
	end, owner)

	self.inst:ListenForEvent("potion_refilled", function()
		self:AnimateFocusGrab(2.3)
	end, owner)

	self.last_remaining_uses = nil

	self:RefreshIcons(true)
	self:RefreshUses()

	if not owner:IsLocal() then
		-- TheLog.ch.PotionWidget:printf("Starting remote update for %s EntityID %d", owner, owner.Network:GetEntityID())
		self:StartUpdating()
	end
end)

function PotionWidget:MakeTonicIcon()
	local tonicIcon  = self.equipped_tonic_def.icon

	if self.tonic_icon ~= nil then
		self.tonic_icon:SetTexture(tonicIcon)
	else
		self.tonic_icon = self.potion_icon:AddChild(Image(tonicIcon))
			:SetSize(self.size * 0.33, self.size * 0.33)
			:SetRotation(-15)
			:LayoutBounds("right", "bottom", self.potion_icon)
			:Offset(-7, 13)
	end

	local tip = ("%s\n\n<b>%s</b>\n%s"):format(
		self:GetToolTip(),
		self.equipped_tonic_def.pretty.name,
		Power.GetDescForPower(self.tonic_power)
	)

	self:SetToolTip(tip)
end

function PotionWidget:RefreshIcons(force_refresh)
	local latest_potion_def = self.owner.components.potiondrinker:GetEquippedPotionDef("POTIONS")
	local latest_tonic_def = self.owner.components.potiondrinker:GetEquippedPotionDef("TONICS")

	-- TODO: clean this code up to avoid duplication
	local needs_update = force_refresh
	if not needs_update then
		if (not self.equipped_potion_def and latest_potion_def) or (self.equipped_potion_def and not latest_potion_def) then
			needs_update = true
		elseif self.equipped_potion_def ~= latest_potion_def then
			needs_update = true
		elseif (not self.equipped_tonic_def and latest_tonic_def) or (self.equipped_tonic_def and not latest_tonic_def) then
			needs_update = true
		elseif self.equipped_tonic_def ~= latest_tonic_def then
			needs_update = true
		end
	end

	if not needs_update then
		return
	end

	TheLog.ch.PotionWidget:printf("Updated potion widget for player %s", self.owner)

	self.equipped_potion_def = latest_potion_def
	self.equipped_tonic_def  = latest_tonic_def

	if self.equipped_potion_def ~= nil then
		self.potion_power = self.owner.components.powermanager:CreatePower(Power.FindPowerByName(self.equipped_potion_def.usage_data.power))

		local potionIcon = self.equipped_potion_def.ui_icon
		self.potion_icon:SetTexture(potionIcon)
		local cost = recipes.ForSlot.PRICE.potion_refill.ingredients.konjur
		local tip = ("%s\n\n<b>%s</b>\n%s"):format(
			STRINGS.UI.UNITFRAME.POTION_TOOLTIP:format(cost),
			self.equipped_potion_def.pretty.name,
			Power.GetDescForPower(self.potion_power)
		)
		self:SetToolTip(tip)
	else
		self.potion_power = nil
		self.potion_icon:SetTexture()
		self:SetToolTip("")
	end

	if self.equipped_tonic_def ~= nil then
		self.tonic_power = self.owner.components.powermanager:CreatePower(Power.FindPowerByName(self.equipped_tonic_def.usage_data.power))
		self:MakeTonicIcon()
	else
		self.tonic_power = nil
	end
end

function PotionWidget:RefreshUses()
	local potiondrinker = self.owner.components.potiondrinker
	local uses = potiondrinker:GetRemainingPotionUses()
	local max = potiondrinker:GetMaxUses()

	if self.last_remaining_uses and self.last_remaining_uses == uses then
		return
	end
	self.last_remaining_uses = uses

	self.text:SetText(uses)

	-- TODO: there is a little chunk in the 'bg' element which has space for this number, but it's baked into the entire BG. If we're hiding the number, we should split out that chunk and hide it too.
	if max == 1 then
		self.text:Hide()
	else
		self.text:Show()
	end

	if uses <= 0 then
		self.text:SetGlyphColor(155/255, 80/255, 80/255, 1)
		self.potion_icon:SetMultColor(1, 1, 1, 0.4)
	else
		self.text:SetGlyphColor(216/255, 206/255, 163/255, 1)
		self.potion_icon:SetMultColor(1, 1, 1, 1)
	end
end

function PotionWidget:AnimateFocusGrab(duration)
	if self.is_animating then
		return
	end
	self.is_animating = true

	self:ScaleTo(1, 1.4, duration * 0.05, easing.inOutQuad, function()
		self:ScaleTo(1.4, 1, duration * 0.2, easing.inBack)
	end)

	local x, y = self:GetPos()
	self:MoveTo(x, y + 55, duration * 0.2, easing.inOutQuad, function()
		self:MoveTo(x, y, duration * 0.8, easing.outElastic, function()
			self.is_animating = nil
		end)
	end)
end

function PotionWidget:ABOVE_HEAD()
	self:BOTTOM_LEFT()
	-- Don't show on the main hud to reduce noise, but show in this temporary
	-- mode.
	-- self.hotkeyWidget:Show()
end

function PotionWidget:TOP_LEFT()
	self.potion_icon:LayoutBounds("center", "center")
	self.text_root:LayoutBounds("right", "bottom")
		:Offset(-6, 5)
	self.hotkeyWidget:LayoutBounds("center", "above", self.text_root)
		:Offset(7, 20)
	self.potion_icon:SendToFront()
end

function PotionWidget:TOP_RIGHT()
	self.potion_icon:LayoutBounds("center", "center")
		:Offset(15, 0)
	self.text_root:LayoutBounds("left", "bottom")
		:Offset(4, 3)
	self.hotkeyWidget:LayoutBounds("center", "above", self.text_root)
		:Offset(7, 20)
	self.potion_icon:SendToFront()
end

function PotionWidget:BOTTOM_LEFT()
	self.potion_icon:LayoutBounds("center", "center")
	self.text_root:LayoutBounds("right", "top")
		:Offset(-6, -5)
	self.hotkeyWidget:LayoutBounds("center", "below", self.text_root)
		:Offset(7, -20)
	self.potion_icon:SendToFront()
end

function PotionWidget:BOTTOM_RIGHT()
	self.potion_icon:LayoutBounds("center", "center")
		:Offset(15, 0)
	self.text_root:LayoutBounds("left", "top")
		:Offset(6, -5)
	self.hotkeyWidget:LayoutBounds("center", "below", self.text_root)
		:Offset(7, -20)
	self.potion_icon:SendToFront()
end

-- for remote client updates only; local clients are entity event-driven via refreshpotiondata
function PotionWidget:OnUpdate(dt)
	if not self.owner:IsValid() then
		self:StopUpdating()
		return
	end

	self:RefreshIcons()
	self:RefreshUses()
end

return PotionWidget
