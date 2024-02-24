local HitShudder = Class(function(self, inst)
	self.inst = inst
	self.shudderdirection = false
	self.shuddercounter = 0
	self.shudderamount = 0
	self.timetostop = nil
	self.active = false
	self.scale_amount = 0.01
	self.can_move = true
end)

function HitShudder:DoShudder(shudderamount, animframes)
	if self.active then
		return
	end

	assert(shudderamount ~= nil)

	if self.inst:IsLocal() then
		TheNetEvent:HitShudderStart(self.inst.GUID, shudderamount, animframes)
	else
		self:HandleDoShudder(shudderamount, animframes)
	end
end

function HitShudder:HandleDoShudder(shudderamount, animframes)
	if not self.can_move then
		self.start_pos = { self.inst.Transform:GetWorldXZ() }
	end

	self.shudderamount = shudderamount
	self.shudderdirection = false
	self.shuddercounter = 0
	self.startpos = self.inst:GetPosition()
	self.start_x, self.start_y = self.inst.AnimState:GetScale()

	if animframes then
		self.timetostop = GetTime() + animframes * ANIM_FRAMES * TICKS
	end

	self.active = true
	self.inst:StartUpdatingComponent(self)
end

function HitShudder:OnUpdate(dt)
	self.shudderdirection = not self.shudderdirection
	self.shuddercounter = self.shuddercounter + 1 --unused right now
	if(self.shudderdirection) then
		self.inst.AnimState:SetScale(self.start_x * (1 + self.scale_amount), self.start_y)
		if self.inst.Physics ~= nil then
			self.inst.Physics:MoveRelFacing(self.shudderamount / 150)
		end
	else
		self.inst.AnimState:SetScale(self.start_x * (1 - self.scale_amount), self.start_y)
		if self.inst.Physics ~= nil then
			self.inst.Physics:MoveRelFacing(-self.shudderamount / 150)
		end
	end

	if self.timetostop and GetTime() > self.timetostop then
		self:Stop()
	end
end

function HitShudder:Stop()
	if not self.active then
		TheLog.ch.Combat:printf("Ignoring HitShudder:Stop() on '%s' that doesn't have active shudder.", self.inst)
		return
	end

	if self.inst:IsLocal() then
		TheNetEvent:HitShudderStop(self.inst.GUID)
	else
		-- allow remote entity-triggered shudders to self-stop instead of being silently ignored
		self:HandleStop()
	end
end

function HitShudder:HandleStop()
	if not self.active then
		return
	end

	self.active = false
	self.inst:StopUpdatingComponent(self)

	self.inst.AnimState:SetScale(self.start_x, self.start_y)

	if self.start_pos then
		self.inst.Transform:SetPosition(self.start_pos[1], 0, self.start_pos[2])
	end

	self.timetostop = nil
end

return HitShudder
