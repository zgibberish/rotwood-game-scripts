local Consumable = require "defs.consumable"
local easing = require "util.easing"
local lume = require "util.lume"
local mapgen = require "defs.mapgen"


local LootVacuum = Class(function(self, inst)
	self.inst = inst
	self.collected_loot = {}
	self.loot_to_vacuum = {}

	self.min_loot_speed = 5
	self.max_loot_speed = 50

	self.konjur_speedmult = 2
	self.rarity_speedmults =
	{
		[ITEM_RARITY.s.COMMON] = 1,
		[ITEM_RARITY.s.UNCOMMON] = 0.8,
		[ITEM_RARITY.s.RARE] = 0.6,
		[ITEM_RARITY.s.EPIC] = 0.5,
		[ITEM_RARITY.s.LEGENDARY] = 0.4,
	}

	self.passive_vacuum_radius = 100

	self.next_loot_search = nil
	self.loot_search_interval = 2

	self._wait_time = 2.5
	self._enabled_time = 0

	inst:ListenForEvent("room_locked", function() self:Disable() end, TheWorld)
	inst:ListenForEvent("room_complete", function()
		local worldmap = TheDungeon:GetDungeonMap()
		local reward = worldmap:GetRewardForCurrentRoom()

		if reward == mapgen.Reward.s.plain then
			self._wait_time = 3.0
		elseif reward == mapgen.Reward.s.fabled then
			self._wait_time = 3.5
		else
			self._wait_time = 1
		end

		self:Enable()
	end, TheWorld)

	inst:ListenForEvent("exit_room", function()
		self:CollectAllLoot_Instant()
	end, TheDungeon)

	-- TODO: someone -- remove code permanently or fix in appropriate place
	-- Shouldn't change state of component during construction phase since
	-- this messes up online due to the asynchronous room start nature
	-- if not TheDungeon:GetDungeonMap():IsDebugMap()
	-- 	and (TheWorld.components.roomclear and TheWorld.components.roomclear:IsClearOfEnemies())
	-- then
	-- 	self:Enable()
	-- end
end)

function LootVacuum:Enable()
	-- printf("LootVacuum:Enable()")
	self.inst:StartUpdatingComponent(self)
	self.next_loot_search = 0
	self._enabled_time = 0
	self:_ClearVacuum()
	-- TODO(dbriscoe): Why do we clear out collected loot too? If we used this
	-- variable, it only tracks loot collected since last enable and not in
	-- this room.
	self.collected_loot = {}
end

function LootVacuum:_ClearVacuum()
	self.loot_to_vacuum = {}
end

function LootVacuum:_CanVacuumLoot(loot)
	local owner = loot.components.loot:GetOwner()
	return not self.loot_to_vacuum[loot] and (not owner or owner == self.inst)
end

function LootVacuum:AddAllLootAndVacuum()
	local loot_in_room = self:FindLootInRadius(500)
	if #loot_in_room == 0 then
		return
	end

	for i, loot in ipairs(loot_in_room) do
		if self:_CanVacuumLoot(loot) then
			self:AddLootToVacuum(loot)
		end
	end

	self:Enable()
end

function LootVacuum:CollectAllLoot_Instant()
	-- Process everything we already have first to reduce the number of items
	-- to process later.
	for loot, time in pairs(self.loot_to_vacuum) do
		if loot and loot:IsValid() then
			self:CollectLoot(loot, true)
		end
	end

	local loot_in_room = self:FindLootInRadius(500)
	for i, loot in ipairs(loot_in_room) do
		if self:_CanVacuumLoot(loot) then
			self:AddLootToVacuum(loot)
			self:CollectLoot(loot, true)
		end
	end
end

function LootVacuum:AddLootToVacuum(loot)
	assert(loot)
	assert(loot.components.loot)
	assert(loot:HasTag("loot_acquirable"))
	local speedmult = self.rarity_speedmults[ITEM_RARITY.s.COMMON]
	if loot.components.loot then
		loot.components.loot:SetOwner(self.inst) -- claim it to prevent others from picking
		local loot_id = loot.components.loot:GetLootID()
		if loot_id == "konjur" then
			speedmult = self.konjur_speedmult
		else
			local def = Consumable.FindItem(loot_id)
			local rarity = def.rarity
			speedmult = self.rarity_speedmults[rarity]
		end
	end
	self.loot_to_vacuum[loot] = { time = 0.1, speedmult = speedmult }
end

function LootVacuum:FindLootInRadius(radius)
	local x, z = self.inst.Transform:GetWorldXZ()
	return TheSim:FindEntitiesXZ(x, z, radius, { "loot", "loot_acquirable", })
end

function LootVacuum:OnUpdate(dt)
	self._enabled_time = self._enabled_time + dt

	if self.next_loot_search and GetTime() > self.next_loot_search then
		local loot_nearby = self:FindLootInRadius(self.passive_vacuum_radius)
		for i, loot in ipairs(loot_nearby) do
			if self:_CanVacuumLoot(loot) then
				self:AddLootToVacuum(loot)
			end
		end
		self.next_loot_search = GetTime() + self.loot_search_interval
	end

	if self._enabled_time >= self._wait_time then

		local pos = self.inst:GetPosition()

		-- loop through all the loot in the world and move it a bit closer to you
		for loot, data in pairs(self.loot_to_vacuum) do
			if loot and loot:IsValid() and loot.Physics ~= nil then
				if not loot.sg:HasStateTag("moving") then
					-- We SetVel instead of using motor.
					loot.Physics:SetMotorVel(0)
					loot:PushEvent("vacuum_started", self.inst)
				end

				data.time = data.time + dt

				local to_player = pos - loot:GetPosition()
				to_player.y = 0
				local dir, dist = to_player:normalized()

				-- Start slow and rapidly accelerate until it gets picked up.
				local speed = easing.inCubic(data.time, self.min_loot_speed, self.max_loot_speed - self.min_loot_speed, 1.5)
				speed = lume.clamp(speed, self.min_loot_speed, self.max_loot_speed)
				speed = speed * data.speedmult

				local velocity = dir * speed
				loot.Physics:SetVel(velocity:unpack())

				if dist <= 1 then
					self:CollectLoot(loot)
					self.loot_to_vacuum[loot] = nil
				end
			end
		end
	end

	if not self.next_loot_search and not next(self.loot_to_vacuum) then
		self:Disable()
	end
end

function LootVacuum:CollectLoot(loot, force)
	assert(loot)
	if loot:IsValid() then
		loot.components.loot:OnPickedUpBy(self.inst)
	end
	assert(not loot:IsValid(), "Why does loot still exist after pickup?")

	self.collected_loot[loot.prefab] = (self.collected_loot[loot.prefab] or 0) + 1
end

function LootVacuum:Disable()
	TheLog.ch.Player:print("Disable LootVacuum!")
	-- self:_ClearVacuum()
	self.inst:StopUpdatingComponent(self)
end

return LootVacuum
