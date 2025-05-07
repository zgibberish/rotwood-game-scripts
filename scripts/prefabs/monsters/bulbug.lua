local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local lume = require"util.lume"
local fmodtable = require "defs.sound.fmodtable"
local Power = require"defs.powers"
local SGCommon = require "stategraphs.sg_common"

local assets =
{
	Asset("ANIM", "anim/bulbug_bank.zip"),
	Asset("ANIM", "anim/bulbug_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/bulbug_bank.zip"),
	Asset("ANIM", "anim/bulbug_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",
	"bulbug_shield_buff",
	"bulbug_damage_buff",

	--Drops
	GroupPrefab("fx_bulbug"),
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_bulbug"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "bulbug")

local attacks =
{
	buff_shield =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 45,
		cooldown = 6.67,
		initialCooldown = 0,
		pre_anim = "spell_cast_pre",
		hold_anim = "spell_cast_loop",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			return false -- does not trigger through attack flow
		end
	},
	strike =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 30,
		cooldown = 2,
		initialCooldown = 0,
		pre_anim = "strike_pre",
		hold_anim = "strike_hold",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			return inst:ShouldFight() and trange:IsInRange(3)
		end
	},
	evade =
	{
		priority = 1,
		damage_mod = 0.25,
		startup_frames = 4,
		cooldown = 13.3,
		initialCooldown = 0,
		pre_anim = "evade_pre",
		hold_anim = "evade_hold",
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			return not inst:ShouldFight() and trange:IsInRange(5)
		end
	},
}

local elite_attacks =
{
	buff_shield =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 15,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "spell_cast_pre",
		hold_anim = "spell_cast_loop",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			return false -- does not trigger through attack flow
		end
	},
	buff_damage =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 75,
		cooldown = 6.67,
		initialCooldown = 0,
		pre_anim = "spell_cast_pre",
		hold_anim = "spell_cast_loop",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			return false -- does not trigger through attack flow
		end
	},
	strike =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 15,
		cooldown = 2,
		initialCooldown = 0,
		pre_anim = "strike_pre",
		hold_anim = "strike_hold",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			return inst:ShouldFight() and trange:IsInRange(3)
		end
	},
	evade =
	{
		priority = 1,
		damage_mod = 0.25,
		startup_frames = 4,
		cooldown = 1.33,
		initialCooldown = 0,
		pre_anim = "evade_pre",
		hold_anim = "evade_hold",
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			return not inst:ShouldFight() and trange:IsInRange(10)
		end
	},
}

local function ShouldFight(inst)
	local x,z = inst.Transform:GetWorldXZ()
	local ignore_tags = not inst:HasTag("elite") and { "bulbug" } or nil
	local possible_targets = FindTargetTagGroupEntitiesInRange(x, z, 999, inst.components.combat:GetFriendlyTargetTags(), ignore_tags )

	-- Elite bulbug should always fight when there's no targets to buff, or if it's the last monster remaining.
	if #possible_targets == 1 and possible_targets[1] == inst then
		return true
	end
	if inst:HasTag("elite") then
		local shield_def = Power.Items.SHIELD.shield
		for _, target in ipairs(possible_targets) do
			local pm = target.components.powermanager
			if pm and pm:GetPowerStacks(shield_def) == 0 then
				return false
			end
		end
		return true
	end

	return lume.count(possible_targets) == 0
end

local MONSTER_SIZE = 1.5

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst:AddTag("bulbug")

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.MEDIUM)

	inst.HitBox:SetNonPhysicsRect(1.5)
	inst.Transform:SetScale(1.2, 1.2, 1.2)
	inst.components.scalable:SnapshotBaseSize()

	inst.AnimState:SetBank("bulbug_bank")
	inst.AnimState:SetBuild("bulbug_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:SetStateGraph("sg_bulbug")
	inst:SetBrain("brain_bulbug")

	inst.ShouldFight = ShouldFight

	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.bulbug_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.bulbug_bodyfall)
	-- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.bulbug_hit)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.bulbug_knockdown)

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("bulbug_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	return inst
end

local function shield_hitbox(inst, data)
	local power_def = Power.Items.SHIELD.shield
	local power_stacks = power_def.max_stacks
	local apply_once = false

	for i = 1, #data.targets do
		local v = data.targets[i]
		local pm = v.components.powermanager
		if v ~= inst.owner and pm and (not apply_once or pm:GetPowerStacks(power_def) == 0) then
			inst.owner:DoTaskInAnimFrames(i, function(xinst)
				if xinst ~= nil and xinst:IsValid() and pm ~= nil then
					pm:AddPower(pm:CreatePower(power_def), power_stacks)
				end
			end)
		end
	end
end

local function damage_hitbox(inst, data)
	local power_def = Power.Items.STATUSEFFECT.juggernaut
	local power_stacks = 20
	local apply_once = true

	for i = 1, #data.targets do
		local v = data.targets[i]
		local pm = v.components.powermanager
		if pm and (not apply_once or pm:GetPowerStacks(power_def) == 0) then
			inst.owner:DoTaskInAnimFrames(i, function(xinst)
				if xinst ~= nil and xinst:IsValid() and pm ~= nil then
					pm:AddPower(pm:CreatePower(power_def), power_stacks)
				end
			end)
		end
	end
end

local function shield_buff_fn(prefabname)
	local inst = CreateEntity()

	-- This is called slightly after aoe_fn, same frame, and contains the instigator reference which is networked
	inst.OnSetSpawnInstigator = function(inst, instigator)
		inst.owner = instigator
		inst.components.hitbox:SetHitGroup(HitGroup.MOB) --instigator.components.hitbox:GetHitGroup())
		inst.components.hitbox:SetHitFlags(HitGroup.CREATURES) --instigator.components.hitbox:GetHitFlags())
		inst.components.hitbox:PushCircle(0, 0, instigator:HasTag("elite") and 18 or 12, HitPriority.MOB_DEFAULT)
		SGCommon.Fns.SpawnAtDist(instigator, "fx_bulbug_shield_buff_cast", 0)
	end

	inst.entity:AddTransform()
	inst.entity:AddHitBox()
	inst:AddComponent("hitbox")
	inst:AddComponent("combat")
	inst:ListenForEvent("hitboxtriggered", shield_hitbox)
	inst.components.hitbox:SetUtilityHitbox(true)
	inst.components.hitbox:StartRepeatTargetDelay()
	inst:DelayedRemove()

	return inst
end

local function damage_buff_fn(prefabname)
	local inst = CreateEntity()

	-- This is called slightly after aoe_fn, same frame, and contains the instigator reference which is networked
	inst.OnSetSpawnInstigator = function(inst, instigator)
		inst.owner = instigator
		inst.components.hitbox:SetHitGroup(HitGroup.MOB) --instigator.components.hitbox:GetHitGroup())
		inst.components.hitbox:SetHitFlags(HitGroup.CREATURES) --instigator.components.hitbox:GetHitFlags())
		inst.components.hitbox:PushCircle(0, 0, 18, HitPriority.MOB_DEFAULT)
		SGCommon.Fns.SpawnAtDist(instigator, "fx_bulbug_damage_buff_cast", 0)
	end

	inst.entity:AddTransform()
	inst.entity:AddHitBox()
	inst:AddComponent("hitbox")
	inst:AddComponent("combat")
	inst:ListenForEvent("hitboxtriggered", damage_hitbox)
	inst.components.hitbox:SetUtilityHitbox(true)
	inst.components.hitbox:StartRepeatTargetDelay()
	inst:DelayedRemove()

	return inst
end

return Prefab("bulbug", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("bulbug_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("bulbug_shield_buff", shield_buff_fn, nil, nil, nil, NetworkType_None)
	, Prefab("bulbug_damage_buff", damage_buff_fn, nil, nil, nil, NetworkType_None)
