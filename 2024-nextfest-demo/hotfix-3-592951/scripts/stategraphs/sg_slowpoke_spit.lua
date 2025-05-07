local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local easing = require("util/easing")
local monsterutil = require "util.monsterutil"
local fmodtable = require "defs.sound.fmodtable"

local events =
{
	EventHandler("spit", function(inst, targetpos) inst.sg:GoToState("spit", targetpos) end),
	EventHandler("slam_spit", function(inst, targetpos) inst.sg:GoToState("slam_spit", targetpos) end),
}

local function OnHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "mortar",
		hitstoplevel = HitStopLevel.MEDIUM,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		pushback = 1.25,
		set_dir_angle_to_target = true,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local states =
{
	State({
		name = "idle",
	}),

	State({
		name = "spit",
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
		name = "slam_spit",
		tags = { "airborne" },
		onenter = function(inst, targetpos)
			local x, y, z = inst.Transform:GetWorldPosition()
		    local dx = targetpos.x - x
		    local dz = targetpos.z - z
		    local rangesq = dx * dx + dz * dz
		    local maxrange = 5
		    local speed = easing.linear(rangesq, 10, 3, maxrange * maxrange)
		    inst.components.complexprojectile:SetHorizontalSpeed(speed)
		    inst.components.complexprojectile:SetGravity(-40)
		    inst.components.complexprojectile:Launch(targetpos)
		    inst.components.complexprojectile.onhitfn = function() inst.sg:GoToState("land", targetpos) end
		end,
	}),

	State({
		name = "land",

		onenter = function(inst, pos)
			inst:Hide()
			inst.Transform:SetPosition(pos.x, 0, pos.z)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.sg:SetTimeoutAnimFrames(3)

			-- spawn hurt zone here

			local aoe = SGCommon.Fns.SpawnAtDist(inst, "trap_acid", 0) -- This trap sits in the "init" state until we have told it to proceed. We need to tell it what its transform size + hitbox sizes should be first.
			aoe.Transform:SetPosition(pos.x, 0, pos.z)
			local trapdata =
			{
				size = "medium",
				temporary = true,
			}
			EffectEvents.MakeNetEventPushEventOnMinimalEntity(aoe, "acid_start", trapdata)

			local splat_fx = SpawnPrefab("fx_battoad_projectile_land", inst)
			splat_fx:SetupDeathFxFor(inst)

			local splat_ground_fx = SpawnPrefab("fx_battoad_projectile_land_ground", inst)
			splat_ground_fx:SetupDeathFxFor(inst)
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.components.hitbox:PushCircle(0, 0, 1, HitPriority.MOB_DEFAULT) end),
			FrameEvent(1, function(inst) inst.components.hitbox:PushCircle(0, 0, 2, HitPriority.MOB_DEFAULT) end),
			FrameEvent(2, function(inst) inst.components.hitbox:PushCircle(0, 0, 2.25, HitPriority.MOB_DEFAULT) end),
		},

		ontimeout = function(inst)
			inst:Remove()
		end,

		events = {
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
		}
	})
}

return StateGraph("sg_slowpoke_spit", states, events, "idle")