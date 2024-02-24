local StandAndAttack = Class(BehaviorNode, function(self, inst)
	BehaviorNode._ctor(self, "StandAndAttack")
	self.inst = inst
	self.flipdelay = 0
end)

function StandAndAttack:Visit()
	TheSim:ProfilerPush(self.name)
	local target = self.inst.components.combat:GetTarget()

	if self.status == BNState.READY then
		if target ~= nil then
			self.status = BNState.RUNNING
			self.inst:PushEvent("battlecry", { target = target })
		else
			self.status = BNState.FAILED
		end
	end

	if self.status == BNState.RUNNING then
		if target == nil then
			self.status = BNState.FAILED
		else
			if self.inst.components.combat:HitStunPressureFramesExceeded() then
				self.inst:PushEvent("dohitstunpressureattack", { target = target })
			elseif not self.inst.components.combat:IsInCooldown() then
				self.inst:PushEvent("doattack", { target = target })
			end

			if not self.inst.sg:HasStateTag("busy") then
				if self.inst.sg:HasStateTag("moving") then
					local dir = self.inst:GetAngleTo(target)
					self.inst.components.locomotor:TurnToDirection(dir)
				else
					if self.inst.sg:HasStateTag("idle") then
						self.inst:PushEvent("idlebehavior")
					end
					local dir = self.inst:GetAngleTo(target)
					local flip = DiffAngle(dir, self.inst.Transform:GetFacingRotation()) > 90
					if flip then
						local t = GetTime()
						if t >= self.flipdelay then
							self.flipdelay = t + 1
						else
							dir = nil
						end
					end
					if dir ~= nil then
						if self.inst.components.locomotor ~= nil then
							self.inst.components.locomotor:TurnToDirection(dir)
						end
						--NOTE: don't set rotation without locomotor
					end
					if not self.inst.sg:HasStateTag("busy") then
						self.inst:PushEvent("idlebehavior")
					end
				end
			end

			self:Sleep(self.inst.sg:HasStateTag("moving") and .1 or .25)
		end
	end
	TheSim:ProfilerPop()
end

return StandAndAttack
