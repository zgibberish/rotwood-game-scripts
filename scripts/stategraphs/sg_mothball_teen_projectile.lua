local SGCommon = require("stategraphs/sg_common")
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"
local EffectEvents = require "effectevents"

local function OnHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnProjectileHitboxTriggered(inst, data, {
		attackdata_id = "attack",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.4,
		hitflags = Attack.HitFlags.PROJECTILE,
		combat_attack_fn = "DoKnockbackAttack",
		-- Change later? hit fx is played as an anim on the 'break' state
		hit_fx_offset_x = 0.5,
		keep_alive = true,
	})

	-- Remove if hovering over a knocked down target.
	if (hit or (inst.target and inst.target.sg and inst.target.sg:HasStateTag("prone"))) and not inst.sg.statemem.hit then
		inst.sg.statemem.hit = true
		inst.sg:GoToState("break")
	end
end

local function OnAttacked(inst, data)
	if inst and inst.sg and not inst.sg:HasStateTag("breaking") then
		-- If a non-local entity hit this, take control of it to make hitting it feel better.
		if not inst:IsLocal() then
			inst:TakeControl()
		end

		inst.sg:GoToState("break")
	end
end

local function OnOwnerHit(inst, owner)
	OnAttacked(inst)
end

local function StartLoopingSound(inst)
	local params = {}
	params.fmodevent = fmodtable.Event.mothball_teen_atk_LP

	inst.sg.mem.looping_sound = soundutil.PlaySoundData(inst, params, "looping_sound", inst)
end

local function UpdateLoopingSound(inst)
	local nearest_living_player = inst:GetClosestPlayer(true)
	if nearest_living_player then
		local dist = inst:GetDistanceSqTo(nearest_living_player) / 10

		-- @DANY un-comment this next line to get a reading of what the parameter will be:
		-- print(dist)

		soundutil.SetInstanceParameter(inst, inst.sg.mem.looping_sound, "distanceToNearestPlayer", dist)
	end
end

local function StopLoopingSound(inst)
	soundutil.KillSound(inst, "looping_sound")
end

local events =
{
	EventHandler("attacked", OnAttacked)
}

local states =
{
	State({
		name = "charge_up",
		tags = { "airborne" },

		onenter = function(inst)
			inst.sg:SetTimeoutAnimFrames(30)
			inst:DoTaskInTicks(1, function(inst)
				if inst.owner == nil then return end
				inst.owner:ListenForEvent("ownerhit", function(owner)
					OnOwnerHit(inst, owner)
				end)
			end)

			local anim_name = inst:HasTag("confuse") and "confuse" or "idle2"
			inst.AnimState:PlayAnimation(anim_name .. "_pre")
			inst.AnimState:PushAnimation(anim_name, true)
		end,

		timeline =
		{
			FrameEvent(0, function(inst) StartLoopingSound(inst) end)
		},

		ontimeout = function(inst)
			inst.sg:GoToState("shoot", inst.sg.statemem.target)
		end,
	}),

	State({
		name = "shoot",
		tags = { "airborne" },

		onenter = function(inst)
			-- If owner or target don't exist, destroy the projectile.
			local owner = SGCommon.Fns.SanitizeTarget(inst.owner)
			local target = SGCommon.Fns.SanitizeTarget(inst.target)
			if not owner or not target then
				inst.sg:GoToState("break")
				return
			end

			local anim_name = inst:HasTag("confuse") and "confuse" or "idle2"
			inst.AnimState:PlayAnimation(anim_name, true)

			inst.components.hitbox:StartRepeatTargetDelay()
			inst.Physics:SetMotorVel(inst.tuning.movement_speed)
			owner:ListenForEvent("ownerhit", function(owner)
				if owner == nil then return end
				OnOwnerHit(inst, owner)
			end)
			owner:ListenForEvent("death", function(owner)
				if owner == nil then return end
				OnOwnerHit(inst, owner)
			end)

			-- Store the angle to the target, for calculating homing behavior.
			inst.sg.statemem.angleToTarget = inst:GetAngleTo(target)
			local pos = inst:GetPosition()
			local targetpos = target:GetPosition()
			local dirToTarget = targetpos - pos
			inst.sg.statemem.movedir = dirToTarget
			inst.Transform:SetRotation(inst.sg.statemem.angleToTarget)
			inst.sg.statemem.hitboxResetTime = 0
		end,

		onupdate = function(inst)
			if inst.target == nil or not inst.target:IsValid() or inst.target:IsDead() then
				-- TODO: If their target died, should I pick a new target instead?
				return
			end

			UpdateLoopingSound(inst)

			local pos = inst:GetPosition()
			local targetpos = inst.target:GetPosition()
			local dirToTarget = targetpos - pos
			local currentspeed = inst.Physics:GetMotorVel()

			-- If the target is on the opposite side, smooth speed to zero, then back to full speed towards the target
			local speed = currentspeed

			-- The target is facing the projectile
			if DiffAngle(inst.sg.statemem.angleToTarget, inst:GetAngleTo(inst.target)) < 90 then
				-- Speed up towards the target
				speed = math.min(speed + speed * inst.tuning.acceleration * TheSim:GetTickTime(), inst.tuning.movement_speed)
				inst.sg.statemem.movedir = dirToTarget

				local distanceToTarget = pos:dist(targetpos)
				if distanceToTarget > 2 then
					inst.sg.statemem.angleToTarget = inst:GetAngleTo(inst.target)
					inst.Transform:SetRotation(inst.sg.statemem.angleToTarget)
				end
			else
				-- Slow down
				if inst.sg.statemem.turnAroundStartTime == nil then
					local startTime = TheSim:GetTick() * TheSim:GetTickTime()
					inst.sg.statemem.turnAroundStartTime = startTime
				else
					local currentTime = TheSim:GetTick() * TheSim:GetTickTime()
					if currentTime - inst.sg.statemem.turnAroundStartTime > inst.tuning.slow_down_time then
						inst.sg.statemem.turnAroundStartTime = nil
						inst.sg.statemem.angleToTarget = inst:GetAngleTo(inst.target)
						inst.Transform:SetRotation(inst.sg.statemem.angleToTarget)
					else
						speed = speed - speed * inst.tuning.acceleration * TheSim:GetTickTime()
					end
				end
			end

			-- Reset the projectiles hitbox every so often so it will still hit players who have dodged through it
			if (inst.sg.statemem.hitboxResetTime > 0.2) then
				inst.components.hitbox:StopRepeatTargetDelay()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg.statemem.hitboxResetTime = 0
			else
				inst.sg.statemem.hitboxResetTime = inst.sg.statemem.hitboxResetTime + TICKS
			end

			inst.components.hitbox:PushCircle(0, 0, 0.3, HitPriority.MOB_PROJECTILE)
			inst.Physics:SetMotorVel(speed)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnHitBoxTriggered),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "break",
		tags = { "breaking" },

		onenter = function(inst)
			-- Spawn the Effect
			local effect_name = inst:HasTag("confuse") and "projectile_teen_mothball_hit_elite" or "projectile_teen_mothball_hit"
			local params =
			{
				fxname = effect_name,
				-- offx = 0 -- setting to 0, but leaving this here in case we want to adjust offsets
			}
			EffectEvents.MakeEventSpawnEffect(inst, params)

			-- Play the correct anim on me
			local anim_name = inst:HasTag("confuse") and "confuse_break" or "break_2"
			inst.AnimState:PlayAnimation(anim_name)
			local frames = inst.AnimState:GetCurrentAnimationNumFrames()
			inst.sg:SetTimeoutAnimFrames(frames)
			inst.Physics:Stop()
			inst.HitBox:SetInvincible(true)

			inst.AnimState:SetScale(1.5, 1) --TEMP: until we have real FX, spread out the explo FX

			StopLoopingSound(inst)
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				EffectEvents.MakeEventSpawnLocalEntity(inst, "mothball_teen_projectile_aoe", "idle")
				inst:PushEvent("projectileremoved")
			end),
		},

		ontimeout = function(inst)
			SGCommon.Fns.RemoveProjectile(inst)
		end,
	}),
}

return StateGraph("sg_mothball_teen_projectile", states, events, "charge_up")
