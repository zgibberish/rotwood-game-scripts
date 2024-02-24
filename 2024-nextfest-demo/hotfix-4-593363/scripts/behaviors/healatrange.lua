local CollisionAvoidance = require "behaviors.collisionavoidance"
local DebugDraw = require "util.debugdraw"

-- The key difference of this component and ChaseAndAttack is this component prioritized matching the target's Z position.
local HealAtRange = Class(BehaviorNode, function(self, inst, fn, cooldown)
	BehaviorNode._ctor(self, "HealAtRange")
	self.inst = inst
	self.startedchase = false
	self.startchasedelay = 0
	self.flipdelay = 0

	self.heal_target_fn = fn

	self.heal_target = nil

	self.heal_cooldown = cooldown or 15

	self.target_x = nil
	self.target_z = nil
end)

HealAtRange.DebugDraw = false

function HealAtRange:Visit()
	TheSim:ProfilerPush(self.name)
	if not self.heal_target and self.heal_target_fn then
		self.heal_target = self.heal_target_fn(self.inst)
	end

	if self.status == BNState.READY then
		if self.heal_target ~= nil then
			self.status = BNState.RUNNING
		else
			self.status = BNState.FAILED
		end
	end

	if self.status == BNState.RUNNING then
		if self.heal_target == nil then
			self.status = BNState.FAILED
		else
			if not CollisionAvoidance.IsDebugEnabled() and not self.inst.sg:HasStateTag("busy") then
				self.inst:PushEvent("doheal", { target = self.heal_target })
				self.heal_target = nil
			end
			self:Sleep(1)
		end
	end
	TheSim:ProfilerPop()
end

return HealAtRange
