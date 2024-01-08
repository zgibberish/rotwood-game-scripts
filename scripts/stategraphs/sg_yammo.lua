local EffectEvents = require "effectevents"
local SGCommon = require "stategraphs.sg_common"
local monsterutil = require "util.monsterutil"

local ELITE_SLAM_DISTANCE_THRESHOLD = 80
local ELITE_SWING_DISTANCE_THRESHOLD = 100

local function OnSlamHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = inst.sg.statemem.attack_id or "slam",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 1.5,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		reduce_friendly_fire = true,
	})
end

local function OnSwingHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = inst.sg.statemem.attack_id or "swing",
		set_dir_angle_to_target = true,
		hitstoplevel = HitStopLevel.HEAVIER,
		pushback = 1.5,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		hitflags = Attack.HitFlags.LOW_ATTACK,
		disable_enemy_on_enemy_hitstop = true,
		reduce_friendly_fire = true,
		knockdown_becomes_projectile = true,
	})
end

local function OnChargeHitBoxTriggered(inst, data)
	local hitstoplevel = HitStopLevel.HEAVY

	if #data.targets > 0 then
		local x, z = inst.Transform:GetWorldXZ()
		for i = 1, #data.targets do
			local target = data.targets[i]
			if not target:HasTag("player") then
				local tx, tz = target.Transform:GetWorldXZ()
				local dir = inst.Transform:GetRotation() -- + (math.random(-90, 90))

				if tz > z then -- above
					dir = math.random(-100, -80)
				else
					dir = math.random(80, 100)
				end

				-- inst:GetAngleTo(target)
				local attack = Attack(inst, target)
				attack:SetDamageMod(0.33)
				attack:SetDir(dir)
				attack:SetPushback(1.5)
				attack:SetHitFxData(monsterutil.defaultAttackHitFX, 0.5)
				attack:SetForceRemoteHitConfirm(true) -- mob v mob, so just auto-confirm this

				if target:HasTag("elite") then
					inst.components.combat:DoKnockbackAttack(attack)
				else
					inst.components.combat:DoKnockdownAttack(attack)
				end

				hitstoplevel = SGCommon.Fns.ApplyHitstop(attack, hitstoplevel)
			else
				inst.sg:GoToState(inst.sg.statemem.attack_state)
				inst.sg.statemem.charge_done = true
			end
		end
	end
end

local function ChooseBattleCry(inst, data)
	if data.target ~= nil and data.target:IsValid() then
		if not inst.components.timer:HasTimer("roar_cd") then
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
			if not inst.components.timer:HasTimer("stomp_cd") then
				if inst.components.health:GetPercent() < .75 and not inst:IsNear(target, 6) then
					SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "stomp")
					return true
				end
			end
		end
	end
	return false
end

local function OnDeath(inst, data)
	--Spawn death fx
	EffectEvents.MakeEventFXDeath(inst, data.attack, "death_yammo")
	--Spawn loot (lootdropper will attach hitstopper)
	inst.components.lootdropper:DropLoot()
end

local events =
{
}
monsterutil.AddMinibossCommonEvents(events,
{
	ondeath_fn = OnDeath,
})
monsterutil.AddOptionalMonsterEvents(events,
{
	idlebehavior_fn = ChooseIdleBehavior,
	battlecry_fn = ChooseBattleCry,
	spawn_perimeter = true,
})
SGCommon.Fns.AddCommonSwallowedEvents(events)

local states =
{
	State({
		name = "swing",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("swing")
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-4 , -1, 1, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(7, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.5, 1.85, 1.50, -2, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(8, function(inst)
				inst.components.hitbox:PushOffsetBeam(0, 4.5, 1.75, -2.0, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(3.80, 6.00, 1.50, -1.00, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(5.80, 7.30, 1.50, 0.50, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(9, function(inst)
				inst.components.hitbox:PushBeam(1, 7.1, 2, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(1.75, 7.1, 2.5, 1, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(8, function(inst)
				SGCommon.Fns.StartCounterHitKnockdownWindow(inst)
			end),

			FrameEvent(30, function(inst)
				inst.sg:RemoveStateTag("busy")
				SGCommon.Fns.StopCounterHitKnockdownWindow(inst)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSwingHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "slam",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("heavy_slam")
		end,

		timeline =
		{
			--Hitboxes
			FrameEvent(12, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(0, 6.6, 0.75, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(2, 4, 1.5, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushCircle(5.1, 0, 1.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(13, function(inst)
				-- inst.components.hitbox:PushBeam(0, 6.6, 1, HitPriority.MOB_DEFAULT) --enable this to make dodge-rolling towards the yammo harder
				inst.components.hitbox:PushCircle(5.1, 0, 1.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				-- inst.components.hitbox:PushBeam(0, 6.6, 1, HitPriority.MOB_DEFAULT) --enable this to make dodge-rolling towards the yammo harder
				inst.components.hitbox:PushCircle(5.1, 0, 1.5, HitPriority.MOB_DEFAULT)
			end),


			--knockdownable states
			FrameEvent(10, function(inst)
				-- inst.sg:AddStateTag("caninterrupt") 	-- jambell: I think the OnKnockdown and OnKnockback states in sg_common could be modified to let this tag override nointerrupt
				inst.sg:AddStateTag("vulnerable")   	-- but it sounds a bit like a hairy mess of tags... not that this isn't! to be more explicit I'm going to just remove nointerrupt
				inst.sg:RemoveStateTag("nointerrupt") 	-- as well for now, but I think caninterrupt is used in some other places I don't want to break. To revisit after discussion
			end),
			FrameEvent(54, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
				inst.sg:AddStateTag("nointerrupt")
			end),
			FrameEvent(66, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),

			-- arms hit box
			FrameEvent(12, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(12, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 470/150) end),
			FrameEvent(54, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 460/150) end),
			FrameEvent(55, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSlamHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "stomp",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior1")
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.components.timer:StartTimer("stomp_cd", 12, true)
				inst.components.timer:StartTimer("idlebehavior_cd", 8, true)
			end),
			FrameEvent(60, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
			FrameEvent(64, function(inst)
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
		name = "roar",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior2")
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
			FrameEvent(52, function(inst)
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
		name = "introduction",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("behavior2")
			inst.AnimState:PushAnimation("behavior1")
			inst.sg.statemem.animovers = 0
		end,

		timeline =
		{
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.animovers = inst.sg.statemem.animovers + 1
				if inst.sg.statemem.animovers >= 2 then
					inst.sg:GoToState("idle")
				end
			end),
		},
	}),


	---- ELITE ATTACKS ----

	State({
		name = "charge_slam",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("elite_heavy_slam_run_pre")
			inst.AnimState:PushAnimation("elite_heavy_slam_run_loop", true)

			inst.sg.statemem.attack_state = "charge_slam_stop"
			inst.sg.statemem.target = target
			inst.sg:SetTimeoutTicks(80)

			inst.sg.statemem.initial_rot = inst.Transform:GetRotation()
			inst.sg.statemem.turning_speed = 45 * TICKS
		end,

		ontimeout = function(inst)
			inst.sg:GoToState(inst.sg.statemem.attack_state)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.charging then
				local target = inst.sg.statemem.target
				if target and target:IsValid() then

					-- If I'm within range, just attack!
					local dist_sq = inst:GetDistanceSqTo(target)
					if dist_sq <= ELITE_SLAM_DISTANCE_THRESHOLD then
						inst.sg:GoToState(inst.sg.statemem.attack_state)
					else
						local facingrot = inst.Transform:GetRotation()
						local dir = inst:GetAngleTo(target)
						local total_diff = ReduceAngle(dir - inst.sg.statemem.initial_rot)
						if math.abs(total_diff) <= 90 then
							local diff = ReduceAngle(dir - facingrot)
							diff = math.clamp(diff, -inst.sg.statemem.turning_speed, inst.sg.statemem.turning_speed)
							inst.Transform:SetRotation(facingrot + diff)
						else
							inst.sg:GoToState(inst.sg.statemem.attack_state)
						end
					end

				end

				inst.components.hitbox:PushBeam(1.8, 3.0, 1.8, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg.statemem.charging = true
				SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed)
				inst.components.hitbox:StartRepeatTargetDelay()
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnChargeHitBoxTriggered),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "charge_slam_stop",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.sg.statemem.numanims = 0
			inst.AnimState:PlayAnimation("elite_heavy_slam_run_pst")
			inst.AnimState:PushAnimation("elite_heavy_slam_slide")
		end,

		timeline = {
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed * 0.8) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed * 0.6) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed * 0.4) end),
			FrameEvent(8, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed * 0.2) end),
			FrameEvent(10, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed * 0) end),
		},

		events = {
			EventHandler("animover", function(inst)
				inst.sg.statemem.numanims = inst.sg.statemem.numanims + 1
				if inst.sg.statemem.numanims >= 2 then
					inst.sg:GoToState("charge_slam_attack")
				end
			end)
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end
	}),


	State({
		name = "charge_slam_attack",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("elite_heavy_slam")
			inst.sg.statemem.attack_id = "charge_slam"
		end,

		timeline =
		{
			FrameEvent(12, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(0, 6.6, 0.75, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushBeam(2, 4, 1.5, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushCircle(5.1, 0, 1.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(13, function(inst)
				inst.components.hitbox:PushBeam(0, 6.6, 0.75, HitPriority.MOB_DEFAULT) --enable this to make dodge-rolling towards the yammo harder
				inst.components.hitbox:PushCircle(5.1, 0, 1.5, HitPriority.MOB_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				inst.components.hitbox:PushBeam(0, 6.6, 0.75, HitPriority.MOB_DEFAULT) --enable this to make dodge-rolling towards the yammo harder
				inst.components.hitbox:PushCircle(5.1, 0, 1.5, HitPriority.MOB_DEFAULT)
			end),

			-- arms hit box
			FrameEvent(12, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(12, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 470/150) end),
			FrameEvent(54, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 460/150) end),
			FrameEvent(55, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSlamHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "charge_swing",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("elite_swing_run_pre")
			inst.AnimState:PushAnimation("elite_swing_run_loop", true)

			inst.sg.statemem.attack_state = "charge_swing_stop"
			inst.sg.statemem.target = target
			inst.sg:SetTimeoutTicks(80)

			inst.sg.statemem.initial_rot = inst.Transform:GetRotation()
			inst.sg.statemem.turning_speed = 45 * TICKS
		end,

		ontimeout = function(inst)
			inst.sg:GoToState(inst.sg.statemem.attack_state)
		end,

		onupdate = function(inst)
			if inst.sg.statemem.charging then
				local target = inst.sg.statemem.target
				if target and target:IsValid() then
					-- If I'm in range, just attack!
					local dist_sq = inst:GetDistanceSqTo(target)
					if dist_sq <= ELITE_SWING_DISTANCE_THRESHOLD then
						inst.sg:GoToState(inst.sg.statemem.attack_state)
					else
						local facingrot = inst.Transform:GetRotation()
						local dir = inst:GetAngleTo(target)
						local total_diff = ReduceAngle(dir - inst.sg.statemem.initial_rot)
						if math.abs(total_diff) <= 90 then
							local diff = ReduceAngle(dir - facingrot)
							diff = math.clamp(diff, -inst.sg.statemem.turning_speed, inst.sg.statemem.turning_speed)
							inst.Transform:SetRotation(facingrot + diff)
						else
							inst.sg:GoToState(inst.sg.statemem.attack_state)
						end
					end
				end

				inst.components.hitbox:PushBeam(1.8, 3.0, 2, HitPriority.MOB_DEFAULT)
			end
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg.statemem.charging = true
				SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed)
				inst.components.hitbox:StartRepeatTargetDelay()
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnChargeHitBoxTriggered),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "charge_swing_stop",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.sg.statemem.numanims = 0
			inst.AnimState:PlayAnimation("elite_swing_run_pst")
			inst.AnimState:PushAnimation("elite_swing_slide")
		end,

		timeline = {
			FrameEvent(0, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed) end),
			FrameEvent(2, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed * 0.8) end),
			FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed * 0.6) end),
			FrameEvent(6, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed * 0.4) end),
			FrameEvent(8, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed * 0.2) end),
			FrameEvent(10, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.charge_speed * 0) end),
		},

		events = {
			EventHandler("animover", function(inst)
				inst.sg.statemem.numanims = inst.sg.statemem.numanims + 1
				if inst.sg.statemem.numanims >= 2 then
					inst.sg:GoToState("charge_swing_attack")
				end
			end)
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end
	}),

	State({
		name = "charge_swing_attack",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, data)
			inst.sg.statemem.attack_id = "charge_swing"

			if data and data.alreadyclose then
				inst.AnimState:PlayAnimation("elite_swing_close")
			else
				inst.AnimState:PlayAnimation("elite_swing")
			end
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.components.attacktracker:CompleteActiveAttack()
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-4 , -1, 1, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(7, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.5, 1.85, 1.50, -2, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(8, function(inst)
				inst.components.hitbox:PushOffsetBeam(0, 4.5, 1.75, -2.0, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(3.80, 6.00, 1.50, -1.00, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(5.80, 7.30, 1.50, 0.50, HitPriority.MOB_DEFAULT)
			end),

			FrameEvent(9, function(inst)
				inst.components.hitbox:PushBeam(1, 7.1, 2, HitPriority.MOB_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(1.75, 7.1, 2.5, 1, HitPriority.MOB_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSwingHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	})

}

SGCommon.States.AddAttackPre(states, "swing",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "swing",
{
	tags = { "attack", "busy", "nointerrupt" }
})

SGCommon.States.AddAttackPre(states, "slam",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "slam",
{
	tags = { "attack", "busy", "nointerrupt" }
})


SGCommon.States.AddAttackPre(states, "charge_swing",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "charge_swing",
{
	tags = { "attack", "busy", "nointerrupt" },
	onexit_fn = function(inst)
		-- Prevent transitioning to the next state below, in case we somehow died during this state.
		if not inst:IsAlive() then
			return
		end

		local target = SGCommon.Fns.SanitizeTarget(inst.sg.statemem.target)
		if target then
			local dist_sq = inst:GetDistanceSqTo(target)
			if dist_sq <= ELITE_SWING_DISTANCE_THRESHOLD then
				inst.sg:GoToState("charge_swing_attack", { alreadyclose = true })
			end
		end
	end,

})

SGCommon.States.AddAttackPre(states, "charge_slam",
{
	tags = { "attack", "busy", "nointerrupt" }
})
SGCommon.States.AddAttackHold(states, "charge_slam",
{
	tags = { "attack", "busy", "nointerrupt" },

	onexit_fn = function(inst)
		-- Prevent transitioning to the next state below, in case we somehow died during this state.
		if not inst:IsAlive() then
			return
		end

		local target = SGCommon.Fns.SanitizeTarget(inst.sg.statemem.target)
		if target then
			local dist_sq = inst:GetDistanceSqTo(target)
			if dist_sq <= ELITE_SLAM_DISTANCE_THRESHOLD then
				inst.sg:GoToState("charge_slam_attack")
			end
		end
	end,
})


SGCommon.States.AddHitStates(states, SGCommon.Fns.ChooseAttack)

SGCommon.States.AddSpawnPerimeterStates(states,
{
	pre_anim = "spawn_jump_pre",
	hold_anim = "spawn_jump_hold",
	land_anim = "spawn_jump_land",
	pst_anim = "spawn_jump_pst",

	pst_timeline =
	{
		FrameEvent(0, function(inst) inst.Physics:MoveRelFacing(71/150) end),
	},

	fadeduration = 0.5,
	fadedelay = 0.5,
	jump_time = 0.66,
})

SGCommon.States.AddWalkStates(states,
{
	addtags = { "nointerrupt" },
	turnpsttimeline =
	{
		FrameEvent(2, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),
	},
})

SGCommon.States.AddTurnStates(states,
{
	addtags = { "nointerrupt" },
})

SGCommon.States.AddIdleStates(states,
{
	addtags = { "nointerrupt" },
})

SGCommon.States.AddKnockbackStates(states,
{
	movement_frames = 12
})

SGCommon.States.AddKnockdownStates(states,
{
	movement_frames = 11,
	knockdown_size = 1.45,
})

SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddMonsterDeathStates(states)
SGCommon.States.AddMinibossDeathStates(states)

local fns =
{
	OnResumeFromRemote = SGCommon.Fns.ResumeFromRemoteHandleKnockingAttack,
}

SGRegistry:AddData("sg_yammo", states)

return StateGraph("sg_yammo", states, events, "idle", fns)
