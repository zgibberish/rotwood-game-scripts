local Image = require "widgets.image"
local Widget = require("widgets/widget")
local Text = require("widgets/text")
local Panel = require("widgets/panel")
local easing = require "util.easing"

local SegmentedHealthBar =  Class(Widget, function(self, owner)
	Widget._ctor(self, "SegmentedHealthBar")

	self.time_hurt_bar_visible = 1.0
	self._fade_hurt_bar_task = nil

	self.pixels_per_health = 0.4
	self.inner_height = 30
	self.text_size = 40
	self.health_per_divider = 500
	self.health_floor = 250
	self.normal_health = owner.components.health:GetBaseMaxHealth()
	self.health_ceil = 2000

	self.current_health = self.normal_health

	self.bar_root = self:AddChild(Widget("Bar Root"))
		:SendToBack()

	self.bg = self.bar_root:AddChild(Panel("images/ui_ftf_segmented_healthbar/bar_fill.tex"))
		:SetNineSliceCoords(10, 2, 81, 28)
		:SetMultColor(0.2, 0.2, 0.2)

	self.mask = self.bar_root:AddChild(Panel("images/ui_ftf_segmented_healthbar/bar_fill.tex"))
		:SetNineSliceCoords(10, 2, 81, 28)
		:SetMask()

	self.hurt = self.bar_root:AddChild(Panel("images/ui_ftf_segmented_healthbar/bar_fill.tex"))
		:SetHiddenBoundingBox(true)
		:SetNineSliceCoords(10, 2, 81, 28)
		:SetMultColor(HexToRGB(0xFF7777FF))
		:SetMasked()


	local uicol = owner.uicolor

	self.health = self.bar_root:AddChild(Panel("images/ui_ftf_segmented_healthbar/bar_fill.tex"))
		:SetHiddenBoundingBox(true)
		:SetNineSliceCoords(10, 2, 81, 28)
		:SetMultColor(uicol)
		:SetMasked()

	self.preview_color_gain = {}
	self.preview_color_gain[1] = uicol[1] * 0.75
	self.preview_color_gain[2] = uicol[2] * 0.75
	self.preview_color_gain[3] = uicol[3] * 0.75
	self.preview_color_gain[4] = uicol[4]

	self.preview_color_loss = {}
	self.preview_color_loss[1] = uicol[1] * 0.5
	self.preview_color_loss[2] = uicol[2] * 0.5
	self.preview_color_loss[3] = uicol[3] * 0.5
	self.preview_color_loss[4] = uicol[4]

	self.preview = self.bar_root:AddChild(Panel("images/ui_ftf_segmented_healthbar/bar_fill.tex"))
		:SetHiddenBoundingBox(true)
		:SetNineSliceCoords(10, 2, 81, 28)
		:SetMultColor(self.preview_color_gain)
		:PulseAlpha(0.2, 0.8, 0.02)
		:SetMasked()
		:Hide()

	self.inner_widgets =
	{
		self.bg,
		self.mask,
		self.hurt,
		self.health,
		self.preview,
	}

	self.border = self.bar_root:AddChild(Panel("images/ui_ftf_segmented_healthbar/9_slice_border.tex"))
		:SetMultColor(0, 0, 0, 1)
		:SetNineSliceCoords(35, 4, 110, 34)
		:SendToBack()

	self.health_icon = self.bar_root:AddChild(Image("images/ui_ftf_segmented_healthbar/life_icon.tex"))

	self.ghost_small = self.bar_root:AddChild(Panel("images/ui_ftf_segmented_healthbar/9_slice_border.tex"))
		:SetNineSliceCoords(35, 4, 110, 34)
		:SetMultColorAlpha(0.3)
		:SendToBack()

	self.ghost_big = self.bar_root:AddChild(Panel("images/ui_ftf_segmented_healthbar/ghost.tex"))
		:SetNineSliceCoords(14, 4, 15, 34)
		:SendToBack()

	self.dividers = self.bar_root:AddChild(Widget("Dividers"))
	self.divider_widgets = {}
	self.divider_width = 12 -- how wide each divider widget is in pixels

	self.text_root = self:AddChild(Widget("Text Root"))
	self.outline = self.text_root:AddChild(Text(FONTFACE.CODE, self.text_size, nil, UICOLORS.BLACK))
		:EnableShadow()
		:SetShadowColor(UICOLORS.BLACK)
		:SetShadowOffset(1, -1)
		:EnableOutline()
		:SetOutlineColor(UICOLORS.BLACK)
		:SetMultColorAlpha(0.5)
	self.text = self.text_root:AddChild(Text(FONTFACE.CODE, self.text_size, nil, UICOLORS.LIGHT_TEXT_TITLE))

	self._onhealthchanged = function(_, data)
		self:DoHealthDelta(data)
	end

	self._onpreviewhealthchange = function(_, data)
		self:DoPreviewHealthChange(data)
	end

	self._onpreviewhealthchange_end = function(_)
		self:DoPreviewHealthChangeEnd()
	end

	self._onmaxhealthchanged = function(_, data)
		self:OnMaxHealthChanged(data)
	end

	self._onbasemaxhealthchanged = function(_, data)
		self:OnBaseMaxHealthChanged(data)
	end

	self:UpdateSizeConstraints()

	if owner then
		self:SetOwner(owner)
	end
end)

function SegmentedHealthBar:SetHealthBarSize(width, height)
	for _, widget in ipairs(self.inner_widgets) do
		widget:SetSize(width, height)
		-- widget:LayoutBounds("left", "center", self.border)
	end

	self.health_icon:LayoutBounds("before", "center", self.bg)
		:Offset(-5, 0)

	self.border:SetInnerSize(width, height)

	self:LayoutDividers()

	self.ghost_small:Hide()
	self.ghost_big:Hide()

	local nw, nh = self.ghost_small:GetSize()
	local bw, bh = self.border:GetSize()

	if width < self.normal_width then
		self.ghost_small:Show()
		self.ghost_small:LayoutBounds("left", "center", self.border)
		local delta = (nw - bw) + 10
		if delta > 31 then -- magic number is the minimum size of the ghost_big panel
			self.ghost_big:Show()
			self.ghost_big:SetSize(delta, bh)
			self.ghost_big:LayoutBounds("right", "center", self.ghost_small)
		end
	end

	self:SetHealthPercent(self.owner.components.health:GetPercent())

	if self.on_size_change_fn then
		self.on_size_change_fn(self)
	end

	self.owner:PushEvent("refresh_hud")
end

function SegmentedHealthBar:LayoutDividers()
	local num_dividers = math.floor(self.max_health / self.health_per_divider)

	if self.max_health % self.health_per_divider == 0 then
		num_dividers = num_dividers - 1
	end

	while #self.divider_widgets < num_dividers do
		self:CreateDivider()
	end

	local _, h = self.bg:GetSize()
	for _, divider in ipairs(self.divider_widgets) do
		divider:SetSize(self.divider_width, h)
		divider:Hide()
	end

	for i = 1, num_dividers do
		local divider = self.divider_widgets[i]
		divider:Show()
		local w = divider:GetSize()
		divider:LayoutBounds("left", "center", self.bg)
			:Offset(((self.health_per_divider * self:GetPixelsPerHealth()) * i) - (w * 0.5), 0)
	end
end

function SegmentedHealthBar:CreateDivider()
	local divider = self.dividers:AddChild(Image("images/ui_ftf_segmented_healthbar/divider.tex"))
	table.insert(self.divider_widgets, divider)
end

function SegmentedHealthBar:GetPixelsPerHealth()
	if self.max_health > self.health_ceil then
		return self.max_width / self.max_health
	else
		return self.pixels_per_health
	end
end

function SegmentedHealthBar:OnBaseMaxHealthChanged(max)
	self:SetHealthBounds(self.health_floor, max, self.health_ceil)
	self:OnMaxHealthChanged(max)
	self.ghost_small:SetSize(self.border:GetSize())
end

function SegmentedHealthBar:OnMaxHealthChanged(max)
	self.max_health = max

	local pph = self:GetPixelsPerHealth()

	local new_width = pph * max
	new_width = math.clamp( new_width, self.min_width, self.max_width)

	self:SetHealthBarSize(new_width, self.inner_height)
end

function SegmentedHealthBar:DoHealthDelta(data)
	local bar_w, bar_h = self.bg:GetSize()
	local new_percent = data.new/ data.max
	local x_offset = (1 - new_percent) * bar_w
	self.health:LayoutBounds("left", "center", self.bg)
		:Offset(-x_offset, 0)

	if data.new > data.old then
		self.hurt:LayoutBounds("left", "center", self.bg)
			:Offset(-x_offset, 0)
	else
		self.hurt:SetMultColorAlpha(1)

		if self._fade_hurt_bar_task then
			self._fade_hurt_bar_task:Cancel()
			self._fade_hurt_bar_task = nil
		end

		self._fade_hurt_bar_task = self.inst:DoTaskInTime(self.time_hurt_bar_visible, function() self:FadeOutDamageChunk(x_offset) end)
	end

	self.current_health = data.new

	self:UpdateText()
end

function SegmentedHealthBar:DoPreviewHealthChange(delta)
	local new = self.current_health + delta

	local bar_w, bar_h = self.bg:GetSize()
	local old_percent = self.current_health / self.max_health
	local new_percent = new / self.max_health
	local x_offset

	self:UpdateText()

	if new > self.current_health then
		-- Will gain health -- show a preview at the beginning of the bar
		x_offset = (1 - new_percent) * bar_w
		self.preview:Show()
			:LayoutBounds("left", "center", self.bg)
			:Offset(-x_offset, 0)
			:SetMultColor(self.preview_color_gain)
	else
		-- Will lose health -- show a preview at the end of the 'current health' bar
		local new_w = (old_percent - new_percent) * bar_w
		self.preview:Show()
			:SetSize(new_w, bar_h)
			:LayoutBounds("right", "center", self.health)
			:SetMultColor(self.preview_color_loss)
	end

end

function SegmentedHealthBar:DoPreviewHealthChangeEnd()
	self.preview:Hide()
end


function SegmentedHealthBar:FadeOutDamageChunk(x_offset)
	self._fade_hurt_bar_task = nil
	self.hurt:AlphaTo(0, 0.25, easing.inExpo, function()
		self.hurt:LayoutBounds("left", "center", self.bg)
			:Offset(-x_offset, 0)
	end)
end

function SegmentedHealthBar:SetHealthPercent(percent)
	local bar_w, bar_h = self.mask:GetSize()
	local x_offset = (1 - percent) * bar_w
	self.health:LayoutBounds("left", "center", self.bg)
		:Offset(-x_offset, 0)
	self.hurt:LayoutBounds("left", "center", self.bg)
		:Offset(-x_offset, 0)
	self:UpdateText()
end

function SegmentedHealthBar:UpdateText()
	local current = math.ceil(self.owner.components.health:GetCurrent())
	local max = self.owner.components.health:GetMax()

	self.text:SetText(string.format("%s/%s", current, max))
	self.outline:SetText(string.format("%s/%s", current, max))

	self.text_root:LayoutBounds("left", "center", self.bg)
		:Offset(10, 1)
end

function SegmentedHealthBar:UpdateSizeConstraints()
	self.min_width = self.health_floor * self.pixels_per_health -- this is the smallest the bar will ever get
	self.normal_width = self.normal_health * self.pixels_per_health -- this is how long the bar is if health is normal
	self.max_width = self.health_ceil * self.pixels_per_health -- this is the largest the bar will ever get
end

------ Setup Functions

function SegmentedHealthBar:SetPixelsPerHealth(pph)
	self.pixels_per_health = pph

	self:UpdateSizeConstraints()
	return self
end

function SegmentedHealthBar:SetDividerSpacing(num)
	self.health_per_divider = num
	return self
end

function SegmentedHealthBar:SetHealthBounds(min, normal, max)
	self.health_floor = min
	self.normal_health = normal
	self.health_ceil = max

	self:UpdateSizeConstraints()
	return self
end

function SegmentedHealthBar:SetOwner(owner)
	if owner ~= self.owner then
		if self.owner ~= nil then
			self.inst:RemoveEventCallback("healthchanged", self._onhealthchanged, self.owner)
			self.inst:RemoveEventCallback("maxhealthchanged", self._onmaxhealthchanged, self.owner)
			self.inst:RemoveEventCallback("basemaxhealthchanged", self._onbasemaxhealthchanged, self.owner)
			self.inst:RemoveEventCallback("previewhealthchange", self._onpreviewhealthchange, self.owner)
			self.inst:RemoveEventCallback("previewhealthchange_end", self._onpreviewhealthchange_end, self.owner)
		end

		self.owner = owner

		if self.owner ~= nil then
			self.inst:ListenForEvent("healthchanged", self._onhealthchanged, self.owner)
			self.inst:ListenForEvent("maxhealthchanged", self._onmaxhealthchanged, self.owner)
			self.inst:ListenForEvent("basemaxhealthchanged", self._onbasemaxhealthchanged, self.owner)
			self.inst:ListenForEvent("previewhealthchange", self._onpreviewhealthchange, self.owner)
			self.inst:ListenForEvent("previewhealthchange_end", self._onpreviewhealthchange_end, self.owner)

			self:OnBaseMaxHealthChanged(self.normal_health)
			self.ghost_small:SetSize(self.border:GetSize())

			if self.owner.components.health ~= nil then
				self:OnMaxHealthChanged(self.owner.components.health:GetMax())
			end
		end
	end
	return self
end

function SegmentedHealthBar:SetOnSizeChangeFn(fn)
	self.on_size_change_fn = fn
end

function SegmentedHealthBar:RefreshColor()
	self.health:SetMultColor(self.owner.uicolor)
end

return SegmentedHealthBar
