local CheckBox = require "widgets.checkbox"
local Clickable = require "widgets.clickable"
local ConfirmDialog = require "screens.dialogs.confirmdialog"
local DropDown = require"widgets.dropdown"
local Image = require "widgets.image"
local ImageButton = require "widgets.imagebutton"
local LoadingWidget = require "widgets.redux.loadingwidget"
local Panel = require "widgets.panel"
local PanelButton = require "widgets.panelbutton"
local Screen = require "widgets.screen"
local ScrollPanel = require "widgets.scrollpanel"
local TabGroup = require "widgets.tabgroup"
local Text = require "widgets.text"
local Widget = require "widgets.widget"
local cursor = require "content.cursor"
local easing = require "util.easing"
local fmodtable = require "defs.sound.fmodtable"
local iterator = require "util.iterator"
local kassert = require "util.kassert"
local lume = require "util.lume"
local templates = require "widgets.ftf.templates"


------------------------------------------------------------------------------------------
--- Displays a number of options and the currently selected one
----
local OptionsRowPagination = Class(Widget, function(self)
	Widget._ctor(self, "OptionsRowPagination")

	self.dotSize = 12
	self.selectedAlpha = 1
	self.normalAlpha = 0.25

end)

function OptionsRowPagination:SetCount(count)

	-- Remove old dots
	self:RemoveAllChildren()

	-- Add new ones
	for k = 1, count do
		self:AddChild(Image("images/ui_ftf_options/pagination_dot.tex"))
			:SetSize(self.dotSize, self.dotSize)
			:SetMultColorAlpha(self.normalAlpha)
	end

	-- Layout
	self:LayoutChildrenInGrid(100, 2)

	return self
end

function OptionsRowPagination:SetCurrent(current)

	for k, dot in ipairs(self.children) do
		dot:SetMultColorAlpha(k == current and self.selectedAlpha or self.normalAlpha)
	end

	return self
end


------------------------------------------------------------------------------------------
--- Displays a title widget for the controls panel, for cate gory separation
----
local OptionsScreenCategoryTitle = Class(Widget, function(self, width, text)
	Widget._ctor(self, "OptionsScreenCategoryTitle")

	self.hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetMultColorAlpha(0)

	self.background = self:AddChild(Panel("images/ui_ftf_options/titlerow_bg.tex"))
		:SetNineSliceCoords(30, 0, 370, 100)
		:SetMultColor(UICOLORS.LIGHT_TEXT)
	self.title = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.OPTIONS_ROW_TITLE, text, UICOLORS.BACKGROUND_DARK))

	-- Resize the background to the text
	local w, h = self.title:GetSize()
	self.hitbox:SetSize(width, h + 40)
	self.background:SetSize(w + 120, h + 40)
		:LayoutBounds("left", "center", self.hitbox)
		:Offset(20, 0)
	self.title:LayoutBounds("center", "center", self.background)
		:Offset(-4, 0)

end)

------------------------------------------------------------------------------------------
--- A screen that prompts the player for a key to be pressed and bound to a specific control
----
local OptionsKeybindingScreen = Class(Screen, function(self, controlName, currentKey, callback, bind_target)
	Screen._ctor(self, "OptionsKeybindingScreen")


	assert(TheGameSettings.InputDevice:Contains(bind_target))
	self.is_binding_gamepad = bind_target == TheGameSettings.InputDevice.s.gamepad
	self.controlName = controlName or ""
	self.currentKey = currentKey or ""
	self.oninputpressed = callback
	self.is_delaying = false

	-- Add background
	self.bg = self:AddChild(templates.BackgroundImage("images/global/square.tex"))
		:SetMultColor(UICOLORS.BACKGROUND_DARK)


	-- Add text
	self.textContainer = self:AddChild(Widget("Text Container"))
	self.title = self.textContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.KEYBINDING_TITLE, "", UICOLORS.LIGHT_TEXT))
		:SetText(self.controlName)
	self.subtitle = self.textContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.KEYBINDING_SUBTITLE, "", UICOLORS.LIGHT_TEXT_DARK))
		:OverrideLineHeight(FONTSIZE.KEYBINDING_SUBTITLE * 0.85)
		:SetText(STRINGS.UI.OPTIONSSCREEN.KEYBINDING_SUBTITLE_KBM)
		:OverrideLineHeight(FONTSIZE.KEYBINDING_SUBTITLE)
		:LayoutBounds("center", "below", self.title)

	local current_label_fmt = STRINGS.UI.OPTIONSSCREEN.KEYBINDING_TEXT_KBM
	if self.is_binding_gamepad then
		self.subtitle
			:SetText(STRINGS.UI.OPTIONSSCREEN.KEYBINDING_SUBTITLE_GAMEPAD)
		current_label_fmt = STRINGS.UI.OPTIONSSCREEN.KEYBINDING_TEXT_GAMEPAD
	end

	self.gamepadbuttonhandler = TheInput:AddGamepadButtonHandler(function(gamepad_id, gamepadbutton, down)
		self:OnRawGamepadButton(gamepad_id, gamepadbutton, down)
	end)

	if self.currentKey and self.currentKey ~= "" then
		self.text = self.textContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.KEYBINDING_TEXT, "", UICOLORS.LIGHT_TEXT))
			:OverrideLineHeight(FONTSIZE.KEYBINDING_TEXT * 0.85)
			:SetText(string.format(current_label_fmt, TheInput:BindingToString(self.currentKey)))
			:LayoutBounds("center", "below", self.subtitle)
			:Offset(0, -60)
	end

	self.textContainer:LayoutBounds("center", "center", self.bg)

	self.default_focus = self.bg
end)

function OptionsKeybindingScreen:OnClose()
	OptionsKeybindingScreen._base.OnClose(self)
	TheInput:RemoveAnyGamepadButtonHandler(self.gamepadbuttonhandler)
end

function OptionsKeybindingScreen:_AcceptBinding(binding)
	-- Don't dismiss immediately to show a response to player input on success.
	-- This just for visuals: Responding to key up prevents input bleed between
	-- screens.
	self.is_delaying = true

	if self.oninputpressed then
		self.oninputpressed(binding)
	end

	self:RunUpdater(Updater.Series{
			Updater.Ease(function(v)
				self.textContainer:SetScale(v)
			end, 1, 1.1, 0.25, easing.outCirc),
			Updater.Do(function()
				TheFrontEnd:PopScreen(self)
			end),
		})
end

function OptionsKeybindingScreen:_Abort()
	self.is_delaying = true
	TheFrontEnd:PopScreen(self)
end

local function IsMappableKey(raw_key)
	-- Prevent binding some keys that could get users into a broken state.
	-- Accept modifier keys since we support it by default. Allowing modifiers
	-- prevents chording (mapping Ctrl-I), but that doesn't seem useful.
	local bad_keys = {
		-- Don't allow binding Windows key.
		InputConstants.Keys.LSUPER,
		InputConstants.Keys.RSUPER,
	}
	return lume.find(bad_keys, raw_key) == nil
end

function OptionsKeybindingScreen:OnRawKey(raw_key, down)
	if TheInput:IsControlDownOnAnyDevice(Controls.Digital.MENU_CANCEL_INPUT_BINDING)
		-- Abort on wrong input device, but only on up to prevent leaking input to next screen.
		or (not down and self.is_binding_gamepad)
	then
		-- Player canceled
		self:_Abort()
		return
	end

	if down or self.is_delaying then return end

	-- Convert numeric raw key into a key name
	local key_lookup = lume.invert(InputConstants.Keys)
	local key = key_lookup[raw_key]

	if IsMappableKey(raw_key) then
		local binding = { key = key }
		self:_AcceptBinding(binding)
	end
end

function OptionsKeybindingScreen:OnRawGamepadButton(gamepad_id, raw_button, down)
	if TheInput:IsControlDownOnAnyDevice(Controls.Digital.MENU_CANCEL_INPUT_BINDING)
		-- Abort on wrong input device, but only on up to prevent leaking input.
		or (not down and not self.is_binding_gamepad)
	then
		-- Player canceled
		self:_Abort()
		return
	end

	if down or self.is_delaying then return end

	-- Convert numeric raw button into a button name
	local gamepadbutton = InputConstants.GamepadButtonById[raw_button]

	do
		local binding = { button = gamepadbutton }
		self:_AcceptBinding(binding)
	end
end


------------------------------------------------------------------------------------------
--- Displays a bindable control (W, LEFT, etc)
----
local OptionsKeyBindingWidget = Class(Widget, function(self, width, height)
	Widget._ctor(self, "OptionsKeyBindingWidget")

	-- Set up values
	self.width = width or 400
	self.height = height or 100
	self.textWidth = self.width - 40
	self.bind_target = TheGameSettings.InputDevice.s.keyboard


	self.background = self:AddChild(PanelButton("images/ui_ftf_options/controls_bg.tex"))
		:SetNineSliceCoords(22, 0, 304, 100)
		:SetScaleOnFocus(false)
		:SetMultColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetOnClick(function() self:OpenPopup() end)
	self.valueText = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.OPTIONS_ROW_TITLE, "", UICOLORS.WHITE))
		:LeftAlign()
		:SetMultColor(UICOLORS.BACKGROUND_DARK)


	-- Apply default sizes
	self:SetSize(self.width, self.height)

end)

function OptionsKeyBindingWidget:SetBindDeviceTarget(target)
	self.bind_target = target
	return self
end


function OptionsKeyBindingWidget:SetControl(controlName)
	self.controlName = controlName or ""
	return self
end

function OptionsKeyBindingWidget:OpenPopup()

	local function cb(newKeybinding)
		-- A new key was pressed
		self:SetKeybinding(newKeybinding)
		if self.onValueChangeFn then
			self.onValueChangeFn(self.keybinding)
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.ui_confirm_keybind)
		end
	end
	TheFrontEnd:PushScreen(OptionsKeybindingScreen(self.controlName, self.keybinding, cb, self.bind_target))

	return self
end

function OptionsKeyBindingWidget:DropdownTintTo(back, text, duration)
	self.background:TintTo(nil, back, duration or 0.2, easing.inOutQuad)
	self.valueText:TintTo(nil, text, duration or 0.2, easing.inOutQuad)
	return self
end

function OptionsKeyBindingWidget:SetSize(width, height)
	self.width = width or 220
	self.height = height or 50
	self.textWidth = self.width - 40

	-- Resize main row
	self.background:SetSize(self.width, self.height)
	self.valueText
		:SetAutoSize(self.textWidth)
		:LayoutBounds("center", "center", self.background)

	return self
end

function OptionsKeyBindingWidget:SetKeybinding(keybinding)
	self.keybinding = keybinding

	if self.keybinding then
		self.valueText
			:SetText(TheInput:BindingToString(keybinding))
			:LayoutBounds("center", "center", self.background)
	end

	return self
end

function OptionsKeyBindingWidget:SetOnBindingChange(onValueChangeFn)
	self.onValueChangeFn = onValueChangeFn
	return self
end


------------------------------------------------------------------------------------------
--- Displays a draggable progress bar for volume picking
----
local OptionsRowProgress = Class(Widget, function(self, width, min, max, current)
	Widget._ctor(self, "OptionsRowProgress")

	self.min = min or 0
	self.max = max or 100
	self.current = current or self.min

	self.width = width or 400
	self.barHeight = 36
	self.handleWidth = 16
	self.handleHeight = self.barHeight + 16
	self.fillAlpha = 1
	self.emptyAlpha = 0.25

	self.progressBack = self:AddChild(Panel("images/ui_ftf_options/pagination_dot.tex"))
		:SetNineSliceCoords(5, 0, 43, 48)
		:SetSize(self.width, self.barHeight)
		:SetMultColorAlpha(self.emptyAlpha)
	self.progressFill = self:AddChild(Panel("images/ui_ftf_options/pagination_dot.tex"))
		:SetNineSliceCoords(5, 0, 43, 48)
		:SetSize(self.width, self.barHeight)
		:SetMultColorAlpha(self.fillAlpha)
	self.handle = self:AddChild(Panel("images/ui_ftf_options/pagination_dot.tex"))
		:SetNineSliceCoords(5, 0, 43, 48)
		:SetSize(self.handleWidth, self.handleHeight)


	-- Handle input
	self:SetHoverCheck(true)
	self:SetNavFocusable()

end)

function OptionsRowProgress:WhileOnDown()
	local mouseDown = TheInput:IsControlDown(Controls.Digital.MENU_ACCEPT)

	if mouseDown then
		local x1, y1, x2, y2 = self:GetBoundingBox()

		-- Get current mouse position
		local current_x, current_y = TheInput:GetUIMousePos()
		-- Convert position to this widget's frame of reference
		current_x, current_y = self:TransformFromWorld(current_x, current_y)

		-- Calculate new value
		local value = Remap(current_x, x1, x2, self.min, self.max)

		if self.onChangeFn then
			self.onChangeFn(value)
		end

		self:SetCurrent(value)
	end
end

function OptionsRowProgress:SetWidth(width)
	self.width = width or 200
	self.progressBack:SetSize(self.width, self.barHeight)
	self.progressFill:SetSize(Remap(self.current, self.min, self.max, 0, self.width), self.barHeight)
	return self
end

function OptionsRowProgress:SetRange(min, max)
	self.min = min or 0
	self.max = max or 100
	return self
end

function OptionsRowProgress:BarTintTo(fill, handle, duration)
	local backFill = deepcopy(fill)
	backFill.a = self.emptyAlpha
	self.progressBack:TintTo(nil, backFill, duration or 0.2, easing.inOutQuad)
	self.progressFill:TintTo(nil, fill, duration or 0.2, easing.inOutQuad)
	self.handle:TintTo(nil, handle, duration or 0.2, easing.inOutQuad)
	return self
end

function OptionsRowProgress:SetCurrent(currentIndex, displayValue)
	self.current = currentIndex or self.min
	self.progressFill:SetSize(Remap(self.current, self.min, self.max, 0, self.width), self.barHeight)
		:LayoutBounds("left", nil, self.progressBack)

	-- Position handle
	self.handle:SetPosition(
		Remap(
			self.current,
			self.min,
			self.max,
			-self.width / 2 + self.handleWidth / 2,
			self.width / 2 - self.handleWidth / 2
		)
	)

	return self
end

function OptionsRowProgress:SetOnChange(fn)
	self.onChangeFn = fn
	return self
end

function OptionsRowProgress:OnControl(control, down)
	if OptionsRowProgress._base.OnControl(self, control, down) then
		return true
	end

	if not self:IsEnabled() then
		return false
	end

	if control:Has(Controls.Digital.ACCEPT) then
		if down then
			if not self.down then
				TheFrontEnd:GetSound():PlaySound(fmodtable.Event.input_down)
				self.down = true
				self:StartUpdating()
				TheFrontEnd:LockFocus()
			end
		else
			if self.down then
				self.down = false
				self:StopUpdating()
				TheFrontEnd:LockFocus(false)
			end
		end

		return true
	end
end

-- Will only run if manually told to start updating: we don't want a bunch of unnecessarily updating widgets
function OptionsRowProgress:OnUpdate(dt)
	if self.down then
		self:WhileOnDown()
	end
end


------------------------------------------------------------------------------------------
--- A basic option row. Selectable, but doesn't do anything on its own. Meant to be extended
----
local OptionsScreenBaseRow = Class(Clickable, function(self, width, rightColumnWidth)
	Clickable._ctor(self, "OptionsScreenBaseRow")

	-- Set up sizings
	self.paddingH = 80
	self.paddingHRight = 40
	self.paddingV = 30
	self.width = width or 1600
	self.rightColumnWidth = rightColumnWidth or 300
	self.textWidth = self.width - self.rightColumnWidth - self.paddingH * 2 - self.paddingHRight -- padding on the left and right, and between the text and the right column
	self.height = 110

	-- Set up colors
	self.bgSelectedColor = UICOLORS.FOCUS
	self.bgUnselectedColor = HexToRGB(0xF6B74200)

	self.titleSelectedColor = UICOLORS.BACKGROUND_DARK
	self.titleUnselectedColor = UICOLORS.LIGHT_TEXT

	self.subtitleSelectedColor = UICOLORS.BACKGROUND_MID
	self.subtitleUnselectedColor = UICOLORS.LIGHT_TEXT_DARKER

	-- Build background
	self.bg = self:AddChild(Panel("images/ui_ftf_options/listrow_bg.tex"))
		:SetNineSliceCoords(40, 28, 508, 109)
		:SetSize(self.width, self.height)
		:SetMultColor(self.bgUnselectedColor)
	self.rightColumnHitbox = self:AddChild(Image("images/global/square.tex"))
		:SetSize(self.rightColumnWidth, self.height)
		:SetMultColor(HexToRGB(0xff00ff30))
		:LayoutBounds("right", "center", self.bg)
		:Offset(-self.paddingH, 0)
		:SetMultColorAlpha(0)


	-- Add text
	self.textContainer = self:AddChild(Widget("Text Container"))
	self.title = self.textContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.OPTIONS_ROW_TITLE, "", UICOLORS.WHITE))
		:LeftAlign()
	self.subtitle = self.textContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.OPTIONS_ROW_SUBTITLE, "", UICOLORS.WHITE))
		:OverrideLineHeight(FONTSIZE.OPTIONS_ROW_SUBTITLE * 0.85)
		:LeftAlign()

	-- Add right column container
	self.rightContainer = self:AddChild(Widget("Right Container"))

	-- Handle events
	self:SetScales(1, 1.02, 1.02, 0.2)
	self:SetOnGainFocus(function() self:OnFocusChange(true) end)
	self:SetOnLoseFocus(function() self:OnFocusChange(false) end)

	self:OnFocusChange(false)
end)

function OptionsScreenBaseRow:SetText(title, subtitle)

	self.title:SetText(title)
		:SetShown(title)
	self.subtitle:SetText(subtitle)
		:SetShown(subtitle)

	self:Layout()

	return self
end

function OptionsScreenBaseRow:SetSubtitle(subtitle)

	self.subtitle:SetText(subtitle)
		:SetShown(subtitle)

	self:Layout()

	return self
end

function OptionsScreenBaseRow:_TrySetValueToValue(option_key, desired)
	if self.values then
		for i,val in ipairs(self.values) do
			if deepcompare(val.data, desired) then
				--~ TheLog.ch.Settings:print(option_key, "set initial value to index", i)
				self:SetToValueIndex(i)
				return true
			end
		end
	else
		--~ TheLog.ch.Settings:print(option_key, "set initial value to ", desired)
		local silent = true
		self:_SetValue(desired, silent)
		return true
	end
	TheLog.ch.Settings:print(option_key, "FAILED to set initial value to ", desired)
end

function OptionsScreenBaseRow:HookupSetting(option_key, screen)
	-- If we wanted to lookup widgets by option name, we could track them like this:
	--   screen.options[option_key] = self
	self:SetOnValueChangeFn(function(data, valueIndex, value)
		--~ TheLog.ch.Settings:print(option_key, "value changed", data, valueIndex)
		TheGameSettings:Set(option_key, data)
		screen:MakeDirty()
	end)
	local current = TheGameSettings:Get(option_key)
	kassert.assert_fmt(current ~= nil, "gamesettings doesn't have a default for %s", option_key)
	self:_TrySetValueToValue(option_key, current)
	return self
end

function OptionsScreenBaseRow:SetValues(values)
	self.values = values or {}
	return self
end

function OptionsScreenBaseRow:SetToValueIndex(selectedIndex)
	self:_SetValue(selectedIndex)
end

function OptionsScreenBaseRow:SetOnValueChangeFn(onValueChangeFn)
	self.onValueChangeFn = onValueChangeFn
	return self
end

function OptionsScreenBaseRow:Layout()
	-- Position text
	self.title:SetAutoSize(self.textWidth)
	self.subtitle:SetAutoSize(self.textWidth)
		:LayoutBounds("left", "below", self.title)
		:Offset(0, 2)

	-- Get text size
	local textW, textH = self.textContainer:GetSize()

	-- Get right column size
	local rightW, rightH = self.rightContainer:GetSize()

	-- Resize the background to accomodate both
	self.height = math.max(textH, rightH) + self.paddingV * 2
	self.bg:SetSize(self.width, self.height)
	self.rightColumnHitbox:SetSize(self.rightColumnWidth, self.height)
		:Offset(-self.paddingHRight, 0)

	-- Position stuff
	self.textContainer:LayoutBounds("left", "center", self.bg)
		:Offset(self.paddingH, 0)
	self.rightContainer:LayoutBounds("right", "center", self.bg)
		:Offset(-self.paddingHRight, 0)
	self.rightColumnHitbox:LayoutBounds("right", "center", self.bg)
		:Offset(-self.paddingHRight, 0)

	return self
end

function OptionsScreenBaseRow:OnFocusChange(hasFocus)
	if hasFocus then
		self.bg:TintTo(nil, self.bgSelectedColor, 0.2, easing.outQuad)
		self.title:TintTo(nil, self.titleSelectedColor, 0.2, easing.outQuad)
		self.subtitle:TintTo(nil, self.subtitleSelectedColor, 0.2, easing.outQuad)
	else
		self.bg:TintTo(nil, self.bgUnselectedColor, 0.4, easing.outQuad)
		self.title:TintTo(nil, self.titleUnselectedColor, 0.4, easing.outQuad)
		self.subtitle:TintTo(nil, self.subtitleUnselectedColor, 0.4, easing.outQuad)
	end

	return self
end


------------------------------------------------------------------------------------------
--- An option row that allows you to loop through discrete values
----
local OptionsScreenSpinnerRow = Class(OptionsScreenBaseRow, function(self, width, rightColumnWidth)
	OptionsScreenBaseRow._ctor(self, width, rightColumnWidth)


	-- Set up sizings
	self.arrowSize = 60
	self.valueTextWidth = self.rightColumnWidth - self.arrowSize * 2


	-- Set up colors
	self.arrowSelectedColor = self.titleSelectedColor
	self.arrowFocusColor = self.subtitleSelectedColor
	self.arrowUnselectedColor = self.titleUnselectedColor
	self.paginationUnselectedColor = HexToRGB(0xB6965500)


	-- Build right column contents
	self.valueLeftArrow = self.rightContainer:AddChild(ImageButton("images/ui_ftf_options/pagination_left.tex"))
		:SetSize(self.arrowSize, self.arrowSize)
		:SetOnClick(function() self:OnArrowLeft() end)
		:SetScaleOnFocus(false)
	self.valueText = self.rightContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.OPTIONS_ROW_TITLE, "", UICOLORS.WHITE))
		:SetAutoSize(self.valueTextWidth)
	self.valueRightArrow = self.rightContainer:AddChild(ImageButton("images/ui_ftf_options/pagination_right.tex"))
		:SetSize(self.arrowSize, self.arrowSize)
		:SetOnClick(function() self:OnArrowRight() end)
		:SetScaleOnFocus(false)
	self.pagination = self.rightContainer:AddChild(OptionsRowPagination())

	-- Default values
	self.currentIndex = 0

	self:OnFocusChange(false)
end)

OptionsScreenSpinnerRow.CONTROL_MAP = {
	{
		control = Controls.Digital.MENU_ONCE_RIGHT,
		hint = function(self, left, right)
			-- table.insert(right, loc.format(LOC"UI.CONTROLS.NEXT", Controls.Digital.MENU_ONCE_RIGHT))
		end,
		fn = function(self)
			self:OnArrowRight()
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_ONCE_LEFT,
		hint = function(self, left, right)
			-- table.insert(right, loc.format(LOC"UI.CONTROLS.PREV", Controls.Digital.MENU_ONCE_LEFT))
		end,
		fn = function(self)
			self:OnArrowLeft()
			return true
		end,
	},
}

function OptionsScreenSpinnerRow:Layout()

	-- Layout right column elements
	self.valueLeftArrow:LayoutBounds("left", "center", self.rightColumnHitbox)
	self.valueRightArrow:LayoutBounds("right", "center", self.rightColumnHitbox)
	self.valueText:LayoutBounds("center", "center", self.rightColumnHitbox)
	self.pagination:LayoutBounds("center", "below", self.valueText)
		:Offset(0, -4)

	OptionsScreenSpinnerRow._base.Layout(self)

	self.rightContainer:LayoutBounds("right", "center", self.bg)
		:Offset(-self.paddingHRight, 0)

	return self
end

function OptionsScreenSpinnerRow:OnFocusChange(hasFocus)
	OptionsScreenSpinnerRow._base.OnFocusChange(self, hasFocus)

	if not self.valueText then
		return self
	end

	if hasFocus then
		self.valueText:TintTo(nil, self.titleSelectedColor, 0.2, easing.inOutQuad)
		self.pagination:TintTo(nil, self.titleSelectedColor, 0.2, easing.inOutQuad)
		self.valueLeftArrow:SetImageNormalColour(self.arrowSelectedColor)
			:SetImageFocusColour(self.arrowFocusColor)
		self.valueRightArrow:SetImageNormalColour(self.arrowSelectedColor)
			:SetImageFocusColour(self.arrowFocusColor)
	else
		self.valueText:TintTo(nil, self.titleUnselectedColor, 0.4, easing.inOutQuad)
		self.pagination:TintTo(nil, self.paginationUnselectedColor, 0.4, easing.inOutQuad)
		self.subtitle:TintTo(nil, self.subtitleUnselectedColor, 0.4, easing.inOutQuad)
		self.valueLeftArrow:SetImageNormalColour(self.arrowUnselectedColor)
			:SetImageFocusColour(self.arrowUnselectedColor)
		self.valueRightArrow:SetImageNormalColour(self.arrowUnselectedColor)
			:SetImageFocusColour(self.arrowUnselectedColor)
	end

	return self
end

function OptionsScreenSpinnerRow:SetValues(values)
	assert(type(values[1].data) ~= "boolean", "Use OptionsScreenToggleRow for bools.")
	-- I don't think there's a hard requirement on type, but you probably want
	-- an enum string since settings has support for them.
	assert(type(values[1].data) == "string" or type(values[1].data) == "number", "Are you storing the right kind of data?")

	OptionsScreenSpinnerRow._base.SetValues(self, values)
	if #self.values > 0 then
		-- TODO(dbriscoe): Does changing this to be after _SetValue break things?
		self.pagination:SetCount(#self.values)
	end

	return self
end

-- Updates the spinner to display this value's data
function OptionsScreenSpinnerRow:_SetValue(index)
	self.currentIndex = index
	self.pagination:SetCurrent(self.currentIndex)

	local valueData = self.values[self.currentIndex]

	if valueData then
		if valueData.name then
			self.valueText:SetText(valueData.name)
		end
		if valueData.desc then
			self:SetSubtitle(valueData.desc)
		end
	end

	if self.onValueChangeFn then
		self.onValueChangeFn(valueData.data, self.currentIndex, valueData)
	end
	return self
end

function OptionsScreenSpinnerRow:HidePagination()
	self.pagination:Hide()
	return self
end

function OptionsScreenSpinnerRow:OnArrowRight()
	if self.values then
		self.currentIndex = self.currentIndex + 1
		if self.currentIndex > #self.values then
			self.currentIndex = 1
		end
		self:_SetValue(self.currentIndex)
	end
	return self
end

function OptionsScreenSpinnerRow:OnArrowLeft()
	if self.values then
		self.currentIndex = self.currentIndex - 1
		if self.currentIndex < 1 then
			self.currentIndex = #self.values
		end
		self:_SetValue(self.currentIndex)
	end
	return self
end


------------------------------------------------------------------------------------------
--- An option row that allows you to loop through discrete values
----
local OptionsScreenDropdownRow = Class(OptionsScreenBaseRow, function(self, width, rightColumnWidth)
	OptionsScreenBaseRow._ctor(self, width, rightColumnWidth)

	-- Set up sizings
	self.rightPadding = 20 -- How much spacing to leave on the right, so right-most elements look aligned

	-- Set up colors
	self.dropdownBgSelectedColor = UICOLORS.LIGHT_TEXT_DARKER
	self.dropdownBgUnselectedColor = deepcopy(UICOLORS.LIGHT_TEXT_DARKER)
	self.dropdownBgUnselectedColor.a = 0.25
	self.dropdownButtonSelectedColor = UICOLORS.BACKGROUND_DARK
	self.dropdownButtonUnselectedColor = UICOLORS.LIGHT_TEXT_DARKER

	-- Build right column contents
	self.dropdown = self.rightContainer:AddChild(DropDown())
		:RightAlign()
		:SetOnValueChangeFn(function(index, data, value) self:_SetValue(index) end)

	-- Default values
	self.currentIndex = 0

	self:OnFocusChange(false)
	self:SetOnClick(function() self.dropdown:OnButtonClick() end)
end)

function OptionsScreenDropdownRow:Layout()
	-- Layout right column elements
	self.dropdown:LayoutBounds("right", "center", self.rightColumnHitbox)

	OptionsScreenDropdownRow._base.Layout(self)

	self.rightContainer:Offset(-self.rightPadding, 0)

	return self
end

function OptionsScreenDropdownRow:OnFocusChange(hasFocus)
	OptionsScreenDropdownRow._base.OnFocusChange(self, hasFocus)

	if not self.dropdown then
		return self
	end

	if hasFocus then
		self.dropdown:DropdownTintTo(self.dropdownBgSelectedColor, self.dropdownButtonSelectedColor, 0.2)

		self:SendToFront()
	else
		self.dropdown:DropdownTintTo(self.dropdownBgUnselectedColor, self.dropdownButtonUnselectedColor, 0.4)

		-- Close the dropdown if the row lost focus, and not to one of its children (like the dropdown)
		-- local childHasFocus = self:GetFocusChild()
		-- if childHasFocus
		-- and self.dropdown:IsListOpen() then
		-- 	self.dropdown:CloseList()
		-- end
	end

	return self
end

function OptionsScreenDropdownRow:SetValues(values)
	self.values = values or {}

	if #self.values > 0 then
		self.dropdown:SetValues(self.values)
	end

	return self
end

-- Updates the spinner to display this value's data
function OptionsScreenDropdownRow:_SetValue(index)
	self.currentIndex = index

	local valueData = self.values[self.currentIndex]

	if valueData then
		if valueData.desc then
			self:SetSubtitle(valueData.desc)
		end
	end

	if self.onValueChangeFn then
		self.onValueChangeFn(valueData.data, self.currentIndex, valueData)
	end
	return self
end


------------------------------------------------------------------------------------------
--- An option row that allows you to bind a control to a key
----
local OptionsScreenControlRow = Class(OptionsScreenBaseRow, function(self, width, rightColumnWidth)
	OptionsScreenBaseRow._ctor(self, width, rightColumnWidth)

	-- Set up sizings
	self.rightPadding = 20 -- How much spacing to leave on the right, so right-most elements look aligned

	-- Set up colors
	self.dropdownBgSelectedColor = UICOLORS.LIGHT_TEXT_DARKER
	self.dropdownBgUnselectedColor = deepcopy(UICOLORS.LIGHT_TEXT_DARKER)
	self.dropdownBgUnselectedColor.a = 0.25
	self.dropdownButtonSelectedColor = UICOLORS.BACKGROUND_DARK
	self.dropdownButtonUnselectedColor = UICOLORS.LIGHT_TEXT_DARKER

	-- Build right column contents
	self.keyWidget = self.rightContainer:AddChild(OptionsKeyBindingWidget())
		:SetOnBindingChange(function(keybinding) self:SetKeybinding(keybinding) end)

	self.missing_warn = self:AddChild(Widget("missing_warn"))
	self.missing_warn.text = self.missing_warn:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.OPTIONS_ROW_TITLE, STRINGS.UI.OPTIONSSCREEN.KEYBINDING_MISSING, UICOLORS.LIGHT_TEXT_WARN))

	-- Default values
	self.currentKeybinding = nil

	self:OnFocusChange(false)
	self:SetOnClick(function() self.keyWidget:OpenPopup() end)
end)

function OptionsScreenControlRow:ShowReadonlyBinding(control)
	self.keyWidget.valueText:SetText(TheInput:GetLabelForControl(control))
	self.missing_warn:SetMultColorAlpha(0)
	local fn = function()
		local popup = ConfirmDialog(
			nil,
			self.keyWidget.valueText,
			true
		)
			:SetTitle(STRINGS.UI.OPTIONSSCREEN.KEYBINDING_MOUSE_UNSUPPORTED.TITLE)
			:SetText(STRINGS.UI.OPTIONSSCREEN.KEYBINDING_MOUSE_UNSUPPORTED.BODY)
			:SetArrowUp()
			:SetCancelButtonText(STRINGS.UI.BUTTONS.OK)
			:HideYesButton()
			:HideNoButton()
			:CenterButtons()
			:SetOnDoneFn(function()
				TheFrontEnd:PopScreen()
			end)
		TheFrontEnd:PushScreen(popup)
	end
	-- Easier to force it to do our handling than multiple overrides.
	-- TODO(ui): Make Rows defer clicks to their internal widgets.
	self.keyWidget.OpenPopup = fn
	return self
end

function OptionsScreenControlRow:Layout()
	-- Layout right column elements
	self.keyWidget:LayoutBounds("right", "center", self.rightColumnHitbox)

	self.missing_warn:LayoutBounds("before", "center", self.rightContainer)
		:Offset(-50, 0)

	OptionsScreenControlRow._base.Layout(self)

	self.rightContainer:Offset(-self.rightPadding, 0)

	return self
end

function OptionsScreenControlRow:OnFocusChange(hasFocus)
	OptionsScreenControlRow._base.OnFocusChange(self, hasFocus)

	if not self.keyWidget then
		return self
	end

	if hasFocus then
		self.keyWidget:DropdownTintTo(self.dropdownBgSelectedColor, self.dropdownButtonSelectedColor, 0.2)
	else
		self.keyWidget:DropdownTintTo(self.dropdownBgUnselectedColor, self.dropdownButtonUnselectedColor, 0.4)
	end

	return self
end

function OptionsScreenControlRow:SetText(title, subtitle)
	OptionsScreenControlRow._base.SetText(self, title, subtitle)

	self.keyWidget:SetControl(title)

	return self
end

-- Updates the row to display this keybinding
function OptionsScreenControlRow:SetKeybinding(keybinding, skip_propagate)
	self.currentKeybinding = keybinding
	self:Refresh()

	if not skip_propagate and self.onValueChangeFn then
		self.onValueChangeFn(self.currentKeybinding)
	end

	return self
end

function OptionsScreenControlRow:SetBindDeviceTarget(target)
	self.keyWidget:SetBindDeviceTarget(target)
	return self
end

function OptionsScreenControlRow:HasValidBinding()
	return self.currentKeybinding and table.numkeys(self.currentKeybinding) > 0
end

function OptionsScreenControlRow:Refresh()
	self.keyWidget:SetKeybinding(self.currentKeybinding)
	self.missing_warn:SetShown(not self:HasValidBinding())
	return self
end


------------------------------------------------------------------------------------------
--- Displays a row with an on/off toggle option
----
local OptionsScreenToggleRow = Class(OptionsScreenBaseRow, function(self, width, rightColumnWidth)
	OptionsScreenBaseRow._ctor(self, width, rightColumnWidth)

	-- Set up sizings
	self.rightPadding = 40 -- How much spacing to leave on the right, so right-most elements look aligned

	-- Set up colors
	self.arrowSelectedColor = self.titleSelectedColor
	self.arrowFocusColor = self.subtitleSelectedColor
	self.arrowUnselectedColor = self.titleUnselectedColor
	self.paginationUnselectedColor = HexToRGB(0xB6965500)

	self:SetControlDownSound(nil)
	self:SetControlUpSound(nil)

	-- Build right column contents
	local palette = {
		primary_active = self.titleSelectedColor,
		primary_inactive = self.titleUnselectedColor,
	}
	self.toggleButton = self.rightContainer:AddChild(CheckBox(palette))
		:SetIsSlider(true)

	-- Default values
	self.currentIndex = 0

	self:OnFocusChange(false)
	local onclick = function() self:OnClick() end
	self:SetOnClick(onclick)
	self.toggleButton:SetOnClick(onclick)
end)

OptionsScreenToggleRow.CONTROL_MAP = {
}

function OptionsScreenToggleRow:Layout()
	-- Layout right column elements
	self.toggleButton:LayoutBounds("right", "center", self.rightColumnHitbox)
	self.toggleButton:Layout()

	OptionsScreenToggleRow._base.Layout(self)

	self.rightContainer:Offset(-self.rightPadding, 0)

	return self
end

function OptionsScreenToggleRow:OnFocusChange(hasFocus)
	OptionsScreenToggleRow._base.OnFocusChange(self, hasFocus)

	if not self.toggleButton then
		return self
	end

	self.toggleButton:OnFocusChange(hasFocus)

	return self
end

function OptionsScreenToggleRow:SetValues(values)
	kassert.typeof("boolean", values[1].data)
	return OptionsScreenToggleRow._base.SetValues(self, values)
end

-- Updates the spinner to display this value's data
function OptionsScreenToggleRow:_SetValue(index)
	self.currentIndex = index

	local valueData = self.values[self.currentIndex]

	if valueData then
		if valueData.desc then
			self:SetSubtitle(valueData.desc)
		end
	end

	self.toggleButton:SetValue(self.currentIndex == 1)
	self:Layout()

	if self.onValueChangeFn then
		self.onValueChangeFn(valueData.data, self.currentIndex, valueData)
	end

	return self
end

function OptionsScreenToggleRow:OnClick()
	if self.values then
		self.currentIndex = self.currentIndex + 1
		if self.currentIndex > #self.values then
			self.currentIndex = 1
		end

		if self.currentIndex == 1 then
			TheFrontEnd:GetSound():PlaySound(self.toggleButton.toggleon_sound)
		else
			TheFrontEnd:GetSound():PlaySound(self.toggleButton.toggleoff_sound)
		end

		self:_SetValue(self.currentIndex)
	end
	return self
end


------------------------------------------------------------------------------------------
--- An options row that allows you to choose a value within a range (useful for audio volume)
----
local OptionsScreenVolumeRow = Class(OptionsScreenBaseRow, function(self, width, rightColumnWidth, is_sad_when_muted)
	OptionsScreenBaseRow._ctor(self, width, rightColumnWidth)

	-- Set up sizings
	self.rightPadding = 40 -- How much spacing to leave on the right, so right-most elements look aligned
	self.leftPadding = 40 -- How much spacing to leave on the left, so left-most elements look aligned
	self.valueTextWidth = 120
	self.progressBarWidth = self.rightColumnWidth - self.valueTextWidth - self.leftPadding - self.rightPadding

	-- Set up colors
	self.arrowSelectedColor = self.titleSelectedColor
	self.arrowFocusColor = self.subtitleSelectedColor
	self.arrowUnselectedColor = self.titleUnselectedColor
	self.handleFocusColor = HexToRGB(0xF9F0C4FF)
	self.handleUnselectedColor = HexToRGB(0xF9F0C400)

	-- Default values
	self.minValue = 0
	self.maxValue = 100
	self.currentIndex = 0
	self.isPercent = false
	self.displayFormat = "%.0f"

	-- Build right column contents
	self.valueText = self.rightContainer:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.OPTIONS_ROW_TITLE, "", UICOLORS.WHITE))
		:RightAlign()
	self.progress = self.rightContainer:AddChild(OptionsRowProgress(self.progressBarWidth, self.minValue, self.maxValue, self.currentIndex))
		:SetOnChange(function(value) self:_SetValue(value) end)

	if is_sad_when_muted then
		self.muted_emotion = self:AddChild(Image("images/ui_ftf_options/ic_sadcabbage.tex"))
			:SetScale(0.5)
			:AlphaTo(0, 0)
	end

	self:OnFocusChange(false)

	self:SetOnUp(function()
		--fallback code to catch errant loop
		if TheFrontEnd:GetSound():IsPlayingSound("options_volume_sound") then
			TheFrontEnd:GetSound():KillSound("options_volume_sound")
		end
	end)

end)

OptionsScreenVolumeRow.CONTROL_MAP = {
	{
		control = Controls.Digital.MENU_RIGHT,
		hint = function(self, left, right)
			-- table.insert(right, loc.format(LOC"UI.CONTROLS.PREV_TAB", Controls.Digital.MENU_TAB_PREV))
		end,
		fn = function(self)
			self:OnArrowRight()
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_LEFT,
		hint = function(self, left, right)
			-- table.insert(right, loc.format(LOC"UI.CONTROLS.NEXT_TAB", Controls.Digital.MENU_TAB_NEXT))
		end,
		fn = function(self)
			self:OnArrowLeft()
			return true
		end,
	},
}

function OptionsScreenVolumeRow:Layout()
	-- Layout right column elements
	self.progress:LayoutBounds("left", "center", self.rightColumnHitbox)
		:Offset(self.leftPadding, 0)
	self.valueText:LayoutBounds("right", "center", self.rightColumnHitbox)
		:Offset(-self.rightPadding, 0)

	if self.muted_emotion then
		self.muted_emotion:LayoutBounds("after", "center", self.rightColumnHitbox)
			:Offset(70, 0)
	end

	OptionsScreenVolumeRow._base.Layout(self)

	self.rightContainer:Offset(-self.rightPadding, 0)

	return self
end

function OptionsScreenVolumeRow:OnFocusChange(hasFocus)
	OptionsScreenVolumeRow._base.OnFocusChange(self, hasFocus)

	if not self.progress then
		return self
	end

	if hasFocus then
		self.valueText:TintTo(nil, self.titleSelectedColor, 0.2, easing.inOutQuad)
		self.progress:BarTintTo(self.titleSelectedColor, self.handleFocusColor, 0.2)
	else
		self.valueText:TintTo(nil, self.titleUnselectedColor, 0.4, easing.inOutQuad)
		--fallback code to catch errant loop
		if TheFrontEnd:GetSound():IsPlayingSound("options_volume_sound") then
			TheFrontEnd:GetSound():KillSound("options_volume_sound")
		end
		self.progress:BarTintTo(self.arrowUnselectedColor, self.handleUnselectedColor, 0.4)
	end

	return self
end

function OptionsScreenVolumeRow:SetSoundOnChange(sound_on_change)
	self.sound_on_change = sound_on_change
	return self
end

function OptionsScreenVolumeRow:SetRange(min, max, stepSize)
	self.minValue = min
	self.maxValue = max
	self.currentIndex = self.minValue
	self.stepSize = 10

	self.progress:SetRange(self.minValue, self.maxValue)
	self:_SetValue(self.currentIndex, true)
	self:Layout()

	return self
end

function OptionsScreenVolumeRow:SetPercent(isPercent)
	self.isPercent = isPercent or false
	return self
end

function OptionsScreenVolumeRow:SetStepSize(stepSize)
	self.stepSize = stepSize or 10
	return self
end

function OptionsScreenVolumeRow:SetDisplayFormat(displayFormat)
	self.displayFormat = displayFormat or "%d"
	return self
end

local function KillPreviewSound()
	TheFrontEnd:GetSound():KillSound("options_volume_sound")
end

-- Updates the progress to display this value
function OptionsScreenVolumeRow:_SetValue(value, silent)
	kassert.typeof('number', value)
	self.currentIndex = value
	local displayValue = string.format(self.displayFormat, self.currentIndex)
	displayValue = displayValue .. (self.isPercent and "%" or "")

	self.valueText:SetText(displayValue)
	self.progress:SetCurrent(self.currentIndex, displayValue)
	if self.muted_emotion then
		local a = 0
		if value == 0 then
			a = 1
		end
		self.muted_emotion
			:AlphaTo(a, 0.7 + a * 0.5, easing.inOutQuad)
	end
	self:Layout()

	if not silent and self.sound_on_change then
		if self.cancel_task then
			self.cancel_task:Cancel()
		end
		local sound = TheFrontEnd:GetSound()
		-- Only play if not playing to avoid interrupting the sound which is
		-- terrible to hear.
		-- TODO(dbriscoe): Maybe handle this in fmod instead?
		if not sound:IsPlayingSound("options_volume_sound") then
			sound:PlaySound(self.sound_on_change, "options_volume_sound")
		end
		self.cancel_task = self.inst:DoTaskInTime(0.25, KillPreviewSound)
	end

	if self.onValueChangeFn then
		-- Volume is continuous, so data and index are the same.
		self.onValueChangeFn(self.currentIndex, self.currentIndex)
	end

	return self
end


function OptionsScreenVolumeRow:OnArrowRight()
	self.currentIndex = self.currentIndex + self.stepSize
	if self.currentIndex > self.maxValue then
		self.currentIndex = self.maxValue
	end
	self:_SetValue(self.currentIndex)
	return self
end

function OptionsScreenVolumeRow:OnArrowLeft()
	self.currentIndex = self.currentIndex - self.stepSize
	if self.currentIndex < self.minValue then
		self.currentIndex = self.minValue
	end
	self:_SetValue(self.currentIndex)
	return self
end

------------------------------------------------------------------------------------------
--- The options screen
----
local OptionsScreen = Class(Screen, function(self)
	Screen._ctor(self, "OptionsScreen")
	--sound
	self:SetAudioCategory(Screen.AudioCategory.s.Fullscreen)
	self:SetAudioExitOverride(nil)

	-- Setup sizings
	self.rowWidth = 2520
	self.rowRightColumnWidth = 880
	self.rowSpacing = 120

	-- Add background
	self.bg = self:AddChild(templates.BackgroundImage("images/ui_ftf_options/optionsscreen_bg.tex"))

	-- Add nav header
	self.navbarWidth = RES_X - 160
	self.navbarHeight = 180
	local icon_size = FONTSIZE.OPTIONS_SCREEN_TAB * 1.1

	self.navbar = self:AddChild(Widget("navbar"))
		:LayoutBounds("center", "top", self.bg)
		:Offset(0, -150)
	self.navbar.bg = self.navbar:AddChild(Panel("images/ui_ftf_options/topbar_bg.tex"))
		:SetNineSliceCoords(40, 0, 560, 170)
		:SetSize(self.navbarWidth, self.navbarHeight)
		:SetMultColor(HexToRGB(0x0F0C0AFF))
	self.navbar.tabs = self.navbar:AddChild(TabGroup())
		:SetTheme_LightTransparentOnDark()
		:SetFontSize(FONTSIZE.OPTIONS_SCREEN_TAB)


	-- Add navbar options
	self.tabs = {}
	self.tabs.gameplay = self.navbar.tabs:AddIconTextTab("images/ui_ftf_options/ic_gameplay.tex", STRINGS.UI.OPTIONSSCREEN.NAVBAR_GAMEPLAY)
	-- Sound
	--self.tabs.gameplay:SetControlDownSound(fmodtable.Event.input_down_mainMenu)
	--self.tabs.gameplay:SetControlUpSound(fmodtable.Event.input_up_mainMenu)
	self.tabs.gameplay:SetGainFocusSound(fmodtable.Event.hover)

	self.tabs.graphics = self.navbar.tabs:AddIconTextTab("images/ui_ftf_options/ic_graphics.tex", STRINGS.UI.OPTIONSSCREEN.NAVBAR_GRAPHICS)
	-- Sound
	--self.tabs.graphics:SetControlDownSound(fmodtable.Event.input_down_mainMenu)
	--self.tabs.graphics:SetControlUpSound(fmodtable.Event.input_up_mainMenu)
	self.tabs.graphics:SetGainFocusSound(fmodtable.Event.hover)

	self.tabs.audio    = self.navbar.tabs:AddIconTextTab("images/ui_ftf_options/ic_audio.tex", STRINGS.UI.OPTIONSSCREEN.NAVBAR_AUDIO)
	-- Sound
	--self.tabs.audio:SetControlDownSound(fmodtable.Event.input_down_mainMenu)
	--self.tabs.audio:SetControlUpSound(fmodtable.Event.input_up_mainMenu)
	self.tabs.audio:SetGainFocusSound(fmodtable.Event.hover)

	self.tabs.controls = self.navbar.tabs:AddIconTextTab("images/ui_ftf_options/ic_controls.tex", STRINGS.UI.OPTIONSSCREEN.NAVBAR_CONTROLS)
	-- Sound
	--self.tabs.controls:SetControlDownSound(fmodtable.Event.input_down_mainMenu)
	--self.tabs.controls:SetControlUpSound(fmodtable.Event.input_up_mainMenu)
	self.tabs.controls:SetGainFocusSound(fmodtable.Event.hover)

	self.tabs.other    = self.navbar.tabs:AddIconTextTab("images/ui_ftf_options/ic_other.tex", STRINGS.UI.OPTIONSSCREEN.NAVBAR_OTHER)
	-- Sound
	--self.tabs.other:SetControlDownSound(fmodtable.Event.input_down_mainMenu)
	--self.tabs.other:SetControlUpSound(fmodtable.Event.input_up_mainMenu)
	self.tabs.other:SetGainFocusSound(fmodtable.Event.hover)

	local tab_count = lume.count(self.tabs)
	self.navbar.tabs
		:SetTabSize(nil, icon_size)
		:SetTabOnClick(function(tab_btn) self:OnChangeTab(tab_btn) end)
		:SetNavFocusable(false) -- rely on CONTROL_MAP
		:LayoutChildrenInGrid(tab_count + 2, 90)
		:LayoutBounds("center", "center", self.navbar.bg)
		:AddCycleIcons()


	-- Add navbar back button
	self.backButton = self.navbar:AddChild(templates.BackButton())
		:SetNormalScale(0.8)
		:SetFocusScale(0.85)
		:SetSecondary()
		:LayoutBounds("left", "center", self.navbar.bg)
		:Offset(40, 0)
		:SetOnClick(function() self:OnClickClose() end)


	self.unbound_control = self.backButton:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.OPTIONS_ROW_TITLE, STRINGS.UI.OPTIONSSCREEN.KEYBINDING_MISSING, UICOLORS.LIGHT_TEXT_WARN))
		:LayoutBounds("center", "below", self.backButton)
		:Offset(0, -20)
		:Hide()


	-- Add navbar save button
	self.saveButton = self.navbar:AddChild(templates.AcceptButton(STRINGS.UI.OPTIONSSCREEN.SAVE_BUTTON))
		:SetNormalScale(0.8)
		:SetFocusScale(0.85)
		:SetPrimary()
		:LayoutBounds("right", "center", self.navbar.bg)
		:Offset(-50, 0)
		:SetOnClick(function() self:OnClickSave() end)
		:Hide()
		:SetControlUpSound(fmodtable.Event.ui_input_up_confirm_save)

	-- Add a confirmation label to be displayed when the options are saved
	self.saveConfirmationLabel = self.navbar:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.OPTIONS_SCREEN_TAB))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetAutoSize(600)
		:SetText(STRINGS.UI.OPTIONSSCREEN.SAVED_OPTIONS_LABEL)
		:LayoutBounds("center", "center", self.saveButton)
		:SetMultColorAlpha(0)
	self.labelX, self.labelY = self.saveConfirmationLabel:GetPosition()

	-- Add scrolling panel below the navbar
	self.scrollSideMargin = 60
	self.scrollTopMargin = 220
	self.scroll = self:AddChild(ScrollPanel())
		:SetSize(RES_X - self.scrollSideMargin * 2, RES_Y - self.scrollTopMargin)
		:SetVirtualMargin(200)
		:SetVirtualBottomMargin(1000)
		:LayoutBounds("center", "bottom", self.bg)
	self.scrollContents = self.scroll:AddScrollChild(Widget())

	-- Add tab-specific views
	self.pages = {}
	self.pages.gameplay = self.scrollContents:AddChild(Widget("Page Gameplay"))
	self.pages.graphics = self.scrollContents:AddChild(Widget("Page Graphics"))
	self.pages.audio = self.scrollContents:AddChild(Widget("Page Audio"))
	self.pages.controls = self.scrollContents:AddChild(Widget("Page Gameplay"))
	self.pages.other = self.scrollContents:AddChild(Widget("Page Gameplay"))

	-- Hide pages: we'll show the first one later. Hookup to tabs for click handler.
	for id,page in pairs(self.pages) do
		page:Hide()
		local tab = self.tabs[id]
		assert(tab)
		tab.page = page
	end

	-- Validate tabs and pages match up.
	for id,tab in pairs(self.tabs) do
		assert(self.pages[id])
	end


	self.settings_backup = deepcopy(TheGameSettings:GetSaveData())
	self.language_on_enter = TheGameSettings:Get("language.selected")

	-- Fill up all the pages with content!
	self:_BuildGameplayPage()
	self:_BuildGraphicsPage()
	self:_BuildAudioPage()
	self:_BuildControlsPage()
	self:_BuildOtherPage()

	dbassert(not self:IsDirty(), "Shouldn't be dirty before making changes. Are we clamping? (Should migrate save data in gamesettings.)")

	-- Add a gradient fading out the options at the bottom of the screen
	self.bottomGradientFade = self:AddChild(Image("images/ui_ftf_options/bottom_gradient.tex"))
		:SetSize(RES_X, 600)
		:LayoutBounds("center", "bottom", self.bg)
	-- Move the gradient into the scroll panel, so I can place the scroll bar on top
	self.bottomGradientFade:Reparent(self.scroll)
	self.scroll.scroll_bar:SendToFront()

	-- Position navbar in front of the scroll panel
	self.navbar:SendToFront()
end)

OptionsScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.MENU_SCREEN_ADVANCE,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.ACCEPT", Controls.Digital.MENU_SCREEN_ADVANCE))
		end,
		fn = function(self)
			self:OnClickClose()
			return true
		end,
	},
	{
		control = Controls.Digital.CANCEL,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.CANCEL", Controls.Digital.CANCEL))
		end,
		fn = function(self)
			self:OnClickClose()
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_TAB_PREV,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.PREV_TAB", Controls.Digital.MENU_TAB_PREV))
		end,
		fn = function(self)
			self:NextTab(-1)
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.hover)
			return true
		end,
	},
	{
		control = Controls.Digital.MENU_TAB_NEXT,
		hint = function(self, left, right)
			table.insert(right, loc.format(LOC"UI.CONTROLS.NEXT_TAB", Controls.Digital.MENU_TAB_NEXT))
		end,
		fn = function(self)
			self:NextTab(1)
			TheFrontEnd:GetSound():PlaySound(fmodtable.Event.hover)
			return true
		end,
	},
}


function OptionsScreen:NextTab(direction)
	if self.navbar.tabs:IsVisible() then
		self.navbar.tabs:NextTab(direction)
	end
end

local function FindFirstNavChild(w)
	for _,child in ipairs(w:GetChildren()) do
		if child.can_focus_with_nav then
			return child
		end
	end
end

function OptionsScreen:OnChangeTab(tabButton)
	for _,page in pairs(self.pages) do
		page:Hide()
	end

	assert(tabButton.page)
	self.currentPage = tabButton.page

	-- Show current page
	self.currentPage:Show()

	-- Update default_focus so we return to a visible widget if we switch to
	-- gamepad.
	if self.currentPage:IsEmpty() then
		self.default_focus = self.backButton
	else
		self.default_focus = FindFirstNavChild(self.currentPage) or self.backButton
	end
	self.default_focus:SetFocus()

	-- DEBUG: Useful to preview the bounds of the scroll panel
	-- self.scrollContents:AddChild(Image("images/global/square.tex"))
	-- 	:SetMultColor(HexToRGB(0xff00ff30))
	-- 	:SetSize(5000, 5000)

	self.scroll:RefreshView()

	return self
end

local function StandardValue(strings_t, data)
	return { name = strings_t.NAME, desc = strings_t.DESC, data = data }
end

function OptionsScreen:_BuildGameplayPage()

	--~ self.pages.gameplay:AddChild(OptionsScreenVolumeRow(self.rowWidth, self.rowRightColumnWidth))
	--~ 	:SetText("Dialog speed", "The dialog speed in the game.")
	--~ 	:SetDisplayFormat("%.1fx")
	--~ 	:SetRange(0.5, 4)
	--~ 	:SetStepSize(0.1)
	--~ 	:HookupSetting("gameplay.dialog_speed", self)

	--~ self.pages.gameplay:AddChild(OptionsScreenVolumeRow(self.rowWidth, self.rowRightColumnWidth))
	--~ 	:SetText("Animation speed", "The speed of presentation animations in the game.")
	--~ 	:SetDisplayFormat("%.1fx")
	--~ 	:SetRange(0.5, 4)
	--~ 	:SetStepSize(0.1)
	--~ 	:HookupSetting("gameplay.animation_speed", self)


	self.pages.gameplay:AddChild(OptionsScreenToggleRow(self.rowWidth, self.rowRightColumnWidth))
		:SetText(STRINGS.UI.OPTIONSSCREEN.GAMEPLAY_VIBRATION)
		:SetValues({
			{	name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.GAMEPLAY_VIBRATION.ON.NAME,
				desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.GAMEPLAY_VIBRATION.ON.DESC, data = true },

			{	name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.GAMEPLAY_VIBRATION.OFF.NAME,
				desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.GAMEPLAY_VIBRATION.OFF.DESC, data = false },
		})
		:HookupSetting("gameplay.vibration", self)

	self.pages.gameplay:AddChild(OptionsScreenToggleRow(self.rowWidth, self.rowRightColumnWidth))
		:SetText(STRINGS.UI.OPTIONSSCREEN.GAMEPLAY_MOUSE_AIMING)
		:SetValues({
			{	name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.GAMEPLAY_MOUSE_AIMING.ON.NAME,
				desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.GAMEPLAY_MOUSE_AIMING.ON.DESC, data = true },

			{	name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.GAMEPLAY_MOUSE_AIMING.OFF.NAME,
				desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.GAMEPLAY_MOUSE_AIMING.OFF.DESC, data = false },
		})
		:HookupSetting("gameplay.mouseaiming", self)


	self.pages.gameplay:LayoutChildrenInGrid(1, self.rowSpacing)

	return self
end

function OptionsScreen:_BuildGraphicsPage()

	if not Platform.IsBigPictureMode() then
		self.pages.graphics:AddChild(OptionsScreenToggleRow(self.rowWidth, self.rowRightColumnWidth))
			:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.FULLSCREEN.TITLE)
			:SetValues({
				{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.FULLSCREEN.ON.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.FULLSCREEN.ON.DESC, data = true },
				{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.FULLSCREEN.OFF.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.FULLSCREEN.OFF.DESC, data = false },
			})
			:HookupSetting("graphics.fullscreen", self)
	end


	-- self.pages.graphics:AddChild(OptionsScreenDropdownRow(self.rowWidth, self.rowRightColumnWidth))
	-- 	:SetText("Resolution", "The size of the window in pixels.")
	-- 	:SetValues({
	-- 		{ name = "1280x720", data = { w = 1280, h = 720 } },
	-- 		{ name = "1440x810", data = { w = 1440, h = 810 } },
	-- 		{ name = "1600x900", data = { w = 1600, h = 900 } },
	-- 		{ name = "1760x990", data = { w = 1760, h = 990 } },
	-- 		{ name = "1920x1080", data = { w = 1920, h = 1080 } },
	-- 		{ name = "2240x1260", data = { w = 2240, h = 1260 } },
	-- 		{ name = "2560x1440", data = { w = 2560, h = 1440 } },
	-- 		{ name = "2880x1620", data = { w = 2880, h = 1620 } },
	-- 		{ name = "3200x1800", data = { w = 3200, h = 1800 } },
	-- 		{ name = "3840x2160", data = { w = 3840, h = 2160 } },
	-- 	})
	-- 	:HookupSetting("graphics.resolution", self)


	self.pages.graphics:AddChild(OptionsScreenSpinnerRow(self.rowWidth, self.rowRightColumnWidth))
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.CURSOR_SIZE.TITLE)
		:SetValues({
			StandardValue(STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.CURSOR_SIZE.SMALL, cursor.Size.s.small),
			StandardValue(STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.CURSOR_SIZE.NORMAL, cursor.Size.s.normal),
			StandardValue(STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.CURSOR_SIZE.LARGE, cursor.Size.s.large),
			StandardValue(STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.CURSOR_SIZE.SYSTEM, cursor.Size.s.SYSTEM),
		})
		:HookupSetting("graphics.cursor_size", self)


	self.pages.graphics:AddChild(OptionsScreenToggleRow(self.rowWidth, self.rowRightColumnWidth))
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.BLOOM.TITLE)
		:SetValues({
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.BLOOM.ON.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.BLOOM.ON.DESC, data = true },
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.BLOOM.OFF.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.BLOOM.OFF.DESC, data = false },
		})
		:HookupSetting("graphics.bloom", self)

	self.pages.graphics:AddChild(OptionsScreenToggleRow(self.rowWidth, self.rowRightColumnWidth))
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.RIM_LIGHTING.TITLE)
		:SetValues({
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.RIM_LIGHTING.ON.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.RIM_LIGHTING.ON.DESC, data = true },
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.RIM_LIGHTING.OFF.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.RIM_LIGHTING.OFF.DESC, data = false },
		})
		:HookupSetting("graphics.rimlighting", self)

	self.pages.graphics:AddChild(OptionsScreenToggleRow(self.rowWidth, self.rowRightColumnWidth))
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SHADOWS.TITLE)
		:SetValues({
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SHADOWS.ON.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SHADOWS.ON.DESC, data = true },
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SHADOWS.OFF.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SHADOWS.OFF.DESC, data = false },
		})
		:HookupSetting("graphics.shadows", self)

	--~ self.pages.graphics:AddChild(OptionsScreenSpinnerRow(self.rowWidth, self.rowRightColumnWidth))
	--~ 	:SetText("Level of detail")
	--~ 	:SetValues({
	--~ 		{
	--~ 			name = "HIGH",
	--~ 			desc = "High quality textures, fog and distance blur. More graphically demanding. Requires restarting the game to fully apply.",
	--~ 			data = 1,
	--~ 		},
	--~ 		{
	--~ 			name = "MEDIUM",
	--~ 			desc = "Balance between graphical quality and performance cost.",
	--~ 			data = 2,
	--~ 		},
	--~ 		{
	--~ 			name = "LOW",
	--~ 			desc = "Increased performance by lowering the fog, texture resolution, and distance blur quality. Requires restarting the game to fully apply.",
	--~ 			data = 0,
	--~ 		},
	--~ 	})
	--~ 	:HookupSetting("graphics.lod", self)


	self.pages.graphics:AddChild(OptionsScreenToggleRow(self.rowWidth, self.rowRightColumnWidth))
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SCREEN_SHAKE.TITLE)
		:SetValues({
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SCREEN_SHAKE.ON.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SCREEN_SHAKE.ON.DESC, data = true },
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SCREEN_SHAKE.OFF.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SCREEN_SHAKE.OFF.DESC, data = false },
		})
		:HookupSetting("graphics.screen_shake", self)


	self.pages.graphics:AddChild(OptionsScreenToggleRow(self.rowWidth, self.rowRightColumnWidth))
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SCREEN_FLASH.TITLE)
		:SetValues({
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SCREEN_FLASH.ON.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SCREEN_FLASH.ON.DESC, data = true },
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SCREEN_FLASH.OFF.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.VIDEO.SCREEN_FLASH.OFF.DESC, data = false },
		})
		:HookupSetting("graphics.screen_flash", self)


	self.pages.graphics:LayoutChildrenInGrid(1, self.rowSpacing)

	return self
end

function OptionsScreen:_BuildAudioPage()

	self.audio_device_options = { {
			default = true,
			name = STRINGS.UI.OPTIONSSCREEN.AUDIO_SYSTEM_DEFAULT,
			data = -1,
	}}
	for _, audio_device in ipairs(TheAudio:GetOutputDevices() or {}) do
		table.insert(self.audio_device_options, {
				default = false,
				name = audio_device.name,
				data = audio_device.id,
			})
	end

	local audio_spinner = self.pages.audio:AddChild(OptionsScreenSpinnerRow(self.rowWidth, self.rowRightColumnWidth))
	audio_spinner
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.OUTPUT_DEVICE.NAME, STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.OUTPUT_DEVICE.DESC)
		:SetValues(self.audio_device_options)
		:HidePagination()
		:HookupSetting("audio.devicename", self)
		:SetFocusDir("right", audio_spinner, true)


	local ListenEnv = TheGameSettings:EnumForSetting("audio.listening_environment")
	self.listening_envs = {}
	for _,env in ipairs(ListenEnv:Ordered()) do
		table.insert(self.listening_envs, {
				name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.ENVIRONMENT_NAME[env],
				desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.ENVIRONMENT_DESC[env],
				data = env,
			})
	end

	local environment_spinner = self.pages.audio:AddChild(OptionsScreenSpinnerRow(self.rowWidth, self.rowRightColumnWidth))
	environment_spinner
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.ENVIRONMENT_TITLE)
		:SetValues(self.listening_envs)
		:HookupSetting("audio.listening_environment", self)
		:SetFocusDir("right", environment_spinner, true)


	self.pages.audio:AddChild(OptionsScreenToggleRow(self.rowWidth, self.rowRightColumnWidth))
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.FORCE_MONO_MIX.TITLE)
		:SetValues({
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.FORCE_MONO_MIX.ON.NAME,
			desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.FORCE_MONO_MIX.ON.DESC, data = true
			},
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.FORCE_MONO_MIX.OFF.NAME,
			desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.FORCE_MONO_MIX.OFF.DESC, data = false
			},
		})
		:HookupSetting("audio.force_mono", self)


	self.pages.audio:AddChild(OptionsScreenToggleRow(self.rowWidth, self.rowRightColumnWidth))
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.MUTE_LOSE_FOCUS.TITLE)
		:SetValues({
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.MUTE_LOSE_FOCUS.ON.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.MUTE_LOSE_FOCUS.ON.DESC, data = true },
			{ name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.MUTE_LOSE_FOCUS.OFF.NAME, desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.MUTE_LOSE_FOCUS.OFF.DESC, data = false },
		})
		:HookupSetting("audio.mute_on_lost_focus", self)


	local master_volume = self.pages.audio:AddChild(OptionsScreenVolumeRow(self.rowWidth, self.rowRightColumnWidth, true))
	master_volume
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.VOLUME.MASTER.NAME, STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.VOLUME.MASTER.DESC)
		:SetPercent(true)
		:SetRange(0, 100)
		:SetStepSize(5)
		:HookupSetting("audio.master_volume", self)
		:SetSoundOnChange(fmodtable.Event.blarmadillo_trumpet)
		:SetFocusDir("right", master_volume, true)


	local music_volume = self.pages.audio:AddChild(OptionsScreenVolumeRow(self.rowWidth, self.rowRightColumnWidth))
	music_volume
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.VOLUME.MUSIC.NAME, STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.VOLUME.MUSIC.DESC)
		:SetPercent(true)
		:SetRange(0, 100)
		:SetStepSize(5)
		:HookupSetting("audio.music_volume", self)
		:SetFocusDir("right", music_volume, true)

	local sfx_volume = self.pages.audio:AddChild(OptionsScreenVolumeRow(self.rowWidth, self.rowRightColumnWidth))
	sfx_volume
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.VOLUME.SFX.NAME, STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.VOLUME.SFX.DESC)
		:SetPercent(true)
		:SetRange(0, 100)
		:SetStepSize(5)
		:HookupSetting("audio.sfx_volume", self)
		:SetSoundOnChange(fmodtable.Event.OptionsMenu_SFXVol_Test)
		:SetFocusDir("right", sfx_volume, true)


	local voice_volume = self.pages.audio:AddChild(OptionsScreenVolumeRow(self.rowWidth, self.rowRightColumnWidth))
	voice_volume
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.VOLUME.VOICE.NAME, STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.VOLUME.VOICE.DESC)
		:SetPercent(true)
		:SetRange(0, 100)
		:SetStepSize(5)
		:HookupSetting("audio.voice_volume", self)
		:SetSoundOnChange(fmodtable.Event.OptionsMenu_Voice_Test)
		:SetFocusDir("right", voice_volume, true)

	local ambience_volume = self.pages.audio:AddChild(OptionsScreenVolumeRow(self.rowWidth, self.rowRightColumnWidth))
	ambience_volume
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.VOLUME.AMBIENCE.NAME, STRINGS.UI.OPTIONSSCREEN.SETTINGS.AUDIO.VOLUME.AMBIENCE.DESC)
		:SetPercent(true)
		:SetRange(0, 100)
		:SetStepSize(5)
		:HookupSetting("audio.ambience_volume", self)
		:SetSoundOnChange(fmodtable.Event.OptionsMenu_Amb_Test_LP)
		:SetFocusDir("right", ambience_volume, true)


	self.pages.audio:LayoutChildrenInGrid(1, self.rowSpacing)

	return self
end

function OptionsScreen:_HighlightInvalidBindings(bind_widgets)
	local are_all_valid = true
	for bind_target,device_widgets in pairs(bind_widgets) do
		for settings_key,w in pairs(device_widgets) do
			local bind_set = TheGameSettings:Get(settings_key)
			w:SetKeybinding(bind_set[bind_target], true)
			are_all_valid = are_all_valid and w:HasValidBinding()
		end
	end
	self.unbound_control:SetShown(not are_all_valid)
end

function OptionsScreen:_BuildControlsPage()
	-- Show reset first to make it easy to find and obvious that it exists.
	self.pages.controls:AddChild(OptionsScreenCategoryTitle(self.rowWidth, STRINGS.UI.OPTIONSSCREEN.BIND_SECTIONS.ADMIN))
	self.pages.controls:AddChild(OptionsScreenBaseRow(self.rowWidth, self.rowRightColumnWidth))
		:SetText(
			STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.RESET_BINDINGS.TITLE,
			STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.RESET_BINDINGS.DESC
		)
		:SetOnClick(function()
			local confirm = ConfirmDialog(nil, nil, true,
				STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.RESET_BINDINGS.CONFIRM,
				nil,
				STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.RESET_BINDINGS.DESC,
				function(should_reset)
					TheFrontEnd:PopScreen() -- popup
					if should_reset then
						TheGameSettings:ResetBindingsToDefaults()
						self:_SaveChanges(function()
							-- exit screen because settings are out of date
							self:_AnimateOut()
						end)
					end
				end)
				:HideArrow()
				:SetYesButtonText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.RESET_BINDINGS.YES)
				:SetNoButtonText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.CONTROLS.RESET_BINDINGS.NO)
			TheFrontEnd:PushScreen(confirm)
		end)



	local bind_widgets = {}
	local bind_settings = {}

	local function ConfigureKeybind(bind_target, settings_key, control)
		local binding_pretty_label = TheInput:GetControlPrettyName(control)
		table.insert(bind_settings, settings_key)
		local bind_set = TheGameSettings:Get(settings_key)
		local bind_row = self.pages.controls:AddChild(OptionsScreenControlRow(self.rowWidth, self.rowRightColumnWidth))
			:SetText(binding_pretty_label)
			:SetKeybinding(bind_set[bind_target])
			:SetBindDeviceTarget(bind_target)
			:SetOnValueChangeFn(function(keybinding)
				TheLog.ch.Input:printf("User changed binding '%s': %s", binding_pretty_label, TheInput:BindingToString(keybinding))
				-- Re-fetch in case it was modified by the other device. Make a
				-- copy to ensure it isn't modified before we set it.
				bind_set = deepcopy(TheGameSettings:Get(settings_key))
				bind_set[bind_target] = keybinding
				TheGameSettings:ClearMatchingInputBinding(bind_set)
				TheGameSettings:Set(settings_key, bind_set)
				self:_HighlightInvalidBindings(bind_widgets)
				self:MakeDirty()
			end)
			bind_widgets[bind_target][settings_key] = bind_row
			return bind_row
		end

	local function CreateBindingPage(bind_target)
		bind_widgets[bind_target] = {}
		self.pages.controls:AddChild(OptionsScreenCategoryTitle(self.rowWidth, STRINGS.UI.OPTIONSSCREEN.BIND_SECTIONS.CONTROLS_BASIC[bind_target]))

		ConfigureKeybind(bind_target, "bindings.crafting",  Controls.Digital.OPEN_CRAFTING)
		ConfigureKeybind(bind_target, "bindings.inventory", Controls.Digital.OPEN_INVENTORY)
		ConfigureKeybind(bind_target, "bindings.interact",  Controls.Digital.ACTION)
		ConfigureKeybind(bind_target, "bindings.emote",     Controls.Digital.SHOW_EMOTE_RING)


		self.pages.controls:AddChild(OptionsScreenCategoryTitle(self.rowWidth, STRINGS.UI.OPTIONSSCREEN.BIND_SECTIONS.CONTROLS_COMBAT[bind_target]))

		-- Only for keyboard show mouse controls. Since we're getting the icons
		-- from the control, this only works if our input method is keyboard
		-- too.
		if not self:IsUsingGamepad()
			and bind_target == TheGameSettings.InputDevice.s.keyboard
		then
			local function CreatePseudoBinding(control)
				local binding_pretty_label = TheInput:GetControlPrettyName(control)
				local row = self.pages.controls:AddChild(OptionsScreenControlRow(self.rowWidth, self.rowRightColumnWidth))
					:SetText(binding_pretty_label)
					:ShowReadonlyBinding(control)
				return row
			end
			CreatePseudoBinding(Controls.Digital.ATTACK_LIGHT)
			CreatePseudoBinding(Controls.Digital.ATTACK_HEAVY)
		end

		ConfigureKeybind(bind_target, "bindings.light_attack", Controls.Digital.ATTACK_LIGHT)
		ConfigureKeybind(bind_target, "bindings.heavy_attack", Controls.Digital.ATTACK_HEAVY)
		ConfigureKeybind(bind_target, "bindings.dodge",        Controls.Digital.DODGE)
		ConfigureKeybind(bind_target, "bindings.potion",       Controls.Digital.USE_POTION)
		ConfigureKeybind(bind_target, "bindings.skill",        Controls.Digital.SKILL)
	end


	local function CreateGamepadRows()
		CreateBindingPage(TheGameSettings.InputDevice.s.gamepad)
	end

	-- Put current input first since there's soooo many to scroll past.
	local is_gamepad_first = self:IsUsingGamepad()
	if is_gamepad_first then
		CreateGamepadRows()
	end

	CreateBindingPage(TheGameSettings.InputDevice.s.keyboard)

	if not is_gamepad_first then
		CreateGamepadRows()
	end



	self.pages.controls:LayoutChildrenInGrid(1, self.rowSpacing * 0.5)

	self:_HighlightInvalidBindings(bind_widgets)

	return self
end

function OptionsScreen:_BuildOtherPage()

	local language_spinner = self.pages.other:AddChild(OptionsScreenSpinnerRow(self.rowWidth, self.rowRightColumnWidth))
	local lang_values = {}
	for _,id in iterator.sorted_pairs(LOC.GetLanguages()) do
		table.insert(lang_values, {
				name = STRINGS.PRETRANSLATED.LANGUAGES[id],
				desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.LANGUAGE_DESC,
				data = id,
			})
	end
	language_spinner
		:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.LANGUAGE_TITLE)
		:SetValues(lang_values)
		:SetFocusDir("right", language_spinner, true)

	-- Instead of HookupSetting, manually cache the desired language and change
	-- setting on screen exit so we never change the language until right
	-- before simreset. Changing the setting swaps the language immediately
	-- which doesn't fully cleanup when switching to english.
	local language_key = "language.selected"
	language_spinner:SetOnValueChangeFn(function(data, valueIndex, value)
		--~ TheLog.ch.Settings:print(language_key, "value changed", data, valueIndex)
		self.selected_language = data
		self:MakeDirty()
	end)
	local current = TheGameSettings:Get(language_key)
	kassert.assert_fmt(current ~= nil, "gamesettings doesn't have a default for %s", language_key)
	language_spinner:_TrySetValueToValue(language_key, current)
	-- /HookupSetting


	if not InGamePlay() then
		local data_collection_row = OptionsScreenToggleRow(self.rowWidth, self.rowRightColumnWidth)
		data_collection_row
			:SetText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.DATACOLLECTION.TITLE)
			:SetValues({
				{
					name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.DATACOLLECTION.DESC.ON.NAME,
					desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.DATACOLLECTION.DESC.ON.DESC,
					data = true,
				},
				{
					name = STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.DATACOLLECTION.DESC.OFF.NAME,
					desc = STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.DATACOLLECTION.DESC.OFF.DESC,
					data = false,
				},
			})
			:SetOnValueChangeFn(
				function(enabled, data, value) 
					local currently_enabled = TheSim:GetOnlineEnabled()
					if enabled ~= currently_enabled then
						-- show the confirm dialog
						local fullbody = table.concat({
								STRINGS.UI.DATACOLLECTION.REQUIREMENT,
								STRINGS.UI.DATACOLLECTION.EXPLAIN_POPUP.SEE_PRIVACY,
								STRINGS.UI.DATACOLLECTION.EXPLAIN_POPUP.BODY_RESTART,
							},
							"\n\n")
						local label = currently_enabled and STRINGS.UI.DATACOLLECTION.EXPLAIN_POPUP.OPT_OUT.CONTINUE or STRINGS.UI.DATACOLLECTION.EXPLAIN_POPUP.OPT_IN.CONTINUE
						local onopenfn = function()
									-- I don't want the toggle to visually change before we confirm
									data_collection_row:_TrySetValueToValue("other.metrics", TheSim:GetOnlineEnabled())
								end
						local dialog = ConfirmDialog(nil, nil, true, STRINGS.UI.DATACOLLECTION.EXPLAIN_POPUP.TITLE, nil, fullbody, nil, onopenfn )
						dialog
							:SetYesButton(label, 
								function()
									TheSim:SetOnlineEnabled(enabled)
									-- NOW change the visual to be changed
									data_collection_row:_TrySetValueToValue("other.metrics", enabled)
									local quit_dialog = ConfirmDialog(nil, nil, true, STRINGS.UI.DATACOLLECTION.QUIT_POPUP.TITLE, nil, nil, nil, nil )
									quit_dialog
										:HideArrow()
										:HideNoButton()
										:CenterText()
										:CenterButtons()
										:SetYesButton(STRINGS.UI.DATACOLLECTION.QUIT_POPUP.CONFIRM, function()
														TheSim:Quit()
													end)
									-- pop this cialog
									TheFrontEnd:PopScreen()
									TheFrontEnd:PushScreen(quit_dialog)
								end)
							:SetCancelButton(STRINGS.UI.DATACOLLECTION.EXPLAIN_POPUP.CANCEL, 
								function() 
									dialog:Close() 
								end)
							:SetNoButton(STRINGS.UI.DATACOLLECTION.EXPLAIN_POPUP.PRIVACY_PORTAL, 
								function() 
									VisitURL("https://www.klei.com/privacy-policy")
								end)
							:HideArrow() 
							:CenterButtons()
							:SetWideButtons()
							:MoveCancelButtonToTop()
						TheFrontEnd:PushScreen(dialog)
					end
				end)
			:_TrySetValueToValue("other.metrics", TheSim:GetOnlineEnabled())
	 	self.pages.other:AddChild(data_collection_row)
	end

	if not Platform.IsBigPictureMode() then
		self.pages.other:AddChild(OptionsScreenBaseRow(self.rowWidth, self.rowRightColumnWidth))
			:SetText(
				STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.SAVEDIR_TITLE,
				STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.SAVEDIR_DESC
			)
			:SetOnClick(function()
				TheSim:OpenGameSaveFolder()
			end)
	end

	--~ self.pages.other:AddChild(OptionsScreenBaseRow(self.rowWidth, self.rowRightColumnWidth))
	--~ 	:SetText("Credits", "See who made this game")
	--~ 	:SetOnClick(function()
	--~ 		print("Show credits.................")
	--~ 	end)

	--~ self.pages.other:AddChild(OptionsScreenBaseRow(self.rowWidth, self.rowRightColumnWidth))
	--~ 	:SetText("Reset profile", "Reset all saved games, unlocks and stats.")
	--~ 	:SetOnClick(function()
	--~ 		print("Reset profile.................")
	--~ 	end)

	self.pages.other:AddChild(OptionsScreenBaseRow(self.rowWidth, self.rowRightColumnWidth))
		:SetText(
			STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.RESET_SETTINGS_TITLE,
			STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.RESET_SETTINGS_DESC
		)
		:SetOnClick(function()
			local confirm = ConfirmDialog(nil, nil, true,
				STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.RESET_SETTINGS_CONFIRM,
				nil,
				STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.RESET_SETTINGS_DESC,
				function(should_reset)
					TheFrontEnd:PopScreen() -- popup
					if should_reset then
						TheGameSettings:ResetToDefaults()
						self:_SaveChanges(function()
							-- exit screen because settings are out of date
							self:_AnimateOut()
						end)
					end
				end)
				:SetYesButtonText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.RESET_SETTINGS_YES)
				:SetNoButtonText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.RESET_SETTINGS_NO)
				:HideArrow()
			TheFrontEnd:PushScreen(confirm)
		end)

	self.pages.other:AddChild(OptionsScreenBaseRow(self.rowWidth, self.rowRightColumnWidth))
		:SetText(
			STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.RESET_PROGRESS_TITLE,
			STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.RESET_PROGRESS_DESC
		)
		:SetOnClick(function()
			local confirm = ConfirmDialog(nil, nil, true,
				STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.RESET_PROGRESS_CONFIRM,
				nil,
				STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.RESET_PROGRESS_DESC,
				function(should_reset)
					TheFrontEnd:PopScreen() -- popup
					if should_reset then
						print("User confirmed: TheSaveSystem:EraseAll")
						TheFrontEnd:PushScreen(LoadingWidget())
						TheSaveSystem:EraseAll(function(success)
							-- quit to main menu to start new player experience
							RestartToMainMenu()
						end)
					end
				end)
				:SetYesButtonText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.RESET_PROGRESS_YES)
				:SetNoButtonText(STRINGS.UI.OPTIONSSCREEN.SETTINGS.OTHER.RESET_PROGRESS_NO)
				:HideArrow()
			TheFrontEnd:PushScreen(confirm)
		end)

	self.pages.other:LayoutChildrenInGrid(1, self.rowSpacing)

	return self
end

--- Called when an option was edited by the player
function OptionsScreen:MakeDirty()
	-- Check if something actually changed compared to the stored settings
	if self:IsDirty() then
		-- Show the save button
		self.saveButton:Show()
	else
		-- Hide the save button
		self.saveButton:Hide()
	end
end

function OptionsScreen:IsDirty()
	local matches_saved = deepcompare(self.settings_backup, TheGameSettings:GetSaveData())
	return not matches_saved
end

function OptionsScreen:IsLanguageDirty()
	return self.selected_language ~= self.language_on_enter
end

function OptionsScreen:_SaveChanges(cb)
	TheLog.ch.FrontEnd:print("OptionsScreen: Saving changes to disk.")
	-- Deep copy to ensure modifications of the settings can't possibly touch
	-- our backup since we need it for dirty detection.
	self.settings_backup = deepcopy(TheGameSettings:Save(cb))
	-- Don't update self.language_on_enter here since it's for detecting if the
	-- language changed while in this screen and we don't want the save button
	-- to skip the restart.
	return false
end

function OptionsScreen:OnClickClose()
	local ExitScreen = function(success)
		self:_AnimateOut() -- will pop our dialog
	end

	local function CreateConfirm(title, subtitle, text, confirm_yes, confirm_no)
		return ConfirmDialog(
			nil,
			self.backButton,
			true,
			title,
			subtitle,
			text
		)
			:SetYesButtonText(confirm_yes)
			:SetNoButtonText(confirm_no)
			:SetArrowUp()
			:SetArrowXOffset(20) -- extra right shift looks more centred
			:SetAnchorOffset(305, 0)
	end


	if self:IsLanguageDirty() then
		local dialog = CreateConfirm(
			STRINGS.UI.OPTIONSSCREEN.CONFIRM_LANGUAGE_TITLE,
			STRINGS.UI.OPTIONSSCREEN.CONFIRM_LANGUAGE_SUBTITLE,
			STRINGS.UI.OPTIONSSCREEN.CONFIRM_LANGUAGE_TEXT,
			STRINGS.UI.OPTIONSSCREEN.CONFIRM_RESTART,
			STRINGS.UI.OPTIONSSCREEN.CONFIRM_NO)

		dialog:SetOnDoneFn(function(confirm_save)
			if confirm_save then
				assert(self.selected_language, "How is language dirty without a selection?")
				TheGameSettings:Set("language.selected", self.selected_language)

				-- Quit to main menu to reload with new language setup.
				self:_SaveChanges(function(success)
					-- TODO(saveload): Saving changes since you can already
					-- save anywhere from the pause menu. If we make that
					-- robust, we should do the same here.
					RestartToMainMenu(true)
				end)

			else
				-- Revert to original/last saved.
				TheLog.ch.FrontEnd:print("OptionsScreen: Writing reverted changes to disk.")
				TheGameSettings:SetSaveData(self.settings_backup)
				TheGameSettings:Save(ExitScreen)
			end
		end)

		-- Show the popup
		TheFrontEnd:PushScreen(dialog)

		-- And animate it in!
		dialog:AnimateIn()

	elseif self:IsDirty() then
		-- Show confirmation to save the changes or reject them
		local dialog = CreateConfirm(
			STRINGS.UI.OPTIONSSCREEN.CONFIRM_TITLE,
			STRINGS.UI.OPTIONSSCREEN.CONFIRM_SUBTITLE,
			STRINGS.UI.OPTIONSSCREEN.CONFIRM_TEXT,
			STRINGS.UI.OPTIONSSCREEN.CONFIRM_OK,
			STRINGS.UI.OPTIONSSCREEN.CONFIRM_NO)

		-- Set its callback
		dialog:SetOnDoneFn(function(confirm_save)
			if confirm_save then
				self:_SaveChanges(ExitScreen)
			else
				-- Revert to original/last saved.
				TheLog.ch.FrontEnd:print("OptionsScreen: Writing reverted changes to disk.")
				TheGameSettings:SetSaveData(self.settings_backup)
				TheGameSettings:Save(ExitScreen)
			end
		end)

		-- Show the popup
		TheFrontEnd:PushScreen(dialog)

		-- And animate it in!
		dialog:AnimateIn()
	else
		self:Close() --go back
	end
end

function OptionsScreen:OnClickSave()
	if self:IsDirty() then
		-- Player clicked Save

		-- Save changes!
		self:_SaveChanges()

		-- Animate confirmation label and button
		self.saveConfirmationLabel:RunUpdater(Updater.Series({

			-- Fade button out
			Updater.Ease(function(v) self.saveButton:SetMultColorAlpha(v) end, 1, 0, 0.2, easing.inOutQuad),
			Updater.Do(function()
				self.saveButton:Hide()
					:SetMultColorAlpha(1)
			end),

			-- Animate in label
			Updater.Parallel({
				Updater.Ease(function(v) self.saveConfirmationLabel:SetMultColorAlpha(v) end, 0, 1, 0.3, easing.inOutQuad),
				Updater.Ease(function(v) self.saveConfirmationLabel:SetPosition(self.labelX, v) end, self.labelY - 10, self.labelY, 0.8, easing.outQuad),
			}),

			Updater.Wait(0.8),

			-- Animate label out
			Updater.Parallel({
				Updater.Ease(function(v) self.saveConfirmationLabel:SetMultColorAlpha(v) end, 1, 0, 0.8, easing.inOutQuad),
				Updater.Ease(function(v) self.saveConfirmationLabel:SetPosition(self.labelX, v) end, self.labelY, self.labelY + 10, 0.8, easing.inQuad),
			}),

		}))
	end
end

function OptionsScreen:Close()
	--fallback code to catch errant loop
	if TheFrontEnd:GetSound():IsPlayingSound("options_volume_sound") then
		TheFrontEnd:GetSound():KillSound("options_volume_sound")
	end

	self:_AnimateOut()
end

function OptionsScreen:OnBecomeActive()
	OptionsScreen._base.OnBecomeActive(self)
	-- Hide the topfade, it'll obscure the pause menu if paused during fade. Fade-out will re-enable it
	TheFrontEnd:HideTopFade()

	if not self.animatedIn then
		-- Select first tab
		self.tabs.gameplay:Click()

		self:_AnimateIn()
		self.animatedIn = true
	end
end

function OptionsScreen:_AnimateIn()
	self:_AnimateInFromDirection(Vector2.unit_y)
end

function OptionsScreen:_AnimateOut()
	self:_AnimateOutToDirection(Vector2.unit_y)
end

return OptionsScreen
