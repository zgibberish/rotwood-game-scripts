local prefabutil = require "prefabs.prefabutil"

local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

	inst.entity:AddHitBox()
	inst.entity:AddTransform()

	inst:AddComponent("combat")
	inst:AddComponent("hitbox")
	inst:AddComponent("attacktracker")
	prefabutil.RegisterHitbox(inst, "main")

	inst:AddComponent("jointaoeparent")

	return inst
end

return Prefab("jointaoeparent", fn)
