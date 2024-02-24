local Widget = require("widgets/widget")
local ImageButton = require("widgets/imagebutton")
local Text = require("widgets/text")
local RoomBonusButtonTitle = require("widgets/ftf/roombonusbuttontitle")
local LockedMetaRewardWidget = require("widgets/ftf/lockedmetarewardwidget")

local easing = require "util.easing"

--- A large tall button showing a selectable room bonus
local ItemDetailsButton = Class(ImageButton, function(self, owner, item)
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

    self.icon = self.image:AddChild(LockedMetaRewardWidget(self.height*2, owner, item))
		-- :SetScale(self.iconScale)

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

	if item then
		self:SetItem(item)
	end

	if TheDungeon.HUD.player_unit_frames then
		TheDungeon.HUD.player_unit_frames:Hide()
	end
end)

function ItemDetailsButton:SetItem(item)
	self.item = item

	if self.item then
		local def = self.item:GetDef()

		self.can_select = true

		-- Update text
		self.title:SetTitle(string.upper(def.pretty.name))

		-- self.title:SetHAlign(ANCHOR_MIDDLE)
		self.description:SetText(string.upper(def.pretty.desc))

		local icon_offset = 225
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

function ItemDetailsButton:AnimateIn()
	local x, y = self:GetPos()
	local offset = 500
	self:Offset(offset, 0)

	self:RunUpdater(Updater.Ease(function(v) self:SetPosition(v, y) end, x + offset, x, 0.5, easing.outElastic))

	return self
end

function ItemDetailsButton:AnimateOut(cb)
	local x, y = self:GetPos()
	local offset = -1000

	self:RunUpdater(
		Updater.Series({
			Updater.Ease(function(v) self:SetPosition(v, y) end, x, x + offset, 0.5, easing.inExpo),
			Updater.Do(cb)
	}))

	return self
end

return ItemDetailsButton
