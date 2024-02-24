local Widget = require "widgets/widget"
local MenuButton = require ("widgets/ftf/menubutton")

local fmodtable = require "defs.sound.fmodtable"

local easing = require"util/easing"

local DiscordCTA = Class(Widget, function(self)
	Widget._ctor(self, "Image")

	self.button = self:AddChild(MenuButton(525, 350))
		:SetName("Discord CTA Button")
		:SetTexture("images/ui_ftf/discord_cta_bg.tex")
		:SetNineSliceCoords(0, 50, 670, 60)
		:SetText(STRINGS.UI.MAINSCREEN.DISCORD_CTA.TITLE, STRINGS.UI.MAINSCREEN.DISCORD_CTA.BODY)
		:SetTextColor(HexToRGB(0xffffffff), HexToRGB(0xffffffff))
		:AddImage("images/ui_ftf_icons/discord.tex", 200, 200)
		:SetOnClick(function() VisitURL("http://discord.gg/klei", false) end)

	self.button.img:LayoutBounds("right", "bottom", self.button.bg)
		:Offset(-40, 20)

	self.button.text_container:LayoutBounds("center", "top", self.button.bg)
		:Offset(0, -30)
		-- :SetControlUpSound(fmodtable.Event.ui_input_up_play)
end)

function DiscordCTA:AnimateIn()
	if self:IsShown() then return end

	self:Show()
	self:SetMultColorAlpha(0)

	local x, y = self:GetPos()

	self:RunUpdater(Updater.Parallel{
		Updater.Ease(function(a) self:SetMultColorAlpha(a) end, 0, 1, 0.25, easing.outQuad),
		Updater.Ease(function(_y) self:SetPos(x, _y) end, y-40, y, 0.75, easing.outElasticUI),
	})
	return self
end

function DiscordCTA:AnimateOut()
	self:Hide()
end

return DiscordCTA
