local prefabs =
{
	GroupPrefab("UI"),
}

local function SetBusy(inst)
	inst.components.questmarker:SetBusy()
end

local function SpawnMarker(inst)
	inst.components.questmarker:SpawnMarkerFX()
end

local function DespawnMarker(inst, cb)
	inst.components.questmarker:DespawnMarkerFX(cb)
end


local function fn()
	local inst = CreateEntity()
	inst.entity:AddTransform()
	inst.entity:AddFollower()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	--[[Non-networked entity]]
	inst.persists = false

	inst:AddComponent("questmarker")

	inst.SpawnMarker = SpawnMarker
	inst.DespawnMarker = DespawnMarker
	inst.SetBusy = SetBusy

	return inst
end

return Prefab("questmarker", fn, nil, prefabs)
