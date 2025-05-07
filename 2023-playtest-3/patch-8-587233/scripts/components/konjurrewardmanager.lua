local mapgen = require "defs.mapgen"
local krandom = require "util.krandom"
local LootEvents = require "lootevents"
local lume = require "util.lume"
-- local prefabutil = require "prefabs.prefabutil"
require "util.tableutil"
local fmodtable = require "defs.sound.fmodtable"

-- This component manages Konjur rewards in any type of combat room.

-- General philosophy is:
--		Every room delivers a minimum amount of Konjur, based on difficulty. (basic_room_drops)
--			(delivered via mob kills, until the budget is depleted. If budget remains in last enemy, drop remaining budget)
--		Reward rooms drop an extra chunk of Konjur, LESS whatever basic_room_drops already delivered. (reward_room_drops)
--			(delivered via end-of-room konjur reward interactable)

-- Total konjur in a room:
-- basic room drops + reward drops

local basic_room_drops = {
--		Every room delivers a minimum amount of extra Konjur, based on difficulty. (basic_room_drops)
--			(delivered via mob kills, until the budget is depleted. If budget remains in last enemy, drop remaining budget)
	easy = {
		min = 4,
		max = 7,
	},

	medium = {
		min = 5,
		max = 10,
	},
	hard = {
		min = 12,
		max = 16,
	},
}

-- JAMBELL: These reward_room_drops are currently tuned to be "what is the TOTAL amount of new konjur the player should leave the room with"
-- so, if the player made 30K from basic_room_drops and the end-of-room reward is trying to have them leave the room with 60K, that bonus will be 30K.
local reward_room_drops = {
--		Reward rooms drop an extra chunk of Konjur, LESS whatever basic_room_drops already delivered. (reward_room_drops)
--			(delivered via end-of-room konjur reward interactable)
	-- Easy rooms are slightly less difficult than a medium room, but appear visually the same to the player in every way.
	easy = {
		min = TUNING.KONJUR_ON_SKIP_POWER + 10,
		max = TUNING.KONJUR_ON_SKIP_POWER + 15,
	},
	-- Konjur on skip gives 30konjur. Choosing the "Konjur Reward" room should give more than that. see tuning.lua
	-- The other choice in this part of the dungeon is a Relic. This reward is helping contribute towards an early potion or upgrade.
	medium = {
		min = TUNING.KONJUR_ON_SKIP_POWER + 35,
		max = TUNING.KONJUR_ON_SKIP_POWER + 40,
	},
	-- These should be rewarding enough to definitely give a potion, and POSSIBLY a Legendary upgrade, so they make sense to choose near the end of a run. Otherwise, never worth.
	-- The other choice in this part of the dungeon is a Fabled Relic, which is *super* powerful. This reward should contend.
	hard = {
		min = TUNING.KONJUR_ON_SKIP_POWER_FABLED + 65,
		max = TUNING.KONJUR_ON_SKIP_POWER_FABLED + 85,
	},
}


-- print("Some prints to help make sure it feels rewarding to choose CoinRoom over PowerRoom:")
-- print("Minimum possible EASY CoinRoom reward is this much higher than just skipping a power:", reward_room_drops.easy.min - 	basic_room_drops.easy.max - TUNING.KONJUR_ON_SKIP_POWER)
-- print("Minimum possible MEDIUM CoinRoom reward is this much higher than just skipping a power:", reward_room_drops.medium.min - 	basic_room_drops.medium.max - TUNING.KONJUR_ON_SKIP_POWER)
-- print("Minimum possible HARD CoinRoom reward is this much higher than just skipping a power:", reward_room_drops.hard.min - 	basic_room_drops.hard.max - TUNING.KONJUR_ON_SKIP_POWER_FABLED)

assert((reward_room_drops.easy.min - 	basic_room_drops.easy.max) - TUNING.KONJUR_ON_SKIP_POWER > 0, string.format("TUNING ASSERT: Always ensure that the 'bonus konjur' popping up at the end of a room is significantly greater than a skipped power reward. Otherwise, it will not seem rewarding to choose a Konjur Reward room. Currently the lowest possible reward in an EASY Reward Room is only [%d] greater than a Power-Skip, which is not enough.]", (reward_room_drops.easy.min - 	basic_room_drops.easy.max) - TUNING.KONJUR_ON_SKIP_POWER))
assert((reward_room_drops.medium.min - 	basic_room_drops.medium.max) - TUNING.KONJUR_ON_SKIP_POWER > 20, string.format("TUNING ASSERT: Always ensure that the 'bonus konjur' popping up at the end of a room is significantly greater than a skipped power reward. Otherwise, it will not seem rewarding to choose a Konjur Reward room. Currently the lowest possible reward in a MEDIUM Reward Room is only [%d] greater than a Power-Skip, which is not enough.]", (reward_room_drops.medium.min - 	basic_room_drops.medium.max) - TUNING.KONJUR_ON_SKIP_POWER))
assert((reward_room_drops.hard.min - 	basic_room_drops.hard.max) - TUNING.KONJUR_ON_SKIP_POWER_FABLED > 40, string.format("TUNING ASSERT: Always ensure that the 'bonus konjur' popping up at the end of a room is significantly greater than a skipped power reward. Otherwise, it will not seem rewarding to choose a Konjur Reward room. Currently the lowest possible reward in a HARD Reward Room is only [%d] greater than a Power-Skip, which is not enough.]", (reward_room_drops.hard.min - 	basic_room_drops.hard.max) - TUNING.KONJUR_ON_SKIP_POWER_FABLED))

local distribution_modifier_by_difficulty = {
	-- Presentational tuning value.
	-- This is basically a rate at which the 'basic_room_drops' is delivered.
	-- This isn't easy to explain/use... plan to make this better.
	easy = 2.5,
	medium = 4,
	hard = 4,
}

local function ShouldSpawnLootInThisRoom()
	local worldmap = TheDungeon:GetDungeonMap()
	return not worldmap:IsCurrentRoomDungeonEntrance()
		and not worldmap:HasEnemyForCurrentRoom('boss')
		and worldmap:DoesCurrentRoomHaveCombat()
end

local function GenerateKonjurAmount(min, max)
	min = (min >= 0) and min or 0
	max = (max and max > min) and max or nil
	-- TODO: networking2022, this should be deterministic for room restarts,
	-- but it only runs on the host so the urgency is not as high
	return max and math.random(min, max) or min
end

mapgen.validate.all_keys_are_difficulty(basic_room_drops)
mapgen.validate.all_keys_are_difficulty(reward_room_drops)
mapgen.validate.has_all_difficulty_keys(basic_room_drops)
mapgen.validate.has_all_difficulty_keys(reward_room_drops)

local KonjurRewardManager = Class(function(self, inst)
	self.inst = inst
	local seed = TheDungeon:GetDungeonMap():GetRNG():Integer(2^32 - 1)
	TheLog.ch.Random:printf("KonjurRewardManager Random Seed: %d", seed)
	self.rng = krandom.CreateGenerator(seed)
	self.basic_konjur_budget_max = nil
	self.basic_konjur_budget = nil

	self._on_enter_room = function() self:OnEnterRoom() end
    self._on_room_complete_fn = function(_, _data) self:OnRoomComplete() end
	if not TheWorld:HasTag("town")
		and not TheWorld:HasTag("debug")
	then
		self.inst:ListenForEvent("room_locked", self._on_enter_room)
		self.inst:ListenForEvent("room_complete", self._on_room_complete_fn)
	end

	self.lucky_konjur_bonus = 0.33
end)

function KonjurRewardManager:OnEnterRoom()
	if ShouldSpawnLootInThisRoom() then
		self:SetBasicKonjurBudget()
	end
end

function KonjurRewardManager:SetBasicKonjurBudget()
	if ShouldSpawnLootInThisRoom() then
		local difficulty = TheDungeon:GetDungeonMap():GetDifficultyForCurrentRoom()
		local diff_name = mapgen.Difficulty:FromId(difficulty)
		local drop_range = basic_room_drops[diff_name]
		-- local dungeon_progress = TheDungeon:GetDungeonMap().nav:GetProgressThroughDungeon()
		-- local current_segment = prefabutil.ProgressToSegment(dungeon_progress)
		-- if diff_name == "easy" and current_segment ~= prefabutil.ProgressSegments.s.early then -- Past the miniboss, give more basic-konjur if we're in an easy room
		-- 	drop_range = basic_room_drops["medium"]
		-- end

		local amount = self.rng:Integer(drop_range.min, drop_range.max)
		self.basic_konjur_budget = amount
		self.basic_konjur_budget_max = amount
	end
end

-- This only runs on hosts because it has the side effect of testing + setting the basic konjur budget.
-- It sends an event to clients and they spawn local konjur
-- (i.e. real ones for the local players, visual representations for the remote players).
function KonjurRewardManager:OnEnemyDeath(enemy)
	if TheNet:IsHost() and ShouldSpawnLootInThisRoom() then
		-- Spawn Room Budget konjur to ensure a solid baseline
		local drop_amount = 0
		if self.basic_konjur_budget > 0 then
			local difficulty = TheDungeon:GetDungeonMap():GetDifficultyForCurrentRoom()
			local min = 0
			local max = math.max(1, math.floor(self.basic_konjur_budget / distribution_modifier_by_difficulty[mapgen.Difficulty:FromId(difficulty)]))

			drop_amount = GenerateKonjurAmount(min, max)
			self.basic_konjur_budget = self.basic_konjur_budget - drop_amount
		end

		if drop_amount > 0 then
			LootEvents.MakeEventSpawnCurrency(drop_amount, enemy:GetPosition())
		end

		-- TheLog.ch.KonjurRewardManager:printf("Dropped Konjur: [%d] -- Basic Budget Remaining: [%d]", drop_amount, self.basic_konjur_budget)
		-- TheDungeon.HUD:MakePopText({ target = enemy, button = "[Budget: "..self.basic_konjur_budget.."]", color = UICOLORS.KONJUR, size = 50, fade_time = 5 })
	end
end

-- fired on room_complete via powerdropmanager
function KonjurRewardManager:OnLastEnemyDeath(inst)
	if TheNet:IsHost() and ShouldSpawnLootInThisRoom() then
		if self.basic_konjur_budget > 0 then
			--TheLog.ch.KonjurRewardManager:printf("OnLastEnemyDeath, delivering remaining budget all at once: %d", self.basic_konjur_budget)
			local drop_amount = GenerateKonjurAmount(self.basic_konjur_budget)
			self.basic_konjur_budget = 0
			if not inst then
				TheLog.ch.KonjurRewardManager:printf("Last enemy position invalid, spawning at origin")
			end
			local pos = inst and inst:GetPosition() or Vector3.zero
			LootEvents.MakeEventSpawnCurrency(drop_amount, pos)
		end
		self:AddToLog(self.basic_konjur_budget_max, "basic")
	end
end

function KonjurRewardManager:OnRoomComplete()
	if TheNet:IsHost() and ShouldSpawnLootInThisRoom() then
		local reward = TheDungeon:GetDungeonMap():GetRewardForCurrentRoom()
		if reward == mapgen.Reward.s.coin then
			self.inst:RemoveEventCallback("room_complete", self._on_room_complete_fn)

			local spawners = TheWorld.components.powerdropmanager.spawners
			table.sort(spawners, EntityScript.OrderByXZDistanceFromOrigin)
			self.rng:Shuffle(spawners)

			self:SpawnBonusKonjurDrop(spawners[1])
		end
	end
end

local function PickPowerDropSpawnPosition()
	local angle = math.rad(math.random(360))
	local dist_mod = math.random(3, 6)
	local target_offset = Vector2.unit_x:rotate(angle) * dist_mod
	return Vector3(target_offset.x, 0, target_offset.y)
end

function KonjurRewardManager:SpawnBonusKonjurDrop(spawner)
	local target_pos
	if spawner then
		target_pos = spawner:GetPosition()
	else
		-- Fallback to random position near the centre of the world if we
		-- didn't have enough spawners.
		TheLog.ch.Power:print("No room_loot for this power drop. Use self.spawners to place them to avoid appearing inside of something.")
		target_pos = PickPowerDropSpawnPosition()
	end

	local drop = SpawnPrefab("power_drop_konjur", self.inst)
	drop.Transform:SetPosition(target_pos:Get())
	return drop
end

function KonjurRewardManager:SpawnRoomRewardKonjur(drop)
	if TheNet:IsHost() then
		local worldmap = TheDungeon:GetDungeonMap()
		local difficulty = worldmap:GetDifficultyForCurrentRoom()
		local reward = worldmap:GetRewardForCurrentRoom()
		if reward == mapgen.Reward.s.coin then
			local diff_name = mapgen.Difficulty:FromId(difficulty)
			local drop_range = reward_room_drops[diff_name]
			local drop_amount = GenerateKonjurAmount(drop_range.min, drop_range.max)
			--print("reward konjur before:", droptable.konjur)
			-- Subtract the amount we've already delivered them, since the 'reward' value is meant to be TOTAL upon leaving the room
			drop_amount = math.max(0, drop_amount - self.basic_konjur_budget_max)
			if drop_amount > 0 then
				LootEvents.MakeEventSpawnCurrency(drop_amount, drop:GetPosition(), nil, false, true)
				self:AddToLog(drop_amount, "reward")

				local luckyAmount = math.ceil(drop_amount * self.lucky_konjur_bonus)
				local players = TheNet:GetPlayersOnRoomChange()
				for _i, player in ipairs(players) do
					-- TODO: networking2022, this needs to be synchronized
					-- this is accessing the unsynced lucky component from the host side
					if player.components.lucky and player.components.lucky:DoLuckRoll() then
						LootEvents.MakeEventSpawnCurrency(luckyAmount, drop:GetPosition(), player, true)
						if player.SoundEmitter then
							--sound
							local soundutil = require "util.soundutil"
							local params = {}
							params.fmodevent = fmodtable.Event.lucky
							params.sound_max_count = 1
							soundutil.PlaySoundData(player, params)
						end
					end
				end
			end
		end
	end
end

-- TODO: networking2022, victorc - this needs to be hooked up for networking
function KonjurRewardManager:SpawnSkipPowerKonjur(player, amount)
	local target_pos
	if player then
		target_pos = player:GetPosition()
	else
		-- Fallback to random position near the centre of the world if we
		-- didn't have enough spawners.
		target_pos = PickPowerDropSpawnPosition()
	end

	local drop_amount = GenerateKonjurAmount(amount)
	LootEvents.MakeEventSpawnCurrency(drop_amount, target_pos, player, false, true) -- spawn only for this player
	self:AddToLog(drop_amount, "power_skip")
end

function KonjurRewardManager:AddToLog(amount, source)
	local tbl = self:GetLog()

	local worldmap = TheDungeon:GetDungeonMap()
	local dungeon_progress = worldmap.nav:GetProgressThroughDungeon()
	local rewardtype = worldmap:GetRewardForCurrentRoom()
	local difficulty = TheDungeon:GetDungeonMap():GetDifficultyForCurrentRoom()
	local diff_name = mapgen.Difficulty:FromId(difficulty, "<none>")

	if tbl.total == nil then
		tbl.total = 0
	end
	if tbl[dungeon_progress] == nil then
		tbl[dungeon_progress] = {}

		tbl[dungeon_progress].roomdata = {}
		tbl[dungeon_progress].roomdata.difficulty = diff_name
		tbl[dungeon_progress].roomdata.rewardtype = rewardtype
		tbl[dungeon_progress].roomdata.total = 0
		tbl[dungeon_progress].entries = {}
	end

	local data =
	{
		amount = amount,
		source = source,
	}

	tbl.total = tbl.total + amount

	tbl[dungeon_progress].roomdata.total = tbl[dungeon_progress].roomdata.total + amount
	table.insert(tbl[dungeon_progress].entries, data)

	TheSaveSystem.progress.dirty = true
end

function KonjurRewardManager:GetLog()
	local log = TheSaveSystem.progress:GetValue("konjur_debug")
	if log == nil then
		TheSaveSystem.progress:SetValue("konjur_debug", {})
		log = TheSaveSystem.progress:GetValue("konjur_debug")
	end

	return log
end

return KonjurRewardManager
