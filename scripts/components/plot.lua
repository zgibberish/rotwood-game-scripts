local fmodtable = require "defs.sound.fmodtable"
local audioid = require "defs.sound.audioid"
local ParticleSystemHelper = require "util.particlesystemhelper"

local Plot = Class(function(self, inst)
	self.inst = inst
	self.building = nil
	self.spawn_flag = nil
	self.npc_prefab = nil
	self.range = 0

	self.inst:ListenForEvent("startplacing", function(_, placer) self:OnStartPlacing(placer) end, TheWorld)
	self.inst:ListenForEvent("stopplacing", function() self:OnStopPlacing() end, TheWorld)
end)

function Plot:OnStartPlacing(placer)
	if self:IsOccupied() or not placer.components.placer.isbuilding then
		return
	end

    local fx = SpawnPrefab("fx_low_health_ring")
    assert(fx)
    local x, y, z = self.inst.Transform:GetWorldPosition()
    fx.Transform:SetPosition(x, y, z)
    fx.Transform:SetScale(1.5, 1.5, 1.5)
    fx.AnimState:PlayAnimation("pre_large")
    fx.AnimState:PushAnimation("loop_large", true)

    self.mark_fx = fx
end

function Plot:OnStopPlacing()
	if self.mark_fx then
		self.mark_fx:Remove()
		self.mark_fx = nil
	end
end

function Plot:IsOccupied()
	return self.building ~= nil
end

function Plot:SetBuildingPrefab(prefab)
	self.building_prefab = prefab
end

function Plot:SetSpawnFlag(flag)
	if flag and string.len(flag) > 0 then
		self.spawn_flag = flag
	end
end

function Plot:SetNPCPrefab(prefab)
	self.npc_prefab = prefab
end

function Plot:OnPostLoadWorld()
	if self.spawn_flag and TheWorld:IsFlagUnlocked(self.spawn_flag) and TheNet:IsHost() and not self:IsOccupied() then
		self:SpawnBuilding(true, true)
	end
end

function Plot:SpawnBuilding(spawn_npc, silent)
	local building = SpawnPrefab(self.building_prefab)

	if not building then
		assert(false, string.format("[%s] tried to spawn building [%s] but failed", self.inst, self.building_prefab))
	end

	local x, z = self.inst.Transform:GetWorldXZ()
	building.components.snaptogrid:MoveToNearestGridPos(x,0,z, true)

	if spawn_npc and self.npc_prefab then
		local npc = SpawnPrefab(self.npc_prefab)
		building.components.npchome:AddNpc(npc)
		-- ParticleSystemHelper.MakeOneShot(building, "building_upgrade", nil, 1)
	end

	self:SetBuilding(building, silent)
end

function Plot:SetBuilding(building, silent)
	self.building = building
	self.inst:ListenForEvent("onremove",
		function()
				self:RemoveBuilding()
				building.SoundEmitter:PlaySound(fmodtable.Event.remove_constructable)
		end,
		self.building)


	if not silent then
		building.SoundEmitter:PlaySound(fmodtable.Event.place_building)
		TheFrontEnd:GetSound():PlaySound(fmodtable.Event.Mus_miscStinger)
	end

	self.inst:Hide()
end

function Plot:RemoveBuilding()
	self.building = nil
	ParticleSystemHelper.MakeOneShot(self.inst, "building_upgrade", nil, 1)
	self.inst:Show()
	--sound
end

function Plot:HasBuilding()
	return self.building ~= nil
end

function Plot:OnSave()
	if self:IsOccupied() then
		return { building_data = self.building:GetPersistData() }
	end
end

function Plot:OnLoad(data)
	if data and data.building_data and TheNet:IsHost() then
		self:SpawnBuilding(false, true)
		self.building:SetPersistData(data.building_data)
	end
end

return Plot
