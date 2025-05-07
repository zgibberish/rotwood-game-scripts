local function CreateLayer()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	inst.persists = false

	return inst
end

local Placer = Class(function(self, inst)
	self.inst = inst
	self.placed_prefab = nil
	self.validatefn = nil
	self.onplacefn = nil
	self.oncancelfn = nil
	self.hasplaced = false

	self.flip = nil

	self.inst:AddTag('placer')

	inst:StartWallUpdatingComponent(self)
	self:OnWallUpdate(0)
end)

function Placer:FlipPlacer()
	self.flip = not self.flip or nil
	local xscale = self.flip and -1 or 1
	if self.inst.AnimState ~= nil then
		self.inst.AnimState:SetScale(xscale, 1)
	end
	if self.inst.highlightchildren ~= nil then
		for i = 1, #self.inst.highlightchildren do
			local child = self.inst.highlightchildren[i]
			if child.AnimState ~= nil then
				child.AnimState:SetScale(xscale, 1)
			end
			-- local xp, yp, zp = child.Transform:GetLocalPosition()
			-- child.Transform:SetPosition(xp * -1, yp, zp)
		end
	end
end

function Placer:SetParams(params)
	self.params = params

	if params.variations then
		self.variation = 1
	end

	self:UpdateVisuals()
end

function Placer:AdvanceVariation()
	if not self.params.variations then
		self.variation = nil
		return
	end

	self.variation = self.variation + 1

	if self.variation > self.params.variations then
		self.variation = 1
	end

	self:UpdateVisuals()
end

function Placer:UpdateVisuals()
	local params = self.params

	if params.parallax ~= nil then

		if self.inst.highlightchildren then
			for _, child in ipairs(self.inst.highlightchildren) do
				child:Remove()
			end
		end

		local bank = params.bank or self.placed_prefab
		local build = params.build or self.placed_prefab
		local variation = self.variation or ""

		for i = 1, #params.parallax do
			local layerparams = params.parallax[i]
			if layerparams.anim ~= nil then
				local ent
				if layerparams.dist == nil or layerparams.dist == 0 then
					ent = self.inst
				else
					ent = CreateLayer()
					ent.entity:SetParent(self.inst.entity)
					ent.Transform:SetPosition(0, 0, layerparams.dist)

					if self.inst.highlightchildren == nil then
						self.inst.highlightchildren = { ent }
					else
						self.inst.highlightchildren[#self.inst.highlightchildren + 1] = ent
					end
				end

				ent.AnimState:SetBank(bank)
				ent.AnimState:SetBuild(build)
				ent.AnimState:SetPercent(layerparams.anim..variation, 0)

			end
		end
	end
end

function Placer:OnRemoveEntity()
	if self.oncancelfn ~= nil then
		self.oncancelfn(self.inst)
	end
end

function Placer:OnRemoveFromEntity()
	self:OnRemoveEntity()
end

function Placer:SetPlacedPrefab(name)
	self.placed_prefab = name
end

function Placer:SetValidateFn(fn)
	self.validatefn = fn
end

function Placer:SetOnPlaceFn(fn)
	self.onplacefn = fn
end

function Placer:SetOnCancelFn(fn)
	self.oncancelfn = fn
end

function Placer:HasPlaced()
	return self.hasplaced
end

function Placer:GetPlotInCells()
	local ents = self.inst.components.snaptogrid:GetEntitiesInCells()
	for _, ent in ipairs(ents) do
		-- TODO: check for a tag instead
		if ent.prefab == "plot" then
			return ent
		end
	end
end

function Placer:GetPlotInPos(x, z)
	local snapgrid = TheWorld.components.snapgrid
	local x1,z1, row, col = snapgrid:SnapToGrid(x, z, 1,1)
	local cellid = snapgrid:GetCellId(row, col, 0)
	local ents = snapgrid:GetEntitiesInCell(cellid)

	for _, ent in ipairs(ents) do
		-- TODO: check for a tag instead
		if ent.prefab == "plot" then
			return ent
		end
	end	
end

function Placer:CanPlace()
	if self.inst.components.snaptogrid ~= nil then
		if self.isbuilding then
			local plot = self:GetPlotInCells()
			if plot ~= nil and not plot.components.plot:IsOccupied() then
				return true
			end
			return false
		else
		 	return self.inst.components.snaptogrid:IsGridClearForCells()
		end
	end

	return true
end

function Placer:OnPlace()
	if self.validatefn ~= nil then
		if not self.validatefn(self.inst, self.placed_prefab) then
			return false
		end
	end

	self.hasplaced = true

	local pending_build = SpawnPrefab(self.placed_prefab.."_pending", self.inst)
	if pending_build ~= nil then
		local x, z = self.inst.Transform:GetWorldXZ()
		if pending_build.components.snaptogrid ~= nil then

			if self.isbuilding then
				local plot = self:GetPlotInCells()
				if plot and not plot.components.plot:IsOccupied() then
					x,z = plot.Transform:GetWorldXZ()
				end
			end

			--We can force the grid position if we know the placer already snaps to grid
			local alreadysnapped = self.inst.components.snaptogrid ~= nil
			pending_build.components.snaptogrid:SetNearestGridPos(x, 0, z, alreadysnapped)
		else
			pending_build.Transform:SetPosition(x, 0, z)
		end

		if self.flip then
			pending_build.components.pendingbuild:FlipPendingBuild()
		end

		if self.variation then
			pending_build.components.pendingbuild:SetVariation(self.variation)
		end
	end

	local function on_success()
		local ent = SpawnPrefab(self.placed_prefab, self.inst)
		if ent ~= nil then
			local x, z = pending_build.Transform:GetWorldXZ()
			if ent.components.snaptogrid ~= nil then
				--We can force the grid position if we know the placer already snaps to grid
				local alreadysnapped = self.inst.components.snaptogrid ~= nil
				ent.components.snaptogrid:SetNearestGridPos(x, 0, z, alreadysnapped)
			else
				ent.Transform:SetPosition(x, 0, z)
			end
		end

		if pending_build.components.pendingbuild.flip then
			ent.components.prop:FlipProp()
		end

		if pending_build.components.pendingbuild.variation then
			ent.components.prop:SetVariationOverride(pending_build.components.pendingbuild.variation)
		end

		if self.onplacefn ~= nil then
			self.onplacefn(self.inst, ent)
		end
	end

	pending_build.components.pendingbuild:SetUpPendingBuild(on_success, nil)
	pending_build:DoTaskInTime(1, function()
		local is_valid = true

		if self.validatefn ~= nil then
			is_valid = self.validatefn(self.inst, self.placed_prefab)
		end

		if pending_build.components.snaptogrid:IsGridClearForCells() and is_valid then
			pending_build.components.pendingbuild:OnSuccess()
		else
			pending_build.components.pendingbuild:OnFail()
		end
	end)

	return true
end

function Placer:OnWallUpdate(dt)
	-- TODO: someone - support gamepad for non-developer features like home/building placement
	local x, z = TheInput:GetWorldXZWithHeight(1)
	x = x or 0
	z = z or 0
	
	if self.inst.components.snaptogrid ~= nil then
		if self.isbuilding then
			local plot = self:GetPlotInPos(x, z)
			if plot and not plot.components.plot:IsOccupied() then
				x,z = plot.Transform:GetWorldXZ()
			end
		end

		self.inst.components.snaptogrid:MoveToNearestGridPos(x, 0, z, false)
	else
		self.inst.Transform:SetPosition(x, 0, z)
	end
end

return Placer
