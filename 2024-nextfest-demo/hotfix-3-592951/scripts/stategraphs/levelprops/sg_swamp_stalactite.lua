local SGCommon = require("stategraphs/sg_common")
local monsterutil = require "util.monsterutil"
local ParticleSystemHelper = require "util.particlesystemhelper"
local EffectEvents = require "effectevents"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local DebugDraw = require "util.debugdraw"

local function OnEmbellisherLoad(inst)
	local pos = inst:GetPosition()
	inst.Transform:SetPosition(pos.x, 0, pos.z)
end

local events =
{
	EventHandler("dying", function(inst, data)
		inst.sg:GoToState("death", data)
	end),
	EventHandler("attacked", function(inst, data)
		if inst.sg:HasStateTag("death") then
			return
		end

		SGCommon.Fns.OnAttacked(inst, data)

		if not inst:IsValid() or inst:IsDead() then
			inst.sg:GoToState("death", data)
		else
			inst.sg:GoToState("hit", data)
		end
	end),
}

local FALL_HEIGHT = 10
--[[local FX_OFFSETS =
{
	{ x = 0, z = 0 },
	{ x = -2, z =  0.5 },
	{ x = 2, z = 0.5 },
	{ x = -1, z = -2 },
	{ x = 1, z = -2 },
	{ x = 0, z = 2 },
}]]

local PEEKABOOM_ATTACK_LENGTH_TICKS = 200
local PEEKABOOM_SHOCKWAVE_RADIUS_PER_TICK = 0.2
local PEEKABOOM_SHOCKWAVE_PFX_EMITMULT_PER_TICK = 0.02

local function RemoveLandFX(inst)
	if inst == nil then return end

	--[[if inst.sg.mem.fx_list then
		for i, fx in ipairs(inst.sg.mem.fx_list) do
			if fx:IsValid() then
				fx:Remove()
			end
		end
	end]]
	if inst.sg.mem.land_fx and inst.sg.mem.land_fx:IsValid() then
		inst.sg.mem.land_fx:Remove()
	end
end

local function OnFallingHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = HitStopLevel.MEDIUM,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		set_dir_angle_to_target = true,
		hit_target_pst_fn = function(attacker, v)
			if v:HasTag("clone") and inst.sg.statemem.kill_clone then
				v.components.health:Kill()
			end
		end,
	})
end

local function OnShockWaveHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = HitStopLevel.HEAVY,
		hitflags = Attack.HitFlags.GROUND,
		hitstun_anim_frames = 15,
		disable_self_hitstop = true,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		set_dir_angle_to_target = true,
		custom_attack_fn = function(attacker, attack)
			local hit = false

			local radius_distance = inst.sg.mem.ticks_expanding * PEEKABOOM_SHOCKWAVE_RADIUS_PER_TICK -- How big has the radius grown?
			radius_distance = radius_distance * radius_distance -- To compare with distsq
			local threshold = 0.9 -- Because this is a circle hitbox, but we want only a thin ring: only the outer 'threshold' % of the circle will actually hit.

			local distance_to_target = attacker:GetDistanceSqTo(attack:GetTarget()) -- How far is this entity from the stalactite?

			-- print("radius_distance", radius_distance, "threshold", threshold, "distance_to_target", distance_to_target)
			if distance_to_target >= radius_distance * threshold then
				hit = attacker.components.combat:DoKnockdownAttack(attack)
			end

			return hit
		end,
	})
end



local function IsLowHealth(inst)
	return inst.components.health:GetPercent() < 0.5
end

local function CreateShockWaveFX(inst)
	local shockwave_param =
	{
		particlefxname = "bandicoot_ring_test",
	}
	local ring_params =
	{
		fxname = "fx_bandicoot_groundring_solid",
	}
	inst.sg.mem.shockwave_ring = EffectEvents.MakeEventSpawnEffect(inst, ring_params)
	inst.sg.mem.shockwave_particles = ParticleSystemHelper.MakeEventSpawnParticles(inst, shockwave_param)

	inst.sg.mem.shockwave_x = 0
	inst.sg.mem.shockwave_y = 0
	inst.sg.mem.shockwave_emitter = inst.sg.mem.shockwave_particles.components.particlesystem:GetEmitter(1)
end

local function UpdateShockWave(inst)
	if inst.sg.mem.shockwave_ring then
		local radius = inst.sg.mem.ticks_expanding * PEEKABOOM_SHOCKWAVE_RADIUS_PER_TICK

		local x = inst.sg.mem.shockwave_x
		local y = inst.sg.mem.shockwave_y

		local x1, x2 = x - radius, x + radius
		local y1, y2 = y - radius, y + radius

		--SetEmitterBounds(x,y,w,h)
		inst.sg.mem.shockwave_emitter.inst.ParticleEmitter:SetSpawnAABB(x1, x2, y1, y2)

		local emitmult = 1 + (inst.sg.mem.ticks_expanding * PEEKABOOM_SHOCKWAVE_PFX_EMITMULT_PER_TICK)
		inst.sg.mem.shockwave_emitter:SetEmitRateMult(emitmult)

		inst.sg.mem.shockwave_ring.AnimState:SetScale(radius * 0.56, radius * 0.56) -- Scaled 56% to match the attack hitbox
		inst.components.hitbox:PushCircle(0, 0, radius, HitPriority.BOSS_DEFAULT)
		inst.sg.mem.ticks_expanding = inst.sg.mem.ticks_expanding + 1

		if inst.sg.mem.ticks_expanding >= PEEKABOOM_ATTACK_LENGTH_TICKS then
			inst.sg.mem.shockwave_particles.components.particlesystem:StopThenRemoveEntity()
			inst:Remove()
		end
	end
end

local FALL_DELAY = 1
local HEIGHT_DAMAGE_THRESHOLD = 2
local IDLE_TO_HIDDEN_TIMEOUT = 2.5

local states =
{
	State({
		name = "local_init",
		onenter = function(inst, prefab_to_spawn)
			EffectEvents.MakeEventSpawnLocalEntity(inst, prefab_to_spawn or "idle", "")
			inst:DelayedRemove()
		end,
	}),

	State({
		name = "bandicoot_intro",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "intro_1")

			-- Need to cancel all tasks & setup that the default fall_pre statedoes
			inst:CancelAllTasks()

			-- Disable physics so that it doesn't push away Bandicoot during its intro anim.
			inst.Physics:SetEnabled(false)

			-- Need to manually turn on shadows, since by default it's turned off in its prefab init function.
			inst.AnimState:SetShadowEnabled(true)
		end,

		events =
		{
			EventHandler("cine_skipped", function(inst)
				inst.sg:GoToState("idle")
			end),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		on_exit = function(inst)
			inst.Physics:SetEnabled(true)
		end,
	}),

    State({
		name = "idle",
		tags = { "idle" },

		onenter = function(inst)
			local anim = IsLowHealth(inst) and "broken_1" or "1"
			SGCommon.Fns.PlayAnimOnAllLayers(inst, anim, true)
		end,

		events =
		{
			EventHandler("flash", function(inst)
				inst.sg:GoToState("flash")
			end),
		},
	}),

	State({
		name = "flash",
		tags = { "idle" },

		onenter = function(inst)
			local anim = IsLowHealth(inst) and "broken_hidden_1" or "hidden_1"
			SGCommon.Fns.PlayAnimOnAllLayers(inst, anim, true)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "fall_pre",

		default_data_for_tools = OnEmbellisherLoad,

		onenter = function(inst)
			inst.components.fallingobject:SetOnLand(RemoveLandFX)

			inst:DoTaskInTime(0, function(inst)
				-- Set to fall from above
				inst.components.fallingobject:SetLaunchHeight(FALL_HEIGHT)
				inst.components.fallingobject:SetGravity(-80)

				-- Spawn ground target (temp? replace with a single shadow FX?)
				local x, y, z = inst.Transform:GetWorldPosition()
				--[[inst.sg.mem.fx_list = {}
				for i, offset in ipairs(FX_OFFSETS) do
					local targetpos = Vector3(x + offset.x, 0, z + offset.z)
					local fx = SpawnPrefab("fx_ground_target_red_local", inst)
					fx.Transform:SetPosition( targetpos.x, 0, targetpos.z )

					table.insert(inst.sg.mem.fx_list, fx)
				end]]
				local land_fx = SpawnPrefab("fx_ground_target_red_local", inst)
				land_fx.AnimState:SetScale(3.2, 3.2, 3.2)
				land_fx.Transform:SetPosition( x, 0, z )
				inst.sg.mem.land_fx = land_fx
			end)

			inst:Hide()
			inst.Physics:SetEnabled(false)
			inst.sg:SetTimeout(FALL_DELAY)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("fall")
		end,

		onexit = function(inst)
			inst:Show()
			inst.Physics:SetEnabled(true)
		end,
	}),

    State({
		name = "fall",
		tags = { "falling" },

		default_data_for_tools = OnEmbellisherLoad,

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "fall_1", true)
			inst.HitBox:SetInvincible(true)
            inst.Physics:SetEnabled(false)

            inst.components.fallingobject:Launch()

            inst.components.hitbox:StartRepeatTargetDelay()
		end,

        events =
		{
            EventHandler("hitboxtriggered", OnFallingHitBoxTriggered),
			EventHandler("landed", function(inst)
				inst.sg:GoToState("land")
			end),
		},

        onupdate = function(inst)
			local pos = inst:GetPosition()
			if pos.y <= HEIGHT_DAMAGE_THRESHOLD and inst.sg:HasStateTag("falling") then
				inst.components.hitbox:PushCircle(0.00, 0.00, 1.20, HitPriority.MOB_PROJECTILE)
			end
        end,

        onexit = function(inst)
			inst.HitBox:SetInvincible(false)
            inst.Physics:SetEnabled(true)
        end,
	}),

    State({
		name = "land",
		tags = { "idle" },

		onenter = function(inst)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "impact_1", true)

			inst.AnimState:SetShadowEnabled(true)

			-- Shake the camera for everyone on landing.
			ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.5, 0.02, 0.5)
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 3.20, HitPriority.MOB_PROJECTILE)
			end),
			FrameEvent(1, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 3.20, HitPriority.MOB_PROJECTILE)
			end),
		},

        events =
		{
			EventHandler("hitboxtriggered", OnFallingHitBoxTriggered),
			EventHandler("animover", function(inst)
				-- In networked multiplayer, after landing, remove stalactites & make the host spawn a stalagmite to replace it.
				if TheNet:IsHost() then
					SGCommon.Fns.SpawnAtDist(inst, "swamp_stalagmite", 0)
					if inst.owner then
						inst.owner:PushEvent("stalactite_landed", inst)
					end
				end

				inst:DelayedRemove()
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end
	}),

	State({
        name = "hit",
        tags = { "hit", "busy" },

		default_data_for_tools = { front = true },

        onenter = function(inst, data)
			local anim = nil
			if IsLowHealth(inst) then
				anim = data.front and "broken_hit_r_1" or "broken_hit_l_1"
				inst:SpawnHitRubble(data.front)
			else
				anim = data.front and "hit_r_1" or "hit_l_1"
				inst:SpawnHitRubble(data.front)
			end
            SGCommon.Fns.PlayAnimOnAllLayers(inst, anim, true)
        end,

        events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
    }),

	State({
        name = "death",
        tags = { "busy", "death" },

        onenter = function(inst, data)
			RemoveLandFX(inst) -- in case we directly enter this before landing.
            SGCommon.Fns.PlayAnimOnAllLayers(inst, "shatter_fx_1", true)
            inst.Physics:SetEnabled(false)
			inst.HitBox:SetEnabled(false)
			inst:PushEvent("hit", data)
			inst:PushEvent("done_dying")
        end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		}
    }),

	State({
		name = "peekaboom_impact",
		tags = { "busy" },

		onenter = function(inst, data)
			SGCommon.Fns.PlayAnimOnAllLayers(inst, "peek_a_boom_impact_1")
			ShakeAllCameras(CAMERASHAKE.VERTICAL, 1.5, 0.02, 1)
			inst.Physics:SetEnabled(false)
			inst.HitBox:SetEnabled(false)

			inst.components.hitbox:StartRepeatTargetDelay()
			inst.sg.statemem.kill_clone = true
		end,

		onupdate = function(inst)
			if inst.sg.statemem.attack == "shockwave" then
				UpdateShockWave(inst)
			end
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				inst.sg.statemem.attack = "fall"
				inst.components.hitbox:PushCircle(0, 0, 1.2, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(1, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 2.20, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(2, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 3.20, HitPriority.BOSS_DEFAULT)
				inst.components.hitbox:StopRepeatTargetDelay() -- Fall attack complete, start shockwave.
			end),

			FrameEvent(3, function(inst)
				inst.sg.statemem.attack = "shockwave"
				inst.sg.mem.ticks_expanding = 0
				inst.sg.statemem.kill_clone = false -- Shockwave doesn't kill clone automatically, only the fall.

				CreateShockWaveFX(inst)

				inst.components.hitbox:StartRepeatTargetDelay() -- Shockwave started, different target set.
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("peekaboom_shockwave")
			end),

			EventHandler("hitboxtriggered", OnFallingHitBoxTriggered),
		},
	}),

	State({
		name = "peekaboom_shockwave",
		tags = { "busy" },

		onenter = function(inst)
			RemoveLandFX(inst)
		end,

		-- StartRepeatTargetDelay() holding over from previous state
		onupdate = function(inst)
			UpdateShockWave(inst)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnShockWaveHitBoxTriggered),
			EventHandler("onremove", function(inst)
				if inst.sg.mem.shockwave_particles and inst.sg.mem.shockwave_particles.components.particlesystem then
					inst.sg.mem.shockwave_particles.components.particlesystem:StopThenRemoveEntity()
				end
			end),
		},
	}),
}

return StateGraph("sg_swamp_stalactite", states, events, "idle")
