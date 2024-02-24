local SnapToGrid  = require "components.snaptogrid"

local SnapToGridProxy = Class( function(self, gridsize)	
	self.snap_to_grid = SnapToGrid({
		components = {
			placer = {}
		},
		Transform = {
			SetPosition = function(_, _, _, _) end
		}
	})
	self.snap_to_grid:SetDimensions(gridsize[1].w, gridsize[1].h)
end)

-- Try to place the prop on our proxy snapgrid. If it succeeds, placement may be modified to the snapped position.
-- Return true if the prop is placed, false otherwise.
function SnapToGridProxy:Place(placement)
	local snap_x, snap_z, row, column = TheWorld.components.snapgrid:SnapToGrid(placement.x, placement.z, self.snap_to_grid.oddw, self.snap_to_grid.oddh)
	if self.snap_to_grid:IsGridClearAt(row, column) then
		local resnap_x, _snap_y, resnap_z = self.snap_to_grid:SetNearestGridPos(placement.x, 0, placement.z, false)
		if snap_x == resnap_x and snap_z == resnap_z then
			placement.x = snap_x
			placement.z = snap_z
			return true
		end
	end
	return false
end

function SnapToGridProxy:CanPlace(placement)
	local _, _, row, column = TheWorld.components.snapgrid:SnapToGrid(placement.x, placement.z, self.snap_to_grid.oddw, self.snap_to_grid.oddh)
	return self.snap_to_grid:IsGridClearAt(row, column)
end

return SnapToGridProxy
