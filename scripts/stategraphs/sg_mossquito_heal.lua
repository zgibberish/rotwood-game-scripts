local easing = require("util/easing")
local SGCommon = require "stategraphs.sg_common"
local ParticleSystemHelper = require "util.particlesystemhelper"

local events =
{
	EventHandler("drop", function(inst, targetpos) inst.sg:GoToState("drop", targetpos) end),
}

local function OnHealHitBoxTriggered(inst, data)
	local disable_hit_reaction = inst.sg.mem.trapdata ~= nil and inst.sg.mem.trapdata.disable_hit_reaction or false

	SGCommon.Events.OnHitboxTriggered(inst, data, {
		hitstoplevel = disable_hit_reaction and 0 or HitStopLevel.HEAVIER,
		set_dir_angle_to_target = true,
		player_damage_mod = 0,
		pushback = 0,
		hitstun_anim_frames = 0,
		--disable_damage_number = true,
		disable_hit_reaction = true,
		disable_self_hitstop = true,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = nil,
		hit_fx_offset_x = 0.5,
		hit_target_pre_fn = function(attacker, v)
			local is_player = v:HasTag("player")
			local heal = TUNING.TRAPS.trap_spores.DAMAGE_VERSION_BASE_DAMAGE
			if is_player then
				heal = heal * TUNING.TRAPS.DAMAGE_TO_PLAYER_MULTIPLIER
			end

			local spore_heal = Attack(attacker, v)
			spore_heal:SetHeal(heal)
			attacker.components.combat:ApplyHeal(spore_heal)

			ParticleSystemHelper.MakeOneShotAtPosition(v:GetPosition(), "mushroom_shrink_burst", nil, inst)
		end,
	})
end

local states =
{
	State({
		name = "idle",
	}),

	State({
		name = "drop",
		tags = { "airborne" },
		onenter = function(inst, targetpos)
			local x, y, z = inst.Transform:GetWorldPosition()
		    local dx = targetpos.x - x
		    local dz = targetpos.z - z
		    local rangesq = dx * dx + dz * dz
		    local maxrange = 15
		    local speed = easing.linear(rangesq, 20, 3, maxrange * maxrange)
		    inst.components.complexprojectile:SetHorizontalSpeed(speed)
		    inst.components.complexprojectile:SetGravity(-40)
		    inst.components.complexprojectile:Launch(targetpos)
		    inst.components.complexprojectile.onhitfn = function() inst.sg:GoToState("land", targetpos) end

			local circle = SpawnPrefab("ground_target", inst)
			circle.Transform:SetPosition( targetpos.x, 0, targetpos.z )
			circle.Transform:SetScale( 1.4, 1.4, 1.4 )

			inst.sg.statemem.landing_pos = circle
		end,

		onexit = function(inst)
			if inst.sg.statemem.landing_pos then
				inst.sg.statemem.landing_pos:Remove()
			end
		end,
	}),

	State({
		name = "land",

		default_data_for_tools = Vector3.zero,

		onenter = function(inst, pos)
			inst.Transform:SetPosition(pos.x, 0, pos.z)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.sg:SetTimeoutAnimFrames(3)

			SGCommon.Fns.SpawnAtDist(inst, "fx_spores_heal_all", 0)
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 2.5, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(1, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 3.5, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(2, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 3.5, HitPriority.MOB_DEFAULT)
			end),
		},

		ontimeout = function(inst)
			inst:Remove()
		end,

		events = {
			EventHandler("hitboxtriggered", OnHealHitBoxTriggered),
		}
	})
}

return StateGraph("sg_mossquito_heal", states, events, "idle")
