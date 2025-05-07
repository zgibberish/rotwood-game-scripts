local SGCommon = require("stategraphs/sg_common")

local THROW_SPEED = 30
local THROW_OUT_TIME = 0.66
local THROW_HOLD_TIME = 0.1
local THROW_RETURN_TIME = 0.66
local SPIRAL_SPEED = 18
local SPIRAL_TIME = 5.25
local HITBOX_RADIUS = 0.8
local HITBOX_ELITE_RADIUS = 1.2

local function OnHitBoxTriggered(inst, data)
	SGCommon.Events.OnProjectileHitboxTriggered(inst, data, {
		attackdata_id = "shoot",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.4,
		hitflags = Attack.HitFlags.PROJECTILE,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 2,
		keep_alive = true
	})
end

local function OwnerLost(inst)
	return (inst.owner and (not inst.owner:IsAlive() or not inst.owner:IsLocal())) or not inst.owner
end

local states =
{
	State({
		name = "thrown",
		tags = { "airborne" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation("lily_hat_spin_loop", true)
			inst.sg:SetTimeout(THROW_OUT_TIME)
			inst.components.hitbox:StartRepeatTargetDelay()
		end,
		onupdate = function(inst)
			local time_remaining = inst.sg:GetTimeoutTicks() / SECONDS
			inst.Physics:SetMotorVel(THROW_SPEED * (time_remaining / THROW_OUT_TIME))

			local hit_radius = inst:HasTag("elite") and HITBOX_ELITE_RADIUS or HITBOX_RADIUS
			inst.components.hitbox:PushCircle(0, 0, hit_radius, HitPriority.MOB_PROJECTILE)

			if (OwnerLost(inst)) then --Owner(totolili) was knocked down and taken by another player or killed, remove projectile
				inst.sg:GoToState("death")
			end
		end,
		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
		},
		ontimeout = function(inst)
			inst.sg:GoToState("thrown_hold")
		end,
	}),
	State({
		name = "thrown_hold",
		tags = { "airborne" },
		onenter = function(inst)
			inst.sg:SetTimeout(THROW_HOLD_TIME)
			inst.Physics:Stop()
		end,
		onupdate = function(inst)
			local hit_radius = inst:HasTag("elite") and HITBOX_ELITE_RADIUS or HITBOX_RADIUS
			inst.components.hitbox:PushCircle(0, 0, hit_radius, HitPriority.MOB_PROJECTILE)

			if (OwnerLost(inst)) then
				inst.sg:GoToState("death")
			end
		end,
		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
		},
		ontimeout = function(inst)
			inst.sg:GoToState("thrown_return")
		end,
		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end
	}),
	State({
		name = "thrown_return",
		tags = { "airborne" },
		onenter = function(inst)
			inst.sg:SetTimeout(THROW_RETURN_TIME)
			inst.components.hitbox:StartRepeatTargetDelay()
		end,
		onupdate = function(inst)
			local time_remaining = inst.sg:GetTimeoutTicks() / SECONDS
			local time_factor = math.clamp(1 - (time_remaining / THROW_RETURN_TIME), 0, 1)
			inst.Physics:SetMotorVel(-THROW_SPEED * time_factor)

			local hit_radius = inst:HasTag("elite") and HITBOX_ELITE_RADIUS or HITBOX_RADIUS
			inst.components.hitbox:PushCircle(0, 0, hit_radius, HitPriority.MOB_PROJECTILE)

			if (OwnerLost(inst)) then
				inst.sg:GoToState("death")
			end
		end,
		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
		},
		ontimeout = function(inst)
			inst.sg:GoToState("death")
		end,
		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end
	}),
	State({
		name = "spiral",
		tags = { "airborne" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation("lily_hat_spin_loop", true)
			inst.sg:SetTimeout(SPIRAL_TIME)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.sg.statemem.facing_rot = 90
			inst.sg.statemem.looking_left = inst.Transform:GetFacing() == FACING_LEFT
		end,
		onupdate = function(inst)
			local hit_radius = inst:HasTag("elite") and HITBOX_ELITE_RADIUS or HITBOX_RADIUS
			inst.components.hitbox:PushCircle(0, 0, hit_radius, HitPriority.MOB_PROJECTILE)

			local time_remaining = inst.sg:GetTimeoutTicks() / SECONDS
			local time_factor = math.clamp(1 - (time_remaining / SPIRAL_TIME), 0, 1)
			local final_vel = 12 + (SPIRAL_SPEED * time_factor)
			inst.Physics:SetMotorVel(-final_vel)

			local rot_over_time = 3 + (2 * (time_remaining / SPIRAL_TIME))
			if (inst.sg.statemem.looking_left) then
				inst.sg.statemem.facing_rot = inst.sg.statemem.facing_rot + rot_over_time
				if (inst.sg.statemem.facing_rot > 360) then
					inst.components.hitbox:StopRepeatTargetDelay()
					inst.components.hitbox:StartRepeatTargetDelay()
					inst.sg.statemem.facing_rot = 0
				end
			else
				inst.sg.statemem.facing_rot = inst.sg.statemem.facing_rot - rot_over_time
				if (inst.sg.statemem.facing_rot <= 0) then
					inst.components.hitbox:StopRepeatTargetDelay()
					inst.components.hitbox:StartRepeatTargetDelay()
					inst.sg.statemem.facing_rot = 360
				end
			end

			inst.Transform:SetRotation(inst.sg.statemem.facing_rot)

			if (OwnerLost(inst)) then
				inst.sg:GoToState("death")
			end
		end,
		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
		},
		ontimeout = function(inst)
			inst.sg:GoToState("death")
		end,
		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end
	}),
	State({
		name = "death",
		tags = { "airborne" },
		onenter = function(inst)
			inst.AnimState:PlayAnimation("lily_hat_death")
			inst.Physics:Stop()
		end,
		events =
		{
			EventHandler("animover", function(inst)
				SGCommon.Fns.RemoveProjectile(inst) -- remove in onenter for now, eventually can do it after an anim
			end),
		},
	}),
}

return StateGraph("sg_totolili_projectile", states, nil, "thrown")
