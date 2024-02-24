local SGCommon = require "stategraphs.sg_common"
local combatutil = require "util.combatutil"
local spawnutil = require "util.spawnutil"
local prefabutil = require "prefabs.prefabutil"
local monsterutil = require "util.monsterutil"

local assets =
{
	Asset("ANIM", "anim/minion2.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",
	"minion_ranged_bullet",
}
prefabutil.SetupDeathFxPrefabs(prefabs, "minion2")

local attacks =
{
	shoot =
	{
		priority = 10,
		startup_frames = 10,
		cooldown = 0.67,
		initialCooldown = 0,
		pre_anim = "shoot_pre",
		hold_anim = "shoot_hold",
		start_conditions_fn = function(inst, data, trange)
			return true
		end
	}
}

local function OnCombatTargetChanged(inst, data)
	if data ~= nil then
		if data.new ~= nil then
			if data.old == nil then
				for id, data in pairs(inst.components.attacktracker.attack_data) do
					if data.timer_id then
						inst.components.timer:ResumeTimer(data.timer_id)
					end
				end
			end
		end
	end
end

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.tuning = TUNING.minion_ranged

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddHitBox()
	inst.HitBox:SetNonPhysicsRect(1.1)

	inst:AddTag("playerminion")

	inst.Transform:SetTwoFaced()

	MakeSmallMonsterPhysics(inst, 1.1)

	inst.AnimState:SetBank("minion2")
	inst.AnimState:SetBuild("minion2")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
	inst.AnimState:SetShadowEnabled(true)
	inst.AnimState:SetRimEnabled(true)
	inst.AnimState:SetRimSize(3)
	inst.AnimState:SetRimSteps(3)

	inst:AddComponent("bloomer")
	inst:AddComponent("colormultiplier")
	inst:AddComponent("coloradder")
	inst:AddComponent("hitstopper")

	inst:AddComponent("knownlocations")

	inst:AddComponent("health")
	inst.components.health:SetMax(inst.tuning.health, true)

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.NPC)
	inst.components.hitbox:SetHitFlags(HitGroup.CREATURES)

	prefabutil.RegisterHitbox(inst, "main")

	inst:AddComponent("scalable")

	inst:AddComponent("combat")
	inst.components.combat:SetDefaultTargettingForTuning()
	inst.components.combat:SetHurtFx("fx_hurt_sweat")
	inst.components.combat:SetBaseDamage(inst, inst.tuning.base_damage)
	inst.components.combat:AddTargetTags(TargetTagGroups.Enemies)

	inst:AddComponent("hitshudder")
	inst:AddComponent("pushbacker")

	inst:AddComponent("timer")

	inst:AddComponent("attacktracker")
	inst.components.attacktracker:AddAttacks(attacks)

	inst:AddComponent("powermanager")

	inst:AddComponent("lowhealthindicator")

	inst:ListenForEvent("combattargetchanged", OnCombatTargetChanged)

	inst:ListenForEvent("despawn", function(inst)
		inst.sg:GoToState("despawn")
	end)

	inst:SetStateGraph("sg_minion_ranged")
	inst:SetBrain("brain_minion_ranged")

	inst:DoTaskInTicks(1, function() inst.Physics:StartPassingThroughObjects() end)

	return inst
end

------------------------------------------------------------------------------
-- Projectile

local bullet_prefabs =
{
	"projectile_minion",
	"projectile_minion_hit"
}

local function OnHitBoxTriggered(inst, data)
	SGCommon.Events.OnProjectileHitboxTriggered(inst, data, {
		attackdata_id = "shoot",
		hitstoplevel = HitStopLevel.LIGHT,
		pushback = 0.4,
		hitflags = Attack.HitFlags.PROJECTILE,
		combat_attack_fn = "DoBasicAttack",
		hit_fx = "projectile_minion_hit",
		hit_fx_offset_x = 0.5,
	})
end

local function Setup(inst, owner)
	monsterutil.BasicProjectileSetup(inst, owner)
	inst.components.combat:SetBaseDamage(owner, owner.components.combat.basedamage:Get())

	inst.components.projectilehitbox:PushCircle(0.00, 0.00, 0.50, HitPriority.MOB_PROJECTILE)
									:SetTriggerFunction(OnHitBoxTriggered)
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
		motor_vel = 14,
		stategraph = "sg_minion_ranged_projectile",
		fx_prefab = "projectile_minion",
	})

	inst.Setup = Setup

	return inst
end

---------------------------------------------------------------------------------------

return Prefab("minion_ranged", fn, assets, prefabs, nil, NetworkType_ClientAuth)
	, Prefab("minion_ranged_bullet", bullet_fn, nil, bullet_prefabs, nil, NetworkType_SharedAnySpawn)
