local StandAndAttack = require "behaviors.standandattack"
local StandStill = require "behaviors.standstill"

local BrainTrap = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		StandAndAttack(inst),
		StandStill(inst),
	}, .5))
end)

return BrainTrap
