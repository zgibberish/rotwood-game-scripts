local StandAndAttack = require "behaviors.standandattack"

local BrainBasicStationary = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		StandAndAttack(inst),
	}, .1))
end)

return BrainBasicStationary