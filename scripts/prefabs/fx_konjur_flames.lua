local assets =
{
	Asset("ANIM", "anim/fx_konjur_flames.zip"),
}

local function MakeFX(size)
	local function fn(prefabname)
		local inst = CreateEntity()
		inst:SetPrefabName(prefabname)

		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddFollower()

		inst:AddTag("FX")
		inst:AddTag("NOCLICK")
		inst.persists = false

		inst.Transform:SetTwoFaced()

		inst.AnimState:SetBank("fx_konjur_flames")
		inst.AnimState:SetBuild("fx_konjur_flames")
		inst.AnimState:PlayAnimation(size.."1", true)
		inst.AnimState:SetFrame(math.random(inst.AnimState:GetCurrentAnimationNumFrames()) - 1)
		inst.AnimState:SetBloom(.6)
		inst.AnimState:SetLightOverride(1)

		return inst
	end

	return Prefab("fx_konjur_flame_"..size, fn, assets)
end

return MakeFX("sm"),
	MakeFX("med")
