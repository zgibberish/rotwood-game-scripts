require "class"


-- Send events to the inst during peace times. Simplifies stategraph setup for
-- dormant state: just add some EventHandlers to go to a dormant state.
local DormantDuringPeace = Class(function(self, inst)
	self.inst = inst

	inst:ListenForEvent("room_locked", function()
		inst.sg.mem.dormant = false
		inst:PushEvent("dormant_stop")
	end, TheWorld)

	inst:ListenForEvent("room_complete", function()
		inst.sg.mem.dormant = true
		inst:PushEvent("dormant_start")
	end, TheWorld)
end)


return DormantDuringPeace
