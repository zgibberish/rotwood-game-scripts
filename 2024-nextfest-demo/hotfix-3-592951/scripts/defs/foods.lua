local foods =
{
	{
		name = "meatwich", -- generic
		build = "potion_health",
		data = {
			tags = { "hide" },
			-- tags = { "default_unlocked" },
			stats = { --[[lifetime = 5]] },
			usage_data = {
				power = "thick_skin",
			},
			rarity = ITEM_RARITY.s.COMMON,
			crafting_data = {},
		},
	},

	{
		name = "haggis", -- generic
		build = "potion_health",
		data = {
			tags = { "hide" },
			-- tags = { "default_unlocked" },
			stats = { --[[lifetime = 5]] },
			usage_data = {
				power = "heal_on_enter",
			},
			rarity = ITEM_RARITY.s.COMMON,
			crafting_data = {},
		},
	},

	{
		name = "cased_sausage", -- generic
		build = "potion_health",
		data = {
			tags = { "hide" },
			-- tags = { "default_unlocked" },
			stats = { --[[lifetime = 5]] },
			usage_data = {
				power = "max_health",
			},
			rarity = ITEM_RARITY.s.COMMON,
			crafting_data = {},
		},
	},

	{
		name = "stuffed_blarma", -- blarma
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = { --[[lifetime = 5]] },
			usage_data = {
				power = "max_health_on_enter",
			},
			rarity = ITEM_RARITY.s.UNCOMMON,
			crafting_data =
			{
				monster_source = {"blarmadillo"},
			},
		},
	},

	{
		name = "dimsum", -- cabbageroll
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = { --[[lifetime = 5]] },
			usage_data = {
				power = "retail_therapy",
			},
			rarity = ITEM_RARITY.s.UNCOMMON,
			crafting_data =
			{
				monster_source = {"cabbageroll"},
			},
		},
	},

	{
		name = "salad", -- treemon
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = { --[[lifetime = 5]] },
			usage_data = {
				power = "perfect_pairing",
			},
			rarity = ITEM_RARITY.s.UNCOMMON,
			crafting_data =
			{
				monster_source = {"treemon"},
			},
		},
	},

	{
		name = "gourd_stew", -- yammo
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = { --[[lifetime = 5]] },
			usage_data = {
				power = "pocket_money",
			},
			rarity = ITEM_RARITY.s.UNCOMMON,
			crafting_data =
			{
				monster_source = {"yammo"},
			},
		},
	},

	{
		name = "spiced_gourd", -- gourdo
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = { --[[lifetime = 5]] },
			usage_data = {
				power = "private_healthcare",
			},
			rarity = ITEM_RARITY.s.UNCOMMON,
			crafting_data =
			{
				monster_source = {"gourdo"},
			},
		},
	},

	-- Dupes --
	{
		name = "roast_tail",
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = { --[[lifetime = 5]] },
			usage_data = {
				power = "momentum",
			},
			rarity = ITEM_RARITY.s.UNCOMMON,
		},
	},

	{
		name = "noodle_legs",
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = { --[[lifetime = 5]] },
			usage_data = {
				power = "down_to_business",
			},
			rarity = ITEM_RARITY.s.UNCOMMON,
		},
	},

	{
		name = "cabbage_wrap",
		build = "potion_health",
		data = {
			tags = { "hide" },
			stats = { --[[lifetime = 5]] },
			usage_data = {
				power = "shrapnel",
			},
			rarity = ITEM_RARITY.s.UNCOMMON,
		},
	},




}

-- stuffed_blarma
-- spiced_gourd
-- salad
-- roast_tail
-- noodle_legs
-- meatwich
-- haggis
-- gourd_stew
-- cased_sausage
-- dimsum
-- cabbage_wrap

-- attack_dice
-- undamaged_target
-- running_shoes
-- momentum
-- down_to_business
-- extroverted
-- no_pushback
-- increased_hitstun
-- feedback_loop
-- retail_therapy
-- shrapnel

-- Success level determines how upgraded the dish is
-- Bad food can't be equiped

return foods
