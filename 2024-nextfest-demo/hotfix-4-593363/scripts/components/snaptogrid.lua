local DebugDraw = require "util.debugdraw"
require "util.pool"


local offsets_tbl_pool = SimpleTablePool()
local SEARCH_DIST = 8

local SnapToGrid = Class(function(self, inst)
	self.inst = inst
	self.levels = {}
	self.cells = {}
	self.oddw = nil
	self.oddh = nil
	self.place_anywhere = nil

	self._onstartplacing = function() self:SetDrawGridEnabled(true)  end
	self._onstopplacing  = function() self:SetDrawGridEnabled(false) end

	if self.inst.components.placer == nil then -- The placer is handled by playercontroller.lua
		self.inst:ListenForEvent("startplacing", self._onstartplacing, TheWorld)
		self.inst:ListenForEvent("stopplacing", self._onstopplacing, TheWorld)
	end
end)

function SnapToGrid:OnRemoveEntity()
	self:ClearCells()
end

-- Set dimensions this object occupies in the world grid. Other objects cannot
-- be placed in this object's occupied cells. level is an abstract vertical
-- height; see uses for different levels.
-- Use negative level for things that don't block, but should snap to grid.
function SnapToGrid:SetDimensions(width, height, level, expand)
	level = level or 0

	if self.oddw == nil then
		self.oddw = width & 1
		self.oddh = height & 1
	else
		-- Even or odd dimensions must be consistent across levels because we
		-- use dimensions to determine movmeent increments.
		assert(
			self.oddw == (width & 1) and self.oddh == (height & 1),
			"Choose even or odd grid sizes for your object. All layers must match to ensure movement increments are compatible across layers.")
	end

	local t = self.levels[level]
	if t == nil then
		self.levels[level] = { w = width, h = height, expand = expand }
	else
		t.w = width
		t.h = height
		t.expand = expand
	end
end

function SnapToGrid:SetPlaceAnywhere(place_anywhere)
	self.place_anywhere = place_anywhere
end

function SnapToGrid:ClearCells()
	if not TheWorld then -- can happen with dev reload and nosimreset
		return
	end

	local snapgrid = TheWorld.components.snapgrid
	for i = 1, #self.cells do
		snapgrid:Clear(self.cells[i], self.inst)
		self.cells[i] = nil
	end
end

function SnapToGrid:DisableCells()
	local snapgrid = TheWorld.components.snapgrid
	self.backup_cells = {}

	for i = 1, #self.cells do
		self.backup_cells[i] = self.cells[i]
		snapgrid:Clear(self.cells[i], self.inst)
		self.cells[i] = nil
	end
end

function SnapToGrid:EnableCells()
	assert(self.backup_cells)

	local snapgrid = TheWorld.components.snapgrid
	for i = 1, #self.cells do
		self.cells[i] = self.backup_cells[i]
		snapgrid:Set(self.cells[i], self.inst)
	end

	self.backup_cells = nil
end

function SnapToGrid:ResolveRowColSpan(row, col, width, height, expand)
	local snapgrid = TheWorld.components.snapgrid
	local row1, col1, row2, col2 = snapgrid:GetRowColSpan(row, col, width, height)
	if expand ~= nil then
		row1 = row1 - (expand.bottom or 0)
		col1 = col1 - (expand.left or 0)
		row2 = row2 + (expand.top or 0)
		col2 = col2 + (expand.right or 0)
	end
	return row1, col1, row2, col2
end

function SnapToGrid:IsGridClearAt(row, col)
	local snapgrid = TheWorld.components.snapgrid
	local cellsize = snapgrid:GetCellSize()
	for level, t in pairs(self.levels) do
		local row1, col1, row2, col2 = self:ResolveRowColSpan(row, col, t.w, t.h, t.expand)
		for row3 = row1, row2 do
			for col3 = col1, col2 do
				local cellid = snapgrid:GetCellId(row3, col3, level)
				if not snapgrid:IsClear(cellid, self.inst) then
					return false
				end
				local x = (col3 + .5) * cellsize
				local z = (row3 + .5) * cellsize
				if not TheWorld.Map:IsGroundAtXZ(x, z) and not self.place_anywhere then
					return false
				end
			end
		end
	end
	return true
end

function SnapToGrid:IsGridClearForCells()
	local snapgrid = TheWorld.components.snapgrid
	local cellsize = snapgrid:GetCellSize()
	for i = 1, #self.cells do
		local cellid = self.cells[i]
		if not snapgrid:IsClear(cellid, self.inst) then
			return false
		end
		local row, col = snapgrid:GetRowColFromCellId(cellid)
		local x = (col + .5) * cellsize
		local z = (row + .5) * cellsize
		if not TheWorld.Map:IsGroundAtXZ(x, z) and not self.place_anywhere then
			return false
		end
	end
	return true
end

function SnapToGrid:GetEntitiesInCells()
	local snapgrid = TheWorld.components.snapgrid
	local ents = {}
	for i = 1, #self.cells do
		local cellid = self.cells[i]
		local newents = snapgrid:GetEntitiesInCell(cellid)
		table.appendarrays(ents, newents)
	end

	return ents
end

local function PackPosition(world_x, world_z, grid_x, grid_z)
	return {
		world = { x = world_x, z = world_z },
		grid = { x = grid_x, z = grid_z }
	}
end

local function UnpackPosition(position)
	return position.world.x, position.world.z, position.grid.x, position.grid.z
end

-- Search for closest spot starting at destination and searching outwards
-- 'force' means to force the specified position regardless of whether it is clear or not.
function SnapToGrid:FindNearestValidGridPos(x, y, z, force)
	local position = PackPosition(TheWorld.components.snapgrid:SnapToGrid(x, z, self.oddw, self.oddh))
	if force then -- 'force' means to force the specified position regardless of whether it is clear or not.
		return UnpackPosition(position)
	elseif self:IsGridClearAt(position.grid.x, position.grid.z) then
		return UnpackPosition(position)
	else
		return UnpackPosition(self:_FindNearestValidGridPos(position))
	end
end

-- Search in square pattern of increasing dist (aka size)
function SnapToGrid:_FindNearestValidGridPos(position)
	local offsets = offsets_tbl_pool:Get()
	local clear_position
	-- TODO @chrisp #snap - would like to better describe what 'dist' and 'i' are here...
	for dist = 1, SEARCH_DIST do
		for i = 0, dist do
			local offset_count = self:ComputeOffsets(offsets, dist, i)
			clear_position = self:FindValidGridPosFromOffsets(offsets, offset_count, position)
			table.clear(offsets) -- Reset offsets table
			if clear_position then
				break
			end
		end
	end
	offsets_tbl_pool:Recycle(offsets)
	return clear_position
end

-- Collect all equal distance offsets. Return the number of offsets filled in with values.
function SnapToGrid:ComputeOffsets(offsets, dist, i)
	offsets[1], offsets[2] = dist, i
	offsets[3], offsets[4] = -dist, i
	local count = 4
	if i > 0 then
		offsets[5], offsets[6] = dist, -i
		offsets[7], offsets[8] = -dist, -i
		count = 8
	end
	if i < dist then
		offsets[count + 1], offsets[count + 2] = i, dist
		offsets[count + 3], offsets[count + 4] = i, -dist
		count = count + 4
		if i > 0 then
			offsets[count + 1], offsets[count + 2] = -i, dist
			offsets[count + 3], offsets[count + 4] = -i, -dist
			count = count + 4
		end
	end
	return count
end

-- Try offsets in random order. Return a position if a valid one is found, nil otherwise.
function SnapToGrid:FindValidGridPosFromOffsets(offsets, offset_count, position)
	local snapgrid = TheWorld.components.snapgrid
	while offset_count > 0 do
		local rnd = math.random(offset_count >> 1) << 1
		local offsrow, offscol = offsets[rnd - 1], offsets[rnd]

		if self:IsGridClearAt(position.grid.x + offsrow, position.grid.z + offscol) then
			local cellsize = snapgrid:GetCellSize()
			--Snap again to update position.grid.
			return PackPosition(snapgrid:SnapToGrid(
				position.world.x + offscol * cellsize,
				position.world.z + offsrow * cellsize,
				self.oddw,
				self.oddh
			))
		end

		offsets[rnd - 1], offsets[rnd] = offsets[offset_count - 1], offsets[offset_count]
		offsets[offset_count - 1], offsets[offset_count] = nil, nil
		offset_count = offset_count - 2
	end
end

function SnapToGrid:SetNearestGridPos(x, y, z, force)
	local x1, z1, row1, col1 = self:FindNearestValidGridPos(x, y, z, force)

	self:ClearCells()
	self:SetCellsInternal(row1, col1)

	self.inst.Transform:SetPosition(x1, 0, z1)
	return x1, 0, z1
end

-- Search for closest spot toward destination, starting from our current position.
-- 'force' means to use the specified position regardless of the grid status.
function SnapToGrid:MoveToNearestGridPos(x, y, z, force)
	local to_position = PackPosition(TheWorld.components.snapgrid:SnapToGrid(x, z, self.oddw, self.oddh))

	local nearest_position

	-- 'force' means to use the specified position regardless of the grid status.
	if force then
		nearest_position = to_position
	elseif self:IsGridClearAt(to_position.grid.x, to_position.grid.z) then
		nearest_position = to_position
	else
		nearest_position = self:_MoveToNearestGridPos(to_position.grid)
	end

	self:ClearCells()
	self:SetCellsInternal(nearest_position.grid.x, nearest_position.grid.z)

	self.inst.Transform:SetPosition(nearest_position.world.x, 0, nearest_position.world.z)
	return nearest_position.world.x, 0, nearest_position.world.z
end

-- Mutate 'position' as we move it towards 'to_grid_position' along the X-axis.
function SnapToGrid:MoveToNearestGridPosAlongXAxis(position, to_grid_position)
	local sign = position.grid.x > to_grid_position.x and -1 or 1
	if not self:IsGridClearAt(position.grid.x + sign, position.grid.z) then
		return false
	end
	position.grid.x = position.grid.x + sign
	position.world.z = position.world.z + sign * TheWorld.components.snapgrid:GetCellSize()
	return true
end

-- Mutate 'position' as we move it towards 'to_grid_position' along the Z-axis.
function SnapToGrid:MoveToNearestGridPosAlongZAxis(position, to_grid_position)
	local sign = position.grid.z > to_grid_position.z and -1 or 1
	if not self:IsGridClearAt(position.grid.x, position.grid.z + sign) then
		return false
	end
	position.grid.z = position.grid.z + sign
	position.world.x = position.world.x + sign * TheWorld.components.snapgrid:GetCellSize()
	return true
end

function SnapToGrid:_MoveToNearestGridPos(to_grid_position)
	local snapgrid = TheWorld.components.snapgrid
	local x, z = self.inst.Transform:GetWorldXZ()
	local position = PackPosition(snapgrid:SnapToGrid(x, z, self.oddw, self.oddh))

	local is_start_position_clear = self:IsGridClearAt(position.grid.x, position.grid.z)
	-- dbassert(is_start_position_clear, "How curious, to not be able to occupy the position we are at...")
	if not is_start_position_clear then
		return position
	end

	-- Maximum number of moves needed is the manhattan distance between the start and end grid positions.
	local manhattan_distance = math.abs(position.grid.x - to_grid_position.x) + math.abs(position.grid.z - to_grid_position.z)
	for _ = 1, manhattan_distance do
		local moved = false

		--Try moving on the farther axis first
		if math.abs(position.grid.x - to_grid_position.x) > math.abs(position.grid.z - to_grid_position.z) then
			if self:MoveToNearestGridPosAlongXAxis(position, to_grid_position) then
				moved = true
			end
		elseif position.grid.z ~= to_grid_position.z then
			if self:MoveToNearestGridPosAlongZAxis(position, to_grid_position) then
				moved = true
			end
		end

		--Try moving on the shorter axis second
		if not moved then
			if math.abs(position.grid.x - to_grid_position.x) <= math.abs(position.grid.z - to_grid_position.z) then
				if position.grid.x ~= to_grid_position.x then
					if self:MoveToNearestGridPosAlongXAxis(position, to_grid_position) then
						moved = true
					end
				end
			elseif position.grid.z ~= to_grid_position.z then
				if self:MoveToNearestGridPosAlongZAxis(position, to_grid_position) then
					moved = true
				end
			end

			if not moved then
				break
			end
		end
	end

	-- Snap again just in case
	return PackPosition(snapgrid:SnapToGrid(position.world.x, position.world.z, self.oddw, self.oddh))
end

function SnapToGrid:SetCellsInternal(row1, col1)
	local snapgrid = TheWorld.components.snapgrid
	for level, t in pairs(self.levels) do
		local row1a, col1a, row1b, col1b = self:ResolveRowColSpan(row1, col1, t.w, t.h, t.expand)
		for row = row1a, row1b do
			for col = col1a, col1b do
				local cellid = snapgrid:GetCellId(row, col, level)
				self.cells[#self.cells + 1] = cellid
				snapgrid:Set(cellid, self.inst)
			end
		end
	end
end

function SnapToGrid:OnSave()
	--Force saving so we always trigger OnLoad
	return true
end

function SnapToGrid:OnLoad(data)
	local x, y, z = self.inst.Transform:GetWorldPosition()
	self:SetNearestGridPos(x, y, z, true)
end

function SnapToGrid:_OnStartWallUpdating()
	local layout = TheWorld.map_layout.layout
	self.layout_odd_w = layout and ((layout.width & 1) ~= 0) or false
	self.layout_odd_h = layout and ((layout.height & 1) ~= 0) or false
end

--------------------------------------------------------------------------

function SnapToGrid:SetDebugDrawEnabled(enable)
	if enable then
		if not self.drawgrid and not self.debugdraw then
			self.inst:StartWallUpdatingComponent(self)
			self:_OnStartWallUpdating()
		end
		self.debugdraw = true
	else
		self.debugdraw = false
		if not self.drawgrid and not self.debugdraw then
			self.inst:StopWallUpdatingComponent(self)
		end
	end
end

function SnapToGrid:SetDrawGridEnabled(enable, color)
	if enable then
		if not self.drawgrid and not self.debugdraw then
			self.inst:StartWallUpdatingComponent(self)
			self:_OnStartWallUpdating()
		end
		self.drawgrid = true
		self.gridcolor = color or RGB(255,255,255,255)
	else
		self.drawgrid = false
		if not self.drawgrid and not self.debugdraw then
			self.inst:StopWallUpdatingComponent(self)
		end
	end
end

local function AlwaysTrue()
	return true
end

local function FloorOnly(t, row, col, level)
	return level == 0
end

function SnapToGrid:_DrawOccupiedGridBounds(pred)
	pred = pred or AlwaysTrue
	local bounds = {}
	local snapgrid = TheWorld.components.snapgrid
	for i = 1, #self.cells do
		local row, col, level = snapgrid:GetRowColFromCellId(self.cells[i])
		local t = bounds[level]
		if pred(t, row, col, level) then
			if t == nil then
				bounds[level] = { row = { min = row, max = row }, col = { min = col, max = col } }
			else
				t.row.min = math.min(row, t.row.min)
				t.row.max = math.max(row, t.row.max)
				t.col.min = math.min(col, t.col.min)
				t.col.max = math.max(col, t.col.max)
			end
		end
	end

	local cellsize = snapgrid:GetCellSize()
	for level, t in pairs(bounds) do
		local x1 = t.col.min * cellsize
		local z1 = t.row.min * cellsize
		local x2 = (t.col.max + 1) * cellsize
		local z2 = (t.row.max + 1) * cellsize
		DebugDraw.GroundRect(x1, z1, x2, z2)
	end
end

function SnapToGrid:OnWallUpdate()
	if self.debugdraw then
		self:_DrawOccupiedGridBounds()
	end

	if self.drawgrid then
		self:_DrawOccupiedGridBounds(FloorOnly)
	end
end

--------------------------------------------------------------------------

return SnapToGrid
