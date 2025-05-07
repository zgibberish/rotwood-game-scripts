-- A prefab to make a room stay locked to hide the "next room" dungeon signpost
-- ui. Useful for debug rooms when you'll never leave.

local spawnutil = require "util.spawnutil"


local assets = {
	Asset("ANIM", "anim/mouseover.zip"),
}

local function fn()
	local inst = CreateEntity()
	inst:SetPrefabName("debug_roomlock")

	inst.persists = true
	inst:AddTag("NOCLICK")
	inst:AddTag("CLASSIFIED")
	inst.entity:AddTransform()
	spawnutil.AddWorldLabel(inst, "debug_roomlock")

	inst.entity:AddAnimState()
	inst.AnimState:SetBank("mouseover")
	inst.AnimState:SetBuild("mouseover")
	inst.AnimState:SetMultColor(0, 0, 1, 0.5)
	inst.AnimState:PlayAnimation("circle")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(2)

	inst:AddComponent("prop")
	inst:AddComponent("roomlock")

	return inst
end

return Prefab("debug_roomlock", fn, assets)
