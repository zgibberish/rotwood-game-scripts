local assets =
{
	Asset("MODEL", "levels/models_new/edge_soft.bin"),
}

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddModel()

	local modelfile = "levels/models_new/edge_soft.bin"
	local meshname = "edge_1_0"

	inst.Model:SetModelFile(modelfile)
	inst.Model:SetMesh(meshname)
	inst.Model:SetLayer(LAYER_BELOW_OCEAN)

	inst.Transform:SetScale(4,4,4)

	return inst
end

return Prefab("cliffedge", fn, assets)
