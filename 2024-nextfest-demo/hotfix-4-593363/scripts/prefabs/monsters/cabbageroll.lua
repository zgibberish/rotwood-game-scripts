local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local DebugDraw = require "util.debugdraw"
local fmodtable = require "defs.sound.fmodtable"

local AttackDebugDrawEnabled = false

-- assign a random range to an enemy for when a particular attack is considered
local UseAttackRanges = true
-- throttle whether an attack is triggered based on the enemy's nearby neighbours
local UseAttackThrottling = false
-- provide a combat cooldown value when an attack is attempted but does not succeed
local UseAttackRetryCooldowns = true
-- enable whether or not certain attacks can be used against helpless players (hit/prone/airborne/knockdown)
local CanAttackHelpless = false

local function IsTargetHelpless(inst)
	return inst.sg and
		(inst.sg:HasStateTag("hit") or inst.sg:HasStateTag("knockdown") or inst.sg:HasStateTag("prone") or inst.sg:HasStateTag("airborne"))
end

local assets =
{
	Asset("ANIM", "anim/cabbageroll_single_bank.zip"),
	Asset("ANIM", "anim/cabbagerolls_double_bank.zip"),
	Asset("ANIM", "anim/cabbagerolls_bank.zip"),
	Asset("ANIM", "anim/cabbageroll_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/cabbageroll_single_bank.zip"),
	Asset("ANIM", "anim/cabbagerolls_double_bank.zip"),
	Asset("ANIM", "anim/cabbagerolls_bank.zip"),
	Asset("ANIM", "anim/cabbageroll_elite_build.zip"),
}

local prefabs =
{
	GroupPrefab("drops_cabbageroll"),
	GroupPrefab("drops_currency"),
	GroupPrefab("drops_generic"),

	"fx_hurt_sweat",
	"fx_low_health_ring",
}
prefabutil.SetupDeathFxPrefabs(prefabs, "cabbageroll")

local attacks =
{
	-- 1 cabbageroll
	[1] =
	{
		roll =
		{
			type = "ranged",
			startup_frames = 45,
			cooldown = 5.33,
			pre_anim = "roll_pre",
			hold_anim = "roll_pre_hold",
			targetrange = { base = 4, steps = 4, scale = 2, centered = false },
			max_attacks_per_target = 2,
			retry_cooldown_range = { base = 1, steps = 5, scale = 1, centered = false},
			start_conditions_fn = function(inst, data, trange)
				local result = false
				local use_retry_cooldown = false
				local range = UseAttackRanges and data.targetrange or 4
				if not CanAttackHelpless and IsTargetHelpless(trange.target) then
					result = false
					use_retry_cooldown = UseAttackRetryCooldowns
				elseif trange:IsInRange(range) then
					result = monsterutil.MaxAttacksPerTarget(inst, data)
					use_retry_cooldown = UseAttackRetryCooldowns
				end
				if AttackDebugDrawEnabled then
					DebugDraw.GroundCircle(trange.x, trange.z, 1, result and WEBCOLORS.GREEN or WEBCOLORS.RED, 1, result and 1.0 or 0.5)
				end
				return result, use_retry_cooldown
			end
		},
		bite =
		{
			type = "melee",
			startup_frames = 30,
			cooldown = 4,
			initialCooldown = 0,
			pre_anim = "bite_pre",
			hold_anim = "bite_pre_hold",
			targetrange = { base = 4, steps = 2, scale = 1, centered = false },
			max_attacks_per_target = 2,
			retry_cooldown_range = { base = 0.5, steps = 8, scale = 1, centered = false},
			start_conditions_fn = function(inst, data, trange)
				local result = false
				local use_retry_cooldown = false
				local range = UseAttackRanges and data.targetrange or 7
				if trange:TestCone45(0, range, 1) then
					result = monsterutil.MaxAttacksPerTarget(inst, data)
					use_retry_cooldown = UseAttackRetryCooldowns
				end
				if AttackDebugDrawEnabled then
					DebugDraw.GroundCircle(trange.x, trange.z, 1, result and WEBCOLORS.GREEN or WEBCOLORS.RED, 1, result and 1.0 or 0.5)
				end
				return result, use_retry_cooldown
			end
		},
	},

-- 2 stack
	[2] =
	{
		slam =
		{
			type = "melee",
			pre_anim = "slam_pre",
			hold_anim = "slam_hold",
			startup_frames = 30,
			cooldown = 2.66,
			targetrange = { base = 4, steps = 4, scale = 2, centered = false },
			max_attacks_per_target = 2,
			retry_cooldown_range = { base = 0.5, steps = 8, scale = 1, centered = false},
			start_conditions_fn = function(inst, data, trange)
				local result = false
				local use_retry_cooldown = false
				local dx2 = math.max(0, trange.absdx - trange.targetsize - 2)
				local dz2 = math.max(0, trange.absdz - trange.targetdepth - .5)
				local range = UseAttackRanges and data.targetrange or 2
				if dx2 * dx2 + dz2 * dz2 < range * range then
					result = monsterutil.MaxAttacksPerTarget(inst, data)
					use_retry_cooldown = UseAttackRetryCooldowns
				end
				if AttackDebugDrawEnabled then
					DebugDraw.GroundCircle(trange.x, trange.z, 1, result and WEBCOLORS.GREEN or WEBCOLORS.RED, 1, result and 1.0 or 0.5)
				end
				return result, use_retry_cooldown
			end,
		},

		throw =
		{
			type = "ranged",
			pre_anim = "throw_pre",
			hold_anim = "throw_hold",
			startup_frames = 35,
			cooldown = 10.67,
			start_conditions_fn = function(inst, data, trange)
				if trange:TestDetachedCone45(3, 12, 1) then
					return true
				end
			end,
		},
	},

	-- 3 stack
	[3] =
	{
		smash =
		{
			type = "melee",
			pre_anim = "smash_pre",
			hold_anim = "smash_hold",
			startup_frames = 30,
			cooldown = 2.67,
			targetrange = { base = 3.6, steps = 4, scale = 2, centered = false },
			max_attacks_per_target = 2,
			retry_cooldown_range = { base = 0.5, steps = 8, scale = 1, centered = false},
			start_conditions_fn = function(inst, data, trange)
				local result = false
				local use_retry_cooldown = false
				local range = UseAttackRanges and data.targetrange or 4.6
				if trange:TestBeam(0, range, 1) then
					result = monsterutil.MaxAttacksPerTarget(inst, data)
					use_retry_cooldown = UseAttackRetryCooldowns
				end
				if AttackDebugDrawEnabled then
					DebugDraw.GroundCircle(trange.x, trange.z, 1, result and WEBCOLORS.GREEN or WEBCOLORS.RED, 1, result and 1.0 or 0.5)
				end
				return result, use_retry_cooldown
			end,
		},
		bodyslam =
		{
			type = "melee_special",
			priority = 2,
			pre_anim = "bodyslam_pre",
			hold_anim = "body_slam_hold",
			startup_frames = 40,
			cooldown = 10.67,
			start_conditions_fn = function(inst, data, trange)
				local result = false
				local use_retry_cooldown = false
				local range = 5
				if trange:IsInRange(range) then
					result = monsterutil.MaxAttacksPerTarget(inst, data)
					use_retry_cooldown = UseAttackRetryCooldowns
				end
				if AttackDebugDrawEnabled then
					DebugDraw.GroundCircle(trange.x, trange.z, 1, result and WEBCOLORS.GREEN or WEBCOLORS.RED, 1, result and 1.0 or 0.5)
				end
				return result, use_retry_cooldown
			end,
		},
	},
}

local elite_attacks =
{
	-- 1 cabbageroll
	[1] =
	{
		elite_roll =
		{
			type = "ranged",
			startup_frames = 30,
			cooldown = 5.33,
			pre_anim = "elite_roll_pre",
			hold_anim = "elite_roll_hold",
			targetrange = { base = 10, steps = 4, scale = 2, centered = false },
			max_attacks_per_target = 2,
			retry_cooldown_range = { base = 1, steps = 5, scale = 1, centered = false},
			start_conditions_fn = function(inst, data, trange)
				local result = false
				local use_retry_cooldown = false
				local range = UseAttackRanges and data.targetrange or 10
				if not CanAttackHelpless and IsTargetHelpless(trange.target) then
					result = false
					use_retry_cooldown = UseAttackRetryCooldowns
				elseif trange:IsInRange(range) then
					result = monsterutil.MaxAttacksPerTarget(inst, data)
					use_retry_cooldown = UseAttackRetryCooldowns
				end
				if AttackDebugDrawEnabled then
					DebugDraw.GroundCircle(trange.x, trange.z, 1, result and WEBCOLORS.GREEN or WEBCOLORS.RED, 1, result and 1.0 or 0.5)
				end
				return result, use_retry_cooldown
			end
		},
		bite =
		{
			type = "melee",
			startup_frames = 30,
			cooldown = 4,
			initialCooldown = 0,
			pre_anim = "bite_pre",
			hold_anim = "bite_pre_hold",
			targetrange = { base = 4, steps = 4, scale = 2, centered = false },
			max_attacks_per_target = 2,
			retry_cooldown_range = { base = 0.5, steps = 8, scale = 1, centered = false},
			start_conditions_fn = function(inst, data, trange)
				local result = false
				local use_retry_cooldown = false
				local range = UseAttackRanges and data.targetrange or 7
				if trange:TestCone45(0, range, 1) then
					result = monsterutil.MaxAttacksPerTarget(inst, data)
					use_retry_cooldown = UseAttackRetryCooldowns
				end
				if AttackDebugDrawEnabled then
					DebugDraw.GroundCircle(trange.x, trange.z, 1, result and WEBCOLORS.GREEN or WEBCOLORS.RED, 1, result and 1.0 or 0.5)
				end
				return result, use_retry_cooldown
			end
		},
		roll = -- used only when thrown by a 2 stack
		{
			type = "ranged",
			start_conditions_fn = function(inst, data, trange)
				return false
			end
		},

	},

-- 2 stack
	[2] =
	{
		slam =
		{
			type = "melee",
			pre_anim = "slam_pre",
			hold_anim = "slam_hold",
			startup_frames = 30,
			cooldown = 2.67,
			targetrange = { base = 4, steps = 4, scale = 2, centered = false },
			max_attacks_per_target = 2,
			retry_cooldown_range = { base = 0.5, steps = 8, scale = 1, centered = false},
			start_conditions_fn = function(inst, data, trange)
				local result = false
				local use_retry_cooldown = false
				local dx2 = math.max(0, trange.absdx - trange.targetsize - 2)
				local dz2 = math.max(0, trange.absdz - trange.targetdepth - .5)
				local range = UseAttackRanges and data.targetrange or 2
				if dx2 * dx2 + dz2 * dz2 < range * range then
					result = monsterutil.MaxAttacksPerTarget(inst, data)
					use_retry_cooldown = UseAttackRetryCooldowns
				end
				if AttackDebugDrawEnabled then
					DebugDraw.GroundCircle(trange.x, trange.z, 1, result and WEBCOLORS.GREEN or WEBCOLORS.RED, 1, result and 1.0 or 0.5)
				end
				return result, use_retry_cooldown
			end,
		},

		throw =
		{
			type = "ranged",
			pre_anim = "throw_pre",
			hold_anim = "throw_hold",
			startup_frames = 35,
			cooldown = 10.67,
			start_conditions_fn = function(inst, data, trange)
				if trange:TestDetachedCone45(3, 12, 1) then
					return true
				end
			end,
		},
	},

	-- 3 stack
	[3] =
	{
		smash =
		{
			type = "melee",
			pre_anim = "smash_pre",
			hold_anim = "smash_hold",
			startup_frames = 30,
			cooldown = 2.67,
			targetrange = { base = 3.6, steps = 4, scale = 2, centered = false },
			max_attacks_per_target = 2,
			retry_cooldown_range = { base = 0.5, steps = 8, scale = 1, centered = false},
			start_conditions_fn = function(inst, data, trange)
				local result = false
				local use_retry_cooldown = false
				local range = UseAttackRanges and data.targetrange or 4.6
				if trange:TestBeam(0, range, 1) then
					result = monsterutil.MaxAttacksPerTarget(inst, data)
					use_retry_cooldown = UseAttackRetryCooldowns
				end
				if AttackDebugDrawEnabled then
					DebugDraw.GroundCircle(trange.x, trange.z, 1, result and WEBCOLORS.GREEN or WEBCOLORS.RED, 1, result and 1.0 or 0.5)
				end
				return result, use_retry_cooldown
			end,
		},
		bodyslam =
		{
			type = "melee_special",
			priority = 2,
			pre_anim = "bodyslam_pre",
			hold_anim = "body_slam_hold",
			startup_frames = 40,
			cooldown = 10.67,
			start_conditions_fn = function(inst, data, trange)
				local result = false
				local use_retry_cooldown = false
				local range = 5
				if trange:IsInRange(range) then
					result = monsterutil.MaxAttacksPerTarget(inst, data)
					use_retry_cooldown = UseAttackRetryCooldowns
				end
				if AttackDebugDrawEnabled then
					DebugDraw.GroundCircle(trange.x, trange.z, 1, result and WEBCOLORS.GREEN or WEBCOLORS.RED, 1, result and 1.0 or 0.5)
				end
				return result, use_retry_cooldown
			end,
		},
	},
}

local MONSTER_SIZE = 0.9

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.SMALL)

	inst.AnimState:SetBuild("cabbageroll_build")

	inst.components.timer:StartTimer("combine_cd", 8)

	inst:AddComponent("cabbagerollstracker")

	inst:SetBrain("brain_cabbagerolls")

	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.cabbageroll_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.cabbageroll_bodyfall)

   -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
   inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.cabbageroll_knockdown)
   -- inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.AAAA_default_event)

	return inst
end

---------------------------------------------------------------------------------------

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst:AddComponent("cabbagetower")
	inst.components.cabbagetower.attacks = attacks
	inst.components.cabbagetower:SetSingle(true)

	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.cabbageroll_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.cabbageroll_bodyfall)

	-- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
	inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.cabbageroll_hit)
	inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.cabbageroll_knockdown)

	--[[
	inst.sg.mem.golden_mob = math.random() <= 0.03
	if (inst.sg.mem.golden_mob) then
		inst.components.coloradder:PushColor("gold", 0.8, 0.5, 0, 0)
	end
	--]]

	return inst
end

---------------------------------------------------------------------------------------

local function cabbagerolls2_fn()
	local master_roll = SpawnPrefab("cabbageroll")
	local hat_roll = SpawnPrefab("cabbageroll", master_roll)
	master_roll.components.cabbagetower:SetDouble(hat_roll)

	master_roll.components.foleysounder:SetFootstepSound(fmodtable.Event.cabbageroll_footstep)
	master_roll.components.foleysounder:SetBodyfallSound(fmodtable.Event.cabbageroll_bodyfall)

	hat_roll.components.foleysounder:SetFootstepSound(fmodtable.Event.cabbageroll_footstep)
	hat_roll.components.foleysounder:SetBodyfallSound(fmodtable.Event.cabbageroll_bodyfall)

   -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
	master_roll.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.cabbageroll_hit)
   	master_roll.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.cabbageroll_knockdown)

	return master_roll
end

---------------------------------------------------------------------------------------

local function cabbagerolls_fn()
	local master_roll = SpawnPrefab("cabbagerolls2")
	local hat_roll = SpawnPrefab("cabbageroll", master_roll)
	master_roll.components.cabbagetower:SetTriple(hat_roll)

	master_roll.components.foleysounder:SetFootstepSound(fmodtable.Event.cabbageroll_footstep)
	master_roll.components.foleysounder:SetBodyfallSound(fmodtable.Event.cabbageroll_bodyfall)

	hat_roll.components.foleysounder:SetFootstepSound(fmodtable.Event.cabbageroll_footstep)
	hat_roll.components.foleysounder:SetBodyfallSound(fmodtable.Event.cabbageroll_bodyfall)

   -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
   	master_roll.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.cabbageroll_hit)
   	master_roll.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.cabbageroll_knockdown)

	return master_roll
end

---------------------------------------------------------------------------------------

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("cabbageroll_elite_build")

	inst:AddComponent("cabbagetower")
	inst.components.cabbagetower.attacks = elite_attacks
	inst.components.cabbagetower:SetSingle(true)

	monsterutil.ExtendToEliteMonster(inst)

	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.cabbageroll_Elite_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.cabbageroll_bodyfall)

   -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
   inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.cabbageroll_Elite_hit)
   inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.cabbageroll_Elite_knockdown)

	return inst
end

---------------------------------------------------------------------------------------

local function cabbagerolls2_elite_fn()
	local master_roll = SpawnPrefab("cabbageroll_elite")
	local hat_roll = SpawnPrefab("cabbageroll_elite", master_roll)
	master_roll.components.cabbagetower:SetDouble(hat_roll)

	master_roll.components.foleysounder:SetFootstepSound(fmodtable.Event.cabbageroll_Elite_footstep)
	master_roll.components.foleysounder:SetBodyfallSound(fmodtable.Event.cabbageroll_bodyfall)

	hat_roll.components.foleysounder:SetFootstepSound(fmodtable.Event.cabbageroll_Elite_footstep)
	hat_roll.components.foleysounder:SetBodyfallSound(fmodtable.Event.cabbageroll_bodyfall)

   -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
   	master_roll.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.cabbageroll_hit)
   	master_roll.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.cabbageroll_knockdown)

	return master_roll
end

---------------------------------------------------------------------------------------

local function cabbagerolls_elite_fn()
	local master_roll = SpawnPrefab("cabbagerolls2_elite")
	local hat_roll = SpawnPrefab("cabbageroll_elite", master_roll)
	master_roll.components.cabbagetower:SetTriple(hat_roll)

	master_roll.components.foleysounder:SetFootstepSound(fmodtable.Event.cabbageroll_Elite_footstep)
	master_roll.components.foleysounder:SetBodyfallSound(fmodtable.Event.cabbageroll_bodyfall)

	hat_roll.components.foleysounder:SetFootstepSound(fmodtable.Event.cabbageroll_Elite_footstep)
	hat_roll.components.foleysounder:SetBodyfallSound(fmodtable.Event.cabbageroll_bodyfall)

   -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
   master_roll.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.cabbageroll_hit)
   master_roll.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.cabbageroll_knockdown)

	return master_roll
end

---------------------------------------------------------------------------------------

return Prefab("cabbageroll", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn),
	Prefab("cabbagerolls2", cabbagerolls2_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn),
	Prefab("cabbagerolls", cabbagerolls_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn),
	Prefab("cabbageroll_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn),
	Prefab("cabbagerolls2_elite", cabbagerolls2_elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn),
	Prefab("cabbagerolls_elite", cabbagerolls_elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)
