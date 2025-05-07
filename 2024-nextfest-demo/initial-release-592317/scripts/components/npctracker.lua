local function OnRegisterNpc(inst, data)
	inst.components.npctracker:RegisterNpc(data.npc, data.role)
end

local function OnUnregisterNpc(inst, data)
	inst.components.npctracker:UnregisterNpc(data.npc)
end

local NpcTracker = Class(function(self, inst)
	self.inst = inst
	self.npcs = {}

	self._onremovenpc = function(npc) self:UnregisterNpc(npc) end

	inst:ListenForEvent("registernpc", OnRegisterNpc)
	inst:ListenForEvent("unregisternpc", OnUnregisterNpc)
end)

function NpcTracker:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("registernpc", OnRegisterNpc)
	self.inst:RemoveEventCallback("unregisternpc", OnUnregisterNpc)
	for npc in pairs(self.npcs) do
		self.inst:RemoveEventCallback("onremove", self._onremovenpc, npc)
	end
end

function NpcTracker:RegisterNpc(npc, job)
	job = job or ""

	if self.npcs[npc] ~= job then
		if self.npcs[npc] == nil then
			self.inst:ListenForEvent("onremove", self._onremovenpc, npc)
		end
		self.npcs[npc] = job
	end
end

function NpcTracker:UnregisterNpc(npc)
	if self.npcs[npc] ~= nil then
		self.inst:PushEvent("npc_unregistered", {role = self.npcs[npc]})
		self.npcs[npc] = nil
		self.inst:RemoveEventCallback("onremove", self._onremovenpc, npc)
	end
end

function NpcTracker:HasAnyNpcWithJob(job)
	for npc, job1 in pairs(self.npcs) do
		if job1 == job then
			return true
		end
	end
	return false
end

function NpcTracker:GetJobForNpc(npc)
	return self.npcs[npc]
end

function NpcTracker:GetDebugString()
	local str = ""
	for npc, job in pairs(self.npcs) do
		str = str.."\n\t["..(npc.prefab).."]: "..job
	end
	return str
end

return NpcTracker