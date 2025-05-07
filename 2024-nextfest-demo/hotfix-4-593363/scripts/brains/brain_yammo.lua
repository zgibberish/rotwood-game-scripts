local ChaseAndAttack = require "behaviors.chaseandattack"
local KnockdownRecovery = require "behaviors.knockdownrecovery"
local TargetLastAttacker = require "behaviors.targetlastattacker"
local Wander = require "behaviors.wander"

local BrainYammo = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		KnockdownRecovery(inst),
		TargetLastAttacker(inst),
		ChaseAndAttack(inst),
		Wander(inst),
	}, .1))
end)

return BrainYammo
