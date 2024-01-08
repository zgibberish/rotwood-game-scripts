local function fn()
    local inst = CreateEntity()

    --[[Non-networked entity]]
    inst.entity:AddTransform()
    inst:AddTag("CLASSIFIED")
    inst.persists = false

	inst:AddComponent("offscreenindicator")
	inst.entity:AddSoundEmitter()

    return inst
end

return Prefab("offscreenentityproxy", fn)
