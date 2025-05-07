-- Pass in an array of powers
-- Display them in a grid
-- Allow selection of one of the powers
-- Display a confirmation screen on selection
-- Execute code when confirmed

-- Useful for stuff like picking a power to upgrade or remove.

local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local ImageButton = require("widgets/imagebutton")
local Image = require("widgets/image")
local Panel = require("widgets/panel")
local Text = require("widgets/text")
local ControlsWidget = require("widgets/ftf/controlswidget")
local InfoPopUp = require "screens.infopopup"

local easing = require "util.easing"
local krandom = require "util.krandom"

---------------- BUTTON

local WeaponButton = Class(ImageButton, function(self, def)
	ImageButton._ctor(self, "images/ui_ftf_roombonus/bonus_bg.tex")

	local scale = 0.6
    self.width = 520 * scale
    self.height = 920 * scale
    self.padding = 35
	self.iconScale = scale --* 0.45

    self.contentWidth = self.width - self.padding * 2
    self.textContentMaxHeight = self.height * 0.3 -- The total height available for the title+desc, before the stats are shown
	self:SetSize(self.width, self.height)

    self.focus_scale = {1.05, 1.05, 1.05}
    self.normal_scale = {1, 1, 1}

    self.icon = self.image:AddChild(Image())
		:SetScale(self.iconScale)
		:Offset(0, 81)

    self.frame = self.image:AddChild(Image("images/ui_ftf_roombonus/bonus_line.tex"))
		:SetSize(self.width, self.height)
		:SetMultColor(HexToRGB(0x302825FF))

    self.textContainer = self.image:AddChild(Widget())
    self.title = self.textContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TITLE))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_TITLE)
		:SetHAlign(ANCHOR_LEFT)
		:OverrideLineHeight(FONTSIZE.ROOMBONUS_TITLE * 0.9)
		:SetAutoSize(self.contentWidth)
		:EnableUnderlines(true)
	self.description = self.textContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(HexToRGB(0x7F7676FF))
		:SetHAlign(ANCHOR_LEFT)
		:OverrideLineHeight(FONTSIZE.ROOMBONUS_TEXT * 0.9)
		:SetAutoSize(self.contentWidth)

	local tooltip = string.format("%s\n\n%s", STRINGS.WEAPONS.HOW_TO_PLAY[def.weapon_type], STRINGS.WEAPONS.FOCUS_HIT[def.weapon_type])

	self:SetText(def.pretty.name, tooltip)
	self:SetImage(def.icon)
	self:DoLayout()

	self:SetToolTip(STRINGS.UI.TOOLTIPS.FOCUS_HIT)
end)

function WeaponButton:SetText(title, desc)
	self.title:SetText(string.format("<u>%s</u>", title))
	self.description:SetText(desc)
end

function WeaponButton:SetImage(tex)
	self.icon:SetTexture(tex)
end

function WeaponButton:DoLayout()
	self.icon:LayoutBounds("center", "top", self.image)
		:Offset(0, -self.height * 0.11)
	-- Layout text
	self.description:LayoutBounds("left", "below", self.title)
		:Offset(0, -4)
	self.textContainer:LayoutBounds("center", "below", self.icon)
		:Offset(0, -10)
end

function WeaponButton:AnimateFloating(speed, amplitude)
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

---------------- TITLE

local WeaponSelectionTitleWidget = Class(Widget, function(self)
	Widget._ctor(self, "WeaponSelectionTitleWidget")

	self.frameContainer = self:AddChild(Widget())
	self.frameLeft = self.frameContainer:AddChild(Panel("images/map_ftf/map_title_frame_left.tex"))
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetNineSliceCoords(100, 42, 150, 58)
		:SetNineSliceBorderScale(0.5)
		:SetSize(300, 200)
	self.frameRight = self.frameContainer:AddChild(Panel("images/map_ftf/map_title_frame_right.tex"))
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetNineSliceCoords(100, 42, 150, 58)
		:SetNineSliceBorderScale(0.5)
		:SetSize(300, 200)

	self.textContent = self:AddChild(Widget())
	self.title = self.textContent:AddChild(Text(FONTFACE.DEFAULT, 60, "", UICOLORS.LIGHT_TEXT_DARK))
end)

function WeaponSelectionTitleWidget:SetTitle(title)
	self.title:SetText(title)

	local w, h = self.title:GetSize()
	w = math.max(w, 200) + 130
	h = h + 60

	self.frameLeft:SetSize( w / 2, h)
	self.frameRight:SetSize( w / 2, h)
		:LayoutBounds("after", nil, self.frameLeft)

	self.textContent:LayoutBounds("center", "top", self.frameContainer)
		:Offset(0, -15)

	return self
end

---------------- SCREEN

local WeaponSelectionScreen = Class(Screen, function(self, player, on_close_cb)
	Screen._ctor(self, "WeaponSelectionScreen")
	self:SetOwningPlayer(player)

	self.on_close_cb = on_close_cb

	self.darken = self:AddChild(Image("images/ui_ftf_roombonus/background_gradient.tex"))
		:SetAnchors("fill", "fill")

	self.bg = self:AddChild(Panel("images/ui_ftf/upgrade_bg.tex"))
		:SetNineSliceCoords(587, 5, 725, 51)
		:SetSize(RES_X, 700)

	self.controls = self:AddChild(ControlsWidget(player))
		:LayoutBounds("left", "center", self.bg):Offset(50, 0)
		:SetScale(0.75)

	self.title = self:AddChild(WeaponSelectionTitleWidget())
		:SetTitle(STRINGS.UI.WEAPONSELECTIONSCREEN.PICK_A_WEAPON)
		:LayoutBounds("center", "above", self.bg)
		:Offset(0, 15)

	self.button_container = self:AddChild(Widget("Button Container"))
	local weapons = player.components.inventoryhoard.data.inventory["WEAPON"]

	for _, weapon in ipairs(weapons) do
		local def = weapon:GetDef()
		self.button_container:AddChild(WeaponButton(def))
			:SetOnClick(function()
				player.components.inventoryhoard:SetLoadoutItem(1, def.slot, weapon)
				player.components.inventoryhoard:SwitchToLoadout(1)
				self:CloseScreen()
			end)
			:AnimateFloating(krandom.Float(0.4, 0.5), krandom.Float(5, 10))
	end
	self.button_container:LayoutChildrenInGrid(2, 100)
	self.button_container:LayoutBounds("center", "center", self.bg)
end)

function WeaponSelectionScreen:SetDefaultFocus()
	self.button_container.children[1]:SetFocus()
end

function WeaponSelectionScreen:OnOpen()
	TheDungeon.HUD:Hide()
end

function WeaponSelectionScreen:CloseScreen()
	TheDungeon.HUD:Show()
	TheFrontEnd:PopScreen(self)

	if self.on_close_cb then
		self.on_close_cb()
	elseif TheDungeon.HUD.townHud then
		WeaponSelectionScreen.ShowWeaponReminder()
	end
end

function WeaponSelectionScreen.ShowWeaponReminder()
	assert(TheDungeon.HUD.townHud)
	if TheDungeon.HUD.townHud then
		-- temp popup for vert slice!
		local button_base = TheDungeon.HUD.townHud.inventoryButton
		local confirmation = nil
		confirmation = InfoPopUp(nil, nil, true,
			STRINGS.UI.WEAPONSELECTIONSCREEN.CHOICES.NAME,
			STRINGS.UI.WEAPONSELECTIONSCREEN.CHOICES.DESC)
			:SetButtonText(STRINGS.UI.BUTTONS.OK)
			:SetOnDoneFn(function(accepted)
				TheFrontEnd:PopScreen(confirmation)
				button_base:Show()
			end)
			:SetScale(0.75, 0.75)
			:SetArrowXOffset(-160)

		-- TODO(dbriscoe): POSTVS make inventory button its own widget.
		confirmation.inventoryButton = confirmation:AddChild(TheDungeon.HUD.townHud:_CreateInventoryButton())
			:SetPosition(-1171, -544)
			:SetScale(1.55) -- It's closer to 1.4, but make it big for emphasis and to hide that we're faking
		confirmation.inventoryButton.hotkeyWidget:Hide()
		local old_onclick = confirmation.inventoryButton.btn.onclick
		confirmation.inventoryButton.btn.onclick = function(...)
			confirmation.okButton:Click()
			old_onclick(...)
		end

		TheFrontEnd:PushScreen(confirmation)

		-- HACK: Don't hack positioning like this! See how ConfirmDialog does it based on a target widget.
		local rootWidget = confirmation:GetRootWidget()
		rootWidget:LayoutBounds("center", "above", button_base)
			:Offset(150, 30)

		button_base:Hide()

		-- And animate it in!
		confirmation:AnimateIn()
	end
end

return WeaponSelectionScreen
