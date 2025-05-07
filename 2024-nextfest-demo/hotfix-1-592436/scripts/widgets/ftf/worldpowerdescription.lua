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
local WorldPowerDescription = Class(Widget, function(self, scale)
	Widget._ctor(self, "WorldPowerDescription")

    -- Set default size
    self.scale = scale or 1
    self.width = 901 * self.scale
    self.height = 498 * self.scale
    self.padding = 35 * HACK_FOR_4K
    self.iconScale = self.scale * 1.2
		self.skillScale = self.scale * 1 -- Alternate scale if it's a skill

	self.image = self:AddChild(Image("images/ui_ftf_relic_selection/relic_bg_black.tex"))
		:SetSize(self.width, self.height)
		:ApplyMultColor(0, 0, 0, .8)

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
    	:ApplyWorldPowerDescriptionStyle()

	self.description = self.textContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.INWORLD_POWER_DESCRIPTION))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetHAlign(ANCHOR_MIDDLE)
		:EnableWordWrap(true)
		:SetRegionSize(self.width * 0.6, 326)
		:SetVAlign(ANCHOR_TOP)
		:ShrinkToFitRegion(true)
		:SetShadowColor(UICOLORS.BLACK)
		:SetOutlineColor(UICOLORS.BLACK)
		:EnableShadow()
		:EnableOutline()
		:SetShadowOffset(1, -1)

	-- Ornament at the bottom
	self.bottomOrnament = self.image:AddChild(Image("images/ui_ftf_relic_selection/relic_bg_bottom_ornament.tex"))
		:SetScale(self.scale)
		--Laid out after laying out text+description
end)

function WorldPowerDescription:SetPowerToolTip(btn_idx, num_buttons, is_lucky)
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

function WorldPowerDescription:SetPrice(price, is_free)
	assert(self.price_widget, "Call AddPriceDisplay!")

	self.price_widget:SetPrice(price)
	if is_free then
		self.price_widget:Hide()
	else
		self.price_widget:LayoutBounds("center", "bottom", self.image)
			:Offset(125, 75)
	end
end

function WorldPowerDescription:SetPower(power, islucky)
	self.power = power
	
	if not power then
		return self
	end

	local def = self.power:GetDef()

	if def.power_type == Power.Types.SKILL then
		self.iconScale = self.skillScale
		self.icon:Remove()
		self.icon = self.image:AddChild(SkillIconWidget())
			:SetScale(self.iconScale)
		self.icon:SetSkill(self.power)
	else
		self.icon:SetPower(self.power)
	end

	-- Update text
	self.title:SetTitle(string.upper(def.pretty.name))

	-- self.title:SetHAlign(ANCHOR_MIDDLE)
	self.description:SetText(Power.GetDescForPower(self.power))

	-- Layout icon
	self.icon:LayoutBounds("center", "top", self.image)
		:Offset(-450, self.height * 0.05)

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

	return self
end

function WorldPowerDescription:GetPower()
	return self.power
end

return WorldPowerDescription
