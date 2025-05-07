local Power = require "defs.powers"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local SkillIconWidget = require "widgets.skilliconwidget"
local easing = require "util.easing"

-- Displays a power widget (frame, icon, and stacks)

local SkillWidget = Class(Widget, function(self, width, owner, skill)
	Widget._ctor(self, "SkillWidget")

	self.width = width or 107

	self.owner = owner

	self.skill_widget_root = self:AddChild(Widget())

	self.skill_widget = self.skill_widget_root:AddChild(SkillIconWidget())
		:SetScaleToMatchWidth(self.width)

	self.text_root = self:AddChild(Widget())
		:LayoutBounds("right", "top", self.power_widget)
		:Offset(-12 * HACK_FOR_4K, -13 * HACK_FOR_4K)
	self.counter_text = self.text_root:AddChild(Text(FONTFACE.DEFAULT, 23 * HACK_FOR_4K, nil, UICOLORS.LIGHT_TEXT_TITLE))
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()

	self.inst:ListenForEvent("update_power", function(owner_, def)
		assert(owner_ == self.owner)
		if self.skill_def and def.name == self.skill_def.name then
			self:UpdateStacks()
			self:UpdateUI()
		end
	end, owner)

	self.inst:ListenForEvent("used_power", function(owner_, def)
		assert(owner_ == self.owner)
		if self.skill_def and def.name == self.skill_def.name then
			self:UpdateStacks()
			self:UpdateUI()
		end
	end, owner)

	-- 
	-- self.inst:ListenForEvent("power_upgraded", function(owner_, pow)
	-- 	assert(owner_ == self.owner)
	-- 	if self.skill_def and def.name == self.skill_def.name then
	-- 		self:AnimateFocusGrab(2.3)
	-- 	end
	-- end, owner)

	if skill then self:SetSkill(skill) end
end)

function SkillWidget:SetSkill(skill)
	self.skill = skill
	-- d_view(self.skill)
	self.skill_def = skill:GetDef()
	self.skill_widget:SetSkill(skill)
	self:UpdateUI()
	return self
end

function SkillWidget:UpdateUI()
	self:SetToolTip((STRINGS.UI.UNITFRAME.SKILL_TOOLTIP):format(self.skill_def.pretty.name, Power.GetDescForPower(self.skill)))
	self.skill_widget:UpdateSkill()
end

function SkillWidget:UpdateStacks()
	local skill = self.skill
	if skill and skill.counter
		and ((type(skill.counter) == "number" and skill.counter > 0)
			or (type(skill.counter) == "string" and skill.counter ~= "")) then
		self.text_root:Show()
		self.counter_text:SetText(skill.counter)
			-- HACK: For some reason, the text doesn't display from
			-- PlayerFollowStatus unless we change the colour after it becomes
			-- visible.
			:SetGlyphColor(UICOLORS.LIGHT_TEXT_TITLE)
	else
		self.text_root:Hide()
	end
end

function SkillWidget:AnimateFocusGrab(duration)
	if self.is_animating then
		return
	end
	self.is_animating = true

	self:ScaleTo(1, 1.75, duration * 0.6, easing.inOutQuad, function()
		self:ScaleTo(1.75, 1, duration * 0.4, easing.outElastic)
	end)
end

return SkillWidget