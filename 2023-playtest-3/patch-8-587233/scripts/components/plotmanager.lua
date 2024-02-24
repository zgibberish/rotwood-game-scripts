local PlotManager = Class(function(self, inst)
	self.inst = inst
	self.plots = {}
end)

function PlotManager:RegisterPlot(plot, owner_prefab, building_prefab)
	self.plots[owner_prefab] = { inst = plot, building_prefab = building_prefab}
end

function PlotManager:IsPlotOccupied(npc_prefab)
	assert(self.plots[npc_prefab])
	
	local plot = self.plots[npc_prefab].inst
	return plot.components.plot:HasBuilding()
end

return PlotManager
