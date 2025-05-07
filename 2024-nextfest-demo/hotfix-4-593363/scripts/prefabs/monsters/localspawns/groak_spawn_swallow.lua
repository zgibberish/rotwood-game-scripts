local assets =
{
}

local function fn(prefabname)
	local inst = CreateEntity()

	inst.OnSetSpawnInstigator = function(inst, instigator)
		inst.owner = instigator
	end

	inst:SetPrefabName(prefabname)

	inst.entity:AddTransform()
	inst.entity:AddHitBox()

	inst:AddComponent("hitbox")
	inst.components.hitbox:SetUtilityHitbox(true)
	inst.components.hitbox:SetHitFlags(HitGroup.ALL)

	inst:AddComponent("powermanager")
	inst.components.powermanager:EnsureRequiredComponents()

	inst:SetStateGraph("sg_groak_spawn_swallow")

	return inst
end

return Prefab("groak_spawn_swallow", fn, assets)
