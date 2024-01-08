local function fn(prefabname)
	local inst = CreateEntity()
	inst:SetPrefabName(prefabname)

    inst.entity:AddTransform()
    inst.entity:AddSoundEmitter()
    inst.entity:AddAnimState()

    inst:AddComponent("groundtargetwarning")
    inst:AddComponent("bloomer")
    inst:AddComponent("colormultiplier")

    -- values taken from fx_ground_target_red fx
	inst.AnimState:SetBank("fx_ground_target")
	inst.AnimState:SetBuild("fx_ground_target")
	inst.AnimState:PlayAnimation("idle", true)

    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetClipAtWorldEdge(true)
    inst.AnimState:SetSortOrder(2)
    local r, g, b = HexToRGBFloats(StrToHex("FF0000FF"))
    inst.components.bloomer:PushBloom("groundtarget", r, g, b, 0.5)
    inst.components.colormultiplier:PushColor("groundtarget", HexToRGBFloats(StrToHex("FF8F8FE6")))
    inst.AnimState:SetBrightness((-25 + 100) / 100)

    inst.OnSetSpawnInstigator = function(inst, instigator)
        inst.owner = instigator -- save the owning projectile on the entity
	end

	return inst
end

return Prefab("ground_target", fn, nil, nil, nil, NetworkType_SharedAnySpawn)