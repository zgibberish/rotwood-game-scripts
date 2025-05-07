local assets =
{
	Asset("ANIM", "anim/aim_indicator_untex.zip"),
}

local function CreatePointer()
	local inst = CreateEntity("aim_pointer.pointer")

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	inst.persists = false

	inst.AnimState:SetBank("aim_indicator_untex")
	inst.AnimState:SetBuild("aim_indicator_untex")
	inst.AnimState:PlayAnimation("pointer")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(10)

	return inst
end

local function OnRemove(inst)
	inst.pointer:Remove()
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.persists = false

	local pointer = CreatePointer()
	pointer.entity:SetParent(inst.entity)
	inst.pointer = pointer

	inst:AddComponent("aimindicator")
	inst.components.aimindicator:SetPointer(pointer)

	inst:ListenForEvent("onremove", OnRemove, inst)
	return inst
end

return Prefab("aim_pointer", fn, assets)
