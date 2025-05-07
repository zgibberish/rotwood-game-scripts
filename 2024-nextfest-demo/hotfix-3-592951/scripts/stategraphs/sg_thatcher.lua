local SGCommon = require "stategraphs.sg_common"
local SGBossCommon = require "stategraphs.sg_boss_common"
local TargetRange = require "targetrange"
local monsterutil = require "util.monsterutil"
local playerutil = require "util.playerutil"
local bossutil = require "prefabs.bossutil"
local spawnutil = require "util.spawnutil"

local function OnSwingShortHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "swing_short",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 0.6,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 0.5,
	})
end

local function OnSwingLongHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "swing_long",
		hitstoplevel = HitStopLevel.HEAVY,
		set_dir_angle_to_target = true,
		pushback = 0.9,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 0.5,
	})
end

local function OnSwingUppercutHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "swing_long",
		hitstoplevel = HitStopLevel.HEAVY,
		hitflags = inst.sg.statemem.is_high and Attack.HitFlags.AIR_HIGH or Attack.HitFlags.DEFAULT,
		set_dir_angle_to_target = true,
		pushback = 0.9,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 0.5,
	})

	inst.sg.statemem.hit = hit
end

local function OnHookHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "hook",
		hitstoplevel = inst.sg.statemem.is_hooking and HitStopLevel.LIGHT or HitStopLevel.HEAVY,
		set_dir_angle_to_target = not inst.sg.statemem.is_hooking,
		pushback = inst.sg.statemem.is_hooking and -2.0 or 0.5,
		combat_attack_fn =
			(inst.sg.statemem.do_basic_attack and "DoBasicAttack") or
			(inst.sg.statemem.is_hooking and "DoKnockbackAttack") or
			"DoKnockdownAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 0.5,
	})

	inst.sg.statemem.hit = inst.sg.statemem.is_hooking and hit
end

local function OnHookUppercutHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "hook_uppercut",
		hitstoplevel = HitStopLevel.HEAVY,
		set_dir_angle_to_target = true,
		pushback = 1.6,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 0.5,
	})

	inst.sg.statemem.hit = hit
end

local function OnDoubleShortSlashHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "double_short_slash",
		hitstoplevel = inst.sg.statemem.is_second_attack and HitStopLevel.HEAVY or HitStopLevel.LIGHT,
		set_dir_angle_to_target = true,
		pushback = inst.sg.statemem.is_second_attack and 1.2 or 0.6,
		combat_attack_fn = inst.sg.statemem.is_second_attack and "DoKnockdownAttack" or "DoKnockbackAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 0.5,
	})
end

local function OnFullSwingHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "full_swing",
		hitstoplevel = inst.sg.statemem.is_last_attack and HitStopLevel.MEDIUM or HitStopLevel.LIGHT,
		hitflags = inst.sg.statemem.is_air_attack and Attack.HitFlags.AIR_HIGH or Attack.HitFlags.DEFAULT,
		set_dir_angle_to_target = true,
		pushback = inst.sg.statemem.is_last_attack and 1.0 or 0.4,
		combat_attack_fn = inst.sg.statemem.is_last_attack and "DoKnockdownAttack" or "DoKnockbackAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 0.5,
	})
end

local function OnSwingSmashHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "swing_smash",
		hitstoplevel = inst.sg.statemem.is_last_attack and HitStopLevel.HEAVY or HitStopLevel.LIGHT,
		set_dir_angle_to_target = true,
		pushback = inst.sg.statemem.is_last_attack and 1.5 or 0.4,
		combat_attack_fn = inst.sg.statemem.is_last_attack and "DoKnockdownAttack" or "DoKnockbackAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 0.5,
	})
end

local function OnAcidSplashHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "acid_splash",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.4,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = "fx_hit_player_round",
		hit_fx_offset_x = 0.5,
	})
end

local function ChooseIdleBehavior(inst)
	if not inst.components.timer:HasTimer("idlebehavior_cd") then
		local threat = playerutil.GetRandomLivingPlayer()
		if not threat then
			inst.sg:GoToState("idle_behaviour")
			return true
		end
	end
	return false
end

local function RemoveStatusEffects(inst)
	inst.components.powermanager:ResetData()
	inst.components.powermanager:SetCanReceivePowers(false)
end

local function SpawnAcidBall(inst, size, target_pos, offset_x, offset_y)
	local projectile = SpawnPrefab("thatcher_acidball", inst)
	projectile:Setup(inst)

	if inst.Transform:GetFacing() == FACING_LEFT then
		offset_x = offset_x and offset_x * -1 or 0
	end

	local offset = Vector3(offset_x or 0, offset_y or 0, 0)
	local x, z = inst.Transform:GetWorldXZ()
	projectile.Transform:SetPosition(x + offset.x, offset.y, z + offset.z)

	-- Make sure the target position in on the map. If not, place at the edge of the map taking into account the acid's size.
	if not TheWorld.Map:IsWalkableAtXZ(target_pos.x, target_pos.z) then
		target_pos.x, target_pos.z = TheWorld.Map:FindClosestXZOnWalkableBoundaryToXZ(target_pos.x, target_pos.z)
		local acid_radius = size == "large" and 4 or 2
		local v = Vector3(target_pos.x, 0, target_pos.z)
		local to_point, len = v:normalized()
		len = math.abs(len - acid_radius)
		target_pos = to_point:scale(len)
	end

	projectile.sg:GoToState("ball", { targetpos = target_pos, size = size })
end

local acidSpitPatterns =
{
	-- Phase 1: a single acid in a big area
	{
		{ x = 10, z = 0 },
	},

	-- Phase 2: a straight line of acid
	{
		{ x = 5, z = 0 },
		{ x = 9, z = 0 },
		{ x = 13, z = 0 },
		{ x = 17, z = 0 },
		{ x = 21, z = 0 },
		{ x = 25, z = 0 },
	},

	-- Phase 3: a vertical column of acid
	{
		{ x = 12, z = -12 },
		{ x = 12, z = -8 },
		{ x = 12, z = -4 },
		{ x = 12, z = 0 },
		{ x = 12, z = 4 },
		{ x = 12, z = 8 },
		{ x = 12, z = 12 },
	},
}

local acidSpitSizes = { "large", "medium", "medium" }

local function SpawnAcidSpitPattern(inst)
	local spawn_offset_x = 3
	local spawn_offset_y = 2

	local current_phase = inst.boss_coro:CurrentPhase() or 1

	local pos = inst:GetPosition()
	local facing = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
	local size = acidSpitSizes[current_phase] or "medium"

	for _, target_offset in ipairs(acidSpitPatterns[current_phase]) do
		local target_pos = pos + Vector3(target_offset.x * facing, 0, target_offset.z)
		SpawnAcidBall(inst, size, target_pos, spawn_offset_x, spawn_offset_y)
	end
end

local ACID_SPLASH_SPAWN_OFFSET_X <const> = 0
local ACID_SPLASH_SPAWN_OFFSET_Y <const> = 5

local ACID_SPLASH_LINE_DIRECTIONS <const> = 8
local ACID_SPLASH_LINE_UNIT_DISTANCE <const> = 5
local ACID_SPLASH_LINE_UNITS <const> = 4

local ACID_SPLASH_GRID_ROWS <const> = 5
local ACID_SPLASH_GRID_COLUMNS <const> = 9
local ACID_SPLASH_GRID_UNIT_DISTANCE <const> = 5

local BACKGROUND_JUMP_POSITION <const> = Vector3(0, 0, 20)
local ACID_SPLASH_POSITION <const> = Vector3(0, 0, -5)
local ACID_SPIT_RANGE = 10

local acidSplashPatterns =
{
	-- Outward lines pattern
	function(inst)
		local angle_delta = 360 / (ACID_SPLASH_LINE_DIRECTIONS or 360)
		local current_angle = 0
		local pos = inst:GetPosition()

		for i = 1, ACID_SPLASH_LINE_DIRECTIONS do
			local current_distance = ACID_SPLASH_LINE_UNIT_DISTANCE

			-- TODO: spawn less acid projectiles on the up/down directions to avoid overlapping due to less vertical height in the boss room

			for j = 1, ACID_SPLASH_LINE_UNITS do
				local target_pos = pos + Vector3(math.cos(math.rad(current_angle)), 0, math.sin(math.rad(current_angle))) * current_distance
				SpawnAcidBall(inst, "small", target_pos, ACID_SPLASH_SPAWN_OFFSET_X, ACID_SPLASH_SPAWN_OFFSET_Y)

				current_distance = current_distance + ACID_SPLASH_LINE_UNIT_DISTANCE
			end

			current_angle = current_angle + angle_delta
		end
	end,

	-- Grid pattern
	function(inst)
		local start_x = -20
		local start_z = 9
		local pos = inst:GetPosition()

		for i = 1, ACID_SPLASH_GRID_ROWS do

			-- TODO: spawn less acid projectiles on the bottom two rows to avoid overlapping due to less horizontal height in the boss room

			-- 'Checkerboard' the grid pattern
			local x = i % 2 == 0 and start_x + ACID_SPLASH_GRID_UNIT_DISTANCE / 2 or start_x
			local num_columns = i % 2 == 0 and ACID_SPLASH_GRID_COLUMNS - 1 or ACID_SPLASH_GRID_COLUMNS

			for j = 1, num_columns do
				local target_pos = pos + Vector3(x + ACID_SPLASH_GRID_UNIT_DISTANCE * (j - 1), 0, start_z - ACID_SPLASH_GRID_UNIT_DISTANCE * (i - 1))
				SpawnAcidBall(inst, "small", target_pos, ACID_SPLASH_SPAWN_OFFSET_X, ACID_SPLASH_SPAWN_OFFSET_Y)
			end
		end
	end,
}

local function SpawnAcidSplash(inst)
	local pattern = math.random(1, #acidSplashPatterns)
	acidSplashPatterns[pattern](inst)
end

local SWING_SMASH_STUCK_TIME <const> = 4

local events =
{
	EventHandler("dodge", function(inst, dir)
		if not (inst.sg:HasStateTag("busy") or inst.components.timer:HasTimer("dodge_cd")) then
			if dir == nil then
				local target = inst.components.combat:GetTarget()
				if target ~= nil then
					local facing = inst.Transform:GetFacing()
					local x, z = inst.Transform:GetWorldXZ()
					local x1, z1 = target.Transform:GetWorldXZ()
					local dx = x1 - x
					local dz = z1 - z
					local absdz = math.abs(dz)
					local right = x > x1 or (x == x1 and facing == FACING_LEFT)
					if absdz < inst.Physics:GetDepth() + target.Physics:GetDepth() + 2 then
						--Too close, so dodge horizontally to avoid clipping
						dir = right and 0 or 180
					else
						local turn = right == (facing == FACING_RIGHT)
						local dist = turn and 6.85 or 6.25
						if absdz < dist then
							local xdist = math.sqrt(dist * dist - dz * dz)
							if xdist + math.abs(dx) > inst.Physics:GetSize() + target.Physics:GetSize() + 1 then
								--Close enough to dodge diagonally without clipping
								dir = math.deg(math.atan(-dz, right and xdist or -xdist))
							end
						end
					end
				else
					dir = inst.Transform:GetFacingRotation() + 180
				end
			end
			if dir ~= nil then
				if DiffAngle(inst.Transform:GetFacingRotation(), dir) < 90 then
					inst.Transform:SetRotation(dir)
					inst.sg:GoToState("turn_dodge_pre")
				else
					inst.Transform:SetRotation(dir + 180)
					inst.sg:GoToState("dodge")
				end
			end
		end
	end),

	EventHandler("fullswing", function(inst)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.FaceActionTarget(inst, target, true)
		end
		bossutil.DoEventTransition(inst, "full_swing_pre")
	end),
	EventHandler("hook", function(inst)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.FaceActionTarget(inst, target, true)
		end
		bossutil.DoEventTransition(inst, "hook_pre")
	end),
	EventHandler("swing_smash", function(inst)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.FaceActionTarget(inst, target, true)
		end
		bossutil.DoEventTransition(inst, "swing_smash_pre")
	end),
	EventHandler("acid_splash", function(inst)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.FaceActionTarget(inst, target, true)
		end
		bossutil.DoEventTransition(inst, "acid_splash_pre")
	end),
	EventHandler("acid_coating", function(inst)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.FaceActionTarget(inst, target, true)
		end
		bossutil.DoEventTransition(inst, "acid_coating")
	end),

	-- Check to enter transition states
	EventHandler("boss_phase_changed", function(inst, phase)
		local target = inst.components.combat:GetTarget()
		if target then
			SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "phase_transition", target)
		else
			inst.sg:GoToState("phase_transition")
		end
	end),
}
monsterutil.AddBossCommonEvents(events,
{
	locomote_data = { run = true, turn = true },
})
monsterutil.AddOptionalMonsterEvents(events,
{
	idlebehavior_fn = ChooseIdleBehavior,
})

local states =
{
	State({
		name = "introduction",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, attack_fn)
			inst.AnimState:PlayAnimation("intro")
			inst.sg.statemem.start_pos = inst:GetPosition()
		end,

		events =
		{
			EventHandler("cine_skipped", function(inst)
				local pos = inst.sg.statemem.start_pos
				inst.Transform:SetPosition(pos.x, pos.y, pos.z)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "introduction2",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, attack_fn)
			inst.AnimState:PlayAnimation("intro_part2")
		end,
	}),

	State({
		name = "taunt",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("behavior1")
			inst.components.timer:StartTimer("taunt_cd", 12 + math.random() * 5, true)
		end,

		timeline =
		{
			FrameEvent(42, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
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
		name = "dodge",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("backhop")
			inst.components.timer:StartTimer("dodge_cd", 4, true)
		end,

		timeline =
		{
			--physics
			FrameEvent(1, function(inst) inst.Physics:SetMotorVel(-8) end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(-12) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(-18) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(-16) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(-12) end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(-6) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(-5) end),
			FrameEvent(15, function(inst) inst.Physics:SetMotorVel(-4) end),
			FrameEvent(16, function(inst) inst.Physics:SetMotorVel(-3) end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(18, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(19, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(20, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
			FrameEvent(13, function(inst)
				inst.sg:RemoveStateTag("airborne")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst) inst.Physics:Stop() end,
	}),

	State({
		name = "turn_dodge_pre",
		tags = { "turning", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("turn_backhop_pre")
			inst.components.timer:StartTimer("dodge_cd", 4, true)
		end,

		timeline =
		{
			--physics
			FrameEvent(1, function(inst) inst.Physics:SetMotorVel(14) end),
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(18) end),
			FrameEvent(4, function(inst) inst.Physics:SetMotorVel(16) end),
			--

			FrameEvent(4, function(inst)
				inst.sg:AddStateTag("airborne")
				inst.sg:AddStateTag("nointerrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.dodging = true
				inst:FlipFacingAndRotation()
				inst.sg:GoToState("turn_dodge_pst")
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.dodging then
				inst.Physics:Stop()
			end
		end,
	}),

	State({
		name = "turn_dodge_pst",
		tags = { "busy", "airborne", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("turn_backhop_pst")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(-14) end),
			FrameEvent(3, function(inst) inst.Physics:SetMotorVel(-12) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(-6) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVel(-5) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(-4) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(-3) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(-2) end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(-1) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(-.5) end),
			FrameEvent(15, function(inst) inst.Physics:Stop() end),
			--

			FrameEvent(8, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg:RemoveStateTag("nointerrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
		end,
	}),

	State({
		name = "phase_transition",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("phase_transition")
			RemoveStatusEffects(inst)
		end,

		timeline =
		{
			FrameEvent(72, function(inst)
				inst.sg:AddStateTag("airborne")

				inst.HitBox:SetEnabled(false)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.Transform:SetPosition(BACKGROUND_JUMP_POSITION:Get())
				inst:DoTaskInTime(1, function()
					inst.sg:GoToState("phase_transition_part2")
				end)
			end),
		},
	}),

	State({
		name = "phase_transition_part2",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("phase_transition_part2")
			inst.components.combat:SetDamageReceivedMult("phase_transition", 0)

			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
			inst.Physics:SetEnabled(false)
		end,

		timeline =
		{
			FrameEvent(115, function(inst)
				inst.sg:AddStateTag("airborne")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				local center_pt = spawnutil.GetStartPointFromWorld(0.5, 0.5)
				inst.Transform:SetPosition(center_pt:Get())
				inst.sg:GoToState("phase_transition_pst")
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
			inst.Physics:SetEnabled(true)
			inst.components.combat:RemoveDamageReceivedMult("phase_transition")
		end,
	}),

	State({
		name = "phase_transition_pst",
		tags = { "busy", "nointerrupt", "airborne" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("phase_transition_part3")

			inst.HitBox:SetInvincible(true)
			inst.HitBox:SetEnabled(false)
			inst.Physics:SetEnabled(false)
		end,

		timeline =
		{
			FrameEvent(20, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.HitBox:SetInvincible(false)
				inst.HitBox:SetEnabled(true)
				inst.Physics:SetEnabled(true)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.HitBox:SetEnabled(true)
			inst.Physics:SetEnabled(true)
		end,
	}),

	State({
		name = "swing_short",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swing_short")
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(7) end),
			FrameEvent(8, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(9, function(inst) inst.Physics:SetMotorVel(3) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(12, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(13, function(inst) inst.Physics:Stop() end),
			--

			--head hitbox
			FrameEvent(4, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(4, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.1) end),
			FrameEvent(6, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 2) end),
			FrameEvent(8, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.8) end),
			FrameEvent(10, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.6) end),
			FrameEvent(12, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.5) end),
			--

			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(-8.50, 3.80, 3.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.20, 8.20, 2.50, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.00, 8.20, 2.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("vulnerable")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSwingShortHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("swing_up")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "swing_long",
		tags = { "attack", "busy", "nointerrupt"},

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swing_long")
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(6) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(10) end),
			FrameEvent(11, function(inst) inst.Physics:SetMotorVel(8) end),
			FrameEvent(13, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(14, function(inst) inst.Physics:SetMotorVel(3) end),
			FrameEvent(15, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(16, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(18, function(inst) inst.Physics:Stop() end),
			--

			--head hitbox
			FrameEvent(9, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(9, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.7) end),
			FrameEvent(11, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 2.8) end),
			FrameEvent(13, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 2.2) end),
			FrameEvent(15, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.5) end),
			--

			FrameEvent(6, function(inst)
				inst.components.hitbox:PushOffsetBeam(-11.00, -3.00, 2.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushOffsetBeam(-7.00, 4.50, 4.00, -1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(11, function(inst)
				inst.components.hitbox:PushBeam(1.00, 12.50, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(13, function(inst)
				inst.components.hitbox:PushOffsetBeam(-6.40, 10.00, 2.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				inst.sg:AddStateTag("vulnerable")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSwingLongHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("swing_pst", inst.sg.statemem.hit)
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "swing_up",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swing_uppercut")
		end,

		timeline =
		{
			--physics
			FrameEvent(0, function(inst) inst.Physics:SetMotorVel(10) end),
			FrameEvent(6, function(inst) inst.Physics:SetMotorVel(8) end),
			FrameEvent(10, function(inst) inst.Physics:SetMotorVel(6) end),
			FrameEvent(13, function(inst) inst.Physics:Stop() end),
			FrameEvent(16, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(22, function(inst) inst.Physics:SetMotorVel(6) end),
			FrameEvent(25, function(inst) inst.Physics:SetMotorVel(5) end),
			FrameEvent(28, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(30, function(inst) inst.Physics:SetMotorVel(8) end),
			FrameEvent(33, function(inst) inst.Physics:SetMotorVel(6) end),
			FrameEvent(34, function(inst) inst.Physics:SetMotorVel(5) end),
			FrameEvent(35, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(36, function(inst) inst.Physics:SetMotorVel(3) end),
			FrameEvent(37, function(inst) inst.Physics:SetMotorVel(2) end),
			FrameEvent(38, function(inst) inst.Physics:SetMotorVel(1) end),
			FrameEvent(39, function(inst) inst.Physics:SetMotorVel(.5) end),
			FrameEvent(40, function(inst) inst.Physics:Stop() end),
			--

			--headhitbox
			FrameEvent(0, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(0, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .7) end),
			FrameEvent(2, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
			FrameEvent(28, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(28, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 2.5) end),
			FrameEvent(30, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 3) end),
			FrameEvent(32, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
			FrameEvent(51, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(51, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .7) end),
			FrameEvent(53, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .4) end),
			FrameEvent(55, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
			--

			FrameEvent(28, function(inst)
				inst.components.hitbox:PushOffsetBeam(-5.20, -2.10, 1.50, -0.85, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(30, function(inst)
				inst.components.hitbox:PushOffsetBeam(-3.60, 10.50, 2.50, -0.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(32, function(inst)
				inst.components.hitbox:PushBeam(4.00, 12.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(33, function(inst)
				inst.sg.statemem.is_high = true
				inst.components.hitbox:PushBeam(-1.50, 13.50, 2.00, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSwingUppercutHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.hit and not inst.components.timer:HasTimer("taunt_cd") then
					inst.sg:GoToState("taunt")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "swing_pst",
		tags = { "attack", "busy", "nointerrupt", "vulnerable" },

		onenter = function(inst, hit)
			inst.AnimState:PlayAnimation("swing_pst")
			inst.sg.statemem.hit = hit
		end,

		timeline =
		{
			--head hitbox
			FrameEvent(0, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(0, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.3) end),
			FrameEvent(2, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.1) end),
			FrameEvent(4, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .6) end),
			FrameEvent(6, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .4) end),
			FrameEvent(8, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
			--

			FrameEvent(2, function(inst)
				inst.sg:RemoveStateTag("vulnerable")
			end),
			FrameEvent(8, function(inst)
				inst.sg:AddStateTag("caninterrupt")
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				if inst.sg.statemem.hit and not inst.components.timer:HasTimer("taunt_cd") then
					inst.sg:GoToState("taunt")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "hook",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hook")
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			-- physics
			FrameEvent(17, function(inst) inst.Physics:SetMotorVel(4) end),
			FrameEvent(20, function(inst) inst.Physics:Stop() end),

			-- hitbox
			FrameEvent(14, function(inst)
				inst.components.hitbox:PushOffsetBeam(-6.00, 2.00, 2.20, -0.60, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(16, function(inst)
				inst.components.hitbox:PushOffsetBeam(-8.00, -2.00, 2.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(17, function(inst)
				inst.components.hitbox:PushOffsetBeam(-8.00, 0.00, 3.00, 3.80, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(18, function(inst)
				inst.components.hitbox:PushOffsetBeam(-5.00, 4.90, 2.50, 4.20, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(19, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.00, 8.40, 2.50, 3.80, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(21, function(inst)
				inst.sg.statemem.do_basic_attack = true
				inst.components.hitbox:PushOffsetBeam(2.00, 10.50, 3.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(23, function(inst)
				inst.components.hitbox:PushOffsetBeam(4.00, 10.50, 2.50, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(24, function(inst)
				inst.sg.statemem.do_basic_attack = false
				inst.components.hitbox:StopRepeatTargetDelay()
			end),

			FrameEvent(32, function(inst)
				inst.sg.statemem.is_hooking = true
				inst.components.hitbox:StartRepeatTargetDelay()
			end),
			FrameEvent(33, function(inst)
				inst.components.hitbox:PushBeam(3.00, 6.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHookHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.hit then
					inst.sg:GoToState("hook_uppercut")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "hook_uppercut",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hook_shoryuken")
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			-- tags
			FrameEvent(22, function(inst) inst.sg.AddStateTag("flying_high") end),
			FrameEvent(41, function(inst) inst.sg.RemoveStateTag("flying_high") end),

			-- physics
			-- Code Generated by PivotTrack.jsfl
			FrameEvent(9, function(inst) inst.Physics:MoveRelFacing(160/150) end),
			FrameEvent(11, function(inst) inst.Physics:MoveRelFacing(44/150) end),
			FrameEvent(13, function(inst) inst.Physics:MoveRelFacing(20/150) end),
			FrameEvent(15, function(inst) inst.Physics:MoveRelFacing(12/150) end),
			FrameEvent(18, function(inst) inst.Physics:MoveRelFacing(124/150) end),
			FrameEvent(20, function(inst) inst.Physics:MoveRelFacing(180/150) end),
			FrameEvent(22, function(inst) inst.Physics:MoveRelFacing(180/150) end),
			FrameEvent(24, function(inst) inst.Physics:MoveRelFacing(84/150) end),
			FrameEvent(26, function(inst) inst.Physics:MoveRelFacing(36/150) end),
			FrameEvent(28, function(inst) inst.Physics:MoveRelFacing(52/150) end),
			FrameEvent(31, function(inst) inst.Physics:MoveRelFacing(48/150) end),
			FrameEvent(34, function(inst) inst.Physics:MoveRelFacing(52/150) end),
			FrameEvent(37, function(inst) inst.Physics:MoveRelFacing(52/150) end),
			FrameEvent(39, function(inst) inst.Physics:MoveRelFacing(36/150) end),
			FrameEvent(41, function(inst) inst.Physics:MoveRelFacing(14/150) end),
			-- End Generated Code

			-- hitbox
			FrameEvent(24, function(inst)
				inst.components.hitbox:PushBeam(1.80, 9.00, 2.40, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(25, function(inst)
				inst.components.hitbox:PushBeam(4.00, 14.50, 2.40, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnHookUppercutHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.hit and not inst.components.timer:HasTimer("taunt_cd") then
					inst.sg:GoToState("taunt")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
			inst:PushEvent("hook_over")
		end,
	}),

	State({
		name = "double_short_slash",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("double_short_slash")
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			-- physics
			-- Code Generated by PivotTrack.jsfl
			FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(112/150) end),
			FrameEvent(3, function(inst) inst.Physics:MoveRelFacing(240/150) end),
			FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(300/150) end),
			FrameEvent(8, function(inst) inst.Physics:MoveRelFacing(240/150) end),
			FrameEvent(11, function(inst) inst.Physics:MoveRelFacing(184/150) end),
			FrameEvent(13, function(inst) inst.Physics:MoveRelFacing(144/150) end),
			FrameEvent(23, function(inst) inst.Physics:MoveRelFacing(36/150) end),
			FrameEvent(25, function(inst) inst.Physics:MoveRelFacing(80/150) end),
			FrameEvent(26, function(inst) inst.Physics:MoveRelFacing(125/150) end),
			-- End Generated Code

			-- hitbox
			FrameEvent(13, function(inst)
				inst.components.hitbox:PushBeam(1.80, 9.00, 2.40, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				inst.components.hitbox:PushOffsetBeam(0.00, 9.00, 2.40, -1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(15, function(inst)
				inst.components.hitbox:StopRepeatTargetDelay()
			end),

			FrameEvent(22, function(inst)
				inst.sg.statemem.is_second_attack = true
				inst.components.hitbox:StartRepeatTargetDelay()
			end),
			FrameEvent(23, function(inst)
				inst.components.hitbox:PushOffsetBeam(-3.00, 1.90, 2.40, -0.20, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(25, function(inst)
				inst.components.hitbox:PushOffsetBeam(1.80, 10.85, 2.80, -0.80, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(26, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.50, 16.00, 3.50, 2.40, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnDoubleShortSlashHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.hit and not inst.components.timer:HasTimer("taunt_cd") then
					inst.sg:GoToState("taunt")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "full_swing",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("full_swing")
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			-- hitbox

			-- Swing 1
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushOffsetBeam(-11.00, -3.00, 2.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				inst.components.hitbox:PushOffsetBeam(-8.50, 4.50, 4.00, -1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(16, function(inst)
				inst.components.hitbox:PushBeam(2.00, 11.50, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(18, function(inst)
				inst.components.hitbox:PushOffsetBeam(5.00, 13.00, 4.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(20, function(inst)
				inst.components.hitbox:PushOffsetBeam(1.00, 12.00, 2.00, 5.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(21, function(inst)
				inst.components.hitbox:PushOffsetBeam(-0.50, 7.00, 2.00, 5.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(22, function(inst)
				inst.components.hitbox:PushOffsetBeam(-11.50, 0.00, 3.00, 4.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(24, function(inst)
				inst.components.hitbox:PushOffsetBeam(-9.00, -3.50, 3.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(26, function(inst)
				inst.components.hitbox:PushOffsetBeam(-12.00, -4.50, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),

			-- Swing 2
			FrameEvent(27, function(inst)
				inst.components.hitbox:StopRepeatTargetDelay()

				inst.sg.statemem.is_last_attack = true
				inst.components.hitbox:StartRepeatTargetDelay()
			end),

			FrameEvent(28, function(inst)
				inst.components.hitbox:PushOffsetBeam(-11.00, -3.00, 2.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(30, function(inst)
				inst.components.hitbox:PushOffsetBeam(-8.50, 4.50, 4.00, -1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(32, function(inst)
				inst.components.hitbox:PushBeam(2.00, 11.50, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(34, function(inst)
				inst.components.hitbox:PushOffsetBeam(5.00, 13.00, 4.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(36, function(inst)
				inst.components.hitbox:PushOffsetBeam(1.00, 12.00, 2.00, 5.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(37, function(inst)
				inst.components.hitbox:PushOffsetBeam(-0.50, 7.00, 2.00, 5.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(38, function(inst)
				inst.components.hitbox:PushOffsetBeam(-11.50, 0.00, 3.00, 4.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(40, function(inst)
				inst.components.hitbox:PushOffsetBeam(-9.00, -3.50, 3.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(42, function(inst)
				inst.components.hitbox:PushOffsetBeam(-12.00, -4.50, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),

			-- Finish
			FrameEvent(44, function(inst)
				inst.components.hitbox:PushOffsetBeam(-11.00, -3.00, 2.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(46, function(inst)
				inst.components.hitbox:PushOffsetBeam(-7.00, -1.00, 2.50, -1.50, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnFullSwingHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.hit and not inst.components.timer:HasTimer("taunt_cd") then
					inst.sg:GoToState("taunt")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
			inst:PushEvent("fullswing_over")
		end,
	}),

	State({
		name = "swing_smash",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swing_smash")
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			-- physics
			-- Code Generated by PivotTrack.jsfl
			FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(52/150) end),
			FrameEvent(16, function(inst) inst.Physics:MoveRelFacing(104/150) end),
			FrameEvent(18, function(inst) inst.Physics:MoveRelFacing(196/150) end),
			FrameEvent(26, function(inst) inst.Physics:MoveRelFacing(40/150) end),
			FrameEvent(28, function(inst) inst.Physics:MoveRelFacing(244/150) end),
			FrameEvent(30, function(inst) inst.Physics:MoveRelFacing(300/150) end),
			FrameEvent(32, function(inst) inst.Physics:MoveRelFacing(90/150) end),
			FrameEvent(34, function(inst) inst.Physics:MoveRelFacing(81/150) end),
			FrameEvent(36, function(inst) inst.Physics:MoveRelFacing(81/150) end),
			FrameEvent(44, function(inst) inst.Physics:MoveRelFacing(300/150) end),
			FrameEvent(46, function(inst) inst.Physics:MoveRelFacing(240/150) end),
			FrameEvent(48, function(inst) inst.Physics:MoveRelFacing(136/150) end),
			FrameEvent(50, function(inst) inst.Physics:MoveRelFacing(92/150) end),
			FrameEvent(52, function(inst) inst.Physics:MoveRelFacing(104/150) end),
			FrameEvent(54, function(inst) inst.Physics:MoveRelFacing(52/150) end),
			FrameEvent(56, function(inst) inst.Physics:MoveRelFacing(128/150) end),
			FrameEvent(58, function(inst) inst.Physics:MoveRelFacing(148/150) end),
			FrameEvent(60, function(inst) inst.Physics:MoveRelFacing(144/150) end),
			FrameEvent(61, function(inst) inst.Physics:MoveRelFacing(108/150) end),
			FrameEvent(62, function(inst) inst.Physics:MoveRelFacing(120/150) end),
			-- End Generated Code

			-- hitbox
			-- Swing 1
			FrameEvent(11, function(inst)
				inst.components.hitbox:PushOffsetBeam(-11.00, -3.00, 2.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushOffsetBeam(-7.50, 4.50, 4.00, -1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				inst.components.hitbox:PushBeam(2.00, 11.50, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(16, function(inst)
				inst.components.hitbox:PushOffsetBeam(5.00, 13.00, 4.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(18, function(inst)
				inst.components.hitbox:PushOffsetBeam(-4.50, 12.00, 3.00, 4.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(20, function(inst)
				inst.components.hitbox:PushOffsetBeam(-8.00, -0.50, 3.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),

			-- Swing 2
			FrameEvent(21, function(inst)
				inst.components.hitbox:StopRepeatTargetDelay()
			end),
			FrameEvent(22, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushOffsetBeam(-9.50, -3.00, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(23, function(inst)
				inst.components.hitbox:PushOffsetBeam(-9.50, -3.00, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(24, function(inst)
				inst.components.hitbox:PushOffsetBeam(-7.50, 4.50, 4.00, -1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(26, function(inst)
				inst.components.hitbox:PushOffsetBeam(2.00, 15.30, 4.00, -1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(28, function(inst)
				inst.components.hitbox:PushOffsetBeam(5.00, 13.00, 4.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(30, function(inst)
				inst.components.hitbox:PushOffsetBeam(-0.50, 15.00, 3.00, 4.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(32, function(inst)
				inst.components.hitbox:PushOffsetBeam(-9.50, -1.50, 3.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(34, function(inst)
				inst.components.hitbox:PushOffsetBeam(-11.00, -3.00, 2.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(36, function(inst)
				inst.components.hitbox:PushOffsetBeam(-6.00, 0.00, 2.50, -1.50, HitPriority.BOSS_DEFAULT)
			end),

			-- Final attack
			FrameEvent(60, function(inst)
				inst.components.hitbox:StopRepeatTargetDelay()

				inst.sg.statemem.is_last_attack = true
				inst.components.hitbox:StartRepeatTargetDelay()
			end),
			FrameEvent(61, function(inst)
				inst.sg.statemem.is_air_attack = true
				inst.components.hitbox:PushBeam(2.00, 8.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(62, function(inst)
				inst.sg.statemem.is_air_attack = nil
				inst.components.hitbox:PushBeam(0.00, 6.50, 3.00, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnSwingSmashHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("swing_smash_stuck_loop")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.attacktracker:CompleteActiveAttack()
		end,
	}),

	State({
		name = "swing_smash_stuck_loop",
		tags = { "attack", "busy", "nointerrupt", "vulnerable" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swing_smash_stuck_loop", true)
			inst.sg:SetTimeout(SWING_SMASH_STUCK_TIME)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("swing_smash_pst")
		end,
	}),

	State({
		name = "swing_smash_pst",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swing_smash_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst:PushEvent("swing_smash_over")
		end,
	}),

	State({
		name = "acid_spit_reposition",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			-- Determine which hop animation to play depending on its current position & facing
			local facing = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
			local pos = inst:GetPosition()

			local target = inst.components.combat:GetTarget()
			if target then
				local targetpos = target:GetPosition()
				local dist_to_target = pos:dist(targetpos)
				if dist_to_target < ACID_SPIT_RANGE then
					inst.AnimState:PlayAnimation("backhop")
				elseif dist_to_target < ACID_SPIT_RANGE then
					inst.AnimState:PlayAnimation("hop_forward")
				end

				-- Too close to the edge; move to the other side
				local reposition_pt = Vector3(targetpos.x - ACID_SPIT_RANGE * facing, 0, targetpos.z)
				if not TheWorld.Map:IsWalkableAtXZ(reposition_pt.x, reposition_pt.z) then
					reposition_pt = Vector3(targetpos.x + ACID_SPIT_RANGE * facing, 0, targetpos.z)
					-- There's also an edge on the other side; move up to the edge
					if not TheWorld.Map:IsWalkableAtXZ(reposition_pt.x, reposition_pt.z) then
						reposition_pt = TheWorld.Map:FindClosestPointOnWalkableBoundary(reposition_pt)
					else
						inst.Physics:StartPassingThroughObjects()
					end
				end

				-- Move to a point in front/back from where the player is standing, within acid spit range
				inst.sg.statemem.movetotask = SGCommon.Fns.MoveToPoint(inst, reposition_pt, 0.25)
				inst.sg:SetTimeoutAnimFrames(150)
			else
				inst.sg:GoToState("acid_spit_pre")
				return
			end
		end,

		ontimeout = function(inst)
			TheLog.ch.StateGraph:printf("Warning: Thatcher state %s timed out.", inst.sg.currentstate.name)
			inst.sg:GoToState("acid_spit_pre")
		end,

		events =
		{
			EventHandler("movetopoint_complete", function(inst)
				local target = inst.components.combat:GetTarget()
				if target then
					SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "acid_spit_pre", target)
				else
					inst.sg:GoToState("acid_spit_pre")
				end

			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.movetotask then
				inst.sg.statemem.movetotask:Cancel()
				inst.sg.statemem.movetotask = nil
			end
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "acid_spit",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("acid_spit")
		end,

		timeline =
		{
			--head hitbox
			FrameEvent(22, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(22, function(inst) inst.components.offsethitboxes:Move("offsethitbox", .8) end),
			FrameEvent(24, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1) end),
			FrameEvent(26, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.2) end),
			FrameEvent(28, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),

			-- Spit acid
			FrameEvent(4, function(inst)
				SpawnAcidSpitPattern(inst)
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
		end,
	}),

	State({
		name = "acid_coating",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("acid_coating")
		end,

		timeline =
		{
			-- Spawn acid
			FrameEvent(32, function(inst)
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
			inst:PushEvent("acid_coating_over")
		end,
	}),

	State({
		name = "acid_splash_reposition",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			-- Determine which hop animation to play depending on its current position & facing
			local facing = inst.Transform:GetFacing() == FACING_LEFT and -1 or 1
			local pos = inst:GetPosition()

			-- back hop
			if (pos.x > ACID_SPLASH_POSITION.x and facing > 0) or pos.x < ACID_SPLASH_POSITION.x and facing < 0 then
				inst.AnimState:PlayAnimation("backhop")
			-- forward hop
			else
				inst.AnimState:PlayAnimation("hop_forward")
			end

			-- Move to target point.
			inst.sg.statemem.movetotask = SGCommon.Fns.MoveToPoint(inst, ACID_SPLASH_POSITION, 0.25)
			inst.sg:SetTimeoutAnimFrames(150)
		end,

		ontimeout = function(inst)
			TheLog.ch.StateGraph:printf("Warning: Thatcher state %s timed out.", inst.sg.currentstate.name)
			inst.sg:GoToState("acid_splash_pre")
		end,

		events =
		{
			EventHandler("movetopoint_complete", function(inst)
				local target = inst.components.combat:GetTarget()
				if target then
					SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "acid_splash_pre", target)
				else
					inst.sg:GoToState("acid_splash_pre")
				end

			end),
		},

		onexit = function(inst)
			if inst.sg.statemem.movetotask then
				inst.sg.statemem.movetotask:Cancel()
				inst.sg.statemem.movetotask = nil
			end
		end,
	}),

	State({
		name = "acid_splash",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("acid_splash")
			inst.components.hitbox:StartRepeatTargetDelayAnimFrames(3)
		end,

		timeline =
		{
			--head hitbox
			FrameEvent(0, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", true) end),
			FrameEvent(0, function(inst) inst.components.offsethitboxes:Move("offsethitbox", 1.1) end),
			FrameEvent(3, function(inst) inst.components.offsethitboxes:SetEnabled("offsethitbox", false) end),
			--

			-- Spawn acid
			FrameEvent(35, function(inst)
				SpawnAcidSplash(inst)
			end),

			-- Forward & top spin
			FrameEvent(66, function(inst)
				inst.components.hitbox:PushBeam(1.00, 3.50, 2.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(67, function(inst)
				inst.components.hitbox:PushBeam(0.00, 4.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(68, function(inst)
				inst.components.hitbox:PushBeam(1.00, 5.00, 4.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(69, function(inst)
				inst.components.hitbox:PushBeam(1.00, 5.00, 3.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(70, function(inst)
				inst.components.hitbox:PushBeam(0.00, 4.50, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(71, function(inst)
				inst.components.hitbox:PushBeam(0.00, 4.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(72, function(inst)
				inst.components.hitbox:PushOffsetBeam(-4.00, 2.50, 2.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(73, function(inst)
				inst.components.hitbox:PushOffsetBeam(-3.00, 2.00, 2.00, 2.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(74, function(inst)
				inst.components.hitbox:PushOffsetBeam(-4.00, -0.50, 2.50, 1.50, HitPriority.BOSS_DEFAULT)
			end),

			-- Back & below spin
			FrameEvent(75, function(inst)
				inst.components.hitbox:PushBeam(-4.50, -1.00, 3.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(76, function(inst)
				inst.components.hitbox:PushBeam(-4.50, -1.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(77, function(inst)
				inst.components.hitbox:PushBeam(-4.50, -1.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(78, function(inst)
				inst.components.hitbox:PushBeam(-4.50, -1.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(79, function(inst)
				inst.components.hitbox:PushBeam(-5.00, -1.00, 3.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(80, function(inst)
				inst.components.hitbox:PushOffsetBeam(-3.00, 0.00, 2.00, -1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(81, function(inst)
				inst.components.hitbox:PushOffsetBeam(-3.00, 0.00, 3.50, -1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(82, function(inst)
				inst.components.hitbox:PushOffsetBeam(-3.50, 0.00, 2.50, -1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(83, function(inst)
				inst.components.hitbox:PushOffsetBeam(-0.50, 2.50, 2.00, -1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(83, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.00, 3.00, 2.00, -0.50, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnAcidSplashHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst:PushEvent("acid_splash_over")
		end,
	}),
}

local nointerrupttags = { "nointerrupt" }

SGCommon.States.AddIdleStates(states, { num_idle_behaviours = 3, })
SGCommon.States.AddTurnStates(states)

SGCommon.States.AddLocomoteStates(states, "run",
{
	isRunState = true,
	addtags = nointerrupttags,
})

SGCommon.States.AddHitStates(states)
SGCommon.States.AddKnockbackStates(states, { movement_frames = 12 })
SGCommon.States.AddKnockdownStates(states, { movement_frames = 12 })
SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddAttackPre(states, "swing_short", { alwaysforceattack = true })
--SGCommon.States.AddAttackHold(states, "swing_short", { alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "swing_long", { alwaysforceattack = true })
--SGCommon.States.AddAttackHold(states, "swing_long", { alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "acid_spit",
{
	alwaysforceattack = true,
	onenter_fn = function(inst)
		if not inst.sg.mem.in_position then
			inst.sg.mem.in_position = true
			inst.sg:GoToState("acid_spit_reposition")
			return
		else
			inst.sg.mem.in_position = nil
		end
	end,
})
SGCommon.States.AddAttackHold(states, "acid_spit", { alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "hook", { alwaysforceattack = true })
SGCommon.States.AddAttackHold(states, "hook", { alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "double_short_slash", { alwaysforceattack = true })
SGCommon.States.AddAttackHold(states, "double_short_slash", { alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "full_swing", { alwaysforceattack = true })
SGCommon.States.AddAttackHold(states, "full_swing", { alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "swing_smash", {
	alwaysforceattack = true,
	onenter_fn = function(inst)
		inst.components.hitbox:StartRepeatTargetDelay()
	end,
	timeline =
	{
		FrameEvent(9, function(inst)
			inst.components.hitbox:PushBeam(-7.00, -2.00, 3.00, HitPriority.BOSS_DEFAULT)
		end),
		FrameEvent(10, function(inst)
			inst.components.hitbox:PushBeam(-7.00, -2.00, 3.00, HitPriority.BOSS_DEFAULT)
		end),
	},
	addevents =
	{
		EventHandler("hitboxtriggered", OnSwingSmashHitBoxTriggered),
	},
	onexit_fn = function(inst)
		inst.components.hitbox:StopRepeatTargetDelay()
	end,
})
SGCommon.States.AddAttackHold(states, "swing_smash", { alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "acid_splash",
{
	alwaysforceattack = true,
	onenter_fn = function(inst)
		if not inst.sg.mem.in_position then
			inst.sg.mem.in_position = true
			inst.sg:GoToState("acid_splash_reposition")
			return
		else
			inst.sg.mem.in_position = nil
		end
	end,
})
SGCommon.States.AddAttackHold(states, "acid_splash",
{
	alwaysforceattack = true,
	onenter_fn = function(inst)
		inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
		inst.components.offsethitboxes:Move("offsethitbox", 1.1)
	end,
	onexit_fn = function(inst)
		inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
	end,
})

SGCommon.States.AddMonsterDeathStates(states)
SGBossCommon.States.AddBossStates(states)

SGRegistry:AddData("sg_bandicoot", states)

return StateGraph("sg_thatcher", states, events, "idle")
