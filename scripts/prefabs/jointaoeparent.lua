local prefabutil = require "prefabs.prefabutil"

local function fn()
	local inst = CreateEntity()

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