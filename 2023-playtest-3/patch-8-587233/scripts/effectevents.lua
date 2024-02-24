local SGCommon = require "stategraphs.sg_common"

local EffectEvents = {}

function EffectEvents.StopFxOnStateExit(inst, ent)
	-- See stategraph.lua for actual removal code.
	inst.sg.mem.autogen_stopfx = inst.sg.mem.autogen_stopfx or {}
	inst.sg.mem.autogen_stopfx[ent] = true

	local fn
	fn = function()
		if inst.sg and inst.sg.mem and inst.sg.mem.autogen_stopfx then
			inst.sg.mem.autogen_stopfx[ent] = nil
		end
		ent:RemoveEventCallback("onremove", fn)
	end
	ent:ListenForEvent("onremove", fn)
	return fn
end

local function RemoveEntityFromExitStateList(inst, entity, listname)
	if inst and inst.sg and inst.sg.mem and inst.sg.mem[listname] then
		inst.sg.mem[listname][entity] = nil
		if not next(inst.sg.mem[listname]) then
			inst.sg.mem[listname] = nil
		end
	end
end

function EffectEvents.MakeEventSpawnEffect(inst, param)
	local fx

	if inst:ShouldSendNetEvents() then
		local fxGUID = TheNetEvent:FXSpawn(inst.GUID, param)
		if fxGUID ~= 0 then
			fx = Ents[fxGUID]
		end
	else
		fx = EffectEvents.HandleEventSpawnEffect(inst, param)
	end

	return fx
end

function EffectEvents.HandleEventSpawnEffect(inst, param)
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
	local testfx = SpawnPrefab(param.fxname, inst)
	local followsymbol = param.followsymbol

	if testfx ~= nil then
		if param.ischild then
			testfx.entity:SetParent(inst.entity)
			testfx.entity:AddFollower()

			if inst.components.hitstopper ~= nil then
				inst.components.hitstopper:AttachChild(testfx)
			end

			if followsymbol then
				testfx.Follower:FollowSymbol(
					inst.GUID,
					followsymbol,
					param.offx or 0,
					param.offy or 0,
					param.offz or 0
				)
				if not param.inheritrotation then
					testfx.AnimState:SetUseOwnRotation()
				end
			else
				testfx.Transform:SetPosition(param.offx or 0, param.offy or 0, param.offz or 0)
				if param.inheritrotation then
					local dir = inst.Transform:GetFacingRotation()
					testfx.Transform:SetRotation(dir)
				end
			end

			if param.detachatexitstate then
				inst.sg.mem.autogen_detachentities = inst.sg.mem.autogen_detachentities or {}
				inst.sg.mem.autogen_detachentities[testfx] = true
				testfx:ListenForEvent("onremove", function()
					RemoveEntityFromExitStateList(inst, testfx, "autogen_detachentities")
				end)
			end
		else
			local offx = param.offx or 0
			local offy = param.offy or 0
			local offz = param.offz or 0

			if followsymbol then
				local x, y, z = inst.AnimState:GetSymbolPosition(followsymbol, offx, offy, offz)
				testfx.Transform:SetPosition(x, y, z)
				if param.inheritrotation then
					local dir = inst.Transform:GetFacingRotation()
					testfx.Transform:SetRotation(dir)
				else
					testfx.AnimState:SetUseOwnRotation()
				end
			else
				local x, y, z = inst.Transform:GetWorldPosition()
				local offdir = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
				testfx.Transform:SetPosition(x + offdir * offx, y + offy, z + offdir * offz)
				if param.inheritrotation then
					local dir = inst.Transform:GetFacingRotation()
					testfx.Transform:SetRotation(dir)
				end
			end
		end
		testfx.AnimState:SetScale(param.scalex or 1, param.scalez or 1)

		if param.flipfacingandrotation then
			testfx:FlipFacingAndRotation()
		end

		if param.stopatexitstate then
			EffectEvents.StopFxOnStateExit(inst, testfx)
		end
	end
	return testfx
end

function EffectEvents.MakeEventFXDeath(inst, attack, fxName, offsets)
	local isFocusAttack = attack ~= nil and attack:GetFocus()
	local attackTarget = attack ~= nil and attack:GetTarget()

	-- FxName is the prefix for the front, ground death FX (Format: <fxName>_<frnt, grnd>)
	TheNetEvent:FXDeath(inst.GUID, isFocusAttack, attackTarget and attackTarget.GUID or 0, fxName, offsets)
end

function EffectEvents.HandleEventFXDeath(inst, isFocusAttack, attackTarget, fxName, offsets)
	local fx = SpawnPrefab("fx_deaths", inst)
	if fx then
		fx:Setup(fxName, offsets)

		if fx.SetupDeathFxFor then
			fx:SetupDeathFxFor(inst)
		end
		if fx.SpawnFocusDeathParticles then
			fx:SpawnFocusDeathParticles(isFocusAttack, attackTarget)
		end
	end
end

function EffectEvents.MakeNetEventScorchMark(inst, focus, explo_scale, scorch_scale, scorch_rot, scorch_fade_scale)
	if inst:ShouldSendNetEvents() then
		TheNetEvent:FXScorchMark(inst.GUID, focus, explo_scale, scorch_scale, scorch_rot, scorch_fade_scale)
	else
		EffectEvents.HandleNetEventScorchMark(inst, focus, explo_scale, scorch_scale, scorch_rot, scorch_fade_scale)
	end
end

function EffectEvents.HandleNetEventScorchMark(inst, focus, explo_scale, scorch_scale, scorch_rot, scorch_fade_scale)
	local expl_prefab = focus and "cannon_mortar_explosion_focus" or "cannon_mortar_explosion"
	local grnd_prefab = focus and "cannon_mortar_explosion_groundring_focus" or "cannon_mortar_explosion_groundring"

	-- Create an explosion
	local explo = SGCommon.Fns.SpawnAtDist(inst, expl_prefab, 0)
	explo.AnimState:SetScale(explo_scale, explo_scale, explo_scale)
	local grnd = SGCommon.Fns.SpawnAtDist(inst, grnd_prefab, 0)

	-- Make a scorchmark and make it fade. on timeout, remove the fade + this entity
	local scorchmark = SGCommon.Fns.SpawnAtDist(inst, "mortar_explosion_scorch_mark", 0)
	scorchmark.Transform:SetRotation(scorch_rot)
	scorchmark.Transform:SetScale(scorch_scale, scorch_scale, scorch_scale)

	-- scorch mark remains for 5 seconds, then fades
	scorchmark:DoTaskInTime(5, function(sinst)
		if sinst ~= nil and sinst:IsValid() then
			sinst.AnimState:PlayAnimation("scorch_mark_fade")
			sinst.AnimState:SetDeltaTimeMultiplier(scorch_fade_scale)
		end
	end)
end

-- see fx_hits.lua for SpawnHitFx, SpawnPowerHitFx, SpawnHurtFx
-- these are pretty old / legacy effect implementations

function EffectEvents.MakeEventSpawnLocalEntity(inst, prefabname, initialstate)
	TheNetEvent:SpawnLocalEntity(inst.GUID, prefabname, initialstate)
end

function EffectEvents.HandleEventSpawnLocalEntity(inst, prefabname, initialstate)
	if not prefabname or not Prefabs[prefabname] then
		-- TODO @chrisp #net - I think this should be an error
		TheLog.ch.Network:printf("ERROR: HandleEventSpawnLocalEntity has invalid prefabname: " .. prefabname)
		return
	end

	-- The entity that is spawned locally HAS to have a network type that is local. It is not allowed to spawn entities that are networked, or the networking will break.
--	if Prefabs[prefabname].network_type ~= NetworkType_None then
--		TheLog.ch.Network:printf("ERROR: HandleEventSpawnLocalEntity ignored local entity spawn: Cannot spawn prefabs that have a network type that is not LOCAL. prefab=" .. prefabname)
--		return
--	end


	local ent = SGCommon.Fns.SpawnAtDist(inst, prefabname, 0, nil, true)
	if not ent then
		-- TODO @chrisp #net - I think this should be an error
		-- TheLog.ch.Network:printf("ERROR: HandleEventSpawnLocalEntity failed to spawn entity from prefab (%s)", prefabname)
		return
	end

	if initialstate then
		local function GoToInitialState()
			if not ent.sg then
				-- TODO @chrisp #net - I think this should be an error
				-- TheLog.ch.Network:printf("ERROR: HandleEventSpawnLocalEntity specified an initialstate (%s) for an entity (%s) without a state graph", initialstate, prefabname)
				return
			end
			if not ent.sg:HasState(initialstate) then
				-- TODO @chrisp #net - I think this should be an error
				-- TheLog.ch.Network:printf("ERROR: HandleEventSpawnLocalEntity specified an initialstate (%s) for an entity (%s) whose state graph does not contain that state", initialstate, prefabname)
				return
			end
			ent.sg:GoToState(initialstate)
		end
		GoToInitialState()
	end

	ent:PushEvent("spawned_local_entity", {
		instigator = inst,
		prefabname = prefabname,
		initialstate = initialstate,
	})
end


function EffectEvents.MakeNetEventPushEventOnMinimalEntity(inst, eventname, parameters)
	if not inst:IsMinimal() then
		print("ERROR: Cannot start event " .. eventname .. " on non-minimal entity.")
	else
		TheNetEvent:PushEventOnMinimalEntity(inst.GUID, eventname, parameters)
	end
	return 0
end

function EffectEvents.HandleNetEventPushEventOnMinimalEntity(inst, eventname, parameters)
	if eventname and inst:IsMinimal() then
		inst:PushEvent(eventname, parameters)
	end
end




function EffectEvents.MakeNetEventPushHitBoxInvincibleEventOnEntity(inst, target)
	if inst:IsLocal() then
		if target:IsLocal() then
			EffectEvents.HandleNetEventPushHitBoxInvincibleEventOnEntity(inst, target)
		else
			TheNetEvent:PushHitBoxInvincibleEventOnEntity(inst.GUID, target.GUID)
		end

		inst:PushEvent("hitboxcollided_invincible_target", target)
	end
	return 0
end

function EffectEvents.HandleNetEventPushHitBoxInvincibleEventOnEntity(inst, target)
	if target:IsLocal() then
		target:PushEvent("hitboxcollided_invincible", inst.components.hitbox) -- let it know that it would have been hit
		inst:PushEvent("hitboxcollided_invincible_target", target)
	end
end


-- Converts a table containing entity scripts to a table that contains EntityID's
function ConvertToEntityIDs(actors_table)
	-- Format:
	-- {
	--   roles =
	--	 {
	--      lead = <entityscript>
	--   }
	--   subactors =
	--   {
	--      <entityscript>
	--      <entityscript>
	--      <entityscript>
	--      <entityscript>
	--      <entityscript>
	--   }
	-- }
	local result = { roles={}, subactors={}}

	if actors_table.roles and actors_table.roles.lead then
		if actors_table.roles.lead.Network then
			result.roles.lead = actors_table.roles.lead.Network:GetEntityID()
		else
			print("Entity " .. actors_table.roles.lead.prefab .. " needs to be a networked entity of type 'NetworkType_HostAuth' to be a lead actor in a cinematic.")
		end
	end
	if actors_table.subactors then
		result.subactors = {}
		for _, ent in ipairs(actors_table.subactors) do
			if ent.Network then
				table.insert(result.subactors, ent.Network:GetEntityID())
			else
				print("Entity " .. ent.prefab .. " needs to be a networked entity 'NetworkType_HostAuth' to be a sub-actor in a cinematic.")

			end
		end
	end

	return result
end

function ResolveToEntityScript(entityID)
	local guid = TheNet:FindGUIDForEntityID(entityID)
	return guid and Ents[guid] or nil
end

function ConvertToEntityInstances(actors_table)
	local result = { roles={}, subactors={}}

	if actors_table.roles.lead then
		result.roles.lead = ResolveToEntityScript(actors_table.roles.lead)
	end

	if actors_table.subactors then
		result.subactors = {}
		for _, entityID in ipairs(actors_table.subactors) do
			table.insert(result.subactors, ResolveToEntityScript(entityID))
		end
	end

	return result
end


function EffectEvents.MakeNetEventPlayCinematic(inst, actors_table)
	if not inst:IsMinimal() then
		print("ERROR: Cannot play cinematic on non-minimal entity.")
	else
		-- Convert the actors_table to use entityIDs instead of entityscripts
		local convertedtable = ConvertToEntityIDs(actors_table)
		TheNetEvent:PlayCinematic(inst.GUID, convertedtable)
	end
	return 0
end

function EffectEvents.HandleNetEventPlayCinematic(inst, converted_table)
	if inst:IsMinimal() then
		local MAX_RETRIES = 30
		local num_retries = 0
		local _play_cinematic_network = nil
		_play_cinematic_network = function()
			local actors_table = ConvertToEntityInstances(converted_table)

			-- If there's a lead actor role defined, but the entity hasn't been loaded yet, keep retrying to obtain the entity instance
			if actors_table.roles.lead == nil and converted_table.roles.lead ~= nil then
				num_retries = num_retries + 1
				if num_retries <= MAX_RETRIES then
					print("WARNING: Cinematic lead actor entity hasn't been loaded yet. Retrying in a few ticks...")
					inst:DoTaskInTicks(2, _play_cinematic_network)
				else
					print("WARNING: Cinematic lead actor entity cannot be loaded.")
					return
				end
			else
				inst:PlayCinematicNetwork(actors_table)
			end
		end

		_play_cinematic_network()
	end
end



return EffectEvents
