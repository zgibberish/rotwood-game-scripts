local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Menu = require "widgets/menu"
local Screen = require "widgets/screen"
local Text = require "widgets/text"
local SolidBox = require "widgets/solidbox"

local DIALOG_WIDTH = 2800
local HEADER_HEIGHT = 450
local MIDDLE_HEIGHT = 910
local FOOTER_HEIGHT = 160
local DIALOG_HEIGHT = 400
local ICON_SIZE = 250
local ERROR_TEXT_TOP_PADDING = 100 -- Space between the top of the text and the top of the bg
local H_PADDING = 150

--  ▼ dialog_container
-- ┌────────────────────────────────────────────────────────────────────────┐
-- │ header_container                                                       │
-- │  header_bg       ┌───────┐                                             │
-- │                  │icon   │ title                                       │
-- │                  │       │ subtitle                                    │
-- │                  │       │ additional_text                             │
-- │                  └───────┘                                             │
-- │                                                                        │
-- ├────────────────────────────────────────────────────────────────────────┤
-- │ middle_container                                                       │
-- │  middle_bg                                                             │
-- │                                                                        │
-- │                                                                        │
-- │                                                                        │
-- │                                                                        │
-- │                                                                        │
-- │                                                                        │
-- │                                                                        │
-- │                                                                        │
-- │                                                                        │
-- │                                                                        │
-- │                                                                        │
-- ├────────────────────────────────────────────────────────────────────────┤
-- │ footer_container                                                       │
-- │  footer_bg                                                             │
-- │                                                                        │
-- └────────────────────────────────────────────────────────────────────────┘

local ScriptErrorWidget = Class(Screen, function(self, title, text, buttons, texthalign, additionaltext, textsize, timeout)
	HideLoading(true)

	Screen._ctor(self, "ScriptErrorWidget")

	textsize = textsize or 24

	TheInput:SetCursorVisibleOverride(true)

	--darken everything behind the dialog
	self.black = self:AddChild(Image("images/global/square.tex"))
		:SetAnchors("fill", "fill")
		:SetMultColor(UICOLORS.BLACK)
		:SetMultColorAlpha(0.7)


	self.dialog_container = self:AddChild(Widget())
		:SetName("Dialog container")


	self.header_container = self.dialog_container:AddChild(Widget())
		:SetName("Header container")
	self.header_bg = self.header_container:AddChild(Image("images/global/square.tex"))
		:SetName("Header background")
		:SetMultColor(HexToRGB(0xCEB6A5ff))
		:SetMultColorAlpha(0.85)
		:SetSize(DIALOG_WIDTH, HEADER_HEIGHT)
	self.icon = self.header_container:AddChild(Image("images/ui_ftf/error_large.tex"))
		:SetName("Header icon")
		:SetMultColor(UICOLORS.BACKGROUND_MID)
		:SetSize(ICON_SIZE, ICON_SIZE)
	self.text_container = self.header_container:AddChild(Widget())
		:SetName("Text container")
	self.title = self.text_container:AddChild(Text(FONTFACE.DEFAULT, 110))
		:SetName("Title text")
		:LeftAlign()
		:SetGlyphColor(UICOLORS.BACKGROUND_MID)
		:SetAutoSize(DIALOG_WIDTH - H_PADDING*2 - ICON_SIZE)
		:SetText(title)
	self.subtitle = self.text_container:AddChild(Text(FONTFACE.DEFAULT, 60))
		:SetName("Subtitle text")
		:LeftAlign()
		:SetGlyphColor(HexToRGB(0x755751ff))
		:SetAutoSize(DIALOG_WIDTH - H_PADDING*2 - ICON_SIZE)
		:SetText(STRINGS.UI.MAINSCREEN.SCRIPTERRORSUBTITLE)
	self.additional_text = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.SCREEN_TEXT * 1.2))
		:SetName("Additional text")
		:LeftAlign()
		:SetGlyphColor(UICOLORS.BACKGROUND_DARK)
		:SetAutoSize(DIALOG_WIDTH - H_PADDING*2 - ICON_SIZE)
		:SetText(additionaltext or "")
		:SetShown(additionaltext)


	self.middle_container = self.dialog_container:AddChild(Widget())
		:SetName("Middle container")
	self.middle_bg = self.middle_container:AddChild(Image("images/global/square.tex"))
		:SetName("Middle background")
		:SetMultColor(HexToRGB(0xCEB6A5ff))
		:SetMultColorAlpha(0.7)
		:SetSize(DIALOG_WIDTH, MIDDLE_HEIGHT)
	self.middle_error_text = self.middle_container:AddChild(Text(FONTFACE.CODE, FONTSIZE.SCREEN_TEXT))
		:SetName("Error text")
		:SetRegionSize(DIALOG_WIDTH - H_PADDING*2, MIDDLE_HEIGHT - ERROR_TEXT_TOP_PADDING)
		:EnableWordWrap(true)
		:SetVAlign(ANCHOR_TOP)
		:SetHAlign(texthalign or ANCHOR_LEFT)
		:SetGlyphColor(UICOLORS.BACKGROUND_DARKEST)
		:SetText(text)


	self.footer_container = self.dialog_container:AddChild(Widget())
		:SetName("Footer container")
	self.footer_bg = self.footer_container:AddChild(Image("images/global/square.tex"))
		:SetName("Footer background")
		:SetMultColor(HexToRGB(0xCEB6A5ff))
		:SetMultColorAlpha(0.85)
		:SetSize(DIALOG_WIDTH, FOOTER_HEIGHT)


	self.version = self:AddChild(Text(FONTFACE.BODYTEXT, 20))
	self.version:SetAnchors("left", "bottom")
	self.version:SetHAlign(ANCHOR_LEFT)
	self.version:SetVAlign(ANCHOR_BOTTOM)
	self.version:SetRegionSize(200, 40)
	self.version:SetPosition(110, 30, 0)
	self.version:SetText("Rev. " .. APP_VERSION .. " " .. PLATFORM)


	-- sort out which buttons to in the more menu
	if buttons ~= nil then
		local rootbuttons = {}
		local more_buttons = {}
		for i,v in pairs(buttons) do
			if not v.submenu then
				rootbuttons[#rootbuttons+1] = v
			else
				more_buttons[#more_buttons+1] = v
				local cb = v.cb
				-- wrap the callback to have each button in the more menu return to the rootmenu
				more_buttons[#more_buttons].cb = function()
									TheFrontEnd.error_widget:ShowRootMenu()
									cb()
								end
			end
		end
		self.menu = self.footer_container:AddChild(Menu(rootbuttons, 350, true))
		self.default_focus = self.menu

		self.moremenu = self.footer_container:AddChild(Menu(more_buttons, 350, true))
		self.moremenu:Hide()
	end

	-- confirm dialog
	self.confirm_root = self:AddChild(Screen())
	local black = self.confirm_root:AddChild(Image("images/global/square.tex"))
		:SetAnchors("fill", "fill")
		:SetMultColor(UICOLORS.BLACK)
		:SetMultColorAlpha(0.7)

	local confirmbox = self.confirm_root:AddChild(SolidBox( DIALOG_WIDTH, DIALOG_HEIGHT, UICOLORS.LIGHT_TEXT ))
		:SetPosition(0, 90)
	local confirm_buttons = {
		{
			text = STRINGS.UI.MAINSCREEN.SCRIPTERROR_COPY_CLIPBOARD,
		},
		{
			text = STRINGS.UI.MAINSCREEN.SCRIPTERROR_COPY_CLIPBOARD,
		},
	}
	self.confirm_root.title = confirmbox:AddChild(Text(FONTFACE.TITLE, 90))
		:SetText("Dialog title <debug>")
		:SetPosition(0, 110, 0)
		:SetGlyphColor(UICOLORS.BACKGROUND_DARKEST)
	self.confirm_root.body = confirmbox:AddChild(Text(FONTFACE.TITLE, 60))
		:SetText("Dialog body <debug>")
		:SetPosition(0, 30, 0)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)

	local confirm_menu = Menu(confirm_buttons, 250, 0)
	confirm_menu:SetHRegPoint(ANCHOR_MIDDLE)
	confirm_menu:SetPosition(0, -100, 0)
	confirmbox:AddChild(confirm_menu)
	self.confirm_menu = confirm_menu
	self.confirm_root:Hide()

	TheSim:SetUIRoot(self.inst.entity)

	self:Layout()
end)

function ScriptErrorWidget:OnOpen()
	TheFrontEnd:HideTopFade();
	TheFrontEnd.blackoverlay:Hide()

	self:ShowRootMenu()
end

function ScriptErrorWidget:ShowRootMenu()
	self.moremenu:Hide()
	self.confirm_root:Hide()
	self.menu:Show()
	self.menu:SetFocus()
end

function ScriptErrorWidget:ShowMoreMenu()
	self.menu:Hide()
	self.confirm_root:Hide()
	self.moremenu:Show()
	self.moremenu:SetFocus()
	self.moremenu.items[#self.moremenu.items]:SetFocus()
end

function ScriptErrorWidget:ConfirmDialog(title, body, confirm_text, cancel_text, confirm_cb, cancel_cb)

	self.confirm_root:Show()
	self.confirm_root.title:SetString(title)
	self.confirm_root.body:SetString(body)

	self.confirm_menu.items[1]:SetText(confirm_text)
	self.confirm_menu.items[2]:SetText(cancel_text)

	self.confirm_menu.items[1]:SetOnClick(function() 
						if confirm_cb then
							confirm_cb()
						end
						self:ShowRootMenu()
					end)
	self.confirm_menu.items[2]:SetOnClick(function() 
						if cancel_cb then
							cancel_cb()
						end
						self:ShowRootMenu()
					end)
	self.confirm_menu.items[2]:SetFocus() -- default to no

	local error_widget = self
	-- add handler to cancel out of dialog and return to active menu
	self.confirm_menu.OnControl = function(self, controls, down)
		Menu.OnControl(self,controls,down)
		if controls:Has(Controls.Digital.CANCEL) then
			if error_widget.moremenu:IsVisible() then 
				error_widget:ShowMoreMenu()
			else
				error_widget:ShowRootMenu()
			end
		end
	end
end


function ScriptErrorWidget:OnUpdate(dt)
	-- debugkeys often don't catch Ctrl-R at this point, so handle it ourself.
	if DEV_MODE
		and TheInput:IsKeyDown(InputConstants.Keys.R)
		and TheInput:IsKeyDown(InputConstants.Keys.CTRL)
	then
		TheSim:ResetError()
		c_reset()
	end
end


function ScriptErrorWidget:Layout()

	-- Header
	self.icon:LayoutBounds("left", "center", self.header_bg)
		:Offset(H_PADDING, 0)
	self.subtitle:LayoutBounds("left", "below", self.title)
		:Offset(0, 0)
	self.additional_text:LayoutBounds("left", "below", self.subtitle)
		:Offset(0, -10)
	self.text_container:LayoutBounds("after", "center", self.icon)
		:Offset(40, 0)

	-- Middle
	self.middle_error_text:LayoutBounds("left", "top", self.middle_bg)
		:Offset(H_PADDING, -ERROR_TEXT_TOP_PADDING)

	-- Footer
	self.menu:LayoutBounds("center", "center", self.footer_bg)
	self.moremenu:LayoutBounds("center", "center", self.footer_bg)


	self.middle_container:LayoutBounds("left", "below", self.header_container)
	self.footer_container:LayoutBounds("left", "below", self.middle_container)
	self.dialog_container:LayoutBounds("center", "center", self)
end

return ScriptErrorWidget
