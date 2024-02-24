local Widget = require "widgets.widget"
local ActionButton = require "widgets.actionbutton"
local Clickable = require "widgets.clickable"
local Image = require "widgets.image"
local ImageButton = require "widgets.imagebutton"
local Panel = require "widgets.panel"
local PanelButton = require "widgets.panelbutton"
local TabGroup = require("widgets/tabgroup")
local ExpandingTabGroup = require("widgets/expandingtabgroup")
local PowerWidget = require "widgets.ftf.powerwidget"
local ScrollPanel = require "widgets.scrollpanel"
local SkillWidget = require "widgets.ftf.skillwidget"
local CheckBox = require "widgets.checkbox"
local Text = require "widgets.text"
local NotificationWidget = require "widgets/notificationwidget"
local Screen = require "widgets.screen"
local ItemUnlockPopup = require "screens.itemunlockpopup"
local ConfirmDialog = require "screens.dialogs.confirmdialog"
local WaitingDialog = require "screens.dialogs.waitingdialog"
local Power = require "defs.powers"
local Equipment = require "defs.equipment"
local itemforge = require "defs.itemforge"
local monster_pictures = require "gen.atlas.monster_pictures"

local ui = require "dbui.imgui"


------------------------------------------------------------------------------------------
--- A screen showing various UI elements
----
local UITestScreen = Class(Screen, function(self)
	Screen._ctor(self, "UITestScreen")

	-- Add background
	self.bg = self:AddChild(Image("images/bg_popup_flat/popup_flat.tex"))
		:SetName("Background")
		:SetScale(1.1)
	self.content_w, self.content_h = self.bg:GetScaledSize()
	self.content_w = self.content_w - 420
	self.content_h = self.content_h - 210

	-- Align contents to this
	self.content_hitbox = self:AddChild(Image("images/global/square.tex"))
		:SetMultColor(UICOLORS.DEBUG)
		:SetMultColorAlpha(0.7)
		:SetSize(self.content_w, self.content_h)
		:Offset(110, 17)
		:SetMultColorAlpha(0)

	-- Scroll panel
	self.scroll = self:AddChild(ScrollPanel())
		:SetSize(self.content_w + 120, self.content_h)
		:SetVirtualMargin(100)
		:SetBarInset(400)
		:SetScrollBarVerticalOffset(30)
		:LayoutBounds("center", "center", self.content_hitbox)
		:Offset(-50, 0)
	self.scrollContents = self.scroll:AddScrollChild(Widget())

	-- Add tabs
	self.tab_callbacks = {} -- associates a tab name to the callback to show its contents
	self.tab_bg = self:AddChild(Panel("images/ui_ftf/small_panel_wide.tex"))
		:SetName("Tab bg")
		:SetNineSliceCoords(9, 0, 8, 120)
		:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_MID)
	self.tab_group = self:AddChild(TabGroup())
		:SetName("Tab group")
	-----------------------------------------------------------------------------
	-----------------------------------------------------------------------------
	self:AddTextContents()
	self:AddButtonsContents()
	self:AddNotificationsContents()
	self:AddContainersContents()
	-----------------------------------------------------------------------------
	-----------------------------------------------------------------------------
	self.tab_group:SetTabOnClick(function(tab_btn) self:OnTabClicked(tab_btn.tab_text) end)
		:LayoutChildrenInRow(40)
		:OpenTabAtIndex(1)
	local tabs_w, tabs_h = self.tab_group:GetSize()
	self.tab_bg:SetSize(tabs_w + 120, 130)
		:LayoutBounds("center", "top", self.bg)
		:Offset(0, -35)
	self.tab_group:LayoutBounds("center", "center", self.tab_bg)
		:OpenTabAtIndex(4)

	-- Info label at the bottom
	self.info_bg = self:AddChild(Panel("images/ui_ftf/small_panel_wide.tex"))
		:SetName("Tab bg")
		:SetNineSliceCoords(9, 0, 8, 120)
		:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_MID)
	self.info_text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.DARK_TEXT)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(800)
		:SetText("Click an element to copy its\nsource-code to your clipboard.")
	local text_w, text_h = self.info_text:GetSize()
	self.info_bg:SetSize(text_w + 140, 120)
		:LayoutBounds("center", "bottom", self.bg)
		:Offset(0, 70)
		:SetScale(1, -1)
	self.info_text:LayoutBounds("center", "center", self.info_bg)
		:Offset(0, -3)

	-- Add close button
	self.close_button = self:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
		:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
		:SetOnClick(function() TheFrontEnd:PopScreen(self) end)
		:LayoutBounds("right", "top", self.bg)
		:Offset(-40, -5)

	-- Game icons
	-- self.iconsContainer = self.scrollContents:AddChild(Widget())
	-- local power = Power.FindPowerByName("parry")
	-- local skill = self.iconsContainer:AddChild(SkillWidget(170, nil, power))
	-- local power = self.iconsContainer:AddChild(PowerWidget(170, nil, nil))
	-- self.iconsContainer:LayoutBounds("left", "below", self.buttonsContainer)
	-- 	:Offset(0, -100)

	self.default_focus = self.close_button
end)

function UITestScreen:_AddClickableWidget(parent, widget, clipboard_text)
	local widget_button = parent:AddChild(Clickable())
	:SetOnClickFn(function()
		ui:SetClipboardText(clipboard_text)
		self:_ShowClipboardNotification()
	end)
	:SetScales(1, 1.05, 0.98, 0.1, 0.3)
	widget_button:AddChild(widget)
	return widget_button
end

function UITestScreen:_ShowClipboardNotification()
	if not self.notification_widget then

		-- Show a notification
		self.notification_widget = TheFrontEnd:ShowTextNotification("images/ui_ftf_notifications/clipboard.tex", "Code copied", "Paste the sample into your code", 3)

		-- Prevent multiple notifications from being triggered
		self.notification_widget:SetOnRemoved(function() self.notification_widget = nil end)
	end
end

function UITestScreen:AddTextContents()
	self:_AddTabPanel("Text", function(container)

		-------------------------------------------------------------------------
		-- Left

		local title = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TITLE)
				:SetName("Title text")
				:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
				:SetAutoSize(700)
				:SetText("Screen Title!"),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TITLE))
	:SetName("Title text")
	:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
	:SetAutoSize(700)
	:SetText("Screen Title!")
]])

		local subtitle = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE)
				:SetName("Subtitle text")
				:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
				:SetAutoSize(700)
				:SetText("Screen Subtitle!"),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_SUBTITLE))
	:SetName("Subtitle text")
	:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
	:SetAutoSize(700)
	:SetText("Screen Subtitle!")
]])
			:LayoutBounds("left", "below")

		local dialog_title = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_TITLE)
				:SetName("Dialog title")
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetAutoSize(700)
				:SetText("Dialog title"),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_TITLE))
	:SetName("Dialog title")
	:SetGlyphColor(UICOLORS.DARK_TEXT)
	:SetAutoSize(700)
	:SetText("Dialog title")
]])
			:LayoutBounds("left", "below")
			:Offset(0, -60)

		local dialog_subtitle = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_SUBTITLE)
				:SetName("Dialog subtitle")
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetAutoSize(700)
				:SetText("Dialog subtitle"),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_SUBTITLE))
	:SetName("Dialog subtitle")
	:SetGlyphColor(UICOLORS.DARK_TEXT)
	:SetAutoSize(700)
	:SetText("Dialog subtitle")
]])
			:LayoutBounds("left", "below")

		local text = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT)
				:SetName("Text")
				:LeftAlign()
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetAutoSize(700)
				:SetText("This is a block of text that wraps around 700px. To wrap, you just have to call :SetAutoSize(700) on your Text widget.\n\nThis is set to <#OVERLAY_ATTENTION_GRAB>font-size 40</>, which should be the <#7F54DDee>smallest</> we ever display in the game (FONTSIZE.SCREEN_TEXT)."),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
	:SetName("Text")
	:LeftAlign()
	:SetGlyphColor(UICOLORS.DARK_TEXT)
	:SetAutoSize(700)
	:SetText("This is a block of text that wraps around 700px. To wrap, you just have to call :SetAutoSize(700) on your Text widget.\n\nThis is set to <#OVERLAY_ATTENTION_GRAB>font-size 40</>, which should be the <#7F54DDee>smallest</> we ever display in the game (FONTSIZE.SCREEN_TEXT).")
]])
			:LayoutBounds("left", "below")
			:Offset(0, -20)

		local spooling_text = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT)
				:SetName("Spooling text")
				:LeftAlign()
				:SetGlyphColor(UICOLORS.SPEECH_TEXT)
				:SetAutoSize(700)
				:SetText("This is a spooling block of text.                                        \nFeels like a character talking, doesn't it?")
				:Spool(50),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetName("Spooling text")
	:LeftAlign()
	:SetGlyphColor(UICOLORS.SPEECH_TEXT)
	:SetAutoSize(700)
	:SetText("This is a spooling block of text.                                        \nFeels like a character talking, doesn't it?")
	:Spool(50)
]])
			:LayoutBounds("left", "below")
			:Offset(0, -70)

		local inline_icon = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT)
				:SetName("Inline-icon text")
				:LeftAlign()
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetAutoSize(700)
				:SetText("<p img='images/icons_ftf/icon_konjurite_cluster_drops_currency.tex' scale=1.4> Text with an inline-icon. Super cool. You can tweak the icon's scale too"),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetName("Inline-icon text")
	:LeftAlign()
	:SetGlyphColor(UICOLORS.DARK_TEXT)
	:SetAutoSize(700)
	:SetText("<p img='images/icons_ftf/icon_konjurite_cluster_drops_currency.tex' scale=1.4> Text with an inline-icon. Super cool. You can tweak the icon's scale too")
]])
			:LayoutBounds("left", "below")
			:Offset(0, -70)

		local inline_icon2 = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT)
				:SetName("Inline-icon text")
				:LeftAlign()
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetAutoSize(700)
				:SetText("<p img='images/ui_ftf/input_gamepad.tex' scale=1.4 color=0> Icon matching the text color"),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetName("Inline-icon text")
	:LeftAlign()
	:SetGlyphColor(UICOLORS.DARK_TEXT)
	:SetAutoSize(700)
	:SetText("<p img='images/ui_ftf/input_gamepad.tex' scale=1.4 color=0> Icon matching the text color")
]])
			:LayoutBounds("left", "below")
			:Offset(0, -10)

		local inline_icon3 = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT)
				:SetName("Inline-icon text")
				:LeftAlign()
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetAutoSize(700)
				:SetText("<p img='images/ui_ftf_dialog/convo_end.tex' scale=1.2 color=UPGRADE_DARK> Icon with color UICOLORS.UPGRADE_DARK"),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetName("Inline-icon text")
	:LeftAlign()
	:SetGlyphColor(UICOLORS.DARK_TEXT)
	:SetAutoSize(700)
	:SetText("<p img='images/ui_ftf_dialog/convo_end.tex' scale=1.2 color=UPGRADE_DARK> Icon with color UICOLORS.UPGRADE_DARK")
]])
			:LayoutBounds("left", "below")
			:Offset(0, -10)

		local inline_icon4 = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT)
				:SetName("Inline-icon text")
				:LeftAlign()
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetAutoSize(700)
				:SetText("<p img='images/ui_ftf_dialog/convo_map.tex' scale=1.2 color=C22D97ee> Icon with color #C22D97ee"),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetName("Inline-icon text")
	:LeftAlign()
	:SetGlyphColor(UICOLORS.DARK_TEXT)
	:SetAutoSize(700)
	:SetText("<p img='images/ui_ftf_dialog/convo_map.tex' scale=1.2 color=C22D97ee> Icon with color #C22D97ee")
]])
			:LayoutBounds("left", "below")
			:Offset(0, -10)

		local inline_icon5 = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT)
				:SetName("Inline-icon text")
				:LeftAlign()
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetAutoSize(700)
				:SetText(" <p bind='Controls.Digital.ACTION' color=0> Inline control binding"),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetName("Inline-icon text")
	:LeftAlign()
	:SetGlyphColor(UICOLORS.DARK_TEXT)
	:SetAutoSize(700)
	:SetText("<p bind='Controls.Digital.ACTION' color=0> Inline control binding")
]])
			:LayoutBounds("left", "below")
			:Offset(0, -15)

		local inline_icon6 = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT)
				:SetName("Inline-icon text")
				:LeftAlign()
				:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
				:SetAutoSize(700)
				:SetText("For text widgets with an inline control binding, make sure to call <#SPEECH_TEXT>:RefreshText()</> when the input mode changes, so the icon updates to the correct device's icon set."),
			[[:RefreshText()
]])
			:LayoutBounds("left", "below")
			:Offset(0, -15)

		-------------------------------------------------------------------------
		-- Middle

		local left_aligned = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT)
				:SetName("Left-aligned text")
				:SetHAlign(ANCHOR_LEFT)
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetText("This is a\ntext that is\nleft aligned"),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
				:SetName("Left-aligned text")
				:SetHAlign(ANCHOR_LEFT)
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetText("This is a\ntext that is\nleft aligned")
]])
			:LayoutBounds("left", "top", title)
			:Offset(1130, 0)

		local center_aligned = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT)
				:SetName("Center-aligned text")
				:SetHAlign(ANCHOR_MIDDLE)
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetText("This is a\ntext that is\ncentered"),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
				:SetName("Center-aligned text")
				:SetHAlign(ANCHOR_MIDDLE)
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetText("This is a\ntext that is\ncentered")
]])
			:LayoutBounds("left", "top", left_aligned)
			:Offset(300, 0)

		local right_aligned = self:_AddClickableWidget(container,
			Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT)
				:SetName("Right-aligned text")
				:SetHAlign(ANCHOR_RIGHT)
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetText("This is a\ntext that is\nright aligned"),
			[[
local text = self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT))
				:SetName("Right-aligned text")
				:SetHAlign(ANCHOR_RIGHT)
				:SetGlyphColor(UICOLORS.DARK_TEXT)
				:SetText("This is a\ntext that is\nright aligned")
]])
			:LayoutBounds("left", "top", center_aligned)
			:Offset(300, 0)

		container:LayoutBounds("left", "top", 0, 0)
			:Offset(-self.content_w/2 + 50, 0)
	end)
end

function UITestScreen:AddButtonsContents()
	self:_AddTabPanel("Buttons", function(container)

		local primary_button = container:AddChild(ActionButton())
				:SetName("Button")
				:SetSize(BUTTON_W, BUTTON_H)
				:SetPrimary()
				:SetText("Call-to-action btn")
				:SetOnClick(function()
					self:_ShowClipboardNotification()
					ui:SetClipboardText([[
local button = self:AddChild(ActionButton())
	:SetName("Button")
	:SetSize(BUTTON_W, BUTTON_H)
	:SetPrimary()
	:SetText(STRINGS.UI.BUTTONS.OK)
	:SetOnClick(function() end)
]])
					end)

		local secondary_button = container:AddChild(ActionButton())
				:SetName("Button")
				:SetSize(BUTTON_W, BUTTON_H)
				:SetSecondary()
				:SetText("Secondary action")
				:SetOnClick(function()
					self:_ShowClipboardNotification()
					ui:SetClipboardText([[
local button = self:AddChild(ActionButton())
	:SetName("Button")
	:SetSize(BUTTON_W, BUTTON_H)
	:SetSecondary()
	:SetText(STRINGS.UI.BUTTONS.CANCEL)
	:SetOnClick(function() end)
]])
					end)
			:LayoutBounds("left", "below")
			:Offset(0, -20)

		local button = container:AddChild(ActionButton())
				:SetName("Button")
				:SetSize(BUTTON_W, BUTTON_H)
				:SetSecondary()
				:SetScaleOnFocus(false)
				:SetText("Focus scale off")
				:SetOnClick(function()
					self:_ShowClipboardNotification()
					ui:SetClipboardText([[
local button = self:AddChild(ActionButton())
	:SetName("Button")
	:SetSize(BUTTON_W, BUTTON_H)
	:SetSecondary()
	:SetScaleOnFocus(false)
	:SetText("Focus scale off")
	:SetOnClick(function() end)
]])
					end)
			:LayoutBounds("left", "below")
			:Offset(0, -20)

		local button = container:AddChild(ActionButton())
				:SetName("Button")
				:SetSize(BUTTON_W, BUTTON_H)
				:SetKonjur()
				:SetText("Konjur button")
				:SetOnClick(function()
					self:_ShowClipboardNotification()
					ui:SetClipboardText([[
local button = self:AddChild(ActionButton())
	:SetName("Button")
	:SetSize(BUTTON_W, BUTTON_H)
	:SetKonjur()
	:SetText("Konjur button")
	:SetOnClick(function() end)
]])
					end)
			:LayoutBounds("left", "below")
			:Offset(0, -20)

		local button = container:AddChild(ActionButton())
				:SetName("Button")
				:SetSize(BUTTON_W, BUTTON_H)
				:SetDebug()
				:SetText("Debug button")
				:SetOnClick(function()
					self:_ShowClipboardNotification()
					ui:SetClipboardText([[
local button = self:AddChild(ActionButton())
	:SetName("Button")
	:SetSize(BUTTON_W, BUTTON_H)
	:SetDebug()
	:SetText("Debug button")
	:SetOnClick(function() end)
]])
					end)
			:LayoutBounds("left", "below")
			:Offset(0, -20)

		local button = container:AddChild(ActionButton())
				:SetName("Button")
				:SetSize(630, 300)
				:SetSecondary()
				:SetText("Button with a\ncustom size")
				:SetOnClick(function()
					self:_ShowClipboardNotification()
					ui:SetClipboardText([[
local button = self:AddChild(ActionButton())
	:SetName("Button")
	:SetSize(630, 300)
	:SetSecondary()
	:SetText(STRINGS.UI.BUTTONS.OK)
	:SetOnClick(function() end)
]])
					end)
			:LayoutBounds("left", "below")
			:Offset(0, -20)

		local button = container:AddChild(ActionButton())
				:SetName("Button")
				:SetSecondary()
				:SetTextAndResizeToFit("Button sized to text,\nwith custom padding.", 50, 30)
				:SetOnClick(function()
					self:_ShowClipboardNotification()
					ui:SetClipboardText([[
local button = self:AddChild(ActionButton())
	:SetName("Button")
	:SetSize(630, 300)
	:SetSecondary()
	:SetTextAndResizeToFit("Button sized to text,\nwith custom padding.", 50, 30)
	:SetOnClick(function() end)
]])
					end)
			:LayoutBounds("left", "below")
			:Offset(0, -20)

		local primary_button_flipped = container:AddChild(ActionButton())
					:SetName("Button")
					:SetSize(BUTTON_W, BUTTON_H)
					:SetPrimary()
					:SetFlipped()
					:SetText("Flipped cta")
					:SetOnClick(function()
						self:_ShowClipboardNotification()
						ui:SetClipboardText([[
local button = self:AddChild(ActionButton())
	:SetName("Button")
	:SetSize(BUTTON_W, BUTTON_H)
	:SetPrimary()
	:SetFlipped()
	:SetText(STRINGS.UI.BUTTONS.OK)
	:SetOnClick(function() end)
]])
					end)
			:LayoutBounds("left", "top", primary_button)
			:Offset(600, 0)

		local secondary_button_flipped = container:AddChild(ActionButton())
				:SetName("Button")
				:SetSize(BUTTON_W, BUTTON_H)
				:SetSecondary()
				:SetFlipped()
				:SetText("Flipped secondary")
				:SetOnClick(function()
					self:_ShowClipboardNotification()
					ui:SetClipboardText([[
local button = self:AddChild(ActionButton())
	:SetName("Button")
	:SetSize(BUTTON_W, BUTTON_H)
	:SetSecondary()
	:SetFlipped()
	:SetText(STRINGS.UI.BUTTONS.CANCEL)
	:SetOnClick(function() end)
]])
					end)
			:LayoutBounds("left", "below")
			:Offset(0, -20)

		local button_flipped = container:AddChild(ActionButton())
				:SetName("Button")
				:SetSize(BUTTON_W, BUTTON_H)
				:SetSecondary()
				:SetFlipped()
				:SetScaleOnFocus(false)
				:SetText("Flipped btn")
				:SetOnClick(function()
					self:_ShowClipboardNotification()
					ui:SetClipboardText([[
local button = self:AddChild(ActionButton())
	:SetName("Button")
	:SetSize(BUTTON_W, BUTTON_H)
	:SetSecondary()
	:SetFlipped()
	:SetScaleOnFocus(false)
	:SetText("Focus scale off")
	:SetOnClick(function() end)
]])
					end)
			:LayoutBounds("left", "below")
			:Offset(0, -20)

		local button_flipped = container:AddChild(ActionButton())
				:SetName("Button")
				:SetSize(BUTTON_W, BUTTON_H)
				:SetKonjur()
				:SetFlipped()
				:SetText("Flipped konjur")
				:SetOnClick(function()
					self:_ShowClipboardNotification()
					ui:SetClipboardText([[
local button = self:AddChild(ActionButton())
	:SetName("Button")
	:SetSize(BUTTON_W, BUTTON_H)
	:SetKonjur()
	:SetFlipped()
	:SetText("Konjur button")
	:SetOnClick(function() end)
]])
					end)
			:LayoutBounds("left", "below")
			:Offset(0, -20)

		local button_flipped = container:AddChild(ActionButton())
				:SetName("Button")
				:SetSize(BUTTON_W, BUTTON_H)
				:SetDebug()
				:SetFlipped()
				:SetText("Flipped debug")
				:SetOnClick(function()
					self:_ShowClipboardNotification()
					ui:SetClipboardText([[
local button = self:AddChild(ActionButton())
	:SetName("Button")
	:SetSize(BUTTON_W, BUTTON_H)
	:SetDebug()
	:SetFlipped()
	:SetText("Debug button")
	:SetOnClick(function() end)
]])
					end)
			:LayoutBounds("left", "below")
			:Offset(0, -20)

		container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
			:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
			:LeftAlign()
			:SetAutoSize(440)
			:SetText("<p img='images/ui_ftf/arrow_up.tex' scale=0.7 color=0> The <#SPEECH_TEXT>:SetFlipped()</> function can be called on buttons to switch their texture, so contiguous buttons don't look repeated.")
			:LayoutBounds("left", "below", button_flipped)
			:Offset(100, -40)

		local close_button = container:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
			:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
			:SetOnClick(function()
				self:_ShowClipboardNotification()
				ui:SetClipboardText([[
local close_button = self:AddChild(ImageButton("images/ui_ftf/HeaderClose.tex"))
	:SetName("Close button")
	:SetSize(BUTTON_SQUARE_SIZE, BUTTON_SQUARE_SIZE)
	:SetOnClick(function() end)
]])
				end)
			:LayoutBounds("left", "top", primary_button_flipped)
			:Offset(900, 0)

		container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
			:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
			:LeftAlign()
			:SetAutoSize(800)
			:SetText("Close button: used on most screens on the top right. Shown even in controller-mode, so players know they can leave.")
			:LayoutBounds("after", "center", close_button)
			:Offset(40, 0)

		local panel_button = container:AddChild(PanelButton("images/ui_ftf_options/controls_bg.tex"))
			:SetNineSliceCoords(22, 12, 304, 82)
			:SetSize(400, 150)
			:SetMultColor(UICOLORS.LIGHT_TEXT_DARKER)
			:SetOnClick(function()
				self:_ShowClipboardNotification()
				ui:SetClipboardText([[
local panel_button = self:AddChild(PanelButton("images/ui_ftf_options/controls_bg.tex"))
	:SetName("Panel button")
	:SetNineSliceCoords(22, 12, 304, 82)
	:SetSize(400, 150)
	:SetMultColor(UICOLORS.LIGHT_TEXT_DARKER)
	:SetOnClick(function() end)
]])
				end)
			:LayoutBounds("left", "below", close_button)
			:Offset(0, -40)

		container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
			:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
			:LeftAlign()
			:SetAutoSize(530)
			:SetText("Panel button: a clickable nineslice, zooms on hover/focus.\nYou can add contents to it")
			:LayoutBounds("after", "center", panel_button)
			:Offset(40, 0)

		local image_button = container:AddChild(ImageButton("images/ui_ftf_multiplayer/multiplayer_btn_host.tex"))
			:SetScale(0.6)
			:SetOnClick(function()
				self:_ShowClipboardNotification()
				ui:SetClipboardText([[
local image_button = self:AddChild(ImageButton("images/ui_ftf_multiplayer/multiplayer_btn_host.tex"))
	:SetName("Image button")
	:SetOnClick(function() end)
]])
				end)
			:LayoutBounds("left", "below", panel_button)
			:Offset(0, -40)

		container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
			:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
			:LeftAlign()
			:SetAutoSize(530)
			:SetText("Image button: a clickable image.\nIf no size is set, it uses the texture's size.")
			:LayoutBounds("after", "center", image_button)
			:Offset(40, 0)

		local check_box = container:AddChild(CheckBox())
			:SetTextSize(FONTSIZE.ROOMBONUS_TEXT)
			:SetText("Check box with text")
		check_box:SetOnChangedFn(function(toggled)
			check_box:SetText(toggled and "Toggled" or "Not toggled")
			self:_ShowClipboardNotification()
			ui:SetClipboardText([[
local check_box = self:AddChild(CheckBox())
	:SetName("Check box")
	:SetTextSize(FONTSIZE.ROOMBONUS_TEXT)
	:SetText("Check box")
	:SetOnChangedFn(function(toggled) end)
]])
			end)
			:LayoutBounds("left", "below", image_button)
			:Offset(0, -60)

		local color_check_box = container:AddChild(CheckBox({
				primary_active = UICOLORS.BONUS, -- Hover color
				primary_inactive = UICOLORS.UPGRADE_DARK, -- Normal color
			}))
			:SetTextSize(FONTSIZE.ROOMBONUS_TEXT)
			:SetText("Custom color check box")
		color_check_box:SetOnChangedFn(function(toggled)
			color_check_box:SetText(toggled and "Toggled" or "Not toggled")
			self:_ShowClipboardNotification()
			ui:SetClipboardText([[
local check_box = self:AddChild(CheckBox({
		primary_active = UICOLORS.BONUS, -- Hover color
		primary_inactive = UICOLORS.UPGRADE_DARK, -- Normal color
	}))
	:SetName("Check box")
	:SetTextSize(FONTSIZE.ROOMBONUS_TEXT)
	:SetText("Check box")
	:SetOnChangedFn(function(toggled) end)
]])
			end)
			:LayoutBounds("after", "center", check_box)
			:Offset(40, 0)

		local slider = container:AddChild(CheckBox())
			:SetIsSlider(true)
			:SetTextSize(FONTSIZE.ROOMBONUS_TEXT)
			:SetText("Slider with text")
			:SetValue(true, true)
		slider:SetOnChangedFn(function(toggled)
			slider:SetText(toggled and "Toggled" or "Not toggled")
			self:_ShowClipboardNotification()
			ui:SetClipboardText([[
local slider = self:AddChild(CheckBox())
	:SetName("Check box")
	:SetIsSlider(true)
	:SetTextSize(FONTSIZE.ROOMBONUS_TEXT)
	:SetText("Check box")
	:SetValue(true, true)
	:SetOnChangedFn(function(toggled) end)
]])
			end)
			:LayoutBounds("left", "below", check_box)
			:Offset(0, -30)

		local tab_group = container:AddChild(TabGroup())
			:SetName("Tab group")
		tab_group:AddTextTab("Tab 1", FONTSIZE.ROOMBONUS_TEXT)
		tab_group:AddTextTab("Tab 2", FONTSIZE.ROOMBONUS_TEXT)
		tab_group:AddTextTab("Tab 3", FONTSIZE.ROOMBONUS_TEXT)
		tab_group:AddTextTab("Tab 4", FONTSIZE.ROOMBONUS_TEXT)
		tab_group:AddTextTab("Tab 5", FONTSIZE.ROOMBONUS_TEXT)
		tab_group:OpenTabAtIndex(1)
		tab_group:SetTabOnClick(function(tab_btn)
				self:_ShowClipboardNotification()
				ui:SetClipboardText([[
local tab_group = self:AddChild(TabGroup())
	:SetName("Tab group")
	:SetTabOnClick(function(active_tab) end)

local tab_1 = tab_group:AddTextTab("Tab 1", FONTSIZE.ROOMBONUS_TEXT)
local tab_2 = tab_group:AddTextTab("Tab 2", FONTSIZE.ROOMBONUS_TEXT)
local tab_3 = tab_group:AddTextTab("Tab 3", FONTSIZE.ROOMBONUS_TEXT)
local tab_4 = tab_group:AddTextTab("Tab 4", FONTSIZE.ROOMBONUS_TEXT)
local tab_5 = tab_group:AddTextTab("Tab 5", FONTSIZE.ROOMBONUS_TEXT)

tab_group:LayoutChildrenInRow(40)
	:OpenTabAtIndex(1)
]])
			end)
			:LayoutChildrenInRow(40)
			:LayoutBounds("left", "below", slider)
			:Offset(0, -60)

		local icon_tab_group = container:AddChild(TabGroup())
			:SetName("Tab group")
			:SetFontSize(FONTSIZE.ROOMBONUS_TEXT)
		icon_tab_group:AddIconTextTab("images/ui_ftf/input_kbm.tex","Tab 1"):SetSize(nil, 70)
		icon_tab_group:AddIconTextTab("images/ui_ftf/input_1.tex","Tab 2"):SetSize(nil, 70)
		icon_tab_group:AddIconTextTab("images/ui_ftf/input_2.tex","Tab 3"):SetSize(nil, 70)
		icon_tab_group:AddIconTextTab("images/ui_ftf/input_3.tex","Tab 4"):SetSize(nil, 70)
		icon_tab_group:AddIconTextTab("images/ui_ftf/input_4.tex","Tab 5"):SetSize(nil, 70)
		icon_tab_group:OpenTabAtIndex(1)
		icon_tab_group:SetTabOnClick(function(tab_btn)
				self:_ShowClipboardNotification()
				ui:SetClipboardText([[
local icon_tab_group = self:AddChild(TabGroup())
	:SetName("Tab group")
	:SetFontSize(FONTSIZE.ROOMBONUS_TEXT)
	:SetTabOnClick(function(active_tab) end)

local tab_1 = icon_tab_group:AddIconTextTab("images/ui_ftf/input_kbm.tex","Tab 1"):SetSize(nil, 70)
local tab_2 = icon_tab_group:AddIconTextTab("images/ui_ftf/input_1.tex","Tab 2"):SetSize(nil, 70)
local tab_3 = icon_tab_group:AddIconTextTab("images/ui_ftf/input_2.tex","Tab 3"):SetSize(nil, 70)
local tab_4 = icon_tab_group:AddIconTextTab("images/ui_ftf/input_3.tex","Tab 4"):SetSize(nil, 70)
local tab_5 = icon_tab_group:AddIconTextTab("images/ui_ftf/input_4.tex","Tab 5"):SetSize(nil, 70)

icon_tab_group:LayoutChildrenInRow(40)
	:OpenTabAtIndex(1)
]])
			end)
			:LayoutChildrenInRow(40)
			:LayoutBounds("left", "below", tab_group)
			:Offset(0, -20)

		local expanding_tab_group_container = container:AddChild(Widget())
			:SetName("Expanding tab group container")
		local tabs_background = expanding_tab_group_container:AddChild(Panel("images/ui_ftf_research/research_tabs_bg.tex"))
			:SetName("Tabs background")
			:SetNineSliceCoords(26, 0, 195, 150)
			:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_DARK)
		local expanding_tab_group = expanding_tab_group_container:AddChild(ExpandingTabGroup())
			:SetName("Expanding tab group")
		expanding_tab_group:AddTab("images/ui_ftf/input_kbm.tex","Tab 1")
		expanding_tab_group:AddTab("images/ui_ftf/input_1.tex","Tab 2")
		expanding_tab_group:AddTab("images/ui_ftf/input_2.tex","Tab 3")
		expanding_tab_group:AddTab("images/ui_ftf/input_3.tex","Tab 4")
		expanding_tab_group:AddTab("images/ui_ftf/input_4.tex","Tab 5")
		expanding_tab_group:OpenTabAtIndex(1)
		expanding_tab_group:SetTabOnClick(function(tab_btn)
				self:_ShowClipboardNotification()
				ui:SetClipboardText([[
local expanding_tab_group_container = self:AddChild(Widget())
	:SetName("Expanding tab group container")
local tabs_background = expanding_tab_group_container:AddChild(Panel("images/ui_ftf_research/research_tabs_bg.tex"))
	:SetName("Tabs background")
	:SetNineSliceCoords(26, 0, 195, 150)
	:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_DARK)
local expanding_tab_group = expanding_tab_group_container:AddChild(ExpandingTabGroup())
	:SetName("Expanding tab group")
	:SetTabOnClick(function(active_tab) end)
	:SetOnTabSizeChange(function()
		expanding_tab_group:LayoutChildrenInRow(5)
		local tabs_w, tabs_h = expanding_tab_group:GetSize()
		tabs_background:SetSize(tabs_w + 100, tabs_h + 60)
		expanding_tab_group:LayoutBounds("center", "center", tabs_background)
	end)

local tab_1 = expanding_tab_group:AddTab("images/ui_ftf/input_kbm.tex","Tab 1")
local tab_2 = expanding_tab_group:AddTab("images/ui_ftf/input_1.tex","Tab 2")
local tab_3 = expanding_tab_group:AddTab("images/ui_ftf/input_2.tex","Tab 3")
local tab_4 = expanding_tab_group:AddTab("images/ui_ftf/input_3.tex","Tab 4")
local tab_5 = expanding_tab_group:AddTab("images/ui_ftf/input_4.tex","Tab 5")

expanding_tab_group:LayoutChildrenInRow(5)
local tabs_w, tabs_h = expanding_tab_group:GetSize()
tabs_background:SetSize(tabs_w + 100, tabs_h + 60)
expanding_tab_group:LayoutBounds("center", "center", tabs_background)
]])
			end)
			:SetOnTabSizeChange(function()
				expanding_tab_group:LayoutChildrenInRow(5)
				local tabs_w, tabs_h = expanding_tab_group:GetSize()
				tabs_background:SetSize(tabs_w + 100, tabs_h + 60)
				expanding_tab_group:LayoutBounds("center", "center", tabs_background)
				expanding_tab_group_container:LayoutBounds("left", "below", icon_tab_group)
					:Offset(0, -30)
			end)
		expanding_tab_group:LayoutChildrenInRow(5)
		local tabs_w, tabs_h = expanding_tab_group:GetSize()
		tabs_background:SetSize(tabs_w + 100, tabs_h + 60)
		expanding_tab_group:LayoutBounds("center", "center", tabs_background)
		expanding_tab_group_container:LayoutBounds("left", "below", icon_tab_group)
			:Offset(0, -30)


		container:LayoutBounds("left", "top", 0, 0)
			:Offset(-self.content_w/2 + 50, 0)

	end)
end

function UITestScreen:AddNotificationsContents()
	self:_AddTabPanel("Notifications", function(container)

		local new_notif = container:AddChild(NotificationWidget.TextNotificationWidget())
			:SetName("Text notification widget")
			:SetData("images/ui_ftf_notifications/playerjoined.tex", "Notification title", "Notification description text, right below the title.")
			:SetMultColorAlpha(1)
			:SetOnClick(function()
				self:_ShowClipboardNotification()

				local duration = 6 -- in seconds
				TheFrontEnd:ShowTextNotification("images/ui_ftf_notifications/playerjoined.tex", "Notification title", "Test notification here. Click again to add another to the queue.", duration)

				ui:SetClipboardText([[
local duration = 6 -- optional, in seconds (if nil, it'll show for 4 seconds)
TheFrontEnd:ShowTextNotification("images/ui_ftf_notifications/playerjoined.tex", "Notification title", "Notification description text, right below the title.", duration)
]])
				end)

		container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
			:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
			:LeftAlign()
			:SetAutoSize(800)
			:SetText("This is what one of our notifications looks like.\nThey show on the lower left third of the screen.\nUp to 4 can show simultaneously, then any additional ones wait until there's a free spot.")
			:LayoutBounds("after", "center", new_notif)
			:Offset(40, 0)

		-- Weapon unlock
		local weapon_btn = container:AddChild(Clickable())
			:SetName("Weapon button")
			:SetScales(1, 1.05, 0.98, 0.1, 0.3)
		local weapon_icon = weapon_btn:AddChild(Image("images/icons_ftf/inventory_weapon_cannon.tex"))
			:SetName("Weapon icon")
			:SetSize(250, 250)
			:SetMultColor(UICOLORS.DARK_TEXT)
		local weapon_title = weapon_btn:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_SUBTITLE))
			:SetName("Weapon title")
			:SetGlyphColor(UICOLORS.DARK_TEXT)
			:SetAutoSize(500)
			:SetText("Weapon unlock popup!")
			:LayoutBounds("center", "below", weapon_icon)
			:Offset(0, -40)
		local weapon_text = weapon_btn:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
			:SetName("Weapon text")
			:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
			:SetAutoSize(500)
			:SetText("Opens when the player unlocks\na new weapon type.")
			:LayoutBounds("center", "below", weapon_title)
			:Offset(0, -10)
		weapon_btn:SetOnClick(function()
				self:_ShowClipboardNotification()
				ui:SetClipboardText([[
local ItemUnlockPopup = require "screens.itemunlockpopup"

local weapon_name = "cannon_basic"
local item_def = Equipment.Items["WEAPON"][weapon_name]
local item = itemforge.CreateEquipment(item_def.slot, item_def)
local weapon_type = item_def.weapon_type

local title = STRINGS.WEAPONS.UNLOCK.TITLE
local unlock_string = STRINGS.WEAPONS.UNLOCK[weapon_type] or string.format("%s UNLOCK STRING MISSING", weapon_type)
local how_to_play = STRINGS.WEAPONS.HOW_TO_PLAY[weapon_type] or string.format("%s HOW TO PLAY STRING MISSING", weapon_type)
local focus_hit = STRINGS.WEAPONS.FOCUS_HIT[weapon_type] or string.format("%s FOCUS HIT STRING MISSING", weapon_type)
local description = string.format("%s\n\n%s\n\n%s", unlock_string, how_to_play, focus_hit)

local screen = ItemUnlockPopup(nil, nil, true)
	:SetItemUnlock(item, title, description)
TheFrontEnd:PushScreen(screen)
screen:SetOnDoneFn(function(accepted)
	TheFrontEnd:PopScreen(screen)
end)
screen:AnimateIn()
]])

				local weapon_name = "cannon_basic"
				local item_def = Equipment.Items["WEAPON"][weapon_name]
				local item = itemforge.CreateEquipment(item_def.slot, item_def)
				local weapon_type = item_def.weapon_type

				local title = STRINGS.WEAPONS.UNLOCK.TITLE
				local unlock_string = STRINGS.WEAPONS.UNLOCK[weapon_type] or string.format("%s UNLOCK STRING MISSING", weapon_type)
				local how_to_play = STRINGS.WEAPONS.HOW_TO_PLAY[weapon_type] or string.format("%s HOW TO PLAY STRING MISSING", weapon_type)
				local focus_hit = STRINGS.WEAPONS.FOCUS_HIT[weapon_type] or string.format("%s FOCUS HIT STRING MISSING", weapon_type)
				local description = string.format("%s\n\n%s\n\n%s", unlock_string, how_to_play, focus_hit)

				local screen = ItemUnlockPopup(nil, nil, true)
					:SetItemUnlock(item, title, description)
				TheFrontEnd:PushScreen(screen)
				screen:SetOnDoneFn(function(accepted)
					TheFrontEnd:PopScreen(screen)
			    end)
			    screen:AnimateIn()
			end)
			:LayoutBounds("left", "below", new_notif)
			:Offset(0, -60)

		-- Armor unlock
		local armor_btn = container:AddChild(Clickable())
			:SetName("Armor button")
			:SetScales(1, 1.05, 0.98, 0.1, 0.3)
		local armor_icon = armor_btn:AddChild(Image("images/icons_ftf/inventory_head.tex"))
			:SetName("Armor icon")
			:SetSize(250, 250)
			:SetMultColor(UICOLORS.DARK_TEXT)
		local armor_title = armor_btn:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_SUBTITLE))
			:SetName("Armor title")
			:SetGlyphColor(UICOLORS.DARK_TEXT)
			:SetAutoSize(500)
			:SetText("Armor unlock popup!")
			:LayoutBounds("center", "below", armor_icon)
			:Offset(0, -40)
		local armor_text = armor_btn:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
			:SetName("Armor text")
			:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
			:SetAutoSize(500)
			:SetText("Opens when the player unlocks\na new monster's armor.")
			:LayoutBounds("center", "below", armor_title)
			:Offset(0, -10)
		armor_btn:SetOnClick(function()
				self:_ShowClipboardNotification()
				ui:SetClipboardText([[
local ItemUnlockPopup = require "screens.itemunlockpopup"

local monster_id = "zucco"

local screen = ItemUnlockPopup(nil, nil, true)
	:SetArmourSetUnlock(monster_id)
TheFrontEnd:PushScreen(screen)
screen:SetOnDoneFn(function(accepted)
	TheFrontEnd:PopScreen(screen)
end)
screen:AnimateIn()
]])

				local monster_id = "zucco"

				local screen = ItemUnlockPopup(nil, nil, true)
					:SetArmourSetUnlock(monster_id)
				TheFrontEnd:PushScreen(screen)
				screen:SetOnDoneFn(function(accepted)
					TheFrontEnd:PopScreen(screen)
			    end)
			    screen:AnimateIn()
			end)
			:LayoutBounds("after", "top", weapon_btn)
			:Offset(80, 0)

		-- Generic unlock
		local generic_btn = container:AddChild(Clickable())
			:SetName("Generic button")
			:SetScales(1, 1.05, 0.98, 0.1, 0.3)
		local generic_icon = generic_btn:AddChild(Image("images/icons_ftf/inventory_equipment.tex"))
			:SetName("Generic icon")
			:SetSize(250, 250)
			:SetMultColor(UICOLORS.DARK_TEXT)
		local generic_title = generic_btn:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_SUBTITLE))
			:SetName("Generic title")
			:SetGlyphColor(UICOLORS.DARK_TEXT)
			:SetAutoSize(500)
			:SetText("Generic unlock popup!")
			:LayoutBounds("center", "below", generic_icon)
			:Offset(0, -40)
		local generic_text = generic_btn:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
			:SetName("Generic text")
			:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
			:SetAutoSize(500)
			:SetText("Pass in any icon, title and\ndescription to build the popup.")
			:LayoutBounds("center", "below", generic_title)
			:Offset(0, -10)
		generic_btn:SetOnClick(function()
				self:_ShowClipboardNotification()
				ui:SetClipboardText([[
local ItemUnlockPopup = require "screens.itemunlockpopup"

local screen = ItemUnlockPopup(nil, nil, true)
	:SetIconUnlock(monster_pictures.tex['research_widget_megatreemon'], "Something unlocked!", "Great job, you!")
TheFrontEnd:PushScreen(screen)
screen:SetOnDoneFn(function(accepted)
	TheFrontEnd:PopScreen(screen)
end)
screen:AnimateIn()
]])

				local screen = ItemUnlockPopup(nil, nil, true)
					:SetIconUnlock(monster_pictures.tex['research_widget_megatreemon'], "Something unlocked!", "Great job, you!")
				TheFrontEnd:PushScreen(screen)
				screen:SetOnDoneFn(function(accepted)
					TheFrontEnd:PopScreen(screen)
				end)
				screen:AnimateIn()
			end)
			:LayoutBounds("after", "top", armor_btn)
			:Offset(80, 0)

		-- Confirm dialog
		local confirm_btn = container:AddChild(Clickable())
			:SetName("Confirm button")
			:SetScales(1, 1.05, 0.98, 0.1, 0.3)
		local confirm_icon = confirm_btn:AddChild(Image("images/icons_ftf/ic_unknown.tex"))
			:SetName("Confirm icon")
			:SetSize(250, 250)
			:SetMultColor(UICOLORS.DARK_TEXT)
		local confirm_title = confirm_btn:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_SUBTITLE))
			:SetName("Confirm title")
			:SetGlyphColor(UICOLORS.DARK_TEXT)
			:SetAutoSize(500)
			:SetText("Dialog!")
			:LayoutBounds("center", "below", confirm_icon)
			:Offset(0, -40)
		local confirm_text = confirm_btn:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
			:SetName("Confirm text")
			:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
			:SetAutoSize(500)
			:SetText("Ask the player to confirm something.")
			:LayoutBounds("center", "below", confirm_title)
			:Offset(0, -10)
		confirm_btn:SetOnClick(function()
				self:_ShowClipboardNotification()
				ui:SetClipboardText([[
local ConfirmDialog = require "screens.dialogs.confirmdialog"

local title = "Discard Item?"
local subtitle = "Decorative Pink Hedge"
local message = "Discarding this item will convert it to 40 <p img='images/icons_ftf/ic_coin.tex' scale=1.0 color=0>. Are you sure?"

local screen = ConfirmDialog(nil, nil, true,
	title, -- Optional
	subtitle, -- Optional
	message -- Optional
)
screen:SetYesButton(STRINGS.UI.MAINSCREEN.YES, function() screen:Close() end)
	:SetNoButton(STRINGS.UI.MAINSCREEN.NO, function() screen:Close() end)
	:SetCancelButton(STRINGS.UI.BUTTONS.CANCEL, function() screen:Close() end) -- Optional
	:SetCloseButton(function() screen:Close() end) -- Optional. Top right X button
	:HideArrow() -- An arrow can show under the dialog pointing at the clicked element
	:SetMinWidth(600)
	:CenterText() -- Aligns left otherwise
	:CenterButtons() -- They align left otherwise
TheFrontEnd:PushScreen(screen)
screen:AnimateIn()
]])

				local title = "Discard Item?"
				local subtitle = "Decorative Pink Hedge"
				local message = "Discarding this item will convert it to 40 <p img='images/icons_ftf/ic_coin.tex' scale=1.0 color=0>. Are you sure?"
				local screen = ConfirmDialog(nil, nil, true,
					title,
					subtitle,
					message)
				screen:SetYesButton(STRINGS.UI.MAINSCREEN.YES, function() screen:Close() end)
					:SetNoButton(STRINGS.UI.MAINSCREEN.NO, function() screen:Close() end)
					:SetCloseButton(function() screen:Close() end)
					:HideArrow()
					:SetMinWidth(600)
					:CenterText()
					:CenterButtons()
				TheFrontEnd:PushScreen(screen)
				screen:AnimateIn()

			end)
			:LayoutBounds("after", "top", generic_btn)
			:Offset(80, 0)

		-- Waiting dialog
		local waiting_btn = container:AddChild(Clickable())
			:SetName("Waiting button")
			:SetScales(1, 1.05, 0.98, 0.1, 0.3)
		waiting_btn.icon = waiting_btn:AddChild(Image("images/ui_ftf_dialog/dialog_time_remaining_icon.tex"))
			:SetName("Waiting icon")
			:SetSize(250, 250)
			:SetMultColor(UICOLORS.DARK_TEXT)
		waiting_btn.title = waiting_btn:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.DIALOG_SUBTITLE))
			:SetName("Waiting title")
			:SetGlyphColor(UICOLORS.DARK_TEXT)
			:SetAutoSize(500)
			:SetText("Wait!")
			:LayoutBounds("center", "below", waiting_btn.icon)
			:Offset(0, -40)
		waiting_btn.text = waiting_btn:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
			:SetName("Waiting text")
			:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
			:SetAutoSize(500)
			:SetText("Tell the player to wait for saving, loading, connecting, etc.")
			:LayoutBounds("center", "below", waiting_btn.title)
			:Offset(0, -10)
		waiting_btn:SetOnClick(function()
				self:_ShowClipboardNotification()
				ui:SetClipboardText([[
local WaitingDialog = require "screens.dialogs.waitingdialog"

local popup = WaitingDialog()
		:SetTitle(STRINGS.UI.NOTIFICATION.SAVING)
TheFrontEnd:PushScreen(popup)
popup:AnimateIn()

self.inst:DoTaskInTime(2, function()
	-- After you're done your long-running action, pop.
	TheFrontEnd:PopScreen(popup)
end)
]])

				local popup = WaitingDialog()
						:SetTitle(STRINGS.UI.NOTIFICATION.SAVING)
				TheFrontEnd:PushScreen(popup)
				popup:AnimateIn()

				self.inst:DoTaskInTime(2, function()
					TheFrontEnd:PopScreen(popup)
				end)

			end)
			:LayoutBounds("after", "top", confirm_btn)
			:Offset(80, 0)


		container:LayoutBounds("left", "top", 0, 0)
			:Offset(-self.content_w/2 + 50, 0)

	end)
end



function UITestScreen:AddContainersContents()
	self:_AddTabPanel("Containers", function(container)

	local price_text = container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
		:SetAutoSize(1000)
		:SetText("<p img='images/ui_ftf/arrow_down.tex' scale=0.7 color=0> Price badges can be used to display a prominent stat/value/currency amount on a screen. <#SPEECH_TEXT>One per screen</> at most. Their height can change.\n\nThe ones on the left can be shown over a corner of a popup, and the ones on the right are meant to be displayed on the edge of the screen.")

	local price_badge_normal = self:_AddClickableWidget(container,
		Panel("images/ui_ftf/price_badge_normal.tex")
			:SetName("Price badge")
			:SetNineSliceCoords(46, 0, 494, 170)
			:SetSize(550, 170),
		[[
local price_badge_normal = self:AddChild(Panel("images/ui_ftf/price_badge_normal.tex"))
	:SetName("Price badge")
	:SetNineSliceCoords(46, 0, 494, 170)
	:SetSize(550, 170)
]])
		:LayoutBounds("left", "below")
		:Offset(0, -40)

	local price_badge_dark = self:_AddClickableWidget(container,
		Panel("images/ui_ftf/price_badge_dark.tex")
			:SetName("Price badge")
			:SetNineSliceCoords(46, 0, 494, 170)
			:SetSize(550, 170),
		[[
local price_badge_dark = self:AddChild(Panel("images/ui_ftf/price_badge_dark.tex"))
	:SetName("Price badge")
	:SetNineSliceCoords(46, 0, 494, 170)
	:SetSize(550, 170)
]])
		:LayoutBounds("left", "below")
		:Offset(0, -30)

	local price_badge_konjur = self:_AddClickableWidget(container,
		Panel("images/ui_ftf/price_badge_konjur.tex")
			:SetName("Price badge")
			:SetNineSliceCoords(46, 0, 494, 170)
			:SetSize(550, 170),
		[[
local price_badge_konjur = self:AddChild(Panel("images/ui_ftf/price_badge_konjur.tex"))
	:SetName("Price badge")
	:SetNineSliceCoords(46, 0, 494, 170)
	:SetSize(550, 170)
]])
		:LayoutBounds("left", "below")
		:Offset(0, -30)

	local price_badge_tint = self:_AddClickableWidget(container,
		Panel("images/ui_ftf/price_badge_tint.tex")
			:SetName("Price badge")
			:SetNineSliceCoords(46, 0, 494, 170)
			:SetSize(550, 170),
		[[
local price_badge_tint = self:AddChild(Panel("images/ui_ftf/price_badge_tint.tex"))
	:SetName("Price badge")
	:SetNineSliceCoords(46, 0, 494, 170)
	:SetSize(550, 170)
	:SetMultColor(HexToRGB(0x61E49EFF))
]])
		:LayoutBounds("left", "below")
		:Offset(0, -30)
	price_badge_tint:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(500)
		:SetText("Tintable to any color")
		:Offset(-5, 10)

	local left_badge_normal = self:_AddClickableWidget(container,
		Panel("images/ui_ftf/left_badge_normal.tex")
			:SetName("Price badge")
			:SetNineSliceCoords(46, 0, 494, 170)
			:SetSize(550, 170),
		[[
local left_badge_normal = self:AddChild(Panel("images/ui_ftf/left_badge_normal.tex"))
	:SetName("Price badge")
	:SetNineSliceCoords(46, 0, 494, 170)
	:SetSize(550, 170)
]])
		:LayoutBounds("after", "top", price_badge_normal)
		:Offset(50, 0)

	local left_badge_dark = self:_AddClickableWidget(container,
		Panel("images/ui_ftf/left_badge_dark.tex")
			:SetName("Price badge")
			:SetNineSliceCoords(46, 0, 494, 170)
			:SetSize(550, 170),
		[[
local left_badge_dark = self:AddChild(Panel("images/ui_ftf/left_badge_dark.tex"))
	:SetName("Price badge")
	:SetNineSliceCoords(46, 0, 494, 170)
	:SetSize(550, 170)
]])
		:LayoutBounds("after", "top", price_badge_dark)
		:Offset(50, 0)

	local left_badge_konjur = self:_AddClickableWidget(container,
		Panel("images/ui_ftf/left_badge_konjur.tex")
			:SetName("Price badge")
			:SetNineSliceCoords(46, 0, 494, 170)
			:SetSize(550, 170),
		[[
local left_badge_konjur = self:AddChild(Panel("images/ui_ftf/left_badge_konjur.tex"))
	:SetName("Price badge")
	:SetNineSliceCoords(46, 0, 494, 170)
	:SetSize(550, 170)
]])
		:LayoutBounds("after", "top", price_badge_konjur)
		:Offset(50, 0)

	local left_badge_tint = self:_AddClickableWidget(container,
		Panel("images/ui_ftf/left_badge_tint.tex")
			:SetName("Price badge")
			:SetNineSliceCoords(46, 0, 494, 170)
			:SetSize(550, 170),
		[[
local left_badge_konjur = self:AddChild(Panel("images/ui_ftf/left_badge_konjur.tex"))
	:SetName("Price badge")
	:SetNineSliceCoords(46, 0, 494, 170)
	:SetSize(550, 170)
	:SetMultColor(HexToRGB(0x61E49EFF))
]])
		:LayoutBounds("after", "top", price_badge_tint)
		:Offset(50, 0)
	left_badge_tint:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(500)
		:SetText("This one too")
		:Offset(-45, 10)


	---------------------------------------------------------------------------

	local popup_text = container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
		:SetAutoSize(1200)
		:SetText("<p img='images/ui_ftf/arrow_down.tex' scale=0.7 color=0> Popups to display info after the player interacted with something. They can display why something is disabled, or additional context for the player.")
		:LayoutBounds("left", "below", price_badge_tint)
		:Offset(0, -100)

	local popup_message_down = self:_AddClickableWidget(container,
		Image("images/ui_ftf/popup_message_down.tex")
			:SetName("Popup message down"),
		[[
local popup_message_down = self:AddChild(Image("images/ui_ftf/popup_message_down.tex"))
	:SetName("Popup message down")
]])
		:LayoutBounds("left", "below", popup_text)
		:Offset(0, -60)

	local popup_message_up = self:_AddClickableWidget(container,
		Image("images/ui_ftf/popup_message_up.tex")
			:SetName("Popup message up"),
		[[
local popup_message_up = self:AddChild(Image("images/ui_ftf/popup_message_up.tex"))
	:SetName("Popup message up")
]])
		:LayoutBounds("after", "top")
		:Offset(40, 30)

	local popup_message_right = self:_AddClickableWidget(container,
		Panel("images/ui_ftf/popup_message_right.tex")
			:SetName("Popup message right")
			:SetNineSliceCoords(40, 0, 605, 200)
			:SetSize(670, 200),
		[[
local popup_message_right = self:AddChild(Panel("images/ui_ftf/popup_message_right.tex"))
	:SetName("Popup message right")
	:SetNineSliceCoords(40, 0, 605, 200)
	:SetSize(670, 200)
]])
		:LayoutBounds("left", "below", popup_message_down)
		:Offset(240, -40)
	popup_message_right:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(600)
		:SetText("(9-slice)\nWidth can be expanded")
		:Offset(0, 10)

	---------------------------------------------------------------------------

	local containers_text = container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
		:SetAutoSize(1200)
		:SetText("<p img='images/ui_ftf/arrow_down.tex' scale=0.7 color=0> Generic images and 9-slices that can be used for various purposes.\nThe dark ones are 9slices, so they <#SPEECH_TEXT>can be resized</> more freely without getting distorted.")
		:LayoutBounds("left", "top", price_text)
		:Offset(1300, 0)

	local round_bg = self:_AddClickableWidget(container,
		Image("images/ui_ftf/round_bg.tex")
			:SetName("Panel")
			:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_DARK),
		[[
local round_bg = self:AddChild(Image("images/ui_ftf/round_bg.tex"))
	:SetName("Panel")
	:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
]])
		:LayoutBounds("left", "below", containers_text)
		:Offset(0, -60)

	local small_panel_narrow = self:_AddClickableWidget(container,
		Image("images/ui_ftf/small_panel_narrow.tex")
			:SetName("Panel")
			:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_DARK),
		[[
local small_panel_narrow = self:AddChild(Image("images/ui_ftf/small_panel_narrow.tex"))
	:SetName("Panel")
	:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
]])
		:LayoutBounds("after", "top")
		:Offset(40, 0)

	local small_panel = self:_AddClickableWidget(container,
		Image("images/ui_ftf/small_panel.tex")
			:SetName("Panel")
			:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_DARK),
		[[
local small_panel = self:AddChild(Image("images/ui_ftf/small_panel.tex"))
	:SetName("Panel")
	:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
]])
		:LayoutBounds("after", "top")
		:Offset(40, 0)

	local small_panel_wide = self:_AddClickableWidget(container,
		Panel("images/ui_ftf/small_panel_wide.tex")
			:SetName("Panel")
			:SetNineSliceCoords(9, 0, 553, 120)
			:SetSize(560, 120)
			:SetMultColor(UICOLORS.LIGHT_TEXT_DARK),
		[[
local small_panel_wide = self:AddChild(Panel("images/ui_ftf/small_panel_wide.tex"))
	:SetName("Panel")
	:SetNineSliceCoords(9, 0, 553, 120)
	:SetSize(560, 120)
	:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
]])
		:LayoutBounds("after", "top")
		:Offset(40, 0)

	local popup_dialog_gradient = self:_AddClickableWidget(container,
		Image("images/ui_ftf_unlock/popup_dialog_gradient.tex")
			:SetName("Circular gradient")
			:SetSize(400, 400),
		[[
local popup_dialog_gradient = self:AddChild(Image("images/ui_ftf_unlock/popup_dialog_gradient.tex"))
	:SetName("Circular gradient")
	:SetSize(600, 600)
]])
		:LayoutBounds("after", "bottom", small_panel_wide)
		:Offset(40, 0)

	local angled_panel = self:_AddClickableWidget(container,
		Panel("images/ui_ftf/angled_panel.tex")
			:SetName("Panel")
			:SetNineSliceCoords(34, 48, 199, 197)
			:SetSize(240, 240)
			:SetMultColor(UICOLORS.LIGHT_TEXT_DARK),
		[[
local angled_panel = self:AddChild(Panel("images/ui_ftf/angled_panel.tex"))
	:SetName("Panel")
	:SetNineSliceCoords(34, 48, 199, 197)
	:SetSize(240, 240)
	:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
]])
		:LayoutBounds("left", "below", round_bg)
		:Offset(0, -80)

	local cornered_panel = self:_AddClickableWidget(container,
		Panel("images/ui_ftf/cornered_panel.tex")
			:SetName("Panel")
			:SetNineSliceCoords(44, 40, 208, 200)
			:SetSize(240, 240)
			:SetMultColor(UICOLORS.LIGHT_TEXT_DARK),
		[[
local cornered_panel = self:AddChild(Panel("images/ui_ftf/cornered_panel.tex"))
	:SetName("Panel")
	:SetNineSliceCoords(44, 40, 208, 200)
	:SetSize(240, 240)
	:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
]])
		:LayoutBounds("after", "top")
		:Offset(40, 0)

	local hex_vertical = self:_AddClickableWidget(container,
		Image("images/ui_ftf/hex_vertical.tex")
			:SetName("Panel")
			:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_DARK),
		[[
local hex_vertical = self:AddChild(Image("images/ui_ftf/hex_vertical.tex"))
	:SetName("Panel")
	:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
]])
		:LayoutBounds("after", "top")
		:Offset(40, 30)

	local hex_horizontal = self:_AddClickableWidget(container,
		Image("images/ui_ftf/hex_horizontal.tex")
			:SetName("Panel")
			:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_DARK),
		[[
local hex_horizontal = self:AddChild(Image("images/ui_ftf/hex_horizontal.tex"))
	:SetName("Panel")
	:SetMultColor(UICOLORS.LIGHT_TEXT_DARK)
]])
		:LayoutBounds("after", "top")
		:Offset(40, 0)

	local dialog_bg = self:_AddClickableWidget(container,
		Panel("images/ui_ftf/dialog_bg.tex")
			:SetName("Panel")
			:SetNineSliceCoords(50, 28, 550, 239)
			:SetSize(600, 260),
		[[
local dialog_bg = self:AddChild(Panel("images/ui_ftf/dialog_bg.tex"))
	:SetName("Panel")
	:SetNineSliceCoords(50, 28, 550, 239)
	:SetSize(600, 260)
dialog_bg:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
	:SetText("Example Text")
]])
		:LayoutBounds("after", "center", hex_horizontal)
		:Offset(40, 0)
	dialog_bg:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(600)
		:SetText("(9-slice)\nWidth and height can be expanded")
		:Offset(0, 10)


	---------------------------------------------------------------------------

	local screens_text = container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
		:SetAutoSize(1200)
		:SetText("<p img='images/ui_ftf/arrow_down.tex' scale=0.7 color=0> Large images to use as screen or large panel backgrounds.")
		:LayoutBounds("left", "below", angled_panel)
		:Offset(0, -100)

	local popup_dialog_bg = self:_AddClickableWidget(container,
		Image("images/ui_ftf_unlock/popup_dialog_bg.tex")
			:SetName("Dialog background")
			:SetSize(2730*0.3, 1330*0.3),
		[[
local popup_dialog_bg = self:AddChild(Image("images/ui_ftf_unlock/popup_dialog_bg.tex"))
	:SetName("Dialog background")
popup_dialog_bg:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
	:SetText("Example Text")
]])
		:LayoutBounds("left", "below", screens_text)
		:Offset(0, -40)
	popup_dialog_bg:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(600)
		:SetText("Good for large popups (~70% screen width)")
		:Offset(0, 10)

	local popup_flat_bg = self:_AddClickableWidget(container,
		Image("images/bg_popup_flat/popup_flat.tex")
			:SetName("Dialog background")
			:SetSize(3330*0.25, 1640*0.25),
		[[
local popup_flat_bg = self:AddChild(Image("images/bg_popup_flat/popup_flat.tex"))
	:SetName("Dialog background")
popup_flat_bg:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
	:SetText("Example Text")
]])
		:LayoutBounds("after", "center")
		:Offset(40, 0)
	popup_flat_bg:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(600)
		:SetText("Has a flat top and bottom, so it can have a scroll panel inside.\n\nGood for huge popups (~95% screen width)")
		:Offset(0, 10)

	local popup_small = self:_AddClickableWidget(container,
		Image("images/bg_popup_small/popup_small.tex")
			:SetName("Popup background")
			:SetSize(1600*0.5, 900*0.5),
		[[
local popup_small = self:AddChild(Image("images/bg_popup_small/popup_small.tex"))
	:SetName("Popup background")
popup_small:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
	:SetText("Example Text")
]])
		:LayoutBounds("left", "below", popup_dialog_bg)
		:Offset(0, -40)
	popup_small:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(600)
		:SetText("Better for smaller popups (~30% screen width)")
		:Offset(0, 10)

	local widebanner = self:_AddClickableWidget(container,
		Image("images/bg_widebanner/widebanner.tex")
			:SetName("Banner background")
			:SetSize(3841*0.25, 1331*0.25),
		[[
local widebanner = self:AddChild(Image("images/bg_widebanner/widebanner.tex"))
	:SetName("Banner background")
widebanner:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
	:SetText("Example Text")
]])
		:LayoutBounds("after", "center")
		:Offset(40, 0)
	widebanner:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(600)
		:SetText("Good for huge popups (100% screen width), but around 50% height")
		:Offset(0, 10)

	local weapons_panel_bg = self:_AddClickableWidget(container,
		Image("images/ui_ftf_gems/weapons_panel_bg.tex")
			:SetName("Panel background")
			:SetSize(1590*0.4, 1620*0.4),
		[[
local weapons_panel_bg = self:AddChild(Image("images/ui_ftf_gems/weapons_panel_bg.tex"))
	:SetName("Panel background")
weapons_panel_bg:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetGlyphColor(UICOLORS.LIGHT_TEXT)
	:SetText("Example Text")
]])
		:LayoutBounds("left", "below", popup_small)
		:Offset(0, -40)
	weapons_panel_bg:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(600)
		:SetText("Good to display next to  <p img='images/ui_ftf/arrow_right.tex' scale=0.5 color=0> \n(~40% screen width, ~80% height)")
		:Offset(0, 10)

	local gems_panel_bg = self:_AddClickableWidget(container,
		Image("images/ui_ftf_gems/gems_panel_bg.tex")
			:SetName("Panel background")
			:SetSize(1350*0.4, 1500*0.4),
		[[
local gems_panel_bg = self:AddChild(Image("images/ui_ftf_gems/gems_panel_bg.tex"))
	:SetName("Panel background")
gems_panel_bg:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
	:SetText("Example Text")
]])
		:LayoutBounds("after", "center")
		:Offset(40, 0)
	gems_panel_bg:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(450)
		:SetText("<p img='images/ui_ftf/arrow_left.tex' scale=0.5 color=0>  Good to display next to\n(~30% screen width, ~70% height)")
		:Offset(0, 10)

	local titles_text = container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:LeftAlign()
		:SetAutoSize(600)
		:SetText("<p img='images/ui_ftf/arrow_left.tex' scale=0.7 color=0>  Most large panels can use the image below to contain their title or tabs.\n\nIt should always look like it blends into their inner frame: UICOLORS.LIGHT_BACKGROUNDS_DARK")
		:LayoutBounds("after", "top", gems_panel_bg)
		:Offset(60, -50)

	local gem_panel_title_bg = self:_AddClickableWidget(container,
		Image("images/ui_ftf_gems/gem_panel_title_bg.tex")
			:SetName("Title background")
			:SetSize(560, 120),
		[[
local title_bg = self:AddChild(Image("images/ui_ftf_gems/gem_panel_title_bg.tex"))
	:SetName("Title background")
	:SetSize(560, 120)
]])
		:LayoutBounds("left", "below")
		:Offset(0, -60)

	local research_screen_left = self:_AddClickableWidget(container,
		Panel("images/bg_research_screen_left/research_screen_left.tex")
			:SetName("Panel background")
			:SetNineSliceCoords(200, 1080, 1414, 1755)
			:SetSize(1600, 2160)
			:SetScale(0.4),
		[[
local research_screen_left = self:AddChild(Panel("images/bg_research_screen_left/research_screen_left.tex"))
	:SetName("Panel background")
	:SetNineSliceCoords(200, 1080, 1414, 1755)
	:SetSize(1600, 2160)
research_screen_left:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
	:SetText("Example Text")
]])
		:LayoutBounds("left", "below", weapons_panel_bg)
		:Offset(0, -40)
	research_screen_left:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARKER)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(550)
		:SetText("Good for tall panels (100% screen height)\n\nIt's a 9-slice, so the width can be adjusted at will")
		:Offset(0, 100)

	local research_screen_right = self:_AddClickableWidget(container,
		Image("images/bg_research_screen_right/research_screen_right.tex")
			:SetName("Panel background")
			:SetSize(1510*0.4, 2160*0.4),
		[[
local research_screen_right = self:AddChild(Image("images/bg_research_screen_right/research_screen_right.tex"))
	:SetName("Panel background")
research_screen_right:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	:SetGlyphColor(UICOLORS.LIGHT_TEXT)
	:SetText("Example Text")
]])
		:LayoutBounds("after", "center")
		:Offset(40, 0)
	research_screen_right:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetHAlign(ANCHOR_MIDDLE)
		:SetAutoSize(600)
		:SetText("Good for tall panels (100% screen height)")
		:Offset(0, 10)

	-- local popup_message_down = container:AddChild(Panel("images/ui_ftf_research/research_tabs_bg.tex"))
	-- 	:SetName("Tabs background")
	-- 	:SetNineSliceCoords(26, 0, 195, 150)
	-- 	:SetMultColor(UICOLORS.LIGHT_BACKGROUNDS_DARK)


	-- 	-- Nineslices
	-- 	local nineslice_container = container:AddChild(Widget())
	-- 	nineslice_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	-- 		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
	-- 		:LeftAlign()
	-- 		:SetAutoSize(800)
	-- 		:SetText("Panel: our 9slice\nTheir slice coordinates start from the top left, and are set through \n\t:SetNineSliceCoords(minx, miny, maxx, maxy)\nYou can also set the scale of the border through \n\t:SetNineSliceBorderScale(0.5)")
	-- 	local focus_bracket = nineslice_container:AddChild(Panel("images/ui_ftf_roombonus/bonus_selection.tex"))
	-- 		:SetNineSliceCoords(100, 60, 110, 70)
	-- 		:SetNineSliceBorderScale(0.5)
	-- 		:SetMultColor(UICOLORS.FOCUS)
	-- 		:SetSize(120, 120)
	-- 		:LayoutBounds("left", "below")
	-- 		:Offset(0, -20)
	-- 	nineslice_container:AddChild(self:GetInfoLabel([[
	-- Panel("images/ui_ftf_roombonus/bonus_selection.tex")
	-- 	:SetNineSliceCoords(100, 60, 110, 70)
	-- 	:SetNineSliceBorderScale(0.5)
	-- 	:SetMultColor(UICOLORS.FOCUS)
	-- ]]))
	-- 		:LayoutBounds("after", "top")
	-- 		:Offset(40, 0)

	-- 	-- Containers
	-- 	local containers_container = container:AddChild(Widget())
	-- 	containers_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	-- 		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
	-- 		:LeftAlign()
	-- 		:SetAutoSize(800)
	-- 		:SetText("Full screen-width popup:")
	-- 	local widePopup = containers_container:AddChild(Image("images/bg_feedback_screen_bg/feedback_screen_bg.tex"))
	-- 		:SetSize(RES_X, 660)
	-- 		:SetScale(0.2)
	-- 		:LayoutBounds("left", "below")
	-- 		:Offset(0, -20)
	-- 	containers_container:AddChild(self:GetInfoLabel([[
	-- Image("images/bg_feedback_screen_bg/feedback_screen_bg.tex")
	-- 	:SetSize(RES_X, 660)
	-- ]]))
	-- 		:LayoutBounds("after", "top")
	-- 		:Offset(40, 0)
	-- 	containers_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	-- 		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
	-- 		:LeftAlign()
	-- 		:SetAutoSize(800)
	-- 		:SetText("Container panel within a larger block")
	-- 		:LayoutBounds("left", "below", widePopup)
	-- 		:Offset(0, -30)
	-- 	local inner_panel = containers_container:AddChild(Panel("images/ui_ftf_crafting/craft_details_bg.tex"))
	-- 		:SetNineSliceCoords(29, 29, 31, 31)
	-- 		:SetSize(200, 150)
	-- 		:SetMultColor(UICOLORS.BLACK)
	-- 		:SetMultColorAlpha(0.3)
	-- 		:LayoutBounds("left", "below")
	-- 		:Offset(0, -20)
	-- 	containers_container:AddChild(self:GetInfoLabel([[
	-- Panel("images/ui_ftf_crafting/craft_details_bg.tex")
	-- 	:SetNineSliceCoords(29, 29, 31, 31)
	-- 	:SetSize(200, 150)
	-- 	:SetMultColor(UICOLORS.BACKGROUND_DARK)
	-- 	:SetMultColorAlpha(0.3)
	-- ]]))
	-- 		:LayoutBounds("after", "top")
	-- 		:Offset(40, 0)
	-- 	containers_container:LayoutBounds("left", "below", nineslice_container)
	-- 		:Offset(0, -100)

	-- 	-- Scroll
	-- 	scroll_container = container:AddChild(Widget())
	-- 	local scroll = scroll_container:AddChild(ScrollPanel())
	-- 		:SetSize(400, 200)
	-- 	local contents = scroll:AddScrollChild(Widget())
	-- 	local text = contents:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT))
	-- 		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
	-- 		:LeftAlign()
	-- 		:SetAutoSize(350)
	-- 		:SetText("This is a scroll panel sized 400*300px. Virtual margins add spacing at the top and bottom, so elements don't touch the bounds.\n\nTo add widgets to a scroll panel, you need to call scrollWidget:AddScrollChild(new widget). They'll get aligned to the center top of the scroll area by default. Offset them by half the width of the scroll to align them to the left.\n\nAfter changing the contents of a scroll panel, you need to call :RefreshView() on it to refresh the scroll bar.")
	-- 		:LayoutBounds("left", "top")
	-- 		:Offset(-200, 0)
	-- 	scroll:RefreshView()
	-- 		:LayoutBounds("left", "top", 0, 0)
	-- 		:Offset(0, 0)
	-- 	scroll_container:AddChild(self:GetInfoLabel([[
	-- local scroll = ScrollPanel()
	-- 	:SetSize(400, 300)
	-- 	:SetVirtualMargin(20)

	-- local contents = scroll:AddScrollChild(Widget())

	-- contents:AddChild(Image("images/global/square.tex"))
	-- 	:SetSize(100, 100)

	-- scroll:RefreshView()
	-- ]]))
	-- 		:LayoutBounds("after", "top")
	-- 		:Offset(40, 0)

		container:LayoutBounds("left", "top", 0, 0)
			:Offset(-self.content_w/2, 0)

	end)
end

-- Returns a Widget container for you to add elements to
function UITestScreen:_AddTabPanel(tab_text, on_click)
	local tab_btn = self.tab_group:AddTextTab(tab_text, 60)
	tab_btn.tab_text = tab_text
	self.tab_callbacks[tab_text] = on_click
end

function UITestScreen:OnTabClicked(tab_text)
	-- Remove existing contents
	self.scrollContents:RemoveAllChildren()

	-- Add new stuff by invoking the correct callback
	self.tab_callbacks[tab_text](self.scrollContents)

	-- Refresh scroll
	self.scroll:RefreshView()
end

function UITestScreen:GetInfoLabel(label_text, max_width)
	local info_label_color = UICOLORS.DEBUG
	local info_label_clickable = Clickable()
		:SetOnClickFn(function()
			ui:SetClipboardText(label_text)
		end)
	local info_label = info_label_clickable:AddChild(Text(FONTFACE.DEFAULT, 30))
		:SetGlyphColor(info_label_color)
		:LeftAlign()
		:SetAutoSize(max_width or 300)
		:SetHoverCheck(true)
		:SetText(label_text)
	info_label_clickable:SetOnHighlight(function(down, hover, selected, focus)
		info_label:SetGlyphColor((hover or focus) and HexToRGB(0xF6B742FF) or info_label_color)
	end)
	return info_label_clickable
end

UITestScreen.CONTROL_MAP =
{
	{
		control = Controls.Digital.CANCEL,
		fn = function(self)
			self.close_button:Click()
			return true
		end,
	},
}

return UITestScreen
