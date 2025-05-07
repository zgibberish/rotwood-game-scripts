local monsterutil = require "util.monsterutil"
local prefabutil = require "prefabs.prefabutil"
local spawnutil = require "util.spawnutil"

local assets =
{
	Asset("ANIM", "anim/treemon_bank.zip"),
	Asset("ANIM", "anim/treemon_build.zip"),
	Asset("ANIM", "anim/treemon_elite_build.zip"),
	Asset("ANIM", "anim/trap_treemon_pinecone.zip"),
	Asset("ANIM", "anim/fx_shadow.zip"),
}

local prefabs =
{
	"treemon_growth_root",
	"treemon_projectile",

	--Drops
	GroupPrefab("drops_treemon")
}
prefabutil.SetupDeathFxPrefabs(prefabs, "treemon")

local projectile_prefabs =
{
	"treemon_projectile",
}

local attacks =
{
	uproot =
	{
		priority = 2,
		damage_mod = 1,
		startup_frames = 20,
		cooldown = 2.67,
		initialCooldown = 0,
		pre_anim = "uproot_pre",
		hold_anim = "uproot_loop",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(10)
		end
	},

	shoot =
	{
		priority = 1,
		damage_mod = 0.75,
		startup_frames = 30,
		cooldown = 3.33,
		initialCooldown = 5,
		pre_anim = "shoot_pre",
		hold_anim = "shoot_hold",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(20)
		end
	},
}

local elite_attacks =
{
	elite_uproot =
	{
		priority = 2,
		damage_mod = 1,
		startup_frames = 20,
		cooldown = 0,
		initialCooldown = 0,
		pre_anim = "uproot_pre",
		hold_anim = "uproot_loop",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(15)
		end
	},

	elite_shoot =
	{
		priority = 1,
		damage_mod = 0.75,
		startup_frames = 30,
		cooldown = 0,
		initialCooldown = 0,
		pre_anim = "shoot_pre",
		hold_anim = "shoot_hold",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(30)
		end
	},
}

local function OnAttacked(inst, data)
	if data ~= nil and data.attack:GetAttacker() ~= nil then
		inst.components.combat:SetTarget(data.attack:GetAttacker())
	end
end

local function SpawnHitLeaves(inst, right)
	local fx = CreateEntity()

	fx.entity:AddTransform()
	fx.entity:AddAnimState()

	fx:AddTag("FX")
	fx:AddTag("NOCLICK")
	fx.persists = false

	fx.AnimState:SetBank("treemon_bank")

	if inst:HasTag("elite") then
		fx.AnimState:SetBuild("treemon_elite_build")
	else
		fx.AnimState:SetBuild("treemon_build")
	end

	fx.AnimState:PlayAnimation("leaves_"..(right and "r" or "l")..tostring(math.random(2)))
	fx.AnimState:SetFinalOffset(1)
	fx.AnimState:SetShadowEnabled(true)

	fx:AddComponent("bloomer")
	fx:AddComponent("colormultiplier")
	fx:AddComponent("coloradder")
	fx:AddComponent("hitstopper")

	inst.components.bloomer:AttachChild(fx)
	inst.components.colormultiplier:AttachChild(fx)
	inst.components.coloradder:AttachChild(fx)
	inst.components.hitstopper:AttachChild(fx)

	fx.Transform:SetPosition(inst.Transform:GetWorldPosition())

	fx:ListenForEvent("animover", fx.Remove)
end

local MONSTER_SIZE = 1
local ATTACK_COOLDOWN = 3

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeStationaryMonster(inst, MONSTER_SIZE)

	inst.AnimState:SetBank("treemon_bank")

	inst:AddComponent("snaptogrid")
	inst.components.snaptogrid:SetDimensions(2, 2, 0) --2x2 trunk on the ground
	inst.components.snaptogrid:SetDimensions(4, 4, 1) --4x4 leaves in the air

	inst.AnimState:PlayAnimation("idle", true)

	-- Hide pinecone symbols until the shoot state is entered
	inst.AnimState:HideSymbol("pinecone")
	inst.AnimState:HideSymbol("pinecone_hide")

	local frame = math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1
	inst.AnimState:SetFrame(frame)

	inst:SetStateGraph("sg_treemon")
	inst:SetBrain("brain_treemon")

	inst.SpawnHitLeaves = SpawnHitLeaves

	inst:ListenForEvent("attacked", OnAttacked)
	inst:ListenForEvent("knockback", OnAttacked)

	-- Add a random cooldown so that all treemon don't attack at the same time after spawning.
	-- local delay = math.random() * ATTACK_COOLDOWN
	-- inst.components.combat:StartCooldown(delay)

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("treemon_build")

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("treemon_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	monsterutil.AddOffsetHitbox(inst)

	return inst
end

---------------------------------------------------------------------------------------
-- Treemon Roots

local function SetupLinked(inst, owner)
	inst.owner = owner
	owner.components.bloomer:AttachChild(inst)
	owner.components.colormultiplier:AttachChild(inst)
	owner.components.coloradder:AttachChild(inst)
	owner.components.hitstopper:AttachChild(inst)

	if owner:HasTag("elite") then
		inst.AnimState:SetBuild("treemon_elite_build")
	else
		inst.AnimState:SetBuild("treemon_build")
	end

	local function onextruderoot()
		inst.sg:PushEvent("extrude")
	end

	local function oninterrupted()
		inst.sg:PushEvent("interrupted")
	end

	inst:ListenForEvent("extruderoot", onextruderoot, owner)
	inst:ListenForEvent("treemon_growth_interrupted", oninterrupted, owner)
	inst:ListenForEvent("onremove", oninterrupted, owner)
end

local function rootfn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddHitBox()

	inst.HitBox:SetEnabled(false)

	inst.Transform:SetTwoFaced()

	inst.AnimState:SetBank("treemon_bank")
	-- SetBuild in SetupLinked(), since we need to inherit the parent's build type.

	inst.AnimState:SetShadowEnabled(true)

	inst:AddComponent("bloomer")
	inst:AddComponent("colormultiplier")
	inst:AddComponent("coloradder")
	inst:AddComponent("hitstopper")

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.MOB)
	inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)

	inst:AddComponent("combat")

	inst:SetStateGraph("sg_treemon_growth_root")

	inst.persists = false

	inst.Setup = SetupLinked

	return inst
end

---------------------------------------------------------------------------------------
-- Treemon projectile
local function projectile_fn(prefabname)
	local inst = spawnutil.CreateComplexProjectile(
	{
		name = prefabname,
		hits_targets = true,
		bank = "trap_treemon_pinecone",
		build = "trap_treemon_pinecone",
		stategraph = "sg_treemon_projectile",
	})

	inst.Setup = monsterutil.BasicProjectileSetup

	return inst
end

return Prefab("treemon", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("treemon_elite", elite_fn, assets, nil, nil, NetworkType_SharedHostSpawn)
	, Prefab("treemon_growth_root", rootfn, assets, nil, nil, NetworkType_SharedAnySpawn)
	, Prefab("treemon_projectile", projectile_fn, assets, projectile_prefabs, nil, NetworkType_SharedAnySpawn)
