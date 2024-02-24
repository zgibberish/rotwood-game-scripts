local CollisionAvoidance = require "behaviors.collisionavoidance"
local DebugDraw = require "util.debugdraw"

-- The key difference of this component and ChaseAndAttack is this component prioritized matching the target's Z position.
local RangeAndAttack = Class(BehaviorNode, function(self, inst, max_z, min_x, max_x)
	BehaviorNode._ctor(self, "RangeAndAttack")
	self.inst = inst
	self.startedchase = false
	self.startchasedelay = 0
	self.flipdelay = 0

	self.max_z = max_z or 1
	self.min_x = min_x or 5
	self.max_x = max_x or 15

	self.target_x = nil
	self.target_z = nil
end)

RangeAndAttack.DebugDraw = false

function RangeAndAttack:SnapRunDirection(dir, snapdir, snaprange)
	if dir ~= snapdir and DiffAngle(dir, snapdir) < snaprange then
		local dir1 = self.inst.Transform:GetRotation()
		if dir1 == snapdir then
			if DiffAngle(dir, self.inst.Transform:GetFacingRotation()) > 90 then
				return snapdir
			end
		elseif (dir1 > snapdir) ~= (dir > snapdir) then
			return snapdir
		end
	end
	return dir
end

function RangeAndAttack:Visit()
	TheSim:ProfilerPush(self.name)
	local target = self.inst.components.combat:GetTarget()

	if self.status == BNState.READY then
		if target ~= nil then
			self.status = BNState.RUNNING
			self.startedchase = false
			self.inst:PushEvent("battlecry", { target = target })
		else
			self.status = BNState.FAILED
		end
	end

	if self.status == BNState.RUNNING then
		if target == nil then
			self.status = BNState.FAILED
		else
			if not CollisionAvoidance.IsDebugEnabled() then
				if self.inst.components.combat:HitStunPressureFramesExceeded() then
					self.inst:PushEvent("dohitstunpressureattack", { target = target })
				elseif not self.inst.components.combat:IsInCooldown() then
					self.inst:PushEvent("doattack", { target = target })
				end
			end

			local t = GetTime()
			if not self.inst.sg:HasStateTag("busy") then
				local x, z = self.inst.Transform:GetWorldXZ()
				local x1, z1 = target.Transform:GetWorldXZ()

				local delta_x = math.abs(x1 - x)
				local delta_z = math.abs(z1 - z)

				local needs_to_reposition = delta_x > self.max_x or delta_x < self.min_x or delta_z > self.max_z
				local should_try_to_align = false
				if needs_to_reposition then
					local find_new_x_target = true

					if self.target_x then
						local delta_target_x = math.abs(x1 - self.target_x)
						find_new_x_target = delta_target_x > self.max_x or delta_target_x < self.min_x
						-- if the distance between your target and x1 is greater than the distance between you and x1
						find_new_x_target = find_new_x_target or (math.abs(self.target_x - x1) > math.abs(x - x1))
					end

					if find_new_x_target then
						local left_x_target = nil
						local right_x_target = nil
						if x < x1 then
							left_x_target = math.ceil(x1 - self.max_x)
							right_x_target = math.floor(x1 - self.min_x)
						else
							left_x_target = math.ceil(x1 + self.min_x)
							right_x_target = math.floor(x1 + self.max_x)
						end
						self.target_x = math.random(left_x_target, right_x_target)
					end

					local find_new_z_target = true
					if self.target_z then
						-- does your current target still work?
						local delta_target_z = math.abs(z1 - self.target_z)
						find_new_z_target = delta_target_z > self.max_z
					end

					if find_new_z_target then
						self.target_z = math.random() < 0.5 and z1 + (self.max_z * math.random()) or z1 - (self.max_z * math.random())
					end
				else
					self.target_x = nil
					self.target_z = nil
				end

				if t >= self.startchasedelay or self.inst.sg:HasStateTag("moving") then
					should_try_to_align = needs_to_reposition and self.target_z ~= nil and self.target_x ~= nil
				end

				if self.target_x and self.target_z and not TheWorld.Map:IsWalkableAtXZ(self.target_x, self.target_z) then
					self.target_x = x1 - (self.target_x - x1)
				end

				if not self.inst.sg:HasStateTag("busy") then
					if should_try_to_align then
						-- you need to be moving towards your target location
						local dir = self.inst:GetAngleToXZ(self.target_x, self.target_z)
						local facingrot = self.inst.Transform:GetFacingRotation()
						local flip = DiffAngle(dir, facingrot) > 90
						if flip and t < self.flipdelay then
							--Prevent flipping back and forth when running directly up/down
							dir = self:SnapRunDirection(dir, -90, 10)
							dir = self:SnapRunDirection(dir, 90, 10)
							flip = DiffAngle(dir, facingrot) > 90
						end
						if flip then
							self.flipdelay = t + 2
						end

						if CollisionAvoidance.Enabled then
							local dt = 0.1
							local speedmultbonus = 0
							self.inst.components.locomotor:AddSpeedMult("collisionavoidance", 0)
							dir, speedmultbonus = CollisionAvoidance.ApplyCollisionAvoidance(self.inst, dir, dt)
							self.inst.components.locomotor:AddSpeedMult("collisionavoidance", speedmultbonus)
						end

						self.inst.components.locomotor:RunInDirection(dir)
						self.startchasedelay = t + 1.5
						self.startedchase = true
					elseif self.inst.sg:HasStateTag("moving") then
						-- you shouldn't try to move, so stop
						self.inst.components.locomotor:Stop()
					else
						-- you shouldn't try to move and you aren't, so look at the target and do idle stuff
						if self.inst.sg:HasStateTag("idle") then
							self.inst:PushEvent("idlebehavior")
						end
						local dir = self.inst:GetAngleToXZ(x1, z1)
						local flip = DiffAngle(dir, self.inst.Transform:GetFacingRotation()) > 90
						if not flip then
							self.inst.components.locomotor:TurnToDirection(dir)
						elseif t >= self.flipdelay then
							self.flipdelay = t + 2
							self.inst.components.locomotor:TurnToDirection(dir)
						end
						if t < self.startchasedelay and not self.inst.sg:HasStateTag("busy") then
							self.inst:PushEvent("idlebehavior")
						end
					end
				end

				if RangeAndAttack.DebugDraw and self.target_x and self.target_z then
					DebugDraw.GroundDiamond(self.target_x, self.target_z, 2, WEBCOLORS.LIME, 0, 0.2)
				end
			elseif self.startedchase and not self.inst.sg:HasStateTag("moving") then
				self.startchasedelay = t + 1
			end

			self:Sleep(self.inst.sg:HasStateTag("moving") and .1 or .25)
		end
	end
	TheSim:ProfilerPop()
end

return RangeAndAttack
