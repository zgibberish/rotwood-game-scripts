local prefabutil = require "prefabs.prefabutil"
local monsterutil = require "util.monsterutil"
local spawnutil = require "util.spawnutil"
local fmodtable = require "defs.sound.fmodtable"
local lume = require "util.lume"

local assets =
{
	Asset("ANIM", "anim/gourdo_bank.zip"),
	Asset("ANIM", "anim/gourdo_build.zip"),
	Asset("ANIM", "anim/trap_gourdo_seed.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/gourdo_bank.zip"),
	Asset("ANIM", "anim/gourdo_elite_build.zip"),
	Asset("ANIM", "anim/trap_gourdo_seed.zip"),
	Asset("ANIM", "anim/trap_gourdo_seed_elite_build.zip")
}

local prefabs =
{
	"cine_gourdo_intro",
	"fx_hurt_sweat",
	"fx_low_health_ring",
	"gourdo_projectile",
	"gourdo_healing_seed",
	"gourdo_elite_projectile",
	"gourdo_elite_seed",
	"radius_indicator",
	"fx_gourdo_seed_heal_beam_lrg",
	"fx_gourdo_seed_heal_beam_sml",
	GroupPrefab("fx_dust"),

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_gourdo"),
	GroupPrefab("fx_warning"),
}
prefabutil.SetupDeathFxPrefabs(prefabs, "gourdo")

local attacks =
{
	punch =
	{
		priority = 2,
		damage_mod = 1,
		startup_frames = 15,
		cooldown = 4.5,
		initialCooldown = 0,
		pre_anim = "punch_pre",
		hold_anim = "punch_hold",
		start_conditions_fn = function(inst, data, trange)
			if trange:TestBeam(0, 7, 2) then
				return true
			end
		end
	},

	butt_slam =
	{
		priority = 1,
		damage_mod = 0.5,
		startup_frames = 28,
		cooldown = 12,
		initialCooldown = 3,
		pre_anim = "butt_slam_pre",
		hold_anim = "butt_slam_loop",
		loop_hold_anim = true,
		start_conditions_fn = function(inst, data, trange)
			if trange:IsBetweenRange(2, 16) then
				return true
			end
		end
	},

	buff =
	{
		startup_frames = 40,
		cooldown = 13.33,
		initialCooldown = 18,
		pre_anim = "buff_pre",
		hold_anim = "buff_hold",
		--max_interrupts = 1,
		start_conditions_fn = function()
			return false -- does not use this flow to evaluate start
		end
	},
}

local elite_attacks =
{
	punch =
	{
		priority = 2,
		damage_mod = 1,
		startup_frames = 20,
		cooldown = 2.2,
		initialCooldown = 3,
		pre_anim = "punch_pre",
		hold_anim = "punch_hold",
		start_conditions_fn = function(inst, data, trange)
			if trange:TestBeam(0, 7, 2) then
				return true
			end
		end
	},

	elite_butt_slam =
	{
		priority = 1,
		damage_mod = 0.5,
		startup_frames = 45,
		cooldown = 11,
		initialCooldown = 10,
		pre_anim = "elite_butt_slam_pre",
		hold_anim = "elite_butt_slam_loop",
		loop_hold_anim = true,
		is_hitstun_pressure_attack = true,
		start_conditions_fn = function(inst, data, trange)
			if trange:IsBetweenRange(2, 20) then
				return true
			end
		end
	},

	buff =
	{
		startup_frames = 40,
		cooldown = 13.33,
		initialCooldown = 5,
		pre_anim = "buff_pre",
		hold_anim = "buff_hold",
		--max_interrupts = 1,
		start_conditions_fn = function()
			return false -- does not use this flow to evaluate start
		end
	},
}

local MONSTER_SIZE = 1.8

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.LARGE)

	inst.AnimState:SetBank("gourdo_bank")
	inst.AnimState:SetBuild("gourdo_build")

	inst.components.hitbox:SetHitFlags(HitGroup.ALL)

	inst.components.combat:SetFrontKnockbackOnly(true)
	inst.components.combat:SetVulnerableKnockdownOnly(true)
	inst.components.combat:SetBlockKnockback(true)

	inst:SetStateGraph("sg_gourdo")
	inst:SetBrain("brain_gourdo")

	local cooldown =  math.random(9, 14) -- offset the initial time mainly for when there are multiple
	inst.components.timer:StartTimer("buff_cd", cooldown, false) -- delay the buff brain behavior until cinematic is complete
	inst:AddComponent("cineactor")
	inst.components.cineactor:AfterEvent_PlayAsLeadActor("cine_play_miniboss_intro", "cine_gourdo_intro")

	---foleysounder
	inst.components.foleysounder:SetFootstepSound(fmodtable.Event.gourdo_footstep)
	inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.gourdo_land)

    -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.gourdo_hit)
    inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.gourdo_knockdown)

	inst:AddTag("nointerrupt")

	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	monsterutil.AddOffsetHitbox(inst)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("gourdo_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)
	inst.components.combat:SetHasKnockback(false)

	monsterutil.ExtendToEliteMonster(inst)

	monsterutil.AddOffsetHitbox(inst)

	return inst
end

---------------------------------------------------------------------------------------

local debug_gourdo
local function OnEditorSpawn_dosetup(inst, editor)
	debug_gourdo = debug_gourdo or DebugSpawn("gourdo")
	debug_gourdo:Stupify("OnEditorSpawn")
	inst:Setup(debug_gourdo)
end

local function HandleProjectileSetup(inst, owner)
	inst.owner = owner

	local prefab_key = inst:HasTag("elite") and "gourdo_elite" or "gourdo"
	inst.tuning = lume.clone(TUNING[prefab_key].healing_seed)
	inst.components.hitbox:SetHitGroup(HitGroup.MOB)
	inst.components.hitbox:SetHitFlags(HitGroup.ALL) -- this seed *can* collide with everyone, but it decides who it heals using its target tags in healingzone.lua

	inst.components.combat:AddTargetTags(owner ~= nil and owner.components.combat:GetTargetTags() or TargetTagGroups.Players)
	inst.components.combat:AddFriendlyTargetTags(owner ~= nil and owner.components.combat:GetFriendlyTargetTags() or TargetTagGroups.Enemies)

	inst.heal_amount = inst.tuning.heal_amount -- JAMBELL: possibly scale this for vs player or vs enemy?
	inst.heal_radius = inst.tuning.heal_radius

	if owner then
		spawnutil.ApplyCharmColors(inst, owner, "projectile")
	end
end

local function ProjectileSetup(inst, owner)
	if inst:ShouldSendNetEvents() then
		TheSim:HandleEntitySetup(inst.GUID, owner.GUID)
	else
		HandleProjectileSetup(inst, owner)
	end
end

local function MakeProjectileEntity(prefabname, this_build)
	local inst = spawnutil.CreateComplexProjectile(
	{
		name = prefabname,
		hits_targets = true,
		hit_group = HitGroup.NEUTRAL,
		hit_flags = HitGroup.CREATURES,
		does_hitstop = true,
		bank = "trap_gourdo_seed",
		build = this_build,
		start_anim = "spin",
		stategraph = "sg_gourdo_projectile",
	})

	prefabutil.RegisterHitbox(inst, "main")
	inst:AddTag("healingseed")

	inst.Setup = ProjectileSetup
	inst.HandleSetup = HandleProjectileSetup
	inst.OnEditorSpawn = OnEditorSpawn_dosetup

	return inst
end

local function gourdo_projectile_fn(prefabname)
	return MakeProjectileEntity(prefabname, "trap_gourdo_seed")
end

local function gourdo_elite_projectile_fn(prefabname)
	local inst = MakeProjectileEntity(prefabname, "trap_gourdo_seed_elite_build")
	inst:AddTag("elite")
	return inst
end

---------------------------------------------------------------------------------------
local function OnRemoveHealingSeed(inst, owner)
	inst.circle:Remove()
end

local function HandleSeedSetup(inst, owner)
	--inst.owner = owner
	local prefab_key = inst:HasTag("elite") and "gourdo_elite" or "gourdo"
	inst.tuning = lume.clone(TUNING[prefab_key].healing_seed)
	inst.components.combat:AddTargetTags(owner ~= nil and owner.components.combat:GetTargetTags() or TargetTagGroups.Players)
	inst.components.combat:AddFriendlyTargetTags(owner ~= nil and owner.components.combat:GetFriendlyTargetTags() or TargetTagGroups.Enemies)

	local radius = inst.tuning.heal_radius
	local circle = SpawnPrefab("radius_indicator", inst)
	circle.entity:SetParent(inst.entity)
	inst.circle = circle
	circle.AnimState:PlayAnimation("circle_5")
	circle.AnimState:SetScale(radius/5, radius/5)
	circle.AnimState:SetMultColor(143/255, 156/255, 99/255, 0.66)

	inst.components.healingzone.heal_radius = radius
	inst.components.healingzone.heal_amount = inst.tuning.heal_amount -- JAMBELL: possibly scale this for vs player or vs enemy?
	inst.components.healingzone.heal_period = inst.tuning.heal_period -- JAMBELL: possibly scale this for vs player or vs enemy?
	inst.components.health:SetMax(inst.tuning.health, true)

	-- TODO: setmultcolor for radius circle.AnimState:SetMultColor(1, 1, 1, 1)
	-- TODO: set color for this seed itself

	if owner then
		spawnutil.ApplyCharmColors(inst, owner, "seed")
	end

	inst:ListenForEvent("onremove", OnRemoveHealingSeed, inst)
end

local function SeedSetup(inst, owner)
	if inst:ShouldSendNetEvents() then
		TheSim:HandleEntitySetup(inst.GUID, owner.GUID)
	else
		HandleSeedSetup(inst, owner)
	end
end

local function MakeSeedEntity(inst, build, scale)
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddHitBox()

	monsterutil.MakeAttackable(inst)
	inst:AddTag("healingseed")
	inst:AddTag("nocharm")

	MakeObstacleMonsterPhysics(inst, 0.5)
	inst.Transform:SetScale(scale, scale, scale)

	inst.AnimState:SetBank("trap_gourdo_seed")
	inst.AnimState:SetBuild(build)
	inst.AnimState:PlayAnimation("open")
	inst.AnimState:SetShadowEnabled(true)

	inst:AddComponent("hitstopper")
	inst:AddComponent("hitshudder")
	inst:AddComponent("combat")
	inst.components.combat:SetHasKnockback(true)
	inst.components.combat:SetHasKnockdown(false)
	inst:AddComponent("lowhealthindicator")

	inst:AddComponent("bloomer")
	inst:AddComponent("colormultiplier")
	inst:AddComponent("coloradder")

	inst:AddComponent("powermanager")
	inst:AddComponent("health")
	inst:AddComponent("hitbox")
	inst:AddComponent("timer")
	inst:AddComponent("healingzone")

	inst:SetStateGraph("sg_gourdo_healing_seed")

	inst.components.hitbox:SetHitGroup(HitGroup.MOB)
	inst.components.hitbox:SetHitFlags(HitGroup.ALL) -- this seed *can* collide with everyone, but it decides who it heals using its target tags in healingzone.lua

	inst.Setup = SeedSetup
	inst.HandleSetup = HandleSeedSetup
	inst.OnEditorSpawn = OnEditorSpawn_dosetup
end

local function gourdo_healing_seed_fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)
	MakeSeedEntity(inst, "trap_gourdo_seed", 1)
	return inst
end

local function gourdo_elite_seed_fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)
	MakeSeedEntity(inst, "trap_gourdo_seed_elite_build", 1.5)
	inst:AddTag("elite")
	inst.components.healingzone.show_projectile = true
	return inst
end

---------------------------------------------------------------------------------------

return Prefab("gourdo", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("gourdo_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)
	, Prefab("gourdo_projectile", gourdo_projectile_fn, assets, prefabs, nil, NetworkType_SharedAnySpawn)
	, Prefab("gourdo_healing_seed", gourdo_healing_seed_fn, assets, prefabs, nil, NetworkType_SharedAnySpawn)
	, Prefab("gourdo_elite_seed", gourdo_elite_seed_fn, elite_assets, prefabs, nil, NetworkType_SharedAnySpawn)
	, Prefab("gourdo_elite_projectile", gourdo_elite_projectile_fn, elite_assets, prefabs, nil, NetworkType_SharedAnySpawn)
