local bossutil = require "prefabs.bossutil"

local assets =
{
	Asset("ANIM", "anim/quetz.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",

	--Drops
	GroupPrefab("drops_generic"),
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

	inst.AnimState:SetBank("quetz")
	inst.AnimState:SetBuild("quetz")
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
	inst.components.lootdropper:AddFixedLoot("drop_generic_bone", 2, 3)
	inst.components.lootdropper:AddFixedLoot("drop_generic_rib", 2, 3)
	inst.components.lootdropper:AddFixedLoot("drop_generic_meat", 2, 3)
	-- inst.components.lootdropper:AddChanceLoot("drop_generic_guts", 0.25)

	inst:AddComponent("health")
	inst.components.health:SetMax(3000, true)

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.BOSS)
	inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)

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

	--inst:SetStateGraph("sg_quetz")
	--inst:SetBrain("brain_quetz")

	return inst
end

return Prefab("quetz", fn, assets, prefabs, nil, NetworkType_HostAuth)
