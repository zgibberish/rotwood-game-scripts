local SGCommon = require "stategraphs.sg_common"
local krandom = require "util.krandom"
local EffectEvents = require "effectevents"

local events =
{
}

local sizes =
{
	small =
	{
		scale = 1.05,
		rotation = 360,
		hitbox_size = 1,
		beam_thickness = 0.3,
		bubble_chance = 0.01,
		bubble_dist = 0.7,
		pfx = "acid_motes_sml",
		footstep_aura_sizemod_x = 0.5,
		footstep_aura_sizemod_y = 1,
	},

	medium =
	{
		scale = 1.5,
		rotation = 30,
		hitbox_size = 2.45,
		beam_thickness = 1.4,
		bubble_chance = 0.02,
		bubble_dist = 2,
		pfx = "acid_motes_med",
		footstep_aura_sizemod_x = 0.5,
		footstep_aura_sizemod_y = 0.75,
	},

	large =
	{
		scale = 2,
		rotation = 30,
		hitbox_size = 3.75,
		beam_thickness = 3.45,
		bubble_chance = 0.04,
		bubble_dist = 3.5,
		pfx = "acid_motes_lrg",
		footstep_aura_sizemod_x = 0.4,
		footstep_aura_sizemod_y = 0.4,
	},
}

local function ConfigureTrap(inst, data)
	-- override preset trap data if it came with an event
	if data then
		inst.sg.mem.trapdata = data
	end
	local size = inst.sg.mem.trapdata ~= nil and sizes[inst.sg.mem.trapdata.size] or sizes.large -- Traps which don't have trapdata were spawned by non-mobs. Make large.

	inst:ListenForEvent("room_complete", function()
		local frames = math.random(10) -- Slight variation in timing so not everything happens at the exact same time
		inst:DoTaskInAnimFrames(frames, function(xinst)
			if xinst ~= nil and xinst:IsValid() then
				xinst.sg:GoToState("pst")
			end
		end)
	end, TheWorld)

	inst.sg.mem.lifetimeframes = (inst.sg.mem.trapdata ~= nil and inst.sg.mem.trapdata.temporary) and 300 or nil
	inst.sg.mem.bubble_chance = size.bubble_chance
	inst.sg.mem.bubble_dist = size.bubble_dist

	inst.sg.mem.pfx_name = size.pfx

	local scale = size.scale
	local rotation = math.random(-size.rotation, size.rotation or 0)
	inst.Transform:SetRotation(rotation)
	inst.Transform:SetScale(scale,scale,scale)

	inst.components.auraapplyer:SetEffect("acid")
	inst.components.auraapplyer:SetupBeamHitbox(-size.hitbox_size*size.footstep_aura_sizemod_x, size.hitbox_size*size.footstep_aura_sizemod_x, size.beam_thickness*size.footstep_aura_sizemod_y) -- Footstepper hitbox is a little smaller
end

local function CreateParticles(inst)
	local x,z = inst.Transform:GetWorldXZ()
	local pfx = SpawnPrefab(inst.sg.mem.pfx_name, inst)
	pfx.Transform:SetPosition(x, 0, z)
	inst.sg.mem.pfx = pfx

	-- removal path if the entity is suddenly removed without the stategraph knowing
	-- this is triggered for network use
	local onremove_fn = function(_inst)
		-- TheLog.ch.StateGraph:printf("sg_trap_acid stopping particles")
		if pfx and pfx:IsValid() then
			pfx.components.particlesystem:StopThenRemoveEntity()
		end
	end

	pfx:ListenForEvent("onremove", onremove_fn, inst)
end

local function StopParticles(inst)
	if inst.sg.mem.pfx then
		inst.sg.mem.pfx.components.particlesystem:StopThenRemoveEntity()
		inst.sg.mem.pfx = nil
	end
end

local function SpawnBubble(inst)
	local bubble = SpawnPrefab("fx_battoad_bubbles", inst)
	local dist_mod = math.random() * inst.sg.mem.bubble_dist or 2.2
	local target_pos = inst:GetPosition()
	target_pos.y = 0
	target_pos = target_pos + krandom.Vec3_FlatOffset(dist_mod)
	bubble.Transform:SetPosition(target_pos:unpack())
end

local states =
{
		State({
		name = "init",
		tags = { },

		onenter = function(inst)
			-- When spawned by a mob, trap waits in this state until told otherwise from the mob itself, to give it time to configure the trap
			inst.sg:SetTimeoutTicks(1)
		end,

		ontimeout = function(inst)
			-- TODO: networking2022, find a better way to detect this condition since it can look medium/large briefly for small acid pools
			-- This hasn't been spawned by a mob, so skip straight to the "loop" state, because it was probably spawned by the trap spawner
			-- First, set up some data to use, since it didn't come from a mob:
			ConfigureTrap(inst)
			inst.sg:GoToState("loop")
		end,

		events =
		{
			EventHandler("acid_start", function(inst, data)
				ConfigureTrap(inst, data)
				inst.sg:GoToState("land", data)
			end),
		},
	}),

	State({
		name = "land",
		tags = { },

		onenter = function(inst, data)
			ConfigureTrap(inst, data)

			local splash = EffectEvents.MakeEventSpawnEffect(inst, { fxname = "fx_acid_splash" })
			--local land = EffectEvents.MakeEventSpawnEffect(inst, { fxname = "fx_acid_land" })

			SGCommon.Fns.PlayAnimOnAllLayers(inst, "ground_land", true)
		end,

		onupdate = function(inst)
			if not inst.sg.statemem.attacking then
				return
			end

			if math.random() < (inst.sg.mem.bubble_chance or 0.02) and inst.sg:GetTimeInState() then
				SpawnBubble(inst)
			end
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.sg.statemem.attacking = true
				inst.components.auraapplyer:Enable()
			end),
			--
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("loop")
			end),
		},
	}),

	State({
		name = "loop",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "ground_loop", true)
			if inst.sg.mem.lifetimeframes ~= nil then
				inst.sg:SetTimeoutAnimFrames(inst.sg.mem.lifetimeframes)
			end
			CreateParticles(inst)
			SpawnBubble(inst)
		end,

		onupdate = function(inst)
			if math.random() < (inst.sg.mem.bubble_chance or 0.02) and inst.sg:GetTimeInState() then
				SpawnBubble(inst)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("pst")
		end,
	}),

	State({
		name = "pst",
		tags = { "hit", "busy" },

		onenter = function(inst, data)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "ground_pst")
			StopParticles(inst)
			inst.components.auraapplyer:Disable()
		end,


		onexit = function(inst)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},
	}),
}

return StateGraph("sg_trap_acid", states, events, "init")
