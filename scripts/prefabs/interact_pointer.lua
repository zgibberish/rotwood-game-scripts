local assets =
{
	Asset("ANIM", "anim/interact_indicator_untex.zip"),
}

local function CreatePointer()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	inst.persists = false

	inst.AnimState:SetBank("interact_indicator_untex")
	inst.AnimState:SetBuild("interact_indicator_untex")
	inst.AnimState:PlayAnimation("pointer")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(3)

	return inst
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	inst.persists = false

	local pointer = CreatePointer()
	pointer.entity:SetParent(inst.entity)

	inst:AddComponent("targetindicator")
	inst.components.targetindicator:SetPointer(pointer)

	return inst
end

return Prefab("interact_pointer", fn, assets)
