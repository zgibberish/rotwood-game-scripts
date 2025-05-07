local SGCommon = require "stategraphs.sg_common"
local SGPlayerCommon = require "stategraphs.sg_player_common"
local fmodtable = require "defs.sound.fmodtable"
local PlayerSkillState = require "playerskillstate"
local combatutil = require "util.combatutil"
local soundutil = require "util.soundutil"

-- TODO(jambell): ONCE THIS IS PROVEN OUT, commonize this with the other stategraph


-- BIG BIG BIG TO-DO!

local function FindNearestBall(inst)
	local closest_dist
	local closest_ball
	for projectile,_ in pairs(inst.sg.mem.active_projectiles) do
		if projectile:IsValid() then
			local dist = inst:GetDistanceSqTo(projectile)
			if not closest_dist or dist < closest_dist then
				closest_dist = dist
				closest_ball = projectile
			end
		end
	end

	return closest_ball
end

local function TryPlayTackleSound(inst, victim)
	if not victim:HasTag("shotput") then
		local params = {}
		params.fmodevent = fmodtable.Event.Hit_tackle
		params.sound_max_count = 1
		soundutil.PlaySoundData(inst, params, nil, inst)
	end
end

local ATTACKS =
{
	TACKLE =
	{
		DMG_NORM = 0.67,
		HITSTUN = 10,
		PB_NORM = 1,
		HS_NORM = HitStopLevel.MINOR,
	},
}

local TACKLE_HEIGHT_THRESHOLD = 1.5
local THROW_BUTTON = "heavyattack"
local TACKLE_HIT_THROW_CANCEL_DELAY = 4 	-- after hitting with a tackle, how many frames should we have to wait before a THROW-cancel is executed?

local function CheckForBallHit(inst, target, height_threshold)
	-- When melee attacking, this function checks to see whether or not the melee attack connected with a ball.
	-- Checks whether the ball is hittable or not, then checks to see if the y height of the ball is in a range that can be hit by that specific attack.
	if not target.sg:HasStateTag("hittable") then
		return
	end
	local ball_y = target:GetPosition().y
	local my_minx, my_miny, my_minz, my_maxx, my_maxy, my_maxz = inst.entity:GetWorldAABB()
	local threshold = my_maxy + height_threshold -- height_threshold above the player's highest point. height_threshold is set per attack.

	if not (ball_y <= threshold) then
		-- The ball is too high.
		return false
	else
		local params = {}
		params.fmodevent = fmodtable.Event.Hit_ball
		params.sound_max_count = 1
		soundutil.PlaySoundData(inst, params, nil, inst)

		target.sg:AddStateTag("tackled")
		return true
	end
end
local function OnTackleHitBoxTriggered(inst, data)
	local attackdata = ATTACKS[inst.sg.statemem.attackid]
	local hitstoplevel = 0

	local hit = false

	local dir = inst.Transform:GetFacingRotation()
	for i = 1, #data.targets do
		local v = data.targets[i]
		local shouldhit = true
		if inst.sg.statemem.tackletargets[v] then
			-- We've already hit this target. RepeatTargetDelay isn't reliable in this case because we want to keep evaluating if we've hit a ball, but not re-hit an enemy if we've hit them
			shouldhit = false
		end

		local hitfx = "hits_player_unarmed"

		if v:HasTag("shotput") then
			if not inst.sg.statemem.hitball then -- If they haven't already hit a ball with this attack
				local ballhit = CheckForBallHit(inst, v, TACKLE_HEIGHT_THRESHOLD)
				if ballhit then
					hitstoplevel = 0
					inst.sg.statemem.hitball = true
					hitfx = "hits_player_unarmed_ball"

					-- The y-positions that the ball will be restrained to when it starts its 'spiked' trajectory
					inst.sg.statemem.minheight = 0.5
					inst.sg.statemem.maxheight = 1
				else
					shouldhit = false
				end
			else
				shouldhit = false
			end
		end

		if shouldhit then
			local focushit = inst.sg.statemem.focushit

			local attack = Attack(inst, v)
			attack:SetDamageMod(attackdata.DMG_NORM)
			attack:SetDir(dir)
			attack:SetHitstunAnimFrames(attackdata.HITSTUN)
			attack:SetPushback(attackdata.PB_NORM)
			attack:SetFocus(focushit)
			attack:SetID(inst.sg.mem.attack_type)

			inst.components.combat:DoBasicAttack(attack)

			-- hitstoplevel = SGCommon.Fns.ApplyHitstop(attack, hitstoplevel)

			local hitfx_x_offset = 2.75
			local hitfx_y_offset = 1.5

			inst.components.combat:SpawnHitFxForPlayerAttack(attack, hitfx, v, inst, hitfx_x_offset, hitfx_y_offset, dir, hitstoplevel)

			TryPlayTackleSound(inst, v)

			-- TODO(dbriscoe): Why do we only spawn if target didn't block? We unconditionally spawn in hammer. Maybe we should move this to SpawnHitFxForPlayerAttack
			if v.sg ~= nil and v.sg:HasStateTag("block") then
			else
				SpawnHurtFx(inst, v, hitfx_x_offset, dir, hitstoplevel)
			end

			inst.sg.statemem.tackletargets[v] = true
			hit = true
		end
	end

	if inst.sg.statemem.hitball then
		inst.Physics:Stop()
	end

	if hit then
		inst.components.playercontroller:OverrideControlQueueTicks(THROW_BUTTON, TACKLE_HIT_THROW_CANCEL_DELAY * ANIM_FRAMES)
		inst:DoTaskInAnimFrames(TACKLE_HIT_THROW_CANCEL_DELAY, function(inst)
			-- DESIGN: Allow throw-cancelling if we hit anything, but not immediately.
			if inst.sg:HasStateTag("busy") then -- In case we've gone into a different state
				inst.sg.statemem.heavycombostate = "default_heavy_attack"
				SGPlayerCommon.Fns.TryQueuedAction(inst, THROW_BUTTON)
			end
			inst.components.playercontroller:OverrideControlQueueTicks(THROW_BUTTON, nil)
		end)

		inst.sg.statemem.speedmult = 0.15 -- We've hit, so slow down the player's movement.
		inst.sg.statemem.hitting = false
	end
end

local events = {}
local states =
{
	PlayerSkillState({
		name = "skill_shotput_seek",
		tags = { "attack", "busy", "shotput_catch_forbidden" }, --shotput_catch_forbidden removed after active frames

		onenter = function(inst, speedmult)
			local ball = FindNearestBall(inst)
			if ball == nil then
				inst.sg.statemem.early_exit = true
				inst.sg:GoToState("idle")
				return
			end

			inst:PushEvent("attack_state_start")
			inst.AnimState:PlayAnimation("shotput_tackle")

			SGCommon.Fns.FaceActionTarget(inst, ball, true, true)

			inst.sg.statemem.speedmult = speedmult or 1
			SGPlayerCommon.Fns.SetRollPhysicsSize(inst)
			inst.sg.statemem.hitboxsize = inst.HitBox:GetSize()
			inst.HitBox:SetNonPhysicsRect(1.5)
			inst.sg.statemem.tackletargets = {}

			SGCommon.Fns.StartJumpingOverHoles(inst)
			inst.Physics:StartPassingThroughObjects()
		end,

		onupdate = function(inst)
			if inst.sg.statemem.hittingbody then
				-- A very thin hitbox not intended to hit enemies, but place a hitbox over the player's body. Should still allow players to tackle *past* adjacent enemies, but catch a ball landing on them.
				inst.components.hitbox:PushBeam(-1.5, 1, 0.05, HitPriority.PLAYER_DEFAULT)
			end

			if inst.sg.statemem.hittingshoulder then
				-- The main attacking hitbox of the attack
				inst.components.hitbox:PushBeam(1.75, 2.25, 1.25, HitPriority.PLAYER_DEFAULT)
			end
		end,

		timeline =
		{
			--PHYSICS
			-- leaving the ground again
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 35 * inst.sg.statemem.speedmult) end),
			FrameEvent(17, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 17 * inst.sg.statemem.speedmult) end),
			-- FrameEvent(15, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 16 * inst.sg.statemem.speedmult) end),
			FrameEvent(21, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4 * inst.sg.statemem.speedmult) end),
			FrameEvent(25, function(inst) inst.Physics:Stop() end),

			FrameEvent(6, function(inst)
				inst.AnimState:Pause()
			end),
			FrameEvent(15, function(inst)
				inst.AnimState:Resume()
			end),

			--ATTACK
			FrameEvent(0, function(inst)
				--TODO(jambell): try adding a head hitbox that extends past the attack hitbox
				inst.sg:AddStateTag("airborne")
				combatutil.StartMeleeAttack(inst)

				inst.sg.statemem.attackid = "TACKLE"

				inst.sg.statemem.focushit = false
				inst.components.hitbox:StartRepeatTargetDelayTicks(1) -- Set quite low so that we still evaluate if the ball should be hit every tick

				inst.sg.statemem.hittingbody = true
				inst.sg.statemem.hittingshoulder = false

			end),
			FrameEvent(2, function(inst)
				inst.sg.statemem.hittingbody = true
				inst.sg.statemem.hittingshoulder = true
			end),
			FrameEvent(20, function(inst)
				inst.sg:RemoveStateTag("airborne")
				SGCommon.Fns.StopJumpingOverHoles(inst)
				inst.Physics:StopPassingThroughObjects()
			end),
			FrameEvent(25, function(inst)
				inst.sg.statemem.hittingbody = false
				inst.sg.statemem.hittingshoulder = false
				combatutil.EndMeleeAttack(inst)
				inst.sg:RemoveStateTag("shotput_catch_forbidden")
			end),

			--CANCELS
			FrameEvent(20, SGPlayerCommon.Fns.SetCanDodge),
			FrameEvent(25, SGPlayerCommon.Fns.SetCanAttackOrAbility),
			FrameEvent(25, SGPlayerCommon.Fns.RemoveBusyState),
		},

		onexit = function(inst)
			if not inst.sg.statemem.early_exit then
				inst.Physics:Stop()
				inst.HitBox:SetNonPhysicsRect(inst.sg.statemem.hitboxsize)
				SGPlayerCommon.Fns.UndoRollPhysicsSize(inst)
				inst.components.hitbox:StopRepeatTargetDelay()
				SGCommon.Fns.StopJumpingOverHoles(inst)
				inst.Physics:StopPassingThroughObjects()
			end
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnTackleHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),
}

return StateGraph("sg_player_shotput_skill_seek", states, events, "skill_shotput_seek")
