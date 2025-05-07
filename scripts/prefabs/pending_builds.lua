local function MakePendingBuildPrefab(name, params)
	local assets =
	{
		Asset("ANIM", "anim/"..(params.build or name)..".zip"),
	}
	if params.bankfile ~= nil and params.bankfile ~= (params.build or name) then
		assets[#assets + 1] = Asset("ANIM", "anim/"..params.bankfile..".zip")
	end

	local prefabs =
	{
		name,
	}

	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()

		--See if we need AnimState first
		if params.parallax ~= nil then
			for i = 1, #params.parallax do
				local layerparams = params.parallax[i]
				if layerparams.anim ~= nil and (layerparams.dist == nil or layerparams.dist == 0) then
					inst.entity:AddAnimState()
					break
				end
			end
		end

		inst:AddTag("NOCLICK")
		inst.persists = false

		inst:AddComponent("pendingbuild")
		inst.components.pendingbuild:SetPlacedPrefab(name)
		inst.components.pendingbuild:SetParams(params)

		if params.gridsize ~= nil and #params.gridsize > 0 then
			inst:AddComponent("snaptogrid")
			for i = 1, #params.gridsize do
				local gridsize = params.gridsize[i]
				if gridsize.w ~= nil and gridsize.h ~= nil then
					inst.components.snaptogrid:SetDimensions(gridsize.w, gridsize.h, gridsize.level, gridsize.expand)
				end
			end
		end

		return inst
	end

	return Prefab(name.."_pending", fn, assets, prefabs)
end

return
{
	MakePendingBuildPrefab = MakePendingBuildPrefab,
}