local Power = require "defs.powers"
local Widget = require("widgets/widget")
local ImageButton = require("widgets/imagebutton")
local Text = require("widgets/text")
local RoomBonusButtonTitle = require("widgets/ftf/roombonusbuttontitle")
local PowerIconWidget = require("widgets/powericonwidget")

local easing = require "util.easing"

--- A large tall button showing a selectable room bonus
local PowerDetailsButton = Class(ImageButton, function(self, owner, power)
    ImageButton._ctor(self, "images/ui_ftf_relic_selection/relic_bg.tex")

    self.owner = owner

    -- Set default size
    local scale = 0.5
    self.width = 875 * scale
    self.height = 449 * scale
    self.padding = 35
    self.iconScale = scale * 0.75

    self.contentWidth = self.width - self.padding * 2
    self.textContentMaxHeight = self.height * 0.3 -- The total height available for the title+desc, before the stats are shown
	self:SetSize(self.width, self.height)

    -- Setup default scale
    self.focus_scale =  {1.05, 1.05, 1.05} -- TODO(jambell): on focus, make self.icon bigger, without making self.shadow bigger
    self.normal_scale = {1, 1, 1}

    -- Set default flags
    self.scaleOnFocus = true
    self.moveOnClick = true

    self.icon = self.image:AddChild(PowerIconWidget())
		:SetScale(self.iconScale)

    -- Add text contents
    self.textContainer = self.image:AddChild(Widget())

    --RBS
    self.title = self.image:AddChild(RoomBonusButtonTitle(self, "images/ui_ftf_relic_selection/relic_nameornament.tex"))

	self.description = self.textContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(HexToRGB(0xB28C77FF))
		:SetHAlign(ANCHOR_LEFT)
		-- :OverrideLineHeight(FONTSIZE.ROOMBONUS_TEXT * 0.9)
		:EnableWordWrap(true)
		:SetAutoSize(self.width * 0.55) -- What is the total horizontal size that the text can take up?

	if power then
		self:SetPower(power)
	end

	if TheDungeon.HUD.player_unit_frames then
		TheDungeon.HUD.player_unit_frames:Hide()
	end
end)

function PowerDetailsButton:SetPower(power)
	self.power = power

	if self.power then
		local def = self.power:GetDef()

		self.can_select = true
		self.icon:SetPower(self.power)

		-- Update text
		self.title:SetTitle(string.upper(def.pretty.name))

		-- self.title:SetHAlign(ANCHOR_MIDDLE)
		self.description:SetText(Power.GetDescForPower(self.power))

		local icon_offset
		-- JAMBELL: has to differ per icon type, because of how big Legendary Frames are
		if self.power.rarity == "LEGENDARY" then
			icon_offset = 255
		elseif self.power.rarity == "EPIC" then
			icon_offset = 225
		else
			icon_offset = 225
		end

		-- Layout icon
		self.icon:LayoutBounds("center", "top", self.image)
			:Offset(-icon_offset, self.height * 0.37)

		-- Layout text
		self.title:LayoutBounds("center", "center", self)
			:Offset(50, 70)
		self.description:LayoutBounds("center", "center", self)
			:Offset(50, 10)
	end

	return self
end

function PowerDetailsButton:GetPower()
	return self.power
end

function PowerDetailsButton:PrepareAnimation()

	return self
end

function PowerDetailsButton:AnimateIn()
	local x, y = self:GetPos()
	local offset = 500
	self:Offset(offset, 0)

	self:RunUpdater(Updater.Ease(function(v) self:SetPosition(v, y) end, x + offset, x, 0.5, easing.outElastic))

	return self
end

function PowerDetailsButton:AnimateOut(cb)
	local x, y = self:GetPos()
	local offset = -1000

	self:RunUpdater(
		Updater.Series({
			Updater.Ease(function(v) self:SetPosition(v, y) end, x, x + offset, 0.5, easing.inExpo),
			Updater.Do(cb)
	}))

	return self
end

function PowerDetailsButton:AnimateFloating(speed, amplitude)
	speed = speed or 0.3
	speed = speed * 4
	amplitude = amplitude or 5
	local widgetX, widgetY = self.image:GetPosition()
	self.image:RunUpdater(
		Updater.Loop({
			Updater.Ease(function(v) self.image:SetPosition(widgetX, v) end, widgetY, widgetY + amplitude, speed * 0.8, easing.outQuad),
			Updater.Wait(speed * 0.5),
			Updater.Ease(function(v) self.image:SetPosition(widgetX, v) end, widgetY + amplitude, widgetY - amplitude * 1.2, speed * 1.8, easing.inOutQuad),
			Updater.Wait(speed * 0.2),
			Updater.Ease(function(v) self.image:SetPosition(widgetX, v) end, widgetY - amplitude * 1.2, widgetY + amplitude * 1.3, speed * 1.6, easing.inOutQuad),
			Updater.Wait(speed * 0.4),
			Updater.Ease(function(v) self.image:SetPosition(widgetX, v) end, widgetY + amplitude * 1.3, widgetY - amplitude, speed * 1.7, easing.inOutQuad),
			Updater.Wait(speed * 0.3),
			Updater.Ease(function(v) self.image:SetPosition(widgetX, v) end, widgetY - amplitude, widgetY, speed * 0.8, easing.inQuad),
		})
	)
	return self
end

return PowerDetailsButton
