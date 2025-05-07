local ParticleSystemHelper = {}

function ParticleSystemHelper.MakeOneShot(target, effectName, attachSymbol, lifetime)
	lifetime = lifetime or TICKS

	local pfx = SpawnPrefab(effectName, target)
	if target then
		pfx.entity:SetParent(target.entity)
		pfx.entity:AddFollower()
		if attachSymbol then
			pfx.Follower:FollowSymbol(target.GUID, attachSymbol)
		end
	end

	pfx.OnTimerDone = function(source, data)
		if source == pfx and data ~= nil and data.name == "hitexpiry" then
			source.components.particlesystem:StopAndNotify()
		end
	end

	pfx.OnParticlesDone = function(source, data)
		if source == pfx then
			source:Remove()
		end
	end

	pfx:ListenForEvent("timerdone", pfx.OnTimerDone)
	pfx:ListenForEvent("particles_stopcomplete", pfx.OnParticlesDone)

	local timer = pfx:AddComponent("timer")
	timer:StartTimer("hitexpiry", lifetime)
	return pfx
end

function ParticleSystemHelper.MakeOneShotAtPosition(position, effectName, lifetime, instigator, param)
	lifetime = lifetime or TICKS

	if instigator and instigator:IsValid() and instigator:IsNetworked() and instigator:IsLocal() then
		local fxGUID = TheNetEvent:ParticlesOneShotAtPosition(instigator.GUID, position, effectName, lifetime, param)
		if fxGUID then
			return Ents[fxGUID]
		end
		return nil
	else
		return ParticleSystemHelper.HandleMakeOneShotAtPosition(position, effectName, lifetime, instigator, param)
	end
end

-- TODO(dbriscoe): Make everything pass instigator
function ParticleSystemHelper.HandleMakeOneShotAtPosition(position, effectName, lifetime, instigator, param)
	local pfx = SpawnPrefab(effectName, instigator)
	pfx.Transform:SetPosition(position.x, position.y, position.z)

	-- print(position, effectName, lifetime, instigator, param)
	pfx.OnTimerDone = function(source, data)
		if source == pfx and data ~= nil and data.name == "hitexpiry" then
			source.components.particlesystem:StopAndNotify()
		end
	end

	pfx.OnParticlesDone = function(source, data)
		if source == pfx then
			source:Remove()
		end
	end

	if param then
		for emitter_num,emitter_param in ipairs(param) do
			local emitter = pfx.components.particlesystem:GetEmitter(emitter_num)

			-- Multiplier of amount of particles in the burst
			if emitter_param.amount_mult then
				local raw_amount = emitter:GetBurstAmount()
				local new_amount = math.max(1, math.ceil(raw_amount * emitter_param.amount_mult)) -- QUESTION: Should we allow boosting above 100% amount? Existing uses did not.
				emitter:SetupBurstOnce(new_amount)
			end

			-- Multiplier of size of particles in the burst
			if emitter_param.scale_mult then
				emitter:SetScaleMult(emitter_param.scale_mult)
			end
		end

		if param.use_entity_facing then
			local emitters = pfx.components.particlesystem.emitters
			if emitters then
				for i, emitter in ipairs(emitters) do
					emitter.inst.ParticleEmitter:UseEntityFacing(param.use_entity_facing or false)

					local facing_left = instigator.Transform:GetFacing() == FACING_LEFT
					local spawn_vel_x_min = facing_left and -emitter.params.spawn.vel[1] or emitter.params.spawn.vel[1]
					local spawn_vel_x_max = facing_left and -emitter.params.spawn.vel[2] or emitter.params.spawn.vel[2]
					local spawn_vel_flipped = { spawn_vel_x_min, spawn_vel_x_max, table.unpack(emitter.params.spawn.vel, 3, 6) }
					emitter.inst.ParticleEmitter:SetSpawnVel( table.unpack( spawn_vel_flipped ) )
				end
			end
		end
	end

	pfx:ListenForEvent("timerdone", pfx.OnTimerDone)
	pfx:ListenForEvent("particles_stopcomplete", pfx.OnParticlesDone)

	local timer = pfx:AddComponent("timer")
	timer:StartTimer("hitexpiry", lifetime)
	return pfx
end

-- TODO(dbriscoe): Make everything pass instigator
function ParticleSystemHelper.AttachParticlesForTime(target, effectName, attachSymbol, lifetime, instigator)
	local pfx = SpawnPrefab(effectName, instigator)
	pfx.entity:SetParent(target.entity)
	pfx.entity:AddFollower()
	if attachSymbol then
		pfx.Follower:FollowSymbol(target.GUID, attachSymbol)
	end

	pfx.OnTimerDone = function(source, data)
		if source == pfx and data ~= nil and data.name == "hitexpiry" then
			source.components.particlesystem:StopAndNotify()
		end
	end

	pfx.OnParticlesDone = function(source, data)
		if source == pfx then
			local parent = source.entity:GetParent()
			if parent and parent.hitTrailEntity == source then
				-- clear the entry if it is us, otherwise leave it alone
				-- another trail may have started while waiting for the emitter to stop
				parent.hitTrailEntity = nil
			end
			source:Remove()
		end
	end

	pfx:ListenForEvent("timerdone", pfx.OnTimerDone)
	pfx:ListenForEvent("particles_stopcomplete", pfx.OnParticlesDone)

	local timer = pfx:AddComponent("timer")
	timer:StartTimer("hitexpiry", lifetime)
end

-- ===========================================================================
-- eventfunc implementation for particle system events (i.e. spawnparticles, stopparticles)
-- ===========================================================================

local function RemoveParticles(inst)
	-- TheLog.ch.NetworkEventManager:printf("EventFuncs RemoveParticles ent=%d name=%s", inst.GUID, inst.prefab)
	inst:Remove()
end

local function GetMemTable_Safe(inst, listname)
	return inst and inst.sg and inst.sg.mem and inst.sg.mem[listname]
end

local function RemoveEntityFromExitStateList(inst, entity, listname)
	local list = GetMemTable_Safe(inst, listname)
	if list then
		list[entity] = nil
		if not next(list) then
			inst.sg.mem[listname] = nil
		end
	end
end

-- Like RemoveEntityFromExitStateList, but for labeled tables. We check the
-- name matches the entity we're removing.
local function RemoveEntityFromNamedList(inst, name, entity, listname)
	local list = GetMemTable_Safe(inst, listname)
	if list then
		if list[name] == entity then
			list[name] = nil
			if not next(list) then
				inst.sg.mem[listname] = nil
			end
		else
			TheLog.ch.NetworkEventManager:printf("RemoveEntityFromNamedList, but found inst.sg.mem.%s[%s]: <%s> instead of <%s>. Ignoring.", listname, name, list[name], entity)
		end
	end
end

-- inst : originating entity instance that has a stategraph component
-- param :
--   name (string): particle system instance name
--   particlefxname (string): particle system name
--   duration (float): time to live in seconds
--   followsymbol (string) : specific attach location on entity instance (assuming it has an animstate)
--   ischild (bool) : sets the spawned particle system entity as a child of the entity instance
--   offx, offy, offz (floats) : offset vector relative to entity instance (applies as child and relative to followsymbol)
--   angle: angle (in degrees) in which emitter particles travel at. Rotates exising x, y velocity & gravity values.
--   use_entity_facing (bool) : true changes flip based on the parent entity
--   render_in_front (bool) : true changes rendering sort order to 1
--   stopatexitstate (bool) : stops particle system entity when instance stategraph state change
--   detachatexitstate (bool) : detachs particle system entity on instance stategraph state change
function ParticleSystemHelper.MakeEventSpawnParticles(inst, param)
	if param.name and inst.sg then
		inst.sg.mem.autogen_particles = inst.sg.mem.autogen_particles or {}
		if inst.sg.mem.autogen_particles[param.name] then
			-- this effect was already spawned, don't spawn it again
			return
		end
	end

	local particles
	if inst:ShouldSendNetEvents() then
		-- see networking.lua HandleNetEventParticlesStart
		local particlesGUID = TheNetEvent:ParticlesStart(inst.GUID, param);
		particles = Ents[particlesGUID]
	else
		particles = ParticleSystemHelper.HandleEventSpawnParticles(inst, param)
	end
	return particles
end

function ParticleSystemHelper.HandleEventSpawnParticles(inst, param)
	if param.name and inst.sg then
		inst.sg.mem.autogen_particles = inst.sg.mem.autogen_particles or {}
		if inst.sg.mem.autogen_particles[param.name] then
			-- this effect was already spawned, don't spawn it again
			return
		end
	end

	local particles = SpawnPrefab(param.particlefxname, inst)
	if param.duration then
		particles:DoTaskInTicks(param.duration, function(finst)
			finst.components.particlesystem:StopAndNotify()
		end)
	end

	local followsymbol = param.followsymbol
	if particles then
		if param.ischild then
			particles.entity:SetParent(inst.entity)
			particles.entity:AddFollower()

			if inst.components.hitstopper ~= nil then
				inst.components.hitstopper:AttachChild(particles)
			end

			if followsymbol then
				particles.Follower:FollowSymbol(
					inst.GUID,
					followsymbol,
					param.offx or 0,
					param.offy or 0,
					param.offz or 0
				)
			else
				particles.Transform:SetPosition(param.offx or 0, param.offy or 0, param.offz or 0)
			end
		else
			local offx = param.offx or 0
			local offy = param.offy or 0
			local offz = param.offz or 0

			if followsymbol then
				local x, y, z = inst.AnimState:GetSymbolPosition(followsymbol, offx, offy, offz)
				particles.Transform:SetPosition(x, y, z)
			else
				local x, y, z = inst.Transform:GetWorldPosition()
				local offdir = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
				particles.Transform:SetPosition(x + offdir * offx, y + offy, z + offdir * offz)
			end
		end

		-- If enabled, we need to flip x-axis offset, gravity, & velocity (if used) to respect the entity's facing.
		if param.use_entity_facing then
			local emitters = particles.components.particlesystem.emitters
			if emitters then
				local facing_left = inst.Transform:GetFacing() == FACING_LEFT

				-- If animstate is flipped, check for it to see if it's facing opposite of the transform.
				if inst.AnimState and inst.AnimState:GetScale() < 0 and not facing_left then
					facing_left = true
				end

				for i, emitter in ipairs(emitters) do
					local offset_x = facing_left and -(emitter.params.x or 0) or (emitter.params.x or 0)

					-- Offset.
					if emitter.params.spawn.positionMode then
						emitter.inst.ParticleEmitter:SetSpawnPoint(offset_x, emitter.params.y, emitter.params.z)
					elseif emitter.params.spawn.box then
						-- If an emitter shape is used, need to take that into account for positioning.
						local spawn_box = shallowcopy(emitter.params.spawn.box)

						-- Move the spawn box to the other size of the x-axis if facing left.
						if facing_left and offset_x ~= 0 then
							spawn_box[1] = -spawn_box[1] - (param.offx or 0)
							spawn_box[2] = -spawn_box[2] - (param.offx or 0)
							emitter.inst.ParticleEmitter:SetSpawnAABB( table.unpack( spawn_box ) )
						end
					end

					-- Gravity
					local gravity_x = facing_left and -(emitter.params.gravity_x or 0) or (emitter.params.gravity_x or 0)
					emitter.inst.ParticleEmitter:SetGravity(gravity_x or 0, emitter.params.gravity_y or 0, emitter.params.gravity_z or 0)

					-- Velocity
					emitter.inst.ParticleEmitter:SetSpawnVel( table.unpack(emitter.params.spawn.vel) )

					-- Angle
					if param.angle then
						-- velocity
						local vel_min = Vector2(emitter.params.spawn.vel[1], emitter.params.spawn.vel[3])
						local vel_max = Vector2(emitter.params.spawn.vel[2], emitter.params.spawn.vel[4])

						local rotated_vel_min = Vector2.rotate(vel_min, math.rad(-param.angle))
						local rotated_vel_max = Vector2.rotate(vel_max, math.rad(-param.angle))

						emitter.inst.ParticleEmitter:SetSpawnVel( rotated_vel_min.x, rotated_vel_max.x, rotated_vel_min.y, rotated_vel_max.y, 0, 0)

						-- gravity
						local gravity = Vector3(emitter.params.gravity_x, emitter.params.gravity_y, emitter.params.gravity_z)
						local rotated_gravity = Vector3.rotate(gravity, math.rad(-param.angle), Vector3.unit_y)
						emitter.inst.ParticleEmitter:SetGravity(rotated_gravity.x, rotated_gravity.y, rotated_gravity.z)
					end

					local rotation = emitter.params.r or 0
					emitter.inst.ParticleEmitter:SetWorldEmitterRotation(rotation)
					--emitter.inst.ParticleEmitter:SetWorldEmitterRotation(facing_left and -rotation or rotation)
				end
			end
		end

		local facing = inst.Transform:GetFacing()
		for _, emitter in ipairs(particles.components.particlesystem.emitters) do
			emitter.inst.ParticleEmitter:UseEntityFacing(param.use_entity_facing or false)
			if not param.ischild then
				emitter.inst.ParticleEmitter:SetSpawnFacing(facing)
			end
		end

		-- in front or behind?
		if param.render_in_front then
			particles.components.particlesystem:SetSortOrder(1)
		end

		particles:ListenForEvent("particles_stopcomplete", RemoveParticles, particles)

		if param.name and inst.sg then
			inst.sg.mem.autogen_particles[param.name] = particles
			particles:ListenForEvent("onremove", function()
				RemoveEntityFromNamedList(inst, param.name, "autogen_particles")
			end)
		end

		if param.stopatexitstate and inst.sg then
			inst.sg.mem.autogen_stopparticles = inst.sg.mem.autogen_stopparticles or {}
			inst.sg.mem.autogen_stopparticles[particles] = true
			particles:ListenForEvent("onremove", function()
				RemoveEntityFromExitStateList(inst, particles, "autogen_stopparticles")
			end)
		end

		if param.detachatexitstate and inst.sg then
			inst.sg.mem.autogen_detachentities = inst.sg.mem.autogen_detachentities or {}
			inst.sg.mem.autogen_detachentities[particles] = true
			particles:ListenForEvent("onremove", function()
				RemoveEntityFromExitStateList(inst, particles, "autogen_detachentities")
			end)
		end
	end
	return particles
end

-- inst : originating entity instance that has a stategraph component
-- param :
--   name (string): particle system instance name to stop; if nil, then all particle systems associated with the instance are stopped
function ParticleSystemHelper.MakeEventStopParticles(inst, param)
	if inst.Network then
		TheNetEvent:ParticlesStop(inst.GUID, param and param.name or nil)
	else
		if not param then
			ParticleSystemHelper.HandleEventStopAllParticles(inst)
		else
			ParticleSystemHelper.HandleEventStopParticles(inst, param)
		end
	end
end

function ParticleSystemHelper.HandleEventStopParticles(inst, param)
	if inst.sg and inst.sg.mem and inst.sg.mem.autogen_particles then
		local particles = inst.sg.mem.autogen_particles[param.name]
		if particles then
			inst.sg.mem.autogen_particles[param.name] = nil
			particles.components.particlesystem:StopAndNotify()
			-- else it fizzled or something: probably okay.
		end
	-- else
		-- Maybe user forgot to name their particle, but more likely we
		-- just hit a stop that may happen out of order with the start.
	end
end

function ParticleSystemHelper.HandleEventStopAllParticles(inst)
	if inst.sg and inst.sg.mem and inst.sg.mem.autogen_stopparticles then
		for k,_v in pairs(inst.sg.mem.autogen_stopparticles) do
			TheLog.ch.NetworkEventManager:printf("StateGraph RunStopAutogen StopParticles ent=%d name=%s", k.GUID, k.prefab)
			k.components.particlesystem:StopAndNotify()
		end
	end
end

return ParticleSystemHelper
