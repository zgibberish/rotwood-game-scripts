local Bound2 = require "math.modules.bound2"
local GroundTiles = require "defs.groundtiles"
local kassert = require "util.kassert"
local Lume = require "util.lume"
require "class"
require "constants"
require "vector2"

local function get_tile_group(layout)
	if #layout.tilesets > 0 then
		return GroundTiles.TileGroups[layout.tilesets[1].name]
	end
	return GroundTiles.TileGroups.EMPTY
end


--- Helper to compute map layout information without loading a world.
local MapLayout = Class(function(self, layout)
	self.layout = layout
	self.tilegroup = get_tile_group(layout)
	self.ground = Lume(layout.layers):match(function(layer) return layer.name == "BG_TILES" end):result()
	self.zones = Lume(layout.layers):match(function(layer) return layer.name == "ZONE_TILES" end):result()
	self.portals = Lume(layout.layers):match(function(layer) return layer.name == "PORTALS" end):result()
end)

function MapLayout:CollectDeps(assets, prefabs)
	-- Prefabs used on object layers
	local prefabmap = {}
	for i = 2, #self.layout.layers do
		local objects = self.layout.layers[i].objects
		if objects ~= nil then
			for j = 1, #objects do
				prefabmap[objects[j].type] = true
			end
		end
	end
	for prefab in pairs(prefabmap) do
		prefabs[#prefabs + 1] = prefab
	end

	-- Assets for tilegroup
	if #self.layout.tilesets > 0 then
		GroundTiles.CollectAssetsForTileGroup(assets, self.layout.tilesets[1].name)
	end
end

function MapLayout:GetPosFromLayoutObject(object)
	return {
		--Flip the Y-axis so it visually matches our tile editor
		x = (object.x / self.layout.tilewidth - (self.layout.width + 1) / 2) * TILE_SIZE,
		z = ((self.layout.height - 1) / 2 - object.y / self.layout.tileheight) * TILE_SIZE,
	}
end

function MapLayout:ConvertLayoutObjectToSaveRecord(object)
	local record = self:GetPosFromLayoutObject(object)
	if object.properties ~= nil then
		for k, v in pairs(object.properties) do
			if v == "true" then
				v = true
			elseif v == "false" then
				v = false
			else
				v = tonumber(v) or v
			end

			local keys = string.split(k, ".")
			for i = #keys, 2, -1 do
				v = { [keys[i]] = v }
			end

			if record.data == nil then
				record.data = { [keys[1]] = v }
			else
				record.data[keys[1]] = v
			end
		end
	end

	return record
end

function MapLayout:_GetTileSetIndexOffset(tile_set_name)
	return Lume(self.layout.tilesets)
		:match(function(tile_set) return tile_set.name == tile_set_name end)
		:result()
		.firstgid
end

function MapLayout:GetGroundLayer()
	return self.ground
end

function MapLayout:GetZonesLayer()
	return self.zones
end

function MapLayout:GetZonesTileSetIndexOffset()
	return self:_GetTileSetIndexOffset("zone_tiles")
end

function MapLayout:GetPortalLayer()
	local layer = self.portals
	kassert.equal(layer.name, "PORTALS")
	return layer
end

function MapLayout:GetTileGroupIdFromLayerData(ground_layer, tilesidx)
	local externaltileid = ground_layer.data[tilesidx]
	local tilename = self.tilegroup.ExternalOrder[externaltileid]
	return self.tilegroup.Ids[tilename or "IMPASSABLE"]
end

-- This is not the playable area! It's the size of the world in tiles.
function MapLayout:GetGroundBounds()
	local tiles = self:GetGroundLayer()
	local bounds = Bound2(
		-- highest possible values for min and below lowest for max so we can
		-- detect invalid bounds.
		Vector2(tiles.width, tiles.height),
		Vector2(-1, -1))
	local i = 0
	-- Flip the Y-axis so Tiled matches how we render tiles.
	for y = tiles.height - 1, 0, -1 do
		for x = 0, tiles.width - 1 do
			i = i + 1
			local tile = self:GetTileGroupIdFromLayerData(tiles, i)
			if tile ~= self.tilegroup.Ids.IMPASSABLE then
				bounds = bounds:extend(Vector2(x, y))
			end
		end
	end
	if bounds.max == -1 then
		-- Tile positions are positive, so we didn't find any that weren't
		-- impassible. Return nil for invalid bounds.
		return nil
	end
	return bounds
end

local function test_GetGroundBounds()
	local layout = MapLayout(require("map.layouts.startingforest.startingforest_ew"))
	local bounds = layout:GetGroundBounds()
	kassert.equal(bounds.min.x, 5)
	kassert.equal(bounds.min.y, 4)
	kassert.equal(bounds.max.x, 18)
	kassert.equal(bounds.max.y, 11)
	-- Room is 14x8, so bounds is one less (zero indexed).
	kassert.equal(bounds:size().x, 13)
	kassert.equal(bounds:size().y, 7)
end


function MapLayout:GetPortalWorldBounds()
	local tiles = self:GetPortalLayer()
	local objects = tiles.objects
	if objects == nil then
		return
	end
	local bounds = Bound2()
	for i,obj in ipairs(objects) do
		local p = obj.properties or {}
		local cardinal = p["roomportal.cardinal"]
		if not p.no_bounds then
			local pos = self:GetPosFromLayoutObject(obj)
			if cardinal == "north" or cardinal == "south" then
				pos.x = 0
			elseif cardinal == "east" or cardinal == "west" then
				pos.z = 0
			end
			bounds = bounds:extend(Vector2(pos.x, pos.z))
		end
	end
	return bounds
end

local function test_GetPortalWorldBounds()
	local layout = MapLayout(require("map.layouts.startingforest.startingforest_ew"))
	local bounds = layout:GetPortalWorldBounds()
	kassert.equal(bounds.min.x, -20)
	kassert.equal(bounds.min.y, 0)
	kassert.equal(bounds.max.x, 20)
	kassert.equal(bounds.max.y, 0)
	kassert.equal(bounds:size().x, 40)
	kassert.equal(bounds:size().y, 0)

	layout = MapLayout(require("map.layouts.startingforest.startingforest_nesw"))
	bounds = layout:GetPortalWorldBounds()
	kassert.equal(bounds.min.x, -20)
	kassert.equal(bounds.min.y, -16)
	kassert.equal(bounds.max.x, 20)
	kassert.equal(bounds.max.y, 16)
	kassert.equal(bounds:size().x, 40)
	kassert.equal(bounds:size().y, 32)
end


-- These are the bounds of the playable area in worldspace. If tile paths
-- extend beyond the portals, they're ignored.
function MapLayout:GetWorldspaceBounds()
	local bounds = self:GetGroundBounds()
	if not bounds then
		return
	end
	local layouttiles = self:GetGroundLayer()

	-- NOTE: the half width/height math matches legacy map component behavior
	local halfgrid = (layouttiles.width + 1) / 2
	bounds.min.x = bounds.min.x - halfgrid
	bounds.max.x = bounds.max.x - halfgrid + 1
	halfgrid = (layouttiles.height + 1) / 2
	bounds.min.y = bounds.min.y - halfgrid
	bounds.max.y = bounds.max.y - halfgrid + 1

	bounds.min = bounds.min * TILE_SIZE
	bounds.max = bounds.max * TILE_SIZE

	local portal_bounds = self:GetPortalWorldBounds()
	if portal_bounds then
		-- Snip off bounds to portals to ignore exit pathways that lead into
		-- the darkness. Don't want the camera to see the end of them.
		if portal_bounds.min.x < 0 then
			bounds.min.x = portal_bounds.min.x
		end
		if portal_bounds.max.x > 0 then
			bounds.max.x = portal_bounds.max.x
		end
		if portal_bounds.min.y < 0 then
			bounds.min.y = portal_bounds.min.y
		end
		if portal_bounds.max.y > 0 then
			bounds.max.y = portal_bounds.max.y
		end
	end

	return bounds
end

local function test_GetWorldspaceBounds()
	local layout = MapLayout(require("map.layouts.startingforest.startingforest_ew"))
	local bounds = layout:GetWorldspaceBounds()
	kassert.equal(bounds.min.x, -20)
	kassert.equal(bounds.min.y, -16)
	kassert.equal(bounds.max.x, 20)
	kassert.equal(bounds.max.y, 16)
	kassert.equal(bounds:size().x, 40)
	kassert.equal(bounds:size().y, 32)
end

return MapLayout
