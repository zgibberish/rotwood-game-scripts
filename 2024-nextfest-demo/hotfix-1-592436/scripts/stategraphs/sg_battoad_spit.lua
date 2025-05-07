local easing = require("util/easing")
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"

local events =
{
	EventHandler("spit", function(inst, targetpos) inst.sg:GoToState("spit", targetpos) end),
}

local function OnHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "spit",
		hitstoplevel = HitStopLevel.MEDIUM,
		hitflags = Attack.HitFlags.LOW_ATTACK,
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

		onenter = function(inst, pos)
			inst:Hide()
			inst.Transform:SetPosition(pos.x, 0, pos.z)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.sg:SetTimeoutAnimFrames(3)

			-- spawn hurt zone here

			local aoe_obj = SpawnPrefab("battoad_aoe", inst)
			aoe_obj.Transform:SetPosition(pos.x, 0, pos.z)
			aoe_obj:Setup(inst.owner)

			local splat_fx = SpawnPrefab("fx_battoad_projectile_land", inst)
			splat_fx:SetupDeathFxFor(inst)

			local splat_ground_fx = SpawnPrefab("fx_battoad_projectile_land_ground", inst)
			splat_ground_fx:SetupDeathFxFor(inst)
		end,

		timeline =
		{
			FrameEvent(0, function(inst) inst.components.hitbox:PushCircle(0, 0, 3, HitPriority.MOB_DEFAULT) end),
			FrameEvent(1, function(inst) inst.components.hitbox:PushCircle(0, 0, 3, HitPriority.MOB_DEFAULT) end),
			FrameEvent(2, function(inst) inst.components.hitbox:PushCircle(0, 0, 3, HitPriority.MOB_DEFAULT) end),
		},

		ontimeout = function(inst)
			inst:Remove()
		end,

		events = {
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
		}
	})
}

return StateGraph("sg_battoad_spit", states, events, "idle")
