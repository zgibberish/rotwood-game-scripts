local PendingBuilds = require "prefabs.pending_builds"



local function MakePlacerPrefab(name, params)
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

		inst:AddComponent("placer")
		inst.components.placer:SetPlacedPrefab(name)
		inst.components.placer:SetParams(params)

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

	local pending_prefab = PendingBuilds.MakePendingBuildPrefab(name, params)
	table.insert(prefabs, pending_prefab.name)

	local placer_prefab = Prefab(name.."_placer", fn, assets, prefabs)
	return { placer_prefab, pending_prefab }
end

return
{
	MakePlacerPrefab = MakePlacerPrefab,
}
