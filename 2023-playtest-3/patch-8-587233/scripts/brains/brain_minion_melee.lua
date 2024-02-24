local StandAndAttack = require "behaviors.standandattack"

local BrainMinionMelee = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		StandAndAttack(inst),
	}, .1))
end)

return BrainMinionMelee
