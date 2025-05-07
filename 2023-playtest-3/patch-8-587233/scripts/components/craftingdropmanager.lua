local mapgen = require "defs.mapgen"
local krandom = require "util.krandom"
local lume = require "util.lume"
-- local prefabutil = require "prefabs.prefabutil"
require "util.tableutil"

local CraftingDropManager = Class(function(self, inst)
	self.inst = inst
	local seed = TheDungeon:GetDungeonMap():GetRNG():Integer(2^32 - 1)
	TheLog.ch.Random:printf("CraftingDropManager Random Seed: %d", seed)
	self.rng = krandom.CreateGenerator(seed)

	self._on_room_complete_fn = function(_, _data) self:OnRoomComplete() end
	if not TheWorld:HasTag("town")
		and not TheWorld:HasTag("debug")
	then
		self.inst:ListenForEvent("room_complete", self._on_room_complete_fn)
	end
end)

local function ShouldSpawnLootInThisRoom()
	local worldmap = TheDungeon:GetDungeonMap()
	return not worldmap:IsCurrentRoomDungeonEntrance()
		and not worldmap:HasEnemyForCurrentRoom('boss')
		and worldmap:DoesCurrentRoomHaveCombat()
end

local function PickPowerDropSpawnPosition()
	local angle = math.rad(math.random(360))
	local dist_mod = math.random(3, 6)
	local target_offset = Vector2.unit_x:rotate(angle) * dist_mod
	return Vector3(target_offset.x, 0, target_offset.y)
end

local ENUM_TO_DROP =
{
	[mapgen.Reward.s.small_token] = "soul_drop_lesser",
	[mapgen.Reward.s.big_token] = "soul_drop_greater",
}

function CraftingDropManager:OnRoomComplete()
	if TheNet:IsHost() and ShouldSpawnLootInThisRoom() then
		self.inst:RemoveEventCallback("room_complete", self._on_room_complete_fn)

		local reward = TheDungeon:GetDungeonMap():GetRewardForCurrentRoom()
		local drop = ENUM_TO_DROP[reward]
		if drop then
			local spawners = TheWorld.components.powerdropmanager.spawners
			table.sort(spawners, EntityScript.OrderByXZDistanceFromOrigin)
			self.rng:Shuffle(spawners)

			self:SpawnCraftingDrop(spawners[1], drop)
		end
	end
end

function CraftingDropManager:SpawnCraftingDrop(spawner, drop)
	local target_pos
	if spawner then
		target_pos = spawner:GetPosition()
	else
		-- Fallback to random position near the centre of the world if we
		-- didn't have enough spawners.
		TheLog.ch.Power:print("No room_loot for this power drop. Use self.spawners to place them to avoid appearing inside of something.")
		target_pos = PickPowerDropSpawnPosition()
	end

	local drop = SpawnPrefab(drop, self.inst)
	drop.Transform:SetPosition(target_pos:Get())
	drop.components.souldrop:PrepareToShowGem({
			appear_delay_ticks = TUNING.POWERS.DROP_SPAWN_INITIAL_DELAY_FRAMES,
		})
	return drop
end

return CraftingDropManager
