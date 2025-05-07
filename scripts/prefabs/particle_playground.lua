local assets =
{
	Asset("ANIM", "anim/particle_playground.zip"),
}

local prefabs =
{
	"particle_playground_1",
	"particle_playground_2",
}

local function AddLayer(parent, anim, numparticles)
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")

	inst.AnimState:SetBank("particle_playground")
	inst.AnimState:SetBuild("particle_playground")
	inst.AnimState:PlayAnimation(anim, true)

	inst.entity:SetParent(parent.entity)

	if numparticles >= 1 then
		local particles1 = SpawnPrefab("particle_playground_1", inst)
		particles1.entity:SetParent(inst.entity)
		particles1.entity:AddFollower()
		particles1.Follower:FollowSymbol(inst.GUID, "swap_fx")

		if numparticles >= 2 then
			local particles2 = SpawnPrefab("particle_playground_2", inst)
			particles2.entity:SetParent(inst.entity)
			particles2.entity:AddFollower()
			particles2.Follower:FollowSymbol(inst.GUID, "swap_fx2")
		end
	end

	return inst
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()

	inst.highlightchildren =
	{
		AddLayer(inst, "1", 1),
		AddLayer(inst, "2", 1),
		AddLayer(inst, "3", 1),
		AddLayer(inst, "4", 2),
	}

	inst:AddComponent("prop")
	inst:AddComponent("snaptogrid")
	inst.components.snaptogrid:SetDimensions(2, 2)

	return inst
end

return Prefab("particle_playground", fn, assets, prefabs)
