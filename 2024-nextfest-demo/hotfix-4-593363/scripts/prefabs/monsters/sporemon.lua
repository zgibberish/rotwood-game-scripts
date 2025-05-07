local monsterutil = require "util.monsterutil"
local spawnutil = require "util.spawnutil"
local lume = require "util.lume"

local assets =
{
	Asset("ANIM", "anim/sporemon_bank.zip"),
	Asset("ANIM", "anim/sporemon_build.zip"),
	Asset("ANIM", "anim/trap_bomb_spore.zip"),
	Asset("ANIM", "anim/fx_shadow.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/sporemon_bank.zip"),
	Asset("ANIM", "anim/sporemon_elite_build.zip"),
	Asset("ANIM", "anim/trap_bomb_spore.zip")
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",
	--Drops
	GroupPrefab("drops_generic"),
}
--prefabutil.SetupDeathFxPrefabs(prefabs, "beets") --Just use beets for now

local projectile_prefabs =
{
	"sporemon_projectile_dmg",
	"sporemon_projectile_confuse",
	"sporemon_projectile_juggernaut",
	"sporemon_symbol_damage",
	"sporemon_symbol_confuse",
	"sporemon_symbol_juggernaut"
}

local attacks =
{
	bite_r =
	{
		priority = 2,
		damage_mod = 1,
		cooldown = 0,
		initialCooldown = 0,
		startup_frames = 12,
		pre_anim = "atk_r_bite_pre",
		hold_anim = "atk_r_bite_hold",
		start_conditions_fn = function(inst, data, trange)
			if trange:TestBeamDirectional(0, 3.5, 2) then
				return true
			end
		end
	},

	bite_l =
	{
		priority = 2,
		damage_mod = 1,
		cooldown = 0,
		initialCooldown = 0,
		startup_frames = 12,
		pre_anim = "atk_l_bite_pre",
		hold_anim = "atk_l_bite_hold",
		start_conditions_fn = function(inst, data, trange)
			if trange:TestBeamDirectional(-3.5, 0, 2) then
				return true
			end
		end
	},

    spore =
    {
		priority = 1,
		damage_mod = 1,
		cooldown = 6,
		initialCooldown = 5,
		startup_frames = 18,
		pre_anim = "shoot_pre",
		hold_anim = "shoot_hold",
		start_conditions_fn = function(inst, data, trange)
			if trange:IsBetweenRange(2, 24) then
				return true
			end
		end
    }
}

local elite_attacks =
{
	spike =
	{
		priority = 3,
		damage_mod = 1.2,
		cooldown = 6,
		initialCooldown = 0,
		startup_frames = 24,
		pre_anim = "atk_spike_pre",
		hold_anim = "atk_spike_hold",
		start_conditions_fn = function(inst, data, trange)
			if trange:TestBeamDirectional(-3.7, 3.7, 2) then
				return true
			end
		end
	}
}

local MONSTER_SIZE = 1.3

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeStationaryMonster(inst, MONSTER_SIZE)

	inst.HitBox:SetNonPhysicsRect(1.1)
	inst.Transform:SetScale(0.9, 0.9, 0.9)
	inst.components.scalable:SnapshotBaseSize()

	inst.components.attacktracker:SetMinimumCooldown(0.5)

	inst.AnimState:SetBank("sporemon_bank")
	inst.AnimState:SetBuild("sporemon_build")
	inst.AnimState:PlayAnimation("idle", true)

	inst:SetStateGraph("sg_sporemon")
	inst:SetBrain("brain_treemon")

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("sporemon_elite_build")
	inst.components.attacktracker:AddAttacks(lume.merge(attacks, elite_attacks))
	monsterutil.ExtendToEliteMonster(inst)

	return inst
end

local function HandleSporeSetup(inst, owner)
	inst.owner = owner
	spawnutil.ApplyCharmColors(inst, owner, "projectile")
	inst.components.hitbox:SetHitFlags(HitGroup.ALL)
end
local function SporeSetup(inst, owner)
	if inst:ShouldSendNetEvents() then
		TheSim:HandleEntitySetup(inst.GUID, owner.GUID)
	else
		HandleSporeSetup(inst, owner)
	end
end

local function projectile_fn(prefabname)
	local inst = spawnutil.CreateComplexProjectile(
	{
		name = prefabname,
		hits_targets = true,
		bank = "trap_bomb_spore",
		build = "trap_bomb_spore",
		start_anim = "damage_spin",
		stategraph = "sg_sporemon_projectile",
	})

	inst.Setup = SporeSetup --monsterutil.BasicProjectileSetup
	inst.HandleSetup = HandleSporeSetup

	return inst
end
local function projectile_fn_confuse(prefabname)
	local inst = spawnutil.CreateComplexProjectile(
	{
		name = prefabname,
		hits_targets = true,
		bank = "trap_bomb_spore",
		build = "trap_bomb_spore",
		start_anim = "confuse_spin",
		stategraph = "sg_sporemon_projectile",
	})

	inst.Setup = SporeSetup --monsterutil.BasicProjectileSetup
	inst.HandleSetup = HandleSporeSetup

	return inst
end
local function projectile_fn_juggernaut(prefabname)
	local inst = spawnutil.CreateComplexProjectile(
	{
		name = prefabname,
		hits_targets = true,
		bank = "trap_bomb_spore",
		build = "trap_bomb_spore",
		start_anim = "juggernaut_spin",
		stategraph = "sg_sporemon_projectile",
	})

	inst.Setup = SporeSetup --monsterutil.BasicProjectileSetup
	inst.HandleSetup = HandleSporeSetup

	return inst
end

-----------
--Functions to set projectile symbols on remote players
--These are sent to the remote players after the host decides on a projectile to shoot since symbol swaps are not sunc in AnimState
--This isnt the most elegant but it's relatively self contained, localized to this entity and is working.
--Other options are to duplicate the shoot animations and states for each projectile in sporemon which has it's own downsides
local function symbol_damage(prefabname)
	local inst = CreateEntity()
	inst.OnSetSpawnInstigator = function(inst, instigator)
		if (instigator) then
			instigator.AnimState:OverrideSymbol("lure_spore", "trap_bomb_spore", "lure_spore_damage")
		end
	end
	inst.entity:AddTransform()
	inst:DelayedRemove()
	return inst
end
local function symbol_confuse(prefabname)
	local inst = CreateEntity()
	inst.OnSetSpawnInstigator = function(inst, instigator)
		if (instigator) then
			instigator.AnimState:OverrideSymbol("lure_spore", "trap_bomb_spore", "lure_spore_confuse")
		end
	end
	inst.entity:AddTransform()
	inst:DelayedRemove()
	return inst
end
local function symbol_juggernaut(prefabname)
	local inst = CreateEntity()
	inst.OnSetSpawnInstigator = function(inst, instigator)
		if (instigator) then
			instigator.AnimState:OverrideSymbol("lure_spore", "trap_bomb_spore", "lure_spore_juggernaut")
		end
	end
	inst.entity:AddTransform()
	inst:DelayedRemove()
	return inst
end

return	Prefab("sporemon", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn),
		Prefab("sporemon_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn),
		Prefab("sporemon_projectile_dmg", projectile_fn, assets, projectile_prefabs, nil, NetworkType_SharedAnySpawn),
		Prefab("sporemon_projectile_confuse", projectile_fn_confuse, assets, projectile_prefabs, nil, NetworkType_SharedAnySpawn),
		Prefab("sporemon_projectile_juggernaut", projectile_fn_juggernaut, assets, projectile_prefabs, nil, NetworkType_SharedAnySpawn),
		Prefab("sporemon_symbol_damage", symbol_damage, assets, projectile_prefabs, nil, NetworkType_None),
		Prefab("sporemon_symbol_confuse", symbol_confuse, assets, projectile_prefabs, nil, NetworkType_None),
		Prefab("sporemon_symbol_juggernaut", symbol_juggernaut, assets, projectile_prefabs, nil, NetworkType_None)
