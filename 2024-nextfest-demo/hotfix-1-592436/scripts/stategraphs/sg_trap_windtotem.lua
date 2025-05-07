local spawnutil = require "util.spawnutil"
local ParticleSystemHelper = require "util.particlesystemhelper"
local SGCommon = require "stategraphs.sg_common"
local soundutil = require "util.soundutil"
local fmodtable = require "defs.sound.fmodtable"

local function UpdateForegroundFacing(inst)
	local facing = inst.Transform:GetFacing() or FACING_RIGHT
	if facing == FACING_UP then
		local posx, posy, posz = inst.Transform:GetWorldPosition()
		inst.Transform:SetWorldPosition(posx, posy - 1.4, posz)
		inst.AnimState:SetLayer(LAYER_WORLD)
		inst.AnimState:SetIsBGElement(false)
		inst.AnimState:SetIsFGElement(false)
		inst.AnimState:SetSortOrder(0)
	end
end

-- Helper function to change the facing direction.
local function SetFacing(inst, facing)
	spawnutil.SetFacing(inst, facing)

	UpdateForegroundFacing(inst)

	-- Update the anim by re-entering the current state.
	local state = inst.sg.currentstate.name
	inst.sg:GoToState(state)
end

local function PlayFacingAnimation(inst, anim, looping)
	local facing = inst.Transform:GetFacing() or FACING_RIGHT
	local anim_name = nil
	local shoot_spikeballs = inst.shoot_spikeballs and "spikeball_" or ""

	if facing == FACING_UP then
		anim_name = "upfacing_" .. shoot_spikeballs .. anim
	elseif facing == FACING_DOWN then
		anim_name = "downfacing_" .. shoot_spikeballs .. anim
	else -- FACING_RIGHT or FACING_LEFT
		anim_name = "sidefacing_" .. shoot_spikeballs .. anim
	end

	inst.AnimState:PlayAnimation(anim_name, looping)
end

local function StartWindEffect(inst)
	inst.components.auraapplyer:EnableRampUp(true)
	inst.components.auraapplyer:Enable()
	if not inst.sg.mem.wind_lp then
		--sound
		local params = {}
		params.fmodevent = fmodtable.Event.windmon_wind_LP
		inst.sg.mem.wind_lp = soundutil.PlaySoundData(inst, params)
	end

	local fx_params =
	{
		name = "wind_effect",
		particlefxname = "wind_totem_right",
		ischild = true,
		use_entity_facing = true,
		stopatexitstate = true,
	}

	local facing = inst.Transform:GetFacing() or FACING_RIGHT
	if facing == FACING_UP then
		fx_params.name = "wind_effect_up"
		fx_params.particlefxname = "wind_totem_up"
	elseif facing == FACING_DOWN then
		fx_params.name = "wind_effect_down"
		fx_params.particlefxname = "wind_totem_down"
	end

	inst.sg.mem.wind_fx_name = fx_params.name
	ParticleSystemHelper.MakeEventSpawnParticles(inst, fx_params)
end

local function StopWindEffect(inst)
	if inst.sg.mem.wind_lp then
		soundutil.KillSound(inst,inst.sg.mem.wind_lp)
		inst.sg.mem.wind_lp = nil
	end
	inst.components.auraapplyer:EnableRampDown(true)
	inst.components.auraapplyer:Disable()
	local fx_name = inst.sg.mem.wind_fx_name and { name = inst.sg.mem.wind_fx_name } or nil
	ParticleSystemHelper.MakeEventStopParticles(inst, fx_name)
end

local INITIAL_START_TIME_STEPS = 5
local INITIAL_START_TIME_RANGE = 5
local COOLDOWN_TIME = 6
local PRE_TIME = 1.5
local ACTIVE_TIME = 2
local ACTIVE_TIME_SPIKEBALL = 4

local SPIKEBALL_SPAWN_POS_Y = 5.5
local SPAWN_SPIKEBALL_INTERVAL = 0.7

local MAX_SPIKE_BALLS = 30
local SPAWN_DISTANCE = 5
local SPAWN_ANGLE_VARIANCE = 30

local function OnRoomComplete(inst)
	inst.sg.mem.is_room_clear = true
	if inst.sg.mem.wind_lp then
		soundutil.KillSound(inst, inst.sg.mem.wind_lp)
		inst.sg.mem.wind_lp = nil
	end
end

local events =
{
}

local states =
{
	State({
		name = "init",

		onenter = function(inst)
			inst.SetFacing = SetFacing -- Facing is set in spawner_trap's SpawnTrap function, or externally calling inst.SetFacing.
			inst.Transform:SetFourFaced()

			-- Add bloom to glows.
			local r, g, b = HexToRGBFloats(StrToHex("B862EFFF"))
			local intensity = 0.75
			inst.AnimState:SetLayerBloom("glow", r, g, b, intensity)

			inst:ListenForEvent("room_complete", function() OnRoomComplete(inst) end, TheWorld)

			-- If facing up, it's in the foreground & thus need to adjust its layering
			-- Delay until the next update to update its layering is set to the foreground.
			inst:DoTaskInTime(0, function()
				UpdateForegroundFacing(inst)
			end)

			-- Delay for a tick to allow its facing to be set on spawn. See spawner_trap's SpawnTrap() function.
			inst:DoTaskInTime(0, function()
				inst.sg:GoToState("idle")
			end)
		end,
	}),

	State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			PlayFacingAnimation(inst, "idle", true)

			-- Give some random initial delay so that all windblowers don't blow at the same time.
			local delay = COOLDOWN_TIME
			if not inst.sg.mem.has_started then
				delay = SteppedRandomRange(INITIAL_START_TIME_STEPS, INITIAL_START_TIME_RANGE)
			end
			inst.sg:SetTimeout(delay)

			inst.components.hitbox:SetHitFlags(HitGroup.ALL)
		end,

		ontimeout = function(inst)
			if not inst.sg.mem.is_room_clear then
				inst.sg.mem.has_started = true
				inst.sg:GoToState("pre")
			end
		end,
	}),

	State({
		name = "pre",
		tags = { "busy" },

		onenter = function(inst)
			PlayFacingAnimation(inst, "pre", true)
			inst.sg:SetTimeout(PRE_TIME)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("active")
		end,
	}),

	State({
		name = "active",
		tags = { "busy" },

		onenter = function(inst)
			PlayFacingAnimation(inst, "active", true)

			StartWindEffect(inst)
			local timeout = inst.shoot_spikeballs and ACTIVE_TIME_SPIKEBALL or ACTIVE_TIME
			inst.sg:SetTimeout(timeout)

			if inst.shoot_spikeballs then
				inst.sg.statemem.shoot_spikeballs_task = inst:DoPeriodicTask(SPAWN_SPIKEBALL_INTERVAL, function()
					-- Don't spawn additional spikeballs if there's already too many on the map.
					local spikeballs = TheSim:FindEntitiesXZ(0, 0, 1000, { "spikeball" })
					local num_spikeballs_on_map = spikeballs and #spikeballs or 0

					if num_spikeballs_on_map < MAX_SPIKE_BALLS then
						local spikeball = SGCommon.Fns.SpawnAtDist(inst, "owlitzer_spikeball", 0)
						if spikeball then
							-- Spawn spikeballs from the top of the totem:
							local pos = inst:GetPosition()
							spikeball.Transform:SetPosition(pos.x, SPIKEBALL_SPAWN_POS_Y, pos.z)

							local angle = math.rad(inst.Transform:GetFacingRotation() + math.random(-SPAWN_ANGLE_VARIANCE, SPAWN_ANGLE_VARIANCE))
							local target_pos = pos + Vector3(math.cos(angle), 0, -math.sin(angle)) * SPAWN_DISTANCE
							spikeball.sg:GoToState("thrown", target_pos)

							-- Spawn FX
							local fx_params =
							{
								name = "spikeball_burst",
								followsymbol = "fx_attach",
								particlefxname = "wind_totem_spikeball_burst",
								ischild = true,
								use_entity_facing = true,
								stopatexitstate = true,
							}
							ParticleSystemHelper.MakeEventSpawnParticles(inst, fx_params)
							inst:DoTaskInTime(SPAWN_SPIKEBALL_INTERVAL - 0.1, function()
								ParticleSystemHelper.MakeEventStopParticles(inst, { name = "spikeball_burst" })
							end)
						end
					end
				end)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("idle")
		end,

		onexit = function(inst)
			StopWindEffect(inst)
			if inst.sg.statemem.shoot_spikeballs_task then
				inst.sg.statemem.shoot_spikeballs_task:Cancel()
			end
		end,
	}),
}

return StateGraph("sg_trap_windtotem", states, events, "init")
