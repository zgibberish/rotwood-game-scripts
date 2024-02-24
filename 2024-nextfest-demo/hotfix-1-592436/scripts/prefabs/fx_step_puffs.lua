local assets =
{
	Asset("ANIM", "anim/fx_step_puffs.zip"),
}

local function MakeFX(size)
	local function fn(prefabname)
		local inst = CreateEntity()
		inst:SetPrefabName(prefabname)

		inst.entity:AddTransform()
		inst.entity:AddAnimState()

		inst:AddTag("FX")
		inst:AddTag("NOCLICK")
		inst.persists = false

		inst.Transform:SetTwoFaced()

		inst.AnimState:SetBank("fx_step_puffs")
		inst.AnimState:SetBuild("fx_step_puffs")
		inst.AnimState:PlayAnimation(size.."1")
		inst.AnimState:SetFinalOffset(1)

		inst:ListenForEvent("animover", inst.Remove)

		return inst
	end

	return Prefab("fx_step_puff_"..size, fn, assets)
end

return MakeFX("sm"),
	MakeFX("med")
