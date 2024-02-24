local function fn()
    local inst = CreateEntity()
		:MakeSurviveRoomTravel()

    --[[Non-networked entity]]
    inst.entity:AddTransform()
    inst.entity:AddSoundEmitter()
    inst.entity:Hide()
    inst:AddTag("CLASSIFIED")

    inst.persists = false

    local focalpoint = inst:AddComponent("focalpoint")
    focalpoint:SetDefaultCameraDistance(40)

	-- convenience toggle function for TheFocalPoint use
	inst.IsEntityEdgeDetectionEnabled = function(_inst)
		return inst.components.focalpoint.edgeDetectEnabled
	end

	inst.EnableEntityEdgeDetection = function(_inst, enabled)
		inst.components.focalpoint:EnableEntityEdgeDetection(enabled)
	end

    return inst
end

return Prefab("focalpoint", fn)
