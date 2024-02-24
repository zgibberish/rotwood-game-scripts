--------------------------------------------------------------------------
-- Utilities for loading autogenerated Cine prefabs
--------------------------------------------------------------------------

local EffectEvents = require "effectevents"
local camerautil = require "util.camerautil"
local eventfuncs = require "eventfuncs"
local kassert = require "util.kassert"
local lume = require "util.lume"


local cineutil = {}


-- I think these functions are here instead of on cineactor so you didn't have
-- to add cineactor component to everything pushed into a cine state, but I'm
-- no longer sure that's worth it. We should move more logic into cineactor and
-- require every actor to have that component.
local function AllowExitCineState(inst)
	inst.sg.mem.is_in_active_cine = nil
end
local function TryExitCineState(inst)
	if inst.sg.mem.needs_postcine_restore
		and not inst.sg.mem.is_in_active_cine -- cine is no longer active
		and not inst.sg.statemem.has_queued_cine -- Skip if we have another cine queued up to play
	then
		--~ TheLog.ch.Cine:printf("[%s] TryExitCineState going %s -> %s", inst, inst.sg:GetCurrentState(), inst.sg.mem.cine_resumestate)
		kassert.assert_fmt(inst.sg.mem.cine_resumestate, "Why don't we have a resume state? Current state: %s", inst.sg:GetCurrentState())
		if inst.HitBox then
			inst.HitBox:SetInvincible(inst.sg.mem.was_invincible_before_cine)
			inst.sg.mem.was_invincible_before_cine = nil
		end
		inst.sg:GoToState(inst.sg.mem.cine_resumestate)
		inst.sg.mem.cine_resumestate = nil
		inst.sg.mem.needs_postcine_restore = nil
	end
end
local function IsAnimationOver(inst)
	return not inst.AnimState or inst.AnimState:IsCurrentAnimDone() or (inst.sg and inst.sg:GetCurrentState() == "idle")
end
local function StartCineState(inst, resumestate)
	if not inst then
		print("WARNING: cine actor is nil. Aborting cine state!")
		return
	end

	if not inst.components.cineactor then
		inst:AddComponent("cineactor")
	end
	inst.TryExitCineState = TryExitCineState

	-- don't allow remote entities to do further setup.  This could cause side effects
	-- like invincibility state weirdness when entity ownership changes
	if not inst:IsLocalOrMinimal() then
		return
	end

	inst.sg.mem.is_in_active_cine = true
	inst.sg.mem.needs_postcine_restore = true

	if inst.HitBox then
		-- Make everything invincible so it can't get interrupted during cine.
		inst.sg.mem.was_invincible_before_cine = inst.HitBox:IsInvincible()
		inst.HitBox:SetInvincible(true)
	end

	if not inst.sg.sg.states.cinematic then
		inst.sg.sg.states.cinematic = State({
				name = "cinematic",
				tags = { "busy", "nointerrupt", },
				events = {
					-- Defer exiting state to animover for smoother transitions.
					EventHandler("animover", TryExitCineState),
				},
			})
	end
	inst.sg:ForceGoToState("cinematic")
	-- Can't put resumestate in statemem to support eventfunc.gotostate.
	inst.sg.mem.cine_resumestate = resumestate or "idle"
end


local function SetupCinematic(inst, lead, is_test)
	if inst:IsLocal() then
		-- Setup the actors_table, to be transfered to start the cinematic
		local actors_table = { roles={}, subactors={}}
		actors_table.roles.lead = lead

		-- Spawn sub actors in the cinematic:
		if inst.subactor_data then
			local subactors = {}
			for _, subactor in ipairs(inst.subactor_data) do
				if is_test or not subactor.assigned_at_runtime then
					TheSim:LoadPrefabs({ subactor.prefabname }) -- Need to load prefabs in case they haven't been loaded yet.
					local actor = SpawnPrefab(subactor.prefabname)

					--assert(actor:IsNetworked(), "Sub actors are required to be networked entities!")
					if not actor:IsNetworked() then
						print("WARNING: " .. actor.prefab .. "should be a networked entity to be a cine actor")
					end

					if actor:IsNetworked() then
						table.insert(subactors, actor)
					else
						actor:Remove()
					end
				end
			end
			actors_table.subactors = subactors
		end

		EffectEvents.MakeNetEventPlayCinematic(inst, actors_table)
	end
end

local function PlayCinematicNetwork(inst, actors_table)
	if actors_table then
		inst.cine.roles = actors_table.roles
		inst.cine.subactors = actors_table.subactors
	end

	if #AllPlayers > 0 then
		if inst.cine.roles.lead then
			-- Snap cine to lead actor's position to give it a well-defined
			-- position.
			local x,z = inst.cine.roles.lead.Transform:GetWorldXZ()
			inst.Transform:SetPosition(x, 0, z)
		end

		inst.sg:GoToState("playing")
	else
		-- No player, means lots of cine things won't work. So wait.
		inst.sg:SetTimeoutTicks(2)
	end
end

-- This will skip the cine whether it's authored for skip or not! We rely on
-- that to skip during authoring for preview.
local function SkipCinematic(inst)
	TheLog.ch.Cine:print("Skipping cinematic")
	inst.sg.mem.skipped_cine = true

	inst:PushEvent("cine_skipped")

	local data =
	{
		root_pos = inst:GetPosition(),
	}

	-- Send the cine_skipped event to all players, actors:
	for _, player in ipairs(AllPlayers) do
		player:PushEvent("cine_skipped", data)
	end

	-- Lead actor
	for _, role in pairs(inst.cine.roles) do
		role:PushEvent("cine_skipped", data)
	end

	-- Subactors
	if inst.cine.subactors then
		for i, subactor in ipairs(inst.cine.subactors) do
			local subactor_data = lume.merge(data, inst.subactor_data[i])
			subactor:PushEvent("cine_skipped", subactor_data)
		end
	end

	inst.sg:GoToState("complete")
end


function PauseAllEnemyBrains(inst)
	if TheWorld.components.roomclear then
		local enemies = TheWorld.components.roomclear:GetEnemies()
		for enemy, _ in pairs(enemies) do
			if enemy.brain then
				enemy.brain:Pause(inst)
			end
		end
	end
end

function ResumeAllEnemyBrains(inst)
	if TheWorld.components.roomclear then
		local enemies = TheWorld.components.roomclear:GetEnemies()
		for enemy, _ in pairs(enemies) do
			if enemy.brain then
				enemy.brain:Resume(inst)
			end
		end
	end
end


local function MakeStateGraph(params)
	local sg_timeline = {}

	local run_on_skip = {}

	for _,eventlist in pairs(params.timelines or {}) do
		-- Must iterate ordered so run_on_skip will run in the right order!
		for _,p in ipairs(eventlist) do
			local start, stop, v = table.unpack(p)
			local eventdef = eventfuncs[v.eventtype]
			local e = eventdef.cinefunc(eventdef, start, v.param, v)
			e.eventname = v.eventtype
			table.insert(sg_timeline, e)
			if eventdef.run_on_skip then
				table.insert(run_on_skip, e)
			end
		end
	end

	local events =
	{
		EventHandler("animover", function(inst)
			-- TODO(dbriscoe): handle some kind of over state in editor?
		end),
	}

	local states = {
		State({
			name = "waiting",

			onenter = function(inst)
				-- Minor delay to give time to setup actors after spawn, but
				-- also allow spawning to automatically start the cine.
				if inst:IsLocal() then
					inst.sg:SetTimeoutTicks(2)
				end
			end,

			ontimeout = function(inst)
				if inst:IsLocal() then
					inst:PlayCinematicNetwork()
				end
			end
		}),
		State({
			name = "playing",
			timeline = sg_timeline,

			onenter = function(inst)
				-- Set the position of the cine prefab.
				if inst.cine.roles.lead and params.use_lead_actor_pos then
					local x, y, z = inst.cine.roles.lead:GetPosition():Get()
					inst.Transform:SetPosition(x, y, z)
				elseif params.scene_init and params.scene_init.pos then
					local x = params.scene_init.pos.x
					local z = params.scene_init.pos.z
					inst.Transform:SetPosition(x, 0, z)
				end

				-- One extra frame so final frame count matches duration and
				-- events on the last frame work.
				inst.sg:SetTimeoutAnimFrames((params.scene_duration or 0) + 1)
				for role,ent in pairs(inst.cine.roles) do
					ent:Stupify("cinematic")
				end

				-- Set up sub actors
				if inst.cine.subactors then
					for i, subent in ipairs(inst.cine.subactors) do
						cineutil.SetupActor(subent, inst.subactor_data[i], inst:GetPosition())
						subent:Stupify("cinematic")
					end
				end

				for role,data in pairs(params.pause_role_sg) do
					local ent = inst.cine.roles[role]
					StartCineState(ent, data.resumestate)
				end
				inst.sg.statemem.skip_ticks = 0
				inst.sg.mem.run_on_skip = run_on_skip
				PauseAllEnemyBrains(inst)
			end,

			-- TODO(dbriscoe): Use an event handler instead?
			onupdate = function(inst)
				if params.is_skippable
					and TheInput:IsControlDownOnAnyDevice(Controls.Digital.CINE_HOLD_SKIP)
					and false -- DEC2023 playtest: Right now there's a bug where skipping a cinematic can mess up the mob's timers.
							  -- Also, we don't support skipping cines in MP yet. Disabling user skipping for now!
				then
					inst.sg.statemem.skip_ticks = inst.sg.statemem.skip_ticks + 1
					if inst.sg.statemem.skip_ticks > 0.5 * SECONDS then
						inst:SkipCinematic()
					end
				end
			end,

			ontimeout = function(inst)
				--~ TheLog.ch.Cine:printf("Cine ended. AnimFramesInState: %d", inst.sg:GetAnimFramesInState())
				-- Change scene so "until state exits" events fire.
				inst.sg:GoToState("complete")
			end,

			onexit = function(inst)
				for role,ent in pairs(inst.cine.roles) do
					ent:Unstupify("cinematic")
					ent:PushEvent("cine_end", inst.prefab)
				end

				if inst.cine.subactors then
					for i, subent in ipairs(inst.cine.subactors) do
						subent:Unstupify("cinematic")

						-- Remove sub actors flagged for removal.
						if inst.subactor_data[i] and inst.subactor_data[i].kill_on_end then
							-- If the cinematic is in editor mode, hide the sub actor instead of removing it, since we may need to edit it.
							if inst.isEditorPrefab then
								subent:Hide()
							elseif subent:IsValid() then
								subent:Remove()
							end

						end
					end
				end

				for role in pairs(params.pause_role_sg) do
					local ent = inst.cine.roles[role]
					if ent.sg then
						AllowExitCineState(ent)

						if inst.sg.mem.skipped_cine
							-- If anim already ended, we won't get another animover
							-- event: trigger exit now.
							or IsAnimationOver(ent)
						then
							TryExitCineState(ent)
						else
							ent.components.cineactor:ExitCineOnAnimOver()
						end
					end
				end
				if inst.sg.mem.skipped_cine then
					local current_frame = inst.sg:GetAnimFramesInState()
					for i,ev in ipairs(inst.sg.mem.run_on_skip) do
						local frame = ev.frame / ANIM_FRAMES
						if frame >= current_frame then
							TheLog.ch.Cine:printf("Running event '%s' [frame:%d] because we skipped at frame %d.", ev.eventname, frame, current_frame)
							-- If we needed this to work for duration events,
							-- we could make run_on_skip a function that gets
							-- called on skip.
							ev.fn(inst)
						end
					end
				end
				inst.sg.mem.skipped_cine = nil
				inst.sg.mem.run_on_skip = nil
				inst:PushEvent("cine_end", inst.prefab)
				-- In case we forgot a cameratargetend.
				camerautil.ReleaseCamera(inst)
				-- or forgot a blurscreen end
				local off = {} -- empty is off
				TheWorld.components.blurcoordinator:FadeTo(0.4 * SECONDS, off)
				ResumeAllEnemyBrains(inst)
			end,

		}),
		State({
			name = "complete",
		}),
	}

	return StateGraph("sg_cine", states, events, "waiting")
end

function cineutil.ShowActor(inst)
	inst:Show()
	inst.Physics:SetEnabled(true)
end

function cineutil.HideActor(inst)
	inst:Hide()
	inst.Physics:SetEnabled(false)
end

function cineutil.SetupActor(inst, data, start_pos)
	if not data then return end

	if not data.show_on_spawn then
		cineutil.HideActor(inst)
	end

	-- By default, sub actors face towards screen right. The lead actor currently faces towards the player.
	if data.face_left then
		inst.Transform:SetRotation(180)
	end

	-- Set the position of sub actors relative to start_pos (or the prefab position if start_pos doesn't exist)
	start_pos = start_pos or Vector3.zero
	local spawn_pos = start_pos or Vector3.zero
	if data.start_pos and data.start_pos.pos then
		local offset = data.start_pos.pos
		spawn_pos = start_pos + offset
	end

	inst.Transform:SetPosition(spawn_pos:Get())

	return inst
end

function cineutil.Debug_SetupActor(inst, data, start_pos)
	cineutil.SetupActor(inst, data, start_pos)

	inst:Stupify("cineeditor") -- don't Unstupify when cine ends.
	inst.persists = false
	if inst.components.prop and TheWorld.components.propmanager then
		TheWorld.components.propmanager:Debug_ForceUnregisterProp(inst)
	end

	return inst
end

function cineutil.Debug_SpawnActor(prefab, data)
	TheSim:LoadPrefabs({ prefab })
	local inst = SpawnPrefab(prefab, TheDebugSource)
	if inst then
		cineutil.Debug_SetupActor(inst, data)
	end

	return inst
end

function cineutil.Debug_SpawnLeadActor(prefab)
	local inst = cineutil.Debug_SpawnActor(prefab)

	local is_lead_prefab_missing_cineactor = not inst.components.cineactor
	if is_lead_prefab_missing_cineactor then
		inst:AddComponent("cineactor")
	end
	inst.components.cineactor:RemoveAllEvents()

	return inst, is_lead_prefab_missing_cineactor
end

-- Generate the prefab
function cineutil.MakeAutogenCine(name, params, is_debug)
	local assets =
	{
		Asset("PKGREF", "scripts/prefabs/cine_autogen_data.lua"),
	}

	local function fn()
		local inst = CreateEntity()

		inst.cine = {
			roles = {
			},
		}

		inst.entity:AddTransform()
		inst.Transform:SetTwoFaced()
		-- Give Scene an AnimState since some eventfuncs require one but also
		-- affect the world (lightintensity) and it keeps that code simpler.
		inst.entity:AddAnimState()
		inst.entity:AddSoundEmitter()
		inst:AddTag("dbg_nohistory")
		inst:AddTag("cinematic")

		--[[Non-networked entity]]
		inst.persists = false

		inst:SetStateGraph(name, MakeStateGraph(params))
		inst.sg.sg:WrapAllExitStates()

		inst.SetupCinematic = SetupCinematic
		inst.PlayCinematicNetwork = PlayCinematicNetwork
		inst.SkipCinematic = SkipCinematic
		inst.is_skippable = params.is_skippable
		inst.OnEditorSpawn = function(_inst, editor)
			-- When a cine prefab is spawned directly from a non cine editor,
			-- it won't have a lead actor.
			local DebugNodes = require "dbui.debug_nodes"
			if DebugNodes.CineEditor.is_instance(editor) then
				return
			end
			if params.leadprefab then
				local leadactor = cineutil.Debug_SpawnLeadActor(params.leadprefab)
				local subactors = {}
				if params.subactors then
					for _, subactor in ipairs(params.subactors) do
						local actor = cineutil.Debug_SpawnActor(subactor.prefabname, subactor)
						table.insert(subactors, actor)
					end
				end

				inst._onremove = function(source)
					leadactor:Remove()
					for _, subactor in ipairs(params.subactors) do
						subactor:Remove()
					end
				end
				inst:ListenForEvent("onremove", inst._onremove)

				-- Assign anim to work in embellisher.
				inst.AnimState:SetBank("mouseover")
				inst.AnimState:SetBuild("mouseover")
				inst.AnimState:PlayAnimation("circle")
				inst.AnimState:SetMultColor(0,0,0,0.3) -- nearly invisible

				inst.cine.roles.lead = leadactor
				inst.cine.subactors = subactors
			end
		end

		inst.subactor_data = params.subactors

		return inst
	end

	return Prefab(name, fn, assets, nil, nil, NetworkType_Minimal)
end

return cineutil
