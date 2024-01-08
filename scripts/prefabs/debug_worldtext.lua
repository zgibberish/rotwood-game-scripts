local assets =
{
    Asset("ANIM", "anim/mouseover.zip"),
}

local function fn()
    local inst = CreateEntity()
    inst.persists = false

	inst:AddTag("NOCLICK")
	inst:AddTag("CLASSIFIED")
    inst.entity:AddTransform()
--[[
	inst.entity:AddAnimState()
    inst.AnimState:SetBank("mouseover")
    inst.AnimState:SetBuild("mouseover")
    inst.AnimState:SetMultColor(0,0,1,0.1)
	inst.AnimState:SetScale(16,16)
    inst.AnimState:PlayAnimation("circle")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(2)
]]
	inst:AddComponent("worldtext")
    return inst
end

-- See also spawnutil.SpawnWorldLabel()
return Prefab("debug_worldtext", fn, assets)
