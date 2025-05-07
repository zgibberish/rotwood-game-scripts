local MetaProgress = require "defs.metaprogression.metaprogress"

local Power = require"defs.powers"
local Consumable = require"defs.consumable"

function MetaProgress.AddBiomeExploration(id, data)
	-- add tags? (biome name for example?)
	-- define exp curve?

	-- Right now, completing one run gives 225 EXP by default

	-- Die at Miniboss: 75XP
	-- Die at Boss: 175XP
	-- Clear Boss: 225XP

	-- Clearing Miniboss adds +25
	-- Clearing Boss adds +50
	-- Total = 150 + 25 + 50 = 225 for one completed run

	-- NEXTFEST 2024: Aim to have a few full runs between each unlock.
	data.base_exp = {
		400,
		450,
		500,
		550,
		600,
		650,
	}
	data.exp_growth = 0.1

	MetaProgress.AddProgression(MetaProgress.Slots.BIOME_EXPLORATION, id, data)
	-- body
end

MetaProgress.AddProgressionType("BIOME_EXPLORATION")

MetaProgress.AddBiomeExploration("forest",
{
	-- NOTE: Players will be unlocking these through either Dungeon 1 or Dungeon 2
	endless_reward = MetaProgress.Reward(Consumable, Consumable.Slots.MATERIALS, "konjur_soul_lesser", 5),
	rewards =
	{
		MetaProgress.RewardGroup("focus_powers", {
			-- Some focus stuff and some general powers
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "salted_wounds"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "heal_on_focus_kill"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "risk_reward"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "pick_of_the_litter"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "advantage"),
		}),


		MetaProgress.RewardGroup("hitstreak_powers", {
			-- Stuff that starts to make it easier to build high hitstreaks, and pays off on it.
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "fractured_weaponry"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "attack_dice"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "battle_fame"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "no_pushback"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "increased_hitstun"),
		}),

		MetaProgress.RewardGroup("critsimple_powers", {
			-- Stuff that starts to give you more critical chance, and pays off critical chance. Easy options.
			-- Capitalizes off of the hitstreak they learned to develop in the previous batch.
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "lasting_power"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "feedback_loop"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "konjur_on_crit"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "crit_movespeed"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "carefully_critical"),
		}),

		-- NEXTFEST 2024 jambell: Because the Swamp is not enabled, I am moving these over to the Forest and reducing the XP ramp, so players can actually get these powers.
		MetaProgress.RewardGroup("onheal_powers", {
			-- Stuff that helps you heal regularly or triggers off of receiving healing
			-- TODO: Make more powers that proc "on heal", make this more focused.
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "bloodthirsty"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "heal_on_crit"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "optimism"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "sting_like_a_bee"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "crit_knockdown"),
		}),

		-- Hitstreak/Crit stuff
		MetaProgress.RewardGroup("critcomplex_powers", {
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "streaking"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "combo_wombo"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "precision_weaponry"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "weighted_weaponry"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "crit_streak"),
		}),

		MetaProgress.RewardGroup("gamechanger_powers", {
			-- Stuff that makes you fundamentally change the way you're playing.
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "dont_whiff"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "ping"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "pong"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "analytical"),
			MetaProgress.Reward(Power, Power.Slots.PLAYER, "snowball_effect"),
		}),
	},
})

MetaProgress.AddBiomeExploration("swamp",
{
	endless_reward = MetaProgress.Reward(Consumable, Consumable.Slots.MATERIALS, "konjur_soul_lesser", 5),
	rewards =
	{
		-- NEXTFEST 2024 jambell: Because the Swamp is not enabled, I am moving these over to the Forest and reducing the XP ramp, so players can actually get these powers.

		-- -- NOTE: The player will not be getting these until Dungeon 3
		-- MetaProgress.RewardGroup("onheal_powers", {
		-- 	-- Stuff that helps you heal regularly or triggers off of receiving healing
		-- 	-- TODO: Make more powers that proc "on heal", make this more focused.
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "bloodthirsty"),
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "heal_on_crit"),
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "optimism"),
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "sting_like_a_bee"),
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "crit_knockdown"),
		-- }),

		-- -- Hitstreak/Crit stuff
		-- MetaProgress.RewardGroup("critcomplex_powers", {
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "streaking"),
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "combo_wombo"),
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "precision_weaponry"),
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "weighted_weaponry"),
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "crit_streak"),
		-- }),

		-- MetaProgress.RewardGroup("gamechanger_powers", {
		-- 	-- Stuff that makes you fundamentally change the way you're playing.
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "dont_whiff"),
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "ping"),
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "pong"),
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "analytical"),
		-- 	MetaProgress.Reward(Power, Power.Slots.PLAYER, "snowball_effect"),
		-- }),
	},
})

-- TODO @design #sedament_tundra - meta progress
MetaProgress.AddBiomeExploration("tundra",
{
	rewards =
	{
	},
})
