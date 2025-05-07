--local BandicootChaseAndAttack = require("behaviors/bandicoot_chaseandattack")
local ChaseAndAttack = require("behaviors/chaseandattack")
local KnockdownRecovery = require("behaviors/knockdownrecovery")
local TargetLastAttacker = require "behaviors.targetlastattacker"
local Wander = require("behaviors/wander")

local BrainBandicoot = Class(Brain, function(self, inst)
	Brain._ctor(self, inst, PriorityNode({
		KnockdownRecovery(inst),
		TargetLastAttacker(inst),
		--BandicootChaseAndAttack(inst),
		ChaseAndAttack(inst),
		Wander(inst, Vector3(0, 0, 0), 12),
	}, .1))
end)

return BrainBandicoot
