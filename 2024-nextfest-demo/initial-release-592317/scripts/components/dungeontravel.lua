local lume = require "util.lume"
require "class"

local DungeonTravel = Class(function(self, inst)
	self.inst = inst
end)

function DungeonTravel:ReadyToTravel(cardinal)
	self.inst:PushEvent("travelpreview_start", cardinal)
end

function DungeonTravel:AbandonTravel()
	-- Once any player is not ready, we must try to stop.
	self.inst:PushEvent("travelpreview_stop")
end

function DungeonTravel:GetDebugString()
--	if next(self.ready_to_travel) then
--		return table.inspect(lume.map(lume.keys(self.ready_to_travel), tostring))
--	end
end


return DungeonTravel
