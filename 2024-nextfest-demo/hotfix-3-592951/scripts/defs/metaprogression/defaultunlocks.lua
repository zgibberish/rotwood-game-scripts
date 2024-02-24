local MetaProgress = require "defs.metaprogression.metaprogress"

local Power = require"defs.powers"
local Consumable = require"defs.consumable"

function MetaProgress.AddDefaultUnlocks(id, data)
	data.base_exp = 1
	data.exp_growth = 0
	MetaProgress.AddProgression(MetaProgress.Slots.DEFAULT_UNLOCK, id, data)
	-- body
end

-- Players get this applied with max level on creation, which unlocks everything in this file

MetaProgress.AddProgressionType("DEFAULT_UNLOCK")

local DEFAULT_UNLOCKED_SLOTS =
{
	[Power.Slots.ELECTRIC] = true,
	[Power.Slots.SEED] = true,
	[Power.Slots.SHIELD] = true,
	[Power.Slots.SUMMON] = true,
	[Power.Slots.SKILL] = true,
}

local function BuildDefaultUnlocksTable()
	local unlocks = {}

	for slot, powers in pairs(Power.Items) do
		if DEFAULT_UNLOCKED_SLOTS[slot] then
			for id, def in pairs(powers) do
				table.insert(unlocks, MetaProgress.Reward(Power, slot, id))
			end
		end
	end

	-- Commons
	table.insert(unlocks, MetaProgress.RewardGroup("common_powers", {
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "thorns"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "getaway"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "momentum"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "running_shoes"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "grand_entrance"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "down_to_business"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "undamaged_target"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "extroverted"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "extended_range"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "shrapnel"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "retribution"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "bad_luck_protection"),
	}))

	-- Epics
	table.insert(unlocks, MetaProgress.RewardGroup("epic_powers", {
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "iron_brew"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "heal_on_quick_rise"), -- JAMBELL: CONSIDER LOCKING
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "sanguine_power"), --crit
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "bomb_on_dodge"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "mulligan"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "berserk"),
	}))

	-- Legendaries
	table.insert(unlocks, MetaProgress.RewardGroup("legendary_powers", {
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "volatile_weaponry"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "wrecking_ball"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "max_health_and_heal"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "pump_and_dump"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "introverted"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "free_upgrade"),
	}))

	-- TEMP: These are powers based on specific skills, and will only drop if you have that Skill.

	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "moment37"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "jury_and_executioner"))

	table.insert(unlocks, MetaProgress.RewardGroup("revive_powers", {
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "revive_damage_bonus"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "revive_explosion"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "revive_gain_konjur"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "revive_borrow_power"),
	}))

	table.insert(unlocks, MetaProgress.RewardGroup("skills", {
		MetaProgress.Reward(Power, Power.Slots.SKILL, "buffnextattack"),
		MetaProgress.Reward(Power, Power.Slots.SKILL, "bananapeel"),
		MetaProgress.Reward(Power, Power.Slots.SKILL, "throwstone"),
		MetaProgress.Reward(Power, Power.Slots.SKILL, "shotput_seek"),
		MetaProgress.Reward(Power, Power.Slots.SKILL, "hammer_totem"),
		MetaProgress.Reward(Power, Power.Slots.SKILL, "parry"),
	}))

	-- TODO: validate all droppable powers are unlockable

	return unlocks
end

local default_unlocks = BuildDefaultUnlocksTable()

MetaProgress.AddDefaultUnlocks("default",
{
	rewards = default_unlocks,
})
