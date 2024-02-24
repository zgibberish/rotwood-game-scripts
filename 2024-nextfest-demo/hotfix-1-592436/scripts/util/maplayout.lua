local Bound2 = require "math.modules.bound2"
local GroundTiles = require "defs.groundtiles"
local Lume = require "util.lume"
local kassert = require "util.kassert"
local mapgen = require "defs.mapgen"
require "class"
require "constants"
require "vector2"

local function get_tile_group(layout)
	if #layout.tilesets > 0 then
		return GroundTiles.TileGroups[layout.tilesets[1].name]
	end
	return GroundTiles.TileGroups.EMPTY
end

local EMPTY_TILE <const> = 0

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

function MapLayout:_BuildPortalMap()
	local portals = {}
	for i,obj,p in self:PortalObjects() do
		local cardinal = p["roomportal.cardinal"]
		if cardinal then
			portals[cardinal] = obj
		end
	end
	return portals
end

function MapLayout:EliminateInvalidExits(worldmap)
	local portals = self:_BuildPortalMap()

	if not next(portals) then
		-- No portals, nothing to cut.
		return
	end

	local entrances = worldmap:GetCurrentWorldEntrances()
	local to_remove = Lume.reject(entrances, function(cardinal)
		return worldmap:HasGateInCardinalDirection(cardinal)
	end)
	--~ to_remove = { "east", "west", "north", "south" } -- Test removing all directions.

	local tiles = self:GetGroundLayer()
	local world_sz = Vector2(tiles.width, tiles.height)
	for _,cardinal in ipairs(to_remove) do
		self:_CutOffExit(cardinal, portals, world_sz)
	end
end

function MapLayout:_ChangeTile(x, y, new_tile_type, require_tile_type)
	local tilesidx = self:TilePosToIdx(x, y)
	local tile = self.ground.data[tilesidx]
	if tile ~= EMPTY_TILE
		and tile ~= new_tile_type
		and (not require_tile_type or tile == require_tile_type)
	then
		--~ TheLog.ch.World:printf("Tile %i,%i: %s -> %s", x, y, tile, new_tile_type)
		self.ground.data[tilesidx] = new_tile_type
	end
end

function MapLayout:_CutOffExit(cardinal, portals, world_sz)
	local portal = portals[cardinal]
	if not portal then
		TheLog.ch.World:printf("_CutOffExit: No %s portal. Nothing to cut.", cardinal)
		return
	end
	local BORDER_TILE <const> = 3
	local border_depth <const> = 1
	local portal_hwidth <const> = 1
	local portal_pos = self:GetTilePosFromLayoutObject(portal)

	TheLog.ch.World:printf("_CutOffExit %s for world [%s]", cardinal, TheWorld)

	-- Tiled puts the top-left tile in the start of the array.

	local function ChangeTileRow(y, new_tile_type)
		for dx = -portal_hwidth, portal_hwidth + 0 do
			local x = portal_pos.x + dx
			self:_ChangeTile(x, y, new_tile_type)
		end
	end

	local function ChangeTileColumn(x, new_tile_type)
		for dy = -portal_hwidth, portal_hwidth do
			local y = portal_pos.y + dy
			self:_ChangeTile(x, y, new_tile_type)
		end
	end

	if cardinal == "west" then
		for x = 1, portal_pos.x do
			ChangeTileColumn(x, EMPTY_TILE)
		end
		for dx = 1, border_depth do
			local x = portal_pos.x + dx
			ChangeTileColumn(x, BORDER_TILE)
		end

	elseif cardinal == "east" then
		for dx = 0, border_depth do
			local x = portal_pos.x + dx
			ChangeTileColumn(x, BORDER_TILE)
		end
		for x = portal_pos.x + 1, world_sz.x do
			ChangeTileColumn(x, EMPTY_TILE)
		end

	elseif cardinal == "north" then
		for y = 1, portal_pos.y do
			ChangeTileRow(y, EMPTY_TILE)
		end
		for dy = 1, border_depth do
			local y = portal_pos.y + dy
			ChangeTileRow(y, BORDER_TILE)
		end

	elseif cardinal == "south" then
		for dy = 0, border_depth do
			local y = portal_pos.y + dy
			ChangeTileRow(y, BORDER_TILE)
		end
		for y = portal_pos.y + 1, world_sz.y do
			ChangeTileRow(y, EMPTY_TILE)
		end

	end
end

function MapLayout:TilePosToIdx(x, y)
	return (x) + (y - 1) * self.ground.width
end

function MapLayout:GetTilePosFromLayoutObject(object)
	local pos = Vector2(object):scale(1 / self.layout.tilewidth)
	return Vector2(
		Lume.round(pos.x),
		Lume.round(pos.y))
end

function MapLayout:GetWorldPosFromLayoutObject(object)
	return {
		--Flip the Y-axis so it visually matches our tile editor
		x = (object.x / self.layout.tilewidth - (self.layout.width + 1) / 2) * TILE_SIZE,
		z = ((self.layout.height - 1) / 2 - object.y / self.layout.tileheight) * TILE_SIZE,
	}
end

function MapLayout:ConvertLayoutObjectToSaveRecord(object)
	local record = self:GetWorldPosFromLayoutObject(object)
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


-- iterator returning: index, object, properties
function MapLayout:PortalObjects()
	local tiles = self:GetPortalLayer()
	local objects = tiles.objects
	if objects == nil then
		return
	end

	local i = 0
	return function()
		i = i + 1
		local obj = objects[i]
		if obj then
			local p = obj.properties or {}
			return i, obj, p
		else
			return nil, nil
		end
	end
end

function MapLayout:GetPortalWorldBounds()
	local bounds = nil
	for i,obj,p in self:PortalObjects() do
		bounds = bounds or Bound2() -- only return non nil if there were objects.
		local cardinal = p["roomportal.cardinal"]
		if not p.no_bounds then
			local pos = self:GetWorldPosFromLayoutObject(obj)
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

	for i,obj,p in layout:PortalObjects() do
		kassert.typeof("number", layout:GetTilePosFromLayoutObject(obj):unpack())
	end

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



function MapLayout:RenderDebugUI(ui, panel, colors)
	ui:TextColored(colors.header, "MapLayout")

	ui:Text("These debug buttons only change the data, not the live world.")

	do
		local portals = self:_BuildPortalMap()
		local tiles = self:GetGroundLayer()
		local world_sz = Vector2(tiles.width, tiles.height)
		for _,cardinal in ipairs(mapgen.Cardinal:Ordered()) do
			if ui:Button("_CutOffExit ".. cardinal) then
				self:_CutOffExit(cardinal, portals, world_sz)
			end
		end
	end

	if ui:CollapsingHeader("Ground Tile Layout", ui.TreeNodeFlags.DefaultOpen) then
		local tiles = self:GetGroundLayer()
		local max = Vector2(tiles.width, tiles.height)

		ui:DragVec2f("Size", max:clone())

		local flags = (0
			| ui.TableFlags.SizingFixedSame
			| ui.TableFlags.BordersH
			| ui.TableFlags.BordersV)
		local btn_size = Vector2(23, 23)
		local implicit_pad = Vector2(9, 4)
		local table_draw_size = max:mul(btn_size + implicit_pad)
		if ui:BeginTable("forward", max.x + 1, flags, table_draw_size:unpack()) then
			-- Tiled puts the top-left tile in the start of the array.
			for y = 1, self.ground.height do
				ui:TableNextRow()
				for x = 1, self.ground.width do
					ui:TableNextColumn()
					local tilesidx = self:TilePosToIdx(x, y)
					local tile = tostring(self.ground.data[tilesidx])
					local coords = string.format("%i: %i,%i", tilesidx, x, y)
					ui:Button(tile .."##travel"..coords, btn_size:unpack())
					ui:SetTooltipIfHovered(coords)
				end
			end
			ui:EndTable()
		end
	end

	ui:Unindent()
end

return MapLayout
