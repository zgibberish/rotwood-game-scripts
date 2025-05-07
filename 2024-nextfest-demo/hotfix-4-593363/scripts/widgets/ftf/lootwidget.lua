local Widget = require("widgets/widget")
local Panel = require("widgets/panel")
local Image = require("widgets/image")
local Text = require("widgets/text")

local lume = require("util/lume")
local easing = require("util/easing")

local PADDING = 15
local TEXT_SIZE = 30

local LootWidget =  Class(Widget, function(self, owner, data)
	Widget._ctor(self, "LootWidget")

	self.owner = owner
	self.loot_def = data.item
	self.count = 000 -- gets set later in init with :DeltaCount()

	self.panel = self:AddChild(Panel("images/ui_ftf_dialog/dialog_content_bg.tex"))
		:SetNineSliceCoords(100, 60, 110, 70)
		:SetNineSliceBorderScale(0.5)
		:SetMultColor(HexToRGB(0x221C1ABD))

	self.content_root = self:AddChild(Widget())

	self.item_icon = self.content_root:AddChild(Image(self.loot_def.icon))
	self.text_root = self.content_root:AddChild(Widget())

	self.name_text = self.text_root:AddChild(Text(FONTFACE.DEFAULT, TEXT_SIZE, self.loot_def.pretty.name, UICOLORS[self.loot_def.rarity]))
	self.count_text = self.text_root:AddChild(Text(FONTFACE.DEFAULT, TEXT_SIZE, 000, HexToRGB(0xF9CC6DFF)))
		:LayoutBounds("center", "below", self.name_text)

	local w, h = self.text_root:GetSize()
	self.item_icon:SetSize(h, h)

	self.text_root:LayoutBounds("after", "center", self.item_icon)
		:Offset(5, 0)
	self.panel:SizeToWidgets(PADDING, self.content_root)
	self.content_root:LayoutBounds("center", "center", self.panel)

	self.is_animating = false
	self.done_animate_in = false

	self:DeltaCount(data.count)
end)

function LootWidget:AnimateIn(side, prev_widget, cb)
	-- Animate into position
	if self.is_animating then return end
	self.is_animating = true

	self:Show()
	self:SetMultColorAlpha(0)

	local x,y = self:GetPosition()
	local w,h = self:GetSize()
	local start_pos = x - w

	if side == "right" then
		start_pos = x + w
	end

	local time = 0.1
	self:RunUpdater(
		Updater.Series{
			Updater.Parallel{
				Updater.Ease(function(v) self:SetPosition(v, y) end, start_pos, x, time, easing.outQuad),
				Updater.Ease(function(v) self:SetMultColorAlpha(v) end, 0, 1, time/2, easing.inQuad),
			},
			Updater.Do(function() 
				self.is_animating = false
				self.done_animate_in = true
				if cb then
					cb()
				end
			end),
		}
	)

	return self
end

function LootWidget:DeltaCount(delta)
	self.count = self.count + delta
	self.count_text:SetText(self.count)

	if self.done_animate_in then
		self:DoPulse()
	end
end

function LootWidget:UpdateCount(count)
	self.count_text:SetText(count)

	if self.done_animate_in then
		self:DoPulse()
	end
end

function LootWidget:DoPulse()
	if self.do_pulse then return end
	self.do_pulse = true

	self:RunUpdater(
		Updater.Series{
			Updater.Ease(function(v) self.count_text:SetScale(v, v) end, 1, 1.5, 0.1, easing.inQuint),
			Updater.Ease(function(v) self.count_text:SetScale(v, v) end, 1.5, 1, 0.1, easing.outQuint),
			Updater.Do(function(v) self.do_pulse = false end),
		}
	)
end

return LootWidget
