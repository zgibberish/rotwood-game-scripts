local function CreateLayer()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")
	inst.persists = false

	return inst
end

local PendingBuild = Class(function(self, inst)
	self.inst = inst

	self.on_success_fn = nil
	self.on_fail_fn = nil

	self.flip = nil
end)

function PendingBuild:FlipPendingBuild()
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
			local xp, yp, zp = child.Transform:GetLocalPosition()
			child.Transform:SetPosition(xp * -1, yp, zp)
		end
	end
end

function PendingBuild:SetParams(params)
	self.params = params

	if params.variations then
		self.variation = 1
	end

	self:UpdateVisuals()
end

function PendingBuild:SetVariation(num)
	self.variation = num
	self:UpdateVisuals()
end

function PendingBuild:UpdateVisuals()
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
				ent.AnimState:SetMultColor(0.6, 0.6, 0.6, 0.5)
			end
		end
	end
end

function PendingBuild:SetUpPendingBuild(success_fn, fail_fn)
	self.on_success_fn = success_fn
	self.on_fail_fn = fail_fn
end

function PendingBuild:OnSuccess()
	if self.on_success_fn then
		self.on_success_fn()
	end

	local x, z = self.inst.Transform:GetWorldXZ()
	local fx = SpawnPrefab("fx_dust_ground_ring")
	fx.Transform:SetPosition(x, 0, z)

	self.inst:Remove()
end

function PendingBuild:OnFail()
	if self.on_fail_fn then
		self.on_fail_fn()
	end

	local x, z = self.inst.Transform:GetWorldXZ()
	local fx = SpawnPrefab("fx_dust_pickup_up")
	fx.Transform:SetPosition(x, 0, z)

	self.inst:Remove()
end

function PendingBuild:SetPlacedPrefab(name)
	self.placed_prefab = name
end

return PendingBuild