local NpcHome = Class(function(self, inst)
	self.inst = inst
	self.npcs = {}
	self.spawnxoffs = 0
	self.spawnzoffs = 0

	self._ononremove = function(source) self:RemoveNpc(source) end
end)

function NpcHome:OnRemoveFromEntity()
	for _, npc in pairs(self.npcs) do
		assert(npc:IsValid())
		self.inst:RemoveEventCallback("onremove", self._ononremove, npc)
		npc.components.npc:SetHome(nil)
	end
	self.npcs = {}
end

function NpcHome:OnRemoveEntity()
	self:OnRemoveFromEntity()
end

function NpcHome:SetSpawnXZOffset(x, z)
	self.spawnxoffs = x
	self.spawnzoffs = z
end

function NpcHome:GetSpawnXZ(npc)
	if self.spawn_pos_fn then
		return self.spawn_pos_fn(self.inst, npc)
	else
		local x, z = self.inst.Transform:GetWorldXZ()
		return x + self.spawnxoffs, z + self.spawnzoffs
	end
end

function NpcHome:SetSpawnPosFn(fn)
	self.spawn_pos_fn = fn
end

function NpcHome:AddNpc(npc)
	if not self:HasNpc(npc) then
		self.inst:ListenForEvent("onremove", self._ononremove, npc)
		self.npcs[npc.prefab] = npc
		npc.components.npc:SetHome(self.inst)
		local x, z = self:GetSpawnXZ(npc)
		npc.Transform:SetPosition(x, 0, z)
	end
end

function NpcHome:RemoveNpc(npc)
	if self.npcs[npc.prefab] then
		self.inst:RemoveEventCallback("onremove", self._ononremove, npc)
		self.npcs[npc.prefab] = nil
		npc.components.npc:SetHome(nil)
	end
end

function NpcHome:GetNpcs()
	return self.npcs
end

function NpcHome:HasNpc(npc)
	return self.npcs[npc.prefab]
end

function NpcHome:HasNpcByName(npc_name)
return self.npcs[npc_name]
end

function NpcHome:HasAnyNpcs()
	return table.count(self.npcs) > 0
end

function NpcHome:OnSave()
	if self:HasAnyNpcs() then
		local npcs = {}
		for name, npc in pairs(self.npcs) do
			table.insert(npcs, { name = name, data = npc:GetPersistData() })
		end
		return { npcs = npcs }
	end
end

function NpcHome:OnLoad(data)
	if data.npcs ~= nil and table.count(data.npcs) > 0 then
		for _, npcdata in ipairs(data.npcs) do
			if not self:HasNpcByName(npcdata.name) then
				local npc = SpawnPrefab(npcdata.name, self.inst)
				if npc ~= nil then
					npc:SetPersistData(npcdata.data)
					self:AddNpc(npc)
					npc.Transform:SetRotation(math.random(360))
				end
			end
		end
	end
end

return NpcHome
