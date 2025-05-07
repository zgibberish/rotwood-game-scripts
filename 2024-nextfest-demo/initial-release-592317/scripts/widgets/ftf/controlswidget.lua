local HotkeyWidget = require "widgets.hotkeywidget"
local Panel = require "widgets.panel"
local Widget = require("widgets/widget")


-- Show a summary of our control scheme.
local ControlsWidget = Class(Widget, function(self, player)
	Widget._ctor(self, "ControlsWidget")

	self:SetOwningPlayer(player)

	self.frame = self:AddChild(Panel("images/9slice/asymetric.tex"))
		:SetSize(495, 1600)
		:SetNineSliceCoords(150, 150, 160, 160)
		:SetMultColor(UICOLORS.LIGHT_TEXT)

	self.inputs = self:AddChild(Widget("inputs"))
	self.controls = {}

	self:_AddControl(Controls.Digital.ATTACK_LIGHT)
	self:_AddControl(Controls.Digital.ATTACK_HEAVY)
	self:_AddControl(Controls.Digital.DODGE)
	self:_AddControl(Controls.Digital.USE_POTION)
	self:_AddControl(Controls.Digital.SKILL)
	self:_AddControl(Controls.Digital.SHOW_PLAYER_STATUS)

	-- Need initial layout so parent can do immediate layout.
	self:_Layout()
end)

function ControlsWidget:OnAddedToScreen(screen)
	self:RefreshIcons()
end

function ControlsWidget:_Layout()
	self.inputs
		:LayoutChildrenInColumn(60)
		:LayoutBounds("center", "center", self.frame)
end

function ControlsWidget:_AddControl(control)
	local label = TheInput:GetControlPrettyName(control)
	self.controls[control.key] = self.inputs:AddChild(HotkeyWidget(control, label))
		:SetLayout_TextAbove()
		:SetTextMultColor(UICOLORS.LIGHT_TEXT_TITLE)
		:SetIconMultColor(UICOLORS.LIGHT_TEXT)
		:LayoutBounds("center", "below", self)
		:Offset(0, -60)
end

function ControlsWidget:RefreshIcons()
	for _,w in pairs(self.controls) do
		w:RefreshHotkeyIcon()
	end
	self:_Layout()
end

return ControlsWidget
