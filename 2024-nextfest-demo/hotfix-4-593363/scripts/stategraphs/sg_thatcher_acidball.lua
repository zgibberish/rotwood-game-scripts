local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local easing = require("util/easing")
local monsterutil = require "util.monsterutil"
local fmodtable = require "defs.sound.fmodtable"

local events =
{
}

local function OnHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "acid_spit",
		hitstoplevel = HitStopLevel.MEDIUM,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		pushback = 1.25,
		set_dir_angle_to_target = true,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local ACID_TARGET_FX_SIZES =
{
	small = 0.9,
	medium = 1.4,
	large = 1.9,
}

local states =
{
	State({
		name = "idle",
	}),

	State({
		name = "ball",
		tags = { "airborne" },
		onenter = function(inst, data)
			local x, y, z = inst.Transform:GetWorldPosition()
			local targetpos = data and data.targetpos or Vector3.zero
		    local dx = targetpos.x - x
		    local dz = targetpos.z - z
		    local rangesq = dx * dx + dz * dz
		    local maxrange = 15
		    local speed = easing.linear(rangesq, 20, 3, maxrange * maxrange)
		    inst.components.complexprojectile:SetHorizontalSpeed(speed)
		    inst.components.complexprojectile:SetGravity(-40)
		    inst.components.complexprojectile:Launch(targetpos)
		    inst.components.complexprojectile.onhitfn = function() inst.sg:GoToState("land", { pos = targetpos, size = data and data.size or "normal" }) end

			local circle = SpawnPrefab("ground_target", inst)
			circle.Transform:SetPosition( targetpos.x, 0, targetpos.z )

			local scale = data and ACID_TARGET_FX_SIZES[data.size] or 1
			circle.Transform:SetScale( scale, scale, scale )
			circle.warning_sound = fmodtable.Event.slowpoke_spit_bomb_warning
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

		onenter = function(inst, data)
			inst:Hide()

			local pos = data and data.pos or Vector3.zero
			inst.Transform:SetPosition(pos.x, 0, pos.z)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.sg:SetTimeoutAnimFrames(3)

			-- spawn hurt zone here

			local aoe = SGCommon.Fns.SpawnAtDist(inst, "trap_acid", 0) -- This trap sits in the "init" state until we have told it to proceed. We need to tell it what its transform size + hitbox sizes should be first.
			if not aoe then return end

			aoe.Transform:SetPosition(pos.x, 0, pos.z)
			local trapdata =
			{
				size = data and data.size or "medium",
				temporary = true,
			}
			EffectEvents.MakeNetEventPushEventOnMinimalEntity(aoe, "acid_start", trapdata)

			local splat_fx = SpawnPrefab("fx_battoad_projectile_land", inst)
			splat_fx:SetupDeathFxFor(inst)

			local splat_ground_fx = SpawnPrefab("fx_battoad_projectile_land_ground", inst)
			splat_ground_fx:SetupDeathFxFor(inst)

			inst.sg.statemem.size_mod = data and data.size == "large" and 1.3 or 1
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.components.hitbox:PushCircle(0, 0, 1 * inst.sg.statemem.size_mod, HitPriority.MOB_DEFAULT) end),
			FrameEvent(1, function(inst) inst.components.hitbox:PushCircle(0, 0, 2 * inst.sg.statemem.size_mod, HitPriority.MOB_DEFAULT) end),
			FrameEvent(2, function(inst) inst.components.hitbox:PushCircle(0, 0, 2.25 * inst.sg.statemem.size_mod, HitPriority.MOB_DEFAULT) end),
		},

		ontimeout = function(inst)
			inst:Remove()
		end,

		events = {
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
		}
	})
}

return StateGraph("sg_thatcher_acidball", states, events, "idle")