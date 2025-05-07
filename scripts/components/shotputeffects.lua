local LANDINGMARKER_RING_DEFAULT_SCALE = 1

local LAST_ATTACK_SEQNR_BITS <const> = 4
local LAST_ATTACK_SEQNR_MAX_VALUE <const> = (1 << LAST_ATTACK_SEQNR_BITS) - 1
local LAST_ATTACK_MAX_TARGET_COUNT_BITS <const> = 5
local LAST_ATTACK_MAX_TARGET_COUNT_VALUE <const> = (1 << LAST_ATTACK_MAX_TARGET_COUNT_BITS) - 1

local ShotputEffects = Class(function(self, inst)
	self.inst = inst
	self.inst:StartUpdatingComponent(self)

	self.last_attack_seqnr = 0
	self.last_attack_type = "" -- attack type -- i.e. heavy_attack, light_attack, etc.
	self.last_attack_data = { targets_hit = {}, attack_id = "" } -- shotput doesn't care about the data, but powers do, especially #targets_hit

	self:SetupFocusParticles()
end)

function ShotputEffects:_HandleAttackTypeEvent(attack_type, data)
	-- TheLog.ch.Shotput:printf("HandleAttackTypeEvent %s num targets = %d", attack_type, #data.targets_hit)
	self.last_attack_type = attack_type
	-- not sure if it's safe to ignore whiffs for remote (i.e. when the ball is grounded)
	if #data.targets_hit > 0 then
		self.last_attack_seqnr = (self.last_attack_seqnr + 1) % (LAST_ATTACK_SEQNR_MAX_VALUE + 1)
		self.last_attack_type = attack_type
		self.last_attack_data = data
		-- TheLog.ch.Shotput:printf("ShotputEffects attack: seqnr=%d last_attack_type=%s", self.last_attack_seqnr, self.last_attack_type)
	end
	if self.inst.owner:IsLocal() then
		self.inst.owner:PushEvent(self.last_attack_type, data)
	end
end

function ShotputEffects:SetupOwnerCallbacks()
	if self.inst.owner then
		if not self._on_remove_owner then
			-- one check to remove the ball if the owner is removed from the simulation
			-- another is when the entity becomes local (usually for the host)
			self._on_remove_owner = function()
				if self.inst:IsLocal() then
					self:OnRemoveFromEntity()
					self.inst:Remove()
				end
			end

			self.inst:ListenForEvent("onremove", self._on_remove_owner, self.inst.owner)
		end

		if not self._on_heavy_attack then
			self._on_heavy_attack = function(_projectile, data)
				self:_HandleAttackTypeEvent("heavy_attack", data)
			end
			self.inst:ListenForEvent("heavy_attack", self._on_heavy_attack)
		end

		if not self._on_light_attack then
			self._on_light_attack = function(_projectile, data)
				self:_HandleAttackTypeEvent("light_attack", data)
			end

			self.inst:ListenForEvent("light_attack", self._on_light_attack)
		end
	end
end


-------------------------------------------------
-- LANDING MARKERS
-- Indicator that shows where a ball is going to land
function ShotputEffects:CreateLandingMarker(targetpos)
	if self.landingmarker == nil then
		self.landingmarker = SpawnPrefab("fx_ground_target_jamball", self.inst)
	else
		self.landingmarker:ReturnToScene()
	end

	self.landingmarker.AnimState:SetScale(LANDINGMARKER_RING_DEFAULT_SCALE, LANDINGMARKER_RING_DEFAULT_SCALE)
	self.landingmarker.Transform:SetPosition(targetpos.x, targetpos.y, targetpos.z)
end

function ShotputEffects:RemoveLandingMarker()
	if self.landingmarker ~= nil then
		self.landingmarker:RemoveFromScene()
	end
end


local ticksinstate_to_landingmarkerscale =
{
	-- Only updates on even numbers
	{ 0, LANDINGMARKER_RING_DEFAULT_SCALE },
	{ 20, LANDINGMARKER_RING_DEFAULT_SCALE },
	{ 30, LANDINGMARKER_RING_DEFAULT_SCALE * .95},
	{ 40, LANDINGMARKER_RING_DEFAULT_SCALE * .9 },
	{ 50, LANDINGMARKER_RING_DEFAULT_SCALE * .85},
	{ 60, LANDINGMARKER_RING_DEFAULT_SCALE * .8 },
	{ 70, LANDINGMARKER_RING_DEFAULT_SCALE * .75 },
}

function ShotputEffects:UpdateLandingMarkerRingSize()
	local ticks = self.inst.sg:GetTicksInState()
	-- Only update every 2 ticks, every 1 anim frame
	if ticks % 2 == 0 and self.landingmarker ~= nil then
		local scale = PiecewiseFn(ticks, ticksinstate_to_landingmarkerscale)
		self.landingmarker.AnimState:SetScale(scale, scale)
	end
end

---------------------------------------
-- FOCUS PARTICLES
-- Particles that follow a ball when it is a Focus Ball -- distinct from ghost images, which match the buildswap of the actual ball itself

function ShotputEffects:HideFocusParticles()
	if self.focustrail ~= nil then
		self.focustrail:RemoveFromScene()
	end
end

function ShotputEffects:StartFocusParticles()
	if not self.focustrailactive then
		self.focustrailactive = true;

		if self.focustrail ~= nil then
			self.focustrail:ReturnToScene()
			self.focustrail.components.particlesystem:Restart()
		end

		self.inst.AnimState:SetSymbolBloom("spikes", 0/255, 255/255, 255/255, 255/255)
	end
end

function ShotputEffects:StopFocusParticles()
	if self.focustrailactive then
		self.focustrailactive = false;

		if self.focustrail ~= nil then
			self.focustrail.components.particlesystem:StopAndNotify()
		end

		self.inst.AnimState:SetSymbolBloom("spikes", 0/255, 0/255, 0/255, 0/255)
	end
end

function ShotputEffects:SetupFocusParticles()
	local pfx = SpawnPrefab("shotput_focus_trail", self.inst)
	pfx.entity:AddFollower()
	pfx.entity:SetParent(self.inst.entity)
	pfx:RemoveFromScene()
	self.focustrail = pfx
	self.focustrail:ListenForEvent("particles_stopcomplete", function() self:HideFocusParticles() end)
	self.focustrailactive = false;
end

-------------------------------------------------
-- SPIKE DUST
-- Dust along the ground underneath a spiked ball

function ShotputEffects:CreateSpikeDust()
	assert(self.spikedust == nil, "Trying to create new spikedust when one already exists")
	local pos = self.inst:GetPosition()
	self.spikedust = SpawnPrefab("dust_jamball_spiked", self.inst)
	self.spikedust.Transform:SetPosition(pos.x, 0, pos.z)
	self.particleemitrate = 0
	self.spikedust.components.particlesystem:SetAllEmitRateMult(self.particleemitrate)
end

function ShotputEffects:UpdateSpikeDust()
	if self.spikedust ~= nil then
		local pos = self.inst:GetPosition()
		self.spikedust.Transform:SetPosition(pos.x, 0, pos.z)
		if pos.y <= 3 and self.particleemitrate == 0 then
			self.particleemitrate = 2
			self.spikedust.components.particlesystem:SetAllEmitRateMult(self.particleemitrate)
		end
	end
end

function ShotputEffects:StopSpikeDust()
	if self.spikedust ~= nil then
		self.spikedust.components.particlesystem:StopThenRemoveEntity()
		self.spikedust = nil
	end
end




function ShotputEffects:UpdateCatching()
	if	self.inst.owner and 
		self.inst.owner:IsValid() and 
		self.inst.owner:IsLocal() and
		not self.inst.owner.sg:HasStateTag("shotput_catch_forbidden") and
		not self.inst:IsInLimbo() and
		self.inst:IsNear(self.inst.owner, 2.0) then

		if self.inst.sg:HasStateTag("catchable") and 
			not self.inst.sg:HasStateTag("tackled") then

			-- Our owner is local, so check if the ball can be picked up. If it can, take control on this machine, and do the catching logic:
			local bally = self.inst:GetPosition().y
			local v_minx, v_miny, v_minz, v_maxx, v_maxy, v_maxz = self.inst.owner.entity:GetWorldAABB()

			-- Only accept a collision if the ball has actually reached the entity's height
			if bally <= math.max(0.5, v_maxy - 1) then -- NOTE: v_maxy - x => change 'x' to adjust how much below their boundingbox height the ball must go to register a hit.
														 -- The lower this is, the longer it takes to register a hit and also makes player hitting the ball out of the air easier. Slows pace of weapon down a bit.
														 -- Use a minimum of 0.5 because some creatures are very small, and in some animations their bounding boxes may shrink smaller than the normal threshold can hit

				self.inst:TakeControl()
				if self.inst:IsLocal() then
					self.inst.Physics:Stop()
					self.inst.components.shotputeffects:StopFocusParticles()
					self.inst.components.shotputeffects:RemoveLandingMarker()
					self.inst.owner:PushEvent("shotput_caught", self.inst) -- to be object-pooled
				end
			end
		else 
			local bally = self.inst:GetPosition().y

			-- Only accept a collision if the ball has actually reached the entity's height
			if bally <= 0.1 then 
				-- Pick up:
				self.inst:TakeControl()
				if self.inst:IsLocal() then
					self.inst.owner:PushEvent("shotput_pickuped", self.inst) -- to be object-pooled
				end
			end
		end
	end
end

function ShotputEffects:OnUpdate()
	self:SetupOwnerCallbacks()
	self:UpdateSpikeDust()
	self:UpdateLandingMarkerRingSize()
	self:UpdateCatching()
end

function ShotputEffects:OnNetSerialize()
	local e = self.inst.entity

	e:SerializeBoolean(self.focustrailactive)
	e:SerializeBoolean(self.spikedust ~= nil)
	if (self.landingmarker ~= nil) and not self.landingmarker:IsInLimbo() then
		e:SerializeBoolean(true)

		local targetpos = self.landingmarker:GetPosition()
		e:SerializePosition(targetpos)
	else
		e:SerializeBoolean(false)
	end

	e:SerializeUInt(self.last_attack_seqnr, LAST_ATTACK_SEQNR_BITS)
	e:SerializeString(self.last_attack_type)
	local target_count = 0
	for i,target in ipairs(self.last_attack_data.targets_hit) do
		if target:IsValid() and target:IsNetworked() then
			target_count = target_count + 1
			if target_count >= LAST_ATTACK_MAX_TARGET_COUNT_VALUE then
				TheLog.ch.Shotput:printf("Warning: Too many targets to serialize")
				break
			end
		end
	end

	e:SerializeUInt(target_count, LAST_ATTACK_MAX_TARGET_COUNT_BITS)
	for i=1,target_count do
		local target = self.last_attack_data.targets_hit[i]
		if target:IsValid() and target:IsNetworked() then
			e:SerializeEntityID(target.Network:GetEntityID())
		end
	end

	e:SerializeString(self.last_attack_data.attack_id or "")
end

function ShotputEffects:OnNetDeserialize()
	local e = self.inst.entity

	if e:DeserializeBoolean() then
		-- Should have Focus trail
		self:StartFocusParticles()
	else
		-- Should not have Focus trail
		self:StopFocusParticles()
	end

	if e:DeserializeBoolean() then
		-- Should have spiked dust
		if not self.spikedust then
			self:CreateSpikeDust()
		end
	else
		-- Should not have spiked dust
		if self.spikedust then
			self:StopSpikeDust()
		end
	end

	if e:DeserializeBoolean() then
		-- Should have landingmarker
		local targetpos = e:DeserializePosition()

		if targetpos and not self.landingmarker or self.landingmarker:IsInLimbo() then
			self:CreateLandingMarker(targetpos)
		end
	else
		-- Should not have landingmarker
		if self.landingmarker and not self.landingmarker:IsInLimbo() then
			self:RemoveLandingMarker()
		end
	end

	self:SetupOwnerCallbacks()

	local old_last_attack_seqnr = self.last_attack_seqnr
	self.last_attack_seqnr = e:DeserializeUInt(LAST_ATTACK_SEQNR_BITS)

	if old_last_attack_seqnr ~= self.last_attack_seqnr then
		self.last_attack_type = e:DeserializeString()
		local last_attack_target_count = e:DeserializeUInt(LAST_ATTACK_MAX_TARGET_COUNT_BITS)
		table.clear(self.last_attack_data.targets_hit)
		for _i=1,last_attack_target_count do
			local entID = e:DeserializeEntityID()
			local entGUID = TheNet:FindGUIDForEntityID(entID)
			if entGUID and Ents[entGUID] and Ents[entGUID]:IsValid() then
				table.insert(self.last_attack_data.targets_hit, Ents[entGUID])
			end
		end
		self.last_attack_data.attack_id = e:DeserializeString()
		if self.last_attack_data.attack_id == "" then
			self.last_attack_data.attack_id = nil
		end

		-- TheLog.ch.Shotput:printf("ShotputEffects OnNetDeserialize: seqnr=%d last_attack_type=%s", self.last_attack_seqnr, self.last_attack_type)
		if self.inst.owner and self.inst.owner:IsLocal() and self.last_attack_type ~= "" then
			self.inst.owner:PushEvent(self.last_attack_type, self.last_attack_data)
		end
	else
		-- deserialize and discard data when seqnr is identical
		e:DeserializeString() -- last_attack_type
		local last_attack_target_count = e:DeserializeUInt(LAST_ATTACK_MAX_TARGET_COUNT_BITS)
		while last_attack_target_count > 0 do
			e:DeserializeEntityID()
			last_attack_target_count = last_attack_target_count - 1
		end
		e:DeserializeString() -- last_attack_id
	end
end


function ShotputEffects:OnRemoveFromEntity()
	self:StopSpikeDust()
	self:StopFocusParticles()
	self:RemoveLandingMarker()
end

ShotputEffects.OnRemoveEntity = ShotputEffects.OnRemoveFromEntity

function ShotputEffects:OnEntityBecameLocal()
	self:OnRemoveFromEntity()
	self.last_attack_seqnr = 0

	-- another check to remove the ball if the owner is removed from the simulation
	-- other check listens for onremove event
	if self.inst.owner and not self.inst.owner:IsValid() then
		self.inst:Remove()
	end
end

function ShotputEffects:OnEntityBecameRemote()
	self.last_attack_seqnr = -1
end



return ShotputEffects
