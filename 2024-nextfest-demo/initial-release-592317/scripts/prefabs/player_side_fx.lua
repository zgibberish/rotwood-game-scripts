local function MakeFX(name, bank, anim, onground, shadow)
	local assets =
	{
		Asset("ANIM", "anim/"..bank..".zip"),
	}

	local function fn(prefabname)
		local inst = CreateEntity()
		inst:SetPrefabName(prefabname)

		inst.entity:AddTransform()
		inst.entity:AddAnimState()

		inst:AddTag("FX")
		inst:AddTag("NOCLICK")
		inst.persists = false

		inst.Transform:SetTwoFaced()

		inst.AnimState:SetBank(bank)
		inst.AnimState:SetBuild(bank)
		inst.AnimState:PlayAnimation(anim)
		if shadow then
			inst.AnimState:SetShadowEnabled(true)
		end
		if onground then
			inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
			inst.AnimState:SetSortOrder(-2)
		else
			inst.AnimState:SetFinalOffset(1)
		end

		inst:ListenForEvent("animover", inst.Remove)

		return inst
	end

	return Prefab(name, fn, assets)
end

return MakeFX("fx_player_flask_smash_glass", "fx_player_flask_smash", "anim1", false, true),
	MakeFX("fx_player_flask_smash_impact", "fx_player_flask_smash", "impact1", true, false),
	MakeFX("fx_player_ground_smash_dust", "fx_player_ground_smash", "dust1", false, false),
	MakeFX("fx_player_ground_smash_ring", "fx_player_ground_smash", "ring1", true, false)
