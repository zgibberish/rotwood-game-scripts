local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()

	inst:AddTag("CLASSIFIED")
	--[[Non-networked entity]]

	inst:AddComponent("townportal")

	return inst
end

return Prefab("town_portal", fn)
