local Widget = require("widgets/widget")
local NotificationWidget = require "widgets/notificationwidget"

local easing = require "util.easing"

------------------------------------------------------------------------------------
-- Displays notifications to the player above any screen

local SPACING = 20
local ANIMATE_TIME = 0.6

local NotificationsQueueWidget = Class(Widget, function(self, max_notifications)
	Widget._ctor(self, "NotificationsQueueWidget")

    self.max_notif = max_notifications or 4
    self.notification_queue = {}
    self.content = self:AddChild(Widget())
    self.current_notifications = {}

    self.delay_until_next_step = 0

    -- Define the position of the notifications' anchor
    -- Relative to the center of the screen
    self.horizontal_align = "left"
    self.vertical_align = "bottom"
    self.horizontal_offset = -RES_X/2 + 400
    self.vertical_offset = -RES_Y/2 + 500

    self.content:LayoutBounds(self.horizontal_align, self.vertical_align, self.horizontal_offset, self.vertical_offset)

end)

function NotificationsQueueWidget:AddNotification(notification_widget)
	-- Queue up this notification
    table.insert(self.notification_queue, 1, notification_widget)
    notification_widget:Hide()
    return self
end

function NotificationsQueueWidget:RemoveNotification(notification_widget)
	notification_widget:AnimateOut(function()
		table.removearrayvalue(self.current_notifications, notification_widget)
		notification_widget:Remove()
	end)
    return self
end

function NotificationsQueueWidget:OnUpdate( dt )

	if self.delay_until_next_step > 0 then
		self.delay_until_next_step = self.delay_until_next_step - dt
		return
	end

	if #self.notification_queue > 0 then
		-- There are notifications waiting to be shown

		if #self.current_notifications == 0 then -- No notification shown. Show first

			local new_notif = table.remove(self.notification_queue)
            table.insert(self.current_notifications, 1, new_notif)
            self.content:AddChild(new_notif)

            -- Animate new notification
            new_notif:SetPos(30, nil)
            new_notif:MoveTo(0, nil, ANIMATE_TIME, easing.outElasticUI)
				:AnimateIn()
				:RunUpdater(Updater.Series{
					Updater.Wait(new_notif:GetDuration()),
					Updater.Do(function()
						self:RemoveNotification(new_notif)
					end)
				})

			-- Wait until another notification is added
			self.delay_until_next_step = 0.8

		elseif #self.current_notifications < self.max_notif -- Is there room to show them?
		and not self.moved_old_notifications_out then

            -- Animate old notifications out of the way
            for i, widget in ipairs( self.current_notifications ) do
                local pos_y = i * (NotificationWidget.HEIGHT + SPACING)
                widget:MoveTo(nil, pos_y, ANIMATE_TIME, easing.inOutCubic)
            end

            self.moved_old_notifications_out = true

			-- Wait until they moved out of the way
			self.delay_until_next_step = 0.6

		elseif self.moved_old_notifications_out then -- Or finished animating the others

			-- Add another
			local new_notif = table.remove(self.notification_queue)
            table.insert(self.current_notifications, 1, new_notif)
            self.content:AddChild(new_notif)

			-- Animate new notification
            new_notif:SetPos(50, nil)
            new_notif:MoveTo(0, nil, ANIMATE_TIME, easing.outElasticUI)
				:AnimateIn()
				:RunUpdater(Updater.Series{
					Updater.Wait(new_notif:GetDuration()),
					Updater.Do(function()
						self:RemoveNotification(new_notif)
					end)
				})

            self.moved_old_notifications_out = false

			-- Wait until another notification is added
			self.delay_until_next_step = 0.5

		end
    end
end

return NotificationsQueueWidget