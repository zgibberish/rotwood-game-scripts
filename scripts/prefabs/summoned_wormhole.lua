local assets =
{
	Asset("ANIM", "anim/fx_portal.zip"),
}

local prefabs =
{
}

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddHitBox()

	MakeItemDropPhysics(inst, 1)

	inst.AnimState:SetBank("fx_portal")
	inst.AnimState:SetBuild("fx_portal")
	inst.AnimState:SetScale(1, 1)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)

	-- Values from the old FX editor implementation:
	inst.AnimState:SetBloom(1)
	inst.AnimState:SetHue(17)
	inst.AnimState:SetSaturation(50)
	--inst.AnimState:SetBrightness(50)

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetHitGroup(HitGroup.NONE)
	inst.components.hitbox:SetHitFlags(HitGroup.CREATURES | HitGroup.CHARACTERS)
	inst.components.hitbox:SetUtilityHitbox(true)

	inst:AddComponent("wormhole")

	inst:SetStateGraph("sg_summoned_wormhole")

	return inst
end

return Prefab("summoned_wormhole", fn, assets, prefabs, nil, NetworkType_ClientAuth)
