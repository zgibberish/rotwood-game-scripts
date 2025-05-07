local assets =
{
	Asset("ANIM", "anim/radius_indicator.zip"),
}

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("radius_indicator")
	inst.AnimState:SetBuild("radius_indicator")
	inst.AnimState:PlayAnimation("circle_1")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetClipAtWorldEdge(true)
	inst.AnimState:SetSortOrder(10)

	inst.persists = false
	return inst
end

return Prefab("radius_indicator", fn, assets)
