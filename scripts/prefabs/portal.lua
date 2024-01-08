local assets =
{
	Asset("ANIM", "anim/portal.zip"),
}

local function Teleport(inst, player)
	local DungeonSelectionScreen = require "screens.town.dungeonselectionscreen"
	TheFrontEnd:PushScreen(DungeonSelectionScreen(player))
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.AnimState:SetBank("portal")
	inst.AnimState:SetBuild("portal")
	inst.AnimState:PlayAnimation("idle", true)
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(2)
	inst.AnimState:SetBloom(1)

	inst:AddComponent("prop")
	inst:AddComponent("snaptogrid")
	inst.components.snaptogrid:SetDimensions(3, 3)

	inst:AddComponent("interactable")
		:SetRadius(1.5)
		:SetInteractionOffset(Vector3.zero:clone())
		:SetInteractCondition_Always()
		:SetOnInteractFn(Teleport)
		:SetupForButtonPrompt("<p bind='Controls.Digital.ACTION' color=0> Teleport")

	return inst
end

return Prefab("portal", fn, assets)
