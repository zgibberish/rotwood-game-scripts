--------------------------------------------------------------------------
-- Defines tilesets used in Tiled.
-- NOTE: Also used by //contentsrc/levels/TileGroups/updatetilegroups.lua
--
-- * Use contentsrc/levels/TileGroups/updatetilegroups.bat to apply changes from groundtiles.lua
-- * Add new tiles to contentsrc/levels/Textures/TextureList.py
-- * home_town.tmx is a good example of how we use Tiled.
--------------------------------------------------------------------------

local lume = require "util.lume"

local _tiles = {}
local _nextorder = 1
local audio_parameter_labels = {"dirt", "fuzz", "goo", "grass", "snow", "stone"}

local audio_surface_texture_translation_map = {
	bandiforest_fuzz = "grass",
	bandiforest_fuzzcoot = "grass",
	bandiforest_fuzzgrass = "grass",
}

local audio_surface_tileset_translation_map = {
	leaf = "grass",
	tree = "grass",
	blank = "dirt",
	hauntedforest = "dirt",
}

local function AddTile(name, tileset, texture, overhang)
	assert(_tiles[name] == nil)
	overhang = overhang or 0
	assert(overhang < 2, "Overhang must be less than 2")
	-- check if there's a parameter override for the texture translation map first
	local audio_param = lume.find(audio_parameter_labels, audio_surface_texture_translation_map[texture])
	-- if not, fall back to the tileset translation map; if not, use the tileset
	audio_param = audio_param or lume.find(audio_parameter_labels, audio_surface_tileset_translation_map[tileset] or tileset)
	local tile =
	{
		tileset_atlas = "levels/tiles/"..tileset..".xml",
		tileset_image = "levels/tiles/"..tileset..".tex",
		noise_texture = texture ~= nil and ("levels/textures/"..texture..".tex") or "images/square.tex",
		order = _nextorder,
		overhang = overhang,
		audio_param = audio_param or 0 -- 0 is "other"
	}
	_nextorder = _nextorder + 1
	_tiles[name] = tile
	return tile
end

local function AddShadowTile(name, tileset, intensity)
	local tile = AddTile(name, tileset)
	tile.colorize = { intensity, intensity, intensity, 1 }
	tile.shadow = true
end

local function AddUndergroundTile(name, tileset)
	local tile = AddTile(name, tileset)
	tile.underground = true
end

--------------------------------------------------------------------------

local _groups = {}

--IMPASSABLE first
--Bottom to top
--Underground last
local function SortByRenderOrder(a, b)
	if a == "IMPASSABLE" then
		return true
	elseif b == "IMPASSABLE" then
		return false
	end
	a = _tiles[a]
	b = _tiles[b]
	return not a.underground and (b.underground or a.order > b.order)
end

local STATUS_PROTOTYPE = { is_proto = true, }
local function AddTileGroup(tilegroup, list, cfg)
	assert(_groups[tilegroup] == nil)
	cfg = cfg or table.empty

	local hasunderground = false

	local order = { "IMPASSABLE" }
	local unsorted = { "IMPASSABLE" }

	for i = 1, #list do
		assert(not hasunderground)
		local name = list[i]
		order[#order + 1] = name
		unsorted[#unsorted + 1] = name

		if _tiles[name].underground then
			hasunderground = true
		end
	end

	table.sort(order, SortByRenderOrder)

	local ids = {}
	for i = 1, #order do
		ids[order[i]] = i
	end

	_groups[tilegroup] =
	{
		hasunderground = hasunderground,
		Ids = ids,
		Order = order,
		ExternalOrder = unsorted, --tile palette for external editor
		is_proto = cfg.is_proto, -- not ready for broad use
		has_ground_impacts = not cfg.skip_ground_impacts
	}
end

--IMPASSABLE first
--Highest to lowest intensity
local function SortByShadowIntensity(a, b)
	if a == "IMPASSABLE" then
		return true
	elseif b == "IMPASSABLE" then
		return false
	end
	a = _tiles[a]
	b = _tiles[b]
	return a.colorize[1] > b.colorize[1] or (a.colorize[1] == b.colorize[1] and a.order > b.order)
end

local function AddShadowTileGroup(tilegroup, list)
	assert(_groups[tilegroup] == nil)

	local order = { "IMPASSABLE" }

	for i = 1, #list do
		local name = list[i]
		assert(_tiles[name].shadow)
		order[#order + 1] = name
	end

	table.sort(order, SortByShadowIntensity)

	local ids = {}
	for i = 1, #order do
		ids[order[i]] = i
	end

	_groups[tilegroup] =
	{
		Ids = ids,
		Order = order,
		is_shadow_group = true,
	}
end

local function CollectAssetsForTileGroup(assets, tilegroup)
	local tiles = _groups[tilegroup]
	if tiles ~= nil then
		for i = 1, #tiles.Order do
			local def = _tiles[tiles.Order[i]]
			if def ~= nil then
				if def.underground then
					assets[#assets + 1] = Asset("ATLAS", def.tileset_atlas)
				else
					assets[#assets + 1] = Asset("FILE", def.tileset_atlas)
				end
				assets[#assets + 1] = Asset("IMAGE", def.tileset_image)
				assets[#assets + 1] = Asset("IMAGE", def.noise_texture)
			end
		end
	end
end

--------------------------------------------------------------------------
-- Define all tiles here.
-- ORDER MATTERS for render layers!
-- Top of the list will be rendered on top.

-- AddTile args:
--		name: id for AddTileGroup
-- 		tileset: edge tileset (folder in contentsrc/levels/Textures)
-- 		texture: surface texture file name (png in contentsrc/levels/Textures)
-- 		overhang: ??

AddTile("ROTTINGFOREST_LEAVES", "leaf", "rottingforest_leaves")
AddTile("GRASS", "grass", "generic_grass", 1.15)
AddTile("GRASSROT", "grass", "generic_grassrot", 1.15)
AddTile("GRASSHAY", "grasstown", "generic_grasshay", 0.5)
AddTile("GRASSTHAT", "grass", "generic_grassthat")

AddTile("COBBLESTONE", "stone", "generic_cobblestone")
AddTile("STONEFLOOR", "stone", "stone_floor")
AddTile("STONE", "stone", "generic_stone")

AddTile("DIRT", "dirt", "generic_dirt", 0.5)
AddTile("DIRTROT", "dirt", "generic_dirtrot", 0.5)
AddTile("DIRTROCKY", "dirt", "generic_dirtrocky", 0.5)
AddTile("DIRTTHAT", "dirt", "generic_dirtthat")

AddTile("GRASSTOWN", "grasstown", "town_grass", 0.5)
AddTile("GRASSDARKTOWN", "grasstown", "town_grassdark", 0.5)
AddTile("DIRTTOWN", "dirt", "town_dirt", 0.5)
AddTile("COBBLETOWN", "stone", "town_cobblestone", 0.5)
AddTile("STONETOWN", "stone", "town_stone")

AddTile("OWLTREE", "tree", "owlitzer_tree")
AddTile("OWLSTONE", "dirt", "owlitzer_stone", 0.5)

AddTile("FUZZ", "fuzz", "bandiforest_fuzz",1.2)
AddTile("FUZZCOOT", "fuzz", "bandiforest_fuzzcoot",1.2)
AddTile("FUZZGRASS", "fuzzgrass", "bandiforest_fuzzgrass",1.0)
AddTile("FUZZSLIMY", "fuzz", "bandiforest_fuzzslimy",1.2)
AddTile("MOLD", "goo", "bandiforest_mold", 0.3)
AddTile("MOLDCOOT", "goo", "bandiforest_moldcoot", 0.3)
AddTile("MOLDDIRT", "goo", "bandiforest_molddirt", 0.3)
AddTile("MOLDSLIMY", "goo", "bandiforest_moldslimy", 0.3)

AddTile("SNOW", "snow", "tundra_snow", 1.2)
AddTile("SNOWHEAVY", "snow", "tundra_snowheavy", 1.2)
AddTile("ROCK", "stone", "tundra_rock", 0.5)
AddTile("ROCKSNOW", "stone", "tundra_rocksnow", 0.5)

AddTile("SNOWMTN_SNOW", "snow", "snowmtn_snow")
AddTile("SNOWMTN_DIRTSNOW", "snow", "snowmtn_dirtsnow")
AddTile("SNOWMTN_FLOOR", "stone", "snowmtn_floor")
AddTile("SNOWMTN_DIRT", "dirt", "snowmtn_dirt")

AddTile("STARTINGFOREST_ROOT", "dirt", "startingforest_dirtwroot", 0.5)

AddTile("HAUNTEDFOREST_FLOOR1", "blank", "hauntedforest_floor_var1")
AddTile("HAUNTEDFOREST_FLOOR2", "blank", "hauntedforest_floor_var2")
AddTile("HAUNTEDFOREST_CRATER", "hauntedforest", "hauntedforest_crater_lighter")

AddTile("BANDIFOREST_FLOOR1", "blank", "bandiforest_floor_var1")
AddTile("BANDIFOREST_FLOOR2", "blank", "bandiforest_floor_var2")
AddTile("BANDIFOREST_FLOOR3", "blank", "bandiforest_floor_var3")

AddTile("ROTTINGFOREST_DIRT", "dirt", "rottingforest_dirt")
AddTile("ROTTINGFOREST_FLOOR1", "blank", "rottingforest_floor_var1")
AddTile("ROTTINGFOREST_FLOOR2", "blank", "rottingforest_floor_var2")
AddTile("ROTTINGFOREST_FLOOR3", "blank", "rottingforest_floor_var3")

AddTile("SNOWMTN_FLOOR1", "blank", "snowmtn_floor_var1")
AddTile("SNOWMTN_FLOOR2", "blank", "snowmtn_floor_var2")
AddTile("SNOWMTN_FLOOR3", "blank", "snowmtn_floor_var3")
AddTile("SNOWMTN_FLOOR4", "blank", "snowmtn_floor_var4")

AddTile("SNOWMTN_DIRT1", "blank", "snowmtn_dirt_var1")
AddTile("SNOWMTN_DIRT2", "blank", "snowmtn_dirt_var2")
AddTile("SNOWMTN_DIRT3", "blank", "snowmtn_dirt_var3")
AddTile("SNOWMTN_DIRT4", "blank", "snowmtn_dirt_var4")

AddTile("GRADIENT_TEST1", "blank", "gradient_test1")
AddTile("GRADIENT_TEST2", "blank", "gradient_test2")

AddTile("ZONE_BG", "blank", "zone_bg")
AddTile("ZONE_DISTANTBG", "blank", "zone_distantbg")
AddTile("ZONE_DISTANTFG", "blank", "zone_distantfg")
AddTile("ZONE_DISTANTSIDE", "blank", "zone_distantside")
AddTile("ZONE_EXIT", "blank", "zone_exit")
AddTile("ZONE_FG", "blank", "zone_fg")
AddTile("ZONE_FGSIDE", "blank", "zone_fgside")
AddTile("ZONE_FRONTPER", "blank", "zone_frontper")
AddTile("ZONE_INSIDEPER", "blank", "zone_insideper")
AddTile("ZONE_MIDDLE", "blank", "zone_middle")
AddTile("ZONE_NEARBG", "blank", "zone_nearbg")
AddTile("ZONE_NEARFG", "blank", "zone_nearfg")
AddTile("ZONE_NEARSIDE", "blank", "zone_nearside")
AddTile("ZONE_NEARUNDERLAY", "blank", "zone_nearunderlay")
AddTile("ZONE_SIDE", "blank", "zone_side")
AddTile("ZONE_SIDEINLET", "blank", "zone_sideinlet")
AddTile("ZONE_SIDEINLETTWO", "blank", "zone_sideinlettwo")
AddTile("ZONE_SPACEA", "blank", "zone_spacea")
AddTile("ZONE_SPACEB", "blank", "zone_spaceb")
AddTile("ZONE_SPACEC", "blank", "zone_spacec")
AddTile("ZONE_UNDERLAY", "blank", "zone_underlay")

--Shadow tiles (will automatically be sorted by intensity)

AddShadowTile("FOREST_SHADOW4", "forest_shadow", .1)
AddShadowTile("FOREST_SHADOW3", "forest_shadow", .4)
AddShadowTile("FOREST_SHADOW2", "forest_shadow", .7)
AddShadowTile("FOREST_SHADOW1", "forest_shadow", 1)

AddShadowTile("GRADIENT_SHADOW4", "gradient_shadow", .1)
AddShadowTile("GRADIENT_SHADOW3", "gradient_shadow", .4)
AddShadowTile("GRADIENT_SHADOW2", "gradient_shadow", .7)
AddShadowTile("GRADIENT_SHADOW1", "gradient_shadow", 1)

AddShadowTile("SNOWMTN_SHADOW4", "snowmtn_shadow", .1)
AddShadowTile("SNOWMTN_SHADOW3", "snowmtn_shadow", .4)
AddShadowTile("SNOWMTN_SHADOW2", "snowmtn_shadow", .7)
AddShadowTile("SNOWMTN_SHADOW1", "snowmtn_shadow", 1)

--Underground tiles (will always be sorted last)

AddUndergroundTile("SNOWMTN_CLIFF", "snowmtn_falloff")
AddUndergroundTile("STARTINGFOREST_CLIFF", "startingforest_cliff")
AddUndergroundTile("BANDIFOREST_CLIFF", "bandiforest_cliff")
AddUndergroundTile("BANDIFOREST_CLIFFACID", "bandiforest_cliffacid")
AddUndergroundTile("ROTTINGFOREST_CLIFF", "rottingforest_cliff")
AddUndergroundTile("BANDIFOREST_CLIFFSLIMY", "bandiforest_cliffslimy")
AddUndergroundTile("TUNDRASNOW_CLIFF", "tundrasnow_cliff")

--------------------------------------------------------------------------
--Maintain order of tile palette for external editor use.
--Rendering will automatically use layer order from above.

AddTileGroup("EMPTY", {})

AddTileGroup("all_tiles",
{
	"DIRT",
	"DIRTROCKY",
	"DIRTROT",
	"DIRTTOWN",	
	"GRASS",
	"GRASSHAY",
	"GRASSROT",
	"GRASSTOWN",
	"OWLTREE",
	"OWLSTONE",
	"MOLD",
	"MOLDDIRT",
	"FUZZ",
	"FUZZGRASS",
	"MOLDCOOT",
	"FUZZCOOT",
	"COBBLESTONE",
	"COBBLETOWN",
	"STONEFLOOR",
	"STONE",
	"FUZZSLIMY",
	"MOLDSLIMY",
	"SNOW",
	"SNOWHEAVY",
	"ROCK",
	"ROCKSNOW",
	--
	"STARTINGFOREST_CLIFF",
})

AddTileGroup("startingforest",
{
	"DIRT",
	"GRASS",
	"DIRTROT",
	"GRASSROT",
	"STONEFLOOR",
	--
	"STARTINGFOREST_CLIFF",
})

AddTileGroup("owlitzer_forest",
{
	"DIRTROCKY",
	"GRASSHAY",
	"OWLTREE",
	"OWLSTONE",
	"STONEFLOOR",
	--
	"STARTINGFOREST_CLIFF",
})

AddTileGroup("town",
{
	"GRASSTOWN",
	"COBBLETOWN",
	"STONETOWN",	
	"DIRTTOWN",	
	"GRASSDARKTOWN",
	--
	"STARTINGFOREST_CLIFF",
})

AddTileGroup("bandiforest",
{
	"MOLD",
	"FUZZ",
	"MOLDCOOT",
	"FUZZCOOT",
	"STONEFLOOR",
	--
	"BANDIFOREST_CLIFF",
})

AddTileGroup("thatcher_swamp",
{
	"MOLDDIRT",
	"FUZZGRASS",
	"MOLDSLIMY",
	"FUZZSLIMY",
	"STONEFLOOR",
	--
	"BANDIFOREST_CLIFFACID",
})

AddTileGroup("sedament_tundra",
{
	"ROCK",
	"SNOW",
	"ROCKSNOW",
	"SNOWHEAVY",
	"STONEFLOOR",
	--
	"TUNDRASNOW_CLIFF",
})

AddTileGroup("rottingforest",
{
	"ROTTINGFOREST_LEAVES",
	"ROTTINGFOREST_DIRT",
	--
	"ROTTINGFOREST_CLIFF",
}, STATUS_PROTOTYPE)

AddTileGroup("zone_tiles",
{
	"ZONE_NEARBG",
	"ZONE_BG",
	"ZONE_DISTANTBG",
	"ZONE_NEARSIDE",
	"ZONE_SIDE",
	"ZONE_DISTANTSIDE",
	"ZONE_FGSIDE",
	"ZONE_NEARFG",
	"ZONE_FG",
	"ZONE_DISTANTFG",
	"ZONE_NEARUNDERLAY",
	"ZONE_UNDERLAY",
	"ZONE_FRONTPER",
	"ZONE_INSIDEPER",
	"ZONE_MIDDLE",
	"ZONE_EXIT",
	"ZONE_SIDEINLET",
	"ZONE_SIDEINLETTWO",
	"ZONE_SPACEA",
	"ZONE_SPACEB",
	"ZONE_SPACEC",
	--
	"STARTINGFOREST_CLIFF",
},
{
	skip_ground_impacts = true,
})

--#TODO: #REMOVE
AddTileGroup("snowmtn_mtntop",
{
	"SNOWMTN_FLOOR",
	"SNOWMTN_SNOW",
	--
	"SNOWMTN_CLIFF",
}, STATUS_PROTOTYPE)

--#TODO: #REMOVE
AddTileGroup("snowmtn_forest",
{
	"SNOWMTN_DIRT",
	"SNOWMTN_DIRTSNOW",
}, STATUS_PROTOTYPE)

--#TODO: #REMOVE
AddTileGroup("gradienttest",
{
	"GRADIENT_TEST1",
	"GRADIENT_TEST2",
}, STATUS_PROTOTYPE)

-- Shadows

AddShadowTileGroup("forest_shadow",
{
	"FOREST_SHADOW1",
	"FOREST_SHADOW2",
	"FOREST_SHADOW3",
	"FOREST_SHADOW4",
})

AddShadowTileGroup("gradient_shadow",
{
	"GRADIENT_SHADOW1",
	"GRADIENT_SHADOW2",
	"GRADIENT_SHADOW3",
	"GRADIENT_SHADOW4",
})


AddShadowTileGroup("snowmtn_shadow",
{
	"SNOWMTN_SHADOW1",
	"SNOWMTN_SHADOW2",
	"SNOWMTN_SHADOW3",
	"SNOWMTN_SHADOW4",
})

AddShadowTileGroup("mixed_shadow",
{
	"GRADIENT_SHADOW1",
	"GRADIENT_SHADOW2",
	"GRADIENT_SHADOW3",
	"FOREST_SHADOW4",
})

--------------------------------------------------------------------------

local GroundTiles = {
	Tiles = _tiles,
	TileGroups = _groups,
	CollectAssetsForTileGroup = CollectAssetsForTileGroup,
}

return GroundTiles
