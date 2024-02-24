local EffectEvents = require "effectevents"
local ParticleSystemHelper = require "util.particlesystemhelper"


local powerutil = {}

function powerutil.AttachParticleSystemToEntity(pow, inst, pfxname)
	local param =
	{
		name = pow.def.name.."_particles",
		particlefxname = pfxname,
		ischild = true,
	}

	if not inst.components.powermanager:IsLoading() then
		return ParticleSystemHelper.MakeEventSpawnParticles(inst, param)
	else
		inst.components.powermanager:QueuePresentation(function()
			return ParticleSystemHelper.MakeEventSpawnParticles(inst, param)
		end)
	end
end

function powerutil.AttachParticleSystemToSymbol(pow, inst, pfxname, symbol)
	local param =
	{
		name = pow.def.name.."_particles",
		particlefxname = pfxname,
		followsymbol = symbol,
		ischild = true,
	}

	if not inst.components.powermanager:IsLoading() then
		return ParticleSystemHelper.MakeEventSpawnParticles(inst, param)
	else
		inst.components.powermanager:QueuePresentation(function()
			return ParticleSystemHelper.MakeEventSpawnParticles(inst, param)
		end)
	end
end

function powerutil.StopAttachedParticleSystem(inst, pow)
	local param =
	{
		name = pow.def.name.."_particles",
	}
	return ParticleSystemHelper.MakeEventStopParticles(inst, param)
end

function powerutil.SpawnParticlesOnEntity(target, name, symbol, lifetime)
	return ParticleSystemHelper.MakeOneShot(target, name, symbol, lifetime)
end

function powerutil.SpawnParticlesAtPosition(position, name, lifetime, instigator)
	return ParticleSystemHelper.MakeOneShotAtPosition(position, name, lifetime, instigator)
end

function powerutil.SpawnPowerHitFx(prefab, attacker, target, x_offset, y_offset, hitstoplevel, audio_params)
	-- Putting this here just so all of the power FX related things run through powerutil first.

	-- NOTE networking2022: SpawnPowerHitFx will not show to other players if a client somehow generates an attack from a non-local entity.
	-- For example, the Wanderer is non-local for all players and so their attack will not be visible to other players if a non-host has the interaction.
	-- This can be solved by making all NPCs "minimal" entities, and then the internal check for FXHit could be changed from "IsLocal" to "IsLocal or IsMinimal" and allow it to happen
	-- SEE internal todo list: "- Investigate changing them all to minimal entities?
	return SpawnPowerHitFx(prefab, attacker, target, x_offset, y_offset, hitstoplevel)
end

function powerutil.SpawnFxOnEntity(name, ent, params)
	-- params:
		-- ischild
		-- followsymbol
		-- offx
		-- offy
		-- offz
		-- inheritrotation
		-- detachatexitstate
		-- stopatexitstate
		-- scalex
		-- scalez
		-- flipfacingandrotation
	local fx_param =
	{
		fxname = name,
	}

	if params then
		for k,v in pairs(params) do
			fx_param[k] = v
		end
	end

	return EffectEvents.MakeEventSpawnEffect(ent, fx_param)
end

-- Given a position and a radius, return 3 lists of entities based on how far they are within.
-- Good function for when you want to apply something to a group of entities, but not all at once.
function powerutil.GetEntitiesInRangesFromPoint(x, z, radius)
	local ents = FindEnemiesInRange(x, z, radius)

	local ents_near, ents_med, ents_far = powerutil.SortEntitiesIntoRanges(ents, x, z, radius)
	return ents_near, ents_med, ents_far
end

function powerutil.SortEntitiesIntoRanges(ents, x, z, radius)
	local ranges = { radius * 0.3, radius *.5, radius *.75 }
	local ents_near = {}
	local ents_med = {}
	local ents_far = {}

	for i, ent in ipairs(ents) do
		local dist = math.sqrt(ent:GetDistanceSqToXZ(x,z))
		if dist <= ranges[1] then
			table.insert(ents_near, ent)
		elseif dist >= ranges[2] and dist < ranges[3] then
			table.insert(ents_med, ent)
		else
			table.insert(ents_far, ent)
		end
	end

	return ents_near, ents_med, ents_far
end

function powerutil.GetCounterTextPlusPercent(pow, inst)
	return string.format("+%d%%", pow.counter or 0)
end

function powerutil.GetCounterTextPlus(pow, inst)
	return string.format("+%d", pow.counter or 0)
end

function powerutil.GetCounterTextPercent(pow, inst)
	return string.format("%d%%", pow.counter or 0)
end

function powerutil.TargetIsEnemyOrDestructibleProp(attack)
	local target = attack:GetTarget()
	return target ~= nil and target:IsValid() and (target:HasTag("mob") or target:HasTag("prop_destructible"))
end

function powerutil.EntityIsEnemyOrDestructibleProp(entity)
	return entity ~= nil and entity:IsValid() and (entity:HasTag("mob") or entity:HasTag("prop_destructible"))
end

return powerutil
