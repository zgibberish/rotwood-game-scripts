local assets =
{
	Asset("ANIM", "anim/rotwood_growth.zip"),
}

local function MakeFX(name, anim, variations)
	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()
		inst.entity:AddAnimState()

		inst:AddTag("FX")
		inst:AddTag("NOCLICK")
		inst.persists = false

		inst.Transform:SetTwoFaced()

		inst.AnimState:SetBank("rotwood_growth")
		inst.AnimState:SetBuild("rotwood_growth")
		inst.AnimState:PlayAnimation(variations ~= nil and anim..tostring(math.random(variations)) or anim)
		inst.AnimState:SetShadowEnabled(true)
		inst.AnimState:SetRimEnabled(true)
		inst.AnimState:SetRimSize(3)
		inst.AnimState:SetRimSteps(3)

		inst:ListenForEvent("animover", inst.Remove)

		return inst
	end

	return Prefab(name, fn, assets)
end

return MakeFX("fx_rotwood_debris_burrow", "debris_small", 3),
	MakeFX("fx_rotwood_debris_pullout", "debris_fx", 4),
	MakeFX("fx_rotwood_debris_punch", "punch_debris_fx"),
	MakeFX("fx_rotwood_debris_spike", "debris_aoe"),
	MakeFX("fx_rotwood_debris_wave", "debris_wave", 3),
	MakeFX("fx_rotwood_knockdown", "knockdown_fx")
