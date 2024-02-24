local bossutil = require "prefabs.bossutil"

local assets =
{
	Asset("ANIM", "anim/rotwood.zip"),
}

local prefabs =
{
	-- legacy player fx
	"fx_hit_player_horizontal",
	"fx_hit_player_side",

	"fx_hurt_woodchips",
	"fx_rotwood_debris_burrow",
	"fx_rotwood_debris_pullout",
	"fx_rotwood_debris_spike",
	"fx_rotwood_knockdown",
	"rotwood_growth_punch",
	"rotwood_growth_root",
	"rotwood_growth_sapling",

	--Drops
	GroupPrefab("drops_generic"),
	GroupPrefab("drops_rotwood"),
}

local function OnCombatTargetChanged(inst, data)
	if data.old == nil and data.new ~= nil then
		inst.components.timer:ResumeTimer("block_cd")
		inst.components.timer:ResumeTimer("spike_cd")
		inst.components.timer:ResumeTimer("saplings_cd")
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

	MakeGiantMonsterPhysics(inst, 3.4)

	inst.AnimState:SetBank("rotwood")
	inst.AnimState:SetBuild("rotwood")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetShadowEnabled(true)
	inst.AnimState:SetRimEnabled(true)
	inst.AnimState:SetRimSize(3)
	inst.AnimState:SetRimSteps(3)

	TheFocalPoint.components.focalpoint:StartFocusSource(inst, FocusPreset.BOSS)

	inst:AddComponent("locomotor")
	inst.components.locomotor:SetWalkSpeed(4.35)

	inst:AddComponent("bloomer")
	inst:AddComponent("colormultiplier")
	inst:AddComponent("coloradder")
	inst:AddComponent("hitstopper")

	inst:AddComponent("roomlock")

	inst:AddComponent("lootdropper")
	inst.components.lootdropper:AddFixedLoot("drop_rotwood_crown", 1, 2)
	inst.components.lootdropper:AddFixedLoot("drop_rotwood_bark", 1, 2)
	inst.components.lootdropper:AddFixedLoot("drop_rotwood_twig", 2, 3)
	inst.components.lootdropper:AddFixedLoot("drop_rotwood_root", 1, 2)
	inst.components.lootdropper:AddChanceLoot("drop_rotwood_face", 0.25)

	inst:AddComponent("health")
	inst.components.health:SetMax(3000, true)

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.BOSS)
	inst.components.hitbox:SetHitFlags(HitGroup.CHARACTERS)

	inst:AddComponent("combat")
	inst.components.combat:SetHurtFx("fx_hurt_woodchips")
	inst.components.combat:SetHasKnockback(true)
	inst.components.combat:SetHasKnockdown(true)
	inst.components.combat:SetHasKnockdownHits(true)
	inst.components.combat:SetHasKnockdownHitDir(true)
	inst.components.combat:SetFrontKnockbackOnly(true)
	inst.components.combat:SetVulnerableKnockdownOnly(true)
	inst.components.combat:SetHasBlockDir(true)

	inst:AddComponent("timer")
	inst.components.timer:StartPausedTimer("block_cd", 30)
	inst.components.timer:StartPausedTimer("spike_cd", 10)
	inst.components.timer:StartPausedTimer("saplings_cd", 30)

	inst:ListenForEvent("combattargetchanged", OnCombatTargetChanged)

	inst:SetStateGraph("sg_rotwood")
	inst:SetBrain("brain_rotwood")

	return inst
end

return Prefab("rotwood", fn, assets, prefabs, nil, NetworkType_HostAuth)
