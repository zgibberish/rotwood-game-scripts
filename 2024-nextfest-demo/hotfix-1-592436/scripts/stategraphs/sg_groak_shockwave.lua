local SGCommon = require("stategraphs/sg_common")
local monsterutil = require "util.monsterutil"
local ParticleSystemHelper = require "util.particlesystemhelper"

local SHOCKWAVE_RADIUS_PER_TICK = 0.2
local SHOCKWAVE_PFX_EMITMULT_PER_TICK = 0.02

local function OnShockWaveHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		damage_mod = 0.5,
		attackdata_id = "groundpound",
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

			local radius_distance = inst.sg.mem.ticks_expanding * SHOCKWAVE_RADIUS_PER_TICK -- How big has the radius grown?
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

local states =
{
	State({
		name = "expand",
		tags = { "attack" },
		onenter = function(inst)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.sg:SetTimeout(1.5)

			local shockwave_param =
			{
				particlefxname = "bandicoot_ring_test",
			}
			inst.sg.mem.shockwave_particles = ParticleSystemHelper.MakeEventSpawnParticles(inst, shockwave_param)
			inst.sg.mem.shockwave_emitter = inst.sg.mem.shockwave_particles.components.particlesystem:GetEmitter(1)
			inst.sg.mem.ticks_expanding = 0
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

		onupdate = function(inst)
			local radius = inst.sg.mem.ticks_expanding * SHOCKWAVE_RADIUS_PER_TICK

			local x = inst:GetPosition().x
			local y = inst:GetPosition().z

			local x1, x2 = x - radius, x + radius
			local y1, y2 = y - radius, y + radius

			--SetEmitterBounds(x,y,w,h)
			inst.sg.mem.shockwave_emitter.inst.ParticleEmitter:SetSpawnAABB(x1, x2, y1, y2)

			local emitmult = 1 + (inst.sg.mem.ticks_expanding * SHOCKWAVE_PFX_EMITMULT_PER_TICK)
			inst.sg.mem.shockwave_emitter:SetEmitRateMult(emitmult)

			--DebugDraw.GroundCircle(inst.sg.mem.x, inst.sg.mem.z, radius, WEBCOLORS.RED, 20) --(x, z, radius, color, thickness, lifetime)

			inst.AnimState:SetScale(radius * 0.56, radius * 0.56) -- Scaled 56% to match the attack hitbox
			inst.components.hitbox:PushCircle(0, 0, radius, HitPriority.BOSS_DEFAULT)
			inst.sg.mem.ticks_expanding = inst.sg.mem.ticks_expanding + 1
		end,

		ontimeout = function(inst)
			inst:Remove()
		end,
	}),
}

return StateGraph("sg_groak_shockwave", states, nil, "expand")
