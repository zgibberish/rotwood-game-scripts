local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local SGMinibossCommon = require "stategraphs.sg_miniboss_common"
local playerutil = require "util.playerutil"
local TargetRange = require "targetrange"
local monsterutil = require "util.monsterutil"

local function DisableOffsetHitboxes(inst)
	inst.components.offsethitboxes:SetEnabled("head_hitbox", false)
	inst.components.offsethitboxes:SetEnabled("leg_hitbox", false)
end

local function OnFlurryHitboxTriggered(inst, data)
	local bighit = inst.sg.statemem.hit and inst.sg.statemem.lasthit -- The last hit is a big hit if they were hit multiple times in the flurry

	-- NOTE: These numbers are tuned pretty carefully to ensure 5 hits are possible. If you modify them, please ensure 5 hits still occur.
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "flurry",
		hitstoplevel = bighit and HitStopLevel.HEAVIER or 0,
		pushback = bighit and 1.5 or 0.5,
		combat_attack_fn = bighit and "DoKnockdownAttack" or "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		reduce_friendly_fire = true,
		set_dir_angle_to_target = true,
		hitstun_anim_frames = bighit and 15 or 3,
		bypass_posthit_invincibility = not bighit,
		hit_target_pst_fn = function(attacker, target, _attack)
			attacker.sg.statemem.hit = true
		end,
	})
end

local function OnSpearHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "spear",
		hitstoplevel = HitStopLevel.HEAVIER,
		combat_attack_fn = "DoKnockdownAttack",
		set_dir_angle_to_target = true,
		pushback = 1.5,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		reduce_friendly_fire = true,
	})
end

local function OnKickHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "kick",
		hitstoplevel = HitStopLevel.HEAVIER,
		pushback = 0.4,
		custom_attack_fn = function(attacker, attack)
			local hit = false
			local facing = attacker.Transform:GetFacing()
			if attacker.sg.statemem.attack_state == "kick" then
				attack:SetPushback(2)
				if facing == FACING_RIGHT then
					attack:SetDir(0)
				else
					attack:SetDir(180)
				end
				hit = attacker.components.combat:DoKnockdownAttack(attack)
			else
				if facing == FACING_RIGHT then
					attack:SetDir(180)
				else
					attack:SetDir(0)
				end

				hit = attacker.components.combat:DoKnockdownAttack(attack)
			end
			return hit
		end,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		reduce_friendly_fire = true,
	})

	-- go into dive
	inst.sg.statemem.do_dive = true
end

local function OnDiveHitboxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "dive",
		hitstoplevel = HitStopLevel.MAJOR,
		hitflags = Attack.HitFlags.AIR_HIGH,
		pushback = 2,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		reduce_friendly_fire = true,
	})
end

local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		local target = inst.components.combat:GetTarget()
		if target ~= nil and not inst:IsNear(target, 8) then
			inst.components.timer:StartTimer("idlebehavior_cd", 16, true)
			inst.sg:GoToState("idle_behaviour")
			return true
		end
	end
	return false
end

local MAX_SPINNING_BIRD_KICK_HITS = 1 --4
local function OnSpinningBirdKickHitboxTriggered(inst, data)
	--local bighit = inst.sg.statemem.hit and inst.sg.statemem.lasthit -- The last hit is a big hit if they were hit multiple times in the spinning bird kick

	-- (TODO? Look for a cleaner way to implement this...) Track the number of times a target has been hit, and apply different attack data to them.
	inst.sg.statemem.numhits_tracker = inst.sg.statemem.numhits_tracker or {}

	-- Split up the data into two different hit groups:
	local data_normal, data_overhit = {}, {}
	data_normal.hitbox, data_overhit.hitbox = data.hitbox, data.hitbox
	data_normal.targets, data_overhit.targets = {}, {}

	for _, target in ipairs(data.targets) do
		inst.sg.statemem.numhits_tracker[target] = inst.sg.statemem.numhits_tracker[target] and inst.sg.statemem.numhits_tracker[target] + 1 or 1

		-- (TODO) Set up a way to properly override the 'nointerrupt' flag
		if target.sg then
			target.sg:RemoveStateTag("nointerrupt") -- Need to remove this tag to allow targets to enter a knockdown state from nointerrupt states
		end

		if inst.sg.statemem.numhits_tracker[target] > MAX_SPINNING_BIRD_KICK_HITS then
			table.insert(data_overhit.targets, target)
			--[[if target.sg then
				target.sg:RemoveStateTag("nointerrupt") -- Need to remove this tag to allow targets to enter a knockdown state from knockback
			end]]
		else
			table.insert(data_normal.targets, target)
		end
	end

	-- NOTE: Currently tuned to do 5 hits (4 regular hits + 1 final knockdown hit)
	if #data_normal.targets > 0 then
		SGCommon.Events.OnHitboxTriggered(inst, data_normal, {
			--[[attackdata_id = "spinning_bird_kick",
			hitstoplevel = bighit and HitStopLevel.HEAVIER or 0,
			pushback = bighit and 1.5 or 0,
			combat_attack_fn = bighit and "DoKnockdownAttack" or "DoKnockbackAttack",
			hit_fx = monsterutil.defaultAttackHitFX,
			hit_fx_offset_x = 0.5,
			reduce_friendly_fire = true,
			set_dir_angle_to_target = true,
			hitstun_anim_frames = bighit and 6 or 3,
			bypass_posthit_invincibility = not bighit,
			hit_target_pst_fn = function(attacker, target, _attack)
				attacker.sg.statemem.hit = true
			end,]]

			attackdata_id = "spinning_bird_kick",
			hitstoplevel = HitStopLevel.HEAVIER,
			pushback = 1.5,
			combat_attack_fn = "DoKnockdownAttack",
			hit_fx = monsterutil.defaultAttackHitFX,
			hit_fx_offset_x = 0.5,
			reduce_friendly_fire = true,
			set_dir_angle_to_target = true,
			hitstun_anim_frames = 6,
			knockdown_becomes_projectile = true,
			ignore_knockdown = true,
			hit_target_pst_fn = function(attacker, target, _attack)
				attacker.sg.statemem.hit = true
			end,
		})
	end

	if #data_overhit.targets > 0 then
		SGCommon.Events.OnHitboxTriggered(inst, data_overhit, {
			--[[attackdata_id = "spinning_bird_kick",
			hitstoplevel = HitStopLevel.HEAVIER,
			pushback = 1.5,
			combat_attack_fn = "DoKnockdownAttack",
			hit_fx = monsterutil.defaultAttackHitFX,
			hit_fx_offset_x = 0.5,
			reduce_friendly_fire = true,
			set_dir_angle_to_target = true,
			hitstun_anim_frames = 6,
			hit_target_pst_fn = function(attacker, target, _attack)
				attacker.sg.statemem.hit = true
			end,]]

			attackdata_id = "spinning_bird_kick",
			damage_mod = 0.1,
			hitstoplevel = HitStopLevel.HEAVIER,
			pushback = 1.5,
			combat_attack_fn = "DoKnockdownAttack",
			hit_fx = monsterutil.defaultAttackHitFX,
			hit_fx_offset_x = 0.5,
			reduce_friendly_fire = true,
			set_dir_angle_to_target = true,
			hitstun_anim_frames = 6,
			knockdown_becomes_projectile = true,
			ignore_knockdown = true,
			hit_target_pst_fn = function(attacker, target, _attack)
				attacker.sg.statemem.hit = true
			end,
		})

		--inst.sg:GoToState("spinning_bird_kick_pst", true)
	end
end

local function OnDeath(inst, data)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_floracrane", { y = 4.5 })

	--Spawn loot (lootdropper will attach hitstopper)
	inst.components.lootdropper:DropLoot()
end

local MIN_HOP_RANGE, MAX_HOP_RANGE = 8, 20
local events =
{
	SGCommon.Events.OnSpawnWalkable(),
	EventHandler("specialmovement", function(inst, target)
		local trange = TargetRange(inst, target)
		if trange:IsBetweenRange(MIN_HOP_RANGE, MAX_HOP_RANGE) and not inst.components.timer:HasTimer("hop_cd") then
			local direction = SGCommon.Fns.GetSpecialMovementDirection(inst, target)
			local state = (direction == SGCommon.SPECIAL_MOVEMENT_DIR.UP and "hop_above") or
						(direction == SGCommon.SPECIAL_MOVEMENT_DIR.DOWN and "hop_below") or
						"hop_forward"
			SGCommon.Fns.TurnAndActOnTarget(inst, target, true, state, target)
			local hop_cd = inst:HasTag("elite") and 6 or 2.5
			inst.components.timer:StartTimer("hop_cd", hop_cd)
		end
	end),
}
monsterutil.AddMinibossCommonEvents(events,
{
	ondeath_fn = OnDeath,
})
monsterutil.AddOptionalMonsterEvents(events,
{
	idlebehavior_fn = ChooseIdleBehavior,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local DASH_SPEED = 26

local states =
{
	State({
		name = "hop_forward",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("hop_forward")
			SGCommon.Fns.FaceTarget(inst, target, true)
			inst.Physics:StartPassingThroughObjects()
		end,

		timeline =
		{
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(18) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(8) end),
			FrameEvent(20, function(inst) inst.Physics:Stop() end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "hop_above",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("hop_above")
			SGCommon.Fns.FaceTarget(inst, target, true)
			inst.Physics:StartPassingThroughObjects()
		end,

		timeline =
		{
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED * 0.5) end),
			FrameEvent(8, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED) end),
			FrameEvent(11, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED * 0.75) end),
			FrameEvent(14, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED * 0.3) end),
			FrameEvent(16, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED * 0.2) end),
			FrameEvent(18, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED * 0.1) end),
			FrameEvent(20, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 0) end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "hop_below",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("hop_below")
			SGCommon.Fns.FaceTarget(inst, target, true)
			inst.Physics:StartPassingThroughObjects()
		end,

		timeline =
		{
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED * 0.5) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED) end),
			FrameEvent(8, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED * 0.75) end),
			FrameEvent(11, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED * 0.25) end),
			FrameEvent(14, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED * 0.1) end),
			FrameEvent(17, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 0) end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "flurry",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("flurry")
			DisableOffsetHitboxes(inst)
		end,

		timeline =
		{
			FrameEvent(10, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.components.hitbox:StartRepeatTargetDelayAnimFrames(3)
				inst.components.hitbox:PushBeam(-1, 1, 1.5, HitPriority.MOB_DEFAULT)
				inst.Physics:MoveRelFacing(0.4)
			end),
			FrameEvent(11, function(inst)
				inst.components.offsethitboxes:SetEnabled("head_hitbox", true)
				inst.components.offsethitboxes:Move("head_hitbox", -325/150)

				inst.components.offsethitboxes:SetEnabled("leg_hitbox", true)
				inst.components.offsethitboxes:Move("leg_hitbox", 850/150)

				inst.components.hitbox:PushBeam(-0.5, 2, 1, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(2, 3.5, 1.25, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(3.5, 6.6, 1.75, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(15, function(inst)
				inst.components.hitbox:PushBeam(-0.5, 2, 1, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(2, 3.5, 1.25, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(3.5, 6.6, 1.75, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(19, function(inst)
				inst.components.hitbox:PushBeam(-0.5, 2, 1, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(2, 3.5, 1.25, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(3.5, 6.6, 1.75, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(23, function(inst)
				inst.components.hitbox:PushBeam(-0.5, 2, 1, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(2, 3.5, 1.25, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(3.5, 6.6, 1.75, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(27, function(inst)
				inst.sg.statemem.lasthit = true -- Don't do hitstop for the flurry, only the last hits
				inst.components.hitbox:PushBeam(-0.5, 2, 1, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(2, 3.5, 1.25, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(3.5, 6.6, 1.75, HitPriority.MOB_DEFAULT)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("vulnerable")
			end),
			FrameEvent(33, function(inst)
				DisableOffsetHitboxes(inst)
			end),
			FrameEvent(37, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
				inst.sg:AddStateTag("nointerrupt")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnFlurryHitboxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.hit then
					inst.sg:GoToState("taunt")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			DisableOffsetHitboxes(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "kick",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			DisableOffsetHitboxes(inst)
			inst.sg.statemem.target = target
			inst.AnimState:PlayAnimation("kick")
		end,

		timeline =
		{
			FrameEvent(18, function(inst)
				inst.sg.statemem.attack_state = "kick"
				inst.components.offsethitboxes:SetEnabled("head_hitbox", true)
				inst.components.offsethitboxes:Move("head_hitbox", -410/150)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushOffsetBeam(-3, 0, 1, -0.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(19, function(inst)
				inst.components.hitbox:PushBeam(-3, 0, 1, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(-1, 1, 1.5, -1, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(20, function(inst)
				inst.components.offsethitboxes:Move("head_hitbox", -550/150)
				inst.components.hitbox:PushOffsetBeam(0, 6, 1.5, 0, HitPriority.MOB_DEFAULT) -- For some reason pushing a PushBeam here is way offset.
			end),
			FrameEvent(21, function(inst)
				inst.components.hitbox:PushBeam(0, 6, 1.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(22, function(inst)
				inst.components.offsethitboxes:Move("head_hitbox", -850/150)
				inst.components.hitbox:PushBeam(0, 4, 1.5, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(23, function(inst)
				inst.sg.statemem.attack_state = "beak"
				inst.components.hitbox:PushBeam(-6.5, -1, 1, HitPriority.MOB_DEFAULT)
			end),

			-- beak only
			FrameEvent(24, function(inst)
				inst.components.hitbox:PushBeam(-6.5, -1, 1, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(25, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("vulnerable")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnKickHitboxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.do_dive then
					inst.sg:GoToState("kick_pst_hit", { target = inst.sg.statemem.target, do_dive = true })
				else
					inst.sg:GoToState("kick_pst_miss")
				end
			end),
		},

		onexit = function(inst)
			DisableOffsetHitboxes(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "kick_pst_miss",
		tags = { "busy", "vulnerable" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("kick_pst_miss")
		end,

		timeline =
		{
			-- Code Generated by PivotTrack.jsfl
			FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(-60/150) end),
			-- End Generated Code
			FrameEvent(14, function(inst) inst.sg:RemoveStateTag("vulnerable") end),
			FrameEvent(19, function(inst) inst.sg:RemoveStateTag("busy") end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "kick_pst_hit",
		tags = { "attack", "busy", "vulnerable", "nointerrupt" },

		onenter = function(inst, data)
			inst.sg.statemem.do_dive = data.do_dive
			inst.sg.statemem.target = data.target
			inst.AnimState:PlayAnimation("kick_pst_hit")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				if not inst.sg.statemem.target
					or not inst.sg.statemem.target:IsValid()
				then
					inst.sg:GoToState("idle")
					return
				end
				local attacktracker = inst.components.attacktracker
				local trange = TargetRange(inst, inst.sg.statemem.target)
				local next_attack = attacktracker:PickNextAttack(nil, trange)
				if next_attack == "dive_fast" then
					SGCommon.Fns.TurnAndActOnTarget(inst, inst.sg.statemem.target, false, "dive_fast_pre", inst.sg.statemem.target)
				else
					inst.sg:GoToState("idle")
				end
			end),
		},
	}),

	State({
		name = "dive",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			DisableOffsetHitboxes(inst)
			inst.AnimState:PlayAnimation("dive")

			local base_dist = 10
			local base_scale = inst.Transform:GetScale()

			local scaled_dist = (base_dist * base_scale)
			local scaled_move_dist_sq = scaled_dist * scaled_dist

			local dist_sq_to_target = scaled_move_dist_sq

			if target then
				dist_sq_to_target = inst:GetDistanceSqTo(target)
				inst.sg.statemem.target = target
			end

			-- THIS NUMBER CAN NOT BE MORE THAN 1.34 OR THE GAME WILL CRASH FOR MOVING TOO QUICKLY
			inst.sg.statemem.move_scale = math.clamp(dist_sq_to_target / scaled_move_dist_sq, 0.5, 1.3)
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				-- Aim & move towards the target's position
				if inst.sg.statemem.target then
					SGCommon.Fns.FaceTarget(inst, inst.sg.statemem.target, true)

					-- Face target then cap rotation so it is not absolutely vertical
					local facingrot = inst.Transform:GetFacingRotation()
					local target = inst.sg.statemem.target
					local diff
					if target ~= nil and target:IsValid() then
						local dir = inst:GetAngleTo(target)
						diff = ReduceAngle(dir - facingrot)
						if math.abs(diff) >= 90 then
							diff = nil
						end
					end
					if diff == nil then
						local dir = inst.Transform:GetRotation()
						diff = ReduceAngle(dir - facingrot)
					end
					diff = math.clamp(diff, -70, 70)
					inst.Transform:SetRotation(facingrot + diff)
				end
			end),

			FrameEvent(8, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.sg:AddStateTag("flying")
				inst.HitBox:SetInvincible(true) -- Airborne, so don't be hittable.
			end),

			FrameEvent(10, function(inst)
				inst.sg:AddStateTag("flying_high")
				inst.sg:AddStateTag("airborne_high")
			end),

			FrameEvent(29, function(inst)
				inst.sg:RemoveStateTag("flying_high")
				inst.sg:RemoveStateTag("airborne_high")
				inst.HitBox:SetInvincible(false) -- Landed, so be hittable.

				inst.components.hitbox:PushBeam(1, 4, 1, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(30, function(inst)
				inst.components.hitbox:PushBeam(-1, 3.5, 1.5, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(31, function(inst)
				inst.components.offsethitboxes:SetEnabled("head_hitbox", true)
				inst.components.offsethitboxes:Move("head_hitbox", 300/150)
				inst.components.hitbox:PushBeam(-2, 3.5, 1.5, HitPriority.MOB_DEFAULT)
				inst.sg:RemoveStateTag("flying")
			end),

			FrameEvent(32, function(inst)
				inst.components.hitbox:PushBeam(-3, 3.5, 1.5, HitPriority.MOB_DEFAULT)
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("vulnerable")
			end),

			FrameEvent(89, function(inst)
				inst.components.offsethitboxes:SetEnabled("head_hitbox", false)
			end),

			FrameEvent(113, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
			end),

			-- Movement
			FrameEvent(6, function(inst)
				inst.Physics:StartPassingThroughObjects()
				inst.Physics:SetMotorVel(25 * inst.sg.statemem.move_scale)
			end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(24 * inst.sg.statemem.move_scale) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVel(9 * inst.sg.statemem.move_scale) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(3 * inst.sg.statemem.move_scale) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(3 * inst.sg.statemem.move_scale) end),
			FrameEvent(15, function(inst) inst.Physics:SetMotorVel(2 * inst.sg.statemem.move_scale) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(-1 * inst.sg.statemem.move_scale) end),
			FrameEvent(21, function(inst) inst.Physics:SetMotorVel(-6 * inst.sg.statemem.move_scale) end),
			FrameEvent(23, function(inst) inst.Physics:SetMotorVel(5 * inst.sg.statemem.move_scale) end),
			FrameEvent(25, function(inst) inst.Physics:SetMotorVel(8 * inst.sg.statemem.move_scale) end),
			FrameEvent(27, function(inst) inst.Physics:SetMotorVel(35 * inst.sg.statemem.move_scale) end),
			FrameEvent(28, function(inst) inst.Physics:SetMotorVel(89 * inst.sg.statemem.move_scale) end),
			FrameEvent(29, function(inst) inst.Physics:SetMotorVel(38 * inst.sg.statemem.move_scale) end),
			FrameEvent(30, function(inst)
				inst.Physics:StopPassingThroughObjects()
				inst.Physics:Stop()
			end),
			FrameEvent(94, function(inst) inst.Physics:SetMotorVel(-3) end),
			FrameEvent(98, function(inst) inst.Physics:SetMotorVel(-1.5) end),
			FrameEvent(104, function(inst) inst.Physics:Stop() end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnDiveHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			DisableOffsetHitboxes(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.HitBox:SetInvincible(false)
		end,
	}),

	State({
		name = "spear",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			DisableOffsetHitboxes(inst)
			inst.sg.statemem.target = target
			inst.AnimState:PlayAnimation("spear")
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				inst.components.offsethitboxes:SetEnabled("head_hitbox", true)
				inst.components.offsethitboxes:Move("head_hitbox", 250/150)
				inst.components.offsethitboxes:SetEnabled("leg_hitbox", true)
				inst.components.offsethitboxes:Move("leg_hitbox", -205/150)
			end),

			FrameEvent(13, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-5.130, 6.200, 1.5, HitPriority.MOB_DEFAULT)

				inst.components.offsethitboxes:Move("head_hitbox", 5.5)
				inst.components.offsethitboxes:Move("leg_hitbox", -4.5)
			end),

			FrameEvent(14, function(inst)
				inst.components.offsethitboxes:Move("head_hitbox", 7.7)
				inst.components.hitbox:PushBeam(-5.30, 8.50, 1.50, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(15, function(inst)
				inst.components.hitbox:PushBeam(-5.30, 8.50, 1.50, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(16, function(inst)
				inst.components.hitbox:PushBeam(-5.30, 8.50, 1.50, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(17, function(inst)
				inst.components.hitbox:PushBeam(-5.30, 8.50, 1.50, HitPriority.MOB_DEFAULT)
				inst.sg:AddStateTag("vulnerable")
				inst.sg:RemoveStateTag("nointerrupt")
			end),

			FrameEvent(19, function(inst)
				inst.components.offsethitboxes:Move("head_hitbox", 6.75)
			end),

			FrameEvent(21, function(inst)
				inst.components.offsethitboxes:Move("head_hitbox", 6)
				inst.components.offsethitboxes:Move("leg_hitbox", -4)
			end),

			FrameEvent(31, function(inst)
				inst.components.offsethitboxes:Move("head_hitbox", 5.5)
				inst.components.offsethitboxes:Move("leg_hitbox", -3)
			end),

			FrameEvent(33, function(inst)
				inst.components.offsethitboxes:Move("head_hitbox", 4)
				inst.components.offsethitboxes:Move("leg_hitbox", -2.5)
			end),

			FrameEvent(35, function(inst)
				inst.components.offsethitboxes:Move("head_hitbox", 2.4)
				inst.components.offsethitboxes:Move("leg_hitbox", -1.5)
			end),

			FrameEvent(37, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
			end),

			FrameEvent(45, function(inst)
				DisableOffsetHitboxes(inst)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSpearHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			DisableOffsetHitboxes(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "taunt",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior1")
		end,

		timeline =
		{
			FrameEvent(13, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(56, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "spinning_bird_kick",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("spinning_bird_kick_pre_loop")
			inst.sg.statemem.target = target

			inst.Physics:StartPassingThroughObjects()
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			--[[FrameEvent(2, function(inst)
				inst.components.hitbox:PushOffsetBeam(0.50, 4.00, 1.60, 0.70, HitPriority.MOB_DEFAULT)
			end),]]

			FrameEvent(4, function(inst)
				if inst.sg.statemem.target and inst.sg.statemem.target:IsValid() then
					SGCommon.Fns.FaceTarget(inst, inst.sg.statemem.target, true)
				end
				SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.bird_kick_move_speed)
				--inst.components.hitbox:PushOffsetBeam(-1.50, 1.00, 2.80, 3.50, HitPriority.MOB_DEFAULT)
			end),
		},

		events =
		{
			--EventHandler("hitboxtriggered", OnSpinningBirdKickHitboxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("spinning_bird_kick_loop")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "spinning_bird_kick_loop",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("spinning_bird_kick_loop", true)
			inst.sg:SetTimeoutAnimFrames(64) -- 4 frames * 16 loops

			inst.Physics:StartPassingThroughObjects()
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(4)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnSpinningBirdKickHitboxTriggered),
		},

		onupdate = function(inst)
			local current_frame = inst.AnimState:GetCurrentAnimationFrame()
			if ((current_frame % 4) == 0) then -- fire hitbox every 4 frames
				inst.components.hitbox:PushOffsetCircle(0.00, 0.00, 4.50, 2.0, HitPriority.MOB_DEFAULT)
			end
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("spinning_bird_kick_pst", inst.sg.statemem.hit)
		end,

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "spinning_bird_kick_pst",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, washit)
			inst.AnimState:PlayAnimation("spinning_bird_kick_pst")
			inst.sg.statemem.hit = washit
			--inst.sg.statemem.lasthit = true -- Don't do hitstop for the flurry, only the last hits
			inst.Physics:StartPassingThroughObjects()
		end,

		timeline =
		{
			FrameEvent(3, function(inst)

				inst.sg:RemoveStateTag("attack")
				inst.sg:RemoveStateTag("nointerrupt")
				inst.sg:AddStateTag("vulnerable")
			end),

			FrameEvent(10, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.bird_kick_move_speed * 0.5)
				inst.Physics:StopPassingThroughObjects()
			end),

			FrameEvent(13, function(inst)
				DisableOffsetHitboxes(inst)
			end),

			FrameEvent(15, function(inst)
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("vulnerable")
			end),
		},

		events =
		{
			--EventHandler("hitboxtriggered", OnSpinningBirdKickHitboxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.hit then
					inst.sg:GoToState("taunt")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:Stop()
		end
	}),
}


SGCommon.States.AddAttackPre(states, "flurry",
{
	tags = { "attack", "busy", "nointerrupt" },
})
SGCommon.States.AddAttackHold(states, "flurry",
{
	tags = { "attack", "busy", "nointerrupt" },
})

SGCommon.States.AddAttackPre(states, "kick",
{
	tags = { "attack", "busy", "nointerrupt" },
})
SGCommon.States.AddAttackHold(states, "kick",
{
	tags = { "attack", "busy", "nointerrupt" },
})

SGCommon.States.AddAttackPre(states, "dive",
{
	tags = { "attack", "busy", "nointerrupt" },
})
SGCommon.States.AddAttackHold(states, "dive",
{
	tags = { "attack", "busy", "nointerrupt" },
})

SGCommon.States.AddAttackPre(states, "dive_fast",
{
	tags = { "attack", "busy", "nointerrupt" },
})
SGCommon.States.AddAttackHold(states, "dive_fast",
{
	tags = { "attack", "busy", "nointerrupt" },
})

SGCommon.States.AddAttackPre(states, "spear",
{
	tags = { "attack", "busy", "nointerrupt" },
})
SGCommon.States.AddAttackHold(states, "spear",
{
	tags = { "attack", "busy", "nointerrupt" },

	timeline =
	{
		FrameEvent(0, function(inst)
			inst.components.offsethitboxes:SetEnabled("head_hitbox", true)
			inst.components.offsethitboxes:Move("head_hitbox", 250/150)
			inst.components.offsethitboxes:SetEnabled("leg_hitbox", true)
			inst.components.offsethitboxes:Move("leg_hitbox", -205/150)
		end),
	},
	onexit = function(inst)
		DisableOffsetHitboxes(inst)
	end,
})

SGCommon.States.AddAttackPre(states, "spinning_bird_kick",
{
	alwaysforceattack = true,
})
SGCommon.States.AddAttackHold(states, "spinning_bird_kick",
{
	alwaysforceattack = true,
})

SGCommon.States.AddSpawnWalkableStates(states,
{
	anim = "spawn",

	fadeduration = 0.33,
	fadedelay = 0,

	addtags = { "airborne" },

	spawn_tell_prefab = "fx_ground_target_purple",

	onenter_fn = function(inst)
		inst.Physics:StartPassingThroughObjects()

		local mod = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
		local pos = inst:GetPosition()
		inst.Transform:SetPosition(pos.x - (14 * mod), 0, pos.z)

		-- total movement during spawn anim is 2100 pixels or 14 units
		-- get facing direction and then offset 14 units backwards so the spawn location is where intended
	end,

	timeline =
	{
		FrameEvent(2, function(inst) inst.Physics:SetMotorVel(18) end),
		FrameEvent(14, function(inst) inst.Physics:SetMotorVel(8) end),
		FrameEvent(25, function(inst) inst.Physics:Stop() end),

		FrameEvent(27, function(inst)
			-- landed
			inst.Physics:StopPassingThroughObjects()
			inst.sg:RemoveStateTag("airborne")
			if inst.sg.statemem.spawn_data.spawn_tell and inst.sg.statemem.spawn_data.spawn_tell:IsValid() then
				inst.sg.statemem.spawn_data.spawn_tell:Remove()
			end
		end),
	},

	onexit_fn = function(inst)
		inst.Physics:StopPassingThroughObjects()
		inst.Physics:Stop()
	end,
})

SGCommon.States.AddHitStates(states)
SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 9,
	knockdown_getup_timeline =
	{
		-- Code Generated by PivotTrack.jsfl
		FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(6/150) end),
		FrameEvent(16, function(inst) inst.Physics:MoveRelFacing(12/150) end),
		FrameEvent(19, function(inst) inst.Physics:MoveRelFacing(26/150) end),
		FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(12/150) end),
		FrameEvent(25, function(inst) inst.Physics:MoveRelFacing(6/150) end),
		FrameEvent(28, function(inst) inst.Physics:MoveRelFacing(4/150) end),
		FrameEvent(31, function(inst) inst.Physics:MoveRelFacing(-12/150) end),
		FrameEvent(33, function(inst) inst.Physics:MoveRelFacing(-37/150) end),
		FrameEvent(35, function(inst) inst.Physics:MoveRelFacing(-35/150) end),
		FrameEvent(37, function(inst) inst.Physics:MoveRelFacing(-20/150) end),
		FrameEvent(39, function(inst) inst.Physics:MoveRelFacing(-4/150) end),
		FrameEvent(47, function(inst) inst.Physics:MoveRelFacing(8/150) end),
		FrameEvent(50, function(inst) inst.Physics:MoveRelFacing(20/150) end),
		FrameEvent(53, function(inst) inst.Physics:MoveRelFacing(8/150) end),
		FrameEvent(55, function(inst) inst.Physics:MoveRelFacing(6/150) end),
		-- End Generated Code
	},

	onenter_fn = function(inst)
		DisableOffsetHitboxes(inst)
	end,
})

SGCommon.States.AddKnockdownStates(states,
{
	movement_frames = 9,

	onenter_pre_fn = function(inst)
		DisableOffsetHitboxes(inst)
	end,
})
SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddIdleStates(states)
SGCommon.States.AddWalkStates(states,
{
	addtags = { "nointerrupt" },
})
SGCommon.States.AddTurnStates(states)

SGCommon.States.AddMonsterDeathStates(states)
SGMinibossCommon.States.AddMinibossDeathStates(states)

local fns =
{
	OnResumeFromRemote = SGCommon.Fns.ResumeFromRemoteHandleKnockingAttack,
}

SGRegistry:AddData("sg_floracrane", states)

return StateGraph("sg_floracrane", states, events, "idle", fns)
