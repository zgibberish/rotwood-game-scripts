local lume = require "util.lume"

-- fallback code to stop room clear soft locks caused by non-interactive enemies
local ClearEnemyTimeoutEnabled = PLAYTEST_MODE and not IS_QA_BUILD
local ClearEnemyTimeoutSeconds = 10.0 -- needs to be large enough value to support wave spawning

local RoomClear = Class(function(self, inst)
	self.inst = inst
	self.enemies = {}
	self.enemy_highwater = 0
	self.focus_threshold = 1

	self.pending_edge_detection_task = nil

	self._onspawnenemy = function(source, ent) 
		if not TheNet:IsHost() then 
			return 
		end 
		self:AfterSpawn(ent) 
	end

	self._ondefeatenemy = function(source) 
		if not TheNet:IsHost() then 
			return 
		end 
		self:AfterDespawn(source) 
	end

	inst:ListenForEvent("spawnenemy", self._onspawnenemy, TheWorld)
	inst:StartUpdatingComponent(self) -- NETWORK FIX: iterate over remaining mobs and see if any of them are in a zombie state. if so, remove it.

	self.clearenemy_timeout = nil
end)

function RoomClear:OnRemoveEntity()
	self:OnRemoveFromEntity()
end

function RoomClear:OnRemoveFromEntity()
	self.inst:RemoveEventCallback("spawnenemy", self._onspawnenemy, TheWorld)
	self.inst:RemoveEventCallback("room_complete", self._onroomcomplete)

	for source in pairs(self.enemies) do
		self:_RemoveCallbacks(source)
	end
end

function RoomClear:_RemoveCallbacks(source)
	self.inst:RemoveEventCallback("onremove", self._ondefeatenemy, source)
	self.inst:RemoveEventCallback("death", self._ondefeatenemy, source)
	self.inst:RemoveEventCallback("charmed", self._ondefeatenemy, source)
end

-- Has the entire encounter been cleared.
function RoomClear:IsRoomComplete()
	-- This isn't our data, but it's more obvious put next to IsClearOfEnemies.
	return self.inst.components.spawncoordinator:GetIsRoomComplete()
end

-- Whether there are currently no enemies, regardless of whether any spawned.
function RoomClear:IsClearOfEnemies()
	return next(self.enemies) == nil
end

function RoomClear:GetEnemyCount()
	return lume.count(self.enemies)
end

function RoomClear:GetEnemies()
	return self.enemies
end

function RoomClear:AfterSpawn(source)
	assert(EntityScript.is_instance(source))

	if not self.enemies[source] then
		self.clearenemy_timeout = ClearEnemyTimeoutSeconds

		self.enemies[source] = true
		local enemy_count = lume.count(self.enemies)
		self.enemy_highwater = math.max(self.enemy_highwater, enemy_count)
		self.inst:ListenForEvent("onremove", self._ondefeatenemy, source)
		self.inst:ListenForEvent("death", self._ondefeatenemy, source)
		self.inst:ListenForEvent("charmed", self._ondefeatenemy, source)

		if enemy_count > self.focus_threshold then
			if self.pending_edge_detection_task then
				self.pending_edge_detection_task:Cancel()
				self.pending_edge_detection_task = nil
			end
			TheFocalPoint.components.focalpoint:ClearEntitiesForEdgeDetection()
		end
	end
end

function RoomClear:AfterDespawn(source)
	assert(EntityScript.is_instance(source))
	if self.enemies[source] then
		self.clearenemy_timeout = ClearEnemyTimeoutSeconds

		self:_RemoveCallbacks(source)
		self.enemies[source] = nil
		if self:IsClearOfEnemies() then
			-- Fired when enemies are gone, but room may still be locked. Only
			-- fires if enemies existed.
			self.inst:PushEvent("room_cleared", {
					enemy_highwater = self.enemy_highwater,
					last_enemy = source,
				})
		end

		if source:HasTag("boss") then
			local worldmap = TheDungeon:GetDungeonMap()
			local progress = worldmap.nav:GetProgressThroughDungeon()
			if progress >= 1 then
				-- you killed the boss, good job
				local x,y,z = source.Transform:GetWorldPosition()
				local drop = SpawnPrefab("soul_drop_heart")
				drop.Transform:SetPosition(x, y, z)
				drop.components.rotatingdrop:SpawnDrops(drop.components.rotatingdrop:BuildDrops())

				local ascension_level = TheDungeon.progression.components.ascensionmanager:GetCurrentLevel()
				TheDungeon.progression.components.runmanager:SetCanAbandon(false)

				local function on_complete()
					local on_drop_consumed = function()
						-- Networking PSA: this code only runs on hosts
						-- Use functions like RunManager:Victory to generate side effects on all clients
						TheDungeon:PushEvent("dungeoncleared", {
							boss_killed = source,
							ascension_level = ascension_level
						})
					end

					-- If a cine is still active or a new one is playing, wait for it to finish.
					if source.components.cineactor and source.components.cineactor:IsInCine() then
						self.inst:ListenForEvent("cine_end", on_complete, source)
					else
						drop.components.souldrop:PrepareToShowGem({
							appear_delay_ticks = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES,
						}, on_drop_consumed)
					end
				end

				-- Delay firing event to ensure cine has time to start (we both
				-- listen to "death" event).
				self.inst:DoTaskInTicks(1, function(inst_)
					if source.components.cineactor and source.components.cineactor:IsInCine() then
						self.inst:ListenForEvent("cine_end", on_complete, source)
					else
						on_complete()
					end
				end)
			end
		end
	end

	-- when there are few enemies remaining, add the remaining enemies
	-- as candidates for camera edge detection
	if not self.pending_edge_detection_task then
		self.pending_edge_detection_task = self.inst:DoTaskInTime(2, function()
			local enemy_count = self:GetEnemyCount()
			if enemy_count > 0 and enemy_count <= self.focus_threshold then
				for ent,_ in pairs(self.enemies) do
					if not ent:HasTag("boss") then
						TheFocalPoint.components.focalpoint:AddEntityForEdgeDetection(ent)
					end
				end
			end
			self.pending_edge_detection_task = nil
		end)
	end
end

function RoomClear:CleanUpRemainingEnemies()
	-- Copy since we might remove enemies during iteration.
	local enemies = shallowcopy(self.enemies)
	for source in pairs(enemies) do
		if source:IsValid() then
			source:TakeControl()
			if source.components.health then
				source.components.health:Kill()
			else
				source:Remove()
			end
		end
	end
end


function RoomClear:OnUpdate(dt)
	-- network test sept2023, host audits mobs for zombie states and deals with them. Can remove this if cause is found and fixed thoroughly.
	if TheNet:IsHost() then
		local only_noninteractive_enemies_left = true
		for enemy,_ in pairs(self.enemies) do
			if enemy:HasTag("boss") then
				only_noninteractive_enemies_left = false
				break
			elseif enemy:IsInLimbo() then
				-- invisible, non-interactive
				local health = enemy.components.health
				if health and health:IsAlive() and health:GetMissing() == 0 and not enemy.HitBox:IsEnabled() then
					if enemy.components.cabbagetower then
						TheLog.ch.RoomClear:printf("[roomclearfix]: A cabbage is in limbo, and is still alive with a disabled hitbox. Pushing dying event: %s", enemy)
						TheLog.ch.RoomClear:printf("[roomclearfix]: SG State: %s", enemy.sg:GetCurrentState())
						enemy:TakeControl()
						enemy:PushEvent("dying")
					else
						TheLog.ch.RoomClear:printf("[roomclearfix]: A non-cabbage is in limbo, and is still alive. Removing: %s", enemy)
						TheLog.ch.RoomClear:printf("[roomclearfix]: SG State: %s", enemy.sg:GetCurrentState())
						enemy:TakeControl()
						enemy:Remove(true)
					end
				end
			elseif not enemy.HitBox:IsEnabled() then
				-- visible, non-interactive
				-- sometimes this is okay for enemies that become "invincible" for certain attacks
			else
				only_noninteractive_enemies_left = false
			end
		end

		-- this should only be triggered if the fallback is enabled AND if at least one enemy was
		-- spawned -- so locks for rooms with npcs/quests only will still not trigger this code
		if ClearEnemyTimeoutEnabled and self.clearenemy_timeout then
			if not self:IsClearOfEnemies() then
				if only_noninteractive_enemies_left then
					self.clearenemy_timeout = self.clearenemy_timeout - dt
				else
					self.clearenemy_timeout = ClearEnemyTimeoutSeconds
				end
			elseif TheWorld.components.roomlockable:IsLocked()
				and TheWorld.components.roomlockable:GetAnyLockWithTagFilter("mob", "boss") then
				self.clearenemy_timeout = self.clearenemy_timeout - dt
			end

			if self.clearenemy_timeout <= 0.0 then
				if not self:IsClearOfEnemies() then
					TheLog.ch.RoomClear:printf("[roomclearfix] Warning: Removing remaining noninteractable enemies in limbo")
					self:CleanUpRemainingEnemies()
				end

				if TheWorld.components.roomlockable:IsLocked() then
					local zombie = TheWorld.components.roomlockable:GetAnyLockWithTagFilter("mob", "boss")
					if zombie then
						-- playtest 3: reports of zombie mobs that are not registered in roomclear but still locking the room
						TheLog.ch.RoomClear:printf("[roomclearfix]: Room cleared, but found locking mob %s EntityID %d.  Removing lock and zombie mob...",
							zombie, zombie:IsNetworked() and zombie.Network:GetEntityID() or "-1")
						TheWorld.components.roomlockable:RemoveLock(zombie)
						zombie:TakeControl()
						zombie:Remove()
						self.clearenemy_timeout = 1.0 -- retry in case more than one left
					end
				end
				if self.clearenemy_timeout <= 0.0 then
					self.clearenemy_timeout = nil
				end
			end
		end
	end
end

function RoomClear:Debug_ForceClear()
	self:CleanUpRemainingEnemies()
	print("Force killed everything in current room")
end

function RoomClear:GetDebugString()
	if self:IsClearOfEnemies() then
		return ("Clear (highwater=%d)\n---ClearEnemyTimeout: %s"):format(
			self.enemy_highwater, self.clearenemy_timeout and string.format("%1.1f", self.clearenemy_timeout) or "n/a")
	else
		return ("Hostiles \n---Highwater: (%d)\n---Current:(%d)\n---ClearEnemyTimeout: %s"):format(
			self.enemy_highwater, lume.count(self.enemies) or 0, self.clearenemy_timeout and string.format("%1.1f", self.clearenemy_timeout) or "n/a")
	end
end

return RoomClear
