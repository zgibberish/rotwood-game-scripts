local easing = require("util/easing")
local EffectEvents = require "effectevents"
local krandom = require "util.krandom"
local fmodtable = require "defs.sound.fmodtable"
local SGCommon = require "stategraphs.sg_common"
local soundutil = require "util.soundutil"

local events =
{
	EventHandler("thrown", function(inst, targetpos) inst.sg:GoToState("thrown", targetpos) end),
}

-- We randomly scale each mortar's expolosion to create offsets/visual variation. What's the min/max?
local EXPLOSION_RANDOM_SCALE_MIN = 0.7
local EXPLOSION_RANDOM_SCALE_MAX = 1.3
local HIT_TRAIL_LIFETIME_SECONDS = 2.5 --seconds

local function CreateHitTrail(target, effectName, attachSymbol)
	local pfx = SpawnPrefab(effectName, target)
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
	timer:StartTimer("hitexpiry", HIT_TRAIL_LIFETIME_SECONDS)
end

local function OnExplodeHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		damage_mod = inst.damage_mod,
		pushback = inst.pushback,
		hitstun_anim_frames = inst.hitstun_animframes,
		hitstoplevel = HitStopLevel.HEAVIER,
		set_dir_angle_to_target = true,
		player_damage_mod = TUNING.TRAPS.DAMAGE_TO_PLAYER_MULTIPLIER,
		combat_attack_fn = "DoKnockdownAttack",
		spawn_hit_fx_fn = function(attacker, target, attack, xdata)
			attacker.components.combat:SpawnHitFxForPlayerAttack(attack, "hits_player_cannon_mortar", target, inst,
				xdata.hit_fx_offset_x, xdata.hit_fx_offset_y, attack:GetDir(), xdata.hitstoplevel)
		end,
		focus_attack = inst.focus or false,
		hit_fx_offset_x = 0,
		hit_fx_offset_y = 1.5,
		attack_id = inst.attacktype,
		disable_self_hitstop = true,
	})
end

local states =
{
	State({
		name = "idle",
	}),

	State({
		name = "thrown",
		tags = { "airborne" },
		onenter = function(inst, targetpos)
			local anim = inst.focus and "mortar_focus" or "mortar"
			inst.AnimState:PlayAnimation(anim, true)

			-- Set up the complex projectile function, and get it flying.
			local x, y, z = inst.Transform:GetWorldPosition()
		    local dx = targetpos.x - x
		    local dz = targetpos.z - z
		    local rangesq = dx * dx + dz * dz
		    local maxrange = 20
		    local speed = easing.linear(rangesq, 20, 3, maxrange * maxrange)
		    inst.components.complexprojectile:SetHorizontalSpeed(speed)
		    inst.components.complexprojectile:SetGravity(-40)
		    inst.components.complexprojectile:Launch(targetpos)
		    inst.components.complexprojectile.onhitfn = function() -- When it lands, go to "explode"
				inst.sg:GoToState("explode", targetpos)
			end

			-- Leave an indicator for where the shot is going to land
			local circle = SpawnPrefab("fx_ground_target_purple", inst)
			circle.Transform:SetPosition( targetpos.x, 0, targetpos.z )
			inst.sg.statemem.landing_pos = circle
		end,

		onexit = function(inst)
			if inst.sg.statemem.landing_pos then
				inst.sg.statemem.landing_pos:Remove()
			end
		end,
	}),

	State({
		name = "explode",
		onenter = function(inst, pos)
			-- Hide it under the explosion FX
			inst:Hide()

			if inst.focus then
				soundutil.PlaySoundWithParams(inst, fmodtable.Event.Cannon_mortar_explode_focus_scatterer,
					{ cannonAmmo = inst.owner.sg.mem.fmodammo })
			else
				soundutil.PlaySoundWithParams(inst, fmodtable.Event.Cannon_mortar_explode_scatterer,
					{ cannonAmmo = inst.owner.sg.mem.fmodammo })
			end

			local explo_scale = krandom.Float(EXPLOSION_RANDOM_SCALE_MIN, EXPLOSION_RANDOM_SCALE_MAX)
			local scorch_scale = 0.75 + krandom.Float(0.3)
			local scorch_rot = math.round(krandom.Float(1) * 360)
			local scorch_fade_scale = krandom.Float(0.5, 1.25)
			EffectEvents.MakeNetEventScorchMark(inst, inst.focus, explo_scale, scorch_scale, scorch_rot, scorch_fade_scale)

			inst.sg.statemem.hitboxradius = inst.hitboxradius or 1.5
		end,

		timeline = {
			FrameEvent(0, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushCircle(0, 0, inst.sg.statemem.hitboxradius, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(1, function(inst) inst.components.hitbox:PushCircle(0, 0, inst.sg.statemem.hitboxradius, HitPriority.MOB_DEFAULT) end),
			FrameEvent(2, function(inst) inst:Remove() end),
		},

		events = {
			EventHandler("hitboxtriggered", OnExplodeHitBoxTriggered),
		}
	})
}

return StateGraph("sg_player_cannon_mortar_projectile", states, events, "idle")
