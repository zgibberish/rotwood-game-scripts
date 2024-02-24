local Screen = require "widgets/screen"
local Button = require "widgets/button"
local AnimButton = require "widgets/animbutton"
local Menu = require "widgets/menu"
local Text = require "widgets/text"
local Image = require "widgets/image"
local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"

local ModWarningScreen = Class(Screen, function(self, title, text, buttons, texthalign, additionaltext, textsize)
	Screen._ctor(self, "ModWarningScreen")

	--darken everything behind the dialog
	self.black = self:AddChild(Image("images/global.xml", "square.tex"))
    self.black:SetVRegPoint(ANCHOR_MIDDLE)
    self.black:SetHRegPoint(ANCHOR_MIDDLE)
    self.black:SetAnchors("center","center")
    self.black:SetScaleMode(SCALEMODE_FILLSCREEN)
	self.black:SetMultColor(0,0,0,.8)

	self.root = self:AddChild(Widget("ROOT"))
    self.root:SetAnchors("center","center")
    self.root:SetPosition(0,0,0)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

	--title
    self.title = self.root:AddChild(Text(FONTFACE.TITLE, 50))
    self.title:SetPosition(0, 170, 0)
    self.title:SetText(title)

	--text
	local defaulttextsize = 24
	if textsize then
		defaulttextsize = textsize
	end


    self.text = self.root:AddChild(Text(FONTFACE.BODYTEXT, defaulttextsize))
	self.text:SetVAlign(ANCHOR_TOP)

	if texthalign then
		self.text:SetHAlign(texthalign)
	end


    self.text:SetPosition(0, 40, 0)
    self.text:SetText(text)
    self.text:EnableWordWrap(true)
    self.text:SetRegionSize(480*2, 200)

    if additionaltext then
	    self.additionaltext = self.root:AddChild(Text(FONTFACE.BODYTEXT, 24))
		self.additionaltext:SetVAlign(ANCHOR_TOP)
	    self.additionaltext:SetPosition(0, -150, 0)
	    self.additionaltext:SetText(additionaltext)
	    self.additionaltext:EnableWordWrap(true)
	    self.additionaltext:SetRegionSize(480*2, 100)
    end

	self.version = self:AddChild(Text(FONTFACE.BODYTEXT, 20))
	--self.version:SetHRegPoint(ANCHOR_LEFT)
	--self.version:SetVRegPoint(ANCHOR_BOTTOM)
	self.version:SetAnchors("left", "center")
	self.version:SetVAlign(ANCHOR_BOTTOM)
	self.version:SetRegionSize(200, 40)
	self.version:SetPosition(110, 30, 0)
	self.version:SetText("Rev. "..APP_VERSION.." "..PLATFORM)

	if buttons then
	    --create the menu itself
	    local button_w = 200
	    local space_between = 20
	    local spacing = button_w + space_between

	    self.menu = self.root:AddChild(Menu(buttons, 250, true))
	    self.menu:SetHRegPoint(ANCHOR_MIDDLE)
	    self.menu:SetPosition(0, -250, 0)
	    self.default_focus = self.menu
	end

	if Platform.IsRail() then
		-- disable the mod forum button if it exists
		if self.menu and self.menu.items then
			for i,v in pairs(self.menu.items) do
				if v:GetText() == STRINGS.UI.MAINSCREEN.MODFORUMS then
					v:Select()
					v:SetToolTip(STRINGS.UI.MAINSCREEN.MODFORUMS_NOT_AVAILABLE_YET)
				end
			end
		end
	end
end)

return ModWarningScreen
