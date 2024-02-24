local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local ActionButton = require("widgets/actionbutton")
local ImageButton = require("widgets/imagebutton")
local Enum = require "util.enum"
local PowerDescriptionButton = require "widgets.ftf.powerdescriptionbutton"
local PriceWidget = require("widgets/pricewidget")
local PlayerUnitFrames = require("widgets/ftf/playerunitframes")
local Text = require("widgets/text")
local Consumable = require "defs.consumable"
local Power = require "defs.powers"
local itemforge = require "defs.itemforge"

local easing = require("util/easing")

--------------------------------------------------------------
-- Displays a power and its upgrade, with animated arrows in between

local UpgradePowerPreview = Class(Widget, function(self, player, power, can_afford, free)
	Widget._ctor(self, "UpgradePowerPreview")

	self.def = power:GetDef()
	self.power = power
	local next_rarity = Power.GetNextRarity(power)

	local upgraded_power = itemforge.CreateEquipment(self.def.slot, self.def)
	upgraded_power:SetRarity(next_rarity)

	self.power_container = self:AddChild(Widget("Power Container"))

	local num_buttons = 3 -- so the tooltips show below  the powers

	self.before_widget = self.power_container:AddChild(PowerDescriptionButton())
		:SetPower(power, false, true)
		:SetPowerToolTip(1, num_buttons)
		:SetUnclickable()

	self.arrows_container = self:AddChild(Widget())
		:SetName("Arrows container")
		:SetMultColorAlpha(0)
	self.arrow_widget_left = self.arrows_container:AddChild(Image("images/ui_ftf_powers/upgrade_arrow_left.tex"))
		:SetName("Arrow left")
		:Offset(-60, 0)
	self.arrow_widget_right = self.arrows_container:AddChild(Image("images/ui_ftf_powers/upgrade_arrow_right.tex"))
		:SetName("Arrow right")
		:Offset(60, 0)

	self.after_widget = self.power_container:AddChild(PowerDescriptionButton())
		:SetPower(upgraded_power, false, true)
		:SetPowerToolTip(2, num_buttons)
		:SetUnclickable()

	self.before_widget:LayoutBounds("before", "center", self.arrows_container)
		:Offset(-100, 0)
	self.after_widget:LayoutBounds("after", "center", self.arrows_container)
		:Offset(100, 0)

	-- Animate arrows
	local arrow_left_x = self.arrow_widget_left:GetPos()
	local arrow_right_x = self.arrow_widget_right:GetPos()
	local duration = 2
	local distance = 150
	self.arrows_container:Offset(-distance/2 + 10, 0)
	self.arrows_container:RunUpdater(
		Updater.Loop({
			Updater.Parallel{
				Updater.Ease(function(v) self.arrows_container:SetMultColorAlpha(v) end, 0, 1, duration*0.25, easing.inOutQuad),
				Updater.Ease(function(v) self.arrow_widget_left:SetPos(v, 0) end, arrow_left_x, arrow_left_x+distance, duration*0.9, easing.inOutQuad),
				Updater.Ease(function(v) self.arrow_widget_right:SetPos(v, 0) end, arrow_right_x, arrow_right_x+distance, duration, easing.inOutQuad),
				Updater.Series{
					Updater.Wait(duration*0.75),
					Updater.Ease(function(v) self.arrows_container:SetMultColorAlpha(v) end, 1, 0, duration*0.25, easing.inOutQuad),
				},
			},
		})
	)

	self.focus_forward = self.after_widget
end)

--------------------------------------------------------------
-- Displays a power to be removed

local RemovePowerPreview = Class(Widget, function(self, player, power)
	Widget._ctor(self, "RemovePowerPreview")

	self.def = power:GetDef()
	self.power = power

	local title = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TITLE))
		:SetGlyphColor(UICOLORS.BACKGROUND_MID)
		:SetHiddenBoundingBox(true)
		:SetAutoSize(500)
		:SetText(STRINGS.UI.POWERSELECTIONSCREEN.REMOVE_TITLE)
		:Offset(-100, 400)

	self.power_container = self:AddChild(Widget("Power Container"))
	local num_buttons = 3 -- so the tooltips show below  the powers
	self.before_widget = self.power_container:AddChild(PowerDescriptionButton())
		:SetPower(power, false, true)
		:SetPowerToolTip(1, num_buttons)
		:SetUnclickable()

	self.focus_forward = self.after_widget
end)

--------------------------------------------------------------
-- Screen to confirm an action on a selected power

local ConfirmAction = Enum{
	"Remove",
	"Upgrade",
}

local PowerConfirmationScreen = Class(Screen, function(self, player, power, can_afford, free, action, on_confirm_cb, on_cancel_cb)
	Screen._ctor(self, "PowerConfirmationScreen")
	assert(ConfirmAction:Contains(action), "Use PowerConfirmationScreen.ConfirmAction enum.")
	self:SetAudioCategory(Screen.AudioCategory.s.PartialOverlay)

	self:SetOwningPlayer(player)
	self.power = power
	self.free = free
	self.action = action
	self.on_confirm_cb = on_confirm_cb
	self.on_cancel_cb = on_cancel_cb

	self.darken = self:AddChild(Image("images/ui_ftf_roombonus/background_gradient.tex"))
		:SetAnchors("fill", "fill")
	self.bg = self:AddChild(Image("images/bg_widebanner/widebanner.tex"))

	self.content = self:AddChild(Widget("Content"))
	self.details_container = self.content:AddChild(Widget("Content Container"))

	self.nav_buttons = self.content:AddChild(Widget("Nav Buttons"))
	self.cancel_button = self.nav_buttons:AddChild(ActionButton())
		:SetSecondary()
		:SetSize(BUTTON_W, BUTTON_H)
		:SetTextAndResizeToFit(STRINGS.UI.POWERSELECTIONSCREEN.BACK_BUTTON)
		:SetOnClick(function() self:OnCancel() end)
	local function onconfirm() self:OnConfirm() end
	self.confirm_button = self.nav_buttons:AddChild(ActionButton())
		:SetPrimary()
		:SetSize(BUTTON_W, BUTTON_H)
		:SetText(STRINGS.UI.POWERSELECTIONSCREEN.CONFIRM_BUTTON)
		:SetOnClick(onconfirm)

	if action == ConfirmAction.s.Upgrade then
		self.details = self.details_container:AddChild(UpgradePowerPreview(self.owningplayer, power, can_afford, free))
			:LayoutBounds("center", "center", self.bg)
			:Offset(0, 80)
		self.confirm_button:SetText(STRINGS.UI.POWERSELECTIONSCREEN.UPGRADE_BUTTON)
		if not self.free then
			self.confirm_button:SetRightText(string.format(STRINGS.UI.POWERSELECTIONSCREEN.UPGRADE_BUTTON_PRICE, Power.GetUpgradePrice(power)))
		end
	elseif action == ConfirmAction.s.Remove then
		self.details = self.details_container:AddChild(RemovePowerPreview(self.owningplayer, power, can_afford, free))
			:LayoutBounds("center", "center", self.bg)
			:Offset(100, 0)
		self.confirm_button:SetText(STRINGS.UI.POWERSELECTIONSCREEN.REMOVE_BUTTON)
	end

	if can_afford then
		self.confirm_button:SetToolTip(nil)
		self.confirm_button:SetEnabled(true)
	else
		self.confirm_button:SetEnabled(false)
		self.confirm_button:SetToolTip(STRINGS.UI.POWERSELECTIONSCREEN.NOT_ENOUGH)
	end

	self.nav_buttons:LayoutChildrenInRow(30)
		:LayoutBounds("center", "bottom", self.bg)
		:Offset(0, 100)

	self.player_unit_frames = self:AddChild(PlayerUnitFrames())

	self:RefreshCanAfford()
	self._on_inventory_changed = function()
		self:RefreshCanAfford() -- refresh text colour
	end
	self.inst:ListenForEvent("inventory_stackable_changed", self._on_inventory_changed, self.owningplayer)

	self.default_focus = self.confirm_button
end)
PowerConfirmationScreen.ConfirmAction = ConfirmAction

PowerConfirmationScreen.CONTROL_MAP = {
	{
		control = Controls.Digital.CANCEL,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"STRINGS.UI.POWERSELECTIONSCREEN.BACK_BUTTON", Controls.Digital.CANCEL))
		end,
		fn = function(self)
			self:OnCancel()
			return true
		end,
	},
}



function PowerConfirmationScreen:CloseScreen()
	TheFrontEnd:PopScreen(self)
end

function PowerConfirmationScreen:OnCancel()
	if self.on_cancel_cb then
		self.on_cancel_cb()
	end
	self:CloseScreen()
end

function PowerConfirmationScreen:OnConfirm(power)
	if self.on_confirm_cb then
		self.on_confirm_cb()
	end
	self:CloseScreen()
end

function PowerConfirmationScreen:RefreshCanAfford()
	local price = self.free and 0 or Power.GetUpgradePrice(self.power)
	local inventory = self.owningplayer.components.inventoryhoard
	local can_afford = inventory:GetStackableCount(Consumable.Items.MATERIALS.konjur) >= price

	if can_afford then
		self.confirm_button:SetToolTip(nil)
		self.confirm_button:SetEnabled(true)
	else
		self.confirm_button:SetEnabled(false)
		self.confirm_button:SetToolTip(STRINGS.UI.POWERSELECTIONSCREEN.NOT_ENOUGH)
	end
end

return PowerConfirmationScreen
