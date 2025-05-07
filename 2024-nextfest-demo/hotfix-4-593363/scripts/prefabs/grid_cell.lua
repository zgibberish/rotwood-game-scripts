local assets =
{
	Asset("ANIM", "anim/mouseover.zip"),
}

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("mouseover")
	inst.AnimState:SetBuild("mouseover")
	inst.AnimState:SetMultColor(table.unpack(WEBCOLORS.RED))
	inst.AnimState:PlayAnimation("square")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(1)
	inst.AnimState:SetScale(.5, .5)

	inst:AddComponent("prop")
	inst:AddComponent("snaptogrid")
	inst.components.snaptogrid:SetDimensions(1, 1)

	return inst
end

return Prefab("grid_cell", fn, assets)
