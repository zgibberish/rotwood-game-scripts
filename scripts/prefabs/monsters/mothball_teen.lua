local lume = require "util.lume"
local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local spawnutil = require "util.spawnutil"
require "components.hitbox" -- for HitGroup
local fmodtable = require "defs.sound.fmodtable"
local SGCommon = require "stategraphs.sg_common"


local assets =
{
	Asset("ANIM", "anim/mothball_teen_bank.zip"),
	Asset("ANIM", "anim/mothball_teen_build.zip"),
	Asset("ANIM", "anim/fx_mothball_teen.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/mothball_teen_bank.zip"),
	Asset("ANIM", "anim/mothball_teen_elite_build.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",
	"mothball_teen_projectile",
	"mothball_teen_projectile_elite",
	"mothball_teen_projectile2_elite",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_mothball"),
	GroupPrefab("drops_mothball_teen"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "mothball_teen")

local attacks =
{
	attack =
	{
		priority = 1,
		damage_mod = 1,
		startup_frames = 30,
		cooldown = 3.33,
		initialCooldown = 3,
		pre_anim = "attack_pre",
		start_conditions_fn = function(inst, data, trange)
			local target = inst.components.combat:GetTarget()
			if target then
				return (trange:IsOutOfRange(4) or inst.components.attacktracker:GetAttackCooldown() <= 0) and not target.sg:HasStateTag("prone")
			end

			return false
		end
	},

	escape =
	{
		priority = 2,
		startup_frames = 60,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "walk_pre",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(4) and inst.sg.mem.wants_to_escape
		end
	},
}

local MONSTER_SIZE = 0.75

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.MEDIUM)
	inst.Transform:SetScale(1.2, 1.2, 1.2)
	inst.components.scalable:SnapshotBaseSize()

	inst.AnimState:SetBank("mothball_teen_bank")
	inst.AnimState:SetBuild("mothball_teen_build")

	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst:SetStateGraph("sg_mothball_teen")
	inst:SetBrain("brain_mothball_teen")

	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.mothball_teen_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.AAAA_default_event)

	-- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.mothball_teen_hit)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.mothball_teen_knockdown)



	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = normal_fn(prefabname)

	inst.AnimState:SetBuild("mothball_teen_elite_build")

	monsterutil.ExtendToEliteMonster(inst)

	return inst
end

------------------------------------------------------------------------------
-- Projectile

--[[local bullet_prefabs =
{
	"projectile_mothball_teen",
	"projectile_mothball_teen_hit"
}]]

local function OnPhysicsCollide(inst, other)
	if inst and inst.sg and not inst.sg:HasStateTag("breaking") then
		inst.sg:GoToState("break")
	end
end

local projectile_cfg = {
	physics_size = 1,
	hits_targets = true,
	hit_group = HitGroup.MOB,
	hit_flags = HitGroup.CHARACTERS,
	does_hitstop = true,
	twofaced = true,
	--motor_vel = 4, -- The projectile starts up not moving; we'll manually move it in the projectile's stategraph
	stategraph = "sg_mothball_teen_projectile",
	fx_attach_to_hitstopper = true,
	outofbounds_timeout = 5,
	collision_callback = OnPhysicsCollide,
}

-- Why is assets re-used here? Will it actually appear in the projectile? Or
-- should it be a seprate list?
local proj_assets, proj_prefabs = spawnutil.CollectProjectileAssets(shallowcopy(assets), {}, projectile_cfg)

local function projectile_fn(prefabname, fx_prefab)
	local inst = spawnutil.CreateProjectile(
		lume.overlaymaps({
			name = prefabname,
			fx_prefab = fx_prefab or "projectile_teen_mothball",
		}, projectile_cfg))

	inst.Setup = monsterutil.BasicProjectileSetup

	monsterutil.BuildTuningTable(inst, prefabname)

	inst.components.projectilehitbox:PermanentlyDisableTrigger()
	inst:AddComponent("powermanager")
	inst:AddComponent("timer") -- some powers use timer

	return inst
end

-- Slow effect projectile
local function elite_projectile_fn(prefabname, fx_prefab)
	local inst = projectile_fn(prefabname, fx_prefab)
	return inst
end

-- Confuse effect projectile
local function elite_projectile2_fn(prefabname)
	local inst = elite_projectile_fn("mothball_teen_projectile_elite", "projectile_teen_mothball_elite")
	inst:AddTag("confuse")

	-- Override the tuning properties here manually; monsterutil.BuildTuningTable() doesn't inherit tuning properties from this prefab's name.
	for key, value in pairs(inst.tuning) do
		inst.tuning[key] = TUNING[prefabname][key] or value
	end

	inst.AnimState:SetAddColor(1, 0, 0, 1) -- TODO: need a proper art pass to differentiate the slow & confuse projectiles.

	return inst
end

-- Locally spawned hitbox objects for burst attack
local function aoe_hitbox(inst, data)
	-- Teen mothball projectiles cannot affect other projectiles; if one is in the hit data, remove it before processing.
	for i, target in ipairs(data.targets) do
		if target:HasTag("projectile") then
			table.remove(data.targets, i)
		end
	end

	local effect_type = inst:HasTag("confuse") and "confused" or "slowed"
	local hit = SGCommon.Events.OnProjectileHitboxTriggered(inst, data, {
		attackdata_id = "attack",
		damage_mod = 0,
		disable_damage_number = true,
		hitstoplevel = HitStopLevel.MEDIUM,
		pushback = 0.4,
		-- hitflags = Attack.HitFlags.PROJECTILE,
		combat_attack_fn = "DoKnockbackAttack",
		-- Change later? hit fx is played as an anim on the 'break' state
		hit_fx_offset_x = 0.5,
		disable_hit_reaction = true,
		can_hit_self = true,
		keep_alive = true, -- Removed when the animation of the FX is over, because of the above ^ hit fx note.
		hit_target_pst_fn = function(_inst, target)
			if target.components.powermanager then
				target.components.powermanager:AddPowerByName(effect_type, 100)
			end
		end,
	})
end

local function aoe_fn(prefabname)
	local inst = CreateEntity()

	-- This is called slightly after aoe_fn, same frame, and contains the instigator reference which is networked
	inst.OnSetSpawnInstigator = function(inst, instigator)
		inst.owner = instigator
		inst.components.hitbox:SetHitGroup(HitGroup.MOB)
		inst.components.hitbox:SetHitFlags(HitGroup.ALL)
		inst.components.hitbox:SetUtilityHitbox(true) --This happens so quick after being hit by the ball that the player is still invulnerable
		inst.components.hitbox:PushCircle(0, 0, 3.5, HitPriority.MOB_PROJECTILE)
	end

	inst.entity:AddTransform()
	inst.entity:AddHitBox()
	inst:AddComponent("hitbox")
	inst:AddComponent("combat")
	inst:ListenForEvent("hitboxtriggered", aoe_hitbox)
	inst.components.hitbox:StartRepeatTargetDelay()
	inst:DelayedRemove()

	return inst
end
------------------------------------------------------------------------------

return Prefab("mothball_teen", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("mothball_teen_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("mothball_teen_projectile", projectile_fn, proj_assets, proj_prefabs, nil, NetworkType_SharedAnySpawn)
	, Prefab("mothball_teen_projectile_elite", elite_projectile_fn, proj_assets, proj_prefabs, nil, NetworkType_SharedAnySpawn)
	, Prefab("mothball_teen_projectile2_elite", elite_projectile2_fn, proj_assets, proj_prefabs, nil, NetworkType_SharedAnySpawn)
	, Prefab("mothball_teen_projectile_aoe", aoe_fn, nil, nil, nil, NetworkType_None)
