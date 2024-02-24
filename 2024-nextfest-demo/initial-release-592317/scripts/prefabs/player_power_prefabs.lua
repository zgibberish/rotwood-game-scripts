local Power = require "defs.powers"

function MakePowerPrefab()
	local assets = {}
	local prefabs = {}

	Power.CollectPrefabs(prefabs)
	Power.CollectAssets(assets)

	-- Unspawnable prefabs for power dependencies.
	return Prefab(GroupPrefab("player_power_prefabs"), nil, assets, prefabs)
end

return MakePowerPrefab()
