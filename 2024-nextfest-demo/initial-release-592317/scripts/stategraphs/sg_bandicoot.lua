local SGCommon = require "stategraphs.sg_common"
local SGBossCommon = require "stategraphs.sg_boss_common"
local TargetRange = require "targetrange"
local playerutil = require "util.playerutil"
local monsterutil = require "util.monsterutil"
local bossutil = require "prefabs.bossutil"
local spawnutil = require "util.spawnutil"
local krandom = require "util.krandom"
local audioid = require "defs.sound.audioid"
local fmodtable = require "defs.sound.fmodtable"
local soundutil = require "util.soundutil"
local ParticleSystemHelper = require "util.particlesystemhelper"
local prop_destructible = require "prefabs.customscript.prop_destructible"

local function GetPhase(inst)
	-- Clones always use the parent's current phase
	local parent = inst:HasTag("clone") and inst.parent or inst
	return parent.boss_coro:CurrentPhase()
end

local function CheckLaughOnHitPlayer(inst, targets)
	for i, target in ipairs(targets) do
		if inst.components.combat:CanTargetEntity(target) then
			inst.sg.statemem.do_laugh = true
			return
		end
	end
end

local function OnSwipeHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "swipe",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 1.4,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		hitflags = Attack.HitFlags.LOW_ATTACK, -- Can jump over tail spin
	})

	if hit then
		CheckLaughOnHitPlayer(inst, data.targets)
	end
end

--[[local function OnSwipe2HitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "swipe2",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.7,
		combat_attack_fn = "DoKnockbackAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})

	if hit then
		CheckLaughOnHitPlayer(inst, data.targets)
	end
end]]

local function OnSwipeToTailSweepHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "swipe_to_tail_sweep",
		set_dir_angle_to_target = true,
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 1.8,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		hitflags = not inst.sg.statemem.is_high_attack and Attack.HitFlags.LOW_ATTACK or nil, -- Can jump over tail spin (the first one)
	})
end

--[[local function OnTailSpinHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "tailspin",
		set_dir_angle_to_target = true,
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 1.8,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
		hitflags = Attack.HitFlags.LOW_ATTACK, -- Can jump over tail spin
	})
end]]

--[[local function OnTailWhipHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "tailwhip",
		hitstoplevel = HitStopLevel.LIGHT,
		pushback = 1.5,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end]]

local function OnPeekABooHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "peekaboo",
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 1.4,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})

	if hit then
		CheckLaughOnHitPlayer(inst, data.targets)
	end
end

local function OnBiteHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "bite",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 0.4,
		combat_attack_fn = "DoKnockdownAttack",
		reduce_friendly_fire = true,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnBiteDownHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "bite_down",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 0.4,
		combat_attack_fn = "DoKnockdownAttack",
		reduce_friendly_fire = true,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnRageBiteHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "rage_bite",
		hitstoplevel = HitStopLevel.HEAVY,
		pushback = 0.4,
		combat_attack_fn = "DoKnockdownAttack",
		reduce_friendly_fire = true,
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})
end

local function OnHowlHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "howl",
		hitstoplevel = HitStopLevel.LIGHT,
		pushback = 1.5,
		combat_attack_fn = "DoKnockbackAttack",
	})
end

local function OnExplodeHitBoxTriggered(inst, data)
	SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "clone_explode",
		hitstoplevel = HitStopLevel.HEAVIER,
		set_dir_angle_to_target = true,
		pushback = 1.5,
		hitstun_anim_frames = 4,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = "hits_bomb",
		hit_fx_offset_x = 0.5,
		hit_target_pre_fn = function(attacker, v)
			if v.entity:HasTag("player") then
				if v:IsLocal() then	-- Only spawn the hurt_explosion for local players
					TheDungeon.HUD.effects.hurt_explosion:StartOneShot()
				end

				local createHitTrail = false
				if not v.hitTrailEntity or not v.hitTrailEntity:IsValid() then
					createHitTrail = true
				else
					local timer = v.hitTrailEntity.components.timer
					if timer:GetTimeRemaining() > 0 then
						timer:SetTimeRemaining("hitexpiry", HIT_TRAIL_LIFETIME)
					else
						-- handle corner case of timer finished but emitter has not stopped
						-- just forget about it and create a new trail entity
						createHitTrail = true
					end
				end

				if createHitTrail then
					ParticleSystemHelper.AttachParticlesForTime(v, "bomb_hit_trail", "weapon_back01", 2.5, inst)
				end
			end
		end,
		hit_target_pst_fn = function(attacker, v)
			local hit_ground = SpawnHitFx("hits_bomb_ground", attacker, v, 0, 0, nil, HitStopLevel.HEAVIER)
			if hit_ground then
				hit_ground.AnimState:SetScale(0.25, 0.25)
			end
		end,
	})
end

local function OnRageTransitionHitBoxTriggered(inst, data)
	local hit = SGCommon.Events.OnHitboxTriggered(inst, data, {
		attackdata_id = "rage_transition",
		hitstoplevel = HitStopLevel.LIGHT,
		pushback = 3,
		combat_attack_fn = "DoKnockdownAttack",
		hit_fx = monsterutil.defaultAttackHitFX,
		hit_fx_offset_x = 0.5,
	})

	if hit then
		CheckLaughOnHitPlayer(inst, data.targets)
	end
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

local TELEPORT_SPEED = 20

local function GetSource(inst)
	return inst.parent or inst
end

local function GetHidingSpots()
	local hiding_spots = TheSim:FindEntitiesXZ(0, 0, 10000, { "hidingspot" })
	return hiding_spots
end

local function GetRandomHidingSpot()
	local hiding_spots = GetHidingSpots()
	local eligible_spots = {}

	-- Don't include hiding spots with stuff already hiding in it, or dead ones.
	for _, hiding_spot in ipairs(hiding_spots) do
		if hiding_spot:IsValid() and not hiding_spot:IsDead() then
			table.insert(eligible_spots, hiding_spot)
		end
	end

	return #eligible_spots > 0 and eligible_spots[math.random(1, #eligible_spots)] or nil
end

local function UnhideFromHidingSpot(inst)
	local hiding_spot = inst.sg.mem.hiding_spot
	if hiding_spot then
		inst.sg.mem.hiding_spot = nil
	end
	inst.components.powermanager:SetCanReceivePowers(true) -- Prevent Bandicoot from gaining any powers while in this state
end

local function OnHidingSpotHit(inst, source, data)
	if not inst:IsValid() or inst:IsDead() then
		return
	end

	-- If hiding at the hit object, play hit anim.
	if source ~= inst.sg.mem.hiding_spot then
		return
	else
		UnhideFromHidingSpot(inst)
	end

	-- face the direction of the attacker from data
	if data and data.attack then
		local attack_angle = data.attack:GetDir()
		local facing_rotation = inst.Transform:GetFacingRotation()
		inst.Transform:SetRotation(facing_rotation) -- Reset rotation to facing so it moves out left or right from the hiding spot.
		if attack_angle == facing_rotation then
			inst.Transform:FlipFacingAndRotation()
		end
	end

	inst.sg:GoToState("flinch_pillar")
end

local function HideInHidingSpot(inst, hiding_spot)
	inst.sg.mem.hiding_spot = hiding_spot

	inst.components.powermanager:ResetData() -- Clear all powers, to remove any stacks of status effects
	inst.components.powermanager:SetCanReceivePowers(false) -- Prevent Bandicoot from gaining any powers while in this state

	-- Listen for if the hiding spot is killed.
	-- hiding_spot:ListenForEvent("attacked",
	-- function(source, data)
	-- 	OnHidingSpotHit(inst, source, data)
	-- end,
	-- hiding_spot)
	hiding_spot:ListenForEvent("dying",
	function(source, data)
		OnHidingSpotHit(inst, source, data)
	end,
	hiding_spot)
end

local MOB_PREFAB = "mothball"
local NUM_MOBS_TO_SPAWN_MIN = 1
local NUM_MOBS_TO_SPAWN_MAX = 3

local NUM_MOBS_TO_SPAWN_CLONEDEATH_MIN = 6
local NUM_MOBS_TO_SPAWN_CLONEDEATH_MAX = 8

local function SpawnMobsFromHidingSpot(inst, hiding_spot)
	if not hiding_spot then
		return
	end

	-- Only spawn mobs while less than the limit for the room.
	local source = GetSource(inst) -- Clones don't have max_mobs tuning data

	-- Don't spawn if the boss is dead
	if source and (source:IsDying() or source:IsDead()) then
		return
	end

	local max_mobs = (source ~= nil and source.tuning ~= nil and source.tuning.max_mobs ~= nil) and source.tuning.max_mobs[#AllPlayers] or 15
	local mobs = TheSim:FindEntitiesXZ(0, 0, 10000, { "mob" }, { "boss", "clone" })
	local num_mobs = #mobs

	for i = 1, math.random(NUM_MOBS_TO_SPAWN_MIN, NUM_MOBS_TO_SPAWN_MAX) do
		if num_mobs >= max_mobs then
			return
		end

		local ent = SpawnPrefab(MOB_PREFAB, hiding_spot)
		if ent then
			num_mobs = num_mobs + 1

			local x, y, z = hiding_spot.Transform:GetWorldPosition()

			ent.Transform:SetPosition(x, y, z)
			if math.random() < 0.5 then
				ent.Transform:FlipFacingAndRotation()
			end

			ent.sg:GoToState("spawn_battlefield")
		end
	end
end

local function SpawnMobsFromCloneDeath(inst)
	-- Only spawn mobs while less than the limit for the room.
	local source = GetSource(inst) -- Clones don't have max_mobs tuning data
	local max_mobs = (source ~= nil and source.tuning ~= nil and source.tuning.max_mobs ~= nil) and source.tuning.max_mobs[#AllPlayers] or 15
	local mobs = TheSim:FindEntitiesXZ(0, 0, 10000, { "mob" }, { "boss", "clone" })
	local num_mobs = #mobs

	local x, y, z = inst.Transform:GetWorldPosition()

	for i = 1, math.random(NUM_MOBS_TO_SPAWN_CLONEDEATH_MIN, NUM_MOBS_TO_SPAWN_CLONEDEATH_MAX) do
		if num_mobs >= max_mobs then
			return
		end

		local ent = SpawnPrefab(MOB_PREFAB, inst)
		if ent then
			num_mobs = num_mobs + 1

			ent.Transform:SetPosition(x, y, z)
			if math.random() < 0.5 then
				ent.Transform:FlipFacingAndRotation()
			end

			ent.sg:GoToState("spawn_battlefield")
		end
	end
end

local NUM_SPORES_TO_SPAWN_MIN = 1
local NUM_SPORES_TO_SPAWN_MAX = 3

local function SpawnSpores(inst)
	inst:DoTaskInTime(0.5, function(inst)
		-- Get the list of empty trap spawn locations to spawn a spore at.
		local trap_spawnpoints = {}

		local sc = TheWorld.components.spawncoordinator
		for _, spawner in pairs(sc.trap_locations) do
			local x, _, z = spawner.spawner_ent:GetPosition():Get()
			local traps = TheSim:FindEntitiesXZ(x, z, 3, {"trap"})

			if #traps <= 0 then
				table.insert(trap_spawnpoints, spawner)
			end
		end

		local num_to_spawn = math.min(math.random(NUM_SPORES_TO_SPAWN_MIN, NUM_SPORES_TO_SPAWN_MAX), #trap_spawnpoints)
		for i = 1, num_to_spawn do
			-- Select a spore type to spawn
			local rng = krandom.CreateGenerator()
			local source = GetSource(inst) -- Clones don't have spore_weights tuning data
			local spore_prefab = rng:WeightedChoice(source.tuning.spore_weights)

			if spore_prefab ~= nil then
				local spore = SpawnPrefab(spore_prefab)
				if spore then
					local index = math.random(1, #trap_spawnpoints)
					local selected_spawner = trap_spawnpoints[index]
					local pos = selected_spawner.spawner_ent:GetPosition()
					spore.Transform:SetPosition(pos:Get())
					spore.sg:GoToState("grow")

					table.remove(trap_spawnpoints, index)
				end
			end
		end
	end)
end

local MAX_STALACTITES = 16

local function CanSpawnStalactites(inst)
	local hiding_spots = GetHidingSpots()
	return table.count(hiding_spots) < MAX_STALACTITES
end

local function DoStalactiteFallPresentation(inst)
	-- Shake the camera for all players
	ShakeAllCameras(CAMERASHAKE.VERTICAL, 1.5, 0.02, 1)

	local params = {}
	params.fmodevent = fmodtable.Event.earthquake_low_rumble_LP
	soundutil.PlaySoundData(inst, params, "rumble", inst)
end

local function SpawnStalactites(inst)
	DoStalactiteFallPresentation(inst)
	inst:PushEvent("spawn_stalactites")
end

local function DestroyStalacties(inst)
	local hiding_spots = GetHidingSpots()
	for k, hiding_spot in pairs(hiding_spots) do
		hiding_spot:PushEvent("death")
	end
end

local TELEPORT_HIDE_OFFSET_X = 5
local TELEPORT_RAGE_OFFSET_X = 15

local function TeleportToTarget(inst, teleport_target, offset)
	-- Teleport to a walkable point in front or behind a random target.
	local target = teleport_target or inst:GetRandomEntityByTagInRange(10000, inst.components.combat:GetTargetTags(), true, true)
	if not target then return end

	inst.components.combat:SetTarget(target)

	local offset = math.random() < 0.5 and -offset or offset
	local targetpos = target:GetPosition()

	-- If the teleport offset point is out of bounds, teleport to the other side.
	if not TheWorld.Map:IsWalkableAtXZ(targetpos.x + offset, targetpos.z) then
		offset = -offset
	end

	inst.Transform:SetPosition(targetpos.x + offset, targetpos.y, targetpos.z)

	-- Face the target
	SGCommon.Fns.FaceTarget(inst, target, true)
end

local BITE_DOWN_ANGLE_MIN <const> = 75
local BITE_DOWN_ANGLE_MAX <const> = 105
local function UpdateBiteDownAngle(inst)
	local facingrot = inst.Transform:GetFacingRotation()
	local target = inst.components.combat:GetTarget()
	if target and target:IsValid() then
		local angleToTarget = inst:GetAngleTo(target)
		angleToTarget = ReduceAngle(angleToTarget)
		local move_angle = math.clamp(angleToTarget, BITE_DOWN_ANGLE_MIN, BITE_DOWN_ANGLE_MAX)
		inst.Transform:SetRotation(move_angle)
	end
end

local function SpawnClones(inst, num_clones)

	-- Calculate which directions bandicoot & clones should move to.
	local monsterlist = {}
	table.insert(monsterlist, inst)

	-- Spawn clones.
	for i = 1, num_clones or 1 do
		local clone = SpawnPrefab("bandicoot_clone")
		if clone ~= nil then
			clone.parent = inst
			table.insert(monsterlist, clone)

			-- Get clones to face the same way as the parent
			if clone.Transform:GetFacing() ~= inst.Transform:GetFacing() then
				clone:FlipFacingAndRotation()
			end

			-- Clones listen for parent laugh
			clone:ListenForEvent("laugh", function()
				if not clone.sg:HasStateTag("death") then
					clone.sg:GoToState("laugh")
				end
			end, inst)

			-- Clones inherit their parent's powers
			clone.components.powermanager:CopyPowersFrom(inst)

			-- Clones inherit the parent's rage face swap
			if clone.parent and clone.parent.sg.mem.is_rage_mode then
				clone.components.bossdata:SetBossPhaseChanged(true)
			end
		end
	end

	-- Shuffle the real bandicoot with its clones.
	monsterlist = krandom.Shuffle(monsterlist)
	local angle_delta = 360 / (#monsterlist or 1)

	-- Assign post-spawn move angles to everyone; get clones to transition to post-spawn state.
	local angle = 0
	for i, ent in ipairs(monsterlist) do
		if ent:HasTag("clone") then
			-- Clone
			local pos = inst:GetPosition()
			ent.Transform:SetPosition(pos.x, pos.y, pos.z)
			ent.sg:GoToState("clone_pst", { move_angle = angle })

		else
			-- Parent
			ent.sg.statemem.move_angle = angle
		end

		angle = angle + angle_delta
	end
end

local HIDE_TIME = 10
local HIDE_FLASH_INTERVAL = 3
local TAUNT_TIME = 2
local TELEPORT_APPEAR_DELAY = 1
local PEEK_A_BOO_APPEAR_ATTACK_DELAY = 0.025
local MAX_RAGE_COUNT = 5
local RAGE_TIRED_TIME = 6
--local SWIPE_FAKE_CHANCE = 0.25
local MIN_RUN_DISTANCE = 20
local MAX_RUN_ANGLE = 45
local FLINCH_MOVE_SPEED = -6
local FLINCH_STUN_TIME = 3
local VULNERABLE_DAMAGE_MULTIPLIER = 1.2
local TAUNTING_DAMAGE_MULTIPLIER = 0

local TAUNT_HIT_HITSTOP_FRAMES = 10 -- How many frames does the attacker hitstop for?
local TAUNT_HIT_FX_FRAMES = 4 -- How many frames does the attacker flicker for?
local TAUNT_HIT_SHUDDER_STRENGTH = TUNING.HITSHUDDER_AMOUNT_HEAVY -- How much hitshudder should apply to the attacker?
local TAUNT_HIT_HOLD_FRAMES = 4 -- How many frames does bandicoot hold the 'taunt_hit' state?

local BITE_DOWN_LOOPS <const> = 3

local function WalkOrRun(inst)
	local target = inst.components.combat:GetTarget()
	if not target then
		return { walk = true, run = true, turn = true }
	end

	local pos = inst:GetPosition()
	local targetpos = target:GetPosition()
	local distanceToTarget = pos:dist(targetpos)

	-- Run if too far away and within a certain angle.
	if distanceToTarget > MIN_RUN_DISTANCE and inst:IsWithinAngleTo(target, MAX_RUN_ANGLE) then
		-- If walking, transition to run
		if inst.sg:HasStateTag("walking") then
			inst:PushEvent("walktorun")
		end

		return { walk = false, run = true, turn = true }
	else
		return { walk = true, run = false, turn = true }
	end
end

local MELEE_RANGE = 6
local DODGE_RANGE = 6

local DASH_SPEED = 100

local PEEKABOOM_FALL_HEIGHT = 15
local PEEKABOOM_FX_OFFSETS =
{
	-- For the warning icons
	{ x = 0, z = 0 },
	{ x = -2, z =  0.5 },
	{ x = 2, z = 0.5 },
	{ x = -1, z = -2 },
	{ x = 1, z = -2 },
	{ x = 0, z = 2 },
}

local PHASE_FOUR_THRESHOLD = 0.5 -- Refer to bc_bandicoot

local events =
{
	EventHandler("laugh", function(inst) bossutil.DoEventTransition(inst, "laugh") end),
	EventHandler("howl", function(inst)
		if CanSpawnStalactites(inst) then
			bossutil.DoEventTransition(inst, "howl")
		else
			inst:PushEvent("howl_over") -- Tell the coroutine to stop wating for the howl to finish.
		end
	end),
	EventHandler("hide", function(inst) bossutil.DoEventTransition(inst, "hide") end),
	EventHandler("clone", function(inst, num_clones) bossutil.DoEventTransition(inst, "clone", num_clones) end),
	EventHandler("rage", function(inst) bossutil.DoEventTransition(inst, "rage") end),

	EventHandler("spawn_mobs", SpawnMobsFromHidingSpot),
	EventHandler("spawn_spores", SpawnSpores),

	EventHandler("dodge", function(inst, dir)
		local target = inst.components.combat:GetTarget()
		local trange = TargetRange(inst, target)

		-- Dodge
		if not (inst.sg:HasStateTag("busy") or inst.components.timer:HasTimer("dodge_cd")) and trange:IsInRange(DODGE_RANGE) then
			if dir ~= nil then
				inst.Transform:SetRotation(dir + 180)
			end
			inst.sg:GoToState("dodge")
		end
	end),

	EventHandler("specialmovement", function(inst, target)
		local trange = TargetRange(inst, target)

		-- Dash toward target. Different state depending on facing angle to target.
		if trange:IsBetweenRange(MELEE_RANGE, MIN_RUN_DISTANCE) then
			SGCommon.Fns.TurnAndActOnTarget(inst, target, true, "dash", target)
		end
	end),

	-- Transition to rage attack
	EventHandler("attacked", function(inst)
		if not inst:HasTag("clone") and not inst.sg.mem.is_rage_mode and inst:IsAlive() and inst.components.health:GetPercent() < PHASE_FOUR_THRESHOLD then
			inst.sg:GoToState("rage_transition_pre")
		end
	end),
}
monsterutil.AddBossCommonEvents(events,
{
	locomote_data = { walkrun_fn = WalkOrRun },
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

		timeline =
		{
			-- Code Generated by PivotTrack.jsfl
			FrameEvent(64, function(inst) inst.Physics:MoveRelFacing(41/150) end),
			FrameEvent(66, function(inst) inst.Physics:MoveRelFacing(38/150) end),
			FrameEvent(68, function(inst) inst.Physics:MoveRelFacing(33/150) end),
			FrameEvent(70, function(inst) inst.Physics:MoveRelFacing(30/150) end),
			FrameEvent(72, function(inst) inst.Physics:MoveRelFacing(26/150) end),
			FrameEvent(74, function(inst) inst.Physics:MoveRelFacing(22/150) end),
			FrameEvent(76, function(inst) inst.Physics:MoveRelFacing(18/150) end),
			FrameEvent(78, function(inst) inst.Physics:MoveRelFacing(15/150) end),
			FrameEvent(80, function(inst) inst.Physics:MoveRelFacing(10/150) end),
			FrameEvent(82, function(inst) inst.Physics:MoveRelFacing(7/150) end),
			FrameEvent(112, function(inst) inst.Physics:MoveRelFacing(40/150) end),
			FrameEvent(114, function(inst) inst.Physics:MoveRelFacing(40/150) end),
			FrameEvent(116, function(inst) inst.Physics:MoveRelFacing(80/150) end),
			FrameEvent(118, function(inst) inst.Physics:MoveRelFacing(120/150) end),
			FrameEvent(120, function(inst) inst.Physics:MoveRelFacing(80/150) end),
			FrameEvent(124, function(inst) inst.Physics:MoveRelFacing(120/150) end),
			FrameEvent(127, function(inst) inst.Physics:MoveRelFacing(222/150) end),
			FrameEvent(129, function(inst) inst.Physics:MoveRelFacing(18/150) end),
		},

		events =
		{
			EventHandler("cine_skipped", function(inst)
				local pos = inst.sg.statemem.start_pos
				inst.Transform:SetPosition(pos.x + 9.6, pos.y, pos.z) -- Bandicoot appears 9.6 units from the starting point at the end of the animation.
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "clone_death_pre",
		tags = { "death", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("clone_death_pre")
			inst.AnimState:PushAnimation("clone_death_hold")

			--sound
			local params = {}
			params.fmodevent = fmodtable.Event.bandicoot_clone_kill
			soundutil.PlaySoundData(inst, params)
			inst.HitBox:SetInvincible(true)
			SGCommon.Fns.BlinkAndFadeColor(inst, { 0.75, 0.75, 0.75 }, 20)
			if inst.parent ~= nil then
				inst.parent:PushEvent("clone_death")
			end
		end,

		events =
		{
			EventHandler("animqueueover", function(inst)
				inst.sg:ForceGoToState("clone_death")
			end),
		},
	}),

	State({
		name = "clone_death",
		tags = { "death", "busy", "nointerrupt" },

		onenter = function(inst)
			-- Clones don't play the death animation; instead play disppear FX.
			inst.AnimState:PlayAnimation("clone_death_pst")
			SGCommon.Fns.BlinkAndFadeColor(inst, { .25, .25, .25 }, 2)
			inst.sg:Resume("death") -- Resume stategraph because it gets paused on entering the 'death' state.
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				SGCommon.Fns.SpawnAtDist(inst, "bomb_explosion", 0)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 2, HitPriority.BOSS_DEFAULT)
			end),

			FrameEvent(4, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 4, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 5, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushCircle(0, 0, 5.25, HitPriority.BOSS_DEFAULT)
			end),

			FrameEvent(7, function(inst)
				-- Only spawn mobs on clone death if the parent is still alive.
				if inst.parent and inst.parent:IsAlive() then
					SpawnMobsFromCloneDeath(inst)
				end
				inst:Remove()
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnExplodeHitBoxTriggered),
		},
	}),

	State({
		name = "walk_to_run",
		tags = { "moving", "running", "busy" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("walk_to_run")
			inst.Physics:SetMotorVel(inst.components.locomotor:GetWalkSpeed())
		end,

		timeline =
		{
			FrameEvent(2, function(inst) inst.Physics:SetMotorVel(inst.components.locomotor:GetRunSpeed()) end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg.statemem.moving = true
				inst.sg:GoToState("run_loop", inst.sg.statemem.movequeue)
			end),
		},

		onexit = function(inst)
			if not inst.sg.statemem.moving then
				inst.Physics:Stop()
			end
		end,
	}),

	State({
		name = "laugh",
		tags = { "busy", "vulnerable" },

		onenter = function(inst, noflip)
			local target = inst.components.combat:GetTarget()
			if target and not noflip then
				SGCommon.Fns.FaceTarget(inst, target, true)
			end
			inst.AnimState:PlayAnimation("behavior6")
			inst:SnapToFacingRotation()
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst:PushEvent("laugh_over")
		end,
	}),

	State({
		name = "howl",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("howl")
			inst:SnapToFacingRotation()
		end,

		events =
		{
			--EventHandler("hitboxtriggered", OnHowlHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		timeline = {
			FrameEvent(20, function(inst)
				--inst.components.hitbox:PushCircle(0.00, 0.00, 8.00, HitPriority.BOSS_DEFAULT)
				inst:DoTaskInTime(1, function(inst)
					SpawnStalactites(inst)
				end)
			end),
		},

		onexit = function(inst)
			inst:PushEvent("howl_over")
		end
	}),

	State({
		name = "swipe",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("swipe")
			inst.sg.statemem.target = target
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnSwipeHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.do_laugh then
					inst.sg:GoToState("laugh")
				else
					inst.sg:GoToState("swipe_to_tail_sweep_pre")
				end
			end),
		},

		timeline = {
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushOffsetBeam(-5.00, 0.00, 2.00, -1.50, HitPriority.BOSS_DEFAULT)
				inst.components.hitbox:PushBeam(0.00, 3.00, 1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushOffsetBeam(0.50, 7.00, 3.00, -1.50, HitPriority.BOSS_DEFAULT)
				inst.components.hitbox:PushOffsetBeam(7.00, 8.50, 3.00, 1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushOffsetBeam(4.00, 7.50, 4.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "swipe_to_tail_sweep_pre",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swipe_to_tail_sweep_pre")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("swipe_to_tail_sweep")
			end),
		},
	}),

	State({
		name = "swipe_to_tail_sweep",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("swipe_to_tail_sweep")
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnSwipeToTailSweepHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		timeline = {
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushBeam(-6.50, -0.80, 3.00, HitPriority.BOSS_DEFAULT)
				SGCommon.Fns.SetMotorVelScaled(inst, 10)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushOffsetBeam(-5.00, -0.50, 2.00, -1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushOffsetBeam(-4.00, 2.50, 2.00, -1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.50, 3.00, 2.00, -2.00, HitPriority.BOSS_DEFAULT)
			end),
			-- Other side now
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.50, 5.50, 3.00, 0.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushOffsetBeam(0.00, 5.50, 3.00, 1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushOffsetBeam(1.00, 6.00, 3.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.components.hitbox:PushOffsetBeam(1.00, 6.00, 3.00, 3.00, HitPriority.BOSS_DEFAULT)
				inst.sg.statemem.is_high_attack = true
			end),
			FrameEvent(11, function(inst)
				inst.components.hitbox:PushOffsetBeam(2.50, 6.00, 3.00, 3.50, HitPriority.BOSS_DEFAULT)
				SGCommon.Fns.SetMotorVelScaled(inst, 5)
			end),
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushOffsetBeam(2.50, 6.00, 2.00, 2.0, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(13, function(inst)
				inst.components.hitbox:PushOffsetBeam(1.00, 4.00, 2.00, 2.50, HitPriority.BOSS_DEFAULT)
				inst.Physics:Stop()
			end),
			FrameEvent(25, function(inst)
				inst.Transform:FlipFacingAndRotation( )
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	--[[State({
		name = "swipe2",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("swipe2")
			inst.sg.statemem.target = target
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnSwipe2HitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.do_laugh then
					inst.sg:GoToState("laugh")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		timeline = {
			FrameEvent(7, function(inst)
				inst.components.hitbox:PushBeam(3.00, 11.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(8, function(inst)
				inst.components.hitbox:PushBeam(3.00, 8.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushBeam(3.00, 8.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),]]

	--[[State({
		name = "tailspin",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("tailspin")
			inst.sg.statemem.target = target
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, 10)
			end),
			FrameEvent(11, function(inst)
				inst.components.hitbox:PushOffsetBeam(-6.50, -1.20, 2.50, 0.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushOffsetBeam(-6.50, -1.20, 2.50, 0.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(13, function(inst)
				inst.components.hitbox:PushBeam(-4.50, 2.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				inst.components.hitbox:PushBeam(-4.50, 2.00, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(15, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.00, 6.00, 3.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(16, function(inst)
				inst.components.hitbox:PushOffsetBeam(-1.50, 6.00, 3.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(17, function(inst)
				inst.components.hitbox:PushOffsetBeam(-4.50, 2.50, 3.00, 3.00, HitPriority.BOSS_DEFAULT)
				inst.Physics:Stop()
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnTailSpinHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			inst.Physics:Stop()
		end,
	}),]]

	--[[State({
		name = "tailwhip",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("tailwhip")
			inst.sg.statemem.target = target
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()

			inst.components.offsethitboxes:Move("offsethitbox", 1.5)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
		end,

		timeline =
		{
			FrameEvent(4, function(inst)
				--inst.sg.statemem.fx = SGCommon.Fns.SpawnAtDist(inst, "fx_bandicoot_tail_dust", -3.2)
				--inst.components.hitstopper:AttachChild(inst.sg.statemem.fx)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(-.5, -5.5, 2.5, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(5, function(inst)
				inst.components.hitbox:PushBeam(-.5, -5.5, 2.5, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(6, function(inst)
				inst.components.hitbox:PushBeam(-.5, -5.5, 2.5, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(14, function(inst)
				--inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
				--inst.sg.statemem.fx = nil
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnTailWhipHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			if inst.sg.statemem.fx ~= nil then
				inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
			end
		end,
	}),]]

	State({
		name = "taunt_hold",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("taunt_loop", true)
			inst.components.attacktracker:CompleteActiveAttack()
			inst.sg:SetTimeout(TAUNT_TIME)
			inst.components.combat:SetDamageReceivedMult("bandicoot_taunting", TAUNTING_DAMAGE_MULTIPLIER)
		end,

		events =
		{
			EventHandler("attacked", function(inst, data)
				local attacker = data.attack:GetAttacker()
				if attacker and attacker:HasTag("player") then
					inst.sg:GoToState("taunt_hit", data)
				end
			end),
			EventHandler("knockback", function(inst, data)
				local attacker = data.attack:GetAttacker()
				if attacker and attacker:HasTag("player") then
					inst.sg:GoToState("taunt_hit", data)
				end
			end),
			EventHandler("knockdown", function(inst, data)
				local attacker = data.attack:GetAttacker()
				if attacker and attacker:HasTag("player") then
					inst.sg:GoToState("taunt_hit", data)
				end
			end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("taunt_pst")
		end,

		onexit = function(inst)
			inst.components.combat:RemoveDamageReceivedMult("bandicoot_taunting") -- will re-add in "taunt-hit", removing here in case exit for some other reason
		end,
	}),

	State({
		name = "taunt_hit",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("taunt_hit_hold")
			inst.components.combat:SetDamageReceivedMult("bandicoot_taunting", TAUNTING_DAMAGE_MULTIPLIER)

			local attack = data ~= nil and data.attack
			local attacker = attack ~= nil and attack:GetAttacker()
			if attacker ~= nil and attacker:IsValid() then
				local hitstopframes = TAUNT_HIT_HITSTOP_FRAMES
				local fxframes = TAUNT_HIT_FX_FRAMES
				local shudder = TAUNT_HIT_SHUDDER_STRENGTH

				if attacker.components.hitstopper ~= nil then
					attacker.components.hitstopper:PushHitStop(hitstopframes)
				end

				-- Hitshudder
				if attacker.components.hitshudder ~= nil then
					attacker.components.hitshudder:DoShudder(shudder, fxframes)
				end

				-- FX
				SGCommon.Fns.BlinkAndFadeColor(inst, { 0, 0.5, 1 }, (fxframes))
				if attacker.components.coloradder ~= nil then
					SGCommon.Fns.BlinkAndFadeColor(attacker, { 0, 0.5, 1 }, (fxframes))
				end

				inst.sg.statemem.target = attacker
			end

			inst.sg:SetTimeoutAnimFrames(TAUNT_HIT_HOLD_FRAMES)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("taunt", inst.sg.statemem.target)
		end,

		onexit = function(inst)
			inst.components.combat:RemoveDamageReceivedMult("bandicoot_taunting") -- will re-add in "taunt-hit", removing here in case exit for some other reason
		end,
	}),

	State({
		name = "taunt",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("taunt")

			inst.sg.statemem.target = target
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("peek_a_boo_pre", inst.sg.statemem.target)
			end),
		},
	}),

	State({
		name = "taunt_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("taunt_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "bite",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("bite")
			inst.sg.statemem.target = target
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS | HitGroup.MOB) -- Enable friendly fire on this attack, but not on the clone, which is part of the BOSS hitgroup
		end,

		timeline =
		{
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 4) end),
			FrameEvent(5, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 2) end),
			FrameEvent(10, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 11) end),
			FrameEvent(13, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, 6)
				inst.Physics:SetSize(2.8)
				inst.components.offsethitboxes:Move("offsethitbox", 4.8)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
			end),
			FrameEvent(14, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, 3)
				--inst.sg.statemem.fx = SGCommon.Fns.SpawnFollower(inst, "fx_bandicoot_bite")
				--inst.components.hitstopper:AttachChild(inst.sg.statemem.fx)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushBeam(2.00, 7.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(15, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, 1.5)
				inst.components.hitbox:PushBeam(2.00, 7.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(16, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, .75)
				inst.components.hitbox:PushBeam(2.00, 7.20, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(17, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, -1.6)
				inst.components.offsethitboxes:Move("offsethitbox", 4.4)
				--inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
				--inst.sg.statemem.fx = nil
			end),
			FrameEvent(22, function(inst)
				inst.components.offsethitboxes:Move("offsethitbox", 3.2)
			end),
			FrameEvent(24, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, -.8)
				inst.components.offsethitboxes:Move("offsethitbox", 2.4)
			end),
			FrameEvent(26, function(inst)
				inst.Physics:Stop()
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnBiteHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.components.hitbox:StopRepeatTargetDelay()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			if inst.sg.statemem.fx ~= nil then
				inst.components.hitstopper:DetachChild(inst.sg.statemem.fx)
			end
		end,
	}),

	State({
		name = "bite_down_reposition",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			local target = inst.components.combat:GetTarget()
			if target then
				local targetpos = target:GetPosition()
				inst.AnimState:PlayAnimation("dodge")
				inst.Physics:StartPassingThroughObjects()

				-- Move to a point at the top of the map above the player and move downwards
				local reposition_pt = spawnutil.GetStartPointFromWorld(0, 1)
				reposition_pt.x = targetpos.x
				if not TheWorld.Map:IsWalkableAtXZ(reposition_pt.x, reposition_pt.z) then
					reposition_pt = TheWorld.Map:FindClosestPointOnWalkableBoundary(reposition_pt)
				end

				-- Move to a point in front/back from where the player is standing, within acid spit range
				inst.sg.statemem.movetotask = SGCommon.Fns.MoveToPoint(inst, reposition_pt, 0.25)
				inst.sg:SetTimeoutAnimFrames(150)
			else
				inst.sg:GoToState("bite_down_pre")
				return
			end
		end,

		ontimeout = function(inst)
			TheLog.ch.StateGraph:printf("Warning: Bandicoot state %s timed out.", inst.sg.currentstate.name)
			inst.sg:GoToState("bite_down_pre")
		end,

		events =
		{
			EventHandler("movetopoint_complete", function(inst)
				inst.sg:GoToState("bite_down_pre")
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
		name = "bite_down",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("bite_below_loop")
			inst.sg.statemem.target = target
			inst.components.attacktracker:CompleteActiveAttack()
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS | HitGroup.MOB) -- Enable friendly fire on this attack, but not on the clone, which is part of the BOSS hitgroup
			inst.Physics:StartPassingThroughObjects()

			-- Move downwards
			inst.Transform:SetRotation(90)
			SGCommon.Fns.SetMotorVelScaled(inst, 2)

			inst.sg.mem.bite_down_loop = inst.sg.mem.bite_down_loop or 1
		end,

		timeline =
		{
			-- Movement
			FrameEvent(9, function(inst)
				UpdateBiteDownAngle(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, 22)
			end),
			FrameEvent(13, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, 2)
			end),
			FrameEvent(21, function(inst)
				UpdateBiteDownAngle(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, 22)
			end),

			-- Hitbox
			FrameEvent(9, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.00, 3.00, 2.00, -1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(10, function(inst)
				inst.components.hitbox:PushOffsetBeam(-0.50, 4.50, 2.00, -1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(11, function(inst)
				inst.components.hitbox:PushOffsetBeam(1.00, 6.00, 2.00, -1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(12, function(inst)
				inst.components.hitbox:PushBeam(2.00, 6.50, 2.00, HitPriority.BOSS_DEFAULT)
				inst.components.hitbox:StopRepeatTargetDelay()
			end),

			FrameEvent(23, function(inst)
				inst.components.hitbox:StartRepeatTargetDelay()
				inst.components.hitbox:PushOffsetBeam(1.00, 5.50, 2.00, -1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(24, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.50, 3.50, 2.00, -1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(25, function(inst)
				inst.components.hitbox:PushOffsetBeam(-3.00, 2.00, 2.00, -1.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(26, function(inst)
				inst.components.hitbox:PushOffsetBeam(-3.50, 1.50, 2.00, -1.50, HitPriority.BOSS_DEFAULT)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnBiteDownHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.mem.bite_down_loop < BITE_DOWN_LOOPS then
					inst.sg.mem.bite_down_loop = inst.sg.mem.bite_down_loop + 1
					inst.sg:GoToState("bite_down")
				else
					inst.sg.mem.bite_down_loop = nil
					inst.sg:GoToState("bite_down_pst")
				end
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "bite_down_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("bite_below_pst")
		end,

		timeline =
		{
			FrameEvent(3, function(inst)
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
		name = "dodge",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("dodge")
		end,

		onupdate = function(inst)
			if inst.sg.statemem.speed ~= nil then
				inst.sg.statemem.speed = inst.sg.statemem.speed + .7
				SGCommon.Fns.SetMotorVelScaled(inst, inst.sg.statemem.speed)
			end
			inst.Physics:StartPassingThroughObjects()
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.sg:AddStateTag("airborne")
				SGCommon.Fns.SetMotorVelScaled(inst, -6)
				inst.components.timer:StartTimer("dodge_cd", 2, true)
			end),
			FrameEvent(3, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, -10) end),
			FrameEvent(4, function(inst)
				inst.sg:AddStateTag("nointerrupt")
				SGCommon.Fns.SetMotorVelScaled(inst, -14)
			end),
			FrameEvent(8, function(inst)
				inst.sg.statemem.speed = -14
			end),
			FrameEvent(19, function(inst)
				inst.sg:RemoveStateTag("airborne")
				inst.sg.statemem.speed = nil
				SGCommon.Fns.SetMotorVelScaled(inst, -2.6)
				inst.Physics:StopPassingThroughObjects()
			end),
			FrameEvent(21, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			FrameEvent(24, function(inst) inst.Physics:Stop() end),
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

	-- Dash
	State({
		name = "dash",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, target)
			local direction = SGCommon.Fns.GetSpecialMovementDirection(inst, target)
			local anim = (direction == SGCommon.SPECIAL_MOVEMENT_DIR.UP and "dash_above") or
						(direction == SGCommon.SPECIAL_MOVEMENT_DIR.DOWN and "dash_below") or
						"dash_forward"
			inst.AnimState:PlayAnimation(anim)
		end,

		timeline =
		{
			FrameEvent(7, function(inst)
				inst.Physics:StartPassingThroughObjects()
				SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED)
			end),
			FrameEvent(9, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED * 0.5)
			end),
			FrameEvent(10, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED * 0.2)
			end),
			FrameEvent(11, function(inst)
				SGCommon.Fns.SetMotorVelScaled(inst, DASH_SPEED * 0.1)
			end),
			FrameEvent(12, function(inst)
				inst.Physics:Stop()
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
			inst.Physics:StopPassingThroughObjects()
		end,
	}),

	State({
		name = "clone",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("clone")
			inst.sg.statemem.num_clones = data
		end,

		timeline =
		{
			FrameEvent(33, function(inst)
				if GetPhase(inst) < 3 then
					inst.boss_coro:SetMusicPhase(2)
				end
			end),
			-- Spawn clones, start moving to positions.
			FrameEvent(84, function(inst)
				inst.Physics:StartPassingThroughObjects()

				SpawnClones(inst, inst.sg.statemem.num_clones)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("clone_pst", { move_angle = inst.sg.statemem.move_angle, facing = inst.Transform:GetFacing() })
			end),
		},

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
			inst:PushEvent("clone_over")
		end,
	}),

	State({
		name = "clone_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("clone_pst")
			inst.Physics:StartPassingThroughObjects()
			if data.move_angle then
				inst.Transform:SetRotation(data.move_angle)

				-- Make the clone and parent face the same way, but make them move away from each other.
				local facing = 1
				if (inst.parent and inst.Transform:GetFacing() ~= inst.parent.Transform:GetFacing()) or
					(data.facing and data.facing ~= inst.Transform:GetFacing()) then -- The parent got flipped; need to reset facing.
					inst.Transform:FlipFacingAndRotation()
					facing = -1
				end

				SGCommon.Fns.SetMotorVelScaled(inst, inst.tuning.clone_spawn_move_speed * facing)
			end
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				inst.Physics:Stop()
				inst.Physics:StopPassingThroughObjects()
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
		end
	}),

	-- Hide & peek-a-boo attack
	State({
		name = "hide",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hide")
			inst.sg:SetTimeout(HIDE_TIME)
		end,

		timeline =
		{
			FrameEvent(40, function(inst)
				inst.HitBox:SetInvincible(true)
				inst.Physics:StartPassingThroughObjects()
			end),

			FrameEvent(41, function(inst)
				inst.Physics:SetMotorVel(TELEPORT_SPEED)
			end),

			FrameEvent(44, function(inst)
				-- Teleport and hide at a nearby pillar.
				local hiding_spot = GetRandomHidingSpot()

				-- Hiding spots somehow don't exist anymore; transition immediately to teleport appear & attack
				if hiding_spot == nil then
					inst.Physics:Stop()

					-- Currently, there is no handling for when TELEPORT_APPEAR_DELAY is longer than the HIDE_TIME timeout.
					inst:DoTaskInTime(TELEPORT_APPEAR_DELAY, function(inst)
						inst.sg:GoToState("peek_a_boo_pre")
					end)
				else
					-- Move to the hiding spot.
					HideInHidingSpot(inst, hiding_spot)
					local selected_hiding_spot_pos = inst.sg.mem.hiding_spot:GetPosition()
					inst.Transform:SetPosition(selected_hiding_spot_pos:Get())

					inst.Physics:Stop()

					inst:AddTag("notarget")
					inst:Hide()
					TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Bandicoot_clockFreq", 0)
					TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Bandicoot_isHiding", 1)


					-- Make the hiding spot flash to show where bandicoot is hiding.
					local function flash(inst)
						local hiding_spot = inst.sg.mem.hiding_spot
						if hiding_spot then
							hiding_spot:PushEvent("flash")
						end

						inst:DoTaskInTime(HIDE_FLASH_INTERVAL, flash)
					end

					inst:DoTaskInTime(1, function(inst) flash(inst) end)
				end
			end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("peek_a_boo")
		end,

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:Stop()
			inst:Show()

			inst:PushEvent("hide_over")
		end,
	}),

	State({
		name = "peek_a_boo",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, target)
			inst.AnimState:PlayAnimation("peek_a_boo")
			inst.Physics:StartPassingThroughObjects()
		end,

		timeline =
		{
			FrameEvent(24, function(inst)
				TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Bandicoot_PillarFailStinger", 1)
			end),

			FrameEvent(26, function(inst)
				inst.HitBox:SetInvincible(true)
				UnhideFromHidingSpot(inst)
			end),

			FrameEvent(27, function(inst)
				-- Reset rotation to facing so it moves out left or right from the hiding spot.
				local facing_rotation = inst.Transform:GetFacingRotation()
				inst.Transform:SetRotation(facing_rotation)

				inst.Physics:SetMotorVel(TELEPORT_SPEED)
				TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Bandicoot_isHiding", 0)
				TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Bandicoot_clockFreq", 0)
			end),

			FrameEvent(30, function(inst)
				inst:Hide()
				inst.sg:SetTimeout(TELEPORT_APPEAR_DELAY)
				inst.Physics:Stop()
			end),
		},

		ontimeout =	function(inst)
			inst.sg:GoToState("peek_a_boom_fall_pre")
		end,

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:Stop()
			inst:Show()
			inst:RemoveTag("notarget")

			UnhideFromHidingSpot(inst)
		end,
	}),

	State({
		name = "peek_a_boo_pre",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, target)
			-- Add a delay to spawn particle FX at the position where it's going to appear.
			inst:DoTaskInTime(0.3, function(inst)
				inst.Physics:SetMotorVel(TELEPORT_SPEED)
				inst.AnimState:PlayAnimation("peek_a_boo_pre")
			end)
			inst.HitBox:SetInvincible(true)
			inst.Physics:StartPassingThroughObjects()

			TeleportToTarget(inst, target, TELEPORT_HIDE_OFFSET_X)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("peek_a_boo_hold")
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:Stop()
		end,
	}),

	State({
		name = "peek_a_boo_hold",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("peek_a_boo_hold")
			inst.sg:SetTimeout(PEEK_A_BOO_APPEAR_ATTACK_DELAY)

			inst.Physics:StartPassingThroughObjects()
			inst.Physics:SetMotorVel(TELEPORT_SPEED * 0.1)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("peek_a_boo_pst")
		end,

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:Stop()
		end,
	}),

	State({
		name = "peek_a_boo_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("peek_a_boo_pst")
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.Physics:StartPassingThroughObjects()
		end,

		events =
		{
			EventHandler("hitboxtriggered", OnPeekABooHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.statemem.do_laugh then
					inst.sg:GoToState("laugh")
				else
					inst.sg:GoToState("idle")
				end
			end),
		},

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.components.hitbox:PushBeam(-6.00, 7.00, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(3, function(inst)
				inst.components.hitbox:PushBeam(-3.50, 6.50, 2.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(4, function(inst)
				inst.components.hitbox:PushBeam(-3.50, 6.50, 2.00, HitPriority.BOSS_DEFAULT)
			end),
		},

		onexit = function(inst)
			inst.Physics:StopPassingThroughObjects()
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),

	State({
		name = "flinch_pillar",
		tags = { "busy", "vulnerable" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("flinch_pillar")
			inst:RemoveTag("notarget")
			inst.Physics:SetMotorVel(FLINCH_MOVE_SPEED)
			inst.Physics:StartPassingThroughObjects()
			inst.components.combat:SetDamageReceivedMult("bandicoot_vulnerable", VULNERABLE_DAMAGE_MULTIPLIER)
		end,

		timeline =
		{
			FrameEvent(1, function(inst)
				if not inst:HasTag("clone") then
					TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Bandicoot_PillarRevealStinger", 1)
					TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Bandicoot_isHiding", 0)
				end
			end),
			FrameEvent(9, function(inst)
				inst.Physics:SetMotorVel(FLINCH_MOVE_SPEED * 0.5)
			end),
			FrameEvent(14, function(inst)
				inst.Physics:StopPassingThroughObjects()
				inst.Physics:Stop()
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("flinch_pillar_loop")
			end),
		},

		onexit = function(inst)
			inst.components.combat:RemoveDamageReceivedMult("bandicoot_vulnerable")
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:Stop()
		end,
	}),

	State({
		name = "flinch_pillar_loop",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("flinch_pillar_loop", true)
			inst.sg:SetTimeout(FLINCH_STUN_TIME)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("flinch_pillar_pst")
		end,
	}),

	State({
		name = "flinch_pillar_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, data)
			inst.AnimState:PlayAnimation("flinch_pillar_pst")
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	-- Rage bite attack
	State({
		name = "rage",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("rage")
			inst.sg.mem.rage_count = 1
		end,

		timeline =
		{
			FrameEvent(14, function(inst)
				DestroyStalacties(inst)
				SpawnStalactites(inst)
			end),
			FrameEvent(88, function(inst)
				inst.HitBox:SetInvincible(true)
				inst.Physics:StartPassingThroughObjects()
			end),
			FrameEvent(90, function(inst)
				inst.Physics:SetMotorVel(TELEPORT_SPEED)
			end),
			FrameEvent(94, function(inst)
				inst:Hide()
				inst.sg:SetTimeout(TELEPORT_APPEAR_DELAY)
				inst.Physics:Stop()
			end),

			FrameEvent(63, function(inst)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
				inst.components.offsethitboxes:Move("offsethitbox", 4.8)
			end),
		},

		ontimeout =	function(inst)
			inst.sg:GoToState("rage_bite_pre")
		end,

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:Stop()
			inst:Show()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "rage_bite_pre",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst, target)
			-- Add a delay to spawn particle FX at the position where it's going to appear.
			--inst:DoTaskInTime(0.3, function(inst)
			inst.Physics:SetMotorVel(TELEPORT_SPEED)
			inst.AnimState:PlayAnimation("rage_bite_pre")
			--end)
			inst.HitBox:SetInvincible(true)
			inst.Physics:StartPassingThroughObjects()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
			inst.components.offsethitboxes:Move("offsethitbox", 4)

			TeleportToTarget(inst, target, TELEPORT_RAGE_OFFSET_X)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("rage_bite_hold")
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:Stop()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "rage_bite_hold",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("rage_bite_hold")
			inst.Physics:SetMotorVel(TELEPORT_SPEED)
			inst.Physics:StartPassingThroughObjects()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
			inst.components.offsethitboxes:Move("offsethitbox", 4.8)
		end,

		--[[onupdate = function(inst)
			inst.components.hitbox:PushBeam(-4.00, 6.00, 2.00, HitPriority.BOSS_DEFAULT)
		end,]]

		timeline = {
			FrameEvent(1, function(inst)
				if not inst.sg.mem.play_rage_stinger then
					inst.sg.mem.play_rage_stinger = 1
				end
				if inst.sg.mem.play_rage_stinger == 1 then
					TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.Music_Boss_StingerCounter, inst.sg.mem.rage_count)
					TheAudio:SetPersistentSoundParameter(audioid.persistent.boss_music, "Music_Bandicoot_DashStinger", 1)
				end
				if inst.sg.mem.rage_count == MAX_RAGE_COUNT then
					inst.sg.mem.play_rage_stinger = 0
				end
			end),
		},

		events =
		{
			--[[EventHandler("hitboxtriggered", function(inst)
				inst.sg:GoToState("rage_bite")
			end),]]
			EventHandler("animover", function(inst)
				inst.sg:GoToState("rage_bite")
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "rage_bite",
		tags = { "busy", "nointerrupt" },

		default_data_for_tools = function(inst)
			inst.sg.mem.rage_count = 1
		end,

		onenter = function(inst)
			inst.AnimState:PlayAnimation("rage_bite")
			inst.Physics:SetMotorVel(TELEPORT_SPEED)
			inst.Physics:StartPassingThroughObjects()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", true)

			--inst.sg.statemem.previousHitFlags = inst.components.hitbox:GetHitFlags()
			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS | HitGroup.MOB) -- Enable friendly fire on this attack, but not on the clone, which is part of the BOSS hitgroup
		end,

		timeline = {
			FrameEvent(0, function(inst)
				inst.components.hitbox:PushBeam(-1.50, 7.20, 2.00, HitPriority.BOSS_DEFAULT)
				inst.components.offsethitboxes:Move("offsethitbox", 5.2)
			end),
			FrameEvent(1, function(inst)
				inst.components.hitbox:PushBeam(2.50, 9.50, 2.00, HitPriority.BOSS_DEFAULT)
				inst.components.offsethitboxes:Move("offsethitbox", 5.6)
			end),
			FrameEvent(2, function(inst)
				inst.components.hitbox:PushBeam(4.00, 8.80, 2.00, HitPriority.BOSS_DEFAULT)
				inst.components.offsethitboxes:Move("offsethitbox", 6)
			end),
			FrameEvent(4, function(inst)
				inst.Physics:Stop()
				inst.Physics:StopPassingThroughObjects()
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnRageBiteHitBoxTriggered),
			EventHandler("animover", function(inst)
				if inst.sg.mem.rage_count < MAX_RAGE_COUNT then
					inst.sg.mem.rage_count = inst.sg.mem.rage_count + 1
					inst.sg:GoToState("rage_bite_loop")
				else
					inst.sg:GoToState("rage_bite_tired_pre") -- Go to tired after rage loop.
				end
			end),
		},

		onexit = function(inst)
			--inst.components.hitbox:SetHitFlags(inst.sg.statemem.previousHitFlags)
			inst.Physics:Stop()
			inst.Physics:StopPassingThroughObjects()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "rage_bite_loop",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("rage_bite_loop")
			inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
		end,

		timeline =
		{
			FrameEvent(9, function(inst)
				inst.HitBox:SetInvincible(true)
				inst.Physics:StartPassingThroughObjects()
			end),
			FrameEvent(10, function(inst)
				inst.Physics:SetMotorVel(TELEPORT_SPEED)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("rage_bite_pre", inst.components.combat:GetTarget())
			end),
		},

		onexit = function(inst)
			inst.HitBox:SetInvincible(false)
			inst.Physics:StopPassingThroughObjects()
			inst.Physics:Stop()
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "rage_bite_tired_pre",
		tags = { "busy", "nointerrupt", "vulnerable" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("rage_bite_tired_pre")
			inst.components.combat:SetDamageReceivedMult("bandicoot_vulnerable", VULNERABLE_DAMAGE_MULTIPLIER)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
			inst.components.offsethitboxes:Move("offsethitbox", 4)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("rage_bite_tired_loop")
			end),
		},

		onexit = function(inst)
			inst.components.combat:RemoveDamageReceivedMult("bandicoot_vulnerable")
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "rage_bite_tired_loop",
		tags = { "busy", "nointerrupt", "vulnerable" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("rage_bite_tired_loop", true)
			inst.components.combat:SetDamageReceivedMult("bandicoot_vulnerable", VULNERABLE_DAMAGE_MULTIPLIER)
			inst.sg:SetTimeout(RAGE_TIRED_TIME)
			inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("rage_bite_pst")
		end,

		onexit = function(inst)
			inst.components.combat:RemoveDamageReceivedMult("bandicoot_vulnerable")
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
		end,
	}),

	State({
		name = "rage_bite_pst",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("rage_bite_pst")
			inst.components.offsethitboxes:SetEnabled("offsethitbox", true)
		end,

		timeline =
		{
			FrameEvent(5, function(inst)
				inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			end),
		},

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst:PushEvent("rage_over")
			inst.components.offsethitboxes:SetEnabled("offsethitbox", false)
			inst.sg.mem.play_rage_stinger = 1
			TheAudio:SetGlobalParameter(fmodtable.GlobalParameter.Music_Boss_StingerCounter, 1) -- reset the rage counter used in FMOD
		end,
	}),

	-- Peek-A-Boom, major attack after players are unsuccessful finding a Hidden bandicoot.

	State({
		name = "peek_a_boom_fall_pre",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst:Hide()
			inst.Physics:SetEnabled(false)
			inst.HitBox:SetInvincible(true)

			local nearest_living_player = inst:GetClosestPlayer(true)
			local pos = nearest_living_player ~= nil and nearest_living_player:GetPosition() or inst:GetPosition()
			inst.Transform:SetPosition(pos.x, pos.y, pos.z)

			DoStalactiteFallPresentation(inst)

			-- Spawn ground target (temp? replace with a single shadow FX?)
			local x, y, z = inst.Transform:GetWorldPosition()
			inst.sg.mem.fx_list = {}
			for i, offset in ipairs(PEEKABOOM_FX_OFFSETS) do
				local targetpos = Vector3(x + offset.x, 0, z + offset.z)
				local fx = SpawnPrefab("fx_ground_target_red", inst)
				fx.Transform:SetPosition( targetpos.x, 0, targetpos.z )

				table.insert(inst.sg.mem.fx_list, fx)
			end

			inst.sg:SetTimeout(1)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("peek_a_boom_fall")
		end,

	}),

	State({
		name = "peek_a_boom_fall",
		tags = { "busy", "nointerrupt" },

		default_data_for_tools = function(inst, cleanup)
			inst.sg.mem.fx_list = {}
		end,

		onenter = function(inst)
			--sound TEMP
			local params = {}
			params.fmodevent = fmodtable.Event.Destructible_Stalactite_Fall
			soundutil.PlaySoundData(inst, params)

			inst:Show()
			inst.AnimState:PlayAnimation("peek_a_boom_stalag_fall")
			-- Set to fall from above
			inst.components.fallingobject:SetLaunchHeight(PEEKABOOM_FALL_HEIGHT)
			inst.components.fallingobject:SetGravity(-40)
			inst.components.fallingobject:Launch()

			local symbol_overrides =
			{
				"bandiforest_grid_stalag",
				"bloom_konjur_untex",
				"bloom_scatter",
				"bloom_untex",
				"fx_shatter1",
				"fx_shatter2",
				"particles_untex",
				"pieces",
				"stalag",
				"stalag2",
			}

			for i,symbol in ipairs(symbol_overrides) do
				inst.AnimState:OverrideSymbol(symbol, "destructible_bandiforest_ceiling", symbol) -- Grab the symbols from the stalag build
			end

			-- local RemoveLandFX = function(inst)

			-- Set up hit FX
			inst.SpawnHitRubble = prop_destructible.default.SpawnHitRubble
			inst.fx_types = TUNING.TRAPS.swamp_stalactite.fx

			inst.components.fallingobject:SetOnLand(function(inst)
				for i, fx in ipairs(inst.sg.mem.fx_list) do
					if fx:IsValid() then
						fx:Remove()
					end
				end

				SGCommon.Fns.SpawnAtDist(inst, "swamp_stalactite_peekaboom_network", 0)
				inst.sg:GoToState("peek_a_boom_jump")
			end)
		end,

		events =
		{
		},

		onexit = function(inst)
			inst.Physics:SetEnabled(true)
		end,
	}),

	State({
		name = "peek_a_boom_jump",
		tags = { "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("peek_a_boom_jump")
			inst.Physics:StartPassingThroughObjects()
		end,

		timeline =
		{
			FrameEvent(2, function(inst)
				inst.Physics:SetMotorVel(20)
			end),
			FrameEvent(14, function(inst)
				inst.Physics:Stop()
				inst.HitBox:SetInvincible(false)
				inst.Physics:StopPassingThroughObjects()
			end),
			-- FrameEvent(2, function(inst) inst.Physics:MoveRelFacing(240/150) end),
			-- FrameEvent(4, function(inst) inst.Physics:MoveRelFacing(240/150) end),
			-- FrameEvent(7, function(inst) inst.Physics:MoveRelFacing(240/150) end),
			-- FrameEvent(10, function(inst) inst.Physics:MoveRelFacing(200/150) end),
			-- FrameEvent(12, function(inst) inst.Physics:MoveRelFacing(208/150) end),
			-- FrameEvent(13, function(inst) inst.Physics:MoveRelFacing(148/150) end),
			-- FrameEvent(14, function(inst) inst.Physics:MoveRelFacing(40/150) end),
		},
		onexit = function(inst)
		end,

		events =
		{
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	}),

	State({
		name = "rage_transition_pre",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("rage_transition_pre")
			inst.AnimState:PushAnimation("rage_transition_hold")
			inst.components.attacktracker:CancelActiveAttack()

			inst.sg:SetTimeout(2)

			inst.components.hitstopper:PushHitStop(6)
		end,

		ontimeout = function(inst)
			inst.sg:GoToState("rage_transition")
		end,
	}),

	State({
		name = "rage_transition",
		tags = { "attack", "busy", "nointerrupt" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("rage_transition")
			inst.components.hitbox:StartRepeatTargetDelay()
			inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS | HitGroup.MOB) -- Enable friendly fire on this attack, but not on the clone, which is part of the BOSS hitgroup
		end,

		timeline = {
			FrameEvent(13, function(inst)
				inst.components.hitbox:PushOffsetBeam(-2.00, 2.30, 2.00, -1.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(15, function(inst)
				inst.components.hitbox:PushOffsetBeam(2.50, 7.00, 3.00, 0.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(16, function(inst)
				inst.components.hitbox:PushOffsetBeam(4.50, 7.00, 3.00, 1.80, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(30, function(inst)
				inst.components.hitbox:PushBeam(-1.50, 4.80, 2.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(32, function(inst)
				inst.components.hitbox:PushOffsetBeam(-5.00, 2.00, 3.00, 0.50, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(33, function(inst)
				inst.components.hitbox:PushOffsetBeam(-8.00, -6.00, 3.00, 2.00, HitPriority.BOSS_DEFAULT)
				inst.components.hitbox:PushBeam(-6.00, 0.50, 3.00, HitPriority.BOSS_DEFAULT)
			end),
			FrameEvent(59, function(inst)
				inst.sg.mem.is_rage_mode = true
				inst:PushEvent("enter_rage_mode")

				inst.components.bossdata:SetBossPhaseChanged(true)
			end),
		},

		events =
		{
			EventHandler("hitboxtriggered", OnRageTransitionHitBoxTriggered),
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},

		onexit = function(inst)
			inst.components.hitbox:StopRepeatTargetDelay()
		end,
	}),
}

local nointerrupttags = { "nointerrupt" }

SGCommon.States.AddIdleStates(states, { num_idle_behaviours = 5, })
SGCommon.States.AddTurnStates(states)
SGCommon.States.AddLocomoteStates(states, "walk",
{
	addtags = nointerrupttags,
	loopevents =
	{
		EventHandler("walktorun",
			function(inst)
				inst.sg:GoToState("walk_to_run")
			end),
	},
})
SGCommon.States.AddLocomoteStates(states, "run",
{
	isRunState = true,
	addtags = nointerrupttags,
})
SGCommon.States.AddHitStates(states)
SGCommon.States.AddKnockbackStates(states, { movement_frames = 12 })
SGCommon.States.AddKnockdownStates(states, { movement_frames = 12 })
SGCommon.States.AddKnockdownHitStates(states)

SGCommon.States.AddAttackPre(states, "swipe",
{
	alwaysforceattack = true,
	--[[onenter_fn = function(inst)
		-- Chance to transition into the swipe fakeout move:
		if math.random() < SWIPE_FAKE_CHANCE then
			inst.components.attacktracker:CancelActiveAttack()
			inst.sg.statemem.attack_cancelled = true
			inst.sg:GoToState("swipe2_pre")
		end
	end]]
})
SGCommon.States.AddAttackHold(states, "swipe", { alwaysforceattack = true })

--SGCommon.States.AddAttackPre(states, "swipe2", { alwaysforceattack = true })
--SGCommon.States.AddAttackHold(states, "swipe2", { alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "swipe_to_tail_sweep", { alwaysforceattack = true })
SGCommon.States.AddAttackHold(states, "swipe_to_tail_sweep", { alwaysforceattack = true })

--SGCommon.States.AddAttackPre(states, "tailspin", { alwaysforceattack = true })
--SGCommon.States.AddAttackHold(states, "tailspin", { alwaysforceattack = true })

--SGCommon.States.AddAttackPre(states, "tailwhip", { alwaysforceattack = true })
--SGCommon.States.AddAttackHold(states, "tailwhip", { alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "taunt", {	alwaysforceattack = true })

SGCommon.States.AddAttackPre(states, "bite", { alwaysforceattack = true })
SGCommon.States.AddAttackHold(states, "bite",
{
	alwaysforceattack = true,
	hold_anim = "bite_step",
	timeline =
	{
		FrameEvent(4, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 1.4) end),
		FrameEvent(7, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 3.6) end),
		FrameEvent(9, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 10.7) end),
		FrameEvent(11, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 5.1) end),
		FrameEvent(13, function(inst) SGCommon.Fns.SetMotorVelScaled(inst, 6.2) end),
	},
})

SGCommon.States.AddAttackPre(states, "bite_down",
{
	alwaysforceattack = true,
	onenter_fn = function(inst)
		local target = inst.components.combat:GetTarget()
		SGCommon.Fns.FaceTarget(inst, target, true)

		if not inst.sg.mem.in_position then
			inst.sg.mem.in_position = true
			inst.sg:GoToState("bite_down_reposition")
			return
		else
			inst.sg.mem.in_position = nil
		end
	end,
})

SGCommon.States.AddMonsterDeathStates(states,
{
	onenter_fn = function(inst)
		-- Clones don't play the death animation; instead they go to an explosion state.
		if inst:HasTag("clone") then
			inst.sg:ForceGoToState("clone_death_pre")
		end
	end,
})
SGBossCommon.States.AddBossStates(states)

SGRegistry:AddData("sg_bandicoot", states)

return StateGraph("sg_bandicoot", states, events, "idle")
