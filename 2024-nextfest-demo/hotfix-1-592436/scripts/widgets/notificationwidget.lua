local Widget = require("widgets/widget")
local Clickable = require("widgets/clickable")
local Text = require("widgets/text")
local Panel = require("widgets/panel")
local Image = require("widgets/image")

local easing = require "util.easing"

------------------------------------------------------------------------------------
-- Displays a single notification.
-- Can be a base class for more elaborate notifications

local Notifications = {}

local _NotificationWidget = Class(Clickable, function(self, duration) self:init(duration) end)

Notifications.WIDTH = 700
Notifications.HEIGHT = 200
local PADDING_H = 40
local PADDING_V = 40

function _NotificationWidget:init(duration)
    Clickable._ctor(self, "Notification Widget")

    self.duration = duration or 4

    -- Add contents
    self.bg = self:AddChild(Panel("images/ui_ftf/notification_bg.tex"))
		:SetName("Background")
		:SetNineSliceCoords(15, 10, 497, 40)
		:SetSize(Notifications.WIDTH, Notifications.HEIGHT)

	self.contents = self:AddChild(Widget())
		:SetName("Contents")

	self:SetMultColorAlpha(0)
end

function _NotificationWidget:GetDuration()
	return self.duration
end

function _NotificationWidget:_Layout()

	return self
end

-- This callback will be invoked when the notification widget gets presented to the player
function _NotificationWidget:SetOnShow(fn)
	self.on_show_fn = fn
	return self
end

-- This callback will be invoked when the notification widget is finished and animated out
function _NotificationWidget:SetOnRemoved(fn)
	self.on_removed_fn = fn
	return self
end

function _NotificationWidget:GetOnRemovedFn()
	return self.on_removed_fn
end

function _NotificationWidget:AnimateIn(on_done_fn)
	if self.on_show_fn then self.on_show_fn() end
	self:AlphaTo(1, 0.35, easing.outQuad, on_done_fn)
	return self
end

function _NotificationWidget:AnimateOut(on_done_fn)
	self:AlphaTo(0, 0.2, easing.inQuad, function()
		if self.on_removed_fn then self.on_removed_fn() end
		if on_done_fn then on_done_fn() end
	end)
	return self
end

------------------------------------------------------------------------------------
-- Displays a notification with an icon, title and subtitle

Notifications.TextNotificationWidget = Class(_NotificationWidget, function(self, duration)
	_NotificationWidget._ctor(self, duration)

	self.icon_size = 110
	self.icon_padding = PADDING_H*0.8

	self.icon = self.contents:AddChild(Image("images/global/square.tex"))
		:SetName("Icon")
		:SetSize(self.icon_size, self.icon_size)

    self.text_container = self.contents:AddChild(Widget())
		:SetName("Text container")
	self.title = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.NOTIFICATION_TITLE))
		:SetName("Title")
		:SetGlyphColor(UICOLORS.BLACK)
		:SetHAlign(ANCHOR_LEFT)
		:SetAutoSize(self.text_width)
	self.description = self.text_container:AddChild(Text(FONTFACE.DEFAULT, FONTSIZE.NOTIFICATION_TEXT))
		:SetName("Description")
		:SetGlyphColor(UICOLORS.DARK_TEXT)
		:SetHAlign(ANCHOR_LEFT)
		:SetAutoSize(self.text_width)
end)

function Notifications.TextNotificationWidget:SetData(icon, title, description)

	if icon then
		self.icon:SetTexture(icon)
			:Show()
	else
		self.icon:Hide()
	end

	self.title:SetText(title)
		:SetShown(title)

	self.description:SetText(description)
		:SetShown(description)

	self:_Layout()

	return self
end

function Notifications.TextNotificationWidget:_Layout()
	Notifications.TextNotificationWidget._base._Layout(self)

	-- Adjust text width
	local text_width = Notifications.WIDTH - PADDING_H*2
	if self.icon:IsShown() then
		text_width = text_width - self.icon_size - self.icon_padding
	end
	self.title:SetAutoSize(text_width)
	self.description:SetAutoSize(text_width)

	-- Position text widgets
	self.text_container:LayoutChildrenInColumn(0, "left")
	self.contents:LayoutChildrenInRow(self.icon_padding, "center")
	self.contents:LayoutBounds("left", "center", self.bg)
		:Offset(PADDING_H, 3)

	return self
end

return Notifications