local ChaseAndAttack = require("behaviors/chaseandattack")
local KnockdownRecovery = require("behaviors/knockdownrecovery")
local StandStill = require "behaviors.standstill"
local Wander = require("behaviors/wander")

local function IsDormant(inst)
	return inst.sg:HasStateTag("dormant")
end

local BrainThatcher = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		KnockdownRecovery(inst),
		ChaseAndAttack(inst),
		IfNode(inst, IsDormant, "IsDormant",
			StandStill(inst)),
		Wander(inst, Vector3(0, 0, 0), 12),
	}, .1))
end)

return BrainThatcher
