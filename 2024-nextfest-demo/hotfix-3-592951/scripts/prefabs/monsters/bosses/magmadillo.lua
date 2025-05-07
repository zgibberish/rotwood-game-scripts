local bossutil = require "prefabs.bossutil"
local monsterutil = require "util.monsterutil"

local assets =
{
	Asset("ANIM", "anim/magmadillo.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",

	--Drops
	GroupPrefab("drops_generic"),
	--"drops_magmadillo",
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

	MakeGiantMonsterPhysics(inst, 2.4)

	inst.AnimState:SetBank("magmadillo")
	inst.AnimState:SetBuild("magmadillo")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetShadowEnabled(true)
	inst.AnimState:SetRimEnabled(true)
	inst.AnimState:SetRimSize(3)
	inst.AnimState:SetRimSteps(3)

	TheFocalPoint.components.focalpoint:StartFocusSource(inst, FocusPreset.BOSS)

	monsterutil.AddOffsetHitbox(inst, 2)

	inst:AddComponent("locomotor")
	inst.components.locomotor:SetRunSpeed(10)

	inst:AddComponent("bloomer")
	inst:AddComponent("colormultiplier")
	inst:AddComponent("coloradder")
	inst:AddComponent("hitstopper")

	inst:AddComponent("roomlock")

	inst:AddComponent("lootdropper")
	--[[inst.components.lootdropper:AddFixedLoot("drop_owlitzer_fur", 2, 3)
	inst.components.lootdropper:AddFixedLoot("drop_owlitzer_pelt", 2, 3)
	inst.components.lootdropper:AddFixedLoot("drop_owlitzer_claw", 1, 2)
	inst.components.lootdropper:AddChanceLoot("drop_owlitzer_skull", 0.25)
	inst.components.lootdropper:AddChanceLoot("drop_owlitzer_foot", 0.25)]]

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

	inst:SetStateGraph("sg_magmadillo")
	inst:SetBrain("brain_magmadillo")
	inst.brain:Pause("dummy")

	return inst
end

return Prefab("magmadillo", fn, assets, prefabs, nil, NetworkType_HostAuth)
