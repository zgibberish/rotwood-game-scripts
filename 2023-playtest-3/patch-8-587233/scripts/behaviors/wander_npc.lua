local Wander = require "behaviors.wander"

local WanderNpc = Class(Wander, function(self, inst, home, maxdist)
	dbassert(maxdist, "NPCs must have limited wander distance so they don't get somewhere weird.")
	Wander._ctor(self, inst, home, maxdist)
	self.charstoprange = { min = 2.2, max = 3.3 }
end)

function WanderNpc:IsValidWalkDirection(dir)
	local x, z = self.inst.Transform:GetWorldXZ()
	local ents = TheSim:FindEntitiesXZ(x, z, self.charstoprange.max, { "character" }, { "INLIMBO" })
	for i = 1, #ents do
		local v = ents[i]
		if v ~= self.inst then
			--At min range, we must be walking at least 90 degrees to target character
			local k = math.sqrt(self.inst:GetDistanceSqTo(v))
			k = math.max(k - self.charstoprange.min, 0) / (self.charstoprange.max - self.charstoprange.min)
			k = 90 * (1 - k * k)
			if DiffAngle(dir, self.inst:GetAngleTo(v)) < k then
				return false
			end
		end
	end
	return true
end

return WanderNpc
