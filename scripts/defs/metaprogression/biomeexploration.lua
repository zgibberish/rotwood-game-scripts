local MetaProgress = require "defs.metaprogression.metaprogress"

local Power = require"defs.powers"
local Consumable = require"defs.consumable"

function MetaProgress.AddBiomeExploration(id, data)
	-- add tags? (biome name for example?)
	-- define exp curve?
	data.base_exp = { 50, 75, 100, 125, 150, 200, 250, 300 }
	data.exp_growth = 0.10

	-- define endless reward?

	MetaProgress.AddProgression(MetaProgress.Slots.BIOME_EXPLORATION, id, data)
	-- body
end

MetaProgress.AddProgressionType("BIOME_EXPLORATION")

MetaProgress.AddBiomeExploration("forest",
{
	-- Aim for 10 Powers per biome
	rewards =
	{
		-- Focus Hits to highlight focus hits early
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "heal_on_focus_kill"), -- Give an early new chance to sustain
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "salted_wounds"),

		MetaProgress.Reward(Power, Power.Slots.PLAYER, "dont_whiff"),

		-- Critical Chance
		-- jambell: this is a lot of crit chance in a row, for a really long time... might be worth splitting up?
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "feedback_loop"), --crit
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "bad_luck_protection"), --crit
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "carefully_critical"), --crit

		-- Weaponry Family
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "precision_weaponry"), --crit
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "fractured_weaponry"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "weighted_weaponry"), --crit
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "volatile_weaponry"),
	},
})

MetaProgress.AddBiomeExploration("swamp",
{
	rewards =
	{
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "combo_wombo"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "retribution"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "free_upgrade"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "bloodthirsty"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "advantage"), --crit
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "lasting_power"), --crit
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "pick_of_the_litter"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "analytical"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "ping"),
		MetaProgress.Reward(Power, Power.Slots.PLAYER, "pong"),
	},
})

-- TODO @design #sedament_tundra - meta progress
MetaProgress.AddBiomeExploration("tundra",
{
	rewards =
	{
	},
})
