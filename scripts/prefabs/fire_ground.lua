local assets =
{
	Asset("ANIM", "anim/fx_fire_grnd.zip"),
}

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	inst.persists = false

	inst.AnimState:SetBank("fx_fire_grnd")
	inst.AnimState:SetBuild("fx_fire_grnd")
	inst.AnimState:PlayAnimation("loop", true)
	inst.AnimState:SetShadowEnabled(true)
	inst.AnimState:SetBloom(1)

	return inst
end

return Prefab("fire_ground", fn, assets)
