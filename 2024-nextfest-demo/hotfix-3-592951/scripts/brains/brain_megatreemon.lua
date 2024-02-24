local StandAndAttack = require "behaviors.standandattack"
local StandStill = require "behaviors.standstill"

local BrainMegaTreemon = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		StandAndAttack(inst),
		StandStill(inst),
	}, .1))
end)

return BrainMegaTreemon
