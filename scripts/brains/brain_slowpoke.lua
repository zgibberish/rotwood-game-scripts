local StandAndAttack = require "behaviors.standandattack"
local ChaseAndAttack = require "behaviors.chaseandattack"
local KnockdownRecovery = require "behaviors.knockdownrecovery"
local TargetLastAttacker = require "behaviors.targetlastattacker"
local Wander = require "behaviors.wander"

-- if you're sitting, stay sitting & attacking until you're forced to exit the state.
local BrainSlowpoke = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		KnockdownRecovery(inst),
		TargetLastAttacker(inst),
		WhileNode(inst, inst.IsSitting, "IsSitting",
			StandAndAttack(inst)
		),
		ChaseAndAttack(inst),
		Wander(inst),
	}, .1))
end)

return BrainSlowpoke