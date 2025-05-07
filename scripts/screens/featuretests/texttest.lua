local ActionButton = require "widgets.actionbutton"
local Screen = require("widgets/screen")
local Text = require("widgets/text")
local templates = require("widgets/ftf/templates")
require "screens/featuretests/fallback"



local TextTest = Class(Screen, function(self, profile)
	Screen._ctor(self, "WidgetTest")
	self.profile = profile
	self:DoInit()
end)

TextTest.CONTROL_MAP =
{
	{
		control = Controls.Digital.CANCEL,
		fn = function(self)
			self.close_button:Click()
			return true
		end,
	},
}

function TextTest:DoInit()
	self:AddChild(templates.SolidBackground(0x444444ff))

	self.close_button = self:AddChild(ActionButton())
		:SetText("Back")
		:LayoutBounds("left","bottom",self)
		:SetOnClick(function()
			TheFrontEnd:PopScreen()
		end)
	self.default_focus = self.close_button

	self:AddChild(Text(FONTFACE.DEFAULT,20))
		:SetText("This is a 20 pt text")
		:SetPosition(0,500)
	self:AddChild(Text(FONTFACE.DEFAULT,40))
		:SetText("This is a 40 pt text")
		:SetPosition(0,460)
	self:AddChild(Text(FONTFACE.DEFAULT,80))
		:SetText("This is a 80 pt text")
		:SetPosition(0,400)
	self:AddChild(Text(FONTFACE.DEFAULT,120))
		:SetText("This is a 120 pt text")
		:SetPosition(0,300)

	self:AddChild(Text(FONTFACE.DEFAULT,50))
		:SetRegionSize(500,500)
		:SetText("This is a\ntext that is\nleft aligned")
		:SetHAlign(ANCHOR_LEFT)
		:SetPosition(-200,140)
	self:AddChild(Text(FONTFACE.DEFAULT,50))
		:SetRegionSize(500,500)
		:SetText("This is a\ntext that is\ncentered")
		:SetHAlign(ANCHOR_MIDDLE)
		:SetPosition(0,140)
	self:AddChild(Text(FONTFACE.DEFAULT,50))
		:SetRegionSize(500,500)
		:SetText("This is a\ntext that is\nright aligned")
		:SetHAlign(ANCHOR_RIGHT)
		:SetPosition(200,140)

	self:AddChild(Text(FONTFACE.DEFAULT,50))
		:SetText("This is some <#RED>red</> and <#0000ff>blue</> text")
		:SetHAlign(ANCHOR_RIGHT)
		:SetPosition(0,0)
	self:AddChild(Text(FONTFACE.DEFAULT,30))
		:SetTextRaw("This is some <#RED>red</> and <#0000ff>blue</> text")
		:SetHAlign(ANCHOR_RIGHT)
		:SetPosition(0,-35)
		:SetGlyphColor(UICOLORS.GOLD)

	self:AddChild(Text(FONTFACE.DEFAULT,50))
		:SetText("This is some <s>text with a dropshadow</>")
		:SetHAlign(ANCHOR_RIGHT)
		:SetPosition(0,-80)
		:SetShadowColor(UICOLORS.RED)
	self:AddChild(Text(FONTFACE.DEFAULT,30))
		:SetTextRaw("This is some <s>text with a dropshadow</>")
		:SetHAlign(ANCHOR_RIGHT)
		:SetPosition(0,-115)
		:SetGlyphColor(UICOLORS.GOLD)


	self:AddChild(Text(FONTFACE.DEFAULT,50))
		:SetText("This is <u>some</> <u#RED>underlined</u> <u#00ff00>text</>")
		:SetHAlign(ANCHOR_RIGHT)
		:SetPosition(0,-160)
		:SetShadowColor(UICOLORS.RED)
	self:AddChild(Text(FONTFACE.DEFAULT,30))
		:SetTextRaw("This is <u>some</> <u#RED>underlined</u> <u#00ff00>text</>")
		:SetHAlign(ANCHOR_RIGHT)
		:SetPosition(0,-195)
		:SetGlyphColor(UICOLORS.GOLD)

	self:AddChild(Text(FONTFACE.DEFAULT,50))
		:SetText("This is <b>bold</> and <i>italic</> text")
		:SetHAlign(ANCHOR_RIGHT)
		:SetPosition(0,-240)
		:SetShadowColor(UICOLORS.RED)
	self:AddChild(Text(FONTFACE.DEFAULT,30))
		:SetTextRaw("This is <b>bold</> and <i>italic</> text")
		:SetHAlign(ANCHOR_RIGHT)
		:SetPosition(0,-275)
		:SetGlyphColor(UICOLORS.GOLD)

	self:AddChild(Text(FONTFACE.DEFAULT,50))
		:SetText("Embedded <p img='images/bg_title/title.tex' color=00ff0080> images and <p bind='Controls.Digital.MENU_ACCEPT' color=RED> controller <p bind='Controls.Digital.MENU_TAB_NEXT'> icons <p bind='Controls.Digital.PAUSE'>")
		:SetHAlign(ANCHOR_RIGHT)
		:SetPosition(0,-320)
		:SetShadowColor(UICOLORS.RED)
	self:AddChild(Text(FONTFACE.DEFAULT,30))
		:SetTextRaw("Embedded <p img='images/bg_title/title.tex' color=00ff0080> images and <p bind='Controls.Digital.MENU_ACCEPT' color=RED> controller <p bind='Controls.Digital.MENU_TAB_NEXT'> icons <p bind='Controls.Digital.PAUSE'>")
		:SetHAlign(ANCHOR_RIGHT)
		:SetPosition(0,-355)
		:SetGlyphColor(UICOLORS.GOLD)

	self:AddChild(Text(FONTFACE.DEFAULT,50))
		:SetText(FALLBACK_STRING)
		:SetPosition(0,-500)

	self:AddChild(Text(FONTFACE.DEFAULT,48 * 0.7))
		:SetGlyphColor(UICOLORS.LIGHT_TEXT_DARK)
		:SetAutoSize(363)
		:SetText("Every <#RED>10 Hit Streak</>, launch a <#RED>Bomb</> in a random direction.")
		:SetPosition(0,-650)

	self:AddChild(Text(FONTFACE.DEFAULT,100))
		:SetText("Outlined text")
		:SetPosition(-300,-430)
		:EnableOutline()
		:SetOutlineColor(UICOLORS.RED)
	self:AddChild(Text(FONTFACE.DEFAULT,100))
		:SetText("Outlined text")
		:SetPosition(300,-430)
		:EnableOutline()
		:SetOutlineColor(UICOLORS.BLUE)

	self:AddChild(Text(FONTFACE.DEFAULT,30))
		:SetText("This is a text that is way too long to fit in one line, it has wordwrap enabled so it should wrap. It has left alignment")
		:SetPosition(-800,0)
		:SetRegionSize(250,300)
		:SetDebugRender(true)
		:EnableWordWrap(true)
		:SetHAlign(ANCHOR_LEFT)
	self:AddChild(Text(FONTFACE.DEFAULT,30))
		:SetText("This is a text that is way too long to fit in one line, it has wordwrap enabled so it should wrap. It has right alignment")
		:SetPosition(800,0)
		:SetRegionSize(250,300)
		:SetDebugRender(true)
		:EnableWordWrap(true)
		:SetHAlign(ANCHOR_RIGHT)
	self:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.ROOMBONUS_TEXT * 0.9))
		:SetText("This is a text that is way too long to fit in one line, it has SetAutoSize(500) so it should wrap. It has left alignment and is on the left of the screen.")
		:SetPosition(-1400,0)
		:SetGlyphColor(UICOLORS.LIGHT_TEXT)
		:SetAutoSize(500)
		:SetHAlign(ANCHOR_LEFT)

	self:AddChild(Text(FONTFACE.DEFAULT,60))
		:SetText("String <z 0.9>with </z><z 0.8>smaller </z><z 0.7>and </z><z 0.6>smaller </z><z 0.5>and </z><z 0.4>smaller </z><z 0.3>and </z><z 0.2>smaller </z><z 0.1>text</z>")
		:SetPosition(550, 500)
		:SetShadowColor(UICOLORS.RED)

	self.textsizetest = self:AddChild(Text(FONTFACE.DEFAULT,120))
		:SetPosition(-600, 500)
		:SetShadowColor(UICOLORS.RED)

	self.control_display = self:AddChild(Text(FONTFACE.DEFAULT,40))
		:SetPosition(-600, 800)
		:SetHAlign(ANCHOR_RIGHT)
		:LayoutBounds("right", "top", self)
		:Offset(-125, 0)
end

function TextTest:_DisplayNextControl()
	local fmt = "%s icon: <p bind='Controls.Digital.%s'>\n"
	local text = "Controls.Digital:\n\n"

	for i=1,50 do
		self.ctrl_index = (self.ctrl_index or 0) + 1

		local keys = table.getkeys(Controls.Digital)
		table.sort(keys)
		local c = circular_index(keys, self.ctrl_index)

		text = text .. fmt:format(c, c)
	end
	self.control_display:SetText(text)
		:LayoutBounds("right", "top", self)
		:Offset(-125, 0)
end

function TextTest:OnUpdate(dt)
	local work = "Just because we can?"
	self.time = self.time or 0
	self.time = self.time + dt
	local text = "<s>"
	for i=1,#work do
		local v = (math.sin(self.time + i * 0.1)/4 + 0.5)
		local c = string.format("%02x",math.floor((v + 0.2) * 255))
		text = text.."<#"..c..c..c..">"
		text = text.."<z "..v..">"
		local char = work:sub(i,i)
		text = text..char
		text = text.."</c>"
		text = text.."</z>"
	end
	text = text.."</s>"
	self.textsizetest:SetText(text)

	self.seconds_remaining = (self.seconds_remaining or 0) - dt
	if self.seconds_remaining < 0 then
		self.seconds_remaining = 5
		self:_DisplayNextControl()
	end
end

return TextTest
