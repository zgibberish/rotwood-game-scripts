local ChaseAndAttack = require("behaviors/chaseandattack")
local KnockdownRecovery = require("behaviors/knockdownrecovery")
local Wander = require("behaviors/wander")

local BrainBonejaw = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		KnockdownRecovery(inst),
		ChaseAndAttack(inst),
		Wander(inst, Vector3(0, 0, 0), 12),
	}, .1))
end)

return BrainBonejaw
