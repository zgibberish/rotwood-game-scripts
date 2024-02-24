local Image = require("widgets/image")
local Equipment = require "defs.equipment"
local Text = require("widgets/text")
local Widget = require("widgets/widget")
local easing = require "util.easing"
local kassert = require "util.kassert"


local function RequireWeaponTypeKeys(t)
	for key,val in pairs(t) do
		kassert.assert_fmt(WEAPON_TYPES[key], "Invalid key for weapontype-related table (typo?): %s", key)
	end
end

RequireWeaponTypeKeys(STRINGS.UI.WEAPON_TIPS.TIP)
RequireWeaponTypeKeys(STRINGS.UI.WEAPON_TIPS.HINT)
-- Enable if you are debugging why strings aren't showing.
--~ for _,weapon_type in pairs(WEAPON_TYPES) do
--~ 	kassert.assert_fmt(STRINGS.UI.WEAPON_TIPS.TIP[weapon_type],  "Missing STRINGS.UI.WEAPON_TIPS.TIP for weapon %s.",  weapon_type)
--~ 	kassert.assert_fmt(STRINGS.UI.WEAPON_TIPS.HINT[weapon_type], "Missing STRINGS.UI.WEAPON_TIPS.HINT for weapon %s.", weapon_type)
--~ 	kassert.assert_fmt(Equipment.GetPrettyNameForWeaponType(weapon_type), "Missing STRING.NAMES for weapon %s.", weapon_type)
--~ end



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
	self.tips_title:SetText(Equipment.GetPrettyNameForWeaponType(self.weapon_type))
	self.tips_text:SetText(STRINGS.UI.WEAPON_TIPS.TIP[self.weapon_type])
	self.tips_hint:SetText(STRINGS.UI.WEAPON_TIPS.HINT[self.weapon_type])

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
