local EquipmentGem = require "defs.equipmentgems.equipmentgem"

local Power = require"defs.powers"
local Consumable = require"defs.consumable"

function EquipmentGem.AddDamageGem(id, data)
	data.gem_type = EquipmentGem.Type.DAMAGE
	EquipmentGem.AddEquipmentGem("GEMS", id, data)
end

EquipmentGem.AddDamageGem("damage_mod",
{
	stat_mods =
	{
		[EQUIPMENT_STATS.s.DMG] = { 3, 5, 7, 10, 12 }, -- TODO: balance this against damage_mult
	},
	tags = { "tutorial_gem", "default_unlocked" },
})

-- EquipmentGem.AddDamageGem("damage_mult",
-- {
-- 	stat_mults =
-- 	{
-- 		[EQUIPMENT_STATS.s.DMG] = { 0.05, 0.10, 0.15, 0.20, 0.25 }, -- TODO: balance this against damage_mod
-- 	},
-- })

EquipmentGem.AddDamageGem("damage_focus",
{
	stat_mods =
	{
		[EQUIPMENT_STATS.s.FOCUS_MULT] = { 0.05, 0.10, 0.15, 0.20, 0.25 }, -- TODO: would prefer this be a flat value increase to any focus hits, instead of adjusting focus mult
	},
	-- tags = { "default_unlocked" },
})

EquipmentGem.AddDamageGem("damage_crit",
{
	stat_mods =
	{
		[EQUIPMENT_STATS.s.CRIT_MULT] = { 0.01, 0.02, 0.03, 0.04, 0.05 },
	},
	tags = { "default_unlocked" },
})

EquipmentGem.AddDamageGem("crit_chance",
{
	stat_mods =
	{
		[EQUIPMENT_STATS.s.CRIT] = { 0.01, 0.02, 0.03, 0.04, 0.05 },
	},
	tags = { "default_unlocked" },
})
