local bossutil = require "prefabs.bossutil"
local monsterutil = require "util.monsterutil"

local assets =
{
	Asset("ANIM", "anim/bonejaw.zip"),
}

local prefabs =
{
	"fx_hurt_sweat",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_bonejaw"),
}

local function OnCombatTargetChanged(inst, data)
	if data.old == nil and data.new ~= nil then
		inst.components.timer:ResumeTimer("bite2_cd")
		inst.components.timer:ResumeTimer("headbutt_cd")
		inst.components.timer:ResumeTimer("charge_cd")
		inst.components.timer:ResumeTimer("roar_cd")
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

	MakeGiantMonsterPhysics(inst, 4.4)

	inst.AnimState:SetBank("bonejaw")
	inst.AnimState:SetBuild("bonejaw")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetShadowEnabled(true)
	inst.AnimState:SetRimEnabled(true)
	inst.AnimState:SetRimSize(3)
	inst.AnimState:SetRimSteps(3)

	TheFocalPoint.components.focalpoint:StartFocusSource(inst, FocusPreset.BOSS)

	monsterutil.AddOffsetHitbox(inst, 2) -- head

	inst:AddComponent("locomotor")
	inst.components.locomotor:SetRunSpeed(12.5)

	inst:AddComponent("bloomer")
	inst:AddComponent("colormultiplier")
	inst:AddComponent("coloradder")
	inst:AddComponent("hitstopper")

	inst:AddComponent("roomlock")

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:AddFixedLoot("drop_bonejaw_hide", 2, 3)
	inst.components.lootdropper:AddFixedLoot("drop_bonejaw_claw", 1, 2)
	inst.components.lootdropper:AddFixedLoot("drop_bonejaw_spike", 1, 2)
	inst.components.lootdropper:AddChanceLoot("drop_bonejaw_skull", 0.25)
	inst.components.lootdropper:AddChanceLoot("drop_bonejaw_tail", 0.25)
	inst.components.lootdropper:AddChanceLoot("drop_bonejaw_tooth", 0.25)

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
	inst.components.timer:StartPausedTimer("bite2_cd", 10)
	inst.components.timer:StartPausedTimer("headbutt_cd", 8)
	inst.components.timer:StartPausedTimer("charge_cd", 10)
	inst.components.timer:StartPausedTimer("roar_cd", 20)

	inst:ListenForEvent("combattargetchanged", OnCombatTargetChanged)

	inst:SetStateGraph("sg_bonejaw")
	inst:SetBrain("brain_bonejaw")

	return inst
end

return Prefab("bonejaw", fn, assets, prefabs, nil, NetworkType_HostAuth)
