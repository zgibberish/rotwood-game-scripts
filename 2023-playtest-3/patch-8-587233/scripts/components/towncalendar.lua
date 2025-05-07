local TownCalendar = Class(function(self, inst)
	self.inst = inst
	self.current_day = 1

	inst:ListenForEvent("end_current_run", function()
		self:NextDay()
	end, TheDungeon)
end)

function TownCalendar:NextDay()
	local previous_day = self.current_day
	self.current_day = (self.current_day + 1)
	self.current_day = self.current_day <= 7 and self.current_day or 1

	TheWorld:PushEvent("day_passed", {previous_day = previous_day, current_day = self.current_day})
end

function TownCalendar:GetDay()
	return self.current_day
end

function TownCalendar:OnSave()
	return { current_day = self.current_day }
end

function TownCalendar:OnLoad(data)
	if data ~= nil then
		self.current_day = data.current_day
	end
end

return TownCalendar
