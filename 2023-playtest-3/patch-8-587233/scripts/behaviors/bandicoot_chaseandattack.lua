local BandicootChaseAndAttack = Class(BehaviorNode, function(self, inst)
	BehaviorNode._ctor(self, "BandicootChaseAndAttack")
	self.inst = inst
	self.approachdelay = 0
	self.retreatdelay = 0
end)

local function IsLeftDir(dir)
	return dir < -90 or dir > 90
end

local function IsRightDir(dir)
	return dir > -90 and dir < 90
end

local function IsSameFacing(dir1, dir2)
	return (IsLeftDir(dir1) and IsLeftDir(dir2)) or (IsRightDir(dir1) and IsRightDir(dir2))
end

function BandicootChaseAndAttack:TryRunDirection(dir, candodge)
	if not self.inst.sg:HasStateTag("moving") then
		if candodge then
			local facing = self.inst.Transform:GetFacing()
			if (facing == FACING_LEFT and not IsLeftDir(dir)) or (facing == FACING_RIGHT and not IsRightDir(dir)) then
				self.inst:PushEvent("dodge", dir)
			end
		end
		if not self.inst.sg:HasStateTag("busy") then
			self.inst.components.locomotor:RunInDirection(dir)
		end
	else
		local rot = self.inst.Transform:GetRotation()
		if DiffAngle(dir, rot) > 30 then
			--Stop to change direction
			self.inst.components.locomotor:Stop()
		elseif IsSameFacing(dir, rot) then
			--Minor direction change (don't allow flipping)
			self.inst.components.locomotor:RunInDirection(dir)
		end
	end
end

function BandicootChaseAndAttack:TryWalkDirection(dir)
	if not self.inst.sg:HasStateTag("moving") then
		if not self.inst.sg:HasStateTag("busy") then
			self.inst.components.locomotor:WalkInDirection(dir)
		end
	else
		local rot = self.inst.Transform:GetRotation()
		if DiffAngle(dir, rot) > 30 then
			--Stop to change direction
			self.inst.components.locomotor:Stop()
		elseif IsSameFacing(dir, rot) then
			--Minor direction change (don't allow flipping)
			self.inst.components.locomotor:WalkInDirection(dir)
		end
	end
end

function BandicootChaseAndAttack:GetRunCycleDist()
	return self.inst.components.locomotor:GetRunSpeed() * 22 * TICKS
end

function BandicootChaseAndAttack:GetWalkCycleDist()
	return self.inst.components.locomotor:GetWalkSpeed() * 25 * TICKS
end

function BandicootChaseAndAttack:GetMinRunDist(fromstop)
	local runspeed = self.inst.components.locomotor:GetRunSpeed()
	if fromstop then
		return runspeed * 18 * TICKS
	elseif self.inst.sg:HasStateTag("running") then
		return runspeed * (self.inst.sg.statemem.framestostop + 22) * TICKS
	end
	local walkspeed = self.inst.components.locomotor:GetWalkSpeed()
	return (walkspeed * self.inst.sg.statemem.framestorun + runspeed * 15) * TICKS
end

function BandicootChaseAndAttack:GetMinWalkDist(fromstop)
	local walkspeed = self.inst.components.locomotor:GetWalkSpeed()
	if fromstop then
		return walkspeed * 20 * TICKS
	elseif self.inst.sg:HasStateTag("walking") then
		return walkspeed * (self.inst.sg.statemem.framestostop + 25) * TICKS
	end
	local runspeed = self.inst.components.locomotor:GetRunSpeed()
	return (runspeed * self.inst.sg.statemem.framestowalk + walkspeed * 21) * TICKS
end

function BandicootChaseAndAttack:Visit()
	TheSim:ProfilerPush(self.name)
	local target = self.inst.components.combat:GetTarget()

	if self.status == BNState.READY then
		self.status = target ~= nil and BNState.RUNNING or BNState.FAILED
	end

	if self.status == BNState.RUNNING then
		if target == nil then
			self.status = BNState.FAILED
		else
			local x, z = self.inst.Transform:GetWorldXZ()
			local x1, z1 = target.Transform:GetWorldXZ()
			local dx = x1 - x
			local dz = z1 - z
			local defaultsize = self.inst.sg.mem.idlesize or self.inst.Physics:GetSize()
			local targetsize = target.HitBox:GetSize()

			local forcestop = false
			local canattack = not self.inst.components.combat:IsInCooldown()
			if canattack then
				if self.inst.components.combat:HitStunPressureFramesExceeded() then
					self.inst:PushEvent("dohitstunpressureattack", { target = target })
				elseif not self.inst.sg:HasStateTag("moving") then
					self.inst:PushEvent("doattack", { target = target })
				elseif not self.inst.components.timer:HasTimer("howl_cd") then
					local range = 6 + targetsize
					if dx * dx + dz * dz < range * range then
						forcestop = true
						self.inst.components.locomotor:Stop()
					end
				end
			end

			local ismoving = self.inst.sg:HasStateTag("moving")
			if (ismoving and not forcestop) or not self.inst.sg:HasStateTag("busy") then
				local aligned = math.abs(dz) < self.inst.Physics:GetDepth() + target.HitBox:GetDepth()
				local minspace = targetsize + defaultsize
				if not aligned and math.abs(dx) < minspace then
					--Overlapped, move apart first
					self:TryRunDirection((x > x1 and 0) or (x < x1 and 180) or self.inst.Transform:GetFacingRotation(), true)
				else
					--Destination is spaced apart on x-axis
					x1 = x > x1 and x1 + minspace or x1 - minspace
					dx = x1 - x

					local rot = self.inst.Transform:GetRotation()
					local t = GetTime()
					local chasing = false

					--Too far
					--Try approaching and aligning on x-axis
					if math.abs(dx) > 1 then
						local canstartapproach = t >= self.approachdelay
						local approaching = ismoving and ((x > x1 and IsLeftDir(rot)) or (x < x1 and IsRightDir(rot)))
						if approaching or (canattack and canstartapproach) then
							local stepdist = self:GetMinRunDist(not approaching)
							local dzsq = dz * dz
							local distsq = dx * dx + dzsq
							if distsq > stepdist * stepdist then
								local runcycledist = self:GetRunCycleDist()
								distsq = math.floor((math.sqrt(distsq) - stepdist) / runcycledist) * runcycledist + stepdist
								distsq = distsq * distsq
								if distsq > dzsq then
									dx = math.max(1, math.sqrt(distsq - dzsq))
									if x > x1 then
										dx = -dx
									end
								end
								self:TryRunDirection(math.deg(math.atan(-dz, dx)), false)
								chasing = true
							elseif not canattack or self.inst.components.timer:HasTimer("bite_cd") then
								local stepdist = self:GetMinWalkDist(not approaching)
								if distsq > stepdist * stepdist then
									local walkcycledist = self:GetWalkCycleDist()
									distsq = math.floor((math.sqrt(distsq) - stepdist) / walkcycledist) * walkcycledist + stepdist
									distsq = distsq * distsq
									if distsq > dzsq then
										dx = math.max(1, math.sqrt(distsq - dzsq))
										if x > x1 then
											dx = -dx
										end
									end
									self:TryWalkDirection(math.deg(math.atan(-dz, dx)), false)
									chasing = true
								end
							end
							if not chasing then
								self.approachdelay = t + 2
							end
						end
					end

					--Close but not aligned
					--Try retreating and aligning on x-axis
					if not (chasing or aligned) then
						local canstartretreat = t >= self.retreatdelay
						if canstartretreat then
							local retreating = ismoving and ((x > x1 and IsRightDir(rot)) or (x < x1 and IsLeftDir(rot)))
							local stepdist = self:GetMinRunDist(not retreating)
							if stepdist > math.abs(dz) then
								dx = math.max(math.abs(dz), math.sqrt(stepdist * stepdist - dz * dz))
								if x < x1 or (x == x1 and self.inst.Transform:GetFacing() == FACING_LEFT) then
									dx = -dx
								end
								self:TryRunDirection(math.deg(math.atan(-dz, dx)), true)
							else
								self:TryRunDirection((x > x1 and 0) or (x < x1 and 180) or self.inst.Transform:GetFacingRotation(), true)
							end
							chasing = true
							self.approachdelay = t + 1.5
							self.retreatdelay = t + 1.5
						end
					end

					--Reached destination
					if not chasing then
						if ismoving then
							self.inst.components.locomotor:Stop()
						else
							if self.inst.components.combat:HitStunPressureFramesExceeded() then
								self.inst:PushEvent("dohitstunpressureattack", { target = target })
							elseif canattack then
								self.inst:PushEvent("doattack", { target = target })
							end
							if self.inst.sg:HasStateTag("idle") or t < self.approachdelay or DiffAngle(self.inst.Transform:GetFacingRotation(), self.inst:GetAngleTo(target)) > 90 then
								self.inst:PushEvent("idlebehavior")
							end
						end
					end
				end
			end

			self:Sleep(.25)
		end
	end
	TheSim:ProfilerPop()
end

return BandicootChaseAndAttack
