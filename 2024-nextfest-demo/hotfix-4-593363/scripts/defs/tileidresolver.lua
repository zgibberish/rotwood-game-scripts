local GroundTiles = require "defs.groundtiles"

local TILE_NAME_REMAPPERS = {
	-- How to map to startingforest...
	startingforest = {	
		-- ...from owlitzer_forest
		owlitzer_forest = {		
			DIRTROCKY = "DIRT",
			GRASSHAY = "GRASS",
			OWLTREE = "DIRTROT",
			OWLSTONE = "GRASSROT",
			STONEFLOOR = "STONEFLOOR",

			STARTINGFOREST_CLIFF = "STARTINGFOREST_CLIFF"
		},
		-- ...from bandiforest
		bandiforest = {		
			MOLD = "DIRT",
			FUZZ = "GRASS",
			MOLDCOOT = "DIRTROT",
			FUZZCOOT = "GRASSROT",
			STONEFLOOR = "STONEFLOOR",
			
			BANDIFOREST_CLIFF = "STARTINGFOREST_CLIFF",
		},
	},
	-- How to map to owlitzer_forest...
	owlitzer_forest = {	
		-- ...from startingforest
		startingforest = {		
			DIRT = "DIRTROCKY",
			GRASS = "GRASSHAY",
			DIRTROT = "OWLSTONE",
			GRASSROT = "OWLTREE",
			STONEFLOOR = "STONEFLOOR",
			
			STARTINGFOREST_CLIFF = "STARTINGFOREST_CLIFF"
		},
		-- ...from bandiforest
		bandiforest = {		
			MOLD = "DIRTROCKY",
			FUZZ = "GRASSHAY",
			MOLDCOOT = "OWLSTONE",
			FUZZCOOT = "OWLTREE",
			STONEFLOOR = "STONEFLOOR",
			BANDIFOREST_CLIFF = "STARTINGFOREST_CLIFF",
		},
	},
	-- How to map to bandiforest...
	bandiforest = {	
		-- ...from startingforest
		startingforest = {		
			DIRT = "MOLD",
			GRASS = "FUZZ",
			DIRTROT = "MOLDCOOT",
			GRASSROT = "FUZZCOOT",
			STONEFLOOR = "STONEFLOOR",
			
			STARTINGFOREST_CLIFF = "BANDIFOREST_CLIFF"
		},
		-- ...from owlitzer_forest
		owlitzer_forest = {		
			DIRTROCKY = "MOLD",
			GRASSHAY = "FUZZ",
			OWLTREE = "MOLDCOOT",
			OWLSTONE = "FUZZCOOT",
			STONEFLOOR = "STONEFLOOR",

			STARTINGFOREST_CLIFF = "BANDIFOREST_CLIFF"
		},
	},
	-- How to map to thatcher_swamp...
	thatcher_swamp = {	
		-- ...from bandiforest
		bandiforest = {		
			MOLD = "MOLDDIRT",
			FUZZ = "FUZZGRASS",
			MOLDCOOT = "MOLDSLIMY",
			FUZZCOOT = "FUZZSLIMY",
			STONEFLOOR = "STONEFLOOR",
			BANDIFOREST_CLIFF = "BANDIFOREST_CLIFFACID",
		},
		-- ...from startingforest
		startingforest = {		
			DIRT = "MOLDDIRT",
			GRASS = "FUZZGRASS",
			DIRTROT = "MOLDSLIMY",
			GRASSROT = "FUZZSLIMY",
			STONEFLOOR = "STONEFLOOR",
			
			STARTINGFOREST_CLIFF = "BANDIFOREST_CLIFFACID"
		},
	},
	-- How to map to sedament_tundra...
	sedament_tundra = {	
		-- ...from bandiforest
		bandiforest = {		
			MOLD = "ROCK",
			FUZZ = "SNOW",
			MOLDCOOT = "ROCKSNOW",
			FUZZCOOT = "SNOWHEAVY",
			STONEFLOOR = "STONEFLOOR",
			BANDIFOREST_CLIFF = "TUNDRASNOW_CLIFF",
		},
		-- ...from startingforest
		startingforest = {		
			DIRT = "ROCK",
			GRASS = "SNOW",
			DIRTROT = "ROCKSNOW",
			GRASSROT = "SNOWHEAVY",
			STONEFLOOR = "STONEFLOOR",			
			STARTINGFOREST_CLIFF = "TUNDRASNOW_CLIFF"
		},
	},
	-- How to map to snowmtn_mtntop...
	snowmtn_mtntop = {	
		-- ...from bandiforest
		bandiforest = {		
			MOLD = "SNOWMTN_FLOOR",
			FUZZ = "SNOWMTN_SNOW",
			MOLDCOOT = "SNOWMTN_FLOOR",
			FUZZCOOT = "SNOWMTN_SNOW",
			STONEFLOOR = "SNOWMTN_FLOOR",
			BANDIFOREST_CLIFF = "SNOWMTN_CLIFF",
		},
		-- ...from startingforest
		startingforest = {		
			DIRT = "SNOWMTN_FLOOR",
			GRASS = "SNOWMTN_SNOW",
			DIRTROT = "SNOWMTN_FLOOR",
			GRASSROT = "SNOWMTN_SNOW",
			STONEFLOOR = "SNOWMTN_FLOOR",			
			STARTINGFOREST_CLIFF = "SNOWMTN_CLIFF"
		},
	},
}

local TileIdResolver = Class(function(self, layout_data, from_group_name, to_group_name)
	self.layout_data = layout_data;
	self.from_group = GroundTiles.TileGroups[from_group_name]
	self.to_group = GroundTiles.TileGroups[to_group_name]
	if from_group_name ~= to_group_name then
		local name_remapper = TILE_NAME_REMAPPERS[to_group_name]
		if name_remapper then
			self.name_remapper = name_remapper[from_group_name]
		end
	end
end)

function TileIdResolver:_IndexToSourceName(index)
	local id = self.layout_data[index]
	local name = self.from_group.ExternalOrder[id] or "IMPASSABLE"
	return name
end

---Maps 'from_tile_index' to a TileId. If a remapping from 'from_group_name' to 'to_group_name' is defined, then that
---mapping will be applied before the Id is resolved.
function TileIdResolver:IndexToId(from_tile_index)
	local from_tile_name = self:_IndexToSourceName(from_tile_index)

	-- Try to remap if neccessary.
	if self:IsRemapper() then
		local to_tile_name = self.name_remapper[from_tile_name]
		if to_tile_name then
			return self.to_group.Ids[to_tile_name], to_tile_name
		end
	end

	-- If no remapping is required (or we can't because there is no name_remapper), just look up the Id in the from_group.
	return self.from_group.Ids[from_tile_name], from_tile_name
end

---Return true if we have remapping data to map from from_group_name to to_group_name.
function TileIdResolver:IsRemapper()
	return self.name_remapper ~= nil
end

return TileIdResolver
