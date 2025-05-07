local assets = {
	-- Load assets here that will only get used from town (e.g., atlases for screens)
	--
	-- Don't need world prefabs placed in town here: we can pull
	-- them from the placmenets.



	-- DungeonSelectionScreen
	Asset("ANIM", "anim/dungeon_map_art.zip"),
	Asset("ATLAS", "images/bg_world_map_full.xml"),
	Asset("IMAGE", "images/bg_world_map_full.tex"),
	Asset("ATLAS", "images/bg_world_map_art_cloud_above.xml"),
	Asset("IMAGE", "images/bg_world_map_art_cloud_above.tex"),
	Asset("ATLAS", "images/bg_world_map_art_cloud_below.xml"),
	Asset("IMAGE", "images/bg_world_map_art_cloud_below.tex"),
	Asset("ATLAS", "images/bg_world_map_ocean_texture.xml"),
	Asset("IMAGE", "images/bg_world_map_ocean_texture.tex"),

}

return Prefab(GroupPrefab("deps_town"), function() end, assets)
