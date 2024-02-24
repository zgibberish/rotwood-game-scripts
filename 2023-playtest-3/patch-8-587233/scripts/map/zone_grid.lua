-- Division of TilEd layouts into collections of tiles called zones.

--[[
Definitions:
============
zone - a collection of tiles, often but not necessarily connected physically, that represent some logical group
stage - the tiled area of the tile layout
stage bounds - the bounding box of the stage, excluding exit tiles
virtual - a cell is virtual if its distances were determined from neighboring cells rather than actual tiles
inside perimeter - the stage tiles at a depth of precisely one from the stage edge
outside permimeter - the offstage cells at a depth of precisely one from the stage edge

Coordinate Systems:
===================
TilEd - origin in top-left, with positive x extending right, and positive y extending down
ZoneGrid - origin in bottom-right, with positive x extending right, and positive y extending up
Game World - origin in the center, with positive x extending right, and positive z extending into the screen
]]

local Lume = require "util.lume"
local Enum = require "util.enum"
local Vec2 = require "math.modules.vec2"
local Bound2 = require "math.modules.bound2"
local PropProcGen = require "proc_gen.prop_proc_gen"
local GroundTiles = require "defs.groundtiles"
local TileIdResolver = require "defs.tileidresolver"

-- Each zone_grid cell stores distances to room features from that cell. For example, cell.Background
-- is the distance of the cell from the backmost part of the playable stage if the cell itself is offstage;
-- if the cell is on-stage, it is always zero. That is, the value of cell.Background is a metric of
-- how "Background" it is.
local Zone = Enum {
	"Foreground",
	"Background",
	"OffstageLeft",
	"OffstageRight",
	"StageForeground", -- how far from the front of the stage, i.e. lower number is "more" foreground
	"StageBackground", -- how far from the back of the stage, i.e. lower number is "more" background
	"StageLeft", -- how far from the left side of the stage, i.e. lower number is "more" left
	"StageRight", -- how far from the right side of the stage, i.e. lower number is "more" right
	"StageHorizontalCenter", -- how far from the horizontal center of the stage
	"StageVerticalCenter", -- how far from the vertical center of the stage

	-- The bounds of the stage is the rectangle surrounding it. It is sometimes more convenient and specific to talk
	-- in terms of distances from the bounds rather than the stage itself.
	"BoundsForeground",
	"BoundsBackground",
	"BoundsOffstageLeft",
	"BoundsOffstageRight",
}

local WORLD_TILE_SIZE = TILE_SIZE
local HALF_TILE = WORLD_TILE_SIZE / 2

--- Convert an (x, z) coordinate on the tile_layer to an index.
local function TilEdGridToIndex(tile_layer, x, z)
	return (tile_layer.height - z - 1) * tile_layer.width + x + 1
end

--- Convert an (x, z) coordinate on a grid with the specified width to an index.
local function GridToIndex(width, x, z)
	return z * width + x + 1
end

--- Convert an index into an (x, z) coordinate on a grid of the specified width.
local function IndexToGrid(width, index)
	index = index - 1
	return { x = index % width, z = index / width }
end

local function _WorldOriginToGridOrigin(grid_width, grid_height)
	return {
		x = grid_width / 2 * WORLD_TILE_SIZE + HALF_TILE,
		z = grid_height / 2 * WORLD_TILE_SIZE + HALF_TILE
	}
end

-- Transform a world position into a grid position.
-- World origin is in the center of the screen. Grid origin is bottom left. Grid is centered on the world origin.
local function WorldToGrid(grid_width, grid_height, world_position)
	local world_half_grid = _WorldOriginToGridOrigin(grid_width, grid_height)
	local point = {
		x = math.floor((world_position.x + world_half_grid.x) / WORLD_TILE_SIZE),
		y = world_position.y and math.floor(world_position.y / WORLD_TILE_SIZE),
		z = math.floor((world_position.z + world_half_grid.z) / WORLD_TILE_SIZE),
	}
	if 0 <= point.x
		and point.x < grid_width
		and 0 <= point.z
		and point.z < grid_height
	then
		return point
	else
		return nil
	end
end

-- Return the world position of the center of the specified tile.
local function GridToWorld(grid_width, grid_height, grid_position)
	local world_half_grid = _WorldOriginToGridOrigin(grid_width, grid_height)
	return {
		x = grid_position.x * WORLD_TILE_SIZE - world_half_grid.x + HALF_TILE,
		y = grid_position.y and grid_position.y * WORLD_TILE_SIZE,
		z = grid_position.z * WORLD_TILE_SIZE - world_half_grid.z + HALF_TILE,
	}
end

-- Query a cell's membership in a zone.
-- FilterDepth is a function that takes a cell_depth and returns a bool.
local function QueryZone(cell, zone, FilterDepth)
	local depth = cell[zone]
	return depth ~= nil and FilterDepth(depth) 
end

-- Check for membership of cell in zone.
-- If query_depth is non-nil, the cell must be at precisely the specified query_depth.
local function IsInZone(cell, zone, query_depth)
	dbassert(query_depth == nil or 0 < query_depth)
	local FilterDepth = query_depth == nil 
		and function(_) return true end
		or function(depth) return depth == query_depth end
	return QueryZone(cell, zone, FilterDepth)
end

-- Return true if the cell is further than 2 in the zone.
local function IsDistant(cell, zone)
	local DISTANT_DEPTH = 2
	return QueryZone(cell, zone, function(depth) 
		return DISTANT_DEPTH < depth 
	end) 
end

-- Convenience functions that wrap the zone specifier into the function name.
local function IsBackground(cell, depth) return IsInZone(cell, Zone.s.Background, depth) end
local function IsForeground(cell, depth) return IsInZone(cell, Zone.s.Foreground, depth) end
local function IsRight(cell, depth) return IsInZone(cell, Zone.s.OffstageRight, depth) end
local function IsLeft(cell, depth) return IsInZone(cell, Zone.s.OffstageLeft, depth) end
local function IsSide(cell, depth) return IsLeft(cell, depth) or IsRight(cell, depth) end
local function IsBoundsBackground(cell, depth) return IsInZone(cell, Zone.s.BoundsBackground, depth) end
local function IsBoundsForeground(cell, depth) return IsInZone(cell, Zone.s.BoundsForeground, depth) end
local function IsBoundsRight(cell, depth) return IsInZone(cell, Zone.s.BoundsOffstageRight, depth) end
local function IsBoundsLeft(cell, depth) return IsInZone(cell, Zone.s.BoundsOffstageLeft, depth) end
local function IsBoundsSide(cell, depth) return IsBoundsLeft(cell, depth) or IsBoundsRight(cell, depth) end
local function IsStageForeground(cell, depth) return IsInZone(cell, Zone.s.StageForeground, depth) end
local function IsStageBackground(cell, depth) return IsInZone(cell, Zone.s.StageBackground, depth) end
local function IsStageRight(cell, depth) return IsInZone(cell, Zone.s.StageRight, depth) end
local function IsStageLeft(cell, depth) return IsInZone(cell, Zone.s.StageLeft, depth) end
local function IsStageSide(cell, depth) return IsStageLeft(cell, depth) or IsStageRight(cell, depth) end
local function IsDistantLeft(cell) return IsDistant(cell, Zone.s.OffstageLeft) end
local function IsDistantRight(cell) return IsDistant(cell, Zone.s.OffstageRight) end

local function IsLeftBackground(cell) return IsBackground(cell) and IsLeft(cell) end
local function IsRightBackground(cell) return IsBackground(cell) and IsRight(cell) end
local function IsLeftForeground(cell) return IsForeground(cell) and IsLeft(cell) end 
local function IsRightForeground(cell) return IsForeground(cell) and IsRight(cell) end

local function IsBoundsLeftBackground(cell) return IsBoundsBackground(cell) and IsBoundsLeft(cell) end
local function IsBoundsRightBackground(cell) return IsBoundsBackground(cell) and IsBoundsRight(cell) end
local function IsBoundsLeftForeground(cell) return IsBoundsForeground(cell) and IsBoundsLeft(cell) end 
local function IsBoundsRightForeground(cell) return IsBoundsForeground(cell) and IsBoundsRight(cell) end

local function IsInBounds(cell)
	return cell.BoundsForeground <= 0
		and cell.BoundsBackground <= 0
		and cell.BoundsOffstageLeft <= 0
		and cell.BoundsOffstageRight <= 0
end

local function IsInHorizontalBounds(cell, margin)
	local WithinMargin = function(depth)
		return depth <= margin
	end
	return QueryZone(cell, Zone.s.BoundsOffstageRight, WithinMargin)
		and QueryZone(cell, Zone.s.BoundsOffstageLeft, WithinMargin)
end

local function IsInVerticalBounds(cell, margin)
	local WithinMargin = function(depth)
		return depth <= margin
	end
	return QueryZone(cell, Zone.s.BoundsBackground, WithinMargin)
		and QueryZone(cell, Zone.s.BoundsForeground, WithinMargin)
end

local function IsOutsidePerimeter(cell)
	local OFFSTAGE_ZONES = {	
		Zone.s.Foreground,
		Zone.s.Background,
		Zone.s.OffstageLeft,
		Zone.s.OffstageRight,
	}
	return Lume(OFFSTAGE_ZONES):any(function(zone) 
		return IsInZone(cell, zone, 1) 
	end):result()
end

local function IsFrontPerimeter(cell)
	return (IsStageForeground(cell, 1) or IsForeground(cell, 1))
		and IsInHorizontalBounds(cell, -1)
end

local function IsStage(cell)
	-- Can test any of the STAGE_ZONES for this.
	return IsInZone(cell, Zone.s.StageForeground) 
end

local function IsForegroundSide(cell)
	local WithinThree = function(depth) return 1 <= depth and depth <= 3 end
	local fg = QueryZone(cell, Zone.s.BoundsForeground, WithinThree)
	local left = QueryZone(cell, Zone.s.BoundsOffstageLeft, WithinThree)
	local right = QueryZone(cell, Zone.s.BoundsOffstageRight, WithinThree)
	return fg and (left or right)
end

local function IsVerticalInlet(cell)
	local left = IsInZone(cell, Zone.s.OffstageLeft)
	local right = IsInZone(cell, Zone.s.OffstageRight)
	return left and right and not cell.virtual
end

local function IsForegroundInlet(cell)
	return IsVerticalInlet(cell) and IsInZone(cell, Zone.s.Foreground)
end

local function IsBackgroundInlet(cell)
	return IsVerticalInlet(cell) and IsInZone(cell, Zone.s.Background)
end

local function IsSideInlet(cell)
	local fg = IsInZone(cell, Zone.s.Foreground)
	local bg = IsInZone(cell, Zone.s.Background)
	return fg and bg and not cell.virtual
end

-- Loosen the rules to be more inclusive.
local function IsPermissiveSideInlet(cell)
	return IsSideInlet(cell)
		or (IsInBounds(cell) and (IsForeground(cell) or IsBackground(cell)))
end

local function IsVirtualForegroundSide(cell)
	return IsForegroundSide(cell) and cell.virtual
end

local function IsActualForegroundSide(cell)
	return IsForegroundSide(cell) and not cell.virtual
end

local function IsExit(cell)
	return cell.exit 
end

local function IsOffscreen(cell)
	-- TODO @chrisp #proc_gen_grid - this is just a quick hack to reject many tiles but doesn't 
	-- accurately reflect which tiles are actually visible...do better math
	local OFFSCREEN_DEPTH = 5
	local FarSide = function(depth) return OFFSCREEN_DEPTH <= depth end
	return QueryZone(cell, Zone.s.BoundsOffstageLeft, FarSide)
		or QueryZone(cell, Zone.s.BoundsOffstageRight, FarSide)
end

local function IsCenter(cell)
	local function WithinOne(depth) return depth <= 1 end
	return QueryZone(cell, Zone.s.StageHorizontalCenter, WithinOne)
		and QueryZone(cell, Zone.s.StageVerticalCenter, WithinOne)
end

local function IsInsidePerimeter(cell)
	local STAGE_ZONES = {	
		Zone.s.StageForeground,
		Zone.s.StageBackground,
		Zone.s.StageLeft,
		Zone.s.StageRight,
	}	
	if Lume(STAGE_ZONES):any(function(zone) 
		return IsInZone(cell, zone, 1) 
	end):result()
	then
		return true
	end

	local in_horizontal_bounds = IsInHorizontalBounds(cell, 1)
	local in_vertical_bounds = IsInVerticalBounds(cell, 1)
	return (IsInZone(cell, Zone.s.Foreground, 1) and in_horizontal_bounds)
		or (IsInZone(cell, Zone.s.Background, 1) and in_horizontal_bounds)
		or (IsInZone(cell, Zone.s.OffstageRight, 1) and in_vertical_bounds)
		or (IsInZone(cell, Zone.s.OffstageLeft, 1) and in_vertical_bounds)
end

local EXIT_WIDTH = 2

-- For proc-gen zones, we require a minimum number of background and foreground rows of cells. If the authored 
-- tile_layer does not meet these requirements, we will inflate the grid and copy the authored data into the new
-- structure.
local REQUIRED_BG = 6
local REQUIRED_FG = 3

-- The local GridBuilder class does all the heavy computation. The public ZoneGrid class discards intermediate data
-- and presents a narrow API.
local GridBuilder = Class(function(self, original_tile_layer)
	TheSim:ProfilerPush("GridBuilder")
	local function Construct(tile_layer)
		self.tile_layer = tile_layer
		self.zone_grid = {
			width = tile_layer.width,
			height = tile_layer.height,
			cells = {}
		}

		-- Scan for exit tiles.
		-- Exits have a width of 2 tiles and can face any of the cardinal directions.
		-- Scan columns first.
		self.exit_columns = {}
		for x = 0, tile_layer.width - 1 do -- Left to right.
			local start_z, end_z
			local exit_column
			for z = tile_layer.height - 1, 0, -1 do -- Top to bottom.
				local layout_cell = tile_layer.data[TilEdGridToIndex(tile_layer, x, z)]

				-- Found an occupied tile. Start exit scan.
				if layout_cell ~= 0 and start_z == nil then
					start_z = z
				end

				-- Found an empty tile. End exit scan if one was in progress.
				if layout_cell == 0 and start_z ~= nil then
					end_z = z
				end

				-- Found a potential exit.
				if start_z ~= nil and end_z ~= nil then
					local width = start_z - end_z
					if width == EXIT_WIDTH then
						exit_column = {x = x, start_z = start_z - 1}
						table.insert(self.exit_columns, exit_column)
						break
					end
					start_z = nil
					end_z = nil
				end
			end
		end

		-- Scan rows next.
		self.exit_rows = {}
		for z = tile_layer.height - 1, 0, -1 do -- Top to bottom.
			local start_x, end_x
			local exit_row
			for x = 0, tile_layer.width - 1 do -- Left to right.
				local layout_cell = tile_layer.data[TilEdGridToIndex(tile_layer, x, z)]

				-- Found an occupied tile. Start exit scan.
				if layout_cell ~= 0 and start_x == nil then
					start_x = x
				end
				
				-- Found an empty tile. End exit scan if one was in progress.
				if layout_cell == 0 and start_x ~= nil then
					end_x = x
				end
				
				-- Found a potential exit.
				if start_x ~= nil and end_x ~= nil then
					local width = end_x - start_x
					if width == EXIT_WIDTH then
						exit_row = {start_x = start_x, z = z}
						table.insert(self.exit_rows, exit_row)
						break
					end
					start_x = nil
					end_x = nil
				end
			end
		end
	end

	Construct(original_tile_layer)

	-- Inflation of the grid is always symmetric with respect to foreground/background so as to keep the center of the
	-- layout the same.
	local inflation = 0
	for x = 0, original_tile_layer.width - 1 do -- Left to right.
		local z = original_tile_layer.height - 1 -- Top.
		local layout_cell = original_tile_layer.data[TilEdGridToIndex(original_tile_layer, x, z)]
		local bg_distance = 0
		local fg_distance = 0
		if layout_cell == 0 then
			fg_distance = self:DistanceToStage(Vec2.new(x, z), Vec2.new(0, 1))
			bg_distance = self:DistanceToStage(Vec2.new(x, z), Vec2.new(0, -1))
		end
		if fg_distance ~= nil then
			inflation = math.max(inflation, REQUIRED_FG - fg_distance)
		end
		if bg_distance ~= nil then
			inflation = math.max(inflation, REQUIRED_BG - bg_distance)
		end
	end
	if inflation ~= 0 then
		local proxy_tile_layer = {
			width = original_tile_layer.width,
			height = original_tile_layer.height + inflation * 2,
			data = {},
		}
		for x = 0, proxy_tile_layer.width - 1 do
			-- Zero out the new bg.
			for z = proxy_tile_layer.height - inflation, proxy_tile_layer.height - 1 do
				local index = TilEdGridToIndex(proxy_tile_layer, x, z)
				proxy_tile_layer.data[index] = 0
			end

			-- Zero out the new fg.
			for z = 0, inflation - 1 do
				local index = TilEdGridToIndex(proxy_tile_layer, x, z)
				proxy_tile_layer.data[index] = 0
			end

			-- Copy the original data.
			for z = 0, original_tile_layer.height - 1 do
				local i = TilEdGridToIndex(proxy_tile_layer, x, z + inflation)
				local j = TilEdGridToIndex(original_tile_layer, x, z)
				proxy_tile_layer.data[i] = original_tile_layer.data[j]
			end
		end
		Construct(proxy_tile_layer)
	end
	TheSim:ProfilerPop()
end)

function GridBuilder:GetTilEdCell(x, z)
	return self.tile_layer.data[TilEdGridToIndex(self.tile_layer, x, z)]
end

function GridBuilder:SetCell(x, z, value)
	self.zone_grid.cells[GridToIndex(self.tile_layer.width, x, z)] = value
end

function GridBuilder:ManifestCell(x, z)
	local index = GridToIndex(self.tile_layer.width, x, z)
	local cell = self.zone_grid.cells[index]
	if not cell then
		cell = {}
		self.zone_grid.cells[index] = cell
	end
	return cell
end

function GridBuilder:GetCell(x, z)
	return self.zone_grid.cells[GridToIndex(self.tile_layer.width, x, z)]
end

function GridBuilder:GridToIndex(x, z)
	return GridToIndex(self.tile_layer.width, x, z)
end

function GridBuilder:Build()
	TheSim:ProfilerPush("Build")

	local CellType = Enum { "offstage", "stage" }

	local function GetCellType(x, z)
		-- Treat exit cells as empty for grid computation.
		if self:IsExit(Vec2.new(x,z)) then
			return CellType.id.offstage
		end
		local TILED_EMPTY_TILE = 0
		if self:GetTilEdCell(x, z) == TILED_EMPTY_TILE then
			return CellType.id.offstage
		end
		return CellType.id.stage
	end

	TheSim:ProfilerPush("Column Scan")
	for x = 0, self.tile_layer.width - 1 do
		local start = 0
		local top_marker_distance
		while true do
			local scan = GetCellType(x, start)

			-- Scan up until we find a tile that doesn't match our scan.
			local found_marker = false
			for z = start, self.tile_layer.height - 1 do
				local cell_type = GetCellType(x, z)
				local cell = self:ManifestCell(x, z)
				if cell_type == scan then
					if top_marker_distance ~= nil then
						top_marker_distance = top_marker_distance + 1 -- Increase it.
						if scan == CellType.id.offstage then
							cell.Background = top_marker_distance      -- Mark how far offstage this cell is, i.e. how far to the stage.
						elseif scan == CellType.id.stage then
							cell.StageForeground = top_marker_distance      -- Mark how far on-stage this cell is, i.e. how far to the edge of the stage.
						else
							assert(false, "Unrecognized CellType variant")
						end
					end
				else
					found_marker = true

					-- Scan down, filling in distances.
					local bottom_marker_distance = 1
					for back_z = z - 1, start, -1 do
						local back_cell = self:ManifestCell(x, back_z)
						if scan == CellType.id.offstage then
							back_cell.Foreground = bottom_marker_distance      -- Mark how far offstage this cell is, i.e. how far to the stage.
						elseif scan == CellType.id.stage then
							back_cell.StageBackground = bottom_marker_distance      -- Mark how far on-stage this cell is, i.e. how far to the edge of the stage.
						else
							assert(false, "Unrecognized CellType variant")
						end
						bottom_marker_distance = bottom_marker_distance + 1
					end

					-- Move starting row.
					start = z

					-- We will have a left marker on our next upward scan.
					top_marker_distance = 0

					break
				end
			end

			if not found_marker then
				break
			end
		end
	end
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("Row Scan")
	for z = 0, self.tile_layer.height - 1 do
		local start = 0
		local left_marker_distance
		while true do
			local scan = GetCellType(start, z)

			-- Scan right until we find a tile that doesn't match our scan.
			local found_marker = false
			for x = start, self.tile_layer.width - 1 do
				local cell_type = GetCellType(x, z)
				local cell = self:ManifestCell(x, z)
				if cell_type == scan then
					if left_marker_distance ~= nil then
						left_marker_distance = left_marker_distance + 1 -- Increase it.
						if scan == CellType.id.offstage then
							cell.OffstageRight = left_marker_distance      -- Mark how far offstage this cell is, i.e. how far to the stage.
						elseif scan == CellType.id.stage then
							cell.StageLeft = left_marker_distance      -- Mark how far on-stage this cell is, i.e. how far to the edge of the stage.
						else
							assert(false, "Unrecognized CellType variant")
						end
					end
				else
					found_marker = true

					-- Scan left, filling in distances.
					local right_marker_distance = 0
					for back_x = x, start, -1 do
						local back_cell = self:ManifestCell(back_x, z)
						if right_marker_distance ~= 0 then
							if scan == CellType.id.offstage then
								back_cell.OffstageLeft = right_marker_distance      -- Mark how far offstage this cell is, i.e. how far to the stage.
							elseif scan == CellType.id.stage then
								back_cell.StageRight = right_marker_distance      -- Mark how far on-stage this cell is, i.e. how far to the edge of the stage.
							else
								assert(false, "Unrecognized CellType variant")
							end
						end
						right_marker_distance = right_marker_distance + 1
					end

					-- Move starting column.
					start = x

					-- We will have a left marker on our next rightward scan.
					left_marker_distance = 0

					break
				end
			end

			if not found_marker then
				break
			end
		end
	end
	TheSim:ProfilerPop()

	-- The second pass paints the tiles that cannot see any part of the stage, using the data of the decor cells that can.
	local zone_grid = self.zone_grid
	local function IsVirtual(cell) 
		return not (cell[Zone.s.Background] 
					or cell[Zone.s.Foreground] 
					or cell[Zone.s.OffstageLeft] 
					or cell[Zone.s.OffstageRight]
					or cell[Zone.s.StageBackground] 
					or cell[Zone.s.StageForeground] 
					or cell[Zone.s.StageLeft] 
					or cell[Zone.s.StageRight])
	end
	TheSim:ProfilerPush("Virtual Rows")
	for z = 0, self.tile_layer.height - 1 do
		local parent
		local children = {}
		for x = 0, self.tile_layer.width - 1 do
			local cell = zone_grid.cells[self:GridToIndex(x, z)]
			if IsVirtual(cell) then
				table.insert(children, cell)
			elseif not parent then
				parent = cell
			end
		end
		for _, child in ipairs(children) do
			-- Virtual cells are second-class data. I.e. if a virtual cell is 1 unit left of the stage it is not
			-- 1 unit left of the physical stage, but instead 1 unit left of the stage image swept vertically.
			-- This distinction will be useful when delineating logical zones.
			child.virtual = true
			child[Zone.s.Background] = parent[Zone.s.Background]
			child[Zone.s.Foreground] = parent[Zone.s.Foreground]
		end
	end
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("Virtual Columns")
	for x = 0, self.tile_layer.width - 1 do
		local parent
		local children = {}
		for z = 0, self.tile_layer.height - 1 do
			local cell = zone_grid.cells[self:GridToIndex(x, z)]
			if IsVirtual(cell) then
				table.insert(children, cell)
			elseif not parent then
				parent = cell
			end
		end
		for _, child in ipairs(children) do
			-- Virtual cells are second-class data. I.e. if a virtual cell is 1 unit left of the stage it is not
			-- 1 unit left of the physical stage, but instead 1 unit left of the stage image swept vertically.
			-- This distinction will be useful when delineating logical zones.
			child.virtual = true
			child[Zone.s.OffstageLeft] = parent[Zone.s.OffstageLeft]
			child[Zone.s.OffstageRight] = parent[Zone.s.OffstageRight]
		end
	end
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("Holes")
	-- Offstage cells that are left, right, fg, and bg are holes
	for x = 0, self.tile_layer.width - 1 do -- Left to right.
		for z = self.tile_layer.height - 1, 0, -1 do -- Top to bottom.
			local i = self:GridToIndex(x, z)
			local cell = zone_grid.cells[i]
			if IsLeft(cell) and IsRight(cell) and IsForeground(cell) and IsBackground(cell) then
				cell.Background = nil
				cell.Foreground = nil
				cell.OffstageLeft = nil
				cell.OffstageRight = nil
				cell.StageBackground = nil
				cell.StageForeground = nil
				cell.StageLeft = nil
				cell.StageRight = nil
			end
		end
	end
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("Exits")
	-- Mark the stage cells next to exits as exits.
	for _, exit_column in ipairs(self.exit_columns) do
		for z = exit_column.start_z, exit_column.start_z + EXIT_WIDTH - 1 do
			zone_grid.cells[self:GridToIndex(exit_column.x, z)].exit = true
			local candidates = {exit_column.x - 1,  exit_column.x + 1}
			for _, candidate in ipairs(candidates) do
				local cell = zone_grid.cells[self:GridToIndex(candidate, z)]
				if IsStage(cell) then
					cell.exit = true
				end
			end
		end
	end
	for _, exit_row in ipairs(self.exit_rows) do
		for x = exit_row.start_x, exit_row.start_x + EXIT_WIDTH - 1 do
			zone_grid.cells[self:GridToIndex(x, exit_row.z)].exit = true
			local candidates = {exit_row.z - 1, exit_row.z + 1}
			for _, candidate in ipairs(candidates) do
				local cell = zone_grid.cells[self:GridToIndex(x, candidate)]
				if IsStage(cell) then
					cell.exit = true
				end
			end
		end
	end
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("Center")
	-- Mark stage cells with their distance from the "center". The ideal center of a stage is a point where it is
	-- the same distance from the left and right edges, and the same distance from the top and bottom edges.
	for x = 0, self.tile_layer.width - 1 do -- Left to right.
		for z = self.tile_layer.height - 1, 0, -1 do -- Top to bottom.
			local i = self:GridToIndex( x, z)
			local cell = zone_grid.cells[i]
			if cell.StageLeft and cell.StageRight then
				cell.StageHorizontalCenter =  math.abs(cell.StageLeft - cell.StageRight)
			end
			if cell.StageForeground and cell.StageBackground then
				cell.StageVerticalCenter = math.abs(cell.StageForeground - cell.StageBackground)
			end
		end
	end
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("Bounds")
	-- Bounds.
	self.bounds = {
		min = { x = self.tile_layer.width - 1, z = self.tile_layer.height - 1},
		max = { x = 0, z = 0 },
	}
	for x = 0, self.tile_layer.width - 1 do
		for z = 0, self.tile_layer.height - 1 do
			local layout_cell = self:GetTilEdCell(x, z)
			if layout_cell ~= 0 and not self:IsExit({x=x, y=z}) then
				if x < self.bounds.min.x then
					self.bounds.min.x = x
				end
				if self.bounds.max.x < x then
					self.bounds.max.x = x
				end
				if z < self.bounds.min.z then
					self.bounds.min.z = z
				end
				if self.bounds.max.z < z then
					self.bounds.max.z = z
				end
			end
		end
	end

	-- TODO @chrisp #proc_gen - seems a bit silly to write such simple computations into the cells, but it's more
	-- convenient when we are just passing the cells around as values and we have effectively erased their position.
	for x = 0, self.tile_layer.width - 1 do
		for z = 0, self.tile_layer.height - 1 do
			local cell_index = self:GridToIndex(x, z)
			local cell = zone_grid.cells[cell_index]
			-- If all of these are non-positive, then the cell is within the layout bounds.
			cell.BoundsForeground = self.bounds.min.z - z
			cell.BoundsBackground = z - self.bounds.max.z
			cell.BoundsOffstageLeft = self.bounds.min.x - x
			cell.BoundsOffstageRight = x - self.bounds.max.x
		end
	end
	TheSim:ProfilerPop()

	TheSim:ProfilerPush("Walkability")
	-- Walkability: 3 or more corners are walkable
	for x = 0, self.tile_layer.width - 1 do
		for z = 0, self.tile_layer.height - 1 do
			local cell_index = self:GridToIndex(x, z)
			local cell = zone_grid.cells[cell_index]
			local world_center = GridToWorld(self.tile_layer.width, self.tile_layer.height, {x=x, z=z})
			local HALF_TILE_WIDTH = WORLD_TILE_SIZE / 2 * 0.9
			local HALF_TILE_HEIGHT = WORLD_TILE_SIZE / 2 * 0.9
			local walkable_corner_count = 0
			if TheWorld.Map:IsWalkableAtXZ(world_center.x - HALF_TILE_WIDTH, world_center.z - HALF_TILE_HEIGHT) then
				walkable_corner_count = walkable_corner_count + 1
			end
			if TheWorld.Map:IsWalkableAtXZ(world_center.x - HALF_TILE_WIDTH, world_center.z + HALF_TILE_HEIGHT) then
				walkable_corner_count = walkable_corner_count + 1
			end
			if TheWorld.Map:IsWalkableAtXZ(world_center.x + HALF_TILE_WIDTH, world_center.z - HALF_TILE_HEIGHT) then
				walkable_corner_count = walkable_corner_count + 1
			end
			if TheWorld.Map:IsWalkableAtXZ(world_center.x + HALF_TILE_WIDTH, world_center.z + HALF_TILE_HEIGHT) then
				walkable_corner_count = walkable_corner_count + 1
			end
			cell.walkable = 3 <= walkable_corner_count
		end
	end

	-- Mark cells that are adjacent to non-walkable stage cells.
	for x = 0, self.tile_layer.width - 1 do
		for z = 0, self.tile_layer.height - 1 do
			local cell_index = self:GridToIndex(x, z)
			local cell = zone_grid.cells[cell_index]
			if IsStage(cell) and not cell.walkable then
				local function MarkNeighbor(neighbor_x, neighbor_z)
					local neighbor = zone_grid.cells[self:GridToIndex(neighbor_x, neighbor_z)]
					if neighbor and not IsStage(neighbor) then
						neighbor.adjacent_to_non_walkable_stage = true
					end
				end
				MarkNeighbor(x - 1, z)
				MarkNeighbor(x + 1, z)
				MarkNeighbor(x, z - 1)
				MarkNeighbor(x, z + 1)
			end
		end
	end
	TheSim:ProfilerPop()

	TheSim:ProfilerPop()
end

-- Asserts from does not satisfy predicate.
function GridBuilder:DistanceTo(from, delta, predicate)
	assert(not predicate(self:GetTilEdCell( from.x, from.y)))
	local current = from + delta
	local distance_checked = 1
	local found = false
	while 0 <= current.x and current.x < self.tile_layer.width and 0 <= current.y and current.y < self.tile_layer.height do
		local layout_cell = self:GetTilEdCell( current.x, current.y)

		-- Treat exit cells as empty for grid computation.
		if self:IsExit(current) then
			layout_cell = 0
		end
		
		if predicate(layout_cell) then
			found = true
			break
		else
			distance_checked = distance_checked + 1
		end
		current = current + delta
	end
	return (found and distance_checked) or nil
end

-- Asserts from is not a stage location.
function GridBuilder:DistanceToStage(from, delta)
	return self:DistanceTo(from, delta, function(layout_cell) return layout_cell ~= 0 end)
end

-- Asserts from is a stage location.
function GridBuilder:DistanceToOffstage(from, delta)	
	if self:IsExit(from) then
		return nil -- Exit cells don't register as onstage.
	else
		return self:DistanceTo(from, delta, function(layout_cell) return layout_cell == 0 end)
	end
end

-- Scan in the direction specified by the delta until a valid cell is found and return it. Return nil otherwise.
function GridBuilder:InheritFromOther(zone, from, delta)
	local current = from + delta
	while 0 <= current.x and current.x < self.zone_grid.width and 0 <= current.y and current.y < self.zone_grid.height do
		local cell = self.zone_grid.cells[self:GridToIndex( current.x, current.y)]
		if cell[zone] then
			return cell[zone]
		end
		current = current + delta
	end
end

-- Only true for exit tiles extending into empty space.
function GridBuilder:IsExit(position)
	return Lume(self.exit_columns):any(function(exit_column)
			local delta = position.y - exit_column.start_z
			return position.x == exit_column.x and 0 <= delta and delta < EXIT_WIDTH
		end):result()
		or Lume(self.exit_rows):any(function(exit_row)		
			local delta = position.x - exit_row.start_x
			return position.y == exit_row.z and 0 <= delta and delta < EXIT_WIDTH
		end):result()
end


local function IsNonWalkable(cell)
	return (IsStage(cell) and not cell.walkable)
		or cell.adjacent_to_non_walkable_stage
		-- NOTE @chrisp #proc_gen - Elaine wants these corners excluded
		-- or (ZoneGrid.IsSide(cell, 1) and ZoneGrid.IsForeground(cell, 1))
		-- or (ZoneGrid.IsSide(cell, 1) and ZoneGrid.IsBackground(cell, 1))
end

local function IsNonWalkableBgImpl(cell)
	return (IsBackground(cell, 1)
		or IsStageBackground(cell, 1)
		or IsStageBackground(cell, 2))
end


local function IsNonWalkableFg(cell)
	return IsNonWalkable(cell) and not IsNonWalkableBgImpl(cell)
end

local function IsNonWalkableBg(cell)
	return IsNonWalkable(cell) and IsNonWalkableBgImpl(cell)
end
-- Map elements of the prop_proc_gen.Zone enum to functions that test a cell for zone membership.
local cell_filters = {
	[PropProcGen.Zone.s.near_bg] = function(cell)
		return IsBackground(cell, 1)
			and not IsExit(cell)
			and not IsSideInlet(cell)
	end,
	[PropProcGen.Zone.s.bg] = function(cell)
		return IsBackground(cell) 
			and not IsSideInlet(cell)
			and not IsBackground(cell, 1)
			and (IsInBounds(cell)
					or IsBoundsBackground(cell, 1) 
					or IsBoundsBackground(cell, 2) 
					or IsBoundsBackground(cell, 3))
	end,
	[PropProcGen.Zone.s.distant_bg] = function(cell)
		return IsBoundsBackground(cell, 4)
	end,
	[PropProcGen.Zone.s.near_fg] = function(cell)
		return not cell.virtual
			and IsForeground(cell, 1)
			and not IsSideInlet(cell)
	end,
	[PropProcGen.Zone.s.fg] = function(cell)
		return not cell.virtual
			and IsForeground(cell)
			and not IsSideInlet(cell)
			and not IsForeground(cell, 1)
			and (IsInBounds(cell)
					or IsBoundsForeground(cell, 1)
					or IsBoundsForeground(cell, 2))
	end,
	[PropProcGen.Zone.s.distant_fg] = function(cell)
		return IsBoundsForeground(cell, 3)
			and not (IsLeftForeground(cell) or IsRightForeground(cell))
	end,
	[PropProcGen.Zone.s.fg_side] = IsForegroundSide,
	[PropProcGen.Zone.s.near_side] = function(cell) 
		return (IsLeft(cell, 1) or IsRight(cell, 1))
			and not (IsBackground(cell) or IsForeground(cell))
	end,
	[PropProcGen.Zone.s.side] = function(cell) 
		return not cell.virtual
			and IsSide(cell)
			and not IsSide(cell, 1)
			and (IsInBounds(cell)
					or IsBoundsSide(cell, 1)
					or IsBoundsSide(cell, 2))
			and not (IsBackground(cell) or IsForeground(cell))
	end,
	[PropProcGen.Zone.s.distant_side] = function(cell)
		return (IsBoundsLeft(cell, 3) or IsBoundsRight(cell, 3) or IsBoundsLeft(cell, 4) or IsBoundsRight(cell, 4))
			and not (IsBackground(cell) or IsForeground(cell))
	end,
	[PropProcGen.Zone.s.inside_perimeter] = function(cell)
		return IsInsidePerimeter(cell) and not IsFrontPerimeter(cell)
	end,
	[PropProcGen.Zone.s.middle] = function(cell)
		return IsStage(cell) and not IsInsidePerimeter(cell)
	end,
	[PropProcGen.Zone.s.back_corner] = function(cell)
		return IsStageSide(cell, 1) and IsStageBackground(cell, 1)
	end,
	[PropProcGen.Zone.s.exit] = IsExit,
	[PropProcGen.Zone.s.front_perimeter] = function(cell)
		return (IsStageForeground(cell, 1) or IsForeground(cell, 1))
			and IsInHorizontalBounds(cell, -1)
	end,
	[PropProcGen.Zone.s.center] = IsCenter,
	[PropProcGen.Zone.s.near_underlay] = function(cell)
		return IsBoundsBackground(cell, 5)
	end,
	[PropProcGen.Zone.s.underlay] = function(cell)
		return IsBoundsBackground(cell, 6)
	end,
	[PropProcGen.Zone.s.non_walkable_fg] = IsNonWalkableFg,
	[PropProcGen.Zone.s.non_walkable_bg] = IsNonWalkableBg,
	[PropProcGen.Zone.s.side_inlet] = function(cell)
		return IsSideInlet(cell)
			or (IsInBounds(cell) and IsForeground(cell) and IsBackground(cell))
	end,
	[PropProcGen.Zone.s.side_inlet_two] = function(_) return false end,
}

-- ZoneGrid publishes a number of local functions that are used by GridBuilder, but tries to keep to a narrow API.
local ZoneGrid = Class(function(self, map_layout)
	TheSim:ProfilerPush("ZoneGrid")
	local grid_builder = GridBuilder(map_layout:GetGroundLayer())
	grid_builder:Build()
	-- Take ownership of grid_builder.zone_grid.
	for key, value in pairs(grid_builder.zone_grid) do
		self[key] = value
	end
	self.tile_layer = grid_builder.tile_layer
	self.zone_layer = map_layout:GetZonesLayer()

	local from_tile_group = TheWorld.layout.tilesets[1].name
	local to_tile_group = TheSceneGen
		and TheSceneGen.components.scenegen.tile_group
		or from_tile_group
	self.tile_id_resolver = TileIdResolver(
		self.tile_layer.data, 
		from_tile_group, 
		to_tile_group
	)

	-- This enumeration orders the ZoneTiles as they appear in the tile set in TilEd.
	local ZoneTiles = Enum {
		PropProcGen.Zone.s.near_bg,
		PropProcGen.Zone.s.bg,
		PropProcGen.Zone.s.distant_bg,	
		PropProcGen.Zone.s.near_side,
		PropProcGen.Zone.s.side,
		PropProcGen.Zone.s.distant_side,
		PropProcGen.Zone.s.fg_side,
		PropProcGen.Zone.s.near_fg,	
		PropProcGen.Zone.s.fg,
		PropProcGen.Zone.s.distant_fg,
		PropProcGen.Zone.s.near_underlay,
		PropProcGen.Zone.s.underlay,
		PropProcGen.Zone.s.front_perimeter,		
		PropProcGen.Zone.s.inside_perimeter,
		PropProcGen.Zone.s.middle,
		PropProcGen.Zone.s.exit,
		PropProcGen.Zone.s.side_inlet,
		PropProcGen.Zone.s.side_inlet_two,
	}

	-- Remap cell_filters to a new set of predicates that test grid coordinates for zone membership.
	self.position_filters = Lume(cell_filters):enumerate(function(_, zone_cell_filter)
		return function(x, z)
			return self:QueryCell(x, z, zone_cell_filter)
		end
	end):result()

	-- If we have a zone layer, overwrite some position_filters.	
	if self.zone_layer then
		local tile_index_offset = map_layout:GetZonesTileSetIndexOffset()
		for i, zone in ipairs(ZoneTiles:Ordered()) do
			self.position_filters[zone] = function(x, z)
				local tile_index = self:TilEdGridToIndex(x, z)
				return self.zone_layer.data[tile_index] == i + tile_index_offset
			end
		end
	end

	TheSim:ProfilerPop()
end)

ZoneGrid.WORLD_TILE_SIZE = WORLD_TILE_SIZE

function ZoneGrid:TilEdGridToIndex(x,z)
	return TilEdGridToIndex(self, x, z)
end

function ZoneGrid:GridToIndex(x, z)
	return GridToIndex(self.width, x, z)
end

function ZoneGrid:IndexToGrid(index)
	return IndexToGrid(self.width, index)
end

function ZoneGrid:WorldToGrid(world_position)
	return WorldToGrid(self.width, self.height, world_position)
end

function ZoneGrid:GridToWorld(grid_position)
	return GridToWorld(self.width, self.height, grid_position)
end

function ZoneGrid:ForEachCell(VisitCell)
	for x = 0, self.width - 1 do
		for z = 0, self.height - 1 do
			VisitCell(self.cells[self:GridToIndex(x, z)], x, z)
		end
	end
end

function ZoneGrid:ForEachCellInZone(zone, VisitCell)
	self:ForEachCell(function(cell, x, z)
		if self.position_filters[zone](x, z) then
			VisitCell(cell, x, z)
		end
	end)
end

function ZoneGrid:GetTilEdTile(x, z)
	local tile_index = self:TilEdGridToIndex(x, z)
	if self.tile_layer.data[tile_index] ~= 0 then
		local _, tile_name = self.tile_id_resolver:IndexToId(tile_index)
		return GroundTiles.Tiles[tile_name], tile_name
	end
end

function ZoneGrid:GetOverhang(x, z)
	local tile, _name = self:GetTilEdTile(x, z)
	return tile and tile.overhang or 0
end

-- Return the bounds of the tile at the specified grid coordinates that encompass offstage area.
-- Entirely offstage tiles will return their entire area; entirely on-stage tiles will return nil. 
-- Tiles on the perimeter take into account the visual space occupying approximately half of those tiles.
-- Input unit are grid coordinates; output units are world coordinates
function ZoneGrid:GetOffstageBounds(x, z)
	local cell = self.cells[self:GridToIndex(x, z)]
	if IsStage(cell) then
		return nil
	end

	local bounds = self:GetTileBounds(x, z)
	if cell.virtual then
		return bounds
	end

	local function _IsExit(_x, _z)
		if _x < 0 or self.width <= _x then
			return false
		end
		if _z < 0 or self.height <= _z then
			return false
		end
		return IsExit(self.cells[self:GridToIndex(_x, _z)]) 
	end

	if IsLeft(cell, 1) or _IsExit(x + 1, z) then
		bounds.max.x = bounds.max.x - self:GetOverhang(x + 1, z)
	end
	if IsRight(cell, 1) or _IsExit(x - 1, z) then
		bounds.min.x = bounds.min.x + self:GetOverhang(x - 1, z)	
	end
	if IsBackground(cell, 1) or _IsExit(x, z - 1) then
		bounds.min.y = bounds.min.y + self:GetOverhang(x, z - 1)
	end
	if IsForeground(cell, 1) or _IsExit(x, z + 1)  then
		bounds.max.y = bounds.max.y - self:GetOverhang(x, z + 1)
	end

	return bounds
end

function ZoneGrid:GetStageBounds(x, z)
	local cell = self.cells[self:GridToIndex(x, z)]
	local bounds = self:GetTileBounds(x, z)
	
	if IsStage(cell) then
		return bounds
	end

	if not IsOutsidePerimeter(cell) then
		return nil
	end

	if IsLeft(cell, 1) then
		bounds.min.x = bounds.min.x + WORLD_TILE_SIZE - self:GetOverhang(x + 1, z)
	end
	if IsRight(cell, 1) then
		bounds.max.x = bounds.max.x - WORLD_TILE_SIZE + self:GetOverhang(x - 1, z)	
	end
	if IsBackground(cell, 1) then
		bounds.max.y = bounds.max.y - WORLD_TILE_SIZE + self:GetOverhang(x, z - 1)
	end
	if IsForeground(cell, 1) then		
		bounds.min.y = bounds.min.y + WORLD_TILE_SIZE - self:GetOverhang(x, z + 1)
	end
	
	return bounds
end

-- Logical tile bounds, without regards for visually occupied space.
function ZoneGrid:GetTileBounds(x, z)
	local bounds = Bound2(Vec2(-HALF_TILE, -HALF_TILE), Vec2(HALF_TILE, HALF_TILE))
	local world_position = self:GridToWorld({x=x, z=z})
	return bounds:offset({x=world_position.x, y=world_position.z})
end

-- Given the world position, return the tile at that location, taking overhangs into consideration.
function ZoneGrid:GetTile(world_position)
	local grid_position = self:WorldToGrid(world_position)
	if not grid_position then
		return nil
	end

	local tile, tile_name = self:GetTilEdTile(grid_position.x, grid_position.z)

	-- In world coordinates
	local tile_center = self:GridToWorld(grid_position)

	-- In coordinates with the tile center as the origin.
	local position = {
		x = world_position.x - tile_center.x,
		z = world_position.z - tile_center.z,
	}

	local neighbors = {}

	-- east
	local east, east_name = self:GetTilEdTile(grid_position.x + 1, grid_position.z)
	table.insert(neighbors, {
		tile = east,
		name = east_name,
		IsOnOverhang = function() return position.x > (HALF_TILE - east.overhang) end
	})
	
	-- west
	local west, west_name = self:GetTilEdTile(grid_position.x - 1, grid_position.z)
	table.insert(neighbors, {
		tile = west,
		name = west_name,
		IsOnOverhang = function() return position.x < (-HALF_TILE + west.overhang) end
	})
		
	-- south
	local south, south_name = self:GetTilEdTile(grid_position.x, grid_position.z - 1)
	table.insert(neighbors, {
		tile = south,
		name = south_name,
		IsOnOverhang = function() return position.z < (-HALF_TILE + south.overhang) end
	})
		
	-- north
	local north, north_name = self:GetTilEdTile(grid_position.x, grid_position.z + 1)
	table.insert(neighbors, {
		tile = north,
		name = north_name,
		IsOnOverhang = function() return position.z > (HALF_TILE - north.overhang) end
	})

	-- se
	local se, se_name = self:GetTilEdTile(grid_position.x + 1, grid_position.z - 1)
	table.insert(neighbors, {
		tile = se,
		name = se_name,
		IsOnOverhang = function()
			return position.x > (HALF_TILE - se.overhang)
				and position.z < (-HALF_TILE + se.overhang) 
		end
	})

	-- sw
	local sw, sw_name = self:GetTilEdTile(grid_position.x - 1, grid_position.z - 1)
	table.insert(neighbors, {
		tile = sw,
		name = sw_name,
		IsOnOverhang = function()
			return position.x < (-HALF_TILE + sw.overhang)
				and position.z < (-HALF_TILE + sw.overhang) 
		end
	})

	-- ne
	local ne, ne_name = self:GetTilEdTile(grid_position.x + 1, grid_position.z + 1)
	table.insert(neighbors, {
		tile = ne,
		name = ne_name,
		IsOnOverhang = function()
			return position.x > (HALF_TILE - ne.overhang)
				and position.z > (HALF_TILE - ne.overhang)
		end
	})

	-- nw
	local nw, nw_name = self:GetTilEdTile(grid_position.x - 1, grid_position.z + 1)
	table.insert(neighbors, {
		tile = nw,
		name = nw_name,
		IsOnOverhang = function()
			return position.x < (-HALF_TILE + nw.overhang)
				and position.z > (HALF_TILE - nw.overhang)
		end
	})

	-- Order as per GroundTiles.lua such that topmost tiles appear earlier in the list.
	neighbors = Lume(neighbors)
		:filter(function(neighbor) return neighbor.tile end) -- on grid
		:filter(function(neighbor) return neighbor.tile ~= tile end) -- different from user tile
		:filter(function(neighbor) return not tile or neighbor.tile.order < tile.order end) -- on top of user tile
		:sort(function(a, b) return a.tile.order < b.tile.order end)
		:result()

	-- Return the first tile that is on top of the user tile AND whose overhang contains the point.
	-- Fall through if no neighbors satisfy this.
	for _, neighbor in ipairs(neighbors) do
		if neighbor.IsOnOverhang() then
			return neighbor.tile, neighbor.name
		end
	end

	return tile, tile_name
end

function ZoneGrid.CellInfo(cell)
	local info = ""
	for _, zone in ipairs(Zone:Ordered()) do
		if cell[zone] ~= nil then
			info = info .. zone .. "(" .. cell[zone] .. ")\n"
		end
	end
	return info
end

-- If the cell at (x,z) is not offscreen and is not an exit and satisfies the predicate, return true.
-- Otherwise return false.
function ZoneGrid:QueryCell(x, z, predicate)
	local i = self:GridToIndex(x, z)
	local cell = self.cells[i];
	if IsOffscreen(cell) then
		return false
	end
	if IsExit(cell) then
		return false
	end
	return predicate(cell)
end

return ZoneGrid
