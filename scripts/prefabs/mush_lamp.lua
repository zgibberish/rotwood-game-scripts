local assets =
{
	Asset("ANIM", "anim/mush_lamp.zip"),
}

local prefabs =
{
	"motes_shroomlamp",
}

local function AddLayer(parent, anim, offset, bloom)
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")

	inst.AnimState:SetBank("mush_lamp")
	inst.AnimState:SetBuild("mush_lamp")
	inst.AnimState:PlayAnimation(anim, true)
	if bloom then
		inst.AnimState:SetBloom(0.75)
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

	MakeSmallDecorPhysics(inst, 1)

	inst.AnimState:SetBank("mush_lamp")
	inst.AnimState:SetBuild("mush_lamp")
	inst.AnimState:PlayAnimation("front", true)
	inst.AnimState:SetShadowEnabled(true)

	inst.highlightchildren = {}

	AddLayer(inst, "spore", .1, true)
	AddLayer(inst, "back", .18)

	local particles = SpawnPrefab("motes_shroomlamp", inst)
	particles.entity:SetParent(inst.entity)
	particles.entity:AddFollower()
	particles.Follower:FollowSymbol(inst.GUID, "swap_fx")

	inst:AddComponent("prop")
	inst:AddComponent("snaptogrid")
	inst.components.snaptogrid:SetDimensions(2, 2)

	return inst
end

return Prefab("mush_lamp", fn, assets, prefabs)
