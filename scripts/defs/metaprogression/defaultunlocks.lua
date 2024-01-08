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
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "thorns"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "getaway"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "momentum"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "running_shoes"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "no_pushback"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "grand_entrance"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "down_to_business"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "undamaged_target"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "extroverted"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "konjur_on_crit"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "streaking"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "battle_fame"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "optimism"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "increased_hitstun"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "crit_knockdown"))

	-- Epics
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "snowball_effect"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "iron_brew"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "extended_range"))
	-- table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "reflective_dodge"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "risk_reward"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "crit_movespeed"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "crit_streak"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "heal_on_quick_rise"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "sanguine_power")) --crit
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "bomb_on_dodge"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "shrapnel"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "mulligan"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "attack_dice"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "berserk"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "heal_on_crit"))

	-- Legendaries
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "wrecking_ball"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "max_health_and_heal"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "pump_and_dump"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "introverted"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "sting_like_a_bee"))

	-- TEMP
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "moment37"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "jury_and_executioner"))

	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "revive_damage_bonus"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "revive_explosion"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "revive_gain_konjur"))
	table.insert(unlocks, MetaProgress.Reward(Power, Power.Slots.PLAYER, "revive_borrow_power"))


	-- validate all droppable powers are unlockable

	return unlocks
end

local default_unlocks = BuildDefaultUnlocksTable()

MetaProgress.AddDefaultUnlocks("default",
{
	rewards = default_unlocks,
})
