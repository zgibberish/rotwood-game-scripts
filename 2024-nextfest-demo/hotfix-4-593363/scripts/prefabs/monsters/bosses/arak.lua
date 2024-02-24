local bossutil = require "prefabs.bossutil"

local assets =
{
	Asset("ANIM", "anim/arak.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_arak"),
}

local function OnCombatTargetChanged(inst, data)
	if data.old == nil and data.new ~= nil then
	end
end

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddHitBox()

	inst:AddTag("boss")

	inst.Transform:SetTwoFaced()

	MakeGiantMonsterPhysics(inst, 2)

	inst.AnimState:SetBank("arak")
	inst.AnimState:SetBuild("arak")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetShadowEnabled(true)
	inst.AnimState:SetRimEnabled(true)
	inst.AnimState:SetRimSize(3)
	inst.AnimState:SetRimSteps(3)

	TheFocalPoint.components.focalpoint:StartFocusSource(inst, FocusPreset.BOSS)

	inst:AddComponent("locomotor")
	inst.components.locomotor:SetRunSpeed(12.5)

	inst:AddComponent("bloomer")
	inst:AddComponent("colormultiplier")
	inst:AddComponent("coloradder")
	inst:AddComponent("hitstopper")

	inst:AddComponent("roomlock")

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:AddFixedLoot("drop_arak_web", 2, 3)
	inst.components.lootdropper:AddFixedLoot("drop_arak_leg", 2, 3)
	inst.components.lootdropper:AddFixedLoot("drop_arak_eye", 1, 2)
	inst.components.lootdropper:AddFixedLoot("drop_arak_shell", 1)
	inst.components.lootdropper:AddChanceLoot("drop_arak_skull", 0.25)

	inst:AddComponent("health")
	inst.components.health:SetMax(3000, true)

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.BOSS)
	inst.components.hitbox:SetHitGroup(HitGroup.CHARACTERS)

	inst:AddComponent("combat")
	inst.components.combat:SetHurtFx("fx_hurt_sweat")
	inst.components.combat:SetHasKnockback(true)
	inst.components.combat:SetHasKnockdown(true)
	inst.components.combat:SetHasKnockdownHits(true)
	inst.components.combat:SetHasKnockdownHitDir(true)
	inst.components.combat:SetFrontKnockbackOnly(true)
	inst.components.combat:SetVulnerableKnockdownOnly(true)

	inst:AddComponent("timer")

	inst:ListenForEvent("combattargetchanged", OnCombatTargetChanged)

	--inst:SetStateGraph("sg_arak")
	--inst:SetBrain("brain_arak")

	return inst
end

return Prefab("arak", fn, assets, prefabs, nil, NetworkType_HostAuth)
