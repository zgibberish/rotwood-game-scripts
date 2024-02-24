require "class"

local DailyMenu = Class(function(self, inst)
	self.inst = inst
end)

function DailyMenu:GetDay()
	return self.day
end

function DailyMenu:GetMenuItems()
	return self.items
end

function DailyMenu:SetMenu(items, day)
	self.items = items
	self.day = day
end

return DailyMenu