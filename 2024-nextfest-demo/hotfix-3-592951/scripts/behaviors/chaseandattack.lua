local CollisionAvoidance = require "behaviors.collisionavoidance"
local DebugDraw = require "util.debugdraw"

local ChaseAndAttack = Class(BehaviorNode, function(self, inst)
	BehaviorNode._ctor(self, "ChaseAndAttack")
	self.inst = inst
	self.startedchase = false
	self.startchasedelay = 0
	self.flipdelay = 0

	self.startchasingafterattackdelay = 0.25
end)

ChaseAndAttack.ChaseToTargetAdjacency = true
ChaseAndAttack.DebugDraw = false

function ChaseAndAttack:SnapRunDirection(dir, snapdir, snaprange)
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

function ChaseAndAttack:Visit()
	TheSim:ProfilerPush(self.name)
	local target = self.inst.components.combat:GetTarget()
	if CollisionAvoidance.DebugEntityIsTarget then
		local debugEntity = GetDebugEntity()
		if debugEntity.HitBox and debugEntity.Transform then
			target = GetDebugEntity()
		end
	end

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

				self.inst:PushEvent("specialmovement", target)

				local x, z = self.inst.Transform:GetWorldXZ()
				local x1, z1 = target.Transform:GetWorldXZ()
				local dx = x1 - x
				local dz = z1 - z
				local defaultsize = self.inst.sg.mem.idlesize or self.inst.Physics:GetSize()
				local targetsize = target.HitBox:GetSize()
				local minspace = defaultsize + targetsize
				local overlapped = math.abs(dx) <= minspace
				local shouldchase = false

				local debugColor = WEBCOLORS.LIME
				if t >= self.startchasedelay or self.inst.sg:HasStateTag("moving") then
					if ChaseAndAttack.ChaseToTargetAdjacency then
						-- Try approaching and aligning on x-axis
						-- Always try to move to the left or right of target to minimize
						-- vertical (z-axis) combat
						x1 = x > x1 and x1 + minspace or x1 - minspace
						dx = x1 - x

						local dxmin = (self.inst.Physics:GetDepth() + target.HitBox:GetDepth()) /2
						local dzmin = self.inst.Physics:GetDepth() + target.HitBox:GetDepth()
						local targetXOffset = 0.5
						local targetZOffset = 1

						if math.abs(dx) > dxmin then
							x1 = x > x1 and x1 + targetXOffset or x1 - targetXOffset
							dx = x1 - x
							shouldchase = true
							debugColor = WEBCOLORS.BLUE
						end

						if math.abs(dz) > dzmin then
							z1 = z > z1 and z1 + targetZOffset or z1 - targetZOffset
							dz = z1 - z
							shouldchase = true
							debugColor = debugColor == WEBCOLORS.BLUE and WEBCOLORS.MAGENTA or WEBCOLORS.YELLOW
						end
					else
						-- original algorithm
						if not overlapped then
							--Try approaching and aligning on x-axis
							x1 = x > x1 and x1 + minspace or x1 - minspace
							dx = x1 - x
							if math.abs(dx) > 1 then
								x1 = x > x1 and x1 + .5 or x1 - .5
								dx = x1 - x
								shouldchase = true
							elseif math.abs(dz) > self.inst.Physics:GetDepth() + target.HitBox:GetDepth() then
								shouldchase = true
							end
						elseif math.abs(dz) > self.inst.Physics:GetDepth() + target.HitBox:GetDepth() + .5 then
							--Try moving closer
							shouldchase = true
						end
					end
				end

				if ChaseAndAttack.DebugDraw then
					DebugDraw.GroundDiamond(x1, z1, defaultsize, debugColor, 0, 0.2)
				end

				if overlapped then
					self.inst:PushEvent("dodge")
				end

				if not self.inst.sg:HasStateTag("busy") then
					if shouldchase then
						local dir = math.deg(math.atan(-dz, dx))
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

						if self.inst.components.steeringlimit then
							self.inst.components.steeringlimit:RequestLocomote(dir, "run")
						else
							self.inst.components.locomotor:RunInDirection(dir)
						end
						self.startchasedelay = t + 1.5
						self.startedchase = true
					elseif self.inst.sg:HasStateTag("moving") then
						self.inst.components.locomotor:Stop()
					else
						if self.inst.sg:HasStateTag("idle") then
							self.inst:PushEvent("idlebehavior")
						end
						local dir = math.deg(math.atan(-dz, dx))
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
			elseif self.startedchase and not self.inst.sg:HasStateTag("moving") then
				self.startchasedelay = t + self.startchasingafterattackdelay
			end

			self:Sleep(self.inst.sg:HasStateTag("moving") and .1 or .1)
		end
	end
	TheSim:ProfilerPop()
end

return ChaseAndAttack
