local Widget = require("widgets/widget")
local Image = require("widgets/image")
local RadialProgress = require("widgets/radialprogress")

local easing = require "util.easing"

--------------------------------------------------------------
-- An hexagon shaped widget with a progress radial to display 
-- progress on a research item or category

local ArmourResearchRadial = Class(Widget, function(self, size)
	Widget._ctor(self, "ArmourResearchRadial")

	self.size = size or 350
	self.image_size = self.size

	self.radial_color_bg = HexToRGB(0x352C4Fff)
	self.radial_fill_bg = HexToRGB(0xE0B8FFff)
	self.radial_full_bg = HexToRGB(0xFFEE70ff)
	self.radial_delta_bg = HexToRGB(0x3FCCABff)

	self.normal_color_bg = HexToRGB(0x7F54DDff)
	self.locked_color_bg = HexToRGB(0x967D71ff)
	self.full_color_bg = HexToRGB(0xFFCB27ff)

	self.normal_color_icon = HexToRGB(0xE0B8FFff)
	self.locked_color_icon = HexToRGB(0xCEB6A5ff)
	self.full_color_icon = HexToRGB(0x000000ff)

	self.shadow = self:AddChild(Image("images/ui_ftf_research/item_radial_bg.tex"))
		:SetName("Shadow")
		:SetSize(self.size, self.size)
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_MID)

	self.bg = self:AddChild(Image("images/ui_ftf_research/item_radial_mask.tex"))
		:SetName("Background")
		:SetHiddenBoundingBox(true)
		:SetSize(self.size, self.size)
		:SetMultColor(self.normal_color_bg)

	self.mask = self:AddChild(Image("images/ui_ftf_research/item_radial_mask.tex"))
		:SetName("Mask")
		:SetSize(self.size, self.size)
		:SetMask()

	self.image = self:AddChild(Image("images/global/square.tex"))
		:SetName("Image")
		:SetSize(self.image_size, self.image_size)
		:SetHiddenBoundingBox(true)
		:SetMasked()

	self.overlay = self:AddChild(Image("images/ui_ftf_research/item_radial_overlay.tex"))
		:SetName("Overlay")
		:SetSize(self.size, self.size)
		:SetHiddenBoundingBox(true)
		:SetMultColor(self.radial_color_bg)

	self.fill_back = self:AddChild(Image("images/ui_ftf_research/item_radial_fill_1.tex"))
		:SetName("Fill back")
		:SetSize(self.size, self.size)
		:SetHiddenBoundingBox(true)
		:SetMultColor(self.radial_fill_bg)
		:SetMultColorAlpha(0.1)
	self.fill_upgrade = self:AddChild(RadialProgress("images/ui_ftf_research/item_radial_fill_1.tex"))
		:SetName("Fill upgrade")
		:SetSize(self.size, self.size)
		:SetHiddenBoundingBox(true)
		:SetMultColor(UICOLORS.UPGRADE)
		:SetProgress(0)
		:PulseAlpha(0.5, 1, 0.01)
	self.fill = self:AddChild(RadialProgress("images/ui_ftf_research/item_radial_fill_1.tex"))
		:SetName("Fill")
		:SetSize(self.size, self.size)
		:SetHiddenBoundingBox(true)
		:SetMultColor(self.radial_fill_bg)
end)

function ArmourResearchRadial:SetShadowSizeOffset(size_offset)
	self.shadow:SetSize(self.size+size_offset, self.size+size_offset)
	return self
end

function ArmourResearchRadial:SetShadowColor(color)
	self.shadow:SetMultColor(color)
	return self
end

function ArmourResearchRadial:SetShadowAddColor(color)
	self.shadow:SetAddColor(color)
	return self
end

function ArmourResearchRadial:TintShadowTo(color, duration, easing_fn)
	self.shadow:TintTo(nil, color, duration, easing_fn)
	return self
end

function ArmourResearchRadial:TintIconTo(color, duration, easing_fn)
	if self.is_icon then
		self.image:TintTo(nil, color or self.normal_color_icon, duration, easing_fn)
	end
	return self
end

function ArmourResearchRadial:TintBackgroundTo(color, duration, easing_fn)
	if not color and self.is_locked then
		color = self.locked_color_bg
	elseif not color then
		color = self.normal_color_bg
	end
	self.bg:TintTo(nil, color, duration, easing_fn)
	return self
end

function ArmourResearchRadial:SetBackgroundColor(color)
	self.bg:SetMultColor(color or self.normal_color_bg)
	return self
end

function ArmourResearchRadial:SetImageSaturation(saturation)
	self.image:SetSaturation(saturation)
	return self
end

function ArmourResearchRadial:SetImageColor(color)
	self.image:SetMultColor(color or HexToRGB(0xFFFFFFff))
	return self
end

function ArmourResearchRadial:SetImageAddColor(color)
	self.image:SetAddColor(color or HexToRGB(0xFFFFFFff))
	return self
end

-- Styles are 1, 3 or 10
-- 1 is a filled radial, for small icons
-- 3 is divided into 3 segments
-- 10 into 10 segments
function ArmourResearchRadial:SetMax(num)
	if num == 10 then
		self.fill:SetTexture("images/ui_ftf_research/item_radial_fill_10.tex")
		self.fill_upgrade:SetTexture("images/ui_ftf_research/item_radial_fill_10.tex")
		self.fill_back:SetTexture("images/ui_ftf_research/item_radial_fill_10.tex")
	elseif num == 6 then
		self.fill:SetTexture("images/ui_ftf_research/item_radial_fill_6.tex")
		self.fill_upgrade:SetTexture("images/ui_ftf_research/item_radial_fill_6.tex")
		self.fill_back:SetTexture("images/ui_ftf_research/item_radial_fill_6.tex")
	elseif num == 3 then
		self.fill:SetTexture("images/ui_ftf_research/item_radial_fill_3.tex")
		self.fill_upgrade:SetTexture("images/ui_ftf_research/item_radial_fill_3.tex")
		self.fill_back:SetTexture("images/ui_ftf_research/item_radial_fill_3.tex")
	else
		self.fill:SetTexture("images/ui_ftf_research/item_radial_fill_1.tex")
		self.fill_upgrade:SetTexture("images/ui_ftf_research/item_radial_fill_1.tex")
		self.fill_back:SetTexture("images/ui_ftf_research/item_radial_fill_1.tex")
	end
	return self
end

function ArmourResearchRadial:SetIcon(icon, scale)
	self.is_icon = true
	self.image:SetTexture(icon)
		:SetMultColor(self.normal_color_icon)
	self.image_size = self.size * (scale or 1)
	self:_UpdateDisplay()
	return self
end

function ArmourResearchRadial:SetItem(item)
	self.is_icon = false
	self.image:SetTexture(item:GetDef().icon)
	self.image_size = self.size * 0.45
	self.normal_color_icon = HexToRGB(0xFFFFFFff)
	self:_UpdateDisplay()
	return self
end

-- Set states

function ArmourResearchRadial:SetLocked(is_locked)
	self.is_locked = is_locked
	self:_UpdateDisplay()
	return self
end

function ArmourResearchRadial:IsLocked()
	return self.is_locked
end

function ArmourResearchRadial:SetFull(is_full)
	self.is_full = is_full
	self:_UpdateDisplay()
	return self
end

function ArmourResearchRadial:SetProgress(progress, color)
	self.progress = progress
	self.fill:SetProgress(self.progress)
	if color then
		self.fill:SetMultColor(color)
	end
	self:_UpdateDisplay()
	return self
end

function ArmourResearchRadial:SetUpgradeProgress(progress, color)
	self.fill_upgrade:SetProgress(progress)
	if color then
		self.fill_upgrade:SetMultColor(color)
	end
	return self
end

function ArmourResearchRadial:_UpdateDisplay()
	if self.is_locked then
		self.image_size = self.size
		self.bg:SetSize(self.size * 1.3, self.size * 1.3)
			:SetMultColor(self.locked_color_bg)
		self.image:SetTexture("images/ui_ftf_research/item_radial_lock.tex")
			:SetSize(self.image_size, self.image_size)
			:SetMultColor(self.locked_color_icon)
	else
		self.bg:SetSize(self.size, self.size)
			:SetMultColor(self.normal_color_bg)
		self.image:SetSize(self.image_size, self.image_size)
			:SetMultColor(self.normal_color_icon)
	end
	self.overlay:SetShown(not self.is_locked)
	self.fill_back:SetShown(not self.is_locked)
	self.fill:SetShown(not self.is_locked)
	return self
end


return ArmourResearchRadial
