local DebugDraw = require "util.debugdraw"
local Vector3 = require "math.modules.vec3"

local SnapGrid = Class(function(self, inst)
	self.inst = inst
	self.cellsize = 1
	self.grid = {}

	self._onstartplacing = function()
		self:SetDrawGridEnabled(true)
	end

	self._onstopplacing = function()
		self:SetDrawGridEnabled(false)
	end

	self.inst:ListenForEvent("startplacing", self._onstartplacing, TheWorld)
	self.inst:ListenForEvent("stopplacing", self._onstopplacing, TheWorld)

end)

function SnapGrid:GetCellSize()
	return self.cellsize
end

function SnapGrid:GetCellId(row, col, level)
	dbassert(row >= -256 and row < 256)
	dbassert(col >= -256 and col < 256)
	dbassert(level >= -256 and level < 256)
	return ((level + 256) << 18) | ((row + 256) << 9) | (col + 256)
end

function SnapGrid:GetRowColFromCellId(cellid)
	return ((cellid >> 9) & 511) - 256, (cellid & 511) - 256, (cellid >> 18) - 256
end

-- oddw and oddh stand for odd width and odd height respectively. Objects with odd widths and heights will not have
-- their respective coordinate in world space snapped to the grid.
function SnapGrid:SnapToGrid(x, z, oddw, oddh)
	local function SnapCoordinate(world_coord, odd)
		local grid_coord, new_world_coord
		if world_coord < 0 then
			grid_coord = math.ceil((world_coord - 0.5) / self.cellsize)
			new_world_coord = (grid_coord + odd * 0.5) * self.cellsize
		else
			grid_coord = math.floor((world_coord + 0.5) / self.cellsize)
			new_world_coord = (grid_coord + odd * -0.5) * self.cellsize
		end
		return grid_coord, new_world_coord
	end
	local grid_x, new_world_x = SnapCoordinate(x, oddw)
	local grid_z, new_world_z = SnapCoordinate(z, oddh)
	return new_world_x, new_world_z, grid_z, grid_x
end

function SnapGrid:GetRowColSpan(row, col, width, height)
	return row - math.floor(height / 2) --row1
		, col - math.floor(width / 2) --col1
		, row + math.floor((height - 1) / 2) --row2
		, col + math.floor((width - 1) / 2) --col2
end

function SnapGrid:Set(cellid, ent)
	local cell = self.grid[cellid]
	if cell == nil then
		self.grid[cellid] = { [ent] = true }
	else
		cell[ent] = true
	end
end

function SnapGrid:Clear(cellid, ent)
	local cell = self.grid[cellid]
	if cell ~= nil then
		cell[ent] = nil
		if next(cell) == nil then
			self.grid[cellid] = nil
		end
	end
end

--TODO: move this logic to the placer
function SnapGrid:IsClear(cellid, ent)
	local cell = self.grid[cellid]
	if cell ~= nil then
		for k in pairs(cell) do
			if k ~= ent then
				if k.prefab == "plot" or (k.entity and k:HasTag('placer')) then
					return true
				end
				return false
			end
		end
	end
	return true
end

function SnapGrid:GetEntitiesInCell(cellid)
	local ents = {}
	local cell = self.grid[cellid]
	
	if cell ~= nil then
		for k in pairs(cell) do
			table.insert(ents, k)
		end
	end

	return ents
end

function SnapGrid:GetEntityInCell(cellid)
	local ents = self:GetEntitiesInCell(cellid)
	return ents[1]
end

function SnapGrid:SetDebugDrawEnabled(enable)
	if enable then
		if not self.drawgrid and not self.debugdraw then
			self.inst:StartWallUpdatingComponent(self)
		end
		self.debugdraw = true
	else
		self.debugdraw = false
		if not self.drawgrid and not self.debugdraw then
			self.inst:StopWallUpdatingComponent(self)
		end
	end
end

function SnapGrid:SetDrawGridEnabled(enable)
	if enable then
		if not self.drawgrid and not self.debugdraw then
			self.inst:StartWallUpdatingComponent(self)
		end
		self.drawgrid = true
	else
		self.drawgrid = false
		if not self.drawgrid and not self.debugdraw then
			self.inst:StopWallUpdatingComponent(self)
		end
	end
end

function SnapGrid:_DrawWorldGridForDebugEntity()
	local ent = GetDebugEntity()
	local snaptarget = ent and ent.components.snaptogrid
	if not snaptarget then
		self:SetDebugDrawEnabled(false)
		return
	end
	local cellsize = self:GetCellSize()
	local bound = 15 * cellsize
	local x_start, z_start = self:SnapToGrid(0, 0, snaptarget.oddw, snaptarget.oddh)
	local odd = Vector3(snaptarget.oddw, 0, snaptarget.oddh) * 0.5
	local centre = Vector3(x_start, 0, z_start)
	local offset = Vector3(bound, 0, bound)
	local first = centre - offset - odd
	local last = centre + offset + odd

	local color = shallowcopy(WEBCOLORS.LAVENDER)
	color[4] = 0.2
	for z=first.z, last.z, cellsize do
		local a = first:clone()
		local b = last:clone()
		a.z = z
		b.z = z
		DebugDraw.GroundLine_Vec(a, b, color)
	end
	for x=first.x, last.x, cellsize do
		local a = first:clone()
		local b = last:clone()
		a.x = x
		b.x = x
		DebugDraw.GroundLine_Vec(a, b, color)
	end
end

function SnapGrid:_DrawWorldGrid()
	local cellsize = self:GetCellSize()

	local x_bound = 100 * cellsize
	local z_bound = 60 * cellsize

	local x_start, z_start = self:SnapToGrid(0, 0, 1, 1)
	local odd = Vector3(1, 0, 1) * 0.5
	local centre = Vector3(x_start, 0, z_start)
	local offset = Vector3(x_bound, 0, z_bound)
	local first = centre - offset - odd
	local last = centre + offset + odd

	local color = shallowcopy(WEBCOLORS.LAVENDER)
	color[4] = 0.2
	for z=first.z, last.z, cellsize do
		local a = first:clone()
		local b = last:clone()
		a.z = z
		b.z = z
		DebugDraw.GroundLine_Vec(a, b, color)
	end
	for x=first.x, last.x, cellsize do
		local a = first:clone()
		local b = last:clone()
		a.x = x
		b.x = x
		DebugDraw.GroundLine_Vec(a, b, color)
	end
end

function SnapGrid:OnWallUpdate()
	if self.debugdraw then
		self:_DrawWorldGridForDebugEntity()
	end

	if self.drawgrid then
		self:_DrawWorldGrid()
	end
end

return SnapGrid
