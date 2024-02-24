local EquipmentGem = require "defs.equipmentgems.equipmentgem"

local Power = require"defs.powers"
local Consumable = require"defs.consumable"

function EquipmentGem.AddSupportGem(id, data)
	data.gem_type = EquipmentGem.Type.SUPPORT
	EquipmentGem.AddEquipmentGem("GEMS", id, data)
end

EquipmentGem.AddSupportGem("speed",
{
	stat_mods =
	{
		[EQUIPMENT_STATS.s.SPEED] = { 0.025, 0.05, 0.075, 0.1, 0.125 },
	},
	tags = { "tutorial_gem", "default_unlocked" },
})

-- EquipmentGem.AddSupportGem("sprint",
-- {

-- })

EquipmentGem.AddSupportGem("luck",
{
	stat_mods =
	{
		[EQUIPMENT_STATS.s.LUCK] = { 0.025, 0.05, 0.075, 0.1, 0.125 },
	},
	tags = { "default_unlocked" },
})
