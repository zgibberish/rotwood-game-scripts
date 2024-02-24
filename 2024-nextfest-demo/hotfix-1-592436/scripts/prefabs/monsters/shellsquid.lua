local monsterutil = require "util.monsterutil"
local spawnutil = require "util.spawnutil"


-- This creature isn't fully baked. David made it during gamejam.


local assets =
{
	Asset("ANIM", "anim/blarmadillo_bank.zip"),
	Asset("ANIM", "anim/blarmadillo_build.zip"),
	Asset("ANIM", "anim/blarmadillo_dirt.zip"),
	Asset("ANIM", "anim/eye_v_bank.zip"),
	Asset("ANIM", "anim/eye_v_build.zip"),
}

local elite_assets =
{
	Asset("ANIM", "anim/blarmadillo_bank.zip"),
	Asset("ANIM", "anim/blarmadillo_elite_build.zip"),
	Asset("ANIM", "anim/blarmadillo_dirt.zip"),
	Asset("ANIM", "anim/eye_v_bank.zip"),
	Asset("ANIM", "anim/eye_v_build.zip"),
}


local prefabs =
{
	"blarmadillo_bullet",
	"fx_death_blarmadillo",
	"fx_hurt_sweat",
	"fx_low_health_ring",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_blarmadillo"),
	GroupPrefab("drops_currency"),
}

local attacks =
{
	pierce =
	{
		priority = 2,
		damage_mod = 1,
		startup_frames = 30,
		cooldown = 3.33,
		initialCooldown = 0,
		pre_anim = "pierce_pre",
		hold_anim = "pierce_loop",
		start_conditions_fn = function(inst, data, trange)
			return trange:IsInRange(4)
		end
	},
	dash =
	{
		priority = 10,
		damage_mod = 0.01,
		startup_frames = 10,
		cooldown = 5.33,
		initialCooldown = 0,
		pre_anim = "roll_pre",
		hold_anim = "roll_pre_hold",
		start_conditions_fn = function(inst, data, trange)
			-- TODO(dbriscoe): Was this logic inverted or is it wrong now?
			return not trange:IsInRange(7) -- not too close to you
				and not trange:IsOutOfRange(22) -- not too far
				and not trange:IsOutOfZRange(15) -- not too unaligned on z
		end
	}
}

local elite_attacks =
{
	elite_shoot =
	{
		priority = 5,
		damage_mod = 1.5,
		startup_frames = 60,
		cooldown = 1.33,
		pre_anim = "elite_shoot_pre",
		hold_anim = "elite_shoot_pre_loop",
		loop_hold_anim = true,
		--max_interrupts = 2,
		start_conditions_fn = function(inst, data, trange)
			if trange:TestDetachedBeam(0, 17, 0.5) then
				return true
			end
		end
	},
	roll =
	{
		priority = 10,
		startup_frames = 10,
		cooldown = 5.33,
		initialCooldown = 0,
		pre_anim = "roll_pre",
		hold_anim = "roll_pre_hold",
		start_conditions_fn = function(inst, data, trange)
			if trange:IsInRange(7) -- if your target is too close to you
			or trange:IsOutOfRange(22) -- or if you're just way too far away
			or trange:IsOutOfZRange(7) then -- if you're more than 5 Z units away from your target
				return true
			end
		end
	}
}

local function FaceIdle(inst)
	inst.Follower:FollowSymbol(inst.parent.GUID, "skull", 0, 200, 1)
	inst.AnimState:PlayAnimation("evade", true)
	inst.AnimState:SetFrame(16)
	inst.AnimState:Pause()
	inst.AnimState:SetScale(1, 1)
end
local function RollingBlastMode(inst)
	inst.Follower:StopFollowing() -- We're spinning, so don't follow symbol.
	inst.Transform:SetPosition(0, -1, 1)
	inst.AnimState:Resume()
	--~ inst.AnimState:PlayAnimation("spin", true)
	inst.AnimState:PlayAnimation("knockdown_hold", true)
	local s = 0.75
	inst.AnimState:SetScale(s, s)
	-- Not sure how to get facing to work when not following symbol.
	--~ if inst.Transform:GetFacing() ~= inst.parent.Transform:GetFacing() then
	--~ 	inst.Transform:FlipFacing()
	--~ end
end
local function CreateFace(parent)
	local inst = CreateEntity("shellsquid_face")
	inst.parent = parent
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddFollower()
	inst.entity:SetParent(parent.entity)

	inst.AnimState:SetBank("eye_v_bank")
	inst.AnimState:SetBuild("eye_v_build")
	--~ inst.AnimState:SetDeltaTimeMultiplier(0.3)

	inst.GoIdle = FaceIdle
	inst.RollingBlastMode = RollingBlastMode
	inst:GoIdle()
	return inst
end

local MONSTER_SIZE = 1.1

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	monsterutil.MakeBasicMonster(inst, MONSTER_SIZE, monsterutil.MonsterSize.MEDIUM)

	inst.AnimState:SetBank("blarmadillo_bank")
	inst.AnimState:SetBuild("blarmadillo_build")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)

	inst.components.combat:SetVulnerableKnockdownOnly(false)
	inst.components.combat:SetKnockdownLengthModifier(0.3)
	inst.components.combat:SetBlockKnockback(true)

	inst:AddComponent("animprototyper")

	inst:SetStateGraph("sg_shellsquid")
	inst:SetBrain("brain_shellsquid")

	inst.face = CreateFace(inst)

	inst.components.animprototyper:HookupAnimationRedirector({
			parts = {
				body = inst,
				face = inst.face,
			},
			anim_map = {
				roll = "body",
				pierce = "face",
			},
			anim_when_inactive = {
				face = {
					anim = "evade",
					loop = false,
					frame = 16, -- implies pause
				},
			},
		})

	---foleysounder
    -- inst.components.foleysounder:SetBodyfallSound(fmodtable.Event.AAAA_default_event)
    -- inst.components.foleysounder:SetFootstepSound(fmodtable.Event.AAAA_default_event)

    -- inst.components.foleysounder:SetHitStartSound(fmodtable.Event.AAAA_default_event)
    -- inst.components.foleysounder:SetKnockbackStartSound(fmodtable.Event.AAAA_default_event)
    -- inst.components.foleysounder:SetKnockdownStartSound(fmodtable.Event.AAAA_default_event)


	return inst
end

local function normal_fn(prefabname)
	local inst = fn(prefabname)

	inst.components.attacktracker:AddAttacks(attacks)

	return inst
end

local function elite_fn(prefabname)
	local inst = fn(prefabname)

	inst.AnimState:SetBuild("blarmadillo_elite_build")

	inst.components.attacktracker:AddAttacks(elite_attacks)

	monsterutil.ExtendToEliteMonster(inst)

	return inst
end

---------------------------------------------------------------------------------------

local bullet_assets =
{
	Asset("ANIM", "anim/blarmadillo_dirt.zip"),
}

local bullet_prefabs =
{
	"hits_dirt",
}

local function bullet_fn(prefabname)
	local inst = spawnutil.CreateProjectile(
	{
		name = prefabname,
		physics_size = 0.5,
		hits_targets = true,
		twofaced = true,
		bank = "blarmadillo_dirt",
		build = "blarmadillo_dirt",
		stategraph = "sg_blarmadillo_projectile",
		motor_vel = 14,
	})

	inst.Setup = monsterutil.BasicProjectileSetup

	return inst
end

---------------------------------------------------------------------------------------

return Prefab("shellsquid", normal_fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
	--~ , Prefab("shellsquid_elite", elite_fn, elite_assets, prefabs, nil, NetworkType_SharedHostSpawn)
	--~ , Prefab("shellsquid_bullet", bullet_fn, bullet_assets, bullet_prefabs, nil, NetworkType_SharedAnySpawn)
