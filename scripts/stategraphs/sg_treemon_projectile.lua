local easing = require("util/easing")
local SGCommon = require("stategraphs/sg_common")
local monsterutil = require "util.monsterutil"
local fmodtable = require "defs.sound.fmodtable"

local events =
{
	EventHandler("thrown", function(inst, targetpos) inst.sg:GoToState("thrown", targetpos) end),
}

local function OnHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "shoot",
		hitstoplevel = HitStopLevel.LIGHT,
		set_dir_angle_to_target = true,
		pushback = 0.5,
		combat_attack_fn = "DoKnockbackAttack",
		hitflags = Attack.HitFlags.GROUND,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = -5,
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
			local offset_size = 5.0
			local x_offset = math.random() * offset_size
			local z_offset = math.random() * offset_size
			targetpos.x = targetpos.x + (-(offset_size / 2) + x_offset)
			targetpos.z = targetpos.z + (-(offset_size / 2) + z_offset)
			inst.AnimState:PlayAnimation("spin", true)
			local x, y, z = inst.Transform:GetWorldPosition()
			local dx = targetpos.x - x
			local dz = targetpos.z - z
			local rangesq = dx * dx + dz * dz
			local maxrange = 20
			local speed = easing.linear(rangesq, 20, 10, maxrange * maxrange)
			inst.components.complexprojectile:SetHorizontalSpeed(speed)
			inst.components.complexprojectile:SetGravity(-40)
			inst.components.complexprojectile:Launch(targetpos)
			inst.components.complexprojectile.onhitfn = function()
				inst.sg:GoToState("land", targetpos)
			end

			local circle = SpawnPrefab("ground_target", inst)
			circle.Transform:SetPosition(targetpos.x, 0, targetpos.z)
			circle.warning_sound = fmodtable.Event.treemon_projectile_warning

			inst.components.hitbox:StartRepeatTargetDelay()

			inst.sg.statemem.landing_pos = circle
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
		},

		onupdate = function(inst)
			local x, y, z = inst.Transform:GetWorldPosition()
			if y <= 1 then
				inst.components.hitbox:PushCircle(0, 0, 0.5, HitPriority.MOB_DEFAULT)
			end
		end,

		onexit = function(inst)
			if inst.sg.statemem.landing_pos then
				inst.sg.statemem.landing_pos:Remove()
				inst.components.hitbox:StopRepeatTargetDelay()
			end
		end,
	}),

	State({
		name = "land",
		onenter = function(inst, pos)
			inst.AnimState:PlayAnimation("break")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst:Remove()
			end),
		},
	}),
}

return StateGraph("sg_treemon_projectile", states, events, "idle")
