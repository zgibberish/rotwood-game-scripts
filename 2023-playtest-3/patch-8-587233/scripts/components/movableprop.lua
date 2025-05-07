local MovableProp = Class(function(self, inst)
	self.inst = inst
end)

function MovableProp:StartMove(player)
	local function on_cancel(placer, placed_ent)
		self.inst:ReturnToScene()
	end

	local function on_success(placer, placed_ent)
		local data = self.inst:GetSaveRecord()
		self.inst:Remove()
		placed_ent:SetPersistData(data)
	end

	self.inst:RemoveFromScene()
	player.components.playercontroller:StartPlacer(self.inst.prefab.."_placer", nil, on_success, on_cancel)
end

return MovableProp