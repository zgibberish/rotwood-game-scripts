local MetaProgress = require "defs.metaprogression.metaprogress"
local lume = require "util.lume"
local Power = require"defs.powers"
local Consumable = require"defs.consumable"

function MetaProgress.AddMonsterResearch(id, data)
	-- define endless reward?
	-- when refined, what tags on materials count towards this research?
	local material_tags = data.material_tags or {}
	table.insert(material_tags, string.format("drops_%s", id))
	data.material_tags = lume.invert(material_tags)

	MetaProgress.AddProgression(MetaProgress.Slots.MONSTER_RESEARCH, id, data)
	-- body
end

--[[
Normal Quality: 10xp (everything but bosses)
High Quality: 30xp elites and bosses
Flawless:
]]
function MetaProgress.AddEasyMonsterResearch(id, data)
	data.base_exp = { 5, 5, 20, 30, 40, 50 }
	data.exp_growth = 0
	MetaProgress.AddMonsterResearch(id, data)
end

function MetaProgress.AddHardMonsterResearch(id, data)
	data.base_exp = { 5, 5, 10, 10, 20, 30, 40, 50 } -- 1 Normal item starts the unlock quickly, 2 right away
	data.exp_growth = 0
	MetaProgress.AddMonsterResearch(id, data)
end

function MetaProgress.AddBossMonsterResearch(id, data)
	data.base_exp = { 30, 30, 60, 90 } -- 1 High item unlocks 1 thing to start  -- TODO(jambell): this is probably too slow.
	data.exp_growth = 0
	MetaProgress.AddMonsterResearch(id, data)
end

function MetaProgress.FindMonsterResearchByConsumableDef(item_def)
	for name, def in pairs(MetaProgress.Items.MONSTER_RESEARCH) do
		for tag, _ in pairs(item_def.tags) do
			if def.material_tags[tag] then
				return def
			end
		end
	end
end

function MetaProgress.FindMonsterResearch(id)
	return MetaProgress.Items.MONSTER_RESEARCH[id]
end

MetaProgress.AddProgressionType("MONSTER_RESEARCH")

-- Tree Forest
MetaProgress.AddEasyMonsterResearch("cabbageroll",
{
	rewards =
	{
		-- MetaProgress.Reward(Power, Power.Slots.PLAYER, "loot_increase_cabbageroll"), --TODO(jambell): restrict to biome cabbageroll spawns
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_furnishings_dummy_cabbageroll"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_food_dimsum"),
	},
})
MetaProgress.AddEasyMonsterResearch("blarmadillo",
{
	rewards =
	{
		-- MetaProgress.Reward(Power, Power.Slots.PLAYER, "loot_increase_blarmadillo"), --TODO(jambell): restrict to biome blarmadillo spawns
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_food_stuffed_blarma"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_tonics_mudslinger"),
	},
})
MetaProgress.AddEasyMonsterResearch("beets",
{
	hide = true,
	rewards =
	{
	},
})
MetaProgress.AddEasyMonsterResearch("treemon",
{
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_food_salad"),
	},
})
MetaProgress.AddHardMonsterResearch("zucco",
{
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_legs_zucco"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_arms_zucco"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_weapon_polearm_startingforest2"), --TODO: should this come sooner in the flow?
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_shoulders_zucco"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_waist_zucco"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_head_zucco"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_body_zucco"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_tonics_zucco_dash"),
	},
})
MetaProgress.AddHardMonsterResearch("yammo",
{
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_legs_yammo"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_arms_yammo"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_weapon_hammer_startingforest2"), --TODO: should this come sooner in the flow?
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_shoulders_yammo"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_waist_yammo"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_head_yammo"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_body_yammo"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_tonics_yammo_rage"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_food_gourd_stew"),
	},
})
MetaProgress.AddBossMonsterResearch("megatreemon",
{
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_legs_megatreemon"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_arms_megatreemon"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_weapon_hammer_megatreemon"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_shoulders_megatreemon"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_waist_megatreemon"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_weapon_polearm_megatreemon"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_head_megatreemon"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_weapon_cannon_megatreemon"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_body_megatreemon"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_weapon_shotput_megatreemon"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_tonics_explotion"),
	},
})

-- Owl Forest
MetaProgress.AddEasyMonsterResearch("gnarlic",
{
	hide = true,
	rewards =
	{
	},
})
MetaProgress.AddEasyMonsterResearch("battoad",
{
	hide = true,
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_legs_battoad"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_arms_battoad"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_shoulders_battoad"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_waist_battoad"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_head_battoad"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_body_battoad"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_tonics_juggernaut"),
	},
})
MetaProgress.AddHardMonsterResearch("gourdo",
{
	hide = true,
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_legs_gourdo"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_arms_gourdo"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_shoulders_gourdo"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_waist_gourdo"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_head_gourdo"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_body_gourdo"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_food_spiced_gourd"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_potions_duration_heal1"),
	},
})

MetaProgress.AddBossMonsterResearch("owlitzer",
{
	hide = true,
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_legs_owlitzer"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_arms_owlitzer"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_shoulders_owlitzer"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_waist_owlitzer"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_head_owlitzer"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_body_owlitzer"),
	},
})

-- Bandicoot Swamp
MetaProgress.AddEasyMonsterResearch("mothball",
{
	material_tags = { 'drops_mothball_teen' },
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_legs_mothball"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_arms_mothball"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_shoulders_mothball"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_waist_mothball"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_head_mothball"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_body_mothball"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_tonics_shrink"),
	}
})

MetaProgress.AddHardMonsterResearch("eyev",
{
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_legs_eyev"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_arms_eyev"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_shoulders_eyev"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_waist_eyev"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_head_eyev"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_body_eyev"),
	},
})
MetaProgress.AddHardMonsterResearch("floracrane",
{
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_legs_floracrane"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_arms_floracrane"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_shoulders_floracrane"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_waist_floracrane"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_head_floracrane"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_body_floracrane"),
	},
})
MetaProgress.AddHardMonsterResearch("bulbug",
{
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_legs_bulbug"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_arms_bulbug"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_shoulders_bulbug"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_waist_bulbug"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_head_bulbug"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_body_bulbug"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_tonics_full_shield"),
	},
})
MetaProgress.AddEasyMonsterResearch("mossquito",
{
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_potions_quick_heal1"),
	},
})
MetaProgress.AddHardMonsterResearch("groak",
{
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_legs_groak"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_arms_groak"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_shoulders_groak"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_waist_groak"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_head_groak"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_body_groak"),
	},
})
MetaProgress.AddEasyMonsterResearch("slowpoke",
{
	hide = true,
	-- rewards =
	-- {
	-- 	MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_book_armourset_slowpoke"),
	-- },
})
MetaProgress.AddBossMonsterResearch("bandicoot",
{
	rewards =
	{
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_legs_bandicoot"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_arms_bandicoot"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_shoulders_bandicoot"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_waist_bandicoot"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_head_bandicoot"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_body_bandicoot"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_furnishings_dummy_bandicoot"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_weapon_polearm_bandicoot"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_weapon_hammer_bandicoot"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_weapon_cannon_bandicoot"),
		MetaProgress.Reward(Consumable, Consumable.Slots.KEY_ITEMS, "recipe_scroll_weapon_shotput_bandicoot"),
	},
})
