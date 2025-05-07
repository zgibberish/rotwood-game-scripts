local lume = require "util.lume"
local monsterutil = require "util.monsterutil"

local PeriodicSpawner = Class(function(self, inst)
	self.inst = inst

	self.spawn_cooldown = 10
	self.max_banked_spawns = 3
	self.max_total_spawns = 6
	self.spawns_available = 3

	self._tracked_spawns = {}

	self._on_spawn_death = function(source, data)
		self:_OnSpawnDeath(source)
	end
end)

function PeriodicSpawner:GetNumCurrentSpawns()
	return lume.count(self._tracked_spawns)
end

function PeriodicSpawner:CanSpawn()
	return self.spawns_available > 0 and self:GetNumCurrentSpawns() < self.max_total_spawns
end

function PeriodicSpawner:DoSpawn(prefab, angle)
	local spawn = SpawnPrefab(prefab, self.inst)
	spawn.Physics:StartPassingThroughObjects()
	local x, y, z = self.inst.Transform:GetWorldPosition()
	z = z + 1
	spawn.Transform:SetPosition(x, y, z)
	spawn.Transform:SetRotation(angle)

	spawn:AddComponent("spawnfader")
	spawn:PushEvent("spawn_battlefield", { spawner = self.inst, dir = angle })

	if spawn.components.powermanager then
		spawn.components.powermanager:CopyPowersFrom(self.inst)
	end

	if self.inst:HasTag("playerminion") and self.inst.summoner then
		monsterutil.CharmMonster(spawn, self.inst.summoner)
	else
		if spawn.components.combat then
			spawn.components.combat:SetTarget(spawn:GetClosestEntityByTagInRange(100, spawn.components.combat:GetTargetTags(), true))
		end
	end

	self.spawns_available = self.spawns_available - 1

	self:_StartTrackingSpawn(spawn)
	self:_StartCooldown()
end

function PeriodicSpawner:SetCooldown(time)
	self.spawn_cooldown = time
end

function PeriodicSpawner:SetMaxBankedSpawns(count)
	self.max_banked_spawns = count
end

function PeriodicSpawner:GetSpawnsAvailable(count)
	return self.spawns_available
end

function PeriodicSpawner:SetSpawnsAvailable(count)
	self.spawns_available = count
end

--------------------------------------------

function PeriodicSpawner:_OnSpawnDeath(spawn)
	self:_StopTrackingSpawn(spawn)
	self:_StartCooldown()
end

function PeriodicSpawner:_StartTrackingSpawn(spawn)
	self._tracked_spawns[spawn] = spawn
	self.inst:ListenForEvent("death", self._on_spawn_death, spawn)
	self.inst:ListenForEvent("onremove", self._on_spawn_death, spawn)
end

function PeriodicSpawner:_StopTrackingSpawn(spawn)
	self._tracked_spawns[spawn] = nil

	self.inst:RemoveEventCallback("death", self._on_spawn_death, spawn)
	self.inst:RemoveEventCallback("onremove", self._on_spawn_death, spawn)
end

function PeriodicSpawner:_AddSpawn()
	self.spawns_available = self.spawns_available + 1
	self:_StartCooldown()
end

function PeriodicSpawner:_StartCooldown()
	if not self.cooldown_task
	and self.spawns_available < self.max_banked_spawns then
		self.cooldown_task = self.inst:DoTaskInTime(self.spawn_cooldown, function()
			self.cooldown_task = nil
			self:_AddSpawn()
		end)
	end
end

return PeriodicSpawner
