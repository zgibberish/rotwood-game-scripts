local Widget = require("widgets/widget")
local Panel = require("widgets/panel")
local Image = require("widgets/image")
local Text = require("widgets/text")

local lume = require("util/lume")
local easing = require("util/easing")

local PADDING = 15
local TEXT_SIZE = 30

local LootWidget =  Class(Widget, function(self, owner, loot, count)
	Widget._ctor(self, "LootWidget")

	-- self:SetAnchors(ANCHOR_RIGHT, ANCHOR_TOP)

	self.owner = owner
	self.loot_def = loot

	-- printf("Loot Widget Created for %s", loot.name)

	self.content_root = self:AddChild(Widget())

	self.panel = self.content_root:AddChild(Panel("images/ui_ftf_dialog/dialog_content_bg.tex"))
		:SetNineSliceCoords(100, 60, 110, 70)
		:SetNineSliceBorderScale(0.5)
		:SetMultColor(HexToRGB(0x221C1AFF))

	self.item_icon = self.content_root:AddChild(Image(loot.icon))

	self.text_root = self.content_root:AddChild(Widget())
		:LayoutBounds("after", "center", self.item_icon)
	self.name_text = self.text_root:AddChild(Text(FONTFACE.DEFAULT, TEXT_SIZE, self.loot_def.pretty.name, UICOLORS[self.loot_def.rarity]))
	self.count_text = self.text_root:AddChild(Text(FONTFACE.DEFAULT, TEXT_SIZE, 0, HexToRGB(0xF9CC6DFF)))
		:LayoutBounds("center", "below", self.name_text)

	local w, h = self.text_root:GetSize()
	self.item_icon:SetSize(h, h)

	self.item_icon:LayoutBounds("left", "center", self.panel)
		:Offset(5, 0)
	self.text_root:LayoutBounds("after", "center", self.item_icon)
		:Offset(5, 0)
	self.panel:SizeToWidgets( PADDING, self.item_icon, self.text_root)
	self.item_icon:LayoutBounds("left", "center", self.panel)
		:Offset(5, 0)
	self.text_root:LayoutBounds("after", "center", self.item_icon)
		:Offset(5, 0)

	self:UpdateCount(count)
end)

function LootWidget:AnimateIn(side)
	-- Animate into position
	if self.do_animate then return end
	self.do_animate = true

	local x,y = self:GetPosition()
	local w,h = self:GetSize()

	if side == "right" then
		self:SetPosition(x + w, y)
	else
		self:SetPosition(x - w, y)
	end

	self:MoveTo(x, y, 0.9, easing.outElastic, function() self.do_animate = false end)
	return self
end

function LootWidget:UpdateCount(count)
	self.count_text:SetText(count)
	self:DoPulse()
end

function LootWidget:DoPulse()
	if self.do_pulse then return end
	self.do_pulse = true
	self.count_text:ScaleTo(1, 1.5, 0.16, easing.inQuint, function()
		self.count_text:ScaleTo(1.5, 1, 0.16, easing.outQuint, function()
			self.do_pulse = false
		end)
	end)
end

return LootWidget
