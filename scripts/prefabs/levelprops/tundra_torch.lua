local prop_destructible = require "prefabs.customscript.prop_destructible"

local assets =
{
    Asset("ANIM", "anim/destructible_bandiforest_ceiling.zip"),
}

local prefabs =
{
	"fx_bandicoot_groundring_solid",
	"fx_ground_target_red",
	"mothball",
}

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

    inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()

	local r, g, b = HexToRGBFloats(StrToHex("EA914DFF"))
	local intensity = 0.2
	inst.AnimState:SetLayerBloom("bloom_untex", r, g, b, intensity)
	inst.AnimState:SetLayerBloom("bloom_scatter", r, g, b, intensity)

	inst.AnimState:SetShadowEnabled(false)
	inst.AnimState:SetRimEnabled(true)
	inst.AnimState:SetRimSize(3)
	inst.AnimState:SetRimSteps(3)

	inst.Transform:SetTwoFaced()

	inst.AnimState:SetBank("destructible_bandiforest_ceiling")
	inst.AnimState:SetBuild("destructible_bandiforest_ceiling")

	inst.entity:AddHitBox()

	inst:AddComponent("hitbox")
	inst.HitBox:SetNonPhysicsRect(1.4)
	inst.HitBox:SetHitGroup(HitGroup.NEUTRAL)

	inst:AddComponent("hitstopper")

	inst:AddComponent("combat")

	MakeObstaclePhysics(inst, 1.5)

	inst:SetStateGraph("levelprops/sg_tundra_torch")

	-- Set up hit FX
	inst.SpawnHitRubble = prop_destructible.default.SpawnHitRubble

	inst:AddTag("prop") -- Classify this as a prop for prop-related interactions.

	return inst
end

return Prefab("tundra_torch", fn, assets, prefabs, nil, NetworkType_SharedHostSpawn)
