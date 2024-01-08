local SGCommon = require "stategraphs.sg_common"
local spawnutil = require "util.spawnutil"
local monsterutil = require "util.monsterutil"

local bullet_prefabs =
{
	"projectile_magic_hit",
	"projectile_magic",
}

local function OnHitBoxTriggered(inst, data)
	SGCommon.Events.OnProjectileHitboxTriggered(inst, data, {
		damage_mod = inst.damage_mod, -- Defined in the prefab's setup function.
		hitstoplevel = HitStopLevel.LIGHT,
		damage_override = inst.damage_override, -- Defined in the prefab's setup function.
		hitflags = Attack.HitFlags.PROJECTILE,
		source = inst.source,
		combat_attack_fn = "DoBasicAttack",
		hit_fx = "projectile_magic_hit",
		hit_fx_offset_x = 1,
	})

	--inst:DelayedRemove()
end

local function Setup(inst, owner, damage_mod, source, damage_override)
	assert(type(source) == "string")
	inst.owner = owner
	inst.damage_mod = damage_mod or 1
	inst.damage_override = damage_override
	inst.source = source

	inst.Physics:StartPassingThroughObjects()
end

local function bullet_fn(prefabname)
	local inst = spawnutil.CreateProjectile(
	{
		name = prefabname,
		physics_size = 0.5,
		hits_targets = true,
		hit_group = HitGroup.NONE,
		hit_flags = HitGroup.CREATURES,
		does_hitstop = true,
		twofaced = true,
		stategraph = "sg_generic_projectile",
		fx_prefab = "projectile_magic",
		motor_vel = 20,
	})

	inst.Setup = Setup --monsterutil.BasicProjectileSetup
	inst.components.projectilehitbox:PushBeam(-2.5, 0, 1.75, HitPriority.PLAYER_PROJECTILE, true)
									:PushBeam(-0.75, 0, 1, HitPriority.PLAYER_PROJECTILE)
									:SetTriggerFunction(OnHitBoxTriggered)

	return inst
end

return Prefab("generic_projectile", bullet_fn, nil, bullet_prefabs, nil, NetworkType_SharedAnySpawn)
