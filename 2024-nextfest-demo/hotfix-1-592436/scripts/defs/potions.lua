local SGCommon = require "stategraphs.sg_common"

local potion_heal_simple = function(inst, stats)
	if stats.heal then
		local heal = Attack(inst, inst)
		heal:SetHeal(stats.heal)
		inst.components.combat:ApplyHeal(heal)
	end
end

local POTIONS = "POTIONS"
local TONICS = "TONICS"

local potions =
{

---------POTIONS---------

	{
		slot = POTIONS,
		name = "heal1",
		build = "potion_health_sooth",
		data = {
			stats = { heal = 500 },
			tags = { "starting_equipment", "default_unlocked" },
			usage_data = {
				max_uses = 1,
				cooldown = 30,
				quickdrink = false,
				refill_cost = 75,
				power = "soothing_potion"
			},
		}
	},

	{
		slot = POTIONS,
		name = "quick_heal1",
		build = "potion_health_bubble",
		data = {
			tags = { "hide" },
			stats = { heal = 300 },
			usage_data = {
				max_uses = 2,
				cooldown = 120,
				quickdrink = true,
				refill_cost = 75,
				power = "bubbling_potion"
			},
		}
	},

	{
		slot = POTIONS,
		name = "duration_heal1",
		build = "potion_health_mist",
		data = {
			tags = { "hide" },
			stats = { heal = 50 },
			usage_data = {
				max_uses = 1,
				cooldown = 30,
				quickdrink = false,
				refill_cost = 75,
				power = "misting_potion"
			},
		}
	},

---------TONICS---------

	{
		slot = TONICS,
		name = "zucco_dash",
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = {},
			usage_data = {
				power = "tonic_speed",
			},
			rarity = ITEM_RARITY.s.UNCOMMON,
			crafting_data =
			{
				monster_source = {"zucco"},
			},
		},
	},

	{
		slot = TONICS,
		name = "mudslinger",
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = {},
			usage_data = {
				power = "tonic_projectile",
			},
			rarity = ITEM_RARITY.s.UNCOMMON,
			crafting_data =
			{
				monster_source = {"blarmadillo"},
			},
		}
	},

	{
		slot = TONICS,
		name = "full_shield",
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = {},
			usage_data = {
				power = "shield",
				power_stacks = 4,
			},
			rarity = ITEM_RARITY.s.UNCOMMON,
			crafting_data =
			{
				monster_source = {"bulbug"},
			},
		}
	},

	{
		slot = TONICS,
		name = "shrink",
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = {},
			usage_data = {
				power = "smallify",
			},
			rarity = ITEM_RARITY.s.UNCOMMON,
			crafting_data =
			{
				monster_source = {"mothball"},
			},
		}
	},

	{
		slot = TONICS,
		name = "yammo_rage",
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = {},
			usage_data = {
				power = "tonic_rage",
			},
			rarity = ITEM_RARITY.s.EPIC,
			crafting_data =
			{
				monster_source = {"yammo"},
			},
		}
	},

	{
		slot = TONICS,
		name = "explotion",
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = {},
			usage_data = {
				power = "tonic_explode",
			},
			rarity = ITEM_RARITY.s.EPIC,
			crafting_data =
			{
				monster_source = {"megatreemon"},
			},
		}
	},

	{
		slot = TONICS,
		name = "juggernaut",
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = {},
			usage_data = {
				power = "juggernaut",
				power_stacks = 50,
			},
			rarity = ITEM_RARITY.s.EPIC,
			crafting_data =
			{
				monster_source = {"battoad"},
			},
		}
	},

----------------HIDDEN----------------

	{
		slot = TONICS,
		name = "projectile_repeat",
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = {},
			usage_data = {
				power = "tonic_projectile_repeat",
			},
			rarity = ITEM_RARITY.s.EPIC,
		}
	},

	{
		slot = TONICS,
		name = "resolve1",
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = {},
			usage_data = {
				-- power = "steadfast",
			},
		}
	},

	{
		slot = TONICS,
		name = "freeze",
		build = "potion_health",
		data = {
			tags = {"hide"},
			stats = { },
			usage_data = {
				power = "tonic_freeze",
			},
			rarity = ITEM_RARITY.s.EPIC,
		}
	},


}

return potions
