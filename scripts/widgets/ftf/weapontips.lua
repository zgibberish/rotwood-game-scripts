local Text = require("widgets/text")
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local easing = require "util.easing"

local WEAPON_TYPE_TO_TITLE =
{
	[WEAPON_TYPES.HAMMER] = "Hammer",
	[WEAPON_TYPES.POLEARM] = "Spear",
	[WEAPON_TYPES.CANNON] = "Cannon",
	[WEAPON_TYPES.SHOTPUT] = "Striker",
}

local WEAPON_TYPE_TO_TIPS =
{
	[WEAPON_TYPES.HAMMER] = [[
<p bind='Controls.Digital.ATTACK_LIGHT' color=LIGHT_TEXT> Light Attack
<p bind='Controls.Digital.ATTACK_HEAVY' color=LIGHT_TEXT> Heavy Attack
<p bind='Controls.Digital.DODGE' color=LIGHT_TEXT> Dodge

<#BLUE>Focus Hit:</BLUE>
• Hit multiple enemies with one swing
• Fully charge a <#RED>Heavy Attack</RED> combo ender
• Fully charge a <#RED>Golf Swing</RED> (<p bind='Controls.Digital.DODGE' color=LIGHT_TEXT>  <p img='images/ui_ftf/arrow_right.tex' color=0 scale=0.4>  Back + <p bind='Controls.Digital.ATTACK_HEAVY' color=LIGHT_TEXT>)
]],
	[WEAPON_TYPES.POLEARM] = [[
<p bind='Controls.Digital.ATTACK_LIGHT' color=LIGHT_TEXT> Light Attack
<p bind='Controls.Digital.ATTACK_HEAVY' color=LIGHT_TEXT> Heavy Attack
<p bind='Controls.Digital.DODGE' color=LIGHT_TEXT> Dodge

<#BLUE>Focus Hit:</BLUE>
• Hit an enemy with the tip of your spear
• Hit multiple enemies with the <#RED>Spinning Drill</RED> (<p bind='Controls.Digital.DODGE' color=LIGHT_TEXT>  <p img='images/ui_ftf/arrow_right.tex' color=0 scale=0.4>  <p bind='Controls.Digital.ATTACK_LIGHT' color=LIGHT_TEXT>)
]],
	[WEAPON_TYPES.CANNON] = [[
<p bind='Controls.Digital.ATTACK_LIGHT' color=LIGHT_TEXT> Shoot
<p bind='Controls.Digital.ATTACK_HEAVY' color=LIGHT_TEXT> Shotgun Blast (Dodge)
<p bind='Controls.Digital.DODGE' color=LIGHT_TEXT> Plant Cannon
<p bind='Controls.Digital.DODGE' color=LIGHT_TEXT>  <p img='images/ui_ftf/arrow_right.tex' color=0 scale=0.4>  <p bind='Controls.Digital.DODGE' color=LIGHT_TEXT> <#RED>Reload</> (timing affects speed)
<p bind='Controls.Digital.DODGE' color=LIGHT_TEXT>  <p img='images/ui_ftf/arrow_right.tex' color=0 scale=0.4>  <p bind='Controls.Digital.ATTACK_HEAVY' color=LIGHT_TEXT> <#RED>Mortar Volley</> (timing affects speed)

Shooting a <#RED>Mortar Volley</> with more ammo may cause you to be <#RED>Knocked Down</RED>.

Your <#RED>Heavy Attack</> is also a <#RED>Dodge</>. It has <#RED>Invincibility Frames</> and activates any <#RED>Powers</> that trigger on <#RED>Dodge</>.

<#BLUE>Focus Hit:</BLUE>
• Last three shots of your clip
]],
	[WEAPON_TYPES.SHOTPUT] = [[
<p bind='Controls.Digital.ATTACK_LIGHT' color=LIGHT_TEXT> Punch
<p bind='Controls.Digital.ATTACK_HEAVY' color=LIGHT_TEXT> Throw
<p bind='Controls.Digital.DODGE' color=LIGHT_TEXT> Dodge

<#BLUE>Focus Hit:</BLUE>
• Hit an airborne <#RED>Striker</>
• Throw a <#RED>Striker</> immediately after catching it
]],
}

local WEAPON_TYPE_TO_HINT =
{
	[WEAPON_TYPES.HAMMER] = "Discover more combos by combining <p bind='Controls.Digital.ATTACK_LIGHT' color=LIGHT_TEXT>, <p bind='Controls.Digital.ATTACK_HEAVY' color=LIGHT_TEXT> and <p bind='Controls.Digital.DODGE' color=LIGHT_TEXT>",
	[WEAPON_TYPES.POLEARM] = "Discover more combos by combining <p bind='Controls.Digital.ATTACK_LIGHT' color=LIGHT_TEXT>, <p bind='Controls.Digital.ATTACK_HEAVY' color=LIGHT_TEXT> and <p bind='Controls.Digital.DODGE' color=LIGHT_TEXT>",
	[WEAPON_TYPES.CANNON] = "Discover more combos by combining <p bind='Controls.Digital.ATTACK_LIGHT' color=LIGHT_TEXT>, <p bind='Controls.Digital.ATTACK_HEAVY' color=LIGHT_TEXT> and <p bind='Controls.Digital.DODGE' color=LIGHT_TEXT>",
	[WEAPON_TYPES.SHOTPUT] = "Discover more combos by combining <p bind='Controls.Digital.ATTACK_LIGHT' color=LIGHT_TEXT>, <p bind='Controls.Digital.ATTACK_HEAVY' color=LIGHT_TEXT> and <p bind='Controls.Digital.DODGE' color=LIGHT_TEXT>",
}

local WeaponTips = Class(Widget, function(self)
	Widget._ctor(self, "WeaponTips")

	self.max_text_width = 750

	self.bg = self:AddChild(Image("images/ui_ftf_research/research_banner.tex"))
		:SetMultColor(UICOLORS.BACKGROUND_DARK)
		:SetMultColorAlpha(0.8)

	self.text_container = self:AddChild(Widget())
	self.tips_title = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT*1.2, "", UICOLORS.LIGHT_TEXT_TITLE))
		:LeftAlign()
		:SetAutoSize(self.max_text_width)

	self.tips_text = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT, "", UICOLORS.LIGHT_TEXT))
		:OverrideLineHeight(FONTSIZE.SCREEN_TEXT*1.15)
		:LeftAlign()
		:SetAutoSize(self.max_text_width)

	self.tips_hint = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT, "", UICOLORS.LIGHT_TEXT))
		:LeftAlign()
		:SetAutoSize(self.max_text_width)
end)

function WeaponTips:SetWeaponType(weapon_type, force)
	if not force and self.weapon_type == weapon_type then
		return self
	end

	self.weapon_type = weapon_type
	self.tips_title:SetText(WEAPON_TYPE_TO_TITLE[self.weapon_type])
	self.tips_text:SetText(WEAPON_TYPE_TO_TIPS[self.weapon_type])
	self.tips_hint:SetText(WEAPON_TYPE_TO_HINT[self.weapon_type])

	self:Layout()
	return self
end

function WeaponTips:AnimateIn()
	-- TODO: Add Presentation
	self:Show()
	self:SetMultColorAlpha(0)
		:AlphaTo(1, 0.33, easing.outQuad)

	return self
end

function WeaponTips:AnimateOut()
	-- TODO: Add Presentation
	self:SetMultColorAlpha(1)
		:AlphaTo(0, 0.33, easing.outQuad, function()
			self:Hide()
		end)

	return self
end

function WeaponTips:OnInputModeChanged(old_device_type, new_device_type)
	self.tips_title:RefreshText()
	self.tips_text:RefreshText()
	self.tips_hint:RefreshText()
	self:Layout()
end

function WeaponTips:SetOnLayoutFn(fn)
	self.on_layout_fn = fn
	return self
end

function WeaponTips:Layout()

	self.tips_text:LayoutBounds("left", "below", self.tips_title)
		:Offset(0, -10)
	self.tips_hint:LayoutBounds("left", "below", self.tips_text)
		:Offset(0, -20)

	local w, h = self.text_container:GetSize()
	local padding_w, padding_h = 50, 30
	self.bg:SetSize(w + padding_w*2, h + padding_h*2.4)
	self.text_container:LayoutBounds("left", "top", self.bg)
		:Offset(padding_w, -padding_h)

	if self.on_layout_fn then self.on_layout_fn() end

	return self
end

return WeaponTips