local SGCommon = require "stategraphs.sg_common"
local Power = require "defs.powers"
local TargetRange = require "targetrange"
local playerutil = require "util.playerutil"
local monsterutil = require "util.monsterutil"
local bossutil = require "prefabs.bossutil"
local spawnutil = require "util.spawnutil"
local ParticleSystemHelper = require "util.particlesystemhelper"

local lume = require "util.lume"
local krandom = require "util.krandom"

local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"

local function OnSlashHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "slash_air",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.8,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnSlash2HitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "slash2_air",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 1.4,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnWindGustHitBoxTriggered(inst, data)
	if inst.sg.statemem.is_wind_gust then
		return
	end

	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "wind_gust",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 2.0,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnSnatchHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "snatch",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 2.0,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnDiveSlamHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "dive_bomb",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 2.0,
		set_dir_angle_to_target = true,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnDiveBombHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "dive_bomb",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 2.0,
		set_dir_angle_to_target = true,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})

	-- Check if a player was hit
	local playerhit = false
	for _, ent in ipairs(data.targets) do
		if ent:HasTag("player") then
			--playerhit = true
			break
		end
	end

	--[[ if hit and playerhit then
		inst.sg.statemem.hit = true
	end ]]
end

local function OnFlyByHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "fly_by",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 2.0,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnGetOffMeHitBoxTriggered(inst, data)
	if inst.sg.statemem.is_wind_gust then
		return
	end

	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "phase_transition_get_off_me",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 2.0,
		set_dir_angle_to_target = true,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnDodgingHitBoxTriggered(inst, data)
	-- Stop moving if the hitbox hits a trap.
	for _, target in ipairs(data.targets) do
		if target:HasTag("trap") then
			inst.Physics:Stop()
		end
	end
end

--[[local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		local threat = playerutil.GetRandomLivingPlayer()
		if not threat then
			inst.sg:GoToState("idle_behaviour")
			return true
		end
	end
	return false
end]]

local function SpawnLandFX(inst, targetpos)
	-- Spawn target FX
	inst.sg.mem.dive_fx_list = {}
	local fx = SpawnPrefab("fx_ground_target_red", inst)
	fx.Transform:SetPosition( targetpos.x, 0, targetpos.z )
	table.insert(inst.sg.mem.dive_fx_list, fx)

	spawnutil.SpawnShape("fx_ground_target_red", 5,
	{
		instigator = inst,
		start_pt = targetpos,
		radius = 2,
		start_angle = 90,
		spawn_fn = function(fx_prefab)
			table.insert(inst.sg.mem.dive_fx_list, fx_prefab)
		end,
	})
end

local function RemoveLandFX(inst)
	if inst == nil or inst.sg.mem.dive_fx_list == nil then return end

	for i, fx in ipairs(inst.sg.mem.dive_fx_list) do
		if fx and fx:IsValid() then
			fx:Remove()
		end
	end
end

local function GetSuperFlapSpeed(inst, speed_type)
	local def = Power.FindPowerByName("owlitzer_super_flap")
	local rarity = Power.GetBaseRarity(def)
	local max_speed = def.tuning[rarity][speed_type] or 0

	return max_speed
end

local function SuperFlapAccelerate(inst, progress)
	local max_speed = GetSuperFlapSpeed(inst, "super_flap_speed") * 0.5
	local speed = Vector3.lerp(0, max_speed, progress)
	inst.sg.statemem.flap_speed = speed
end

local function RemoveStatusEffects(inst)
	inst.components.powermanager:ResetData()
	inst.components.powermanager:SetCanReceivePowers(false)
end

local MELEE_RANGE = 6
local events =
{
	EventHandler("specialmovement", function(inst, target)
		local trange = TargetRange(inst, target)

		-- Dash toward target. Different state depending on facing angle to target.
		if trange:IsOutOfRange(MELEE_RANGE) then
			SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "fly_dash", target)
		end
	end),

	EventHandler("getup", function(inst)
		local duration = inst.sg.mem.knockdown_duration or inst.components.combat:GetKnockdownDuration()
		inst.components.combat:SetKnockdownDuration(duration)
	end),

	EventHandler("divebomb", function(inst)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.FaceActionTarget(inst, target, true)
		end
		bossutil.DoEventTransition(inst, "dive_bomb_pre") end),
	EventHandler("superflap", function(inst)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.FaceActionTarget(inst, target, true)
		end
		bossutil.DoEventTransition(inst, "float_to_super_flap_pre")
	end),
	EventHandler("barf", function(inst)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.FaceActionTarget(inst, target, true)
		end
		bossutil.DoEventTransition(inst, "float_to_barf_pre")
	end),

	-- Check to enter transition states
	EventHandler("boss_phase_changed", function(inst, phase)
		if inst.sg:HasStateTag("knockdown") then
			inst.sg:GoToState("phase_transition_pre_getup")
		else
			inst.sg:GoToState("phase_transition_pre_fly")
		end
	end),

	-- Handlers if teleported while moving to a point/target
	EventHandler("teleport_start", function(inst)
		if inst.sg.statemem.movetotask then
			inst.sg.statemem.movetotask:Cancel()
			inst.sg.statemem.movetotask = nil
		end
	end),

	--EventHandler("teleport_end", function(inst)
	--end),
}
monsterutil.AddBossCommonEvents(events)
-- Disabled for now until anims are tweaked. Use when all players dead.
--[[monsterutil.AddOptionalMonsterEvents(events,
{
	idlebehavior_fn = ChooseIdleBehavior,
})]]

local SNATCH_SPEED = 40

local BARF_TIMES = 1
local MAX_BARF_BALLS = 30
local NUM_BALLS_PER_BARF =
{
	12,
	12,
	12,
	12,
}
local MAX_BARF_DISTANCE = 16

local FLAP_TIME = 5

local LEFT_PERCENT, RIGHT_PERCENT = -0.5, 1.5
local TOP_PERCENT, BOTTOM_PERCENT = 0.85, 0.5

local PHASE_TRANSITION_DAMAGE_REDUCTION = 0

local SUPER_LOOP_SPIKEBALL_INTERVAL = 0.4
local SPAWN_SPIKEBALL_DISTANCE_MIN = 10
local SPAWN_SPIKEBALL_DISTANCE_MAX = 15

local states =
{
	State({
		name = "dormant_idle",
		tags = { "idle" --[[, dormant]] },

		onenter = function(inst)
			-- TODO: Should probably wait for cine to trigger us. Intro should be driven by the cine.
			inst.sg:GoToState("idle")
		end,
	}),

	State({
		name = "introduction",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, attack_fn)
			inst.AnimState:PlayAnimation("intro1")
			inst.sg.statemem.start_pos = inst:GetPosition()
		end,

		events =
		{
			EventHandler("cine_skipped", function(inst)
				local pos = inst.sg.statemem.start_pos
				inst.Transform:SetPosition(pos.x, pos.y, pos.z) -- Bandicoot appears 9.6 units from the starting point at the end of the animation.
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "introduction2",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, attack_fn)
			inst.AnimState:PlayAnimation("intro2")
		end,
	}),

	--[[State({
		name = "screech_pre",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("screech_pre")
			inst.Physics:SetSize(2.8)
			inst.HitBox:UsePhysicsShape()
		end,

		timeline =
		{
			FrameEvent(13, function(inst)
				inst.HitBox:SetNonPhysicsRect(3.4)
				inst.components.timer:StartTimer("screech_cd", 30, true)
				local cd = inst.components.timer:GetTimeRemaining("alert_cd")
				if cd == nil or cd < 8 then
					inst.components.timer:StartTimer("alert_cd", 8, true)
				end
				cd = inst.components.timer:GetTimeRemaining("idlebehavior_cd")
				if cd == nil or cd < 2 then
					inst.components.timer:StartTimer("idlebehavior_cd", 2, true)
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState(math.random() < .5 and "screech_loop" or "screech_pst")
			end),
		},
	}),

	State({
		name = "screech_loop",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("screech_loop")
			inst.Physics:SetSize(2.8)
			inst.HitBox:SetNonPhysicsRect(3.4)
		end,

		timeline =
		{
			FrameEvent(2, function(inst) inst.HitBox:UsePhysicsShape() end),
			FrameEvent(8, function(inst) inst.HitBox:SetNonPhysicsRect(3.4) end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("screech_pst")
			end),
		},
	}),

	State({
		name = "screech_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("screech_pst")
			inst.Physics:SetSize(2.8)
			inst.HitBox:SetNonPhysicsRect(3.4)
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.HitBox:UsePhysicsShape()
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),]]

	State({
		name = "float_pre",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("float_pre")
		end,

		timeline =
		{
			FrameEvent(13, function(inst)
				inst.sg:AddStateTag("flying")
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
		name = "float_pst",
		tags = { "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("float_pst")
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	-- Dash
	State({
		name = "fly_dash",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, target)
			local direction = SGCommon.Fns.GetSpecialMovementDirection(inst, target)
			local anim = (direction == SGCommon.SPECIAL_MOVEMENT_DIR.UP and "fly_dash_above") or
						(direction == SGCommon.SPECIAL_MOVEMENT_DIR.DOWN and "fly_dash_below") or
						"fly_dash_forward"
			inst.AnimState:PlayAnimation(anim)
			inst.components.hitbox:StartRepeatTargetDelay()

			inst.sg.statemem.target = target
		end,

		timeline =
		{
			-- FrameEvent(3, function(inst) inst.SoundEmitter:PlaySound(fmodtable.Event.owlitzer_faster_move) end),
			FrameEvent(4, function(inst)
				inst.Physics:StartPassingThroughObjects()
				inst.sg.mem.is_dodging = true

				-- Move right in front of the target
				if inst.sg.statemem.target then
					local facing = inst.Transform:GetFacing() == FACING_LEFT and 1 or -1
					inst.sg.statemem.movetotask = SGCommon.Fns.MoveToTarget(inst, { target = inst.sg.statemem.target, offset = Vector3.unit_x * 2 * facing, duration = 10 * ANIM_FRAMES / SECONDS })
				end
			end),
			FrameEvent(20, function(inst)
				inst.sg.mem.is_dodging = nil
				inst.Physics:Stop()
			end),
		},

		onupdate = function(inst)
			-- Stop before it hits a thorns trap
			if inst.sg.mem.is_dodging then
				inst.components.hitbox:PushOffsetBeam(0.00, 4.00, 4.00, 0.50, HitPriority.BOSS_DEFAULT)
			end
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnDodgingHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.sg.mem.is_dodging = nil
		end,
	}),

	State({
		name = "phase_transition_pre_getup",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("phase_transition_pre_getup")
		end,

		timeline =
		{
			FrameEvent(14, function(inst)
				inst.sg:AddStateTag("flying")
			end),

			FrameEvent(26, function(inst)
				inst.sg:RemoveStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("phase_transition")
			end),
		},
	}),

	State({
		name = "phase_transition_pre_fly",
		tags = { "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("phase_transition_pre_fly")
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("phase_transition")
			end),
		},
	}),

	State({
		name = "phase_transition",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("phase_transition")
			inst.boss_coro:SetMusicPhase(inst.boss_coro.phase) -- manually incrementing because .phase is happening on a delay
			RemoveStatusEffects(inst)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				-- Face towards the center of the map:
				local center_pt = spawnutil.GetStartPointFromWorld(0.5, 0.5)
				SGCommon.Fns.TurnAndActOnLocation(inst, center_pt.x, center_pt.z, true, "phase_transition_leap")
			end),
		},
	}),

	State({
		name = "phase_transition_leap",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("phase_transition_leap")
		end,

		timeline =
		{
			FrameEvent(10, function(inst)
				inst.sg:AddStateTag("flying")
				SGCommon.Fns.SetMotorVelScaled(inst, 20)
			end),
			FrameEvent(25, function(inst)
				inst.sg:RemoveStateTag("flying")
				inst.Physics:Stop()
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("phase_transition_get_off_me_pre")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end,
	}),

	State({
		name = "phase_transition_get_off_me",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("phase_transition_get_off_me")
			inst.components.combat:SetDamageReceivedMult("phase_transition", PHASE_TRANSITION_DAMAGE_REDUCTION)
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.hitbox:SetHitFlags(HitGroup.ALL)
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 3.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 5.50, HitPriority.BOSS_DEFAULT)
				inst.components.hitbox:StopRepeatTargetDelay()
				inst.components.combat:RemoveDamageReceivedMult("phase_transition")
			end),
			FrameEvent(6, function(inst)
				inst.components.auraapplyer:SetEffect("owlitzer_transition_attack")
				inst.components.auraapplyer:SetRadius(100)
				inst.components.auraapplyer:Enable()
				inst.sg.statemem.is_wind_gust = true
			end),
			FrameEvent(18, function(inst)
				inst.components.auraapplyer:Disable()
			end),
			FrameEvent(27, function(inst)
				inst.sg:AddStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnGetOffMeHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("float_to_super_flap", true)
			end),
		},

		onexit = function(inst)
			inst.components.combat:RemoveDamageReceivedMult("phase_transition")
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)
		end,
	}),


	-- Attacks
	State({
		name = "slash_air",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("slash_air")
			SGCommon.Fns.SetMotorVelScaled(inst, 15)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 5.50, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.Physics:Stop()
				inst.components.hitbox:PushOffsetBeam(0.00, 6.00, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(0.00, 5.20, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushOffsetBeam(0.00, 4.00, 2.00, 0.50, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSlashHitBoxTriggered),
			EventHandler("animover", function(inst)
				local target = inst.components.combat:GetTarget()
				if target then
					--[[local trange = TargetRange(inst, target)
					if trange:IsFacingTarget() and trange:TestCone45(0, 10, 4) then]]
						SGCommon.Fns.FaceTarget(inst, target, true)
						inst.sg:GoToState("slash2_air_pre")
					--[[else
						inst.sg:GoToState("slash_pst")
					end]]
				else
					inst.sg:GoToState("slash_pst")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "slash_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("slash_pst")
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, 6)
				inst.sg:AddStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.Physics:Stop()
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "slash2_air",
		tags = { "attack", "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("slash2_air")
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(30) end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushOffsetBeam(-3.50, -0.50, 2.00, 0.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(-2.50, 1.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(1.00, 5.50, 1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushOffsetBeam(3.00, 5.50, 1.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushOffsetBeam(3.00, 5.50, 1.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(10) end),
			FrameEvent(15, function(inst) inst.Physics:Stop() end),
			FrameEvent(19, function(inst) inst.Physics:SetMotorVel(5) end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSlash2HitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "turn_fly_forward_ground",
		tags = { "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("turn_fly_forward_ground")
			inst.Physics:StartPassingThroughObjects()
			inst.components.hitbox:StartRepeatTargetDelay()

			inst.sg.statemem.target = inst.components.combat:GetTarget()
		end,

		timeline =
		{
			-- FrameEvent(4, function(inst) inst.SoundEmitter:PlaySound(fmodtable.Event.owlitzer_faster_move) end),
			FrameEvent(5, function(inst)
				inst.sg.mem.is_dodging = true
				if inst.sg.statemem.target then
					local facing = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
					inst.sg.statemem.movetotask = SGCommon.Fns.MoveToTarget(inst, { target = inst.sg.statemem.target, offset = Vector3.unit_x * 10 * facing, duration = 11 * ANIM_FRAMES / SECONDS })
				end
			end),


			FrameEvent(16, function(inst)
				inst.sg.mem.is_dodging = nil
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("flying")
			end),
		},

		onupdate = function(inst)
			-- Stop before it hits a thorns trap
			if inst.sg.mem.is_dodging then
				inst.components.hitbox:PushOffsetBeam(0.00, 4.00, 4.00, 0.50, HitPriority.BOSS_DEFAULT)
			end
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnDodgingHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("wind_gust_pre")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.sg.mem.is_dodging = nil

			if inst.sg.statemem.target then
				SGCommon.Fns.FaceTarget(inst, inst.sg.statemem.target, true)
			end
		end,
	}),

	State({
		name = "fly_back_ground",
		tags = { "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("fly_back_ground")
			inst.Physics:StartPassingThroughObjects()
			inst.components.hitbox:StartRepeatTargetDelay()

			inst.sg.statemem.target = inst.components.combat:GetTarget()
		end,

		timeline =
		{
			-- FrameEvent(4, function(inst) inst.SoundEmitter:PlaySound(fmodtable.Event.owlitzer_faster_move) end),
			FrameEvent(5, function(inst)
				inst.sg.mem.is_dodging = true
				if inst.sg.statemem.target then
					local facing = inst.Transform:GetFacing() == FACING_LEFT and 1 or -1
					inst.sg.statemem.movetotask = SGCommon.Fns.MoveToTarget(inst, { target = inst.sg.statemem.target, offset = Vector3.unit_x * 16 * facing, duration = 11 * ANIM_FRAMES / SECONDS })
				end
			end),

			FrameEvent(16, function(inst)
				inst.sg.mem.is_dodging = nil
				inst.Physics:Stop()
				inst.sg:RemoveStateTag("flying")
			end),
		},

		onupdate = function(inst)
			-- Stop before it hits a thorns trap
			if inst.sg.mem.is_dodging then
				inst.components.hitbox:PushOffsetBeam(0.00, 4.00, 4.00, 0.50, HitPriority.BOSS_DEFAULT)
			end
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnDodgingHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("wind_gust_pre")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.sg.mem.is_dodging = nil
		end,
	}),

	State({
		name = "wind_gust",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("wind_gust")
			--inst.components.hitbox:StartRepeatTargetDelayAnimFrames(1)
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushOffsetBeam(0.00, 5.50, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			--[[FrameEvent(4, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.00, 5.50, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.00, 5.50, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),]]

			FrameEvent(4, function(inst)
				inst.sg.statemem.flap_speed = GetSuperFlapSpeed(inst, "wind_gust_speed")
				inst.components.auraapplyer:SetEffect("owlitzer_super_flap")
				inst.components.auraapplyer:SetupBeamHitbox(1, 40, 5)
				inst.components.auraapplyer:Enable()
				inst.sg.statemem.is_wind_gust = true

				inst.components.hitbox:SetHitFlags(HitGroup.ALL)
			end),

			FrameEvent(16, function(inst)
				inst.components.auraapplyer:Disable()
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnWindGustHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("wind_gust_fly_pst")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.auraapplyer:Disable()
			inst.sg.statemem.is_wind_gust = false
		end,
	}),

	State({
		name = "wind_gust_fly_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("wind_gust_fly_pst")
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.sg:AddStateTag("flying")
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
		name = "snatch",
		tags = { "attack", "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("snatch")
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
			local target = inst.components.combat:GetTarget()
			SGCommon.Fns.FaceTarget(inst, target, true)
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				inst.Physics:SetMotorVel(SNATCH_SPEED)
			end),
			FrameEvent(11, function(inst)
				inst.Physics:SetMotorVel(SNATCH_SPEED * 0.3)
			end),
			FrameEvent(12, function(inst)
				inst.Physics:SetMotorVel(SNATCH_SPEED * 0.1)
			end),
			FrameEvent(15, function(inst)
				inst.Physics:Stop()
			end),

			FrameEvent(3, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.80, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 2.80, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(11, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 1.9, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushBeam(-1.00, 3.20, 1.9, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSnatchHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "dive_slam",
		tags = { "attack", "busy", "flying_high", "nointerrupt" },

		default_data_for_tools = function(inst)
			inst.sg.mem.dive_fx_list = {}
		end,

		onenter = function(inst)
			local target = inst.components.combat:GetTarget()
			SGCommon.Fns.FaceTarget(inst, target, true)

			inst.AnimState:PlayAnimation("dive_slam")
			inst.Physics:StartPassingThroughObjects()
			inst.HitBox:SetEnabled(false)
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				inst.Physics:Stop()
				inst.Physics:StopPassingThroughObjects()
				inst.sg:RemoveStateTag("flying_high")

				--RemoveLandFX(inst)
			end),

			FrameEvent(5, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 4.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushCircle(0.00, 0.00, 6.00, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnDiveSlamHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
			inst.HitBox:SetEnabled(true)

			--RemoveLandFX(inst)
		end,
	}),

	State({
		name = "dive_bomb",
		tags = { "attack", "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("dive_bomb")
			--SGCommon.Fns.SetMotorVelScaled(inst, 15)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.HitBox:SetInvincible(true)

			-- Set position so that it ends up at the target position.
			local targetpos = inst.sg.mem.dive_pos or Vector3.zero
			local x, y, z = targetpos:Get()
			local facing = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
			inst.Transform:SetPosition(x - (17.4 * facing), y, z) -- x-offset derived from adding the MoveRelFacing values below.

			--warning sound
			local params = {}
			params.fmodevent = fmodtable.Event.Mus_Owlitzer_SwoopStinger_Dive
			soundutil.PlaySoundData(inst, params)
		end,

		timeline =
		{
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushBeam(-2.00, 2.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushBeam(-2.00, 5.50, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.HitBox:SetInvincible(false)
				inst.components.hitbox:PushBeam(0.00, 5.00, 2.00, HitPriority.BOSS_DEFAULT)

				--RemoveLandFX(inst)
			end),

			-- Code Generated by PivotTrack.jsfl (slight modifications made to avoid crashing due to going over the 300 pixel/frame limit.)
			FrameEvent(1, function(inst) inst.Physics:MoveRelFacing(247/150) end),
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(247/150) end),
			FrameEvent(3, function(inst) inst.Physics:MoveRelFacing(247/150) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(247/150) end),
			FrameEvent(5, function(inst) inst.Physics:MoveRelFacing(247/150) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(230/150) end),
			FrameEvent(7, function(inst) inst.Physics:MoveRelFacing(260/150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(295/150) end),
			FrameEvent(9, function(inst) inst.Physics:MoveRelFacing(300/150) end),
			FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(290/150) end),
			-- End Generated Code
		},

		events =
		{
			EventHandler("hitboxtriggered", OnDiveBombHitBoxTriggered),
			EventHandler("animover", function(inst)
				--[[if inst.sg.statemem.hit then
					inst.sg:GoToState("dive_bomb_hit")
					TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Owlitzer_SwoopStinger_Hit", 1)
				else]]
					inst.sg:GoToState("dive_bomb_miss")
					--TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Owlitzer_SwoopStinger_Miss", 1)
				--end
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.components.hitbox:StopRepeatTargetDelay()

			--RemoveLandFX(inst)
		end,
	}),

	State({
		name = "dive_bomb_miss",
		tags = { "busy", "nointerrupt", "knockdown", "vulnerable" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("dive_bomb_miss")
		end,

		timeline =
		{
			FrameEvent(0, function(inst)
				inst.components.hitbox:PushBeam(-2.00, 2.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(1, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.00, 5.50, 2.00, 1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.00, 4.20, 2.00, 1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.00, 3.00, 2.00, 1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.00, 3.00, 2.00, 1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.00, 3.00, 2.00, 1.50, HitPriority.BOSS_DEFAULT)
			end),

			-- Code Generated by PivotTrack.jsfl
			FrameEvent(1, function(inst) inst.Physics:MoveRelFacing(100/150) end),
			FrameEvent(3, function(inst) inst.Physics:MoveRelFacing(230/150) end),
			FrameEvent(5, function(inst) inst.Physics:MoveRelFacing(273/150) end),
			FrameEvent(7, function(inst) inst.Physics:MoveRelFacing(272/150) end),
			FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(300/150) end),
			FrameEvent(12, function(inst) inst.Physics:MoveRelFacing(168/150) end),
			FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(107/150) end),
			FrameEvent(17, function(inst) inst.Physics:MoveRelFacing(170/150) end),
			FrameEvent(20, function(inst) inst.Physics:MoveRelFacing(96/150) end),
			FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(80/150) end),
			-- End Generated Code
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.Physics:Stop()
				inst.Transform:FlipFacingAndRotation() -- Animation ends up facing backwards, so need to flip to match knockdown_idle's anim facing.

				-- Save & reload the knockdown duration after knockdown
				inst.sg.mem.knockdown_duration = inst.components.combat:GetKnockdownDuration() -- Gets reset from the "getup" event handler.
				inst.components.combat:SetKnockdownDuration(4 + math.random() * 2 - 1)
				inst.components.timer:StartTimer("knockdown", inst.components.combat:GetKnockdownDuration(), true)
				inst.sg:GoToState("knockdown_idle")
				inst.sg.statemem.knockdown = true -- Need to set this to remain in knockdown_idle for knockdown duration!
			end),
		},

		onexit = function(inst)
			inst:PushEvent("divebomb_over")
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	--[[State({
		name = "dive_bomb_hit",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("dive_bomb_hit")
		end,

		timeline =
		{
			-- Code Generated by PivotTrack.jsfl
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(300/150) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(206/150) end),
			FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(198/150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(180/150) end),
			FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(128/150) end),
			FrameEvent(11, function(inst) inst.Physics:MoveRelFacing(92/150) end),
			FrameEvent(13, function(inst) inst.Physics:MoveRelFacing(126/150) end),
			-- End Generated Code

			FrameEvent(13, function(inst) inst.Physics:Stop() end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("laugh_pre")
			end),
		},

		onexit = function(inst)
			inst:PushEvent("divebomb_over")
			inst.Physics:Stop()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),]]

	State({
		name = "laugh_pre",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("laugh_pre")
			local target = inst.components.combat:GetTarget()
			SGCommon.Fns.FaceTarget(inst, target, true)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("laugh_loop")
			end),
		},
	}),

	State({
		name = "laugh_loop",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("laugh_loop", true)
			inst.sg:SetTimeout(2)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("laugh_pst")
		end,
	}),

	State({
		name = "laugh_pst",
		tags = { "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("laugh_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "float_to_barf_pre",
		tags = { "busy", "flying", "nointerrupt" },

		onenter = function(inst)
			inst.Physics:Stop()
			inst.AnimState:PlayAnimation("float_pst")
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("flying")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("barf_pre")
			end),
		},
	}),

	State({
		name = "barf_pre",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("barf_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				local num_loops = BARF_TIMES--inst.sg.mem.lowhealth and BARF_TIMES * 2 or BARF_TIMES
				inst.sg:GoToState("barf_loop", num_loops)
			end),
		},
	}),

	State({
		name = "barf_loop",
		tags = { "busy", "nointerrupt" },

		default_data_for_tools = function(inst, cleanup)
			return 1
		end,

		onenter = function(inst, loops)
			inst.AnimState:PlayAnimation("barf_loop")
			inst.sg.statemem.loops = loops or 1
		end,

		timeline =
		{
			FrameEvent(15, function(inst)
				-- Spawn spike balls. Do not spawn more than the limit!
				local spikeballs = TheSim:FindEntitiesXZ(0, 0, 1000, { "spikeball" })
				local num_spikeballs_on_map = spikeballs and #spikeballs or 0

				local num_balls_to_spawn = math.min(MAX_BARF_BALLS - num_spikeballs_on_map, NUM_BALLS_PER_BARF[#AllPlayers])
				local anglediff = 360 / num_balls_to_spawn
				local current_angle = 0
				for i = 1, num_balls_to_spawn do
					local ball = SpawnPrefab("owlitzer_spikeball")
					ball:Setup(inst)
					local x, z = inst:GetPosition():GetXZ()
					local facing = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
					ball.Transform:SetPosition(x + 0.5 * facing, 5, z)

					local distance = math.max(math.random() * MAX_BARF_DISTANCE, 3)
					local pos = inst:GetPosition()
					local target_pos = pos + Vector3(math.cos(math.rad(current_angle)), 0, -math.sin(math.rad(current_angle))) * distance
					if not TheWorld.Map:IsGroundAtPoint(target_pos) then
						target_pos = TheWorld.Map:FindClosestPointOnWalkableBoundary(target_pos)
					end
					ball.sg:GoToState("thrown", target_pos)

					current_angle = current_angle + anglediff + math.random() * 10 - 5

					--[[if inst.sg.mem.lowhealth then
						ball.components.powermanager:RemoveIgnorePower("owlitzer_super_flap")
					end]]
				end
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.loops > 1 then
					inst.sg:GoToState("barf_loop", inst.sg.statemem.loops - 1)
				else
					inst.sg:GoToState("barf_pst")
				end
			end),
		},

		onexit = function(inst)
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "barf_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("barf_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("float_pre")
			end),
		},

		onexit = function(inst)
			inst:PushEvent("barf_over")
		end
	}),

	State({
		name = "float_to_super_flap_pre",
		tags = { "busy", "nointerrupt", "flying" },

		onenter = function(inst)
			inst.Physics:Stop()
			inst.AnimState:PlayAnimation("return_fly")
			TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Owlitzer_IsFlapping", .5)
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				inst.HitBox:SetInvincible(true)
				inst.sg:AddStateTag("flying_high")

				RemoveStatusEffects(inst)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("float_to_super_flap")
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
		end,
	}),

	State({
		name = "float_to_super_flap",
		tags = { "busy", "nointerrupt", "flying_high" },

		onenter = function(inst, skip_wait)
			inst.AnimState:PlayAnimation("float_idle", true)
			inst.HitBox:SetInvincible(true)

			inst.Physics:SetSnapToGround(false)
			inst.Physics:SetEnabled(false)

			-- Teleport to either the left or right side of the map. Go to the side with less spike balls if possible.
			local midpoint = spawnutil.GetStartPointFromWorld(0.5, 0.5)
			local spikeballs = TheSim:FindEntitiesXZ(0, 0, 1000, { "spikeball" })
			local left_side_balls = 0
			local right_side_balls = 0
			for _, ball in ipairs(spikeballs) do
				local x, y, z = ball:GetPosition():Get()
				if x < midpoint.x then
					left_side_balls = left_side_balls + 1
				else
					right_side_balls = right_side_balls + 1
				end
			end

			local left_side = 0
			if left_side_balls == right_side_balls then
				local rng = krandom.CreateGenerator()
				left_side = rng:Boolean() and 0 or 1
			else
				left_side = left_side_balls > right_side_balls and 0 or 1
			end

			local teleport_pt = spawnutil.GetStartPointFromWorld(left_side, 0.65) + Vector3.unit_y * 15
			inst.Transform:SetPosition(teleport_pt:Get())

			-- Face towards the center of the map.
			local facing_left = inst.Transform:GetFacing() == FACING_LEFT
			if left_side == 0 and facing_left or
				left_side == 1 and not facing_left then
					inst.Transform:FlipFacingAndRotation()
			end

			-- Move to target point.
			local target_pos = Vector3(teleport_pt.x, 5, teleport_pt.z)
			inst.sg.statemem.movetotask = SGCommon.Fns.MoveToPoint(inst, target_pos, 1)
			inst.sg:SetTimeoutAnimFrames(150)

			inst.sg.statemem.skip_wait = skip_wait
		end,

		ontimeout = function(inst)
			TheLog.ch.StateGraph:printf("Warning: Owlitzer state %s timed out.", inst.sg.currentstate.name)
			inst.sg:GoToState("super_flap_pre") -- TODO: someone, super_flap_wait?
		end,

		events =
		{
			EventHandler("movetopoint_complete", function(inst)
				if inst.sg.statemem.skip_wait then
					inst.sg:GoToState("super_flap_pre")
				else
					inst:PushEvent("super_flap_wait")
					inst.sg:GoToState("super_flap_wait")
				end
			end),

			EventHandler("do_super_flap", function(inst)
				inst.sg:GoToState("super_flap_pre")
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.movetotask then
				inst.sg.statemem.movetotask:Cancel()
				inst.sg.statemem.movetotask = nil
			end
			inst.HitBox:SetInvincible(false)
			inst.Physics:SetEnabled(true)
		end,
	}),

	State({
		name = "super_flap_wait",
		tags = { "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("float_idle", true)
			inst.HitBox:SetInvincible(true)
		end,

		events =
		{
			EventHandler("do_super_flap", function(inst)
				inst.sg:GoToState("super_flap_pre")
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
		end,
	}),

	State({
		name = "super_flap_pre",
		tags = { "attack", "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("super_flap_pre")
			inst.HitBox:SetInvincible(true)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("super_flap_loop")
			end),
		},

		timeline =
		{
			FrameEvent(1, function(inst)
				--sound
				local params = {}
				params.fmodevent = fmodtable.Event.owlitzer_super_flap_LP
				params.sound_max_count = 1
				params.autostop = true -- will stop the sound when the thing's destroyed
				params.stopatexitstate = true
				inst.sg.mem.wind_sound = soundutil.PlaySoundData(inst, params)
				soundutil.SetInstanceParameter(inst, inst.sg.mem.wind_sound, "Music_BossPhase", inst.boss_coro.phase)
			end),
			FrameEvent(13, function(inst)
				-- Slowly add speed that pushes things back before max speed.
				inst.components.auraapplyer:SetEffect("owlitzer_super_flap")
				inst.components.auraapplyer:SetRadius(100)
				inst.components.auraapplyer:Enable()
				inst:DoDurationTaskForAnimFrames(30, SuperFlapAccelerate)
				inst.components.hitbox:SetHitFlags(HitGroup.ALL)
			end),
			FrameEvent(40, function(inst)
				local pos = inst:GetPosition()
				local center_pt = spawnutil.GetStartPointFromWorld(0.5, 0.5)
				local diff_x = center_pt.x - pos.x
				--ParticleSystemHelper.MakeEventSpawnParticles(inst, { name = "super_flap_wind", particlefxname = "owlitzer_fullscreen_superflap", use_entity_facing = true, offx = diff_x, offz = center_pt.z })
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)
		end,
	}),

	State({
		name = "super_flap_loop",
		tags = { "attack", "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.HitBox:SetInvincible(true)
			inst.AnimState:PlayAnimation("super_flap_loop", true)
			TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Owlitzer_IsFlapping", 1)

			inst.components.hitbox:SetHitFlags(HitGroup.ALL)

			inst.sg:SetTimeout(FLAP_TIME)

			-- Spawn spikeballs
			local _, minz, _, maxz = TheWorld.Map:GetWalkableBounds()
			local facing = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
			inst.sg.statemem.shoot_spikeballs_task = inst:DoPeriodicTask(SUPER_LOOP_SPIKEBALL_INTERVAL, function()
				local spikeball = SGCommon.Fns.SpawnAtDist(inst, "owlitzer_spikeball", 0)
				if spikeball then
					local pos = inst:GetPosition()
					local distance = krandom.Float(SPAWN_SPIKEBALL_DISTANCE_MIN, SPAWN_SPIKEBALL_DISTANCE_MAX)
					local z_pos = krandom.Float(minz + 0.5, maxz - 0.5)
					local target_pos = Vector3(pos.x + distance * facing, pos.y, z_pos)

					spikeball.Transform:SetPosition(pos.x + krandom.Float(-2, 2), pos.y + 1, pos.z) -- Set so the spikeball's y-position is set to be the same as Owlitzer's

					spikeball.sg:GoToState("thrown", target_pos)
				end
			end)
		end,

		timeline =
		{
			FrameEvent(6, function(inst)
				inst.sg.statemem.flap_speed = GetSuperFlapSpeed(inst, "super_flap_speed")
			end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("super_flap_pst")
		end,

		onexit = function(inst)
			if inst.sg.statemem.shoot_spikeballs_task then
				inst.sg.statemem.shoot_spikeballs_task:Cancel()
			end

			inst.HitBox:SetInvincible(false)
			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)

			if inst.sg.mem.wind_sound then
				soundutil.KillSound(inst, inst.sg.mem.wind_sound)
				inst.sg.mem.wind_sound = nil
			end
		end,
	}),

	State({
		name = "super_flap_pst",
		tags = { "attack", "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.components.auraapplyer:Disable()
			inst.HitBox:SetInvincible(true)
			inst.AnimState:PlayAnimation("super_flap_pst")
			if inst.sg.mem.wind_sound then
				soundutil.KillSound(inst, inst.sg.mem.wind_sound)
				inst.sg.mem.wind_sound = nil
			end
			--ParticleSystemHelper.MakeEventStopParticles(inst, { name = "super_flap_wind" })
		end,

		events =
		{
			EventHandler("animover", function(inst)
				TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Owlitzer_IsFlapping", 0)
				if inst.sg.mem.doflyby then
					inst.sg:GoToState("super_flap_to_fly_by")
				else
					inst.sg:GoToState("super_flap_to_float_pre")
				end
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.components.attacktracker:CompleteActiveAttack()
			inst:PushEvent("superflap_over")
			if inst.sg.mem.wind_sound then
				soundutil.KillSound(inst, inst.sg.mem.wind_sound)
				inst.sg.mem.wind_sound = nil
			end
		end,
	}),

	State({
		name = "super_flap_to_float_pre",
		tags = { "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.HitBox:SetInvincible(true)
			inst.AnimState:PlayAnimation("return_fly")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("fly_high_to_float")
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
		end,
	}),

	State({
		name = "super_flap_to_fly_by",
		tags = { "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.HitBox:SetInvincible(true)
			inst.AnimState:PlayAnimation("fly_by_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("fly_by_pre")
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
		end,
	}),

	State({
		name = "fly_by_pre",
		tags = { "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.HitBox:SetInvincible(true)
			inst.sg:SetTimeout(2)

			inst.components.hitbox:SetHitFlags(HitGroup.ALL)

			-- Teleport to either the left or right side of the map, and aligned with the target's position.
			local teleport_pt = Vector3.zero
			local target = inst.components.combat:GetTarget()

			local rng = krandom.CreateGenerator()
			inst.sg.mem.teleport_x = rng:Boolean() and LEFT_PERCENT or RIGHT_PERCENT
			inst.sg.mem.teleport_z = rng:Boolean() and TOP_PERCENT or BOTTOM_PERCENT
			teleport_pt = spawnutil.GetStartPointFromWorld(inst.sg.mem.teleport_x, inst.sg.mem.teleport_z)

			if target then
				teleport_pt.z = target:GetPosition().z
			end
			inst.Transform:SetPosition(teleport_pt:Get())

			-- Face towards the center of the map.
			local facing_left = inst.Transform:GetFacing() == FACING_LEFT
			if inst.sg.mem.teleport_x == LEFT_PERCENT and facing_left or
				inst.sg.mem.teleport_x == RIGHT_PERCENT and not facing_left then
					inst.Transform:FlipFacingAndRotation()
			end

			-- Spawn target FX
			local z2 = (inst.sg.mem.teleport_z == TOP_PERCENT and 0.975) or 0.7
			local fx_x, fx_z = spawnutil.GetStartPointFromWorld(0, z2):GetXZ()
			if target then
				fx_z = target:GetPosition().z
			end

			local pos = inst:GetPosition()
			local fx_params =
			{
				name = "flyby_warning",
				particlefxname = "owlitzer_flyby_warning_wind",
				use_entity_facing = true,
				stopatexitstate = true,
			}
			ParticleSystemHelper.HandleEventSpawnParticles(inst, fx_params)

			-- Wind effect in fly by attack area
			inst.sg.statemem.flap_speed = GetSuperFlapSpeed(inst, "fly_by_pre_speed")
			inst.components.auraapplyer:SetEffect("owlitzer_super_flap")
			local facing = facing_left and -1 or 1
			inst.components.auraapplyer:SetupBeamHitbox(pos.x - fx_x - 2, pos.z - fx_z + 200 * facing, 5)
			inst.components.auraapplyer:Enable()
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("fly_by_loop")
		end,

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.components.auraapplyer:Disable()
			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)
		end,
	}),

	State({
		name = "fly_by_loop",
		tags = { "busy", "nointerrupt", "flying_high" },

		default_data_for_tools = function(inst)
			inst.sg.mem.teleport_x = RIGHT_PERCENT
			inst.sg.mem.teleport_z = TOP_PERCENT
		end,

		onenter = function(inst)
			inst.HitBox:SetInvincible(true)
			inst.AnimState:PlayAnimation("fly_by_loop", true)

			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.hitbox:SetHitFlags(HitGroup.ALL)

			-- Fly across to the opposite side.
			local FLY_TIME = 1.5
			inst.sg:SetTimeout(FLY_TIME)

			local x2 = (inst.sg.mem.teleport_x == LEFT_PERCENT and RIGHT_PERCENT) or LEFT_PERCENT
			local target_pt = spawnutil.GetStartPointFromWorld(x2, inst.sg.mem.teleport_z)
			local target = inst.components.combat:GetTarget()
			if target then
				target_pt.z = target:GetPosition().z
			end
			inst.sg.statemem.movetotask = SGCommon.Fns.MoveToPoint(inst, target_pt, FLY_TIME)

			-- Calculate velocity so that if we're teleported, resume at this velocity.
			local distance = math.abs((target_pt - inst:GetPosition()):Length())
			inst.sg.statemem.moveto_speed = distance / FLY_TIME

			---sound
			-- inst.SoundEmitter:PlaySound(fmodtable.Event.owlitzer_flyby)
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnFlyByHitBoxTriggered),
			EventHandler("teleport_end", function(inst)
				-- If teleported, keep moving
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.moveto_speed)
			end),
		},

		onupdate = function(inst)
			inst.components.hitbox:PushBeam(-1.00, 3.00, 6.00, HitPriority.BOSS_DEFAULT)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("super_flap_to_float_pre")
		end,

		onexit = function(inst)
			if inst.sg.statemem.movetotask then
				inst.sg.statemem.movetotask:Cancel()
				inst.sg.statemem.movetotask = nil
			end
			inst.HitBox:SetInvincible(false)
			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)
			inst.components.hitbox:StopRepeatTargetDelay()

			ParticleSystemHelper.MakeEventStopParticles(inst, { name = "owlitzer_flyby_warning_wind" })
		end,
	}),

	State({
		name = "fly_high_to_float",
		tags = { "busy", "nointerrupt", "flying_high" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("float_idle", true)
			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)

			inst.Physics:SetSnapToGround(false)
			inst.Physics:SetEnabled(false)

			-- Teleport to the center of the map above the origin.
			inst.Transform:SetPosition(0, 10, 0)
			local target = inst.components.combat:GetTarget()
			SGCommon.Fns.FaceTarget(inst, target, true)

			-- Move to target point.
			local target_pos = Vector3.zero
			inst.sg.statemem.movetotask = SGCommon.Fns.MoveToPoint(inst, target_pos, 0.5)
			inst.sg:SetTimeoutAnimFrames(150)
		end,

		ontimeout = function(inst)
			TheLog.ch.StateGraph:printf("Warning: Owlitzer state %s timed out.", inst.sg.currentstate.name)
			inst.sg:GoToState("idle")
		end,

		timeline =
		{
			FrameEvent(12, function(inst)
				inst.HitBox:SetInvincible(false)
				inst.Physics:SetEnabled(true)
			end),
		},

		events =
		{
			EventHandler("movetopoint_complete", function(inst)
				inst.HitBox:SetInvincible(false)
				inst.Physics:SetEnabled(true)
				inst.Physics:SetSnapToGround(true)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.movetotask then
				inst.sg.statemem.movetotask:Cancel()
				inst.sg.statemem.movetotask = nil
			end
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
			inst.Physics:SetEnabled(true)
			inst.Physics:SetSnapToGround(true)

			inst.components.powermanager:SetCanReceivePowers(true)
		end,
	}),
}


local FLYING_TAGS = { "flying" }
local nointerrupttags = { "nointerrupt" }

SGCommon.States.AddIdleStates(states,
{
	modifyanim = "float_",
	num_idle_behaviours = 2,
	addtags = FLYING_TAGS,
})

SGCommon.States.AddTurnStates(states,
{
	modifyanim = "fly_turn",
	addtags = FLYING_TAGS,

	onenterpst = function(inst)
		SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.walk_speed * 0.5)
	end
})
SGCommon.States.AddLocomoteStates(states, "fly",
{
	addtags = lume.concat(nointerrupttags, FLYING_TAGS),
	--[[loopevents =
	{
		EventHandler("walktorun",
			function(inst)
				inst.sg:GoToState("walk_to_run")
			end),
	},]]
})

SGCommon.States.AddHitStates(states, SGCommon.Fns.ChooseAttack, { modifyanim = "hit_air", addtags = FLYING_TAGS })
SGCommon.States.AddKnockbackStates(states, { modifyanim = "flinch_air", addtags = FLYING_TAGS })
SGCommon.States.AddKnockdownStates(states)
SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddAttackPre(states, "slash_air",
{
	alwaysforceattack = true,
	addtags = FLYING_TAGS,
	onenter_fn = function(inst)
		inst.Physics:Stop()
	end,
})
SGCommon.States.AddAttackHold(states, "slash_air", { alwaysforceattack = true, addtags = FLYING_TAGS })

SGCommon.States.AddAttackPre(states, "slash2_air", { alwaysforceattack = true })
SGCommon.States.AddAttackHold(states, "slash2_air", { alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "wind_gust",
{
	alwaysforceattack = true,
	onenter_fn = function(inst)
		inst.Physics:Stop()

		-- Check the positioning of owlitzer to its target & determine what state to play:
		local target = inst.components.combat:GetTarget()
		if target and not inst.sg.mem.in_position then
			local minx, minz, maxx, maxz = TheWorld.Map:GetWalkableBounds()
			local targetpos = target:GetPosition()
			local pos = inst:GetPosition()
			local is_left_side_closer = pos.x - minx < maxx - pos.x

			if is_left_side_closer then
				-- In between the side of the level & target; fly through the player & turn around.
				if (pos.x >= minx and pos.x <= targetpos.x) then
					inst.sg:GoToState("turn_fly_forward_ground", target)
				-- The target is in between owlitzer & the side of the level, but too close to the side; jump backwards.
				elseif (targetpos.x >= minx and targetpos.x <= pos.x) then
					inst.sg:GoToState("fly_back_ground", target)
				end
			else -- right side is closer
				if (pos.x <= maxx and pos.x >= targetpos.x) then
					inst.sg:GoToState("turn_fly_forward_ground", target)
				elseif (targetpos.x <= maxx and targetpos.x >= pos.x and maxx - pos.x) then
					inst.sg:GoToState("fly_back_ground", target)
				end
			end

			inst.sg.mem.in_position = true
			return
		else
			inst.sg.mem.in_position = nil
		end

		if inst.sg.laststate.tags["flying"] then
			inst.AnimState:PlayAnimation("wind_gust_fly_pre")
		else
			inst.AnimState:PlayAnimation("wind_gust_ground_pre")
		end
	end,
})
SGCommon.States.AddAttackHold(states, "wind_gust", { alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "snatch",
{
	alwaysforceattack = true,
	timeline =
	{
		-- Code Generated by PivotTrack.jsfl
		FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-40/150) end),
		FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(-88/150) end),
		FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(-132/150) end),
		-- End Generated Code
	},
})
SGCommon.States.AddAttackHold(states, "snatch",
{
	alwaysforceattack = true,
	timeline =
	{
		-- Code Generated by PivotTrack.jsfl
		FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-16/150) end),
		FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-12/150) end),
		FrameEvent(6, function(inst) inst.Physics:MoveRelFacing(-8/150) end),
		-- End Generated Code
	},
})

SGCommon.States.AddAttackPre(states, "dive_slam",
{
	alwaysforceattack = true,
	addtags = FLYING_TAGS,
	timeline =
	{
		FrameEvent(2, function(inst)
			local target = inst.components.combat:GetTarget()
			if target then
				inst.sg.statemem.movetotask = SGCommon.Fns.MoveToTarget(inst, { target = target, duration = 8 * ANIM_FRAMES / SECONDS })
			end
		end),
		FrameEvent(4, function(inst)
			inst.sg:AddStateTag("flying_high")
			inst.HitBox:SetEnabled(false)
			TheCamera:SetZoom(12)
		end),
	},
	onexit_fn = function(inst)
		inst.HitBox:SetEnabled(true)
		TheCamera:SetZoom(0)
	end
})

SGCommon.States.AddAttackHold(states, "dive_slam",
{
	alwaysforceattack = true,
	addtags = lume.concat(FLYING_TAGS, { "flying_high" }),
	onenter_fn = function(inst)
		inst.Physics:Stop()
		TheCamera:SetZoom(12)

		local target = inst.components.combat:GetTarget()
		if target then
			local targetpos = target:GetPosition()
			--SpawnLandFX(inst, targetpos)
		end
	end,
	onexit_fn = function(inst)
		TheCamera:SetZoom(0)
	end
})

SGCommon.States.AddAttackPre(states, "dive_bomb",
{
	alwaysforceattack = true,
	addtags = FLYING_TAGS,
	timeline =
	{
		FrameEvent(44, function(inst)
			inst.HitBox:SetInvincible(true)
		end),
	},

	onexit_fn = function(inst)
		inst.HitBox:SetInvincible(false)
	end,
})
SGCommon.States.AddAttackHold(states, "dive_bomb",
{
	alwaysforceattack = true,
	addtags = { "flying_high" },

	onenter_fn = function(inst)
		inst.HitBox:SetInvincible(true)
	end,

	timeline =
	{
		-- startup frames (90) - pre anim frames (48) - time before attack to show target FX (0.15s -> 9 frames)
		FrameEvent(33, function(inst)
			-- Select a random target.
			local target = inst:GetRandomEntityByTagInRange(1000, inst.components.combat:GetTargetTags(), true, true)
			if not target then return end

			inst.components.combat:SetTarget(target)
			local targetpos = target:GetPosition()

			--SpawnLandFX(inst, targetpos)
			inst.sg.mem.dive_pos = targetpos
		end),
	},

	onexit_fn = function(inst)
		inst.HitBox:SetInvincible(false)
	end,
})

SGCommon.States.AddAttackPre(states, "phase_transition_get_off_me",
{
	alwaysforceattack = true,
	onenter_fn = function(inst)
		inst.components.combat:SetDamageReceivedMult("phase_transition", PHASE_TRANSITION_DAMAGE_REDUCTION)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.FaceTarget(inst, target, true)
		end
	end,
	onexit_fn = function(inst)
		inst.components.combat:RemoveDamageReceivedMult("phase_transition")
	end,
})
SGCommon.States.AddAttackHold(states, "phase_transition_get_off_me",
{
	alwaysforceattack = true,
	onenter_fn = function(inst)
		inst.components.combat:SetDamageReceivedMult("phase_transition", PHASE_TRANSITION_DAMAGE_REDUCTION)
	end,
	onexit_fn = function(inst)
		inst.components.combat:RemoveDamageReceivedMult("phase_transition")
	end,
})

SGCommon.States.AddMonsterDeathStates(states)

SGCommon.States.AddBossDeathStates(states,
{
	cine_timeline =
	{
		-- Code Generated by PivotTrack.jsfl
		FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(-160/150) end),
		FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(-206/150) end),
		FrameEvent(7, function(inst) inst.Physics:MoveRelFacing(-120/150) end),
		FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(-120/150) end),
		FrameEvent(13, function(inst) inst.Physics:MoveRelFacing(-92/150) end),
		FrameEvent(16, function(inst) inst.Physics:MoveRelFacing(-20/150) end),
		FrameEvent(20, function(inst) inst.Physics:MoveRelFacing(20/150) end),
		FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(44/150) end),
		FrameEvent(23, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(45, function(inst) inst.Physics:MoveRelFacing(24/150) end),
		FrameEvent(47, function(inst) inst.Physics:MoveRelFacing(92/150) end),
		FrameEvent(49, function(inst) inst.Physics:MoveRelFacing(102/150) end),
		FrameEvent(51, function(inst) inst.Physics:MoveRelFacing(100/150) end),
		FrameEvent(54, function(inst) inst.Physics:MoveRelFacing(76/150) end),
		FrameEvent(56, function(inst) inst.Physics:MoveRelFacing(58/150) end),
		FrameEvent(58, function(inst) inst.Physics:MoveRelFacing(56/150) end),
		FrameEvent(60, function(inst) inst.Physics:MoveRelFacing(56/150) end),
		FrameEvent(62, function(inst) inst.Physics:MoveRelFacing(60/150) end),
		FrameEvent(64, function(inst) inst.Physics:MoveRelFacing(84/150) end),
		FrameEvent(66, function(inst) inst.Physics:MoveRelFacing(68/150) end),
		FrameEvent(68, function(inst) inst.Physics:MoveRelFacing(48/150) end),
		FrameEvent(70, function(inst) inst.Physics:MoveRelFacing(52/150) end),
		FrameEvent(72, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(74, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(76, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(78, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(80, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(82, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		FrameEvent(84, function(inst) inst.Physics:MoveRelFacing(56/150) end),
		FrameEvent(87, function(inst) inst.Physics:MoveRelFacing(56/150) end),
		FrameEvent(90, function(inst) inst.Physics:MoveRelFacing(64/150) end),
		FrameEvent(94, function(inst) inst.Physics:MoveRelFacing(52/150) end),
		FrameEvent(98, function(inst) inst.Physics:MoveRelFacing(36/150) end),
		FrameEvent(101, function(inst) inst.Physics:MoveRelFacing(52/150) end),
		FrameEvent(104, function(inst) inst.Physics:MoveRelFacing(48/150) end),
		FrameEvent(107, function(inst) inst.Physics:MoveRelFacing(60/150) end),
		FrameEvent(110, function(inst) inst.Physics:MoveRelFacing(64/150) end),
		FrameEvent(112, function(inst) inst.Physics:MoveRelFacing(76/150) end),
		FrameEvent(114, function(inst) inst.Physics:MoveRelFacing(76/150) end),
		FrameEvent(116, function(inst) inst.Physics:MoveRelFacing(48/150) end),
		FrameEvent(117, function(inst) inst.Physics:MoveRelFacing(80/150) end),
	},
})

SGRegistry:AddData("sg_owlitzer", states)

return StateGraph("sg_owlitzer", states, events, "idle")
