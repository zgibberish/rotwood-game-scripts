local ChaseAndAttack = require "behaviors.chaseandattack"
local KnockdownRecovery = require "behaviors.knockdownrecovery"
local Wander = require "behaviors.wander"

local BrainWarmy = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		KnockdownRecovery(inst),
		ChaseAndAttack(inst),
		Wander(inst),
	}, .5))
end)

return BrainWarmy
