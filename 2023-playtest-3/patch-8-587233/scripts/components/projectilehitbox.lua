local ProjectileHitbox = Class(function(self, inst)
	self.inst = inst
	self.inst:StartUpdatingComponent(self)

    self._onhitboxtriggeredfn = function(inst, data) self:OnHitBoxTriggered(data) end
	self.inst:ListenForEvent("hitboxtriggered", self._onhitboxtriggeredfn)

	self.enabled = true
	self.initial_hitboxes = {}
	self.hitboxes = {}
	self.delay_ticks = nil
end)

function ProjectileHitbox:OnNetSerialize()
	local e = self.inst.entity

	e:SerializeBoolean(self.enabled)
end

function ProjectileHitbox:OnNetDeserialize()
	local e = self.inst.entity

	local enabled = e:DeserializeBoolean()
	if self.enabled ~= enabled then
		self.enabled = enabled
		TheLog.ch.ProjectileHitbox:printf("%s EntityID %d hitboxes enabled: %s",
			self.inst, self.inst.Network:GetEntityID(), enabled)
	end
end

ProjectileHitbox.Types = MakeEnum{ "BEAM", "CIRCLE" }

-- Hitbox that gets spawned on the first frame only
function ProjectileHitbox:PushBeam(startdist, enddist, thickness, priority, on_first_frame_only)
	-- Store this hitbox information
	if on_first_frame_only then
		table.insert(self.initial_hitboxes, { type=ProjectileHitbox.Types.BEAM, startdist = startdist, enddist = enddist, thickness = thickness, priority = priority } )
	else
		table.insert(self.hitboxes, { type=ProjectileHitbox.Types.BEAM, startdist = startdist, enddist = enddist, thickness = thickness, priority = priority } )
	end
	return self
end

-- Hitbox that gets spawned every frame while the projectile is alive
function ProjectileHitbox:PushCircle(distance, rotation, radius, priority, on_first_frame_only)
	if on_first_frame_only then
		table.insert(self.initial_hitboxes, { type=ProjectileHitbox.Types.CIRCLE, distance = distance, rotation = rotation, radius = radius, priority = priority } )
	else
		table.insert(self.hitboxes, { type=ProjectileHitbox.Types.CIRCLE, distance = distance, rotation = rotation, radius = radius, priority = priority } )
	end
	return self
end

function ProjectileHitbox:SetTriggerFunction(func)
	self._hitboxFunc = func
	return self
end

function ProjectileHitbox:_ApplyHitboxes( hitboxes )
	if not self.enabled then
		return
	end

	for k, v in ipairs(hitboxes) do
		if v.type == ProjectileHitbox.Types.BEAM then
			self.inst.components.hitbox:PushBeam(v.startdist, v.enddist, v.thickness, v.priority)
		elseif v.type == ProjectileHitbox.Types.CIRCLE then
			self.inst.components.hitbox:PushCircle(v.distance, v.rotation, v.radius, v.priority)
		end
	end
end

function ProjectileHitbox:SetEnabled(is_enabled)
	self.enabled = is_enabled
end

function ProjectileHitbox:ClearHitBoxes()
	self.initial_hitboxes = {}
	self.hitboxes = {}
end

function ProjectileHitbox:PermanentlyDisableTrigger()
	self:ClearHitBoxes()
	self.inst:RemoveEventCallback("onhitboxtriggered", self._onhitboxtriggeredfn)
	self.inst:StopUpdatingComponent(self)
end

function ProjectileHitbox:SetRepeatTargetDelayTicks(ticks)
	self.delay_ticks = ticks
end

function ProjectileHitbox:OnUpdate()
	if not self.initial_done then
		self.initial_done = true
		if (#self.hitboxes > 0) then
			if self.delay_ticks then
				self.inst.components.hitbox:StartRepeatTargetDelayTicks(self.delay_ticks)
			else
				self.inst.components.hitbox:StartRepeatTargetDelay()
			end
			self:_ApplyHitboxes(self.initial_hitboxes) -- Spawn an attack area in front of the projectile on spawn
		end
	end

	-- Apply the every-frame hitboxes:
	self:_ApplyHitboxes(self.hitboxes)
end

function ProjectileHitbox:OnHitBoxTriggered(data)
--	print("ProjectileHitbox:OnHitBoxTriggered")

	if not self._hitboxFunc then
		return
	end

	-- If this projectile is local --> only hit local objects. Pass through remote objects
	-- If this projectile is remote --> only hit local objects. Take control when they hit.
	-- If this projectile is created by a local player. Detect remote and local entities since we want the projectile to be as responsive as possible

	local owner_is_local_and_player = self.inst.owner and self.inst.owner:IsLocal() and self.inst.owner:HasTag("player")

	-- First see if this projectile is hitting anything local:
	for i = 1, #data.targets do
		local v = data.targets[i]

		-- Only hit local objects:
		if v:IsValid() and (v:IsLocal() or owner_is_local_and_player) then
			local hitting_self = (v.owner or v) == self.inst.owner
			if not hitting_self or data.can_hit_self then
--				print("Projectile hitting")
				-- Try taking control
				if not self.inst:IsLocal() then	-- It this projectile is NOT local, make it local
--					print("Trying to take control of Projectile")
					self.inst:TakeControl()
				end

				-- If this projectile is now local, call the hit function
				if self.inst:IsLocal() then
--					print("Projectile is local, calling hit callback")
					self._hitboxFunc(self.inst, data)
				end
			end
		end
	end

	-- Did the projectile get removed?
	if not self.inst:IsVisible() then
		self.inst:StopUpdatingComponent(self)
		return
	end
end

return ProjectileHitbox
