local Widget = require("widgets/widget")
local Text = require("widgets/text")
local Image = require("widgets/image")
local lume = require("util/lume")
local Panel = require "widgets.panel"
local Weight = require "components/weight"
local UIAnim = require "widgets/uianim"

------------------------------------------------------------------------------------

local TotalWeightWidget = Class(Widget, function(self, player, scale)
	Widget._ctor(self, "TotalWeightWidget")

	self.player = player

	self.current = 0
	self.scalevalue = scale or 1

	self.scale_container = self:AddChild(Widget("Scale Container"))
	self.scale = self.scale_container:AddChild(UIAnim())
		:ScaleTo(1 * self.scalevalue, 0.6 * self.scalevalue, 0)
	local scale_animstate = self.scale:GetAnimState()
	scale_animstate:SetBank("weight_thermometer")
	scale_animstate:SetBuild("weight_thermometer")

	local current = player.components.weight:GetCurrent()
	scale_animstate:PlayAnimation(current)
	self.current = current

	self:UpdateTooltip(self.current)

	self.preview = self.scale_container:AddChild(UIAnim())
		:ScaleTo(1 * self.scalevalue, 0.6 * self.scalevalue, 0)
		:TintTo({1, 1, 1, 1}, { 1, 1, 1, 0.3}, 0)
	local preview_animstate = self.preview:GetAnimState()
	preview_animstate:SetBank("weight_thermometer")
	preview_animstate:SetBuild("weight_thermometer")

	-- The preview will only have a ghosted version of an arrow, so hide all the extras.
	preview_animstate:HideSymbol("border_untex")
	preview_animstate:HideSymbol("bluebox_untex")
	preview_animstate:PlayAnimation("0")
	self.preview:Hide() -- Show it later while previewing

	self.weight_heavy_icon = self:AddChild(Image("images/icons_ftf/stat_weight.tex"))
		:SetScale(0.9)
		:SetMultColor(UICOLORS.DARK_TEXT)
		:LayoutBounds("center", "above", self.scale_container)
		:Offset(0, 170)

	self.weight_light_icon = self:AddChild(Image("images/icons_ftf/stat_weight.tex"))
		:SetScale(0.5)
		:SetMultColor(UICOLORS.DARK_TEXT)
		:LayoutBounds("center", "below", self.scale_container)
		:Offset(0, -185)
end)

function TotalWeightWidget:UpdateByListOfWeights(weights)
	local total = Weight.SumWeights(weights)
	self:UpdateMeter(total)
	self:UpdateTooltip(total, false)
end

function TotalWeightWidget:PreviewByListOfWeights(weights)
	local total = Weight.SumWeights(weights)
	self:ShowPreview(total)
	self:UpdateTooltip(total, true)
end

function TotalWeightWidget:UpdateMeter(weightnum)
	if self.current == weightnum then
		return
	end

	local suffix = weightnum > self.current and "_u" or "_d"

	self.scale:GetAnimState():PlayAnimation(weightnum..suffix)
	self.current = weightnum

	self.preview:Hide()
end

function TotalWeightWidget:UpdateTooltip(weightnum, preview)
	local status = Weight.ComputeStatus(weightnum)
	local tooltip
	if preview then
		if status == Weight.Status.s.Light then
			tooltip = STRINGS.UI.INVENTORYSCREEN.WEIGHT_TOOLTIP_PREVIEW_LIGHT
		elseif status == Weight.Status.s.Heavy then
			tooltip = STRINGS.UI.INVENTORYSCREEN.WEIGHT_TOOLTIP_PREVIEW_HEAVY
		else
			tooltip = STRINGS.UI.INVENTORYSCREEN.WEIGHT_TOOLTIP_PREVIEW_MEDIUM
		end
	else
		if status == Weight.Status.s.Light then
			tooltip = STRINGS.UI.INVENTORYSCREEN.WEIGHT_TOOLTIP_LIGHT
		elseif status == Weight.Status.s.Heavy then
			tooltip = STRINGS.UI.INVENTORYSCREEN.WEIGHT_TOOLTIP_HEAVY
		else
			tooltip = STRINGS.UI.INVENTORYSCREEN.WEIGHT_TOOLTIP_MEDIUM
		end
	end
	dbassert(tooltip, "Failed to get weight tooltip")

	self:SetToolTip(tooltip)
end

function TotalWeightWidget:ShowPreview(weightnum)
	if self.current == weightnum then
		self.preview:Hide()
		return
	end

	self.preview:Show()
	self.preview:GetAnimState():PlayAnimation(weightnum)
end

function TotalWeightWidget:HidePreview()
	self.preview:Hide()
end

return TotalWeightWidget
