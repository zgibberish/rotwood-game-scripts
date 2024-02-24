local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local SGMinibossCommon = require "stategraphs.sg_miniboss_common"
local TargetRange = require "targetrange"
local monsterutil = require "util.monsterutil"

local function OnPunchHitBoxTriggered(inst, data)
	local hitstop = inst:HasTag("elite") and HitStopLevel.MAJOR or HitStopLevel.MEDIUM
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "punch",
		hitstoplevel = hitstop,
		pushback = 1.5,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		reduce_friendly_fire = true,
		knockdown_becomes_projectile = true,
		-- disable_self_hitstop = true,
		disable_enemy_on_enemy_hitstop = true,
	})
end

local function OnButtSlamHitBoxTriggered(inst, data)
	local hitstun = inst:HasTag("elite") and 20 or 3
	-- NOTE: Hitstun frames here determine how the player dodges consecutive buttslams, if they are struck with the first buttslam.
		-- 0 to 1: possible with a perfect dodge and a well timed second dodge
		-- 2 to 11: unsafe, consecutive dodges not dodgeable
		-- 12 to 16: possible with a single perfect dodge
		-- 17+: maybe a little long if two gourdos, doable with a single perfect dodge, but often has weird physics interactions.

	inst.sg.mem.slam_loops = inst.sg.mem.slam_loops or 0
	local consecutive_slam = inst.sg.mem.slam_loops > 1

	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = inst.sg.statemem.current_attack or "butt_slam",
		hitstoplevel = HitStopLevel.HEAVY,
		hitstun_anim_frames = consecutive_slam and 24 or hitstun, -- the consecutive slams are longer than the initial by 5 frames
		pushback = 1.5,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		set_dir_angle_to_target = true,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		reduce_friendly_fire = true,
		knockdown_becomes_projectile = true,
		disable_self_hitstop = true,
		disable_enemy_on_enemy_hitstop = true,
	})
end

local function ChooseAttack(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		local attacktracker = inst.components.attacktracker
		local trange = TargetRange(inst, data.target)
		local next_attack = attacktracker:PickNextAttack(data, trange)

		if next_attack == "punch" then
			-- the logic for the attacks is the same right now, but I've still made two different if statements because more attacks will be added down the road
			local state_name = attacktracker:GetStateNameForAttack(next_attack)
			SGCommon.Fns.TurnAndActOnTarget(inst, data, false, state_name, data.target)
			return true
		end

		if next_attack == "butt_slam" or next_attack == "elite_butt_slam" then
			-- the logic for the attacks is the same right now, but I've still made two different if statements because more attacks will be added down the road
			local state_name = attacktracker:GetStateNameForAttack(next_attack)
			SGCommon.Fns.TurnAndActOnTarget(inst, data, false, state_name, data.target)
			return true
		end

	end
	return false
end

local function ChooseBattleCry(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		if not inst.components.timer:HasTimer("roar_cd") and inst:GetTimeAlive() > 10 then
			if not inst:IsNear(data.target, 6) then
				SGCommon.Fns.TurnAndActOnTarget(inst, data.target, true, "roar")
				return true
			end
		end
	end
	return false
end

local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		local target = inst.components.combat:GetTarget()
		if target ~= nil then
			if not inst.components.timer:HasTimer("roar_cd") then
				if inst.components.health:GetPercent() < .75 and not inst:IsNear(target, 6) then
					SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "roar")
					return true
				end
			end
		end
	end
	return false
end

local function OnDeath(inst, data)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_gourdo")
	--Spawn loot (lootdropper will attach hitstopper)
	inst.components.lootdropper:DropLoot()
end

local events =
{
	EventHandler("doheal", function(inst, data)
		if not inst.sg:HasStateTag("busy") then
			inst.sg.mem.buff_pos = data.pos
			SGCommon.Fns.TurnAndActOnTarget(inst, data, false, "buff_pre", data.pos)
		end
	end),
}
monsterutil.AddMinibossCommonEvents(events,
{
	ondeath_fn = OnDeath,
	chooseattack_fn = ChooseAttack -- TODO: Is this needed? Should it used the new, unified system everything else uses?
})
monsterutil.AddOptionalMonsterEvents(events,
{
	battlecry_fn = ChooseBattleCry,
	idlebehavior_fn = ChooseIdleBehavior,
	spawn_battlefield = true,
	spawn_perimeter = true,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local states =
{
	State({
		name = "roar",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior")
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.components.timer:StartTimer("roar_cd", 12, true)
				inst.components.timer:StartTimer("idlebehavior_cd", 8, true)
			end),
			FrameEvent(47, function(inst)
				inst.sg:AddStateTag("caninterrupt")
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
		name = "intro1",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_idle", true)
		end,

		events =
		{
			EventHandler("cine_skipped", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "intro2",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("knockdown_getup")
		end,

		events =
		{
			EventHandler("cine_skipped", function(inst)
				inst.sg:GoToState("idle")
			end),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "punch",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("punch")
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(0, 3.5, 1.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushBeam(0, 3.5, 1.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.components.hitbox:PushBeam(2, 6, 2.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(11, function(inst)
				inst.components.hitbox:PushBeam(2, 6, 2.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(23, function(inst)
				-- caninterrupt needed if this is meant to cause a knockdown because nointerrupt entity tag exists
				-- inst.sg:AddStateTag("caninterrupt") 	-- jambell: I think the OnKnockdown and OnKnockback states in sg_common could be modified to let this tag override nointerrupt
				inst.sg:AddStateTag("vulnerable")   	-- but it sounds a bit like a hairy mess of tags... not that this isn't! to be more explicit I'm going to just remove nointerrupt
				inst.sg:RemoveStateTag("nointerrupt") 	-- as well for now, but I think caninterrupt is used in some other places I don't want to break. To revisit after discussion
			end),
			FrameEvent(54, function(inst)
				-- inst.sg:RemoveStateTag("caninterrupt")
				inst.sg:RemoveStateTag("vulnerable")
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(66, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),

			-- arms hit box
			FrameEvent(10, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),

			FrameEvent(10, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 520/150) end),

			FrameEvent(12, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 490/150) end),

			FrameEvent(14, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 450/150) end),

			FrameEvent(23, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 150/150) end),

			FrameEvent(25, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnPunchHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "butt_slam",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("butt_slam")

			inst.sg.statemem.target = target
			local jump_time = 22/30 -- # of frames in the air / frames in a second
			local jump_dist = 9 -- desired distance for jump to travel

			if target ~= nil and target:IsValid() then
				local facingrot = inst.Transform:GetFacingRotation()
				local dir = inst:GetAngleTo(target)
				local diff = ReduceAngle(dir - facingrot)
				if math.abs(diff) > 90 then
					inst.sg.statemem.jump_speed = jump_dist/jump_time
				else
					diff = math.clamp(diff, -60, 60)
					inst.Transform:SetRotation(facingrot + diff)

					local dist = math.sqrt(inst:GetDistanceSqTo(target))
					inst.sg.statemem.speedmult = math.clamp(dist / (64 / 30), .5, 2.5)

					jump_dist = math.clamp(math.min(jump_dist, dist), 5, 9) -- desired distance for jump to travel
					inst.sg.statemem.jump_speed = jump_dist/jump_time
				end
			else
				inst.sg.statemem.jump_speed = jump_dist/jump_time
			end
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("airborne")
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.jump_speed)
				inst.Physics:MoveRelFacing(30/150)
			end),

			FrameEvent(10, function(inst) inst.Physics:StartPassingThroughObjects() end),

			FrameEvent(11, function(inst) inst.sg:AddStateTag("airborne_high") end),

			FrameEvent(28, function(inst) inst.Physics:StopPassingThroughObjects() end),
			FrameEvent(29, function(inst) inst.sg:RemoveStateTag("airborne_high") end),
			FrameEvent(30, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:Stop()
			 end),


			FrameEvent(30, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushCircle(0, 0, 3, HitPriority.MOB_DEFAULT)
				SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up", 3, 6, 4)
			end),
			FrameEvent(31, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 4, HitPriority.MOB_DEFAULT)
				SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up2", 4, 6, 4)
			end),
			FrameEvent(32, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 5, HitPriority.MOB_DEFAULT)
				SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up3", 6, 10, 4)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnButtSlamHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.components.timer:StartTimer("knockdown", inst.tuning.butt_slam_pst_knockdown_seconds, true)
				inst.sg:GoToState("knockdown_idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "buff",
		tags = { "attack", "busy", "nointerrupt", "castingseed" },

		onenter = function(inst, target_pos)
			--dbassert(target_pos, "Must have a target to buff.")
			inst.AnimState:PlayAnimation("buff")
			-- We no longer use the target_pos passed here by the "doheal" event from brain_gourdo.lua
			-- since the combat targetting was conflicting and sometimes passing the ai's target (player entity) instead
			-- The target from doheal is now saved directly from the event
		end,

		timeline =
		{
			FrameEvent(7, function(inst)

				if (not inst.sg.mem.buff_pos) then
					inst.sg.mem.buff_pos = inst:GetPosition() -- incase this entity migrates after buff_pos was set
				end
				local projectile_prefab = inst:HasTag("elite") and "gourdo_elite_projectile" or "gourdo_projectile"
				local projectile = SpawnPrefab(projectile_prefab, inst)
				projectile:Setup(inst)
				local origin_offset = Vector3(0, 880/150, 0)
				local x, z = inst.Transform:GetWorldXZ()
				projectile.Transform:SetPosition(x + origin_offset.x, origin_offset.y, z + origin_offset.z)

				-- shoot the seed away from the chosen target so it does not land in the middle of combat
				local offset_range = math.random() * 8
				local min_offset = 10
				local x_dir = 0.5 - math.random()
				local z_dir = 0.5 - math.random()
				local applied_dir_x = inst.sg.mem.buff_pos.x + x_dir
				local applied_dir_z = inst.sg.mem.buff_pos.z + z_dir
				local direction = Vector3.normalized(Vector3(applied_dir_x, 0, applied_dir_z) - inst.sg.mem.buff_pos)
				inst.sg.mem.buff_pos = inst.sg.mem.buff_pos + (direction * (min_offset + offset_range))
				local in_bounds_pos, out_bounds_dist = TheWorld.Map:FindClosestWalkablePoint(inst.sg.mem.buff_pos)

				-- if the position is corrected from out of bounds, offset the new in bounds position so it is not sitting directly on the world border
				if (out_bounds_dist > 0) then
					local bounds_direction = Vector3.normalized(in_bounds_pos - inst.sg.mem.buff_pos)
					in_bounds_pos = in_bounds_pos + (bounds_direction * 4)
				end

				-- if the final position is too near the edge of the world, push it inwards so the seed fight isn't crowded in the corner
				local padding_from_edge = 6
				local _, _, distsq = TheWorld.Map:FindClosestXZOnWalkableBoundaryToXZ(in_bounds_pos.x, in_bounds_pos.z)
				if distsq < padding_from_edge * padding_from_edge then
					-- Pull back from outside edges.
					local to_point, len = in_bounds_pos:normalized()
					-- Double padding to ensure we've backed up enough.
					len = math.abs(len - padding_from_edge * 2)
					in_bounds_pos = to_point:scale(len)
				end

				inst.sg.mem.buff_pos = in_bounds_pos

				projectile.sg:GoToState("thrown", inst.sg.mem.buff_pos)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.Physics:Stop()
		end,
	}),

	State({
		name = "elite_butt_slam",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.sg.statemem.current_attack = "elite_butt_slam"
			inst.AnimState:PlayAnimation("elite_butt_slam_start")
			inst.sg.statemem.target = target
			inst.sg.mem.slam_loops = 0
			local jump_time = 22/30 -- # of frames in the air / frames in a second
			local jump_dist = 9 -- desired distance for jump to travel

			if target ~= nil and target:IsValid() then
				local facingrot = inst.Transform:GetFacingRotation()
				local dir = inst:GetAngleTo(target)
				local diff = ReduceAngle(dir - facingrot)
				if math.abs(diff) > 90 then
					inst.sg.statemem.jump_speed = jump_dist/jump_time
				else
					diff = math.clamp(diff, -60, 60)
					inst.Transform:SetRotation(facingrot + diff)

					local dist = math.sqrt(inst:GetDistanceSqTo(target))
					inst.sg.statemem.speedmult = math.clamp(dist / (64 / 30), .5, 2.5)

					jump_dist = math.clamp(math.min(jump_dist, dist), 5, 9) -- desired distance for jump to travel
					inst.sg.statemem.jump_speed = jump_dist/jump_time
				end
			else
				inst.sg.statemem.jump_speed = jump_dist/jump_time
			end
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				inst.sg:AddStateTag("airborne")
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.jump_speed)
				inst.Physics:MoveRelFacing(30/150)
			end),

			FrameEvent(2, function(inst) inst.Physics:StartPassingThroughObjects() end),

			FrameEvent(4, function(inst) inst.sg:AddStateTag("airborne_high") end),

			FrameEvent(18, function(inst) inst.Physics:StopPassingThroughObjects() end),
			FrameEvent(20, function(inst) inst.sg:RemoveStateTag("airborne_high") end),
			FrameEvent(22, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:Stop()
			 end),

			FrameEvent(22, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushCircle(0, 0, 3, HitPriority.MOB_DEFAULT)
				SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up", 3, 6, 4)
			end),
			FrameEvent(23, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 4, HitPriority.MOB_DEFAULT)
				SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up2", 4, 6, 4)
			end),
			FrameEvent(24, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 4, HitPriority.MOB_DEFAULT)
				SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up3", 6, 10, 4)
			end),
			FrameEvent(25, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 4.5, HitPriority.MOB_DEFAULT)
				SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up3", 6, 10, 4)
			end),

		},

		events =
		{
			EventHandler("hitboxtriggered", OnButtSlamHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("elite_butt_slam_loop", inst.sg.statemem.target)
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "elite_butt_slam_loop",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.sg.statemem.current_attack = "elite_butt_slam"
			inst.AnimState:PlayAnimation("elite_butt_slam_middle_loop")
			inst.sg.statemem.target = target

			local jump_time = 22/30 -- # of frames in the air / frames in a second
			local jump_dist = 9 -- desired distance for jump to travel

			if target ~= nil and target:IsValid() then
				SGCommon.Fns.FaceTarget(inst, target, true)
				local facingrot = inst.Transform:GetFacingRotation()
				local dir = inst:GetAngleTo(target)
				local diff = ReduceAngle(dir - facingrot)
				if math.abs(diff) > 90 then
					inst.sg.statemem.jump_speed = jump_dist/jump_time
				else
					diff = math.clamp(diff, -60, 60)
					inst.Transform:SetRotation(facingrot + diff)

					local dist = math.sqrt(inst:GetDistanceSqTo(target))
					inst.sg.statemem.speedmult = math.clamp(dist / (64 / 30), .5, 2.5)

					jump_dist = math.clamp(math.min(jump_dist, dist), 5, 9) -- desired distance for jump to travel
					inst.sg.statemem.jump_speed = jump_dist/jump_time
				end
			else
				inst.sg.statemem.jump_speed = jump_dist/jump_time
			end
		end,

		timeline =
		{
			FrameEvent(13, function(inst)
				inst.sg:AddStateTag("airborne")
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.jump_speed)
				inst.Physics:MoveRelFacing(30/150)
			end),

			FrameEvent(15, function(inst) inst.Physics:StartPassingThroughObjects() end),

			FrameEvent(16, function(inst) inst.sg:AddStateTag("airborne_high") end),

			FrameEvent(33, function(inst) inst.Physics:StopPassingThroughObjects() end),
			FrameEvent(34, function(inst) inst.sg:RemoveStateTag("airborne_high") end),
			FrameEvent(35, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.Physics:Stop()

				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushCircle(0, 0, 3, HitPriority.MOB_DEFAULT)
				SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up", 3, 6, 4)
			end),
			FrameEvent(36, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 4, HitPriority.MOB_DEFAULT)
				SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up2", 4, 6, 4)
			end),
			FrameEvent(37, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 4, HitPriority.MOB_DEFAULT)
				SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up3", 6, 10, 4)
			end),
			FrameEvent(38, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 4.5, HitPriority.MOB_DEFAULT)
				SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up3", 6, 10, 4)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnButtSlamHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg.mem.slam_loops = inst.sg.mem.slam_loops + 1
				if inst.sg.mem.slam_loops < 2 then
					inst.sg:GoToState("elite_butt_slam_loop", inst.sg.statemem.target)
				else
					inst.sg:GoToState("elite_butt_slam_pst")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "elite_butt_slam_pst",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("elite_butt_slam_pst")
			inst.sg.statemem.target = target
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.components.timer:StartTimer("knockdown", inst.tuning.butt_slam_pst_knockdown_seconds, true)
				inst.sg:GoToState("knockdown_idle")
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),
}

SGCommon.States.AddAttackPre(states, "punch",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "punch",
{
	tags = { "attack", "busy", "nointerrupt" }
})

SGCommon.States.AddAttackPre(states, "butt_slam",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "butt_slam",
{
	tags = { "attack", "busy", "nointerrupt" }
})

SGCommon.States.AddAttackPre(states, "elite_butt_slam",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "elite_butt_slam",
{
	tags = { "attack", "busy", "nointerrupt" }
})

SGCommon.States.AddAttackPre(states, "buff",
{
	tags = { "attack", "busy", "castingseed" }
})
SGCommon.States.AddAttackHold(states, "buff",
{
	tags = { "attack", "busy", "caninterrupt", "knockback_becomes_knockdown", "castingseed" }
})

SGCommon.States.AddIdleStates(states)

SGCommon.States.AddHitStates(states, ChooseAttack)

SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 5,
})

SGCommon.States.AddKnockdownStates(states,
{
	movement_frames = 6,
	getup_frames = 15,
	knockdown_getup_timeline =
	{
		FrameEvent(15, function(inst) inst.Physics:MoveRelFacing(65/150) end),
	}
})

SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddSpawnPerimeterStates(states,
{
	pre_anim = "spawn3_pre",
	hold_anim = "spawn3_hold",
	land_anim = "spawn3_land",
	pst_anim = "spawn3_pst",
	fadeduration = 0.25,
	fadedelay = 0.25,
	jump_time = 0.66,
	exit_state = "knockdown_idle",
	pst_timeline =
	{
		FrameEvent(0, function(inst)
			inst.components.timer:StartTimer("knockdown", 1.5, true)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.hitbox:PushCircle(0, 0, 3, HitPriority.MOB_DEFAULT)
			SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up", 3, 6, 4)
		end),
		FrameEvent(1, function(inst)
			inst.components.hitbox:PushCircle(0, 0, 4, HitPriority.MOB_DEFAULT)
			SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up2", 4, 6, 4)
		end),
		FrameEvent(2, function(inst)
			inst.components.hitbox:PushCircle(0, 0, 5, HitPriority.MOB_DEFAULT)
			SGCommon.Fns.SpawnParticlesInRadius(inst, "dust_burst_up3", 6, 10, 4)
		end),
		FrameEvent(3, function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end),
	},
	pst_events =
	{
		EventHandler("hitboxtriggered", OnButtSlamHitBoxTriggered),
	},
})

SGCommon.States.AddWalkStates(states,
{
	turnpsttimeline =
	{
		FrameEvent(2, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),
	},
})

SGCommon.States.AddTurnStates(states, { chooseattack_fn = ChooseAttack })
SGCommon.States.AddMonsterDeathStates(states)
SGMinibossCommon.States.AddMinibossDeathStates(states)

local fns =
{
	OnResumeFromRemote = SGCommon.Fns.ResumeFromRemoteHandleKnockingAttack,
}

SGRegistry:AddData("sg_gourdo", states)

return StateGraph("sg_gourdo", states, events, "idle", fns)
