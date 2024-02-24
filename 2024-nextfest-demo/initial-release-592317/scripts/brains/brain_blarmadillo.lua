local KnockdownRecovery = require "behaviors.knockdownrecovery"
local RangeAndAttack = require "behaviors.rangeandattack"
local TargetLastAttacker = require "behaviors.targetlastattacker"
local Wander = require "behaviors.wander"

local BrainBlarmadillo = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		KnockdownRecovery(inst),
		TargetLastAttacker(inst),
		RangeAndAttack(inst, 1, 7, 17),
		Wander(inst),
	}, .1))
end)

return BrainBlarmadillo
