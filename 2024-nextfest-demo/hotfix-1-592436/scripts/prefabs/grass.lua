local assets =
{
	Asset("ANIM", "anim/grass.zip"),
}

local function AddLayer(parent, anim, offset, hasshadow)
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")

	inst.AnimState:SetBank("grass")
	inst.AnimState:SetBuild("grass")
	inst.AnimState:PlayAnimation(anim)
	if hasshadow then
		inst.AnimState:SetShadowEnabled(true)
	end

	inst.entity:SetParent(parent.entity)
	inst.Transform:SetPosition(0, 0, offset)

	parent.highlightchildren[#parent.highlightchildren + 1] = inst

	return inst
end

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("grass")
	inst.AnimState:SetBuild("grass")
	inst.AnimState:PlayAnimation("mid")
	inst.AnimState:SetShadowEnabled(true)

	inst.highlightchildren = {}

	AddLayer(inst, "front", -.3, true)
	AddLayer(inst, "side", .6)

	inst:AddComponent("prop")
	inst:AddComponent("snaptogrid")
	inst.components.snaptogrid:SetDimensions(2, 2)

	return inst
end

return Prefab("grass", fn, assets)
