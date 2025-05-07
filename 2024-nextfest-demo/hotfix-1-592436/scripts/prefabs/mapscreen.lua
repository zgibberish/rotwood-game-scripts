local assets =
{
	Asset("ATLAS", "images/map_ftf.xml"),
	Asset("IMAGE", "images/map_ftf.tex"),
	
	Asset("ATLAS", "images/mapicons_ftf.xml"),
	Asset("IMAGE", "images/mapicons_ftf.tex"),
}

return Prefab("mapscreen", function() end, assets)
