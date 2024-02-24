local prefabutil = require "prefabs.prefabutil"

local assets =
{
	Asset("ANIM", "anim/minion1.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",
	"fx_low_health_ring",
}
prefabutil.SetupDeathFxPrefabs(prefabs, "minion1")

local attacks =
{
	jump =
	{
		priority = 10,
		startup_frames = 10,
		cooldown = 0.33,
		initialCooldown = 0,
		pre_anim = "jump_pre",
		hold_anim = "jump_hold",
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

	inst.tuning = TUNING.minion_melee

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddHitBox()
	inst.HitBox:SetNonPhysicsRect(1)


	inst:AddTag("playerminion")

	inst.Transform:SetTwoFaced()

	MakeSmallMonsterPhysics(inst, 0.75)
	inst.Physics:StartPassingThroughObjects()

	inst.AnimState:SetBank("minion1")
	inst.AnimState:SetBuild("minion1")
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
	inst.components.attacktracker:SetMinimumCooldown(0)

	inst:AddComponent("powermanager")

	inst:AddComponent("lowhealthindicator")

	inst:ListenForEvent("combattargetchanged", OnCombatTargetChanged)

	inst:ListenForEvent("despawn", function(inst)
		inst.sg:GoToState("despawn")
	end)

	inst:SetStateGraph("sg_minion_melee")
	inst:SetBrain("brain_minion_melee")

	return inst
end

---------------------------------------------------------------------------------------

return Prefab("minion_melee", fn, assets, prefabs, nil, NetworkType_ClientAuth)	-- minions stay on the client that spawned them!
